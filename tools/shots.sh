#!/usr/bin/env bash
# Renders the player screenshots for qtamp.org into site/assets/shots/.
#
# Uses the offscreen screenshot pipeline of a built qtamp. The shaped cut
# (WASABIQT_SHOT_ALPHA) must keep every pixel the raw grab shows, so the
# qtamp shot_alpha gate runs first and nothing is written when it fails.
# The theme of the main shots is set explicitly, so a colour theme saved in
# the local player config cannot change the website.
#
#   tools/shots.sh                  # all shots except the media library
#   QTAMP_REPO=~/git/qtamp TRACK=/path/song.flac tools/shots.sh
#
# The media library shot renders against a demo library (two albums from
# ~/Music, hardlinked into a throwaway HOME with its own index), so the
# website never shows the rest of a personal music collection.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SITE="$(cd "$HERE/.." && pwd)/site/assets/shots"
QTAMP_REPO="${QTAMP_REPO:-$HOME/git/qtamp}"
QTAMP="${QTAMP:-$QTAMP_REPO/build/qtamp}"
SKIN="${SKIN:-$HOME/.winamp/skins/QTAMP-WinampModernPP}"
TRACK="${TRACK:-$HOME/Music/Achtung Baby/U2 - Zoo Station.flac}"
# The quote would end a word inside ${THEME:-...}, hence the variable.
DEFAULT_THEME="Good Ol' Winamp"
THEME="${THEME:-$DEFAULT_THEME}"
DEMO_ALBUMS=("Achtung Baby" "Kamikaze")

[ -x "$QTAMP" ] || { echo "no qtamp at $QTAMP (build it first)"; exit 2; }
[ -d "$SKIN" ] || { echo "skin missing: $SKIN"; exit 2; }
[ -f "$TRACK" ] || { echo "track missing: $TRACK (set TRACK=)"; exit 2; }

echo "== shot_alpha gate"
"$QTAMP_REPO/tests/regression/shot_alpha_test.sh" "$(dirname "$QTAMP")"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export QT_QPA_PLATFORM=offscreen

shot() { # $1=name, rest = extra environment
  local name="$1"
  shift
  WASABIQT_SHOT_ALPHA=1 env "$@" timeout 60 "$QTAMP" --modern-skin "$SKIN" \
    --screenshot "$tmp/$name.png" "$TRACK" >"$tmp/$name.log" 2>&1
  echo "  $name"
}

echo "== shots"
shot modernpp-eq            "WASABIQT_LIVE_THEME=$THEME"
shot modernpp-drawer-closed "WASABIQT_LIVE_THEME=$THEME" WASABIQT_DRAWER_CLOSED=1
shot theme-blues            "WASABIQT_LIVE_THEME=Blues"
shot theme-goodolwinamp     "WASABIQT_LIVE_THEME=Good Ol' Winamp"
shot theme-halloween        "WASABIQT_LIVE_THEME=Halloween"
timeout 90 "$QTAMP" --modern-skin "$SKIN" --screenshot-container Pledit \
  --screenshot "$tmp/playlist-editor.png" "$TRACK" >"$tmp/pledit.log" 2>&1
echo "  playlist-editor"

# Hardlinks need the same filesystem as ~/Music, hence a HOME under ~/.cache.
# The scan does not follow symlinks.
demo="$(mktemp -d "$HOME/.cache/qtamp-shots-demo.XXXXXX")"
trap 'rm -rf "$tmp" "$demo"' EXIT
mkdir -p "$demo/Music" "$demo/.config/winamp"
for album in "${DEMO_ALBUMS[@]}"; do
  cp -al "$HOME/Music/$album" "$demo/Music/"
done
printf '[player]\ncolortheme=%s\n' "$THEME" >"$demo/.config/winamp/winamp.conf"
HOME="$demo" timeout 180 "$QTAMP" --modern-skin "$SKIN" \
  --screenshot-container MLibrary --screenshot "$tmp/ml-window.png" "$TRACK" \
  >"$tmp/ml.log" 2>&1
echo "  ml-window"

cp "$tmp"/*.png "$SITE/"
echo "== written to $SITE"

# Browsers keep /assets/* for a day (site/_headers), so a new image only
# shows when its URL changes: stamp a hash of each image's bytes into its
# ?v=, which changes exactly when the image does.
INDEX="$(dirname "$(dirname "$SITE")")/index.html"
for f in "$tmp"/*.png; do
  n="$(basename "$f" .png)"
  v="$(sha256sum "$SITE/$n.png" | cut -c1-10)"
  sed -i -E "s#assets/shots/$n\.png(\?v=[0-9a-f]+)?#assets/shots/$n.png?v=$v#g" "$INDEX"
done
echo "== image URLs in $INDEX stamped with content hashes"

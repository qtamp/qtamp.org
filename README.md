# qtamp.org

The [qtamp](https://github.com/qtamp/qtamp) website and the
`curl https://qtamp.sh | sh` installer endpoint, deployed as two
Cloudflare Pages projects:

- `site/` → **qtamp.org** — the project site (static, self-contained).
- `sh/`   → **qtamp.sh** — the installer bootstrap; the root path serves a
  shell script (`_headers` forces `text/x-shellscript`) that fetches and
  runs [`scripts/install.sh`](https://github.com/qtamp/qtamp/blob/main/scripts/install.sh)
  from the qtamp repository.

Deploy:

```sh
wrangler pages deploy site --project-name qtamp-org
wrangler pages deploy sh   --project-name qtamp-sh
```

Screenshots in `site/assets/shots/` are engine renders of the
[QTAMP-branded MIT showcase skins](https://github.com/qtamp) with
transparent backgrounds (`WASABIQT_SHOT_ALPHA=1`).

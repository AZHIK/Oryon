# Deploying the website on the Oryon VPS

This deploys the marketing site as a static Next.js export served by a
non-root Nginx container. It joins the existing `oryon_edge` network, so the
existing Traefik instance terminates TLS and routes `oryonfoods.com` and
`www.oryonfoods.com`.

**No backend service, database, or existing compose file is changed.**

The site has no runtime database dependency. That is deliberate: a public
marketing site stays small, cacheable and cheap to serve. See
[Adding a database later](#adding-a-database-later) for the recommended path.

---

## 1. Prerequisites

- The Oryon Foods stack is already running from `/opt/oryonfoods`; its Traefik
  container owns ports 80/443.
- The external Docker network exists:

  ```bash
  sudo docker network inspect oryon_edge >/dev/null && echo "oryon_edge ok"
  ```

- DNS A records for `oryonfoods.com` and `www.oryonfoods.com` point at the VPS.
  If the apex domain currently points elsewhere, do not start until the record
  is changed.
- Inbound TCP 80 and 443 are open.
- Docker Engine with Compose v2 is installed.

Check DNS from the VPS:

```bash
dig +short oryonfoods.com
dig +short www.oryonfoods.com
```

## Local Docker preview (not the VPS)

The production `docker-compose.yml` expects the VPS Traefik/`oryon_edge`
environment. For a laptop preview, use the separate local compose file. It
publishes port 3000 and requires no Traefik, no external network and no DNS.

Make sure the Docker daemon is running first. On a systemd host such as Kali:

```bash
sudo systemctl start docker
```

Then:

```bash
sudo docker compose -f docker-compose.local.yml up --build -d
```

Open <http://localhost:3000>. Logs and shutdown:

```bash
sudo docker compose -f docker-compose.local.yml logs -f website
sudo docker compose -f docker-compose.local.yml down
```

To test the installer flip locally, create `/tmp/oryon-downloads`, drop
`Oryon-windows-x64-setup.exe` (and optionally `latest.json`) there, and start
the preview. The local compose file mounts that directory read-only at
`/downloads/`.

This builds the same static image as production. It is intentionally separate
from the VPS compose so local work cannot accidentally attach to the production
edge network.

## 2. Get the code on the VPS

This repository can be deployed by pulling `main` on the server. The website
source must be present in that checkout under `apps/website/`; the separate
`/opt/oryonfoods` directory is only the backend deployment package and is not
the website source.

```bash
cd <repo-path>
git pull --ff-only origin main
cd apps/website
```

If the server does not have a full clone yet:

```bash
git clone https://github.com/AZHIK/foodo.git <repo-path>
cd <repo-path>/apps/website
```

If you prefer not to keep the source on the server, copy just the site instead:

```bash
# from the repository root on your workstation
rsync -av \
  --exclude node_modules \
  --exclude .next \
  --exclude out \
  --exclude .env \
  --exclude '.env.*' \
  apps/website/ <user>@<VPS_IP>:/tmp/oryon-website/
```

Then on the VPS:

```bash
sudo install -d -m 755 -o root -g root /opt/oryon-website
sudo cp -a /tmp/oryon-website/. /opt/oryon-website/
sudo chown -R root:root /opt/oryon-website
cd /opt/oryon-website
```

## 3. Build and start

From the directory containing the website's `docker-compose.yml`:

```bash
sudo docker compose config -q
sudo docker compose build
sudo docker compose up -d
```

For the GitHub-pull path that is `cd <repo-path>/apps/website`; for the copy
path it is `cd /opt/oryon-website`.

The first build downloads Node and Nginx base images and runs `npm ci` and the
Next.js export. It needs outbound network access for npm and the bundled Google
font fetch.

The defaults are:

- `WEBSITE_HOST=oryonfoods.com`
- `WEBSITE_IMAGE=oryon-website:local`

Override them only if needed, for example when deploying a CI-built image:

```bash
sudo WEBSITE_IMAGE=ghcr.io/azhik/oryon-website:sha-<commit> \
  docker compose up -d --no-build
```

Optional analytics is build-time only and public:

```bash
sudo docker compose build \
  --build-arg NEXT_PUBLIC_PLAUSIBLE_DOMAIN=oryonfoods.com
sudo docker compose up -d
```

Leaving it empty ships no analytics script.

## 4. Verify

```bash
sudo docker compose ps
curl -sS -o /dev/null -w 'apex %{http_code} -> %{redirect_url}\n' https://oryonfoods.com/
curl -sS -o /dev/null -w 'www  %{http_code} -> %{redirect_url}\n' https://www.oryonfoods.com/
curl -sSI https://oryonfoods.com/ | grep -i strict-transport-security
curl -sS https://oryonfoods.com/sitemap.xml | head
```

Expected:

- `https://oryonfoods.com/` returns `200`.
- `https://www.oryonfoods.com/` returns `301` to the apex domain.
- Traefik issues the certificates through the existing `le` resolver.
- HSTS is present from the existing `secure-headers@file` middleware.

Container logs:

```bash
sudo docker compose logs -f website
```

The container has no published host ports. It is reachable only through
Traefik on `oryon_edge`.

## 5. Updating and rollback

For the GitHub-pull deployment, update the checkout and rebuild:

```bash
cd <repo-path>
git pull --ff-only origin main
cd apps/website
sudo docker compose build
sudo docker compose up -d
```

For the copy-only deployment, copy the new `apps/website` contents to
`/opt/oryon-website` and run the same `docker compose build` / `up -d` there.

For a prebuilt image, change `WEBSITE_IMAGE` to the new immutable
`sha-<commit>` tag and run `docker compose up -d --no-build`. To roll back, put
the previous image tag back and repeat.

## 6. Publishing the Windows installer

This is the production runbook. The site is a static export and does **not**
bake the installer into the image. `/download/` probes
`/downloads/latest.json` and the stable alias
`/downloads/Oryon-windows-x64-setup.exe` in the browser and switches from
“Coming soon” to “Download for Windows” when they exist. After the one-time
setup below, a release needs **no website rebuild and no redeploy** — only the
installer upload.

> **The switch happens in the browser.** `curl` on `/download/` will always
> show the server-rendered “Coming soon” text. Verify the flip in a browser,
> and verify the files themselves with `curl` against `/downloads/`.

### 6.1 One-time VPS setup

Do this once, after deploying the version of the website that contains the
`/downloads/` routes and the read-only mount.

1. Update the website checkout and rebuild the image:

   ```bash
   cd <repo-path>
   git pull --ff-only origin main
   cd apps/website
   sudo docker compose build
   ```

   For the copy-only deployment, copy the new `apps/website` contents
   (including `scripts/`) to `/opt/oryon-website` and run the same build there.

2. Create the host directory **before** starting the container, so Docker does
   not create it as `root`:

   ```bash
   sudo install -d -m 755 -o <deploy-user> -g <deploy-user> /srv/oryon/downloads
   ```

   Replace `<deploy-user>` with the SSH account you use to publish (for example
   `ubuntu`, `deploy`, or your own user). If you publish as root, `root:root` is
   fine.

3. Apply the mount and confirm the container can see the directory:

   ```bash
   sudo docker compose up -d
   sudo docker compose exec website ls -la /usr/share/nginx/html/downloads
   ```

   The production compose file uses
   `${WEBSITE_DOWNLOADS_DIR:-/srv/oryon/downloads}`. If you need a different
   host path, set `WEBSITE_DOWNLOADS_DIR` in `apps/website/.env` (or pass it to
   `docker compose`) and run `sudo docker compose up -d` again.

4. Confirm the route is wired up. A `404` is expected while the directory is
   empty:

   ```bash
   curl -sSI https://oryonfoods.com/downloads/latest.json
   ```

### 6.2 Get and verify the installer artifact

Use the artifact produced by `.github/workflows/windows-installer.yml`. It
contains `Oryon-<version>-windows-x64-setup.exe` and `SHA256SUMS.txt`.

**From a GitHub Actions run** (manual run or tag):

```bash
gh run list --workflow=windows-installer.yml --limit 5
gh run download <run-id> -n oryon-windows-installer -D ./dist
```

**From a GitHub Release** (tag `v1.0.0`):

```bash
gh release download v1.0.0 \
  -p 'Oryon-1.0.0-windows-x64-setup.exe' \
  -p 'SHA256SUMS.txt' \
  -D ./dist
```

**From a local build or a teammate:** use the directory containing the `.exe`
and `SHA256SUMS.txt` (for example an extracted
`oryon-windows-installer` folder). Copy it into `./dist` so the commands below
match.

Verify the artifact before it goes anywhere near the server:

```bash
cd dist
sha256sum -c SHA256SUMS.txt
```

### 6.3 Upload and publish

Copy the installer to the VPS. Staging in `/tmp` keeps ownership predictable:

```bash
scp ./dist/Oryon-1.0.0-windows-x64-setup.exe \
  <deploy-user>@<VPS_IP>:/tmp/
```

On the VPS, run the publish script. **Do not set `ORYON_DOWNLOAD_BASE_URL` for
production**; the default is `https://oryonfoods.com/downloads`.

```bash
ssh <deploy-user>@<VPS_IP>
cd <website-dir>
bash scripts/publish-release.sh /tmp/Oryon-1.0.0-windows-x64-setup.exe
```

`<website-dir>` is the directory containing the website’s `docker-compose.yml`:
`<repo-path>/apps/website` for a git checkout, or `/opt/oryon-website` for the
copy-only deployment.

If the downloads directory is not writable by `<deploy-user>`:

```bash
sudo ORYON_DOWNLOADS_DIR=/srv/oryon/downloads \
  bash scripts/publish-release.sh /tmp/Oryon-1.0.0-windows-x64-setup.exe
```

Running the script as `root` makes the published files root-owned. Either
publish as the directory owner, or fix ownership afterwards:

```bash
sudo chown -R <deploy-user>:<deploy-user> /srv/oryon/downloads
```

The script:

- copies the build to `Oryon-<version>-windows-x64-setup.exe`;
- points `Oryon-windows-x64-setup.exe` at it;
- regenerates `SHA256SUMS.txt` for every version in the directory;
- writes `latest.json` with the version, size, checksum and production URL.

### 6.4 Verify the release

On the VPS:

```bash
cat /srv/oryon/downloads/latest.json
cat /srv/oryon/downloads/SHA256SUMS.txt
sha256sum /srv/oryon/downloads/Oryon-1.0.0-windows-x64-setup.exe
```

Through the public site:

```bash
curl -sS https://oryonfoods.com/downloads/latest.json | jq
curl -sSI https://oryonfoods.com/downloads/Oryon-windows-x64-setup.exe
curl -sSLo /tmp/oryon-check.exe \
  https://oryonfoods.com/downloads/Oryon-windows-x64-setup.exe
sha256sum /tmp/oryon-check.exe
```

Expected:

- `latest.json` returns `200` and the version you just published.
- The alias returns `200`, `content-type: application/octet-stream`,
  `content-length` equal to the file size, and `cache-control: no-cache`.
- The downloaded hash matches the hash in `SHA256SUMS.txt`.
- `latest.json` shows `https://oryonfoods.com/downloads/...`, not `localhost`.

Finally, open <https://oryonfoods.com/download/> in a browser and hard-reload.
The badge should read **Available now**, the card should show the version, size
and SHA-256, and the button should download the installer. Check the home-page
hero CTA as well.

### 6.5 Publish a new version

1. Bump `version:` in `apps/restaurant_app/pubspec.yaml`.
2. Commit and tag `v<version>`. The workflow builds the installer and publishes
   the GitHub Release.
3. Download the new artifact, verify it, and repeat §6.3.

The stable alias and `latest.json` move to the new build automatically. Keep
older versioned files in the directory for rollback.

Never reuse a version number with different bytes: versioned files are served
with `cache-control: immutable`, so browsers and proxies may keep the old copy.

### 6.6 Rollback

Re-run the script with an older installer that is still in the directory:

```bash
cd <website-dir>
bash scripts/publish-release.sh \
  /srv/oryon/downloads/Oryon-0.9.0-windows-x64-setup.exe
```

This rewrites `latest.json` and repoints the stable alias. The alias and
manifest revalidate on the next page load.

### 6.7 Manual fallback

If you only copy `Oryon-windows-x64-setup.exe` into the directory, the HEAD
probe still flips the page, but it shows “Latest” and no checksum. The script is
the supported path because it keeps `latest.json` accurate.

### 6.8 Troubleshooting

| Symptom | Check |
|---|---|
| `404` from `/downloads/...` | `sudo docker compose exec website ls -la /usr/share/nginx/html/downloads`; the mount source in `docker compose config`; the exact filename |
| `403` | Directory mode `755`, files mode `644`; the container’s nginx user must be able to read the host path |
| Page still says “Coming soon” | Hard reload; DevTools → Network: `latest.json` or the alias `HEAD` must return `200`; JavaScript must be enabled |
| Button points at `localhost` | `latest.json` was generated with a local base URL. Re-run the script without `ORYON_DOWNLOAD_BASE_URL` |
| New build not picked up | The versioned filename must change; immutable caching keeps the old bytes |
| `latest.json` is stale | Re-run the script; it rewrites the manifest after the binary and alias |
| Disk filling up | Old installers are kept for rollback; archive or remove very old versions deliberately |

### 6.9 Production checklist

- [ ] `/srv/oryon/downloads` exists and is writable by the publish account.
- [ ] `docker compose config` shows the `/usr/share/nginx/html/downloads` mount.
- [ ] `sha256sum -c SHA256SUMS.txt` passed on the downloaded artifact.
- [ ] `latest.json` shows the production URL, not `localhost`.
- [ ] `/downloads/latest.json` and the alias return `200` over HTTPS.
- [ ] A browser shows “Available now” and downloads the exact file.
- [ ] The installer is code-signed. When it is, set `signed: true` in
      `apps/website/site.config.ts` and redeploy the website once.

## 7. Troubleshooting

| Symptom | Check |
|---|---|
| Traefik returns 404 for the domain | Container is on `oryon_edge`; `traefik.enable=true`; router Host rule; `docker compose ps` |
| Traefik returns 502 | Container health; `docker compose logs website`; `curl http://127.0.0.1:8080/healthz` inside the container |
| Certificate not issued | Apex and `www` DNS; port 80; Traefik ACME logs; `generated/letsencrypt/acme.json` |
| `www` does not redirect | `oryon-www-redirect@docker` middleware label; keep `$$1` escaped in the compose label |
| Direct subpage returns 404 | It must exist in the static export; Next `trailingSlash` generates `/route/index.html` |
| Page shows old content | HTML is `no-cache`; hashed `_next/static` assets are cached for a year. A hard refresh should pick up new HTML |
| Compose cannot find network | Start the main `/opt/oryonfoods` stack first; it creates `oryon_edge` |

Useful checks:

```bash
sudo docker inspect oryon-website-website-1 --format '{{json .State.Health}}'
sudo docker network inspect oryon_edge --format '{{range .Containers}}{{.Name}} {{end}}'
sudo docker logs oryonfoods-traefik-1 --tail 100
```

## 8. Adding a database later

There are two clean options.

### Recommended: static site + separate API

Keep this container as-is. Add a small API service (FastAPI or Node) and a
Postgres database to a separate compose file on the same VPS:

- API joins `oryon_edge` and gets a Traefik router such as
  `Host(\`oryonfoods.com\`) && PathPrefix(\`/api\`)`.
- Postgres joins a private `data` network with **no published ports**.
- Credentials live in Docker secrets or a root-owned env file.
- The site calls `/api/...` from the browser, or a future page uses server-side
  fetching if the site is switched to a Node runtime.
- Add rate limiting and validation at the API, not in Nginx.

This keeps the marketing site fast and keeps the database off the public edge.

### If the website itself must query the database server-side

Change `next.config.ts` from `output: "export"` to `output: "standalone"`,
change the Dockerfile runtime stage to run the Next Node server, and keep it
behind Traefik on port 3000. That is a different operational model: a Node
process, a larger image, and no static-host portability. Do not expose
Postgres either way.

## 9. Operational notes

- The runtime filesystem is read-only; only `/tmp`, `/var/cache/nginx` and
  `/var/run` are writable tmpfs.
- The container drops all Linux capabilities and runs as the image's non-root
  Nginx user.
- Only Traefik publishes host ports.
- Pin the base images to the versions in the Dockerfile and rebuild regularly
  for security updates.
- The site is a static export, so there is no database migration or backup
  requirement for this container.

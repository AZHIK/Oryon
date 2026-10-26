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

## 6. Troubleshooting

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

## 7. Adding a database later

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

## 8. Operational notes

- The runtime filesystem is read-only; only `/tmp`, `/var/cache/nginx` and
  `/var/run` are writable tmpfs.
- The container drops all Linux capabilities and runs as the image's non-root
  Nginx user.
- Only Traefik publishes host ports.
- Pin the base images to the versions in the Dockerfile and rebuild regularly
  for security updates.
- The site is a static export, so there is no database migration or backup
  requirement for this container.

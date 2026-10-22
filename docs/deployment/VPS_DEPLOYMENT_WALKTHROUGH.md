# Fresh VPS Deployment Walkthrough

**Scope:** taking a VPS that already has Ubuntu, Docker, and a Traefik install to a
working Oryon Foods production stack — three APIs answering over HTTPS on their
own domains.

**Audience:** whoever performs the first deployment.

**Companion documents:**

- [`PRODUCTION_DEPLOYMENT.md`](PRODUCTION_DEPLOYMENT.md) — production model,
  decisions, and go-live checklist.
- [`../../deploy/README.md`](../../deploy/README.md) — exact file layout and
  script reference for the deploy package.

---

## Quick path

Once the two facts under [Before starting](#before-starting) are satisfied, the
whole deployment is these commands. The sections below explain each one, the
failure modes, and the verification.

```bash
# 1. DNS: auth/inventory/pos.oryonfoods.com -> VPS IP; open 80 and 443.

# 2. Free ports 80/443 (remove any pre-existing Traefik).

# 3. Stage the package (from the checkout on the VPS).
sudo install -d -m 755 -o root -g root /opt/oryonfoods
sudo cp -a deploy/. /opt/oryonfoods/
sudo chown -R root:root /opt/oryonfoods

# 4. Harden the host, once.
cd /opt/oryonfoods
sudo SSH_PORT=22 RESTART_DOCKER=1 ./host/harden-host.sh

# 5. Configure .env and provider credentials interactively.
sudo ./scripts/configure.sh

# 6. Generate secrets, JWT keys, and rendered Traefik configuration.
sudo ./scripts/bootstrap.sh

# 7. Deploy, migrate, seed, start, and smoke-test.
sudo ./scripts/deploy.sh
```

Roughly 10 minutes plus DNS propagation. DNS and the provider credentials are
irreducible: certificates need DNS and port 80, and credentials are
deliberately not generated. The wizard only removes the manual file editing, not
the safety gates.

---

## Before starting

Two facts drive the order of everything below:

1. **The package deploys its own Traefik.** A Traefik that is already installed
   will hold ports 80/443 and cause the stack's Traefik to fail to bind. Remove
   it, or deliberately rewire it (see §13).
2. **Certificates are issued on the first `deploy.sh` run**, using the Let's
   Encrypt HTTP-01 challenge. DNS must already resolve to the VPS and port 80
   must be reachable before that run. "Connecting the domain later" will fail the
   first deployment.

### Root and sudo

You do **not** need to log in as root. Use a normal account with `sudo`; every
privileged command below is prefixed with `sudo`. The scripts check for effective
UID 0 because `.env` and `secrets/` are root-only, and because they create
`/srv` directories, repair container secret ownership, and manage Docker,
UFW, and systemd.

Do not enable SSH root login, and do not add your user to the `docker` group:
that group is equivalent to root and is unnecessary here. The deploy scripts
check for effective UID 0, so group membership would not remove the `sudo`
requirement anyway.

### Information to gather

| Item | Example |
|---|---|
| Domain name | `oryonfoods.com` |
| VPS public IPv4 | `203.0.113.10` |
| ACME email | `ops@oryonfoods.com` |
| Admin email | `admin@oryonfoods.com` |
| Office/VPN public IP for admin access | `198.51.100.7` |
| Africa's Talking username and API key | production account, **not** `sandbox` |
| Brevo API key and verified sender | `no-reply@oryonfoods.com` |
| Meta WhatsApp app secret and a verify token you invent | required by `deploy.sh` |

`deploy.sh` refuses to run when `at_api_key`, `brevo_api_key`, or
`whatsapp_app_secret` is empty, when `AT_USERNAME=sandbox`, or when any checked
value still contains `REPLACE`/`example.com`. Obtain these credentials first.

### Host prerequisites

```bash
uname -m                       # must be x86_64; CI builds linux/amd64 only
docker compose version         # must be >= 2.20 (the scripts use --wait)
docker --version
df -h / /srv                   # 4 vCPU / 8 GB RAM / 80 GB is the stated minimum
openssl version                # used by configure.sh and bootstrap.sh
timedatectl set-timezone UTC   # the backup timer is defined in UTC
```

---

## 1. Remove the existing Traefik

Identify what owns the edge ports:

```bash
sudo ss -ltnp | grep -E ':(80|443)\b'
sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
systemctl list-units --type=service --all | grep -i traefik
```

Stop it according to how it was installed:

```bash
# Docker container / compose project
cd <directory containing that compose file>
sudo docker compose down

# systemd service
sudo systemctl disable --now traefik

# snap
sudo snap stop --disable traefik
```

Confirm the ports are free:

```bash
sudo ss -ltnp | grep -E ':(80|443)\b' || echo "ports free"
```

Do not leave the old Traefik enabled. Its ACME state, middlewares, and dashboard
are not used by this stack.

---

## 2. Create the DNS records

Create `A` records with TTL 300 at the DNS provider:

```text
auth.oryonfoods.com       -> <VPS_IP>
inventory.oryonfoods.com  -> <VPS_IP>
pos.oryonfoods.com        -> <VPS_IP>
```

Add `AAAA` records only if the VPS has working IPv6.

If the domain is behind Cloudflare, set these three records to **DNS only**
(grey cloud) for the first deployment. The orange proxy hides the real client
IP, which breaks `ADMIN_ALLOWLIST` and the Traefik rate limits unless
`forwardedHeaders.trustedIPs` is configured for Cloudflare's ranges.

Verify propagation from another network:

```bash
dig +short auth.oryonfoods.com @1.1.1.1
dig +short inventory.oryonfoods.com @1.1.1.1
dig +short pos.oryonfoods.com @1.1.1.1
```

Also open inbound 80/443 in the **provider's** firewall, not only UFW.

---

## 3. Stage the deploy package

From the checkout on the VPS:

```bash
sudo install -d -m 755 -o root -g root /opt/oryonfoods
sudo cp -a deploy/. /opt/oryonfoods/
sudo chown -R root:root /opt/oryonfoods

cd /opt/oryonfoods
sudo find . -type f -name '*.sh' -exec chmod 755 {} \;
```

The directory itself is `755` so your sudo-capable account can `cd` into it;
the sensitive state inside is protected separately: `.env` is `600`, and
`secrets/` and `generated/` are `700`.

If the checkout is on a workstation instead, copy it to a staging directory as
your normal user, then move it into place with `sudo`. Do not enable root SSH
just for this:

```bash
rsync -av \
  --exclude 'secrets' --exclude 'generated' --exclude '.env' --exclude 'backups' \
  deploy/ <deploy-user>@<VPS_IP>:/tmp/oryonfoods-deploy/

# on the VPS
sudo cp -a /tmp/oryonfoods-deploy/. /opt/oryonfoods/
sudo chown -R root:root /opt/oryonfoods
```

The `--exclude` flags matter: without them, a later re-sync overwrites live
`secrets/`, `generated/`, and `.env`, which breaks a running database.

---

## 4. Harden the host

```bash
cd /opt/oryonfoods
sudo SSH_PORT=22 RESTART_DOCKER=1 ./host/harden-host.sh
```

The script installs UFW, fail2ban, unattended upgrades, `restic`, the sysctl
profile, journald limits, and `/etc/docker/daemon.json`; it also enables the
`DOCKER-USER` ingress filter and the firewall unit. `RESTART_DOCKER=1` is
appropriate on a fresh host.

Do **not** set `SSH_HARDEN=1` yet. Enable it only after key-based login has been
verified in a second terminal.

Verify:

```bash
sudo ufw status verbose          # 22, 80, 443
ip route show default            # interface used by the DOCKER-USER rule
systemctl status oryonfoods-firewall --no-pager
sudo iptables -S DOCKER-USER
```

---

## 5. Configure `.env` and credentials

```bash
cd /opt/oryonfoods
sudo ./scripts/configure.sh
```

The wizard prompts for hosts, emails, admin allowlist, image tag, and provider
values; validates them; lists the image tags published in GHCR; writes `.env`
with mode `600`; and writes the provider credential files without echoing any
secret. Pressing Enter keeps an existing value, so it is safe to re-run.

The resulting `.env` contains:

```dotenv
AUTH_HOST=auth.oryonfoods.com
INVENTORY_HOST=inventory.oryonfoods.com
POS_HOST=pos.oryonfoods.com

ACME_EMAIL=ops@oryonfoods.com
CORS_ALLOWED_ORIGINS="https://app.oryonfoods.com"
ADMIN_ALLOWLIST="127.0.0.1/32"

IMAGE_REGISTRY=ghcr.io/azhik
IMAGE_TAG=sha-<full-git-sha>

TRAEFIK_IMAGE=traefik:v3.7.16
SOCKET_PROXY_IMAGE=tecnativa/docker-socket-proxy:0.2
POSTGRES_IMAGE=postgres:16.4-alpine
REDIS_IMAGE=redis:7.4-alpine

SMS_PROVIDER=africastalking
AT_USERNAME=<production-username>
AT_SENDER_ID=ORYON

EMAIL_PROVIDER=brevo
BREVO_FROM_EMAIL=no-reply@oryonfoods.com
BREVO_FROM_NAME="Oryon Foods"

ADMIN_EMAIL=admin@oryonfoods.com
ADMIN_FULL_NAME="Platform Administrator"
```

Notes:

- `CORS_ALLOWED_ORIGINS` is only consumed by browser clients. This repository
  has no web frontend (the app under `apps/restaurant_app` is Flutter, which does
  not use CORS), so a forward-looking `https://app.oryonfoods.com` is harmless. It
  must not contain `localhost` or `127.0.0.1`.
- Keep `ADMIN_ALLOWLIST=127.0.0.1/32` until after the smoke test. The smoke test
  expects `/admin` and `/api/v1/auth/platform/*` to be unreachable from the
  public internet.
- Leave the restic fields empty until §11.
- The image tags above are floating defaults; pin them to digests for a fully
  immutable stack.

### Choosing `IMAGE_TAG`

CI tags images as `sha-<full 40-character git SHA>` and pushes
`ghcr.io/<owner>/oryon-{identity,inventory,pos}`. Use the tag built for the
commit being deployed:

```bash
git rev-parse HEAD       # sha-<output>
```

For example, commit `042873582db22af8b303d076e2fceeef0cf0cff3` is published as
`sha-042873582db22af8b303d076e2fceeef0cf0cff3`. Confirm the tag exists before
deploying:

```bash
sudo docker manifest inspect \
  ghcr.io/<owner>/oryon-identity:sha-<full-git-sha> >/dev/null && echo "tag exists"
```

If the packages are private, authenticate once on the VPS:

```bash
printf '%s' "$GHCR_TOKEN" | sudo docker login ghcr.io -u <github-user> --password-stdin
```

`deploy.sh` reports a clear error if the pull is unauthorised.

---

## 6. Generate secrets and rendered configuration

```bash
cd /opt/oryonfoods
sudo ./scripts/bootstrap.sh
```

Generated:

- `secrets/` (root-only) with PostgreSQL/Redis passwords, database URLs, the
  internal service token, and the first platform-admin password
- a 4096-bit JWT keypair
- `generated/redis.conf`
- `generated/traefik.yml` and `generated/dynamic.yml`
- `generated/letsencrypt/acme.json` with mode `600`
- `/srv/oryonfoods/{postgres,redis,item_images,receipts}` with the container
  UIDs expected by the stack

Read and store the admin password:

```bash
sudo cat /opt/oryonfoods/secrets/admin_password
```

> **Do not delete or regenerate `secrets/` after PostgreSQL has initialised.**
> The first-boot initdb script creates the roles with these passwords. If the
> secrets change while the data directory exists, the services fail
> authentication and recovery requires wiping `/srv/oryonfoods/postgres`
> (destroying all data).

---

## 7. Change a provider credential manually

`configure.sh` writes these files. To change one later without re-running the
wizard:

```bash
cd /opt/oryonfoods

sudo bash -c 'printf %s "AFRICASTALKING_API_KEY" > secrets/at_api_key'
sudo bash -c 'printf %s "BREVO_API_KEY"          > secrets/brevo_api_key'
sudo bash -c 'printf %s "META_APP_SECRET"        > secrets/whatsapp_app_secret'
sudo bash -c 'printf %s "WEBHOOK_VERIFY_TOKEN"   > secrets/whatsapp_webhook_verify_token'
```

Re-run `sudo ./scripts/deploy.sh` afterwards so ownership and mode are repaired
and the affected containers are recreated.

- `whatsapp_app_secret` is mandatory: inbound webhooks fail closed without it.
- The verify token is any random string, also entered in the Meta webhook
  configuration (`openssl rand -hex 24`).
- It is normal for the files to be root-owned at this point. `deploy.sh` repairs
  ownership (`10001:10001`, mode `0400`) before the containers read them.

---

## 8. First deployment

Confirm DNS from §2 is live and port 80 is reachable from the internet, then:

```bash
cd /opt/oryonfoods
sudo ./scripts/deploy.sh
```

The sequence:

1. Validates `.env`, placeholders, rendered configuration, and required secrets.
2. Pulls the immutable images.
3. Starts PostgreSQL and Redis and waits for health.
4. Runs Alembic migrations under the owner roles.
5. Grants the runtime roles their privileges.
6. Seeds RBAC, taxonomies, and the first platform administrator.
7. Starts the APIs and Traefik and waits for health (`--wait`, 300 s).
8. Runs the smoke test, retrying startup and certificate issuance for up to
   150 seconds.

First-run certificate issuance can take a couple of minutes. If the command
fails:

```bash
cd /opt/oryonfoods
sudo docker compose --env-file .env -f compose/docker-compose.prod.yml ps
sudo docker compose --env-file .env -f compose/docker-compose.prod.yml logs --tail=200 traefik
sudo docker compose --env-file .env -f compose/docker-compose.prod.yml logs --tail=200 identity
sudo ls -l generated/letsencrypt/acme.json      # must be 600
```

---

## 9. Verify the domains

```bash
cd /opt/oryonfoods
sudo ./scripts/smoke-test.sh
```

Expected: HTTP 301/308 to HTTPS, HTTP 200 on `/health`, HSTS present, and
`/docs`, `/openapi.json`, `/health/ready`, `/admin*`,
`/api/v1/auth/platform/login`, and `/api/v1/internal/*` not publicly reachable
(the internal route must be a `403` from the edge).

Manual checks:

```bash
curl -sS -o /dev/null -w 'https %{http_code}\n' https://auth.oryonfoods.com/health
curl -sS -o /dev/null -w 'http  %{http_code}\n' http://auth.oryonfoods.com/health
curl -sSI https://auth.oryonfoods.com/health | grep -i strict-transport-security

openssl s_client -connect auth.oryonfoods.com:443 -servername auth.oryonfoods.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates

# Run from outside the VPS
nmap -Pn -p 22,80,443,5432,6379 <VPS_IP>
```

Only 22, 80, and 443 may be open. Repeat the health check for `inventory` and
`pos`; a 502 with a healthy container means the router is not on the `edge`
network or the service-port label is wrong.

---

## 10. Admin access

`/admin` is a FastAPI route prefix, not a web UI; this repository contains no
admin frontend. Platform login is:

```text
POST https://auth.oryonfoods.com/api/v1/auth/platform/login
{"email": "admin@oryonfoods.com", "password": "<secrets/admin_password>"}
```

Because `/admin/*` and `/api/v1/auth/platform/*` are restricted to
`ADMIN_ALLOWLIST`, they return `403` from the public internet while the default
`127.0.0.1/32` is in place.

**Option A — SSH tunnel (keeps admin fully private):**

```bash
# on the workstation; use the same sudo-capable account, not root
ssh -L 8443:127.0.0.1:443 <deploy-user>@<VPS_IP>

# in another terminal
curl -sk --resolve "auth.oryonfoods.com:8443:127.0.0.1" \
  https://auth.oryonfoods.com:8443/api/v1/auth/platform/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@oryonfoods.com","password":"<password>"}'
```

**Option B — allow an office/VPN CIDR:**

```bash
# find the workstation's public IP
curl -s https://ifconfig.me

# on the VPS
cd /opt/oryonfoods
sudo ./scripts/configure.sh    # change the admin allowlist; Enter keeps the rest
sudo ./scripts/bootstrap.sh    # re-renders generated/dynamic.yml
sudo docker compose --env-file .env -f compose/docker-compose.prod.yml \
  up -d --force-recreate traefik
```

Inspect the rendered allowlist:

```bash
sudo grep -A3 ipAllowList /opt/oryonfoods/generated/dynamic.yml
```

Prefer a VPN/office range over a single home IP, and never use `0.0.0.0/0`.
Re-running the smoke test after allowlisting your own IP will fail the "not
public" checks, because that IP now receives `200`; run it before allowlisting
or from another network.

---

## 11. After the domains are live

```bash
# 1. Encrypted offsite backups. Set RESTIC_REPOSITORY in .env first, e.g.
#    RESTIC_REPOSITORY=b2:oryonfoods-backups:vps01
sudo RESTIC_INIT=1 ./scripts/backup.sh
sudo ENABLE_BACKUP=1 ./scripts/install-systemd.sh

# 2. Store offline
#    secrets/restic_password
#    secrets/admin_password
#    a copy of secrets/ and generated/

# 3. Rotate the initial admin password after first login.
# 4. Perform a restore drill into a staging directory.
```

Point the Flutter client at the deployed hosts when building:

```bash
flutter build apk \
  --dart-define=IDENTITY_API_BASE_URL=https://auth.oryonfoods.com/api/v1 \
  --dart-define=INVENTORY_API_BASE_URL=https://inventory.oryonfoods.com/api/v1 \
  --dart-define=POS_API_BASE_URL=https://pos.oryonfoods.com/api/v1
```

### Updates and rollback

```bash
# Take a backup first, then:
sudo sed -i 's|^IMAGE_TAG=.*|IMAGE_TAG=sha-<new-full-git-sha>|' /opt/oryonfoods/.env
cd /opt/oryonfoods && sudo ./scripts/deploy.sh
```

Roll back by restoring the previous `IMAGE_TAG` and redeploying. Database
migrations are not automatically reversible; use expand/contract migrations so
the previous image remains compatible with the current schema.

---

## 12. Troubleshooting

| Symptom | Cause / action |
|---|---|
| `Bind for 0.0.0.0:80 failed` | The previous Traefik is still running. See §1. |
| `cd: permission denied` on `/opt/oryonfoods` | The directory is `750 root:root`; run `sudo chmod 755 /opt/oryonfoods`. `secrets/` and `generated/` stay `700`. |
| `IMAGE_TAG still contains a placeholder` | `.env` still has `sha-REPLACE`. |
| `configure.sh`: `IMAGE_TAG still contains a placeholder` | Pressing Enter accepted `sha-REPLACE`; enter the real CI tag. |
| `AUTH_HOST still contains a placeholder` | An `example.com` or `REPLACE` value remains in a checked field. |
| `Missing or empty secret: .../at_api_key` | §7 not done, or the file was written without `sudo`. |
| `AT_USERNAME must be ... not 'sandbox'` | Use the production Africa's Talking username. |
| Certificate not issued | DNS not propagated, port 80 blocked by provider firewall/UFW, Cloudflare proxied, or `acme.json` is not `600`. |
| HTTP does not redirect | Traefik `web` entrypoint or port 80 unreachable. |
| `403` on `/docs` or `/admin` | Expected unless the source IP is in `ADMIN_ALLOWLIST`. |
| `502` on a hostname, container healthy | Router not on the `edge` network or wrong service-port label. |
| `Permission denied` on `/run/secrets/...` | Re-run `sudo ./scripts/deploy.sh`; it repairs secret ownership. |
| Database authentication failure | `secrets/` was regenerated after PostgreSQL initialised. Restore the original secrets, or wipe `/srv/oryonfoods/postgres` (destructive). |
| Webhooks return `401` | `whatsapp_app_secret` missing or wrong. |

---

## 13. Keeping an external Traefik

This is supported by the code but is a divergence from the tested package. The
stack's labels reference file-provider middlewares, so an external Traefik must
reproduce the full configuration:

1. Remove or comment out the `traefik` and `socket-proxy` services in
   `compose/docker-compose.prod.yml`.
2. Let the stack create the `oryonfoods_edge` network (the project is named
   `oryonfoods`), then attach the external Traefik container to it as an
   external network in its own compose file. Traefik must be a Docker container
   on that network; a host-network Traefik cannot resolve the service names.
3. Configure the Docker provider with `exposedByDefault: false`, and define an
   ACME certificate resolver named `le`.
4. Merge the rendered middlewares from `deploy/traefik/dynamic.yml.template`
   into the external Traefik's file provider. The labels require
   `secure-headers@file`, `general-rate-limit@file`, `auth-rate-limit@file`,
   `body-limit@file`, `body-limit-uploads@file`, `admin-allowlist@file`,
   `deny-all@file`, and `compress@file`.
5. Keep Docker socket access for service discovery.

Because package updates can change those labels and middlewares, the bundled
Traefik is the lower-maintenance choice.

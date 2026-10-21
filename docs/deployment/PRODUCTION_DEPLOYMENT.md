# Oryon Foods — Production Deployment on Hostinger VPS (Docker + Traefik)

**Companion to:** `docs/security/SECURITY_AUDIT.md`
**Target:** one Hostinger KVM VPS, Ubuntu 24.04 LTS, Docker Engine + Compose v2,
Traefik v3, three FastAPI services, PostgreSQL 16, Redis 7.
**Status:** blueprint. Nothing here has been applied to a live host yet.

> **Code status (2026-10-21):** the local code/config fixes for SEC-01, SEC-02,
> SEC-04, SEC-05, SEC-06, SEC-11, SEC-31, and SEC-32 are implemented and tested;
> dev compose DB/Redis ports are loopback-bound. This document's host/edge stack
> (`deploy/`) is still not built. See
> [`../security/REMEDIATION_LOG.md`](../security/REMEDIATION_LOG.md).
>
> Flutter **release** builds now require three HTTPS `--dart-define` values:
> `IDENTITY_API_BASE_URL`, `INVENTORY_API_BASE_URL`, and `POS_API_BASE_URL`
> (for example `https://auth.oryonfoods.com/api/v1`).

---

## 1. Target architecture

```
                         Internet
                            │
                    ┌───────▼────────┐
                    │  Hostinger FW  │  (allow 22/80/443 only)
                    └───────┬────────┘
                            │
              ┌─────────────▼─────────────┐
              │        UFW + DOCKER-USER  │  (Docker bypasses UFW!)
              └─────────────┬─────────────┘
                            │
                    ┌───────▼────────┐
                    │    Traefik v3  │  80 → 443 redirect, ACME, HSTS,
                    │  (edge network)│  rate/body limits, access logs
                    └───┬───┬───┬────┘
        ┌───────────────┘   │   └────────────────┐
        │                   │                    │
 ┌──────▼──────┐     ┌──────▼──────┐      ┌──────▼──────┐
 │  identity   │     │  inventory  │      │     pos     │
 │   :8000     │◄────┤   :8100     │◄─────┤   :8200     │
 └──────┬──────┘     └──────┬──────┘      └──────┬──────┘
        │                   │                    │
        └───────────┬───────┴────────────────────┘
                    │        data network (internal)
             ┌──────▼──────┐      ┌──────────────┐
             │ PostgreSQL  │      │    Redis 7   │
             │ 3 DBs/roles │      │  requirepass │
             └─────────────┘      └──────────────┘

        volumes: /srv/oryonfoods/{postgres,redis,item_images,receipts}
        secrets: /opt/oryonfoods/secrets  (root:root 600)
        backups: restic → Backblaze B2 / Cloudflare R2 / S3 (offsite)
```

**Hostnames** (subdomains are the least-change option for the Flutter app, which
already uses one base URL per service):

| Service | Hostname | Internal address |
|---------|----------|------------------|
| Identity | `auth.oryonfoods.com` | `http://identity:8000` |
| Inventory | `inventory.oryonfoods.com` | `http://inventory:8100` |
| POS | `pos.oryonfoods.com` | `http://pos:8200` |
| Traefik dashboard | not published | — |
| DB/Redis | not published | `postgres:5432`, `redis:6379` |

If you later prefer one host with path prefixes (`/auth`, `/inventory`, `/pos`),
that requires changing the FastAPI `root_path` and every client base URL. Start
with subdomains.

---

## 2. Sizing and provider notes

- **Minimum:** 4 vCPU / 8 GB RAM / 80 GB NVMe. Three APIs (~150–250 MB each),
  Postgres (~300–600 MB with three DBs), Redis (~50–150 MB), Traefik (~50 MB),
  plus page cache and Docker overhead. 4 GB works only if you are disciplined
  and do not build on the host.
- **Recommended:** 8 GB if you keep three Postgres containers; 8 GB also gives
  headroom for a staging stack on the same host (not ideal, but common for a
  small team). Consolidating to **one Postgres instance with three databases** is
  the better default on a single VPS: less RAM, one backup/PITR target, one set
  of tuning parameters.
- **Region:** choose the Hostinger data center closest to your users (Tanzania →
  Europe or South Africa/India if available). Latency matters for POS sync.
  Confirm data-residency implications under Tanzania's PDPA before choosing.
- **DNS:** create `A` (and `AAAA` if you enable IPv6) records for `auth`,
  `inventory`, and `pos`. Set TTL to **300s** so failover is fast.
- **Firewall:** configure Hostinger's panel firewall *and* host UFW. Do not rely
  on either alone; Docker can bypass both for published ports (see §4).
- **Snapshots:** enable Hostinger VPS snapshots before upgrades. Treat them as a
  provider-side last resort, not your backup strategy.

---

## 3. Host baseline (run once, as root)

### 3.1 Create the deploy user

```bash
adduser --disabled-password --gecos "" deploy
usermod -aG sudo deploy
# Docker group is root-equivalent. Only add the deploy user if it is the
# account you use for deploys, and protect its SSH key accordingly.
usermod -aG docker deploy
install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
# paste the public key:
#   /home/deploy/.ssh/authorized_keys  (mode 600, owner deploy)
```

### 3.2 SSH hardening

`/etc/ssh/sshd_config.d/99-oryonfoods.conf`:

```sshconfig
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowUsers deploy
MaxAuthTries 3
LoginGraceTime 20
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
```

```bash
sshd -t && systemctl reload ssh
```

Keep your current session open until you have verified key-only login in a second
terminal.

### 3.3 Packages, updates, time

```bash
apt update && apt full-upgrade -y
apt install -y ufw fail2ban unattended-upgrades apt-listchanges \
  ca-certificates curl gnupg jq htop iotop nethogs nmap \
  restic chrony iptables-persistent
dpkg-reconfigure -plow unattended-upgrades   # enable security updates
systemctl enable --now chrony
timedatectl set-timezone UTC
```

`/etc/apt/apt.conf.d/20auto-upgrades` should contain:

```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

### 3.4 Kernel/network sysctl

`/etc/sysctl.d/99-oryonfoods.conf`:

```ini
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
```

```bash
sysctl --system
```

`rp_filter=2` (loose) avoids breaking Docker's multi-bridge routing. If you do not
use IPv6, disable it in `/etc/sysctl.d/` and in UFW.

### 3.5 UFW

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
# only if you enable HTTP/3:
# ufw allow 443/udp
ufw enable
ufw status verbose
```

### 3.6 Docker's firewall bypass — `DOCKER-USER`

Publishing a container port inserts DNAT/ACCEPT rules that are evaluated
**before** UFW's `INPUT` rules. Add explicit rules so only 80/443 can be reached
from the public interface:

```bash
# Replace eth0 with your public interface (`ip -brief addr`).
iptables -A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
iptables -A DOCKER-USER -i eth0 -p tcp -m multiport --dports 80,443 -j RETURN
# if HTTP/3:
# iptables -A DOCKER-USER -i eth0 -p udp --dport 443 -j RETURN
iptables -A DOCKER-USER -i eth0 -j DROP

ip6tables -A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
ip6tables -A DOCKER-USER -i eth0 -p tcp -m multiport --dports 80,443 -j RETURN
ip6tables -A DOCKER-USER -i eth0 -j DROP

netfilter-persistent save
```

Verify **from another machine**:

```bash
nmap -Pn -p 22,80,443,5432,5434,5435,5455,6379,6385 <vps-ip>
```

Only 22/80/443 may be open. If a DB port is open, stop and fix before continuing.

### 3.7 fail2ban

`/etc/fail2ban/jail.d/oryonfoods.local`:

```ini
[sshd]
enabled = true
port = ssh
maxretry = 3
findtime = 10m
bantime = 1h
```

```bash
systemctl enable --now fail2ban
fail2ban-client status sshd
```

Optionally add a Traefik access-log jail for repeated 401/403s.

### 3.8 Swap (only if RAM < 8 GB)

```bash
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
sysctl vm.swappiness=10
```

Do not rely on swap for Postgres performance; it is an OOM safety net.

---

## 4. Docker Engine baseline

Install from Docker's official repository (not the distro package):

```bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" \
  > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

`/etc/docker/daemon.json`:

```json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "live-restore": true,
  "no-new-privileges": true,
  "userland-proxy": false,
  "icc": false
}
```

```bash
systemctl restart docker
docker info | grep -E 'Logging Driver|Live Restore|Cgroup'
ss -lntup | grep -E ':2375|:2376' || echo "docker API not exposed (good)"
```

- **Never** expose the Docker API on TCP.
- `live-restore` keeps containers running during daemon restarts.
- `no-new-privileges` at the daemon level plus per-container `security_opt` is
  defense in depth.
- Prune weekly: `docker image prune -af --filter 'until=168h'`.

---

## 5. Directory and secret layout

```bash
install -d -m 750 -o root -g root /opt/oryonfoods
install -d -m 700 -o root -g root /opt/oryonfoods/secrets
install -d -m 750 -o root -g root /opt/oryonfoods/compose /opt/oryonfoods/traefik
install -d -m 750 -o root -g root /opt/oryonfoods/backups
install -d -m 750 -o root -g root /srv/oryonfoods
install -d -m 750 -o 10001 -g 10001 /srv/oryonfoods/item_images /srv/oryonfoods/receipts
install -d -m 750 -o 999 -g 999 /srv/oryonfoods/postgres /srv/oryonfoods/redis
```

> The app images currently create the runtime user with `useradd -r`, which
> yields an unpredictable UID. **Change the Dockerfiles to a fixed UID/GID**
> (e.g. `useradd -r -u 10001 -g oryonfoods`) so host volume ownership is stable.

Files (all `600`, root-owned):

```
/opt/oryonfoods/secrets/
  compose.env                 # variables used by docker compose interpolation
  identity.env                # identity-only runtime env
  inventory.env               # inventory-only runtime env
  pos.env                     # pos-only runtime env
  postgres_password           # superuser password (used at init + backups)
  identity_db_password
  inventory_db_password
  pos_db_password
  redis_password
  internal_service_token      # openssl rand -hex 32
  jwt_private.pem             # mode 400
  jwt_public.pem              # mode 444 (public, but keep root-owned)
  at_api_key / brevo_api_key  # or keep in identity.env only
  restic_password
  b2_account_id / b2_account_key
```

Generate:

```bash
umask 077
openssl rand -hex 32 > /opt/oryonfoods/secrets/internal_service_token
openssl rand -base64 48  > /opt/oryonfoods/secrets/postgres_password
openssl rand -base64 48  > /opt/oryonfoods/secrets/identity_db_password
openssl rand -base64 48  > /opt/oryonfoods/secrets/inventory_db_password
openssl rand -base64 48  > /opt/oryonfoods/secrets/pos_db_password
openssl rand -base64 48  > /opt/oryonfoods/secrets/redis_password
openssl genrsa -out /opt/oryonfoods/secrets/jwt_private.pem 4096
openssl rsa -in /opt/oryonfoods/secrets/jwt_private.pem \
  -pubout -out /opt/oryonfoods/secrets/jwt_public.pem
chmod 400 /opt/oryonfoods/secrets/jwt_private.pem
chmod 444 /opt/oryonfoods/secrets/jwt_public.pem
```

**Do not** put secrets in `/opt/oryonfoods/compose/docker-compose.prod.yml`.
`compose.env` holds only non-secret interpolation values plus DB passwords if
you choose the simpler env-var approach; the preferred approach is Docker
`secrets:` for the JWT keys and DB passwords, and per-service env files for the
rest.

`compose.env`:

```dotenv
IMAGE_TAG=sha-REPLACE_ME
ACME_EMAIL=ops@oryonfoods.com
AUTH_HOST=auth.oryonfoods.com
INVENTORY_HOST=inventory.oryonfoods.com
POS_HOST=pos.oryonfoods.com
IDENTITY_DB_PASSWORD=REPLACE
INVENTORY_DB_PASSWORD=REPLACE
POS_DB_PASSWORD=REPLACE
REDIS_PASSWORD=REPLACE
# Comma-separated; leave empty for a mobile-only client.
CORS_ALLOWED_ORIGINS=https://admin.oryonfoods.com
```

---

## 6. PostgreSQL: one instance, three databases

### 6.1 First-boot init script

`/opt/oryonfoods/compose/initdb/01-databases.sh` (mode 700, root):

```bash
#!/bin/sh
set -eu

# Read the app-role passwords from Docker secrets (never from the environment,
# so `docker inspect` cannot reveal them).
IDENTITY_PW="$(cat /run/secrets/identity_db_password)"
INVENTORY_PW="$(cat /run/secrets/inventory_db_password)"
POS_PW="$(cat /run/secrets/pos_db_password)"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<-SQL
  CREATE DATABASE oryonfoods_auth;
  CREATE DATABASE oryonfoods_inventory;
  CREATE DATABASE oryonfoods_pos;
SQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
  -v identity_pw="$IDENTITY_PW" \
  -v inventory_pw="$INVENTORY_PW" \
  -v pos_pw="$POS_PW" <<'SQL'
  CREATE ROLE identity_app  LOGIN PASSWORD :'identity_pw';
  CREATE ROLE inventory_app LOGIN PASSWORD :'inventory_pw';
  CREATE ROLE pos_app       LOGIN PASSWORD :'pos_pw';

  GRANT CONNECT ON DATABASE oryonfoods_auth      TO identity_app;
  GRANT CONNECT ON DATABASE oryonfoods_inventory TO inventory_app;
  GRANT CONNECT ON DATABASE oryonfoods_pos       TO pos_app;
SQL

for pair in "oryonfoods_auth:identity_app" \
            "oryonfoods_inventory:inventory_app" \
            "oryonfoods_pos:pos_app"; do
  db="${pair%%:*}"; role="${pair##*:}"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<-SQL
    REVOKE ALL ON SCHEMA public FROM PUBLIC;
    GRANT USAGE ON SCHEMA public TO ${role};
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${role};
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ${role};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${role};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
      GRANT USAGE, SELECT ON SEQUENCES TO ${role};
SQL
done
```

Notes:

- This runs **only on first initialization** of an empty data directory.
- The `*_app` roles get DML only. Migrations run as `postgres` (or a dedicated
  owner role) via an explicit one-off command.
- The app-role passwords are read from Docker secrets at first boot. After
  that, rotate with `ALTER ROLE ... PASSWORD ...` and update the stored secret.
- **Single source of truth:** the example mounts the app-role passwords as
  Docker secrets for `initdb`, but also interpolates `${IDENTITY_DB_PASSWORD}`
  etc. into `DB_URL` from `compose.env`. To avoid drift, generate `compose.env`
  from the same secret files in a small deploy script (or extend the app to read
  `DB_PASSWORD_FILE`). Never let the two copies diverge silently.
- If you prefer stricter separation, use one `*_owner` role per DB for DDL and
  `*_app` for runtime. The important part is: **the app does not connect as
  superuser**.

### 6.2 Tuning for a small VPS

`command:` flags (start conservative; adjust with `pg_stat_statements` later):

```
postgres
  -c max_connections=80
  -c shared_buffers=256MB
  -c effective_cache_size=1GB
  -c maintenance_work_mem=64MB
  -c work_mem=8MB
  -c wal_compression=on
  -c log_min_duration_statement=1000
  -c log_checkpoints=on
  -c log_lock_waits=on
```

Add `pg_stat_statements` if you want query-level visibility.

---

## 7. Traefik v3

### 7.1 Static config — `/opt/oryonfoods/traefik/traefik.yml`

```yaml
global:
  checkNewVersion: false
  sendAnonymousUsage: false

log:
  level: INFO
  format: json

accessLog:
  format: json
  fields:
    headers:
      names:
        Authorization: drop
        Cookie: drop
        Set-Cookie: drop

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: le
    transport:
      respondingTimeouts:
        readTimeout: 30s
        idleTimeout: 180s
  # Internal-only, never published. Used by the container healthcheck.
  traefik:
    address: ":8080"

providers:
  docker:
    endpoint: "tcp://socket-proxy:2375"
    exposedByDefault: false
    network: edge
    watch: true
    defaultRule: "Host(`invalid.local`)"
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true

certificatesResolvers:
  le:
    acme:
      email: "ops@oryonfoods.com"      # replace
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web
      # If HTTP-01 is blocked or you need wildcard certs, switch to a DNS
      # challenge and a provider plugin (Hostinger is not built-in; use a
      # supported DNS provider or a manual/scripted hook).

api:
  dashboard: false

ping:
  entryPoint: traefik

serversTransport:
  insecureSkipVerify: false
```

`acme.json` must be `600`. Never commit it; back it up (it holds the ACME account
key, which lets you re-issue certificates).

### 7.2 Dynamic config — `/opt/oryonfoods/traefik/dynamic.yml`

```yaml
http:
  middlewares:
    secure-headers:
      headers:
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
        forceSTSHeader: true
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: strict-origin-when-cross-origin
        permissionsPolicy: "camera=(), microphone=(), geolocation=()"
        customFrameOptionsValue: SAMEORIGIN
        customResponseHeaders:
          Server: ""
          X-Powered-By: ""

    compress:
      compress: {}

    # 1 MB for JSON/auth; separate higher limit for uploads.
    body-limit:
      buffering:
        maxRequestBodyBytes: 1048576
        memRequestBodyBytes: 524288
        retryExpression: "IsNetworkError() && Attempts() < 2"

    body-limit-uploads:
      buffering:
        maxRequestBodyBytes: 6291456
        memRequestBodyBytes: 1048576

    general-rate-limit:
      rateLimit:
        average: 300
        burst: 600
        period: 1m
        sourceCriterion:
          ipStrategy:
            depth: 0          # Traefik is the edge; use the real remote addr.
                              # Set to 1 if you put Cloudflare in front.

    auth-rate-limit:
      rateLimit:
        average: 30
        burst: 60
        period: 1m
        sourceCriterion:
          ipStrategy:
            depth: 0

    # Deny everything (used for paths that must never be public).
    deny-all:
      ipAllowList:
        sourceRange:
          - "127.0.0.1/32"

    # Replace with your office IP / VPN / Tailscale range.
    admin-allowlist:
      ipAllowList:
        sourceRange:
          - "203.0.113.10/32"
          - "10.8.0.0/24"

tls:
  options:
    default:
      minVersion: VersionTLS12
      sniStrict: true
      # Go's defaults are solid; add explicit cipher suites only if required
      # by a compliance standard.
```

### 7.3 Docker socket proxy

Mounting `/var/run/docker.sock` into Traefik gives a compromised Traefik
root-equivalent control of the host. Use a read-only proxy:

```yaml
socket-proxy:
  image: tecnativa/docker-socket-proxy:0.2   # pin by digest in production
  restart: unless-stopped
  environment:
    CONTAINERS: "1"
    SERVICES: "1"
    NETWORKS: "1"
    EVENTS: "1"
    PING: "1"
    VERSION: "1"
    INFO: "1"
    POST: "0"
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
  networks: [socket]
  read_only: true
  tmpfs: ["/tmp"]
  security_opt: ["no-new-privileges:true"]
  cap_drop: ["ALL"]
```

Caveat: `CONTAINERS=1` still allows `GET /containers/{id}/json`, which exposes
container **environment variables**. This is why database passwords should be
Docker `secrets` (files), not env vars, wherever practical. If you cannot move
them, accept that the socket proxy is part of your trusted computing base.

### 7.4 Router labels

Traefik discovers containers through labels. Set `traefik.enable=true` only on
the three APIs (and Traefik itself); everything else stays hidden.

Example for Identity:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.docker.network=edge"
  - "traefik.http.routers.identity.rule=Host(`${AUTH_HOST}`)"
  - "traefik.http.routers.identity.entrypoints=websecure"
  - "traefik.http.routers.identity.tls=true"
  - "traefik.http.routers.identity.tls.certresolver=le"
  - "traefik.http.routers.identity.middlewares=secure-headers@file,general-rate-limit@file,body-limit@file,compress@file"
  - "traefik.http.services.identity.loadbalancer.server.port=8000"
  - "traefik.http.services.identity.loadbalancer.healthcheck.path=/health"
  - "traefik.http.services.identity.loadbalancer.healthcheck.interval=15s"

  # Strict limit on auth mutations (higher priority than the catch-all).
  - "traefik.http.routers.identity-auth.rule=Host(`${AUTH_HOST}`) && PathPrefix(`/api/v1/auth`)"
  - "traefik.http.routers.identity-auth.priority=250"
  - "traefik.http.routers.identity-auth.entrypoints=websecure"
  - "traefik.http.routers.identity-auth.tls=true"
  - "traefik.http.routers.identity-auth.tls.certresolver=le"
  - "traefik.http.routers.identity-auth.middlewares=secure-headers@file,auth-rate-limit@file,body-limit@file"

  # Never public: admin, platform auth, docs, readiness.
  - "traefik.http.routers.identity-restricted.rule=Host(`${AUTH_HOST}`) && (PathPrefix(`/api/v1/admin`) || PathPrefix(`/api/v1/auth/platform`) || Path(`/docs`) || PathPrefix(`/docs/`) || Path(`/redoc`) || Path(`/openapi.json`) || Path(`/health/ready`))"
  - "traefik.http.routers.identity-restricted.priority=300"
  - "traefik.http.routers.identity-restricted.entrypoints=websecure"
  - "traefik.http.routers.identity-restricted.tls=true"
  - "traefik.http.routers.identity-restricted.tls.certresolver=le"
  - "traefik.http.routers.identity-restricted.middlewares=deny-all@file,secure-headers@file"
```

For admin access from a known IP/VPN, replace `deny-all@file` with
`admin-allowlist@file` on the restricted router.

Inventory:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.docker.network=edge"
  - "traefik.http.routers.inventory.rule=Host(`${INVENTORY_HOST}`)"
  - "traefik.http.routers.inventory.entrypoints=websecure"
  - "traefik.http.routers.inventory.tls.certresolver=le"
  - "traefik.http.routers.inventory.middlewares=secure-headers@file,general-rate-limit@file,body-limit@file,compress@file"
  - "traefik.http.services.inventory.loadbalancer.server.port=8100"
  - "traefik.http.services.inventory.loadbalancer.healthcheck.path=/health"

  # Internal service-to-service only; POS calls it over the Docker network.
  - "traefik.http.routers.inventory-internal.rule=Host(`${INVENTORY_HOST}`) && PathPrefix(`/api/v1/internal`)"
  - "traefik.http.routers.inventory-internal.priority=300"
  - "traefik.http.routers.inventory-internal.entrypoints=websecure"
  - "traefik.http.routers.inventory-internal.tls.certresolver=le"
  - "traefik.http.routers.inventory-internal.middlewares=deny-all@file"

  # Docs/readiness deny.
  - "traefik.http.routers.inventory-restricted.rule=Host(`${INVENTORY_HOST}`) && (Path(`/docs`) || PathPrefix(`/docs/`) || Path(`/redoc`) || Path(`/openapi.json`) || Path(`/health/ready`))"
  - "traefik.http.routers.inventory-restricted.priority=300"
  - "traefik.http.routers.inventory-restricted.entrypoints=websecure"
  - "traefik.http.routers.inventory-restricted.tls.certresolver=le"
  - "traefik.http.routers.inventory-restricted.middlewares=deny-all@file"

  # Product-photo uploads need the larger body limit.
  - "traefik.http.routers.inventory-uploads.rule=Host(`${INVENTORY_HOST}`) && PathRegexp(`/api/v1/businesses/[^/]+/items/[^/]+/image`)"
  - "traefik.http.routers.inventory-uploads.priority=200"
  - "traefik.http.routers.inventory-uploads.entrypoints=websecure"
  - "traefik.http.routers.inventory-uploads.tls.certresolver=le"
  - "traefik.http.routers.inventory-uploads.middlewares=secure-headers@file,general-rate-limit@file,body-limit-uploads@file"
```

POS:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.docker.network=edge"
  - "traefik.http.routers.pos.rule=Host(`${POS_HOST}`)"
  - "traefik.http.routers.pos.entrypoints=websecure"
  - "traefik.http.routers.pos.tls.certresolver=le"
  - "traefik.http.routers.pos.middlewares=secure-headers@file,general-rate-limit@file,body-limit@file,compress@file"
  - "traefik.http.services.pos.loadbalancer.server.port=8200"
  - "traefik.http.services.pos.loadbalancer.healthcheck.path=/health"

  - "traefik.http.routers.pos-restricted.rule=Host(`${POS_HOST}`) && (Path(`/docs`) || PathPrefix(`/docs/`) || Path(`/redoc`) || Path(`/openapi.json`) || Path(`/health/ready`))"
  - "traefik.http.routers.pos-restricted.priority=300"
  - "traefik.http.routers.pos-restricted.entrypoints=websecure"
  - "traefik.http.routers.pos-restricted.tls.certresolver=le"
  - "traefik.http.routers.pos-restricted.middlewares=deny-all@file"

  # Finance receipt uploads.
  - "traefik.http.routers.pos-uploads.rule=Host(`${POS_HOST}`) && PathPrefix(`/api/v1/businesses/`) && PathRegexp(`/api/v1/businesses/[^/]+/finance/attachments`)"
  - "traefik.http.routers.pos-uploads.priority=200"
  - "traefik.http.routers.pos-uploads.entrypoints=websecure"
  - "traefik.http.routers.pos-uploads.tls.certresolver=le"
  - "traefik.http.routers.pos-uploads.middlewares=secure-headers@file,general-rate-limit@file,body-limit-uploads@file"
```

> Traefik matches one router per request (highest priority). Make sure the
> `*-uploads` router still enforces the security headers; it does above.

### 7.5 Certificate notes

- HTTP-01 requires port 80 reachable from the internet and DNS pointing at the
  VPS **before** the first start.
- Rate limits: Let's Encrypt allows 5 duplicate certs/week. Test with the
  staging CA (`caServer`) if you are iterating, then switch.
- Back up `acme.json`; losing it is recoverable but re-issuance is rate-limited.
- Do not enable HSTS preload until every subdomain you will ever use is HTTPS.

---

## 8. Production compose

`/opt/oryonfoods/compose/docker-compose.prod.yml` (abridged but functional;
adjust image names/tags).

```yaml
name: oryonfoods

x-logging: &logging
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"

x-api-defaults: &api-defaults
  restart: unless-stopped
  security_opt: ["no-new-privileges:true"]
  cap_drop: ["ALL"]
  read_only: true
  tmpfs:
    - /tmp:size=64m,mode=1777
  logging: *logging
  stop_grace_period: 30s
  ulimits:
    nofile:
      soft: 65536
      hard: 65536

services:
  traefik:
    image: traefik:v3.1
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /opt/oryonfoods/traefik/traefik.yml:/etc/traefik/traefik.yml:ro
      - /opt/oryonfoods/traefik/dynamic.yml:/etc/traefik/dynamic.yml:ro
      - /opt/oryonfoods/traefik/letsencrypt:/letsencrypt
    networks: [edge, socket]
    security_opt: ["no-new-privileges:true"]
    cap_drop: ["ALL"]
    cap_add: ["NET_BIND_SERVICE"]
    read_only: true
    tmpfs: ["/tmp"]
    logging: *logging
    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 30s
      timeout: 5s
      retries: 3

  socket-proxy:
    image: tecnativa/docker-socket-proxy:0.2
    restart: unless-stopped
    environment:
      CONTAINERS: "1"
      SERVICES: "1"
      NETWORKS: "1"
      EVENTS: "1"
      PING: "1"
      VERSION: "1"
      INFO: "1"
      POST: "0"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks: [socket]
    read_only: true
    tmpfs: ["/tmp"]
    security_opt: ["no-new-privileges:true"]
    cap_drop: ["ALL"]
    logging: *logging

  postgres:
    image: postgres:16.4-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
      POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256"
    secrets:
      - postgres_password
      - identity_db_password
      - inventory_db_password
      - pos_db_password
    volumes:
      - /srv/oryonfoods/postgres:/var/lib/postgresql/data
      - /opt/oryonfoods/compose/initdb:/docker-entrypoint-initdb.d:ro
    networks: [data]
    shm_size: 256mb
    logging: *logging
    security_opt: ["no-new-privileges:true"]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 10
    command: >
      postgres
      -c max_connections=80
      -c shared_buffers=256MB
      -c effective_cache_size=1GB
      -c maintenance_work_mem=64MB
      -c work_mem=8MB
      -c wal_compression=on
      -c log_min_duration_statement=1000
      -c log_checkpoints=on

  redis:
    image: redis:7.4-alpine
    restart: unless-stopped
    environment:
      REDISCLI_AUTH: ${REDIS_PASSWORD}
    command:
      - redis-server
      - --requirepass
      - ${REDIS_PASSWORD}
      - --appendonly
      - "yes"
      - --maxmemory
      - 256mb
      - --maxmemory-policy
      - allkeys-lru
    volumes:
      - /srv/oryonfoods/redis:/data
    networks: [data]
    logging: *logging
    security_opt: ["no-new-privileges:true"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 10

  identity:
    <<: *api-defaults
    image: ghcr.io/REPLACE/oryonfoods-identity:${IMAGE_TAG}
    env_file:
      - /opt/oryonfoods/secrets/identity.env
    environment:
      ENVIRONMENT: prod
      DEBUG: "false"
      LOG_LEVEL: INFO
      DB_URL: postgresql+asyncpg://identity_app:${IDENTITY_DB_PASSWORD}@postgres:5432/oryonfoods_auth
      REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379/0
      JWT_PRIVATE_KEY_PATH: /run/secrets/jwt_private.pem
      JWT_PUBLIC_KEY_PATH: /run/secrets/jwt_public.pem
      CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS}
    secrets:
      - source: jwt_private_key
        target: jwt_private.pem
        mode: 0400
      - source: jwt_public_key
        target: jwt_public.pem
        mode: 0444
    depends_on:
      postgres: { condition: service_healthy }
      redis: { condition: service_healthy }
    networks: [edge, data]
    expose: ["8000"]
    mem_limit: 512m
    pids_limit: 256
    labels:
      # See §7.4 for the full label set.
      - "traefik.enable=true"
      - "traefik.docker.network=edge"
      # ...

  inventory:
    <<: *api-defaults
    image: ghcr.io/REPLACE/oryonfoods-inventory:${IMAGE_TAG}
    env_file:
      - /opt/oryonfoods/secrets/inventory.env
    environment:
      ENVIRONMENT: prod
      DEBUG: "false"
      LOG_LEVEL: INFO
      DB_URL: postgresql+asyncpg://inventory_app:${INVENTORY_DB_PASSWORD}@postgres:5432/oryonfoods_inventory
      JWT_PUBLIC_KEY_PATH: /run/secrets/jwt_public.pem
      INTERNAL_SERVICE_TOKEN: ${INTERNAL_SERVICE_TOKEN}
      CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS}
      WHATSAPP_APP_SECRET: ${WHATSAPP_APP_SECRET}
      PUBLIC_BASE_URL: https://${INVENTORY_HOST}
      # Defense in depth: never let a stray dev/test URL leak into prod.
      TEST_DB_URL: ""
    secrets:
      - source: jwt_public_key
        target: jwt_public.pem
        mode: 0444
    volumes:
      - /srv/oryonfoods/item_images:/var/lib/oryonfoods/item_images
    depends_on:
      postgres: { condition: service_healthy }
    networks: [edge, data]
    expose: ["8100"]
    mem_limit: 512m
    pids_limit: 256
    labels:
      - "traefik.enable=true"
      # ...

  pos:
    <<: *api-defaults
    image: ghcr.io/REPLACE/oryonfoods-pos:${IMAGE_TAG}
    env_file:
      - /opt/oryonfoods/secrets/pos.env
    environment:
      ENVIRONMENT: prod
      DEBUG: "false"
      LOG_LEVEL: INFO
      DB_URL: postgresql+asyncpg://pos_app:${POS_DB_PASSWORD}@postgres:5432/oryonfoods_pos
      JWT_PUBLIC_KEY_PATH: /run/secrets/jwt_public.pem
      INTERNAL_SERVICE_TOKEN: ${INTERNAL_SERVICE_TOKEN}
      INVENTORY_SERVICE_URL: http://inventory:8100/api/v1
      IDENTITY_SERVICE_URL: http://identity:8000/api/v1
      CORS_ALLOWED_ORIGINS: ${CORS_ALLOWED_ORIGINS}
    secrets:
      - source: jwt_public_key
        target: jwt_public.pem
        mode: 0444
    volumes:
      - /srv/oryonfoods/receipts:/var/lib/oryonfoods/receipts
    depends_on:
      postgres: { condition: service_healthy }
      identity: { condition: service_healthy }
      inventory: { condition: service_healthy }
    networks: [edge, data]
    expose: ["8200"]
    mem_limit: 512m
    pids_limit: 256
    labels:
      - "traefik.enable=true"
      # ...

networks:
  edge:
    driver: bridge
  data:
    driver: bridge
    internal: true
  socket:
    driver: bridge
    internal: true

secrets:
  postgres_password:
    file: /opt/oryonfoods/secrets/postgres_password
  identity_db_password:
    file: /opt/oryonfoods/secrets/identity_db_password
  inventory_db_password:
    file: /opt/oryonfoods/secrets/inventory_db_password
  pos_db_password:
    file: /opt/oryonfoods/secrets/pos_db_password
  jwt_private_key:
    file: /opt/oryonfoods/secrets/jwt_private.pem
  jwt_public_key:
    file: /opt/oryonfoods/secrets/jwt_public.pem
```

Important details:

- `data` is `internal: true`, so Postgres/Redis have **no egress**. The APIs are
  dual-homed on `edge` and `data`, so they retain outbound access for Brevo,
  Africa's Talking, and Meta.
- `read_only: true` works for the APIs because they only write to `/tmp` and the
  two upload volumes. If a service writes elsewhere, mount an explicit volume.
- `cap_drop: ALL` on the APIs is safe (non-root, no privileged ports). Postgres
  needs some caps for its entrypoint; it is not cap-dropped in this example.
  Harden it further once you confirm the image's requirements.
- `expose` is documentation only; it does not publish to the host.
- Fixed UID/GID requires the Dockerfile change noted in §5.
- The `identity` image must not contain `keys/` (SEC-01).
- Do not pass `env_file` to `postgres`/`redis`; only the variables they need.

### 8.1 Per-service env files

These files hold non-secret runtime settings. Keep them `600 root:root`.

`identity.env`:

```dotenv
APP_NAME=Oryon Foods Auth
SMS_PROVIDER=africastalking
AT_USERNAME=REPLACE
AT_API_KEY=REPLACE
AT_SENDER_ID=ORYON
EMAIL_PROVIDER=brevo
BREVO_API_KEY=REPLACE
BREVO_FROM_EMAIL=no-reply@oryonfoods.com
BREVO_FROM_NAME=Oryon Foods
JWT_ACCESS_TOKEN_TTL_MINUTES=15
JWT_REFRESH_TOKEN_TTL_DAYS=7
OTP_EXPIRE_MINUTES=5
OTP_MAX_ATTEMPTS=5
SESSION_TTL_MINUTES=60
RATE_LIMIT_LOGIN_PASSWORD_PHONE_LIMIT=5
# ... tune the rest
```

`inventory.env`:

```dotenv
SERVICE_NAME=inventory-service
WHATSAPP_GRAPH_BASE_URL=https://graph.facebook.com
WHATSAPP_GRAPH_VERSION=v21.0
WHATSAPP_APP_SECRET=REPLACE
WHATSAPP_WEBHOOK_VERIFY_TOKEN=REPLACE
ITEM_IMAGE_MAX_BYTES=5242880
```

`pos.env`:

```dotenv
SERVICE_NAME=pos-service
RECEIPT_STORAGE_ROOT=/var/lib/oryonfoods/receipts
RECEIPT_MAX_BYTES=5242880
DEFAULT_TAX_RATE=0
TIME_DRIFT_SUSPECT_THRESHOLD_HOURS=48
TIME_DRIFT_FUTURE_TOLERANCE_MINUTES=5
```

`WHATSAPP_APP_SECRET` must come from the Meta app dashboard; without it the
webhook must fail closed.

---

## 9. CI/CD and release flow

### 9.1 Build in CI, never on the VPS

GitHub Actions (or GitLab CI) per service:

1. `uv sync --frozen` and run `ruff`, `mypy`, `pytest`.
2. `docker buildx build --push` to GHCR with immutable tags:
   `ghcr.io/org/oryonfoods-identity:sha-<git-sha>` (and a moving `:prod` only if
   you never roll back by tag).
3. Trivy scan: fail on `CRITICAL,HIGH` with a fix available; generate an SBOM.
4. Optional: cosign sign the image; verify on the VPS before `up`.

Do not copy the repository to `/opt/oryonfoods` and build there — builds need
compilers/cache, consume RAM, and widen the attack surface.

### 9.2 Deploy sequence

```bash
cd /opt/oryonfoods/compose

# 0. Take a backup first (see §10) and verify it completed.
/opt/oryonfoods/backup/run-backup.sh

# 1. Pull the exact images.
docker compose --env-file /opt/oryonfoods/secrets/compose.env \
  -f docker-compose.prod.yml pull

# 2. Bring up stateful services first.
docker compose --env-file /opt/oryonfoods/secrets/compose.env \
  -f docker-compose.prod.yml up -d postgres redis

# 3. Run migrations as the DB owner/superuser (one-off).
for svc in identity inventory pos; do
  docker compose --env-file /opt/oryonfoods/secrets/compose.env \
    -f docker-compose.prod.yml run --rm \
    -e DB_URL="postgresql+asyncpg://postgres:$(cat /opt/oryonfoods/secrets/postgres_password)@postgres:5432/oryonfoods_${svc}" \
    "$svc" alembic upgrade head
done

# 4. Seeds only after migrations (identity first, then inventory).
docker compose ... run --rm identity uv run python scripts/seed_permissions.py
docker compose ... run --rm identity uv run python scripts/seed_internal_rbac.py
docker compose ... run --rm identity uv run python scripts/seed_role_templates.py
docker compose ... run --rm inventory uv run python scripts/seed_categories.py
docker compose ... run --rm inventory uv run python scripts/seed_units.py

# 5. Bring up the rest.
docker compose --env-file /opt/oryonfoods/secrets/compose.env \
  -f docker-compose.prod.yml up -d

# 6. Smoke test.
curl -fsS https://auth.oryonfoods.com/health
curl -fsS https://inventory.oryonfoods.com/health
curl -fsS https://pos.oryonfoods.com/health
curl -fsS -o /dev/null -w '%{http_code}\n' https://auth.oryonfoods.com/docs   # expect 403
```

Caveats:

- The `DB_URL` override in step 3 must use the async driver for Alembic's
  `env.py` (it calls `create_async_engine`). Check each service's
  `migrations/env.py`.
- `seed_*.py` currently call `SQLModel.metadata.create_all()`; run them only
  after migrations and be aware they can create tables outside Alembic. Removing
  that call in prod is a Phase 0/1 code fix.
- The first platform admin must be created once with a dedicated script/SQL
  (see §12), because `/auth/platform/register` requires an existing admin.

### 9.3 Rollback

- Keep the previous `IMAGE_TAG`; redeploy it with `up -d`.
- **Database rollback is not automatic.** Write migrations as expand/contract:
  add nullable columns/backfill/switch reads, then drop old columns in a later
  release. Never ship a destructive migration in the same release as the code
  that stops using the old shape.
- If a migration must be reverted, use `alembic downgrade -1` only after a
  verified backup and only if the down-revision is tested.

---

## 10. Backups

### 10.1 What must be backed up

1. Each PostgreSQL database (`pg_dump -Fc`).
2. PostgreSQL globals/roles (`pg_dumpall --globals-only`).
3. Redis — **not** business-critical (rate limits, ephemeral), but AOF allows a
   warm restart. Do not treat it as a source of truth.
4. Upload volumes: `item_images`, `receipts`.
5. Configuration: compose files, Traefik config, `acme.json`, and secrets
   (encrypted separately — do not put secrets in the same repo as the data).
6. Host-level: a documented rebuild, not a full disk image.

### 10.2 Nightly encrypted offsite backup

`/opt/oryonfoods/backup/run-backup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

COMPOSE="/opt/oryonfoods/compose"
ENVFILE="/opt/oryonfoods/secrets/compose.env"
OUT="/opt/oryonfoods/backups/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT"

export RESTIC_REPOSITORY="b2:oryonfoods-backups:vps01"
export RESTIC_PASSWORD_FILE="/opt/oryonfoods/secrets/restic_password"
export B2_ACCOUNT_ID="$(cat /opt/oryonfoods/secrets/b2_account_id)"
export B2_ACCOUNT_KEY="$(cat /opt/oryonfoods/secrets/b2_account_key)"

cd "$COMPOSE"

for db in auth inventory pos; do
  docker compose --env-file "$ENVFILE" -f docker-compose.prod.yml \
    exec -T postgres pg_dump -U postgres -Fc "oryonfoods_${db}" \
    > "$OUT/${db}.dump"
done

docker compose --env-file "$ENVFILE" -f docker-compose.prod.yml \
  exec -T postgres pg_dumpall -U postgres --globals-only \
  > "$OUT/globals.sql"

sha256sum "$OUT"/*.dump "$OUT"/globals.sql > "$OUT/SHA256SUMS"

restic backup "$OUT" --tag "postgres" --tag "vps01"
restic backup /srv/oryonfoods/item_images /srv/oryonfoods/receipts \
  --tag "uploads" --tag "vps01"

restic forget \
  --keep-daily 7 --keep-weekly 4 --keep-monthly 12 \
  --prune

# Alerting: ping a dead-man's-switch on success.
curl -fsS -m 10 "https://hc-ping.com/REPLACE-UUID" >/dev/null

rm -rf "$OUT"
```

Systemd units:

`/etc/systemd/system/oryonfoods-backup.service`:

```ini
[Unit]
Description=Oryon Foods encrypted offsite backup
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/oryonfoods/backup/run-backup.sh
User=root
```

`/etc/systemd/system/oryonfoods-backup.timer`:

```ini
[Unit]
Description=Nightly Oryon Foods backup

[Timer]
OnCalendar=*-*-* 02:00:00 UTC
Persistent=true
RandomizedDelaySec=10m

[Install]
WantedBy=timers.target
```

```bash
systemctl daemon-reload
systemctl enable --now oryonfoods-backup.timer
systemctl list-timers | grep oryonfoods
```

### 10.3 RPO upgrade: WAL archiving

Nightly dumps give RPO ≈ 24h. For financial data, add continuous WAL archiving
for **RPO ≤ 5 minutes**:

- Build a small Postgres image that includes `wal-g` (or `pgBackRest`).
- Configure:
  ```
  wal_level = replica
  archive_mode = on
  archive_command = 'wal-g wal-push %p'
  archive_timeout = 300
  ```
- Take a base backup weekly (`wal-g backup-push`).
- Restore with `wal-g backup-fetch` + `recovery_target_time`.
- Test the PITR procedure quarterly; an untested archive is not a backup.

If WAL-G is too much for the first release, run the nightly dump **plus a
6-hourly dump** and document RPO = 6h. Do not claim 5-minute RPO without
continuous archiving.

### 10.4 Backup verification

- `restic check --read-data-subset=5%` weekly.
- Restore the latest dump into a throwaway Postgres monthly and run row counts.
- Alert if the backup timer has not succeeded in 26 hours.
- Keep at least one immutable/object-locked copy if the provider supports it
  (protects against ransomware deleting backups via stolen credentials).

---

## 11. Disaster recovery

### 11.1 Targets

| Tier | RPO | RTO | Notes |
|------|-----|-----|-------|
| Single container crash | 0 | < 1 min | `restart: unless-stopped` + health checks |
| VPS host failure | 24h (dumps) / 5 min (WAL) | 2–4h | Rebuild from runbook + restore |
| Data corruption / bad migration | 5 min (PITR) | 1–2h | Restore to a point before the event |
| Ransomware / root compromise | Last clean backup | 4–8h | Rebuild, rotate **all** secrets, notify |
| Region/provider outage | 24h / 5 min | 4–8h | Standby VPS + DNS switch |

State this honestly to stakeholders. A single VPS cannot offer HA; it can offer
fast, tested recovery.

### 11.2 Runbook: restore to a new VPS

1. **Provision** a VPS with the same OS; apply §3–§4 baseline.
2. **Install** Docker, Compose, restic; restore `/opt/oryonfoods` config
   (compose, Traefik, non-secret env) from your config repo/encrypted store.
3. **Secrets:** restore from the password manager/encrypted vault. If the old
   host was compromised, generate **new** secrets and rotate (do not reuse).
4. **Data directory:** create `/srv/oryonfoods/{postgres,redis,item_images,receipts}`
   with the correct ownership.
5. **Start only Postgres:**
   ```bash
   docker compose --env-file /opt/oryonfoods/secrets/compose.env \
     -f docker-compose.prod.yml up -d postgres
   ```
6. **Restore databases:**
   ```bash
   restic restore latest --target /tmp/restore --tag postgres
   for db in auth inventory pos; do
     docker compose exec -T postgres createdb -U postgres "oryonfoods_${db}"
     docker compose exec -T postgres pg_restore -U postgres -d "oryonfoods_${db}" \
       --no-owner --no-privileges < "/tmp/restore/.../${db}.dump"
   done
   docker compose exec -T postgres psql -U postgres -f /tmp/restore/.../globals.sql
   ```
   For PITR, use `wal-g backup-fetch` + `recovery_target_time` instead.
   Review `globals.sql` before applying it: the fresh cluster already contains
   the `postgres` role, so restore it with `psql --set ON_ERROR_STOP=0` or strip
   the existing-role statements to avoid a failure on the first line.
7. **Restore uploads:** `restic restore latest --target / --tag uploads` (or to a
   staging path, then move with correct ownership).
8. **Migrate** if the restored dump predates the current code:
   `alembic upgrade head` per service, after a fresh backup.
9. **Start APIs** and Traefik; verify TLS issuance (`acme.json` restored or
   re-issue).
10. **Smoke test:** health, login, an authenticated read, a sale/stock sync.
11. **DNS:** update A/AAAA records (TTL 300), watch for propagation.
12. **Post-restore:** force re-login if keys rotated, verify backups run, update
    the incident log.

### 11.3 Runbook: suspected secret/key compromise

1. **Contain:** block 80/443 at the firewall (keep 22 for you); optionally stop
   Traefik. Do not destroy the host — snapshot it for forensics.
2. **Assess:** review Traefik access logs, auth risk events, admin audit table,
   `docker ps`, `last`, `journalctl`, and outbound connections.
3. **Rotate everything** (in this order):
   - JWT signing key (invalidates all access tokens);
   - all database passwords (`ALTER ROLE`);
   - `INTERNAL_SERVICE_TOKEN` (both sides);
   - Redis password;
   - Brevo/Africa's Talking/Meta tokens (revoke in provider consoles);
   - SSH keys and any CI deploy keys;
   - ACME account key if `acme.json` was exposed.
4. **Invalidate sessions:** rotate JWT + revoke all `RefreshToken` rows
   (`UPDATE refreshtoken SET revoked_at = now() WHERE revoked_at IS NULL;` or the
   app's revoke-all helper).
5. **Restore integrity:** if data may have been altered, restore from the last
   known-good backup and reconcile with business records.
6. **Notify:** follow the PDPA breach process (PDPC + affected users) and your
   contractual obligations; involve counsel.
7. **Post-mortem:** root cause, detection gap, control changes, and a re-test.

### 11.4 Runbook: key rotation (planned)

Without `kid` support (current code), rotation requires a short maintenance
window:

1. Generate a new RSA pair; store it in the secret manager.
2. Announce the window (access tokens live 15 min; refresh tokens are opaque and
   unaffected, so users will silently refresh).
3. Stop Identity, Inventory, POS.
4. Replace `jwt_private.pem` and `jwt_public.pem` everywhere.
5. Start everything; verify `/health`, login, and a cross-service call.
6. Destroy the old key.

With `kid` support (recommended): publish the new public key first, wait for all
services to reload, switch signing to the new `kid`, keep the old public key for
at least the access-token TTL plus clock skew, then remove it.

---

## 12. First-admin bootstrap

`platform/register` requires an existing admin, so create the first one once:

```bash
docker compose ... run --rm -e ADMIN_EMAIL=you@oryonfoods.com identity \
  uv run python scripts/create_platform_admin.py
```

If the script does not exist yet, create it to:

- refuse to run if any `PLATFORM_STAFF` user already exists (unless `--force`);
- read the password from stdin (never argv);
- validate with the same `StrongPassword` rules;
- assign the seeded "Super Admin" group/role;
- write an `admin_audit_log` entry;
- print only the user id.

Run it over an SSH session, then delete/disable the script in the image or gate
it behind an explicit `--bootstrap` flag. Never expose a bootstrap HTTP endpoint.

---

## 13. Observability and alerting

Minimum viable:

- **External uptime:** Better Stack/UptimeRobot checks on
  `https://auth|inventory|pos.oryonfoods.com/health` every minute, from at least
  two regions, alerting to email/SMS/Slack.
- **TLS expiry:** check `openssl s_client -connect ... -servername ...` daily;
  alert at 21/14/7 days.
- **Docker:** `cAdvisor` + Prometheus/Grafana (or Hostinger metrics) for CPU,
  RAM, disk, network; alert at disk > 80%, RAM > 90% for 10 min.
- **Logs:** ship Traefik JSON access logs and app stdout to Loki/Vector/B2.
  Retain 30–90 days (longer for auth/admin/finance).
- **Backups:** dead-man's-switch ping (healthchecks.io) on success; alert if no
  success in 26h.
- **App errors:** Sentry (or similar) with PII scrubbing; alert on new error
  signatures.
- **Security alerts:** 401/403 spikes, 429 spikes, repeated `/docs` or
  `/api/v1/internal` probes, new platform admin, `*` permission grant, repeated
  webhook signature failures.

Useful commands:

```bash
docker compose ps
docker compose logs -f --tail=200 identity
docker stats --no-stream
docker events --filter type=container --since 1h
journalctl -u docker --since "1 hour ago"
ss -lntup
```

---

## 14. Go-live checklist

### Before DNS

- [ ] Phase 0 audit fixes merged (SEC-01…SEC-06).
- [ ] Images built in CI, scanned, pinned by digest, pushed to a private registry.
- [ ] `docker run --rm --entrypoint sh <identity-image> -c 'ls /app/keys'` shows
      no private key.
- [ ] `ENVIRONMENT=prod DEBUG=false` boot succeeds; `DEBUG=true` boot fails.
- [ ] Secrets live under `/opt/oryonfoods/secrets`, `600 root:root`; no `.env`
      in the repo or images.
- [ ] `nmap` from outside shows only 22/80/443.
- [ ] Postgres/Redis have strong unique passwords, no published ports, and the
      app does not connect as superuser.
- [ ] Traefik serves a valid certificate, redirects HTTP→HTTPS, sends HSTS and
      `nosniff`.
- [ ] `/docs`, `/openapi.json`, `/health/ready`, `/api/v1/internal/*`,
      `/admin/*`, `/api/v1/auth/platform/*` return 403 publicly.
- [ ] WhatsApp POST without a valid `X-Hub-Signature-256` returns 401.
- [ ] Flutter release build points at HTTPS, logs no secrets, and is signed with
      a release key.
- [ ] Backups ran, are encrypted, offsite, and a restore was verified.
- [ ] Alerts fire for service down, disk > 80%, cert < 14 days, backup > 26h.
- [ ] Admin accounts are behind an IP allowlist/VPN and/or MFA.
- [ ] Runbooks (deploy, rollback, restore, rotation, incident) are printed and
      accessible when the network is down.

### First 24 hours

- [ ] Watch 5xx, 401/403, 429, and latency dashboards.
- [ ] Confirm SMS/email delivery and provider spend.
- [ ] Confirm POS→Inventory stock sync and WhatsApp webhook signatures.
- [ ] Confirm certificate renewal path (`acme.json` persists).
- [ ] Re-run `nmap` and `docker ps` to catch drift.

### First week

- [ ] Restore drill into a staging container/host.
- [ ] Load test the auth endpoints (rate limits and Redis behavior).
- [ ] Review auth risk events and admin audit entries.
- [ ] Patch the first round of dependency updates.
- [ ] Rotate the bootstrap admin password and remove the bootstrap artifact.

---

## 15. Decisions to confirm

1. **Database topology:** one Postgres instance with three databases
   (recommended for this size) vs three containers (stronger isolation, more
   RAM/backup jobs).
2. **Admin access:** office IP allowlist vs WireGuard/Tailscale vs a separate
   admin hostname with MFA. Pick one; do not leave `/admin` public.
3. **RPO:** is a 24h dump acceptable for the first month, or do you need WAL
   archiving (RPO ≤ 5 min) from day one? Financial/POS data usually justifies
   WAL.
4. **Uploads:** keep local volumes (simple, single-node) or move to S3/MinIO
   now (enables horizontal scaling and simplifies backup). The code is already
   behind a storage protocol, so the migration is contained.
5. **Domain layout:** `auth/inventory/pos.oryonfoods.com` (least change) vs a
   single `api.oryonfoods.com` with path prefixes (requires app changes).
6. **Observability vendor:** self-hosted Grafana/Loki vs a hosted service.
7. **Compliance:** confirm PDPA registration/notification obligations and
   whether backups/VPS location satisfy any residency requirement.

Once these are decided, the next implementation steps are: add the root
`deploy/` stack (compose + Traefik + initdb + backup units), apply the Phase 0
code patches, and wire CI to build/scan/push the three images.

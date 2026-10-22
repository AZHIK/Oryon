# Oryon Foods — Production Deployment Runbook

**Target:** one hardened Linux VPS (Ubuntu 24.04 LTS), Docker Engine + Compose
v2.20+, Traefik v3, three FastAPI services, PostgreSQL 16, Redis 7.

**Operational package:** [`deploy/`](../../deploy/README.md). That directory is
the executable source of truth for commands, file names, and secrets. This
document explains the production model, the decisions behind it, and the
go-live verification steps.

**Status:** the package is ready for a first deployment once the checklist in
§11 passes. Nothing in this document has been applied to a live host yet.

---

## 1. Architecture

```text
Internet
   │ 80/443
   ▼
Traefik v3 ── socket proxy (read-only Docker API)
   │ edge network
   ├── identity:8000   auth, users, businesses, stores, RBAC, JWT issuer
   ├── inventory:8100  items, stock, suppliers, purchases, recipes, WhatsApp
   └── pos:8200        sales, payments, finance, customers, receipts
          │ data network (internal only)
          ├── PostgreSQL 16 (three databases, owner + runtime roles)
          └── Redis 7 (identity sessions/rate limits)
```

Hostnames:

| Service | Public hostname | Internal address |
|---|---|---|
| Identity | `auth.<domain>` | `http://identity:8000` |
| Inventory | `inventory.<domain>` | `http://inventory:8100` |
| POS | `pos.<domain>` | `http://pos:8200` |
| PostgreSQL | not published | `postgres:5432` |
| Redis | not published | `redis:6379` |

Trust boundaries:

- Identity is the only JWT issuer. It holds the RSA private key.
- Inventory and POS verify tokens with the mounted public key.
- Each service owns its database; there are no cross-database joins.
- POS calls Inventory over the internal network with a service token.
- Only Traefik publishes host ports. APIs, PostgreSQL, and Redis are not
  reachable from the internet.

---

## 2. Sizing and DNS

- **Minimum:** 4 vCPU / 8 GB RAM / 80 GB NVMe. Three APIs plus one PostgreSQL
  instance, Redis, Traefik, and page cache.
- **Recommended:** 8 GB if you also want a staging stack on the same host.
- **Region:** choose the closest region to users; confirm data-residency
  obligations under Tanzania's PDPA.
- **DNS:** create `A` records (and `AAAA` only if IPv6 is configured) for
  `auth`, `inventory`, and `pos`. Use a TTL of 300 seconds.
- **Firewall:** allow only inbound `22`, `80`, and `443`. Keep the provider
  firewall and host firewall aligned; Docker bypasses UFW for published ports,
  which is why the package also installs `DOCKER-USER` rules.

---

## 3. Host baseline

1. Install Docker Engine and the Compose plugin from Docker's official
   repository. Do not use the distro package.
2. Copy the deploy package to `/opt/oryonfoods` and make it root-owned:

   ```bash
   install -d -m 750 -o root -g root /opt/oryonfoods
   cp -a deploy/. /opt/oryonfoods/
   chown -R root:root /opt/oryonfoods
   ```

3. Run the hardening script as root:

   ```bash
   cd /opt/oryonfoods
   sudo ./host/harden-host.sh
   ```

   It installs UFW, fail2ban, unattended upgrades, `restic`, sysctl settings,
   and the Docker ingress firewall. SSH password hardening is opt-in:

   ```bash
   sudo SSH_HARDEN=1 ./host/harden-host.sh
   ```

   Only do that after verifying key-based SSH login in a second session.

4. Keep the host in UTC. The backup timer is defined in UTC.

The package uses fixed container UIDs: PostgreSQL `70`, Redis `999:1000`, and
the API runtime user `10001`. Host upload volumes must be owned by `10001:10001`.

---

## 4. Configuration

Copy the environment template and edit every `REPLACE`/`example.com` value:

```bash
cd /opt/oryonfoods
cp .env.example .env
chmod 600 .env
```

Required values:

- `AUTH_HOST`, `INVENTORY_HOST`, `POS_HOST`
- `ACME_EMAIL`
- `CORS_ALLOWED_ORIGINS` — exact browser origins, HTTPS only
- `ADMIN_ALLOWLIST` — office/VPN CIDRs allowed to reach `/admin` and
  `/api/v1/auth/platform`. The default `127.0.0.1/32` denies public access.
- `IMAGE_REGISTRY`, `IMAGE_TAG` — an immutable CI-built tag
- `TRAEFIK_IMAGE`, `POSTGRES_IMAGE`, `REDIS_IMAGE`, `SOCKET_PROXY_IMAGE` —
  infrastructure images; pin to digests in production
- provider values (`SMS_PROVIDER`, `AT_USERNAME`, `AT_SENDER_ID`,
  `EMAIL_PROVIDER`, `BREVO_FROM_EMAIL`, `BREVO_FROM_NAME`)
- `ADMIN_EMAIL`, `ADMIN_FULL_NAME`
- restic repository and credential-file paths

Generate secrets and rendered configuration:

```bash
sudo ./scripts/bootstrap.sh
```

`bootstrap.sh` creates:

- PostgreSQL superuser, per-service owner passwords, and per-service runtime
  passwords
- database URLs and the Redis URL as Docker secrets
- a 4096-bit JWT keypair
- the internal service token
- the first platform-admin password (`secrets/admin_password`)
- Redis configuration with authentication
- rendered Traefik static/dynamic configuration
- the ACME storage file with `600` permissions

Existing secret files are never overwritten. The `secrets/` directory is
`700 root`; each file is owned by the consuming container UID (`10001` for
APIs, `70` for PostgreSQL, `999:1000` for Redis) with mode `0400`, because
non-Swarm Compose bind-mounts file secrets from the host and ignores
`uid`/`gid`/`mode`. The deploy scripts repair this ownership on every run.
Back up `secrets/` and the restic password offline before going live.

Fill the provider files that apply:

```text
secrets/at_api_key
secrets/brevo_api_key             # or mailjet_api_key + mailjet_secret_key
secrets/whatsapp_app_secret       # required; webhooks fail closed without it
secrets/whatsapp_webhook_verify_token
```

`deploy.sh` refuses to run if the provider files required by the selected
providers are empty.

---

## 5. Images and registry access

CI (`.github/workflows/prod-images.yml`) builds, scans, and pushes:

```text
${IMAGE_REGISTRY}/oryon-identity:${IMAGE_TAG}
${IMAGE_REGISTRY}/oryon-inventory:${IMAGE_TAG}
${IMAGE_REGISTRY}/oryon-pos:${IMAGE_TAG}
```

Use a `sha-<git-sha>` tag. Never build on the VPS. If the GHCR packages are
private, authenticate once:

```bash
printf '%s' "$GHCR_TOKEN" | docker login ghcr.io -u <github-user> --password-stdin
```

Use a read-only token with `read:packages`, or make the three packages public.

Images deliberately contain no JWT keys. The public key is mounted at
`/run/secrets/jwt_public.pem` and all three services read it through
`JWT_PUBLIC_KEY_PATH`.

---

## 6. First deployment

Run from `/opt/oryonfoods`:

```bash
sudo ./scripts/deploy.sh
```

The script:

1. validates `.env`, placeholders, rendered configuration, and required secrets;
2. pulls the exact images;
3. starts PostgreSQL and Redis and waits for health;
4. runs Alembic migrations under the owner roles;
5. grants the runtime roles DML privileges;
6. seeds RBAC, taxonomies, and the first platform administrator;
7. starts the APIs and Traefik and waits for container health;
8. runs the smoke test with retries for startup and certificate issuance.

The initial admin password is in `secrets/admin_password`. Change it after the
first login.

Install the firewall unit now if `harden-host.sh` did not already do so, and
enable the backup timer only after restic is configured:

```bash
sudo ./scripts/install-systemd.sh
sudo ENABLE_BACKUP=1 ./scripts/install-systemd.sh
```

The firewall unit installs `DOCKER-USER` rules; the backup unit is enabled only
with `ENABLE_BACKUP=1` so a fresh host does not start failing backups early.

---

## 7. Verification

`scripts/smoke-test.sh` checks:

- HTTP `80` redirects to HTTPS with `301`/`308`
- `/health` returns `200` on all three hosts
- HSTS is present
- `/docs`, `/openapi.json`, `/health/ready`, `/admin`, `/admin/users`,
  `/admin/groups`, and `/api/v1/auth/platform/login` are not public
- `/api/v1/internal/...` is rejected at the edge with `403`

The smoke test retries for up to 150 seconds so first-time certificate issuance
and API startup do not cause false failures. Run it before adding the VPS itself
to `ADMIN_ALLOWLIST`, or from outside the allowlist, so restricted paths are
observed as `403` rather than as allowed responses.

Run it manually after every change:

```bash
sudo ./scripts/smoke-test.sh
```

Also verify from outside the host:

```bash
nmap -Pn -p 22,80,443,5432,6379 <vps-ip>
```

Only `22`, `80`, and `443` may be open.

---

## 8. Backups and disaster recovery

`host/harden-host.sh` installs `restic`. Configure an offsite repository in
`.env`, then initialise it once:

```bash
sudo RESTIC_INIT=1 ./scripts/backup.sh
```

A backup contains:

- custom-format PostgreSQL dumps for `oryonfoods_auth`,
  `oryonfoods_inventory`, and `oryonfoods_pos`
- PostgreSQL global roles
- `item_images` and `receipts` tarballs
- compose, Traefik, host, systemd, and script configuration plus `.env`
- optionally `secrets/` and `generated/` when `BACKUP_SECRETS=1`

The restic repository is encrypted. Keep its password offline; losing it makes
the backups unrecoverable.

Restore:

```bash
restic restore latest --target /tmp/oryon-restore
sudo CONFIRM_RESTORE=yes ./scripts/restore.sh \
    /tmp/oryon-restore/opt/oryonfoods/backups/<timestamp>
```

The restore script verifies `SHA256SUMS`, stops the APIs, restores the three
databases and upload volumes, grants runtime privileges, starts the stack, and
runs the smoke test. Global roles are not recreated; a fresh host must run
bootstrap/initdb first.

**Recovery targets:** nightly dumps give an RPO of up to 24 hours. For financial
traffic, add PostgreSQL WAL archiving before go-live to reach an RPO of minutes.

---

## 9. Updates and rollback

Before every production change:

1. Run a backup and confirm it completed.
2. Set `IMAGE_TAG` to the new immutable tag.
3. Run `sudo ./scripts/deploy.sh`.
4. Review `scripts/smoke-test.sh` output and application logs.

Rollback:

1. Set `IMAGE_TAG` to the previous known-good tag.
2. Run `sudo ./scripts/deploy.sh`.
3. Re-run the smoke test.

Database migrations are not automatically reversible. Use expand/contract
migrations so the previous image remains compatible with the current schema.

---

## 10. Day-2 operations

- **Logs:** `docker compose --env-file .env -f compose/docker-compose.prod.yml logs`
- **Health:** monitor `/health` on all three public hosts.
- **Disk:** alert before `/srv/oryonfoods` or the Docker root fills.
- **Certificates:** Traefik renews automatically; alert on expiry.
- **Backups:** alert on a missed restic snapshot and on failed restore drills.
- **Secrets:** rotate provider keys and the internal token on a schedule.
- **JWT keys:** rotate with a coordinated deployment; all services read the
  same mounted public key.
- **Admin access:** keep `ADMIN_ALLOWLIST` limited to a VPN/office range.

---

## 11. Go-live checklist

- [ ] DNS resolves; ports 80/443 reachable from the internet.
- [ ] `host/harden-host.sh` completed; SSH key login verified.
- [ ] `.env` has no placeholders; `secrets/` is `700 root`; secret files are
      owned by the consumer UIDs (`10001`/`70`/`999:1000`) with mode `0400`.
- [ ] GHCR pull authentication works.
- [ ] `sudo ./scripts/bootstrap.sh` completed; provider secrets filled.
- [ ] `sudo ./scripts/deploy.sh` completed without errors.
- [ ] Smoke test passes, including `/admin/*`, `/api/v1/internal/*`, and HSTS.
- [ ] `nmap` from outside shows only 22/80/443.
- [ ] PostgreSQL/Redis have no published ports and use non-superuser runtime
      roles.
- [ ] Traefik serves a valid certificate and redirects HTTP to HTTPS.
- [ ] A restic backup completed; a restore was tested into a staging directory.
- [ ] Backup timer and failure alerting are active.
- [ ] Admin access is restricted to the allowlist/VPN.
- [ ] Initial admin password rotated; secrets and restic password stored
      offline.

---

## 12. Decisions to confirm

1. **Database topology:** one PostgreSQL instance with three databases
   (recommended for this size) versus three containers.
2. **Admin access:** office/VPN IP allowlist versus WireGuard/Tailscale versus
   a separate admin hostname with MFA. Do not leave `/admin` public.
3. **RPO:** 24-hour dumps versus WAL archiving with an RPO of minutes.
4. **Uploads:** local volumes now, or S3/MinIO before horizontal scaling.
5. **Domain layout:** subdomains (current) versus a single host with path
   prefixes (requires app changes).
6. **Observability:** self-hosted Grafana/Loki versus a hosted service.
7. **Compliance:** PDPA registration/notification and data residency.

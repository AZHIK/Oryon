# Oryon Foods Production Deployment

This directory is the production package for the three Oryon Foods backends. It
is designed to be copied to `/opt/oryonfoods` on a single hardened VPS.

It contains:

| Path | Purpose |
|---|---|
| `compose/docker-compose.prod.yml` | Production stack: Traefik, socket proxy, PostgreSQL, Redis, Identity, Inventory, POS |
| `compose/initdb/` | First-boot database, owner-role, and runtime-role creation |
| `traefik/` | Static and dynamic Traefik templates |
| `scripts/configure.sh` | Interactive first-run wizard: writes `.env` and the provider credential files |
| `scripts/bootstrap.sh` | Generates secrets, JWT keys, DB URLs, Redis config, and rendered Traefik config |
| `scripts/deploy.sh` | Pulls images, starts stateful services, migrates, seeds, starts the stack, and smoke-tests |
| `scripts/migrate.sh` | Alembic migrations under the owner role + runtime-role grants |
| `scripts/seed.sh` | RBAC/taxonomy seeds and first platform-admin creation |
| `scripts/smoke-test.sh` | Public HTTPS, redirect, and blocked-path checks |
| `scripts/backup.sh` | Encrypted offsite restic backup |
| `scripts/restore.sh` | Restore databases and uploads from a backup directory |
| `systemd/` | Backup timer and Docker ingress-firewall unit |
| `scripts/install-systemd.sh` | Installs the firewall unit and optionally enables the backup timer |
| `host/` | UFW/Docker/fail2ban/sysctl hardening |
| `.env.example` | Non-secret site configuration |
| `secrets/` | Generated secrets; never committed |

## Target topology

```text
Internet
   │ 80/443
   ▼
Traefik v3 ── socket proxy (read-only Docker API)
   │ edge network
   ├── identity:8000
   ├── inventory:8100
   └── pos:8200
          │ data network (internal only)
          ├── PostgreSQL 16
          └── Redis 7
```

Only Traefik publishes host ports. PostgreSQL and Redis have no public ports and
no internet egress. The APIs are dual-homed so they can reach Brevo, Africa's
Talking, and Meta.

---

## 1. Host preparation

1. Provision Ubuntu 24.04 LTS with Docker Engine and Compose v2.20+ (the
   scripts use `docker compose up --wait`).
2. Point `auth`, `inventory`, and `pos` DNS records at the VPS.
3. Allow inbound `22`, `80`, and `443` in the host firewall.
4. Copy this directory to `/opt/oryonfoods` and keep it root-owned.
5. Run `host/harden-host.sh` as root. It installs UFW, fail2ban, restic,
   unattended upgrades, sysctl settings, and the Docker ingress firewall.

Do not enable SSH password hardening until key-based login has been verified.
The harden script leaves that step opt-in via `SSH_HARDEN=1`.

## 2. Site configuration

The fastest path is `sudo ./scripts/configure.sh`. It prompts for the hosts,
emails, admin allowlist, image tag, and provider values; writes `.env` with mode
`600`; and writes the provider credential files without echoing them. It leaves
the infrastructure image tags and restic settings at their defaults. The manual
equivalent is to copy `.env.example` to `.env` and edit:

- `AUTH_HOST`, `INVENTORY_HOST`, `POS_HOST`
- `ACME_EMAIL`
- `CORS_ALLOWED_ORIGINS` — exact browser origins, HTTPS only
- `ADMIN_ALLOWLIST` — office/VPN CIDRs for the real `/admin` routes and
  `/api/v1/auth/platform` (the rule also covers `/api/v1/admin` for future use)
- `IMAGE_REGISTRY`, `IMAGE_TAG` — an immutable CI-built tag
- `TRAEFIK_IMAGE`, `POSTGRES_IMAGE`, `REDIS_IMAGE`, `SOCKET_PROXY_IMAGE` —
  infrastructure images; pin them to digests for a fully immutable stack
- provider identity values (`AT_USERNAME`, `AT_SENDER_ID`, `BREVO_FROM_EMAIL`)
- `ADMIN_EMAIL`, `ADMIN_FULL_NAME`
- restic repository and credential file paths

The default `ADMIN_ALLOWLIST=127.0.0.1/32` makes `/admin` and
`/api/v1/auth/platform` unreachable from the internet until you add your
network.

## 3. Generate secrets

Run `sudo ./scripts/bootstrap.sh` after configuration. It creates:

- PostgreSQL superuser, per-service owner, and per-service runtime passwords
- database URLs and the Redis URL as Docker secrets
- JWT 4096-bit private/public keys
- the internal service token
- the first platform-admin password (consumed by `seed.sh`)
- Redis configuration with authentication
- rendered Traefik static/dynamic configuration
- the ACME storage file with `600` permissions

The secrets directory stays `700 root`, while each secret file is owned by the
container user that reads it (`10001` for APIs, `70` for PostgreSQL,
`999:1000` for Redis) with mode `0400`; `jwt_public.pem` is `0444`. Compose
ignores `uid`/`gid`/`mode` on non-Swarm file secrets, so the deploy scripts
repair this ownership before every run.

Existing secrets are never overwritten. Back up the secrets directory and the
restic password offline before going live. All deploy, migrate, seed, backup,
restore, and smoke-test scripts must run as root so they can read the root-only
`.env`/secrets and repair ownership.

If you did not use `configure.sh`, fill the provider secret files that apply:

```text
secrets/at_api_key
secrets/brevo_api_key             # or mailjet_api_key + mailjet_secret_key
secrets/whatsapp_app_secret
secrets/whatsapp_webhook_verify_token
```

`whatsapp_app_secret` is required: inbound webhooks fail closed without it.
Leave the restic `b2_*` files empty until an offsite repository exists.

## 4. Build images

Images should be built and scanned in CI, never on the VPS. The deploy stack
expects:

```text
${IMAGE_REGISTRY}/oryon-identity:${IMAGE_TAG}
${IMAGE_REGISTRY}/oryon-inventory:${IMAGE_TAG}
${IMAGE_REGISTRY}/oryon-pos:${IMAGE_TAG}
```

Use an immutable tag such as `sha-<git-sha>`. The repository includes a GitHub
Actions workflow that builds and pushes these images to GHCR. If the GHCR
packages are private, authenticate the VPS once before the first pull:

```bash
printf '%s' "$GHCR_TOKEN" | docker login ghcr.io -u <github-user> --password-stdin
```

Use a read-only classic token with `read:packages`, or make the three packages
public. `deploy.sh` reports a clear error if the pull is unauthorised.

CI also validates this package before building: shell syntax, ShellCheck,
Compose interpolation, Traefik templates, the fixed runtime UID (`10001`), and
the absence of baked JWT keys in every image.

## 5. First deployment

Run `sudo scripts/deploy.sh` from `/opt/oryonfoods`. The sequence is:

1. Validate configuration and required secrets.
2. Pull the exact images.
3. Start PostgreSQL and Redis.
4. Run Alembic migrations under the owner roles.
5. Grant the runtime roles access.
6. Seed RBAC, taxonomies, and the first platform administrator.
7. Start the APIs and Traefik and wait for all health checks.
8. Verify HTTPS, HSTS, the HTTP→HTTPS redirect, and blocked admin/internal paths.
   The smoke test retries startup and certificate issuance for up to 150 seconds.

The initial admin password is in `secrets/admin_password`. Change it after the
first login through the normal account-recovery/rotation process.

## 6. Verification

`sudo scripts/smoke-test.sh` checks:

- `http://<host>/health` redirects to HTTPS
- `https://<host>/health` returns `200` and sends HSTS for all three services
- `/docs`, `/openapi.json`, `/health/ready`, `/admin`, `/admin/users`,
  `/admin/groups`, and `/api/v1/auth/platform/login` are not public
- `/api/v1/internal/businesses/<id>/stock-events` is rejected at the edge with
  `403`

Run the smoke test before adding the VPS itself to `ADMIN_ALLOWLIST` (or from a
host outside the allowlist); otherwise the restricted-path checks will see the
allowed response instead of a `403`.

Certificate issuance uses Let's Encrypt HTTP-01, so DNS and port 80 must work
before the first start. If certificates fail, inspect Traefik logs and the
`generated/letsencrypt/acme.json` permissions.

## 7. Backups

`host/harden-host.sh` installs `restic`. Configure a restic repository in
`.env`, then initialise it once with `sudo RESTIC_INIT=1 scripts/backup.sh`.
Install the units and enable the timer with
`sudo ENABLE_BACKUP=1 scripts/install-systemd.sh`.

The timer runs nightly at 02:00 UTC with a randomized delay. A backup contains:

- custom-format PostgreSQL dumps for all three databases
- global roles
- item-image and receipt tarballs
- compose, Traefik, host, systemd, and script configuration plus `.env`
- optionally `secrets/` and `generated/` when `BACKUP_SECRETS=1`

The backup script takes an exclusive lock and removes temporary dumps if any
step fails. Upload volumes on the host must be owned by UID/GID `10001`, which
matches the fixed runtime user in the service images.

The restic repository is encrypted. Keep its password offline; losing it makes
the backups unrecoverable. Test a restore before launch and after any change to
the restore path.

## 8. Restore and disaster recovery

To restore from a restic snapshot:

1. Restore the snapshot to a directory on the host:

   ```bash
   restic restore latest --target /tmp/oryon-restore
   ```

   The backup directory is under
   `/tmp/oryon-restore/opt/oryonfoods/backups/<timestamp>/`.
2. Put the stack in maintenance (the restore script stops the APIs).
3. Verify `SHA256SUMS` (the script does this).
4. Restore the three database dumps and upload tarballs.
5. Grant runtime privileges.
6. Start the APIs and run the smoke test (the script waits for health checks).

`sudo scripts/restore.sh` performs steps 2–6 from a directory produced by the
backup script. Global roles are not recreated by the script; a fresh host must run
bootstrap/initdb first. The full bare-metal runbook is in
[`../docs/deployment/PRODUCTION_DEPLOYMENT.md`](../docs/deployment/PRODUCTION_DEPLOYMENT.md).

**Recovery targets:** nightly dumps give an RPO of up to 24 hours. For a lower
RPO, add PostgreSQL WAL archiving before accepting financial traffic.

## 9. Updates and rollback

1. Run a backup and confirm it completed.
2. Change `IMAGE_TAG` to the new immutable tag.
3. Run `sudo scripts/deploy.sh`.
4. Run the smoke test and review logs.

To roll back, set `IMAGE_TAG` to the previous known-good tag and run the deploy
script again. Database migrations are not automatically reversible: use
expand/contract migrations so the previous image remains compatible with the
current schema.

## 10. Day-2 operations

- **Logs:** `docker compose --env-file .env -f compose/docker-compose.prod.yml logs`
- **Health:** monitor `/health` on all three hosts from outside the VPS.
- **Disk:** alert before `/srv/oryonfoods` or the Docker root fills.
- **Certificates:** Traefik renews automatically; alert on expiry.
- **Backups:** alert on a missed restic snapshot and on failed restore drills.
- **Secrets:** rotate provider keys and the internal token on a schedule.
- **JWT keys:** rotate only with a coordinated deployment; the current services
  load one public key per service.
- **Admin access:** keep `ADMIN_ALLOWLIST` limited to a VPN/office range.

## 11. Before opening public traffic

- [ ] All placeholder values in `.env` replaced; provider secret files non-empty
- [ ] DNS points at the VPS and ports 80/443 are reachable
- [ ] CI image tag is immutable and the images were scanned
- [ ] `sudo scripts/deploy.sh` completed and `sudo scripts/smoke-test.sh` passes
- [ ] Admin/platform routes are reachable only through the configured VPN/office CIDR
- [ ] A backup has completed and a restore drill has been performed
- [ ] The remaining P1 code findings in the security remediation log have been
      reviewed (platform MFA, rate-limit/bot gaps, WhatsApp token encryption,
      admin audit trail)

Do not treat a successful `docker compose up` as production readiness; the
security findings and recovery drill are part of the gate.

## 12. Security invariants

- Never publish PostgreSQL, Redis, or API ports directly.
- Never commit `.env`, `secrets/`, `generated/`, or `acme.json`.
- Never run the stack with `ENVIRONMENT=local` or console providers in
  production.
- Never pass database or provider credentials as plain environment variables if
  a Docker secret can be used.
- Never give the runtime database role DDL privileges.
- Never bypass the smoke test or skip a backup before a production change.

## 13. Troubleshooting

| Symptom | Check |
|---|---|
| HTTP does not redirect | Traefik `web` entrypoint config and port 80 reachability |
| Certificate not issued | DNS, port 80, ACME email, `acme.json` permissions |
| `403` on `/docs` or admin | Expected unless the source IP is in `ADMIN_ALLOWLIST` |
| API healthy internally but 502 at edge | Traefik router labels, service port, `edge` network |
| Database authentication failure | Secret `db_url` ownership/mode, Postgres init logs, role grants |
| Permission denied on `/run/secrets/...` | Re-run `sudo scripts/deploy.sh` to repair secret ownership (`fix_secret_permissions`) |
| Webhooks return `401` | `whatsapp_app_secret` missing or wrong |
| Backup fails | restic credentials, repository initialisation, database container health |

# Oryon Foods — Backend Security Audit & Production Readiness Review

**Audit date:** 2026-10-21
**Scope:** `services/identity-service`, `services/inventory-service`, `services/pos-service`,
`apps/restaurant_app`, Docker build/runtime configuration, and the deployment model
implied by the three `docker-compose.yml` files.
**Method:** Manual source review, configuration review, dependency and container
inspection. No live penetration test was performed against a running deployment —
all findings are reproducible from the repository.
**Assumption:** The target is a single Hostinger KVM VPS running Docker + Traefik v3,
serving the three FastAPI services and their PostgreSQL/Redis dependencies.

---

## 1. Executive summary

The application code is generally well structured: tenant binding is enforced in
shared dependencies, JWTs are RS256 with the private key confined to Identity
Service, passwords/OTPs/refresh tokens are hashed, uploads are magic-byte checked
and path-traversal guarded, containers run as non-root, and stock-event ingestion
is idempotent.

**The deployment as it exists today is not safe to expose to the internet.**
The blockers are configuration and infrastructure, not the domain logic:

| # | Blocker | Why it matters |
|---|---------|----------------|
| 1 | The JWT **private key is baked into the Identity Service image** | Anyone who can pull/read that image can forge tokens for every tenant and every role. |
| 2 | Production **defaults are insecure and nothing fails fast** | `DEBUG=true`, `ENVIRONMENT=local`, console OTP delivery, `change-me-internal-token`, and `oryonfoods:oryonfoods` all boot silently. |
| 3 | PostgreSQL and Redis are **published on all interfaces** with trivial/no credentials | Direct, total data compromise on a public VPS. Docker's published ports also bypass UFW. |
| 4 | WhatsApp webhooks **accept unsigned POSTs** when no app secret is set | Anyone can inject supplier messages and delivery-status changes. |
| 5 | The Flutter client uses **plaintext HTTP** and **logs request/response bodies**, including passwords, OTPs, and tokens | Credential/token leakage on the device and over the network. |
| 6 | Users can change their **login email/phone without verification** | A stolen access token can be converted into permanent account takeover. |
| 7 | Platform-staff MFA is a **501 stub** and the admin surface is public | Admin compromise is one password away; admin APIs need MFA + network restriction. |

Fix items 1–6 before the first public DNS record is pointed at the VPS. Item 7 can
ship with a network restriction + alerting as an interim control.

### Controls that are already good

- RS256 signing; resource services hold only the public key.
- bcrypt (cost 12) for passwords, OTPs, and refresh tokens; cryptographically
  random OTP generation; OTP expiry + attempt cap; refresh-token rotation and
  reuse detection.
- Business/store context is bound into the token and checked against path
  parameters in the shared dependencies (`require_business_permission`,
  `require_store_permission`), so an endpoint cannot accidentally skip tenancy.
- Upload storage never uses the client filename for paths, checks magic bytes,
  enforces a size cap, and re-checks the resolved path stays under the root.
- Stock-event handling is idempotent per `(event_id, item_id)`.
- Containers run as a non-root user and have health checks.
- The Flutter app stores tokens in `flutter_secure_storage` and encrypts its
  local Drift database (`sqlite3mc`).

---

## 2. Severity definitions

| Level | Meaning |
|-------|---------|
| **P0 — Blocker** | Direct path to full compromise or credential theft. Do not expose until fixed. |
| **P1 — High** | Serious confidentiality/integrity risk or a control that will fail under normal attack. Fix before launch. |
| **P2 — Medium** | Defense-in-depth gap, abuse vector, or operational risk. Fix in the first hardening sprint. |
| **P3 — Low** | Hygiene, information disclosure, or future-proofing. Schedule. |

---

## 3. Findings summary

| ID | Severity | Finding |
|----|----------|---------|
| SEC-01 | P0 | JWT private key copied into the Identity Service image |
| SEC-02 | P0 | Insecure production defaults; no fail-fast validation |
| SEC-03 | P0 | PostgreSQL/Redis published publicly with weak/no auth |
| SEC-04 | P0 | Unsigned WhatsApp webhooks accepted by default |
| SEC-05 | P0 | Mobile client: cleartext HTTP + secrets written to logs |
| SEC-06 | P0 | Email/phone change without verification → account takeover |
| SEC-07 | P1 | No MFA for platform staff; admin surface publicly routed |
| SEC-08 | P1 | No network segmentation or edge tier; services assume `localhost` |
| SEC-09 | P1 | Secret sprawl; provider keys injected into database containers |
| SEC-10 | P1 | Rate-limiting gaps and no bot defense on OTP/email endpoints |
| SEC-11 | P1 | Refresh-token replay does not revoke the token family |
| SEC-12 | P1 | JWT lacks `iss`/`aud`/`kid`; no rotation path |
| SEC-13 | P1 | `/health/ready` public and opens a new Redis connection per request |
| SEC-14 | P1 | WhatsApp access tokens stored in plaintext; verify token disclosed |
| SEC-15 | P1 | No audit trail for platform-admin actions |
| SEC-31 | P1 | Deactivated/suspended users can still log in and refresh tokens |
| SEC-32 | P1 | Protected/owner roles can be assigned by any staff-manager (privilege escalation) |
| SEC-16 | P2 | Weak business password policy; no breach check/MFA |
| SEC-17 | P2 | Unverified registration receives full tokens; enumeration via 409 |
| SEC-18 | P2 | No request-body size limits; unbounded JSON parsing |
| SEC-19 | P2 | Container/host hardening missing (caps, limits, log rotation, socket) |
| SEC-20 | P2 | Supply chain: mutable image tags, no scan/SBOM, `requirements.txt` drift |
| SEC-21 | P2 | No log shipping/alerting; PII and OTPs can reach logs |
| SEC-22 | P2 | Single VPS SPOF; no PITR; upload volumes not in backup story |
| SEC-23 | P2 | No first-admin bootstrap; migrations/seeds manual; seed uses `create_all` |
| SEC-24 | P2 | CORS/header wildcards; no security headers at the app |
| SEC-25 | P3 | Information disclosure (health details, version, existence probe) |
| SEC-26 | P3 | OTP exhaustion increment rolled back; fixed-window race |
| SEC-27 | P3 | bcrypt 72-byte truncation; consider Argon2id |
| SEC-28 | P3 | Dev-only seed scripts/pgAdmin with default credentials |
| SEC-29 | P3 | Public key tracked in git; manual key distribution |
| SEC-30 | P3 | Dev compose files are not a production topology |

> **Remediation status:** P0 fixes for SEC-01, SEC-02, SEC-04, SEC-05, SEC-06, and
> the P1 code fixes for SEC-11, SEC-31, and SEC-32 are implemented in the working
> tree. SEC-03 and the proxy half of SEC-13 are partially addressed; the production
> `deploy/` stack is still required. See [`REMEDIATION_LOG.md`](./REMEDIATION_LOG.md)
> for exact changes, test results, and remaining work.

---

## 4. Detailed findings

### SEC-01 — JWT private key copied into the Identity Service image (P0)

**Evidence**

- `services/identity-service/.dockerignore` excludes `.env` but **not `keys/`**.
- `services/identity-service/Dockerfile`:
  - builder stage runs `COPY . .` (includes `keys/private.pem`);
  - runtime stage runs `COPY --from=builder /app /app`;
  - then `chmod -R a+r /app/keys`.
- The compose file mounts the key at `/run/secrets/jwt_private.pem` and
  `JWT_PRIVATE_KEY_PATH` points there, so the baked-in copy is **not needed at
  runtime** but still ships in every image layer.

**Impact**

An image is a distributable artifact. If it is pushed to any registry, copied to
a VPS, saved to a CI cache, or leaked via a compromised host, the RSA private key
is recoverable. With it, an attacker signs valid access tokens for any
`sub`, `active_business_id`, `active_store_id`, and `permissions` set — full
cross-tenant compromise of every service, with no password or OTP required.

**Fix**

1. Add to `services/identity-service/.dockerignore`:
   ```gitignore
   keys/
   scripts/
   tests/
   ```
2. Remove `chmod -R a+r /app/keys` from the Dockerfile.
3. Keep mounting the key at runtime (`/run/secrets/jwt_private.pem`) with mode
   `0400`.
4. **Rotate the key now** — assume the current key is compromised because it has
   existed in local build contexts. Generate a new pair, update the public key in
   Inventory and POS, restart all services, and force re-login.
5. Add a build-time assertion: fail the build if `keys/private.pem` is in the
   context (e.g. a CI check for the file in `docker buildx imagetools inspect`
   layers, or simply the `.dockerignore` plus a grep test).

**Verification**

```bash
docker build -t identity:test services/identity-service
docker run --rm --entrypoint sh identity:test -c 'ls -la /app/keys || echo "no keys (good)"'
```

---

### SEC-02 — Insecure production defaults; nothing fails fast (P0)

**Evidence**

- `services/*/app/core/config.py`: `debug: bool = True`,
  `environment: str = "local"`, `log_level: str = "DEBUG"`.
- `services/*/app/core/database.py`: `create_async_engine(..., echo=settings.debug)`
  — `DEBUG=true` logs every SQL statement and parameter (phone numbers, emails,
  password hashes, supplier data).
- `services/identity-service/app/main.py`: docs/ReDoc/OpenAPI are disabled only
  when `environment == "prod"` explicitly. If the env var is omitted (the default),
  `/docs` and `/openapi.json` are public.
- `sms_provider: Literal[...] = "console"` and `email_provider = "console"` —
  the console providers log the **full OTP message** to stdout.
- `internal_service_token: str = "change-me-internal-token"` in POS and
  Inventory. Inventory accepts stock events with that default; POS sends it.
- `db_url` defaults to `postgresql+asyncpg://oryonfoods:oryonfoods@...`.
- `cors_allowed_origins` defaults to `http://localhost:3000`.
- `CORS_ALLOWED_ORIGINS`, `INTERNAL_SERVICE_TOKEN`, `INVENTORY_SERVICE_URL`, and
  `IDENTITY_SERVICE_URL` are **absent from every `.env.example`**, so an operator
  following the docs will never set them.

**Impact**

Any single missing environment variable silently degrades security rather than
stopping the deploy: exposed API docs, SQL/PII in logs, OTPs in logs, a known
service-to-service secret, and default DB credentials. This is the most common
cause of real-world breaches in small deployments.

**Fix**

1. Add a `model_validator(mode="after")` to each `Settings` that refuses to boot
   when `environment in {"staging", "prod"}` and any of these is true:
   - `debug` is true;
   - `log_level` is `DEBUG`;
   - `sms_provider == "console"` or `email_provider == "console"`;
   - `internal_service_token` is empty/`change-me-internal-token` (POS/Inventory);
   - `cors_allowed_origins` contains `*`;
   - the DB URL contains the default `oryonfoods:oryonfoods`;
   - `whatsapp_app_secret` is unset (Inventory);
   - `jwt_private_key_path` is missing (Identity).
2. Pin `jwt_algorithm` to `RS256` (reject any other value at startup).
3. In code, set `echo=False` unconditionally when `environment == "prod"`
   (defense in depth even if validation is bypassed).
4. Set `docs_url = None`, `redoc_url = None`, `openapi_url = None` for both
   `staging` and `prod`.
5. Add every production variable to `.env.example` with a safe placeholder and a
   comment explaining the failure mode.
6. Log a single, explicit `settings_validated` line at startup (without values)
   so operators can see which profile booted.

**Verification**

```bash
ENVIRONMENT=prod DEBUG=true docker compose up identity   # must exit non-zero
```

---

### SEC-03 — PostgreSQL/Redis published publicly with weak/no auth (P0)

**Evidence**

- `services/identity-service/docker-compose.yml`: `postgres` publishes
  `5455:5432`, `redis` publishes `6385:6379`, `POSTGRES_PASSWORD: oryonfoods`.
- `services/inventory-service/docker-compose.yml`: `5434:5432`,
  `POSTGRES_PASSWORD: oryonfoods`.
- `services/pos-service/docker-compose.yml`: `5435:5432`,
  `POSTGRES_PASSWORD: oryonfoods`.
- Redis has no `requirepass`, no ACL, no bind restriction, and no persistence
  configuration.
- All app URLs connect as the PostgreSQL **superuser** created by the image.

**Impact**

On a public VPS, `5434/5435/5455` and `6385` are reachable unless a firewall
blocks them. **Docker inserts its own iptables rules ahead of UFW's `INPUT`
rules**, so a published port can remain reachable even when UFW says it is
denied. A trivial password plus a superuser role means full read/write/drop of
every database; unauthenticated Redis means rate-limit poisoning, session/OTP
state tampering, and a pivot for further attacks.

**Fix**

1. Remove every `ports:` entry from `postgres` and `redis`. Use `expose:` only,
   and attach them exclusively to an internal Docker network.
2. Generate strong, unique passwords per database (32+ chars) and store them in
   root-owned secret files.
3. Stop connecting as the image superuser:
   - bootstrap the cluster with a `postgres` superuser whose password is only in
     a secret file;
   - create a per-service login role with `CONNECT`, `USAGE`, and
     `SELECT/INSERT/UPDATE/DELETE` on its schema — no `CREATEDB`, no `SUPERUSER`,
     no DDL;
   - use a separate migration role for `alembic upgrade`.
4. Configure Redis:
   ```
   redis-server --requirepass "$REDIS_PASSWORD" \
     --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
   ```
   Use `REDISCLI_AUTH` for health checks so the password is not in `ps`.
5. Add the `DOCKER-USER` firewall rules described in the deployment guide —
   UFW alone is not sufficient with Docker.
6. Verify from **outside** the VPS:
   ```bash
   nmap -Pn -p 22,80,443,5434,5435,5455,6379,6385 <vps-ip>
   ```
   Only 22/80/443 (and 443/udp if HTTP/3) may be open.

---

### SEC-04 — Unsigned WhatsApp webhooks accepted by default (P0)

**Evidence**

- `services/inventory-service/app/core/config.py`: `whatsapp_app_secret: str | None = None`.
- `services/inventory-service/app/services/whatsapp_service.py:216`:
  ```python
  secret = get_settings().whatsapp_app_secret
  if not secret:
      return True          # signature check skipped entirely
  ```
- `POST /api/v1/whatsapp/webhook` has no authentication dependency, no rate
  limit, and no body-size cap.

**Impact**

Anyone who can reach the Inventory host can POST a fabricated Meta payload. The
handler then:

- records supplier replies (`record_inbound_reply`) — poisoned procurement data;
- applies delivery-status callbacks by `wamid` — false "delivered/read/failed"
  states;
- can be used for storage/log amplification.

The `verify_token` check only protects the GET handshake, not POST delivery.

**Fix**

1. Make `whatsapp_app_secret` **mandatory** in `staging`/`prod` (startup
   validation), and change `verify_signature` to return `False` when no secret is
   configured in those environments.
2. Add a Traefik rate limit and `maxRequestBodyBytes` on the webhook route.
3. Deduplicate inbound messages by `provider_message_id` and status by `wamid`
   (idempotency), so replayed signed payloads are harmless.
4. Optionally restrict source IPs to Meta's published ranges — treat this as an
   extra layer, not a replacement for the HMAC.

---

### SEC-05 — Mobile client: cleartext HTTP + secrets in logs (P0)

**Evidence**

- `apps/restaurant_app/lib/config/api_config.dart`:
  ```dart
  static const identityServiceBaseUrl = 'http://localhost:8009/api/v1';
  static const inventoryServiceBaseUrl = 'http://localhost:8100/api/v1';
  static const posServiceBaseUrl = 'http://localhost:8200/api/v1';
  ```
- `apps/restaurant_app/android/app/src/main/AndroidManifest.xml`:
  `android:usesCleartextTraffic="true"` in the **main** manifest (applies to
  release builds).
- `apps/restaurant_app/lib/auth/api_log_interceptor.dart` logs the full request
  body and full response body via `debugPrint`. `ApiLogInterceptor` is registered
  unconditionally in `auth_provider.dart`, `pos_api_provider.dart`, and
  `inventory_api_provider.dart`.
- Login/OTP request bodies contain the password and OTP; `TokenResponse`
  contains the access and refresh tokens.
- `apps/restaurant_app/android/app/build.gradle*` uses
  `signingConfig = signingConfigs.getByName("debug")` for release builds.

**Impact**

- Any device log collector, crash reporter, or `adb logcat` session captures
  passwords, OTPs, and bearer/refresh tokens.
- With `usesCleartextTraffic=true`, an operator can point the app at an
  `http://` host (or be downgraded) and expose credentials on the wire.
- Debug-signed release APKs cannot be securely distributed/updated.

**Fix**

1. Make the base URLs compile-time configurable and HTTPS-only:
   ```dart
   static const identityServiceBaseUrl = String.fromEnvironment(
     'IDENTITY_BASE_URL',
     defaultValue: 'http://10.0.2.2:8009/api/v1', // emulator only
   );
   ```
   Build release with `--dart-define=IDENTITY_BASE_URL=https://auth.example.com/api/v1`.
2. Remove `android:usesCleartextTraffic="true"` from the main manifest. If local
   HTTP is still needed, put it in `android/app/src/debug/AndroidManifest.xml`
   only.
3. Gate `ApiLogInterceptor` behind `kDebugMode`, and redact
   `Authorization`, `Cookie`, `password`, `code`, `refresh_token`,
   `access_token` before logging. Never log response bodies for auth routes.
4. Configure a real release signing key (keystore outside the repo, injected by
   CI), and enable `minifyEnabled`/`shrinkResources`.
5. Consider certificate pinning (or at least a network-security config that only
   trusts system CAs) once the production domains are stable.

---

### SEC-06 — Email/phone change without verification → account takeover (P0)

**Evidence**

`services/identity-service/app/api/v1/endpoints/me.py` (`PATCH /api/v1/users/me`):

```python
if "email" in body.model_fields_set:
    ...
    user.email = body.email          # no OTP, no re-auth, no flag reset

if "phone" in body.model_fields_set:
    ...
    if body.phone != user.phone:
        user.is_phone_verified = False
    user.phone = body.phone          # no OTP, no re-auth
```

`UpdateProfileRequest` requires only `full_name`, `email`, and `phone`.

**Impact**

An attacker holding a short-lived access token (stolen device, logged-in shared
terminal) can change the account's login identifier to one they control. They
then use the normal OTP flow to obtain a fresh refresh token, and keep access
even after the victim changes their password. Email is not marked unverified at
all, so the new address is immediately usable as a login identifier.

**Fix**

1. Split profile updates into:
   - `PATCH /me` — `full_name` only (safe).
   - `POST /me/email/change/request` + `/verify` — send an OTP to the **new**
     address, require the **current password** (or a fresh OTP to the current
     identifier) before switching, then set `is_email_verified=True` only after
     verification.
   - Same for phone.
2. On any identifier change, revoke all other sessions and refresh tokens.
3. Rate-limit the change endpoints and record an auth risk event.
4. Do not allow changing the identifier to an address/number already in use
   (already checked) and do not reveal which one it is beyond the 409.

---

### SEC-07 — No MFA for platform staff; admin surface public (P1)

**Evidence**

- `services/identity-service/app/api/v1/endpoints/platform_auth.py`: the
  `/mfa/verify` endpoint returns `501 NOT_IMPLEMENTED`.
- Admin routes (`/api/v1/admin/*`, `/api/v1/auth/platform/*`) are served on the
  same host as the public API and have no IP allowlist or separate hostname.
- Platform-staff passwords are strong (12+ chars), but a single phished password
  yields full platform administration.

**Impact**

Admin takeover = access to all businesses, users, RBAC definitions, and
potentially the ability to grant `*` permissions.

**Fix (interim, before code change)**

- Route `/api/v1/admin/*` and `/api/v1/auth/platform/*` through a Traefik
  `ipAllowList` restricted to the office IP / VPN / Tailscale range.
- Add a strict rate limit and alert on any 401/403 burst against those paths.
- Do not enable the admin dashboard on a public hostname.

**Fix (proper)**

- Implement TOTP (RFC 6238) with recovery codes, enforced for
  `user_category=platform_staff`; store the secret encrypted; require
  re-authentication for sensitive actions (RBAC changes, user deactivation).
- Add step-up authentication for `groups.*`, `roles.*`, and
  `platform_roles.*` permission changes.

---

### SEC-08 — No network segmentation or edge tier (P1)

**Evidence**

- There is no root compose/Traefik configuration; each service has its own
  compose project and network.
- Apps publish ports `8009`, `8100`, `8200` on the host.
- Every Dockerfile starts uvicorn with
  `--proxy-headers --forwarded-allow-ips "*"`. Behind Traefik this is correct,
  but if an API port is reachable directly, a client can forge
  `X-Forwarded-For` and rotate the per-IP rate-limit key.
- `services/pos-service/app/core/config.py` defaults:
  `inventory_service_url = "http://localhost:8100/api/v1"` and
  `identity_service_url = "http://localhost:8009/api/v1"` — inside a container
  these point at the container itself, not the peer service.
- `INVENTORY_SERVICE_URL` / `IDENTITY_SERVICE_URL` are absent from
  `.env.example`.

**Impact**

- Traffic cannot be routed cleanly by Traefik across three separate projects
  without an external network, and the intended internal calls fail or are
  misconfigured.
- Every service port is reachable directly, bypassing Traefik's TLS, headers,
  rate limits, and IP rules.
- Operators will be tempted to expose DB ports to make cross-project calls work.

**Fix**

Adopt a single root compose project with:
- `edge` network: Traefik + the three API containers only;
- `data` network (`internal: true`): APIs + PostgreSQL + Redis;
- `socket` network: Traefik + a read-only Docker socket proxy;
- no `ports:` on APIs or data stores — `expose:` only; Traefik reaches APIs by
  service name on `edge`;
- POS → Inventory via `http://inventory:8100/api/v1`;
- POS → Identity via `http://identity:8000/api/v1`.

The full topology is in `docs/deployment/PRODUCTION_DEPLOYMENT.md`.

---

### SEC-09 — Secret sprawl; provider keys injected into DB containers (P1)

**Evidence**

- `services/identity-service/.env` contains live Africa's Talking and Brevo API
  keys (non-empty, 77 and 89 chars). The file is correctly gitignored, but it is
  a plain-text file on a developer machine.
- In `services/identity-service/docker-compose.yml`, the `postgres` service also
  declares `env_file: ./.env`, so **AT_API_KEY and BREVO_API_KEY are injected
  into the PostgreSQL container** even though it has no use for them.
- Secrets are passed as environment variables, readable by anything in the
  `docker` group via `docker inspect`.
- `scripts/*.py` embed default credentials (`oryonfoods:oryonfoods`).

**Impact**

Least-privilege violation: a compromise of the database container (or any
process able to read its environment) yields third-party API credentials.
`.env` files are easy to accidentally copy into backups, support bundles, or
chat.

**Fix**

1. Remove `env_file` from `postgres`/`redis`; give them only the variables they
   need (`POSTGRES_*`, `REDIS_*`).
2. Use Docker Compose `secrets:` for:
   - `jwt_private.pem` / `jwt_public.pem` (mode `0400`);
   - PostgreSQL superuser and per-service passwords;
   - `INTERNAL_SERVICE_TOKEN`;
   - provider API keys (or keep them in the identity-only env file, 600 root).
3. Store host secret files under `/opt/oryonfoods/secrets` with `700` directory
   and `600` files, owned by `root:root`; deploy as a user that is **not** in the
   `docker` group unless necessary (note: docker group ≈ root).
4. Rotate the AT/Brevo keys before go-live since they have lived in plaintext.
5. Never pass `--env-file` from the repository; use
   `docker compose --env-file /opt/oryonfoods/secrets/compose.env`.
6. Remove default credentials from any script that could run in production, or
   make the scripts refuse to run unless the target host is localhost.

---

### SEC-10 — Rate-limiting gaps and no bot defense (P1)

**Evidence**

- `services/identity-service/app/core/rate_limit.py`:
  ```python
  count = await r.incr(key)
  if count == 1:
      await r.expire(key, window_seconds)
  ```
  Two round-trips, not atomic. If the process dies between `INCR` and `EXPIRE`,
  the key never expires and the identifier is locked out forever.
- Fixed window (no sliding window), so a burst can straddle a boundary.
- Per-IP keys use `request.client.host`, which is trustworthy only because
  uvicorn trusts `X-Forwarded-For` (`--forwarded-allow-ips "*"`). If an API port
  is reachable directly, the header can be spoofed to rotate the key.
- No limits on `/auth/register`, `/auth/otp/verify`,
  `/auth/otp/email/verify`, `/auth/password/reset/confirm`,
  `/auth/context/switch*`, or the WhatsApp webhook.
- OTP request endpoints send SMS/email; without CAPTCHA/bot defense, an attacker
  can burn SMS credits and spam arbitrary numbers (SMS bombing), even within
  the per-phone/per-IP limits.
- If Redis is down, `get_redis()` raises and every auth endpoint returns 500
  rather than a controlled 503.

**Fix**

1. Replace `INCR` + `EXPIRE` with a single Lua script (or `SET NX EX` +
   `INCR`-with-TTL pattern) so the TTL is always set.
2. Use a sliding-window or token-bucket limiter for auth endpoints.
3. Add a global per-IP limit at Traefik (e.g. 300 req/min, burst 600) and a
   stricter `auth` router limit (e.g. 30 req/min).
4. Add per-IP and per-identifier limits to every state-changing auth endpoint,
   including verification/confirm endpoints.
5. Add a CAPTCHA/Turnstile challenge (or proof-of-work) to OTP/email request
   endpoints, and alert when SMS/email spend exceeds a daily threshold.
6. Wrap Redis calls with timeouts and a circuit breaker; return `503` with
   `Retry-After` when the limiter is unavailable, and decide explicitly whether
   auth fails open or closed (fail closed for login/OTP).
7. Stop publishing the API ports so `X-Forwarded-For` can only come from Traefik.

---

### SEC-11 — Refresh-token replay does not revoke the token family (P1)

**Evidence**

`services/identity-service/app/services/session_service.py` detects reuse:

```python
if old.replaced_by_token_id is not None:
    logger.warning("refresh_token_replay_detected", ...)
    await publish_event("auth:refresh_token_replay", ...)
    raise TokenReuseDetectedError(...)
```

It raises, but does **not** revoke the family (`old.family_id`) or the active
`UserSession`. The legitimate user's newest token remains valid, and so does the
attacker's if they hold it.

**Impact**

The standard benefit of rotation — detecting theft and cutting off the attacker —
is lost. A stolen refresh token can be used until it expires (7 days) or is
manually revoked.

**Fix**

On `TokenReuseDetectedError`:

1. Revoke **all** `RefreshToken` rows with the same `family_id`.
2. Deactivate the associated `UserSession`.
3. Record a `CRITICAL` risk event (already done) and notify the user by
   email/SMS.
4. Return 401 and require a fresh login.

Also document the accepted tradeoff that access tokens remain valid until their
15-minute expiry after logout. If immediate revocation is required, add a
`jti` deny-list in Redis checked by resource services (at the cost of a Redis
round-trip per request).

---

### SEC-12 — JWT lacks `iss`/`aud`/`kid`; no rotation path (P1)

**Evidence**

`services/identity-service/app/core/security.py`: payload has `sub`, `type`,
`iat`, `exp`, category claims; no `iss`, `aud`, `jti`. Verification uses
`algorithms=[settings.jwt_algorithm]` and requires only `exp`, `iat`, `type`.
No key ID header. Resource services load a single public key from disk.

**Impact**

- A token minted for one environment/service could be accepted by another if keys
  are ever shared (e.g. staging key copied to prod).
- Rotating the signing key requires a coordinated restart of all services; there
  is no overlap window or `kid`-based selection.
- No per-token identifier to support revocation/audit.

**Fix**

1. Add `iss = "https://auth.example.com"`, `aud = "oryonfoods-api"`, and a
   random `jti` to access tokens.
2. Verify `iss`/`aud` in all services (config-driven, required in prod).
3. Put `kid` in the JWT header and support a small key set (`kid -> public key`)
   in the resource services; publish new keys before switching signing.
4. Pin `RS256` explicitly; never accept `none` or HMAC algorithms.
5. Document and rehearse the rotation runbook (see deployment guide).

---

### SEC-13 — Readiness endpoint public and leaks connections (P1)

**Evidence**

- `services/identity-service/app/routers/health.py`:
  - `/health/ready` is unauthenticated and returns `database`/`redis` status.
  - It calls `aioredis.from_url(...)` on **every request** and only closes on
    success (an exception leaks the client).
- The compose health check only uses `/health`, but Traefik will route
  `/health/ready` publicly unless blocked.

**Impact**

- Infrastructure state disclosure (DB/Redis up/down) to unauthenticated users.
- A cheap request can create a new Redis connection each time → connection
  exhaustion / DoS against Redis.
- During a DB outage, every readiness probe adds load and log noise.

**Fix**

1. Block `/health/ready`, `/docs`, `/redoc`, `/openapi.json` at Traefik with a
   `deny-all` middleware (or an IP allowlist for operators).
2. Reuse the shared Redis client (`app.core.redis_client.get_redis`) instead of
   creating a new one per request; cache the readiness result for 5–10 seconds.
3. Keep `/health` as a pure liveness probe with no dependency calls.

---

### SEC-14 — WhatsApp tokens plaintext at rest; verify token disclosed (P1)

**Evidence**

- `services/inventory-service/app/models/whatsapp.py` stores `access_token` and
  `verify_token` as ordinary columns (no encryption).
- `connection_public_view` returns `verify_token` in full to any caller with
  `procurement.view`.
- `access_token` is only masked in the response, but the DB/backup contains it in
  clear text.

**Impact**

A database dump, stolen backup, or SQL-injection-class bug yields long-lived Meta
access tokens that can send messages as the business and read its WhatsApp
traffic. The verify token allows webhook handshake impersonation.

**Fix**

1. Encrypt `access_token` (and `verify_token`) at the application layer with an
   envelope key (e.g. `cryptography.fernet` with a key from a secret file), or
   use `pgcrypto` with a KMS-held key. Store a key version for rotation.
2. Stop returning `verify_token` after initial setup; show it only once, or
   require a `procurement.create` + re-auth action to reveal it.
3. Exclude these columns from analytics/reporting queries and logs.
4. Rotate any tokens that have already been stored in plaintext before go-live.

---

### SEC-15 — No audit trail for platform-admin actions (P1)

**Evidence**

- Business-level audit events exist (`app/services/audit_events.py`), and auth
  risk events are recorded.
- Admin RBAC/user endpoints (`admin/internal_rbac.py`, `admin/users.py`) mutate
  groups, roles, permissions, user categories, and activation state without an
  equivalent immutable audit record. `publish_event` in Identity is a no-op stub.

**Impact**

After an incident, there is no reliable record of who granted `*`, who changed a
user's category, or when an admin was created. This also undermines insider-threat
investigation and regulatory accountability.

**Fix**

1. Write an append-only `admin_audit_log` row for every mutation: actor id, action,
   target type/id, before/after (redacted), IP, user agent, timestamp, request id.
2. Ship the audit log to offsite/WORM storage (or at least a separate retention
   bucket) so a compromised app cannot erase it.
3. Alert on high-risk changes (new platform admin, `*` grant, category change).
4. Implement the `publish_event` stub or write directly to the table.

---

### SEC-31 — Deactivated/suspended users can still log in and refresh (P1)

**Evidence**

- `app/api/v1/endpoints/admin/users.py` deactivates a user by setting
  `user.is_active = False` and reactivates with `True`; it does **not** revoke
  the user's sessions.
- `app/api/v1/endpoints/auth.py` login paths (`login_password`,
  `otp/verify`, `otp/email/verify`, `password/reset/confirm`) and `refresh`
  load the user but never check `is_active` or `status`.
- `app/deps/auth.py` `get_current_user` also only checks existence, not
  `is_active`/`status`.
- The resource services trust the JWT claims and have no DB lookup, which is
  expected — but it means a blocked user keeps working until the access token
  expires.

**Impact**

An account that an administrator has deactivated or suspended can log in again
with its password/OTP and rotate refresh tokens indefinitely. Deactivation is
effectively advisory after the current access token expires. This breaks the
primary containment action during an insider-threat or account-compromise
incident.

**Fix**

1. In every login/refresh path, reject when `user.is_active is False` or
   `user.status in {SUSPENDED, LOCKED}` (use the same generic 401 as bad
   credentials to avoid enumeration).
2. On deactivation/suspension, revoke all refresh tokens and active sessions
   (`revoke_all_sessions_for_user`).
3. Optionally add a `token_version` / `security_stamp` claim to the access token
   and check it in resource services (Redis or short-lived cache) if you need
   immediate revocation instead of the 15-minute window.
4. Add an admin audit entry for every activation change (SEC-15).

---

### SEC-32 — Protected/owner roles can be assigned by any staff-manager (P1)

**Evidence**

- `app/api/v1/endpoints/business_rbac.py` `assign_staff_role` (the
  `POST /{business_id}/staff` endpoint) requires only
  `USER_BUSINESS_ROLES_ASSIGN`. It loads the role, checks that it belongs to the
  business, and that the target user is `BUSINESS_STAFF` — but never checks
  `role.is_protected`, never compares the role's permissions with the actor's,
  and never blocks self-assignment.
- The Owner role is seeded with `is_protected=True`
  (`app/services/business_service.py`, from `is_owner_template` in
  `app/db/seed_role_templates.py`). Protected roles are guarded only on
  **update** and **delete** (`business_rbac.py` lines 137 and 184). Assignment
  is unguarded.
- `app/api/v1/endpoints/stores.py` `assign_store_staff`
  (`POST /{business_id}/stores/{store_id}/staff`) has the same gap: it requires
  `USER_STORE_ROLES_ASSIGN` but accepts any business role, including protected
  ones, with no hierarchy check.
- `assign_role_permission` (`business_rbac.py`,
  `POST /{business_id}/roles/{role_id}/permissions`) requires
  `BUSINESS_ROLES_MANAGE_PERMISSIONS` but does not verify that the actor already
  holds the permission being granted, nor that the target role is below the
  actor's own. Combined with role creation, a manager can build an
  owner-equivalent role out of individual permission codes without ever
  touching a protected role.
- Permissions are resolved into the JWT claims at token issuance, so an
  escalation becomes effective on the attacker's next login/refresh and is then
  trusted by the inventory and POS services.

**Impact**

Vertical privilege escalation inside a tenant: a staff manager (or any staff
account that has been given role-assignment rights) can grant themselves — or a
colluding account — the Owner role or an equivalent set of permissions. From
there they can manage staff and stores, change settings, and reach any
finance/refund/export capability the owner has. The same primitive allows
persistence: assigning a role to a second account survives removal of the
attacker's own role. It also defeats the purpose of `is_protected` and makes
role changes unattributable without an audit log (SEC-15).

**Exploit chain (three requests)**

1. `POST /api/v1/businesses/{business_id}/staff`
   `{"user_id": "<self>", "business_role_id": "<owner_role_id>"}` — succeeds
   because the actor is `BUSINESS_STAFF` and holds
   `user_business_roles.assign`.
2. `POST /api/v1/auth/refresh` — the new access token is minted with the Owner
   role's permissions.
3. Call any owner-only endpoint; inventory/POS accept the token because they
   trust the claims.

An equivalent chain is: create an unprotected role
(`business_roles.create`), add every permission code to it
(`business_roles.manage_permissions`), assign it to self, refresh.

**Fix**

1. Reject assignment of a protected role through the normal staff endpoints.
   Ownership transfer must be a separate, explicitly audited, step-up
   (re-authentication/MFA) operation that also demotes the previous owner.
2. Enforce "you can only grant what you have": resolve the actor's effective
   permission set and require it to be a superset of the target role's
   permissions; require the actor's highest role to outrank the target role;
   forbid changing your own assignments (other than the ownership-transfer
   flow).
3. Apply the same rule to `assign_role_permission` / `remove_role_permission`:
   deny modifying protected roles, require the actor to already hold the
   permission being added, and deny removing permissions from roles at or above
   the actor.
4. Recompute authorization after role changes: bump a `token_version` /
   `security_stamp` or revoke the affected users' refresh tokens, so a
   demotion takes effect immediately instead of at the next natural refresh
   (pairs with SEC-31).
5. Audit every role/permission assignment (actor, target, before/after) and
   alert on owner-role assignment or bulk permission grants (SEC-15).
6. Add regression tests: staff-manager cannot assign the owner role, cannot
   grant a permission they lack, cannot escalate their own role; owner can
   transfer ownership only through the dedicated endpoint.

---

### SEC-16 — Weak business password policy; no breach check/MFA (P2)

**Evidence**

`services/identity-service/app/schemas/validators.py`:
`BusinessPassword` requires only 8 characters, one letter, one digit. Platform
passwords are stronger (12+, mixed, denylist) but business owners are the largest
user population and can manage money/inventory.

**Fix**

- Raise to 10–12 chars, check against a breached-password list (HIBP
  k-anonymity API or a bundled list), and add zxcvbn-style scoring.
- Offer TOTP MFA for business owners/admins; require it for `stores.switch`,
  refunds/voids, and finance exports.
- Add a "new device/location" notification on login.

---

### SEC-17 — Unverified registration receives full tokens; enumeration (P2)

**Evidence**

- `POST /api/v1/auth/register` creates an `ACTIVE` user, sets
  `is_phone_verified=False`, then immediately returns `TokenResponse`.
- `POST /api/v1/businesses` requires only a valid token, so an unverified account
  can create a business.
- Registration returns `409` for an existing phone/email, which enumerates
  registered identifiers. Login messages are generic (good).

**Fix**

- Issue a restricted "onboarding" token until the phone/email is verified, or
  require OTP verification before returning a refresh token.
- Gate `POST /businesses` on `is_phone_verified` / `is_email_verified`.
- Make registration always return a generic `202`/`204` and send the OTP, or
  accept the enumeration tradeoff explicitly and rate-limit heavily.

---

### SEC-18 — No request-body size limits; unbounded JSON parsing (P2)

**Evidence**

- No app middleware limits body size. FastAPI/Starlette will read an arbitrarily
  large JSON body before validation.
- `RateLimitDependency` calls `await request.json()` in a dependency; malformed
  JSON raises `JSONDecodeError` (500) and the body is parsed twice.
- Upload endpoints enforce `item_image_max_bytes` / `receipt_max_bytes`, but the
  spooled temp file grows until that check trips; a concurrent upload flood can
  fill the disk.

**Fix**

1. Add a Traefik `buffering` middleware with `maxRequestBodyBytes` (e.g. 1 MB for
   auth/general, 6 MB for upload routers).
2. Add a Starlette middleware that rejects `Content-Length` above a limit and
   caps streamed bodies.
3. Catch JSON parse errors in the rate-limit dependency (treat as 400, not 500).
4. Reserve disk headroom and alert at 80%; consider object storage for uploads.

---

### SEC-19 — Container/host hardening missing (P2)

**Evidence**

- Compose services have no `cap_drop`, `read_only`, `no-new-privileges`,
  `pids_limit`, memory/CPU limits, or log rotation.
- Images run as non-root (good) but with a writable root filesystem and default
  capabilities.
- Traefik (when added) needs the Docker socket; mounting it read-only still gives
  effective root-equivalent control to a compromised Traefik unless a socket
  proxy is used.
- No host hardening (SSH, UFW, unattended upgrades, fail2ban) is encoded anywhere.

**Fix**

- Per-container: `security_opt: ["no-new-privileges:true"]`,
  `cap_drop: ["ALL"]`, `read_only: true` + `tmpfs: ["/tmp"]` for APIs,
  `pids_limit`, `mem_limit`, `cpus`, `logging` with `max-size`/`max-file`.
- Use a Docker socket proxy (`tecnativa/docker-socket-proxy`) with
  `POST=0`, and keep secrets out of container env (socket inspect can read env).
- Apply the host baseline in the deployment guide (SSH keys only, UFW +
  `DOCKER-USER`, unattended upgrades, fail2ban, sysctl, time sync).

---

### SEC-20 — Supply chain (P2)

- Base images use mutable tags (`python:3.12-slim-bookworm`,
  `postgres:16-alpine`, `redis:7-alpine`). Pin by digest.
- No image scanning, SBOM, or signature verification in any pipeline.
- `requirements.txt` is stale relative to `pyproject.toml`/`uv.lock`; builds use
  `uv.lock` (`--frozen`), which is good, but the duplicate file invites drift.
- `python:3.12-slim` has no `apt` upgrade layer pinning; rebuild regularly.

**Fix**

- Pin digests, run Trivy/Grype on every build (`--severity HIGH,CRITICAL`),
  generate an SBOM (Syft), and sign images (cosign) if using a registry.
- Delete `requirements.txt` or generate it from the lock; make CI fail if they
  differ.
- Enable Renovate/Dependabot for base images and Python deps; rebuild weekly even
  without code changes.

---

### SEC-21 — Observability and PII in logs (P2)

**Evidence**

- `console` SMS/email providers log the full OTP message (`sms_console_send`
  includes `message=...`).
- `auth.py` logs `phone=`/`email=` on delivery failures.
- POS `publish_event` logs the full event payload at INFO.
- No access-log shipping, metrics, alerting, or retention policy is configured.
- `structlog` JSON output is good, but there is no request ID correlation.

**Fix**

- Never enable console providers outside local; enforce via startup validation.
- Redact phone/email (keep a hash or last 4 digits) and all token/code fields.
- Add request IDs (middleware) and propagate to Traefik logs.
- Ship Traefik + app logs to a retained store (Loki/Vector/CloudWatch/B2);
  define 30–90 day retention (longer for audit/finance, subject to PDPA).
- Alert on 5xx rate, 401/403 bursts, 429 spikes, container restarts, disk/memory,
  certificate expiry, and backup age.

---

### SEC-22 — Single VPS SPOF; no PITR; volumes not backed up (P2)

**Evidence**

- All three databases, Redis, APIs, and (soon) Traefik would share one VPS.
- No backup scripts, no WAL archiving, no restore documentation.
- Uploads are local volumes (`item_images`, `receipts`); a DB dump alone is not a
  complete backup (the code comments acknowledge this).
- Hostinger snapshots (if enabled) are provider-side and not a substitute for
  offsite, tested backups.

**Fix**

See the deployment guide for the full backup/DR design. Minimum:

- Nightly `pg_dump -Fc` per database + `pg_dumpall --globals-only`, encrypted and
  uploaded offsite (restic/rclone to B2/R2/S3), 7 daily / 4 weekly / 12 monthly.
- WAL archiving (`wal-g`/`pgBackRest`) for RPO ≤ 5 minutes on financial data.
- Back up upload volumes with restic; restore them alongside the DB.
- Quarterly restore drill into an isolated environment; record RTO/RPO actuals.
- Low DNS TTL (300s) and a documented rebuild runbook.

---

### SEC-23 — Bootstrap, migrations, and seeds (P2)

**Evidence**

- There is no script or endpoint to create the **first** platform admin.
  `seed_internal_rbac.py` creates groups/roles only; `platform/register` requires
  an existing admin token → chicken-and-egg.
- Migrations are manual (`docker compose exec api alembic upgrade head`).
- `scripts/seed_*.py` call `SQLModel.metadata.create_all()` before seeding, which
  can create tables outside Alembic and cause schema drift in production.

**Fix**

- Provide a one-off, audited `create_platform_admin.py` (reads a password from
  stdin/secret, refuses to run if an admin exists), run once during bootstrap,
  then remove from the image or gate it behind a CLI flag.
- Run `alembic upgrade head` as an explicit deploy step **after** a verified
  backup; fail the deploy if `alembic current`/`heads` is inconsistent.
- Make seeds not call `create_all` in prod (or guard with
  `if environment in {"local","dev"}`); run seeds only after migrations.
- Add a smoke test after deploy (health, login, one authenticated read).

---

### SEC-24 — CORS/header wildcards; no security headers (P2)

**Evidence**

- `main.py` uses `allow_methods=["*"]`, `allow_headers=["*"]` with
  `allow_credentials=True`; origins come from a comma-separated string with no
  validation (a `*` would be accepted by config parsing).
- No HSTS, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`, or
  frame options at the app; Traefik is not yet configured to add them.

**Fix**

- Validate `cors_allowed_origins`: no `*` when credentials are enabled; require
  `https://` in prod.
- Restrict methods/headers to what the clients actually use (`GET, POST, PATCH,
  PUT, DELETE, OPTIONS`; `Authorization, Content-Type, Accept-Language`).
- Add security headers at Traefik (single place) and keep the app free of
  duplication.
- If the admin dashboard is browser-based, add a CSP suited to it; APIs don't
  need a permissive CSP.

---

### SEC-25 — Information disclosure (P3)

- `/health/ready` returns dependency status (see SEC-13).
- `GET /api/v1/businesses/{uuid}/exists` is a public existence probe. The UUID is
  unguessable, but it confirms a tenant to anyone who obtains an id (e.g. from a
  support ticket). Acceptable for the offline-wipe flow; document it.
- API version `0.1.0` and the OpenAPI schema are exposed if `ENVIRONMENT` is not
  `prod` (see SEC-02).
- `Server`/`X-Powered-By` headers should be stripped at Traefik.

**Fix:** block docs/readiness at the edge, remove version banners, and document
the existence probe as an accepted tradeoff.

---

### SEC-26 — OTP/rate-limit edge cases (P3)

- In `verify_otp`, the exhausted-attempt branch increments `code.attempts` and
  then raises; the transaction rolls back, so the increment is lost. The cap
  still holds because `attempts >= max` remains true, but the audit count is
  inaccurate.
- Fixed-window limiter race (see SEC-10).
- `body_field_source` parses JSON before schema validation; malformed input
  becomes a 500.
- `hash_refresh_token` exists twice (bcrypt in `core/security.py`, SHA-256 in
  `session_service.py`); only the SHA-256 one is used. Remove the unused bcrypt
  variant to avoid future misuse (bcrypt truncates at 72 bytes).

**Fix:** commit the attempt increment before raising (or use a separate update),
use the Lua limiter, catch JSON errors, and delete dead code.

---

### SEC-27 — Password hashing (P3)

bcrypt cost 12 is reasonable. Note bcrypt's 72-byte input truncation and lack of
memory hardness. Consider Argon2id (`argon2-cffi`) for new hashes with a
rehash-on-login migration. Add a server-side pepper stored in a secret if you
want defense against DB-only leaks.

---

### SEC-28 — Dev tooling with default credentials (P3)

- Identity compose includes `pgadmin` (`dpage/pgadmin4:latest`) with
  `PGADMIN_DEFAULT_PASSWORD: oryonfoods` under the `dev` profile.
- Root `scripts/*.py` default to `oryonfoods:oryonfoods` on localhost.

**Fix:** never enable the `dev` profile on the VPS; keep these files out of
production images; make scripts refuse non-localhost targets unless explicitly
overridden.

---

### SEC-29 — Public key distribution (P3)

`services/pos-service/keys/public.pem` is tracked in git. A public key is not a
secret, but production distribution should be deliberate: mount the current
Identity public key into Inventory/POS at deploy time, version it, and update it
as part of key rotation. Do not rely on a checked-in copy staying in sync.

---

### SEC-30 — Dev compose files are not a production topology (P3)

The three compose files are development harnesses: published DB ports, default
passwords, bind-mounted source, a `tail -f` dev container, and pgAdmin. Do not
copy them to the VPS. Use the root production compose described in the
deployment guide.

---

## 5. Application security review by domain

### Authentication and sessions

**Strengths:** RS256, 15-minute access tokens, opaque 48-byte refresh tokens
hashed with SHA-256, rotation, reuse detection, per-device sessions, generic
login errors, OTP hashing with bcrypt, 5-minute expiry, 5-attempt cap,
constant-time comparisons for the internal service token and WhatsApp verify
token.

**Gaps:** no MFA, no identifier-change verification, no family revocation on
replay, no `iss`/`aud`/`jti`, access tokens valid until expiry after logout,
login attempts recorded but never used for lockout (only rate limits), weak
business password policy, unverified registration gets full tokens.

### Authorization and tenancy

**Strengths:** shared dependencies bind `active_business_id` and
`active_store_id` to path parameters; store-pinned tokens cannot read/write
another store; list/report queries are pinned; cross-tenant reads return 404
rather than confirming existence; admin routes require both category and
permission.

**Gaps:** business owners hold `*` (intended, but a compromised owner token is
total tenant compromise); no step-up auth for destructive actions; no audit of
admin RBAC changes; no field-level restrictions on user category changes
(an admin can promote a business user to platform staff — intended but should be
audited/alerted).

### Input handling and uploads

**Strengths:** Pydantic validation, phone normalization, magic-byte checks,
size caps, path traversal guard, no raw SQL/string interpolation found, ORM
parameterization, UUID path params.

**Gaps:** no body-size limit, JSON parse in rate-limit dependency, PDFs accepted
for receipts (served as attachment — good), no antivirus/CLAMAV scan (consider
for user uploads), `original_filename` sanitized.

### Cryptography and secrets

**Strengths:** RS256, bcrypt 12, SHA-256 for refresh tokens, `secrets` module for
OTP/refresh generation, HMAC constant-time compare for webhooks, TLS-ready
structure.

**Gaps:** private key in image, plaintext WhatsApp tokens, secrets in env,
no key rotation path, no envelope encryption for at-rest sensitive columns,
DB/backup encryption not specified.

### Client

**Strengths:** secure storage for tokens, encrypted local DB, offline-first
design.

**Gaps:** cleartext HTTP, debug logging of secrets, debug signing, no pinning,
no jailbreak/root detection (optional), no screenshot protection for sensitive
screens (optional).

### Privacy/compliance (Tanzania PDPA 2022)

The system processes phone numbers, names, emails, customer data, and financial
records. Before launch:

- Document lawful basis and a privacy notice; collect only what is needed.
- Define retention for auth events, login attempts, receipts, and customer data.
- Encrypt backups and restrict access; log access to production data.
- Have a breach-response plan with notification to the PDPC and affected data
  subjects without undue delay (confirm specifics with counsel).
- Check cross-border transfer rules if the VPS/backups are outside Tanzania
  (Hostinger data-center location matters).
- Register as a data controller/processor if required by the Act/regulations.

---

## 6. Production readiness gaps (operational)

These are not vulnerabilities but will cause incidents:

1. **No CI/CD.** No workflow builds/tests/scans images; deploys are manual.
2. **No staging environment.** Migrations and Traefik changes are tested in prod.
3. **No migration gate.** The app never checks schema version; `/health` is green
   even when tables are missing (README explicitly warns).
4. **No first-admin bootstrap.** See SEC-23.
5. **No backup/restore evidence.** No job, no retention, no drill.
6. **No observability.** No metrics, no alerts, no log retention.
7. **No resource limits.** One runaway query/upload can OOM the VPS and take all
   three services down.
8. **No capacity plan.** Three PostgreSQL containers on a 4 GB VPS is tight;
   consolidate to one instance or size up.
9. **No runbooks.** Deploy, rollback, rotation, restore, and incident response are
   undocumented.
10. **No dependency update policy.** Security patches will lag.

---

## 7. Risk register

| Risk | Likelihood | Impact | Mitigation | Residual |
|------|-----------|--------|------------|----------|
| JWT key leak → forge any identity | Medium (image sharing) | Critical | SEC-01 + rotate | Low after fix |
| Public Postgres/Redis → data breach | High if deployed as-is | Critical | SEC-03 + firewall | Low |
| Admin account takeover | Medium | Critical | MFA + IP allowlist | Medium until MFA |
| OTP/SMS abuse → cost + spam | High | Medium | CAPTCHA + limits | Low |
| Account takeover via identifier change | Low–Medium | High | SEC-06 | Low |
| Staff privilege escalation via RBAC assignment | Medium | High | SEC-32 + audit log | Low after fix |
| Unsigned webhook injection | Medium | Medium | SEC-04 | Low |
| Ransomware/root compromise | Low | Critical | Host hardening + offsite immutable backups + rotation | Medium |
| Silent misconfiguration (prod defaults) | High | High | SEC-02 fail-fast | Low |
| Disk full from uploads/logs | Medium | High | Limits + rotation + alerts | Low |
| Single-VPS failure | Medium | High | Backups + rebuild runbook (+ standby) | Medium |

---

## 8. Remediation roadmap

### Phase 0 — Before any public DNS (1–2 days)

- [ ] Rotate JWT keys; fix `.dockerignore`/Dockerfile; verify no key in image.
- [ ] Rotate AT/Brevo keys; move secrets to root-owned files/Docker secrets.
- [ ] Add prod startup validation (SEC-02); set `ENVIRONMENT=prod`, `DEBUG=false`,
      `LOG_LEVEL=INFO`, real providers, real internal token, real CORS.
- [ ] Remove all DB/Redis published ports; generate strong passwords.
- [ ] Require WhatsApp app secret; fix `verify_signature`.
- [ ] Patch `PATCH /me` identifier changes.
- [ ] Enforce `is_active`/`status` at login and refresh; revoke sessions on
      deactivation.
- [ ] Block protected/owner role assignment and permission-granting escalation
      (SEC-32); add regression tests for both staff endpoints.
- [ ] Fix Flutter base URLs/logging/cleartext/signing.
- [ ] Block `/docs`, `/openapi.json`, `/health/ready`, `/api/v1/internal/*`,
      `/admin/*` at the edge.
- [ ] Host baseline: SSH keys only, UFW + `DOCKER-USER`, fail2ban,
      unattended-upgrades.

### Phase 1 — First production week

- [ ] Single root compose with `edge`/`data` networks; Traefik TLS + headers +
      rate limits + body limits + access logs.
- [ ] Backups (nightly dumps + volumes) to encrypted offsite; restore drill.
- [ ] Migration job + first-admin bootstrap + seed procedure.
- [ ] Health/metrics/alerting; log shipping; certificate-expiry alert.
- [ ] Redis auth + persistence decision; DB least-privilege roles.

### Phase 2 — First month

- [ ] Admin MFA + step-up auth; IP allowlist/VPN for admin.
- [ ] Refresh-family revocation; JWT `iss`/`aud`/`kid` + rotation runbook.
- [ ] Audit log for admin actions + alerts on `*` grants.
- [ ] Body-size middleware; JSON error handling; Lua rate limiter.
- [ ] Encrypt WhatsApp tokens; mask verify token.
- [ ] CI/CD with tests, image scan, SBOM, signed images.
- [ ] WAL archiving (RPO ≤ 5 min) and quarterly DR drill.

### Phase 3 — Ongoing

- [ ] Staging environment; dependency updates; quarterly access review.
- [ ] Move uploads to object storage; consider managed/separate Postgres.
- [ ] Penetration test and privacy review before scaling to many tenants.

---

## 9. Go/no-go checklist

A deployment is **not** ready to receive public traffic until every box is
checked:

- [ ] No private key or `.env` in any image (`docker run ... ls /app/keys`).
- [ ] `ENVIRONMENT=prod` boot fails on insecure settings.
- [ ] `nmap` from outside shows only 22/80/443 open.
- [ ] Postgres/Redis have strong auth and no published ports.
- [ ] Traefik serves valid TLS with HSTS; HTTP redirects to HTTPS.
- [ ] `/docs`, `/openapi.json`, `/health/ready`, `/admin/*`,
      `/api/v1/internal/*` are not publicly reachable.
- [ ] WhatsApp POST rejects a bad signature.
- [ ] Flutter release build uses HTTPS and logs no tokens/passwords.
- [ ] Backups ran, are encrypted, offsite, and a restore was verified.
- [ ] Alerts fire for down service, 5xx spike, disk > 80%, cert < 14 days,
      backup older than 26h.
- [ ] Admin accounts have MFA or are behind an IP allowlist/VPN.
- [ ] Runbooks exist for deploy, rollback, key rotation, restore, and incident
      response.

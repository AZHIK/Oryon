# Security Remediation Log

**Started:** 2026-10-21
**Scope:** Oryon Foods identity/inventory/pos services + Flutter client
**Reference:** [`SECURITY_AUDIT.md`](./SECURITY_AUDIT.md)

This log records what was actually changed, how it was verified, and what remains
open. It is intentionally separate from the audit so the original evidence stays
readable.

> Working-tree changes only — none of this has been committed or deployed yet.

---

## 1. Status summary

| Finding | Status | Notes |
|---|---|---|
| SEC-01 — JWT private key baked into image | **Fixed** | `.dockerignore` excludes `keys/`; Dockerfile fails the build if any `*.pem` reaches `/app/keys`. Verified with a real image build and filesystem inspection. |
| SEC-02 — Insecure production defaults | **Fixed** | All three services refuse to start when `ENVIRONMENT=prod` still has dev defaults (debug, console providers, default DB credentials, localhost CORS/URLs, weak internal token, missing WhatsApp secret). |
| SEC-03 — Public Postgres/Redis | **Fixed in package** | Dev compose ports are loopback-bound. The production package places Postgres/Redis on an internal-only network with no published ports; it still needs to be applied to the live VPS. |
| SEC-04 — Unsigned WhatsApp webhooks | **Fixed** | `verify_signature()` fails closed when no app secret is configured. Tests cover valid, invalid, missing header, and missing secret. |
| SEC-05 — Flutter cleartext + secret logging | **Fixed** | Release URLs require `--dart-define` HTTPS values; cleartext is debug-only; the log interceptor is debug-only and redacts credentials. |
| SEC-06 — Unverified email/phone change | **Fixed (backend)** | `PATCH /users/me` no longer changes identifiers. New two-step flows prove control of the new email/phone, require the current password, bind the destination in a signed token, are single-use, and revoke all sessions. Flutter now shows identifiers read-only until the change UI is built. |
| SEC-11 — Refresh replay does not revoke family | **Fixed** | Replay revokes every token in the rotation family and deactivates the user's sessions, committed before the 401. |
| SEC-12 — JWT lacks `iss`/`aud`/`kid` | **Fixed** | Access and identifier-change tokens now carry `jti`; production requires a shared issuer, audience, and key id. All three services verify them and reject unknown `kid`s. Production compose sets them consistently. |
| SEC-13 — Readiness endpoint / Redis churn | **Fixed in package** | Readiness reuses the shared Redis client and caches results for 5s. The deploy package denies `/health/ready`, `/docs`, `/openapi.json`, `/admin`, and `/api/v1/internal/*` at Traefik; it still needs to be applied to the live VPS. |
| SEC-31 — Disabled users can still log in/refresh | **Fixed** | Login, OTP, password reset, refresh, `_issue_tokens`, and `get_current_user` all reject `is_active=false` and `suspended`/`locked`; admin deactivation/update revokes sessions. |
| SEC-32 — Protected-role privilege escalation | **Fixed** | Protected roles cannot be assigned/edited/revoked; callers can only grant or revoke permissions they hold; self-assignment and cross-business role mutation are blocked. |

---

## 2. Changes by service

### Identity Service

- **Image (SEC-01):** `keys/` excluded from build context; build-time guard fails if
  key material is present. Runtime keys stay mounted at `/run/secrets/`.
- **Config (SEC-02):** `Settings` now has a `model_validator` that rejects insecure
  `prod` configurations with a consolidated error list.
- **Auth (SEC-31):** added `ensure_active_account`; called from password login, both
  OTP verifies, password reset, refresh, token issuance, and `get_current_user`.
  Admin deactivate/update calls `revoke_all_sessions_for_user`.
- **RBAC (SEC-32):** new `app/services/rbac_guard.py`; role assignment/permission
  endpoints enforce protected-role and “grant only what you hold” rules. Added the
  missing active-business-context check to role creation/update/delete/permission
  endpoints and staff assignment.
- **Identifier change (SEC-06):**
  - `PATCH /api/v1/users/me` rejects changed `email`/`phone` with a pointer to the
    verification flow; unchanged values remain a valid no-op save.
  - `POST /api/v1/users/me/email/change/request` and
    `POST /api/v1/users/me/email/change/verify`
  - `POST /api/v1/users/me/phone/change/request` and
    `POST /api/v1/users/me/phone/change/verify`
  - `VerificationCodePurpose.EMAIL_CHANGE` / `PHONE_CHANGE`
  - signed, 10-minute change token (`create_identifier_change_token`) binding the
    destination to the account.
- **Refresh replay (SEC-11):** family revocation + session deactivation.
- **Health (SEC-13):** shared Redis client + 5-second readiness cache.

### Inventory Service

- **Config (SEC-02):** production validator rejects debug, default DB credentials,
  `TEST_DB_URL`, the default internal token, short tokens, localhost CORS, and a
  missing `WHATSAPP_APP_SECRET`.
- **Webhooks (SEC-04):** missing app secret now rejects every callback instead of
  accepting it.
- **Compose (SEC-03):** Postgres port bound to `127.0.0.1`.
- **Env example:** documented the required internal token, CORS, and WhatsApp secret.

### POS Service

- **Config (SEC-02):** production validator rejects debug, default DB credentials,
  weak internal token, localhost service URLs, and localhost CORS.
- **Compose (SEC-03):** Postgres port bound to `127.0.0.1`.
- **Env example:** documented service URLs and internal token.

### Flutter app

- **API configuration (SEC-05):** release builds must provide
  `IDENTITY_API_BASE_URL`, `INVENTORY_API_BASE_URL`, and `POS_API_BASE_URL` via
  `--dart-define`; non-HTTPS release URLs are rejected. Debug keeps the local
  docker-compose defaults.
- **Transport (SEC-05):** `android:usesCleartextTraffic` removed from the main
  manifest and scoped to the debug manifest.
- **Logging (SEC-05):** interceptor installed only in debug builds; JSON bodies are
  recursively redacted for password/token/secret/OTP/PIN keys; plain-text bodies are
  never printed.
- **Account settings (SEC-06):** email/phone fields are read-only with a note to
  contact support until the change-verification UI ships.

---

## 3. Verification performed

| Check | Result |
|---|---|
| Identity Service test suite | **401 passed** |
| Inventory Service test suite | **335 passed** |
| POS Service test suite | **226 passed** |
| Identity runtime image build | Passed; `/app/keys` absent, no `.env` in image |
| WhatsApp signature unit checks | Valid accepted; invalid/missing header/missing secret rejected |
| Production-config checks (all services) | Defaults rejected; explicit secure config accepted |
| `ruff check` on changed Python files | Clean |
| `flutter analyze` | No issues |
| Flutter widget tests | Not completed — long-running test command was interrupted by an environment restart |
| Production compose | `docker compose config -q` passed with rendered secrets and Traefik templates |
| Traefik templates | Static and dynamic YAML parsed successfully |
| Deploy scripts | `bash -n` and ShellCheck (`-x -P deploy/scripts`) passed |
| Runtime images | All three built from a clean context; UID/GID `10001`; `/app/keys` absent |
| Production JWT paths | All three images loaded the mounted public key from `/run/secrets/jwt_public.pem`; production settings validated |
| File-secret ownership | End-to-end stack: PostgreSQL init, migrations, seeds, admin creation, and all three APIs started with host-owned `0400` secrets |
| End-to-end auth | Platform login returned a token; Inventory and POS accepted it (403 business-context, not 401 signature failure) |
| Bootstrap script | Generated secrets, JWT keys, DB URLs, Redis config, and Traefik config in a throwaway deploy root |
| Postgres init script | Tested in a throwaway PostgreSQL 16 container: owner/runtime roles, all three databases, and runtime-role login |
| First-admin bootstrap | Tested twice against a temporary migrated/seeded database; second run was idempotent |
| CI workflows | YAML syntax validated and locally linted; not yet executed on GitHub Actions |

Commands used for the backend suites are in the team runbook; they require the dev
Postgres/Redis and a `*_test` database. The test databases are truncated by fixtures,
so never point `TEST_DB_URL` at production.

---

## 4. Still required before go-live

1. **Rotate the live Africa's Talking and Brevo credentials** currently present in
   the local Identity `.env`. They were never committed, but treat them as exposed
   if that file was ever copied off the machine.
2. **Apply the `deploy/` package to the VPS** (Traefik + socket proxy,
   `edge`/`data` networks, no published DB/Redis, Docker secrets, deny rules for
   `/health/ready`, `/docs`, `/openapi.json`, `/admin`, and
   `/api/v1/internal/*`). The package is complete and validated locally; CI also
   validates the compose file and scripts. This closes the remaining SEC-03,
   SEC-08, SEC-09, and SEC-13 work once deployed and smoke-tested on the host.
3. **Rotate the JWT signing key** once, after the runtime mount is in place.
4. **Add the identifier-change UI** in Flutter (request → OTP → verify) so users can
   change email/phone without support.
5. Continue with the remaining P1 findings: SEC-07 (platform MFA), SEC-10
   (rate-limit/bot gaps), SEC-14 (encrypt WhatsApp tokens at rest), SEC-15
   (admin audit trail).

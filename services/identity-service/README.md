# FoodLink Auth Service

Single sign-on identity / auth microservice for the FoodLink Africa platform.
Serves all 4 Flutter apps + the Next.js dashboard with token-based authentication,
OTP flows, session management, and role-based access control.

## Quick start

```bash
# 0. Install uv (one-time, if not already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 1. Copy environment config
cp .env.example .env

# 2. Generate JWT signing keys (one-time)
uv run python scripts/generate_keys.py

# 3. Start everything (Postgres + Redis + API)
docker compose up --build

# 4. Run migrations, then seed the database (see sections below) —
#    the app does NOT do this automatically on startup.

# 5. Verify health
curl http://localhost:8009/health
curl http://localhost:8009/health/ready

# 6. (Optional) pgAdmin + dev tools at http://localhost:5050
docker compose --profile dev up
```

> The `keys/` directory (RSA keypair for RS256 JWT signing) must exist locally
> before `docker compose up --build` — the Dockerfile copies it into the
> runtime image and will fail to build without it. Step 2 creates it.

> Migrations and seeding are manual, deliberate steps — the app never runs
> them on startup. Until you run them, endpoints that depend on permissions,
> role templates, or internal RBAC groups will fail with missing-table or
> empty-lookup errors; `/health` will still report healthy.

## Run migrations

```bash
# Get a shell inside the running API container
docker compose exec api alembic upgrade head

# To create a new migration after adding a model
docker compose exec api alembic revision --autogenerate -m "description"
```

## Seed the database

After migrations complete, run the seed scripts in order (each is idempotent):

### Seed commands

Run individually in order:
```bash
# 1. Seed permissions & default platform roles
docker compose exec api uv run python scripts/seed_permissions.py

# 2. Seed internal RBAC groups and roles
docker compose exec api uv run python scripts/seed_internal_rbac.py

# 3. Seed business role templates
docker compose exec api uv run python scripts/seed_role_templates.py
```

Or run all at once:
```bash
docker compose exec api-dev bash -c '
  uv run python scripts/seed_permissions.py &&
  uv run python scripts/seed_internal_rbac.py &&
  uv run python scripts/seed_role_templates.py
'
```

### What gets seeded

**Step 1: Permissions & Platform Roles**
- All `Permission` records from the `PermissionCode` enum across all domains:
  - Business operations: POS, inventory, procurement, AI forecasting
  - User & role management: users, business roles, role templates
  - Organization & store management
  - Auth & security: sessions, tokens, trusted devices
- 3 default **platform roles**: driver, consumer, admin (with their standard permission sets)

**Step 2: Internal RBAC Groups and Roles**
- Internal platform staff roles and groups for administrative operations
- Super Admin (full platform access)
- Admin groups for managing organizations, businesses, role templates, and internal users

**Step 3: Business Role Templates**
Pre-built **role templates** (Owner + non-owner roles) for each business type:

**Owner Templates** (auto-cloned when a new business is created):
- `restaurant_owner` — POS, inventory, procurement, AI forecasting, staff management
- `supplier_owner` — inventory, procurement, supplier pricing
- `farmer_owner` — inventory, farmer supply commitments
- `distributor_owner` — inventory, procurement, distribution
- `platform_operator_owner` — full platform + all business operation permissions

**Non-Owner Templates** (optional staff roles that can be assigned per business):
- **Restaurant**: Manager, Cashier, Kitchen Staff, Stock Controller
- **Supplier/Distributor**: Sales Admin, Warehouse Staff
- **Farmer**: Farm Coordinator

### Business role assignment flow

When a new business is registered, the identity service:
1. Clones the **owner template** matching that business type into a `BusinessRole` (protected, cannot be deleted)
2. Assigns the business owner to that cloned owner role
3. Optionally instantiates non-owner role templates for that business as custom `BusinessRole` rows

## Run tests & lint

> ⚠️ The suite **truncates every table**. It refuses to run unless the target
> database name ends in `_test`, so set `TEST_DB_URL` (see `.env.example`).
> The test database is created and migrated automatically.

The `api` service runs a production-minimal image without dev tooling.
For tests, linting, and type-checking, use the `api-dev` service:

```bash
# Start the dev service (one-time, --profile dev flag)
docker compose --profile dev up -d

# Get a shell with all tools available
docker compose exec api-dev bash
uv run pytest -v
uv run ruff check app tests
uv run ruff format --check app tests
uv run mypy app
```

To run directly on the host (if you have the dependencies installed):

```bash
# DB_URL points at the docker Postgres on localhost:5455
export TEST_DB_URL=postgresql+asyncpg://foodlink:foodlink@localhost:5455/foodlink_auth_test
uv run pytest
uv run ruff check app tests
uv run ruff format --check app tests
uv run mypy app
```

## OpenAPI docs

- Swagger UI: http://localhost:8009/docs
- ReDoc: http://localhost:8009/redoc

### Client generation

Once endpoints are stable, generate typed clients:

- **Dart/Flutter**: `dart run build_runner build` with `openapi_generator` or use
  [openapi-generator](https://openapi-generator.tech) with the `dart` target.
- **TypeScript/Next.js**: Use `openapi-typescript` to generate types + `openapi-fetch`
  for a thin client.

These tools consume `GET http://localhost:8009/openapi.json`.

## What's NOT built yet

This scaffold is project structure, tooling, and Docker only. The following
feature work still needs implementation:

- [ ] OTP send/verify endpoints (Twilio / Africa's Talking / Termii)
- [ ] Email/password registration and login
- [x] JWT signing and verification (RS256)
- [x] Password hashing (bcrypt)
- [x] Refresh token primitives
- [x] OTP code hashing
- [ ] Access + refresh token flow
- [ ] Session management (active sessions, force logout)
- [ ] Staff PIN login
- [ ] Role-based access control (RBAC) endpoints
- [ ] Rate limiting
- [ ] OpenTelemetry distributed tracing
- [ ] CI/CD pipeline (GitHub Actions / GitLab CI)
- [ ] Production Docker secrets (JWT keys, DB passwords)

## Tech stack

| Layer | Choice | Reason |
|-------|--------|--------|
| Framework | FastAPI | Async-native, automatic OpenAPI, Pydantic integration |
| ORM | SQLModel | SQLAlchemy 2.0 + Pydantic in one model class |
| DB | PostgreSQL 16 | Mature, JSONB for flexible profile data |
| Cache | Redis 7 | Session store, rate-limit counters, OTP TTL |
| Migrations | Alembic | Standard for SQLAlchemy-based projects |
| Package mgr | uv | Fastest Python resolver, from Astral (ruff too) |
| Linting | ruff | 100x faster than flake8, built-in formatter |
| Types | mypy | Strict mode, best-in-class for gradual typing |
| Logging | structlog | JSON structured logging for production |

## Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for folder layout, layer responsibilities,
and key design decisions.

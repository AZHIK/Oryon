# Development Guide

This guide contains the commands developers need to run the platform locally.
The root [README](../README.md) explains the architecture and technology stack;
this document explains the local workflow.

> These instructions target development only. For production, use the
> [deployment runbook](deployment/PRODUCTION_DEPLOYMENT.md).

## Prerequisites

- Docker Engine 24+ with Compose v2
- Python 3.12+
- [`uv`](https://docs.astral.sh/uv/)
- Flutter stable with Dart `^3.12.2`
- Git and `curl`

## 1. Identity Service

Start Identity first: it generates the JWT keypair the other services use.

```bash
cd services/identity-service
cp .env.example .env
uv run python scripts/generate_keys.py
docker compose up --build -d
docker compose exec api alembic upgrade head
```

Seed the platform RBAC hierarchy and role templates:

```bash
docker compose exec api python scripts/seed_permissions.py
docker compose exec api python scripts/seed_internal_rbac.py
docker compose exec api python scripts/seed_role_templates.py
```

Verify:

```bash
curl http://localhost:8009/health
curl http://localhost:8009/health/ready
```

Swagger UI is available at `http://localhost:8009/docs`.

## 2. Inventory Service

```bash
cd services/inventory-service
cp .env.example .env
mkdir -p keys
cp ../identity-service/keys/public.pem keys/public.pem
docker compose up --build -d
docker compose exec api alembic upgrade head
docker compose exec api python scripts/seed_categories.py
docker compose exec api python scripts/seed_units.py
curl http://localhost:8100/health
```

## 3. POS Service

```bash
cd services/pos-service
cp .env.example .env
mkdir -p keys
cp ../identity-service/keys/public.pem keys/public.pem
docker compose up --build -d
docker compose exec api alembic upgrade head
curl http://localhost:8200/health
```

The `INTERNAL_SERVICE_TOKEN` in the Inventory and POS `.env` files must match.
Production rejects the development default.

## 4. Flutter client

```bash
cd apps/restaurant_app
flutter pub get
flutter devices

# Against the deployed Oryon Foods APIs
flutter run -d linux

# Against the local Docker Compose services
flutter run -d linux --dart-define=API_ENV=local
```

Debug builds default to the deployed production APIs. For local development,
pass `API_ENV=local`. For an Android emulator using the local stack, use the
host alias `10.0.2.2`:

```bash
flutter run \
  --dart-define=API_ENV=local \
  --dart-define=IDENTITY_API_BASE_URL=http://10.0.2.2:8009/api/v1 \
  --dart-define=INVENTORY_API_BASE_URL=http://10.0.2.2:8100/api/v1 \
  --dart-define=POS_API_BASE_URL=http://10.0.2.2:8200/api/v1
```

For a physical device, use the host machine's LAN address.

Release builds require all three URLs and reject non-HTTPS values:

```bash
flutter build apk --release \
  --dart-define=IDENTITY_API_BASE_URL=https://auth.example.com/api/v1 \
  --dart-define=INVENTORY_API_BASE_URL=https://inventory.example.com/api/v1 \
  --dart-define=POS_API_BASE_URL=https://pos.example.com/api/v1
```

## 5. Tests and quality checks

### Identity

```bash
cd services/identity-service
docker compose --profile dev up -d api-dev
docker compose exec \
  -e TEST_DB_URL=postgresql+asyncpg://oryonfoods:oryonfoods@postgres:5432/oryonfoods_auth_test \
  api-dev uv run pytest -v
docker compose exec api-dev uv run ruff check app tests
docker compose exec api-dev uv run mypy app
```

### Inventory

```bash
cd services/inventory-service
docker compose --profile dev up -d api-dev
docker compose exec api-dev uv run pytest -v tests/
docker compose exec api-dev uv run ruff check app tests
docker compose exec api-dev uv run mypy app
```

### POS

```bash
cd services/pos-service
docker compose --profile dev up -d api-dev
docker compose exec postgres createdb -U oryonfoods oryonfoods_pos_test
docker compose exec \
  -e DB_URL=postgresql+asyncpg://oryonfoods:oryonfoods@postgres:5432/oryonfoods_pos_test \
  api-dev uv run pytest -v tests/
docker compose exec api-dev uv run ruff check app tests
docker compose exec api-dev uv run mypy app
```

### Flutter

```bash
cd apps/restaurant_app
flutter analyze
flutter test
```

> **Test databases:** the backend suites truncate or recreate tables. Always use
> a dedicated database whose name ends in `_test`. Never point `TEST_DB_URL` or a
> test run at a production database.

## 6. Cross-service development tools

The root `scripts/` directory contains demo, seed, and cleanup tools that talk to
all three local databases. Each script documents its own options and
idempotency behaviour:

```bash
uv run scripts/seed_test_store.py
uv run scripts/seed_tanzania_recipes.py
uv run scripts/seed_inventory_suppliers.py
uv run scripts/demo_target_flow.py --business-id <uuid>
uv run scripts/clean_test_store.py --store-id <uuid> --business-id <uuid>
```

## 7. Common operations

```bash
# From a service directory
docker compose ps
docker compose logs -f --tail=200 api
docker compose restart api
docker compose exec api alembic upgrade head

# Create a migration after a model change
docker compose exec api alembic revision --autogenerate -m "describe change"

# Stop without deleting data
docker compose down

# Delete local database/volume data (destructive)
docker compose down -v
```

Database changes: Drift generated files are committed. After changing a Drift
table or converter, regenerate them:

```bash
cd apps/restaurant_app
dart run build_runner build --delete-conflicting-outputs
```

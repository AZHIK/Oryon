# Oryon Foods Inventory Service

Inventory microservice for Oryon Foods. Handles item catalog, stock
levels, movements, adjustments, and procurement — everything that tracks
"what do we have and where".

## Architecture

This service is a **resource server** in the Oryon Foods ecosystem. It:

- **Verifies** JWT tokens issued by the Identity Service (it never issues
  its own tokens — only the Identity Service possesses the private key).
- **Owns its own data** in a dedicated `oryonfoods_inventory` Postgres database
  (it does not share Identity Service's database).
- **Publishes and subscribes** to events via a shared RabbitMQ exchange
  (configured via `RABBITMQ_URL` and `EVENTS_EXCHANGE`).

## Suppliers and Reorders

Beyond items/stock/movements, this service also owns the **supplier
directory** and **reorders** (purchase orders placed with a supplier to
restock an item):

| Method | Path | Permission | Purpose |
|--------|------|------------|---------|
| `POST` | `/businesses/{business_id}/suppliers` | `suppliers.create` | Add a supplier |
| `GET` | `/businesses/{business_id}/suppliers` | `suppliers.view` | List suppliers (paginated, searchable) |
| `GET` | `/businesses/{business_id}/suppliers/{supplier_id}` | `suppliers.view` | Read a single supplier |
| `PATCH` | `/businesses/{business_id}/suppliers/{supplier_id}` | `suppliers.update` | Edit a supplier |
| `DELETE` | `/businesses/{business_id}/suppliers/{supplier_id}` | `suppliers.delete` | Soft-delete a supplier (past reorders keep their attribution) |
| `POST` | `/businesses/{business_id}/reorders` | `reorders.create` | Place a reorder (rejects `sellable`-type items — see below) |
| `GET` | `/businesses/{business_id}/reorders` | `reorders.view` | List reorders (filter by status/item/store) |
| `GET` | `/businesses/{business_id}/reorders/{reorder_id}` | `reorders.view` | Read a single reorder |
| `POST` | `/businesses/{business_id}/reorders/{reorder_id}/receive` | `reorders.receive` | Mark received — credits stock via `record_movement` |
| `POST` | `/businesses/{business_id}/reorders/{reorder_id}/cancel` | `reorders.cancel` | Cancel a pending reorder |

Key design points:

- **`receive_reorder` reuses the existing stock-movement engine** — it calls
  `record_movement()` (`app/services/stock_movement_service.py`) with
  `movement_type=purchase_received` and `reference_type="reorder"`, then
  updates the `Reorder` row's status in the same transaction (`commit=False`
  on the movement call, one `session.commit()` at the end) — the same
  pattern `app/api/v1/endpoints/operations.py`'s `transfer_stock` uses for
  its two-movement transfer.
- **A `sellable`-type item can never be reordered** — `record_movement`
  already rejects `purchase_received` for `item_type == sellable`
  (`_COMPATIBILITY_RULES`), so `create_reorder` refuses it up front with a
  clear 422 rather than deferring the same failure to receive time.
- **`Reorder`/`Supplier` use real foreign keys** (`item_id`, `supplier_id`),
  unlike `business_id`/`store_id` which stay plain cross-service UUIDs — see
  `app/models/reorders.py`'s module docstring.
- **No soft-delete on `Reorder`** — like `Sale` in pos-service, it's an
  append-only purchase record with state transitions
  (`pending -> received | cancelled`), not a mutable row.

## Cross-Service JWT Verification

This service verifies tokens using the Identity Service's **public key**.
The public key must be deployed alongside this service.

### Operational Note: Public Key Distribution

In a real deployment, the public key (`keys/public.pem`) is **not** committed
as a permanent file in this repository. Instead:

1. The Identity Service's deployment pipeline exports its public key to a
   shared secret store (e.g., HashiCorp Vault, AWS Secrets Manager, or a
   Kubernetes ConfigMap).
2. This service's deployment pipeline copies that public key into
   `keys/public.pem` at deployment time (or injects it via the
   `JWT_PUBLIC_KEY_PATH` env var pointing to a mounted secret).

**Do not** rely on the checked-in `keys/public.pem` for production — it
exists here only for local development convenience. A deployment-time copy
step ensures that key rotation in the Identity Service propagates to all
resource servers without a source-control PR.

## RabbitMQ Topology Notes

The shared RabbitMQ instance may run:

- **As part of this compose stack** — add a `rabbitmq` service to
  `docker-compose.yml` and wire `RABBITMQ_URL` to it.
- **As a separate shared stack** — point `RABBITMQ_URL` at the shared
  instance's host and port.

The choice depends on whether RabbitMQ is treated as platform infrastructure
(shared stack) or per-service infrastructure (in-stack). The compose file
in this repo currently assumes it is shared infrastructure and does not
include a RabbitMQ container — this is the recommended default.

## Local Development

```bash
cp .env.example .env
# Ensure keys/public.pem exists (copied from identity-service/keys/public.pem)
# Requires Python 3.12+ and uv installed

uv sync
uv run uvicorn app.main:app --reload
```

## Run migrations

```bash
docker compose exec api alembic upgrade head

# To create a new migration after adding a model
docker compose exec api alembic revision --autogenerate -m "description"
```

## Seed data

Migrations only create schema — they never insert seed rows. After running
migrations, seed the category taxonomy (Produce, Dairy, Beverages, ...) and
the unit-of-measure taxonomy (Kilogram, Gram, Liter, ...) as separate,
explicit steps:

```bash
docker compose exec api python scripts/seed_categories.py
docker compose exec api python scripts/seed_units.py
```

Safe to run multiple times — each upserts by its taxonomy's stable `code`, so
re-running after editing `CATEGORY_SEEDS` (`app/db/seed_categories.py`) or
`UNIT_SEEDS` (`app/db/seed_units.py`) updates existing rows instead of
duplicating them.

## Tests

Run the full suite (206 tests covering CRUD, auth, schemas, movement engine,
operation endpoints, and supplier/reorder endpoints) with a single command:

```bash
docker compose run --rm api-dev uv run pytest -v tests/
```

Run a specific subset:

```bash
# Service-layer tests (movement engine)
docker compose run --rm api-dev uv run pytest -v tests/services/

# API integration tests
docker compose run --rm api-dev uv run pytest -v tests/api/
```

## Docker Compose

```bash
docker compose up --build
```

This starts the API on port 8100 and a dedicated Postgres instance on port 5433.
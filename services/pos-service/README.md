# Oryon Foods POS Service

Point-of-sale microservice for Oryon Foods. Manages sales transactions,
line items, payments, receipts, local tax configuration, ad-hoc
other-expense/other-income finance entries, and a business's customer
ledger (sales may optionally be attributed to a customer via a real FK).

- **Database**: dedicated `oryonfoods_pos` PostgreSQL instance (not shared).
- **Auth**: verifies RS256 JWTs issued by Identity Service (never issues tokens).
- **Events**: publishes sale lifecycle events (`sale.completed`, `sale.voided`,
  `sale.refunded`) via a shared RabbitMQ exchange.
- **Port**: `8200`

---

## Quick Start

```bash
cp .env.example .env
cp ../identity-service/keys/public.pem keys/
uv sync
uv run uvicorn app.main:app --reload
```

---

## Available Endpoints

| Method | Path | Permission | Purpose |
|--------|------|------------|---------|
| `GET` | `/health` | none | Liveness probe |
| `POST` | `/businesses/{business_id}/sales/sync` | `pos.write` | Batch-sync offline sales |
| `GET` | `/businesses/{business_id}/sales` | `pos.view` | List sales (paginated, filterable) |
| `GET` | `/businesses/{business_id}/sales/summary` | `pos.view` | Aggregate summary (revenue, voided, refunded, payment-method breakdown) |
| `GET` | `/businesses/{business_id}/sales/{sale_id}` | `pos.view` | Read single sale by server ID |
| `GET` | `/businesses/{business_id}/sales/by-client-id/{client_sale_id}` | `pos.view` | Read single sale by client idempotency key |
| `POST` | `/businesses/{business_id}/sales/{sale_id}/void-or-refund` | `pos.refund` | Void or refund a completed sale |
| `POST` | `/businesses/{business_id}/other-expenses/sync` | `finance.expenses.create` | Batch-sync offline expense entries |
| `GET` | `/businesses/{business_id}/other-expenses` | `finance.view` | List expenses (paginated, filterable) |
| `GET` | `/businesses/{business_id}/other-expenses/summary` | `finance.view` | Aggregate summary + category breakdown |
| `GET` | `/businesses/{business_id}/other-expenses/{expense_id}` | `finance.view` | Read single expense |
| `PATCH` | `/businesses/{business_id}/other-expenses/{expense_id}` | `finance.expenses.update` | Edit an already-synced expense |
| `DELETE` | `/businesses/{business_id}/other-expenses/{expense_id}` | `finance.expenses.delete` | Soft-delete an expense |
| `POST` | `/businesses/{business_id}/other-incomes/sync` | `finance.incomes.create` | Batch-sync offline income entries |
| `GET` | `/businesses/{business_id}/other-incomes` | `finance.view` | List incomes (paginated, filterable) |
| `GET` | `/businesses/{business_id}/other-incomes/summary` | `finance.view` | Aggregate summary + category breakdown |
| `GET` | `/businesses/{business_id}/other-incomes/{income_id}` | `finance.view` | Read single income |
| `PATCH` | `/businesses/{business_id}/other-incomes/{income_id}` | `finance.incomes.update` | Edit an already-synced income |
| `DELETE` | `/businesses/{business_id}/other-incomes/{income_id}` | `finance.incomes.delete` | Soft-delete an income |
| `POST` | `/businesses/{business_id}/finance/attachments` | `finance.attachments.upload` | Upload a receipt file |
| `GET` | `/businesses/{business_id}/finance/attachments/{attachment_id}` | `finance.view` | Download a receipt file |
| `POST` | `/businesses/{business_id}/customers/sync` | `customers.create` | Batch-sync offline-created customers |
| `GET` | `/businesses/{business_id}/customers` | `customers.view` | List customers (paginated, searchable, server-computed totals) |
| `PATCH` | `/businesses/{business_id}/customers/{customer_id}` | `customers.update` | Edit an already-synced customer |
| `DELETE` | `/businesses/{business_id}/customers/{customer_id}` | `customers.delete` | Soft-delete a customer (sales keep their attribution) |
| `GET` | `/businesses/{business_id}/customers/{customer_id}` | `customers.view` | Read single customer, with computed totals |

All `pos.*`/`finance.*`/`customers.*` endpoints enforce **business-context
binding**: the URL path's `business_id` must match the JWT's
`active_business_id` claim.

---

## Design Decisions (with in-file documentation anchors)

Every non-trivial design choice is documented at the point of implementation.
Key locations:

| Decision | File & Line |
|----------|-------------|
| Cross-service reference columns (no FK constraints) | `app/models/pos.py:4-18` |
| Why no `processed_sync_events` table | `app/models/pos.py:20-28` |
| Sale state machine (terminal states only) | `app/models/pos.py:31-38` |
| Pre-voided / pre-refunded sale on first sync | `app/schemas/sales.py:3-19` |
| Partial-success batch design (not all-or-nothing) | `app/schemas/sales.py:14-20` |
| Business-context binding (Gap 1 fix) | `app/deps/auth.py:126-148` |
| Event-publish stub (RabbitMQ deferred) | `app/core/events.py:1-4` |
| PermissionCode duplication / shared-package extraction | `app/core/permission_codes.py:1-13` |
| Per-sale independent transactions in batch sync | `app/services/sale_service.py:69-75` |
| Finance entries are mutable, sales are not | `app/models/finance.py:16-26` |
| Category storage: VARCHAR, not a Postgres enum | `app/models/finance.py:28-37` |
| Local-disk receipt storage (single-node/backup tradeoff) | `app/services/receipt_storage.py:1-24` |
| `Customer.id` is client-generated and IS the server PK/FK | `app/models/customers.py:1-25` |
| Customer totals computed on read, never stored counters | `app/services/customer_service.py:239-260` |

---

## KNOWN GAPS

### 1. Inventory Service does not yet consume `sale.voided` / `sale.refunded`

POS Service correctly publishes `sale.voided` and `sale.refunded` events
with full line-item payloads (`void_or_refund_sale()` at
`sale_service.py:284-298`). However, Inventory Service has **no handler**
for these events — stock is **not reversed** when a sale is voided or
refunded.

- POS-side test: `test_KNOWN_GAP_inventory_does_not_yet_reverse_stock_on_void`
  in `tests/services/test_sale_service.py:928`.
- Fix target: add `handle_sale_voided` / `handle_sale_refunded` in
  Inventory Service's `app/services/event_handlers.py`.

### 2. Receipt files are stored on local disk, not object storage

`app/services/receipt_storage.py`'s `LocalDiskReceiptStorage` writes
uploaded receipts under `RECEIPT_STORAGE_ROOT` on the container's own
filesystem (a named Docker volume in `docker-compose.yml`). This is fine
for a single instance, but:

- **No horizontal scaling / rolling deploy**: a second replica would not
  see receipts uploaded to the first. Do not scale this service past one
  instance (or deploy behind a shared network filesystem) without first
  swapping in an S3/MinIO-backed `ReceiptStorage` implementation.
- **Backup**: a Postgres dump alone is no longer a complete backup once
  receipts exist — the `receipt_data` volume must be included in whatever
  backs up this service's state.

Swapping the backend is a new class behind the existing `ReceiptStorage`
protocol — no call-site changes needed.

### 3. Shared-package extraction (prep for Service #4)

`security.py`, `deps/auth.py`, and `PermissionCode` (`permission_codes.py`)
are duplicated across POS Service and Identity Service. Before starting
Service #4 (Procurement or whichever comes next), extract these into a
**shared Python package** that both services import.

- See the TODO-FIXME header in `app/core/permission_codes.py:12`.

---

## Cross-Service JWT Verification

POS Service verifies tokens using Identity Service's **public key**
(`keys/public.pem`). It never possesses a private key.

**Operational note**: in production, the public key is deployed via a
secret store (Vault, K8s ConfigMap, etc.) — do not rely on the checked-in
key for production. Key rotation in Identity Service must propagate to all
resource servers.

---

## RabbitMQ Topology

The compose file in this repo does **not** include a RabbitMQ container
(RabbitMQ is treated as shared platform infrastructure). Set
`RABBITMQ_URL` and `EVENTS_EXCHANGE` in `.env` to point to the shared
instance.

Currently all event publishing is a **stub** that logs only
(`app/core/events.py:13`). Real RabbitMQ wiring is deferred to a later
stage.

---

## Local Development

```bash
cp .env.example .env
cp ../identity-service/keys/public.pem keys/   # required for JWT verification
uv sync
uv run uvicorn app.main:app --reload
```

---

## Docker Compose

```bash
docker compose up --build
```

Starts the API on port 8200 and a dedicated Postgres on port 5435.

A dev profile is also available (hot-reload via volume mount):

```bash
docker compose --profile dev up -d
docker compose exec api-dev tail -f /dev/null  # attach your editor
```

## Run migrations

```bash
docker compose exec api alembic upgrade head

# To create a new migration after adding a model
docker compose exec api alembic revision --autogenerate -m "description"
```

---

## Tests

Requires a running Postgres (either via Docker Compose or a local instance
with the `DB_URL` from `.env.example`).

```bash
# Via Docker Compose dev profile
docker compose --profile dev up -d
docker compose exec api-dev uv run pytest -v tests/

# Or directly (if Postgres is running on localhost:5432)
uv run pytest -v tests/
```

Full suite (169+ tests):

```bash
uv run pytest -v tests/ --tb=short
```

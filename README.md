# Oryon — Restaurant Operations Platform

Oryon is the restaurant point-of-sale and business-management platform from
Oryon Foods. It pairs a Flutter client with three FastAPI services — Identity,
Inventory, and POS — each owning its own PostgreSQL database.

This document explains **what the system is, how it is structured, and which
technology it uses**. It deliberately contains no setup or operational commands.
Those live in the service READMEs and the documents under [`docs/`](docs/), which
are linked throughout.

---

## 1. System intent

Oryon is built for restaurant operators who need to keep selling, tracking
stock, and managing staff even when connectivity is unreliable.

The platform separates three concerns:

- **Who a person is and what they may do** — Identity.
- **What the business owns and consumes** — Inventory.
- **What the business sells and earns** — POS.

The Flutter client is offline-first: it keeps an encrypted local database,
synchronises with the services when a connection exists, and continues operating
through short outages.

The database is application state, not a user document. It is
SQLCipher-encrypted and stored in the platform's private application-data
directory — `%APPDATA%\Oryon Foods\Oryon` on Windows, `$XDG_DATA_HOME/oryon` on
Linux, Application Support on macOS, and the app sandbox on Android and iOS —
never in the user's Documents folder. On Windows the uninstaller deletes that
directory, database and encryption key included, so any unsynced sales are
discarded with it. See
[Windows installer](docs/deployment/WINDOWS_INSTALLER.md) for details.

A separate public website lives in `apps/website`. It is a static Next.js
marketing and download site served by a non-root Nginx container on the same
VPS edge. It does not import the Flutter client or any backend service.

---

## 2. Architecture at a glance

```text
                         ┌──────────────────────────┐
                         │   Flutter client         │
                         │   apps/restaurant_app    │
                         └────────────┬─────────────┘
                                      │ HTTPS / JSON
                    RS256 JWT issued by the Identity Service
                                      │
          ┌───────────────────────────┼───────────────────────────┐
          │                           │                           │
 ┌────────▼─────────┐       ┌─────────▼─────────┐       ┌─────────▼────────┐
 │ Identity Service │       │ Inventory Service │       │   POS Service    │
 │ auth, users,     │       │ items, stock,     │       │ sales, payments, │
 │ RBAC, business,  │       │ suppliers,        │       │ finance,         │
 │ stores, roles    │       │ reorders, recipes │       │ customers        │
 └───────┬──────────┘       └─────────┬─────────┘       └─────────┬────────┘
         │                            │                           │
   PostgreSQL + Redis          PostgreSQL 16              PostgreSQL 16
                                 + image volume             + receipt volume
```

### Trust boundaries

- **Identity is the only token issuer.** It holds the JWT private key; the other
  services receive only the public key.
- **Inventory and POS are resource servers.** They verify tokens and enforce
  permissions but never mint them.
- **Each service owns its schema.** There are no cross-database joins.
- **POS calls Inventory internally** for stock-affecting events using a
  service-to-service token. RabbitMQ is the intended future event bus, but no
  broker is wired in yet.
- **Production terminates TLS at the edge.** PostgreSQL and Redis are not
  reachable from the public internet.

---

## 3. Services

| Component | Repository path | Responsibility |
|---|---|---|
| Identity Service | `services/identity-service` | Accounts, OTP/password login, sessions, JWT issuance, businesses, stores, RBAC, platform staff |
| Inventory Service | `services/inventory-service` | Items, categories, units, stock movements, suppliers, requisitions, purchase orders, recipes, WhatsApp ordering |
| POS Service | `services/pos-service` | Sales, payments, refunds, finance entries, customers, receipts, reporting |
| Flutter client | `apps/restaurant_app` | Offline-first POS and management UI for phones, tablets, desktop, and web |
| Public website | `apps/website` | Product story, screenshots, download/store options, support and legal pages; static Next.js export served by Nginx |

### Public website

The public marketing and download site is a standalone Next.js 16 static export
with routes for the product story, downloads, support, privacy and terms. It
uses the supplied desktop and mobile product screenshots and the app's
deep-teal/mint visual language. It does not import the Flutter client or call
the backend APIs; a non-root Nginx container serves it through the same VPS
edge. See the [website overview](apps/website/README.md) and
[deployment guide](apps/website/DEPLOYMENT.md).

Local ports, database names, and development topology are documented in
[`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) and each service's README.

---

## 4. Project structure

```text
Oryon/
├── apps/
│   ├── restaurant_app/          # Flutter client
│   │   ├── lib/
│   │   │   ├── auth/            # Login, session, token refresh
│   │   │   ├── config/          # Environment-specific API endpoints
│   │   │   ├── database/        # Drift/SQLite schema and encryption
│   │   │   ├── models/          # Client domain models
│   │   │   ├── providers/       # Riverpod state and API clients
│   │   │   ├── router/          # go_router navigation
│   │   │   ├── screens/         # POS, inventory, finance, staff, settings
│   │   │   ├── services/        # HTTP service clients
│   │   │   ├── sync/            # Offline-first synchronisation
│   │   │   └── widgets/         # Shared UI
│   │   ├── test/                # Flutter tests
│   │   └── android/ ios/ linux/ web/ windows/
│   │
│   └── website/                 # Public marketing and download site
│       ├── app/                 # Routes, metadata, sitemap, robots, styles
│       ├── components/          # Brand, layout, home sections, screenshots
│       ├── content/             # English and Swahili copy
│       ├── assets/images/       # Supplied product screenshots
│       ├── public/badges/       # Official store badge artwork
│       ├── Dockerfile / nginx.conf / docker-compose*.yml
│       └── README.md / DEPLOYMENT.md
│
├── services/
│   ├── identity-service/
│   │   ├── app/                 # Routers, services, models, repositories
│   │   ├── migrations/          # Alembic migrations
│   │   ├── scripts/             # Key generation and RBAC seeds
│   │   └── tests/
│   ├── inventory-service/
│   │   ├── app/
│   │   ├── migrations/
│   │   ├── scripts/             # Taxonomy seeds
│   │   └── tests/
│   └── pos-service/
│       ├── app/
│       ├── migrations/
│       └── tests/
│
├── deploy/                      # Production host, edge, DB, backup package
│   ├── compose/                 # Production compose and first-boot DB init
│   ├── traefik/                 # Traefik static/dynamic templates
│   ├── scripts/                 # Bootstrap, deploy, migrate, seed, backup, restore
│   ├── host/                    # UFW, fail2ban, sysctl, Docker ingress hardening
│   ├── systemd/                 # Backup timer and firewall unit
│   └── README.md                # Production runbook and commands
│
├── docs/                        # Cross-cutting documentation
│   ├── DEVELOPMENT.md           # Local workflow and test commands
│   ├── deployment/              # Production model, verification, DR
│   └── security/                # Audit, findings, remediation status
│
├── scripts/                     # Cross-service demo, seed, and cleanup tools
├── .github/workflows/           # CI image build, scan, and deploy validation
└── README.md
```

The backend services follow the same layering:

```text
HTTP → Router → Service → Database
          ↓        ↑
       Schema    Model
```

Identity adds a repository layer where persistence logic is complex enough to
warrant it:

```text
HTTP → Router → Service → Repository → Database
```

Routers parse and delegate. Services hold business rules and data access. Models
describe persistence; schemas describe the HTTP contract.

---

## 5. Technology stack

### Client

| Concern | Technology |
|---|---|
| Framework | Flutter / Dart |
| State management | Riverpod |
| Navigation | go_router |
| Local persistence | Drift + SQLite, encrypted at rest with SQLCipher |
| Secure storage | flutter_secure_storage |
| Networking | Dio |
| Offline/sync | Connectivity awareness, Workmanager, custom sync services |
| UI and charts | Material, fl_chart, Google Fonts |
| Documents | PDF, Excel, share and file-picker packages |
| Platforms | Android, iOS, Linux and Windows desktop, web |

### Public website

| Concern | Technology |
|---|---|
| Framework | Next.js 16 App Router, TypeScript, static export |
| UI | Tailwind CSS 4, Inter via `next/font`, Motion for the mobile menu |
| Images | `next/image` with the supplied desktop and mobile product screenshots |
| Hosting | Multi-stage Docker image, non-root Nginx, Traefik on the existing VPS |
| Documentation | [`apps/website/README.md`](apps/website/README.md), [`DEPLOYMENT.md`](apps/website/DEPLOYMENT.md) |

### Backend

| Concern | Technology |
|---|---|
| Language | Python 3.12+ |
| Framework | FastAPI |
| Models and validation | SQLModel (SQLAlchemy 2 + Pydantic) |
| Database driver | asyncpg |
| Migrations | Alembic |
| Settings | pydantic-settings, with Docker-secret support |
| Authentication | RS256 JWTs, bcrypt password hashing, OTP flows |
| Structured logging | structlog |
| HTTP client | httpx |
| Package manager | uv |
| Linting and typing | ruff, mypy |
| Tests | pytest, pytest-asyncio |

### Infrastructure

| Concern | Technology |
|---|---|
| Databases | PostgreSQL 16, one database per service |
| Cache, sessions, rate limits | Redis 7 |
| Events | Internal HTTP today; RabbitMQ planned |
| Container runtime | Docker Engine + Compose v2 |
| Production edge | Traefik v3, Docker secrets, isolated edge/data networks |
| Images | Multi-stage Docker builds with non-root runtime users |
| Backups | Encrypted, offsite PostgreSQL dumps plus upload volumes |

---

## 6. Documentation

The complete documentation index is [`docs/README.md`](docs/README.md). The most
important entry points are:

### Security and production

| Document | Purpose |
|---|---|
| [Security Audit](docs/security/SECURITY_AUDIT.md) | Findings, severity, evidence, and recommended fixes across all services and the client |
| [Security Remediation Log](docs/security/REMEDIATION_LOG.md) | What has been fixed, how it was verified, and what remains before go-live |
| [Production Deployment](docs/deployment/PRODUCTION_DEPLOYMENT.md) | Host baseline, edge design, secrets, compose topology, backups, and disaster recovery |
| [Deployment Package](deploy/README.md) | Executable Traefik, compose, secrets, migration, backup, and restore package |

### Service and application documentation

| Document | Purpose |
|---|---|
| [Identity Service](services/identity-service/README.md) | Identity setup, RBAC model, migrations, seeds, endpoints |
| [Identity Architecture](services/identity-service/ARCHITECTURE.md) | Layering and key design decisions |
| [Identity Schema](services/identity-service/schema.md) | Users, businesses, stores, roles, and permissions |
| [Inventory Service](services/inventory-service/README.md) | Stock engine, suppliers, reorders, events |
| [Inventory Requisitions](services/inventory-service/REQUISITIONS.md) | Requisition → purchase order → WhatsApp flow |
| [POS Service](services/pos-service/README.md) | Sales, payments, finance, customers, known gaps |
| [Flutter App](apps/restaurant_app/README.md) | Client setup and feature organisation |
| [App UI Audit](apps/restaurant_app/ORYON_BUSINESS_APP_AUDIT.md) | Feature completeness review |
| [Permission Integration](apps/restaurant_app/docs/PERMISSION_INTEGRATION_PATTERN.md) | How screens and actions are permission-gated |

### Public website

| Document | Purpose |
|---|---|
| [Website overview](apps/website/README.md) | Stack, local development, pages, design system and project structure |
| [Website deployment](apps/website/DEPLOYMENT.md) | Local Docker preview, GitHub-pull VPS deployment, DNS/TLS, rollback and database-integration path |
| [Website screenshots](apps/website/SCREENSHOTS.md) | Product screenshot files, usage and proportion rules |
| [Website content TODO](apps/website/CONTENT_TODO.md) | Outstanding store URLs, installer metadata, contact details and review gates |

---

## 7. Environment model

### Local development

Each backend service runs in its own Docker Compose stack with a dedicated
PostgreSQL database; Identity also runs Redis. The Flutter client points at the
three local APIs. Local defaults are intentionally convenient, not secure, and
are rejected when a service is started in production mode.

The public website is independent: it runs locally through its development
server or a local Docker compose file and does not call the backend services.

### Production

Production targets a single hardened Linux VPS:

- Traefik is the only public entry point, with automatic HTTPS, HTTP-to-HTTPS
  redirect, HSTS, rate limits, and restricted admin/readiness paths.
- Docker secrets carry database URLs, JWT keys, provider credentials, and
  service tokens.
- PostgreSQL and Redis sit on an internal-only network with no published ports.
- Images are built, scanned, and pushed by CI, then deployed by immutable tag.
- The public website is a static Next.js export in a non-root Nginx container
  attached to the same edge network and served at `oryonfoods.com`.
- Backups leave the host encrypted; restore procedures are documented and must
  be drilled before go-live and after any restore-path change.

The security and deployment documents are the authority for production. This
README only describes the system and how its parts fit together.

---

## 8. Engineering conventions

- Service-specific design notes stay next to the code.
- Cross-cutting security and deployment documentation lives under `docs/`.
- Backend changes must pass linting, type checking, and tests.
- Client changes must pass static analysis and widget tests.
- Secrets, private keys, environment files, and database volumes never enter
  version control.
- Migrations are applied explicitly, never on application startup.
- Production configuration fails closed rather than silently falling back to
  development defaults.

---

## License

Proprietary — © Oryon Foods. See the `license` field in each service's
`pyproject.toml`.

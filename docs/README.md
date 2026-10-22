# Documentation Index

This directory holds the cross-cutting documentation for the Oryon platform.
Each backend service and the Flutter app also keep their own documentation next
to the code.

## Start here

| Document | Audience | Purpose |
|---|---|---|
| [Project overview](../README.md) | Everyone | What Oryon is, its architecture, project structure, and technology stack |
| [Development guide](DEVELOPMENT.md) | Engineers | Local stack, tests, and client workflow |

## Security

| Document | Audience | Purpose |
|---|---|---|
| [Security audit](security/SECURITY_AUDIT.md) | Engineering, operations, leadership | Full findings register with severity, evidence, impact, and recommended remediation |
| [Remediation log](security/REMEDIATION_LOG.md) | Engineering, operations | What was fixed, how it was verified, and what remains before go-live |

## Production and operations

| Document | Audience | Purpose |
|---|---|---|
| [Production deployment runbook](deployment/PRODUCTION_DEPLOYMENT.md) | Operations, engineering | Production model, host hardening, secrets, deploy/verify, backups, and disaster recovery |
| [Deploy package README](../deploy/README.md) | Operations | Exact commands and file layout for the production package |
| [Deployment package](../deploy/README.md) | Operations | Executable Traefik/compose/secrets/migration/backup package and runbook |

## Service documentation

| Document | Purpose |
|---|---|
| [Identity Service](../services/identity-service/README.md) | Identity setup, RBAC model, migrations, seeds, endpoints |
| [Identity Architecture](../services/identity-service/ARCHITECTURE.md) | Layering and key design decisions |
| [Identity Database Schema](../services/identity-service/schema.md) | Tables for users, businesses, stores, permissions, and roles |
| [Inventory Service](../services/inventory-service/README.md) | Stock engine, suppliers, reorders, events, local setup |
| [Inventory Requisitions](../services/inventory-service/REQUISITIONS.md) | Requisition → purchase order → WhatsApp flow |
| [POS Service](../services/pos-service/README.md) | Sales, payments, finance entries, customers, known gaps |
| [Flutter App](../apps/restaurant_app/README.md) | Client setup and feature organisation |
| [App UI Audit](../apps/restaurant_app/ORYON_BUSINESS_APP_AUDIT.md) | Feature-by-feature completeness review |
| [Permission Integration](../apps/restaurant_app/docs/PERMISSION_INTEGRATION_PATTERN.md) | How to gate screens and actions by permission |

## Documentation conventions

- The root README describes the system; it does not contain setup or deployment
  commands.
- Operational commands live in the development guide, service READMEs, or the
  production runbook where their prerequisites are explained.
- Security decisions are recorded in the audit and remediation log so the
  original evidence is never lost.
- When a behaviour changes, update the document that owns that behaviour rather
  than adding a second explanation elsewhere.

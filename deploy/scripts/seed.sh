#!/usr/bin/env bash
# Seed the platform RBAC, inventory taxonomy, and first platform admin.
# Safe to re-run: every seed is idempotent; the admin script does not reset an
# existing password unless ADMIN_RESET_PASSWORD=1 is set explicitly.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_cmd docker
require_root
load_env
fix_secret_permissions

compose up -d postgres redis
wait_for_postgres

identity_url="$(owner_db_url identity oryonfoods_auth)"
inventory_url="$(owner_db_url inventory oryonfoods_inventory)"

log "Seeding Identity permissions"
compose run --rm -T --no-deps -e DB_URL="$identity_url" identity \
    python scripts/seed_permissions.py

log "Seeding internal RBAC groups and roles"
compose run --rm -T --no-deps -e DB_URL="$identity_url" identity \
    python scripts/seed_internal_rbac.py

log "Seeding business role templates"
compose run --rm -T --no-deps -e DB_URL="$identity_url" identity \
    python scripts/seed_role_templates.py

log "Seeding Inventory categories and units"
compose run --rm -T --no-deps -e DB_URL="$inventory_url" inventory \
    python scripts/seed_categories.py
compose run --rm -T --no-deps -e DB_URL="$inventory_url" inventory \
    python scripts/seed_units.py

log "Creating the first platform administrator"
compose run --rm -T --no-deps \
    -e DB_URL="$identity_url" \
    -e ADMIN_EMAIL="${ADMIN_EMAIL:?set ADMIN_EMAIL}" \
    -e ADMIN_FULL_NAME="${ADMIN_FULL_NAME:-Platform Administrator}" \
    -e ADMIN_RESET_PASSWORD="${ADMIN_RESET_PASSWORD:-0}" \
    identity python scripts/create_platform_admin.py

grant_app_privileges identity oryonfoods_auth
grant_app_privileges inventory oryonfoods_inventory

log "Seeding complete."

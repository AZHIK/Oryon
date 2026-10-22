#!/usr/bin/env bash
# Apply Alembic migrations with the per-service owner role, then grant the
# runtime role the privileges it needs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_cmd docker
require_root
load_env
fix_secret_permissions

require_secret postgres_password
for service in identity inventory pos; do
    require_secret "${service}_owner_db_password"
done

compose up -d postgres redis
wait_for_postgres

migrate_service() {
    local service="$1"
    local database="$2"
    local url
    url="$(owner_db_url "$service" "$database")"

    log "Migrating $service ($database)"
    compose run --rm -T --no-deps \
        -e DB_URL="$url" \
        "$service" alembic upgrade head

    log "Granting runtime privileges for $service"
    grant_app_privileges "$service" "$database"
}

migrate_service identity oryonfoods_auth
migrate_service inventory oryonfoods_inventory
migrate_service pos oryonfoods_pos

log "Migrations complete."

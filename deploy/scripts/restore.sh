#!/usr/bin/env bash
# Restore databases and upload volumes from a directory produced by backup.sh
# (directly, or after extracting a restic snapshot).
#
# This is destructive. It requires CONFIRM_RESTORE=yes.
#
# Usage:
#   CONFIRM_RESTORE=yes ./scripts/restore.sh /path/to/backup-directory
#
# Global roles are not recreated here because bootstrap/initdb already creates
# them. See the deployment guide for a full bare-metal restore.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_cmd docker
require_cmd sha256sum
require_cmd tar
require_root
load_env
fix_secret_permissions

[[ "${CONFIRM_RESTORE:-}" == "yes" ]] || fail "Refusing to restore without CONFIRM_RESTORE=yes"
dump_dir="${1:-}"
[[ -n "$dump_dir" && -d "$dump_dir" ]] || fail "Usage: CONFIRM_RESTORE=yes $0 /path/to/backup-directory"
[[ -f "$dump_dir/SHA256SUMS" ]] || fail "Missing $dump_dir/SHA256SUMS"
log "Global roles are not recreated by this script; bootstrap/initdb must have run on the target cluster."
[[ ! -f "$dump_dir/globals.sql" ]] || log "Global-role dump retained at $dump_dir/globals.sql for manual review."

log "Verifying backup checksums"
(
    cd "$dump_dir"
    sha256sum -c SHA256SUMS
)

log "Stopping APIs"
compose stop identity inventory pos || true
compose up -d postgres redis
wait_for_postgres

restore_database() {
    local service="$1"
    local database="$2"
    local dump="$3"
    [[ -f "$dump" ]] || fail "Missing dump: $dump"

    log "Restoring $database from $(basename "$dump")"
    compose exec -T postgres pg_restore \
        -U postgres \
        --clean --if-exists --no-acl \
        --role="${service}_owner" \
        -d "$database" < "$dump"
    grant_app_privileges "$service" "$database"
}

restore_database identity oryonfoods_auth "$dump_dir/auth.dump"
restore_database inventory oryonfoods_inventory "$dump_dir/inventory.dump"
restore_database pos oryonfoods_pos "$dump_dir/pos.dump"

if [[ -f "$dump_dir/item_images.tgz" ]]; then
    log "Restoring item images"
    tar -C /srv/oryonfoods -xzf "$dump_dir/item_images.tgz"
    chown -R 10001:10001 /srv/oryonfoods/item_images
fi
if [[ -f "$dump_dir/receipts.tgz" ]]; then
    log "Restoring receipts"
    tar -C /srv/oryonfoods -xzf "$dump_dir/receipts.tgz"
    chown -R 10001:10001 /srv/oryonfoods/receipts
fi

log "Starting APIs and edge"
compose up -d --wait --wait-timeout 300

if [[ "${SKIP_SMOKE:-0}" != "1" ]]; then
    "$SCRIPT_DIR/smoke-test.sh"
fi

log "Restore complete. Review application logs before reopening traffic."

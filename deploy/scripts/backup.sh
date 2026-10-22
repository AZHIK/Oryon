#!/usr/bin/env bash
# Nightly encrypted offsite backup.
#
# Backs up:
#   - one PostgreSQL custom-format dump per service
#   - global roles
#   - item-image and receipt volumes
#   - compose/Traefik/host/script configuration and .env
#   - optionally the secrets and generated directories (restic encrypts the
#     repository)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_cmd docker
require_cmd restic
require_cmd tar
require_cmd sha256sum
require_cmd flock
require_root
load_env

[[ -n "${RESTIC_REPOSITORY:-}" ]] || fail "RESTIC_REPOSITORY is empty; configure an offsite restic repository first"
[[ -s "${RESTIC_PASSWORD_FILE:-}" ]] || fail "RESTIC_PASSWORD_FILE is missing or empty: ${RESTIC_PASSWORD_FILE:-<unset>}"

export RESTIC_REPOSITORY
export RESTIC_PASSWORD_FILE

if [[ -n "${B2_ACCOUNT_ID_FILE:-}" && -s "$B2_ACCOUNT_ID_FILE" ]]; then
    export B2_ACCOUNT_ID
    B2_ACCOUNT_ID="$(cat "$B2_ACCOUNT_ID_FILE")"
fi
if [[ -n "${B2_ACCOUNT_KEY_FILE:-}" && -s "$B2_ACCOUNT_KEY_FILE" ]]; then
    export B2_ACCOUNT_KEY
    B2_ACCOUNT_KEY="$(cat "$B2_ACCOUNT_KEY_FILE")"
fi

umask 077
mkdir -p "$DEPLOY_DIR/backups"
exec 9>"$DEPLOY_DIR/backups/.backup.lock"
flock -n 9 || fail "Another backup is already running"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
out="$DEPLOY_DIR/backups/$timestamp"
mkdir -p "$out"
chmod 700 "$out"
# Never leave unencrypted database dumps on disk if any step fails.
trap 'rm -rf "$out"' EXIT

log "Dumping PostgreSQL databases to $out"
for pair in "auth:oryonfoods_auth" "inventory:oryonfoods_inventory" "pos:oryonfoods_pos"; do
    name="${pair%%:*}"
    database="${pair##*:}"
    compose exec -T postgres pg_dump -U postgres -Fc "$database" > "$out/$name.dump"
done

compose exec -T postgres pg_dumpall -U postgres --globals-only > "$out/globals.sql"

log "Archiving upload volumes"
tar -C /srv/oryonfoods -czf "$out/item_images.tgz" item_images
tar -C /srv/oryonfoods -czf "$out/receipts.tgz" receipts

(
    cd "$out"
    sha256sum ./*.dump ./globals.sql ./*.tgz > SHA256SUMS
)

# Initialise the repository only when explicitly asked; an accidental empty
# repository name must never silently create a new backup history.
if ! restic snapshots >/dev/null 2>&1; then
    if [[ "${RESTIC_INIT:-0}" == "1" ]]; then
        log "Initialising restic repository"
        restic init
    else
        fail "restic repository is not initialised. Create it once, or set RESTIC_INIT=1 on the first run."
    fi
fi

config_paths=(
    "$DEPLOY_DIR/compose"
    "$DEPLOY_DIR/traefik"
    "$DEPLOY_DIR/scripts"
    "$DEPLOY_DIR/systemd"
    "$DEPLOY_DIR/host"
    "$DEPLOY_DIR/.env"
    "$DEPLOY_DIR/.env.example"
    "$DEPLOY_DIR/README.md"
    "$DEPLOY_DIR/generated/traefik.yml"
    "$DEPLOY_DIR/generated/dynamic.yml"
)

if [[ "${BACKUP_SECRETS:-0}" == "1" ]]; then
    log "Including secrets and generated credentials in the encrypted snapshot"
    config_paths+=("$DEPLOY_DIR/secrets" "$DEPLOY_DIR/generated")
fi

log "Uploading encrypted snapshot"
restic backup "$out" /srv/oryonfoods/item_images /srv/oryonfoods/receipts \
    "${config_paths[@]}" \
    --tag oryonfoods --tag vps01

log "Applying retention policy"
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune

if [[ -n "${BACKUP_HEALTHCHECK_URL:-}" ]]; then
    require_cmd curl
    curl -fsS -m 10 "$BACKUP_HEALTHCHECK_URL" >/dev/null || log "warning: backup healthcheck ping failed"
fi

log "Backup complete."

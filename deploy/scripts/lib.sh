#!/usr/bin/env bash
# Shared helpers for the Oryon Foods deployment scripts.
set -euo pipefail

DEPLOY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$DEPLOY_DIR/compose/docker-compose.prod.yml"
ENV_FILE="$DEPLOY_DIR/.env"
SECRETS_DIR="$DEPLOY_DIR/secrets"
# shellcheck disable=SC2034 # consumed by scripts that source this file
GENERATED_DIR="$DEPLOY_DIR/generated"

log() { printf '[oryonfoods] %s\n' "$*"; }
fail() { printf '[oryonfoods] ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

require_root() {
    [[ "$(id -u)" -eq 0 ]] || fail "Run this script as root (it reads root-owned .env/secrets and manages the stack)."
}

require_env() {
    local name
    for name in "$@"; do
        [[ -n "${!name:-}" ]] || fail "$name is not set in $ENV_FILE"
    done
}

# Compose file secrets are bind-mounted from the host, so host ownership and
# mode decide whether the container user can read them. The long-form `uid`,
# `gid`, and `mode` keys are ignored by non-Swarm Compose, so set them here.
fix_secret_permissions() {
    local name

    [[ -d "$SECRETS_DIR" ]] || return 0
    chown 0:0 "$SECRETS_DIR"
    chmod 700 "$SECRETS_DIR"

    _own_secret() {
        local uid="$1"
        local gid="$2"
        local mode="$3"
        shift 3
        for name in "$@"; do
            if [[ -e "$SECRETS_DIR/$name" ]]; then
                chown "$uid:$gid" "$SECRETS_DIR/$name"
                chmod "$mode" "$SECRETS_DIR/$name"
            fi
        done
    }

    # API runtime user (10001): service URLs, keys, provider credentials.
    _own_secret 10001 10001 0400 \
        identity_db_url identity_redis_url inventory_db_url pos_db_url \
        internal_service_token jwt_private.pem \
        at_api_key brevo_api_key mailjet_api_key mailjet_secret_key \
        admin_password whatsapp_app_secret whatsapp_webhook_verify_token

    # Identity's public key is intentionally world-readable inside its own
    # container; the host secrets directory remains root-only (700).
    _own_secret 10001 10001 0444 jwt_public.pem

    # PostgreSQL image user (70): superuser, owner, and runtime passwords used
    # by the first-boot init script and POSTGRES_PASSWORD_FILE.
    _own_secret 70 70 0400 \
        postgres_password \
        identity_owner_db_password identity_app_db_password \
        inventory_owner_db_password inventory_app_db_password \
        pos_owner_db_password pos_app_db_password

    # Redis image user (999:1000).
    _own_secret 999 1000 0400 redis_password

    # Host-only restic credentials, never mounted into a container.
    _own_secret 0 0 0600 restic_password b2_account_id b2_account_key
}

load_env() {
    [[ -f "$ENV_FILE" ]] || fail "Missing $ENV_FILE. Copy .env.example to .env and edit it."
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a

    [[ -n "${AUTH_HOST:-}" ]] || fail "AUTH_HOST is not set"
    [[ -n "${INVENTORY_HOST:-}" ]] || fail "INVENTORY_HOST is not set"
    [[ -n "${POS_HOST:-}" ]] || fail "POS_HOST is not set"
    [[ -n "${IMAGE_TAG:-}" ]] || fail "IMAGE_TAG is not set"
    [[ -n "${IMAGE_REGISTRY:-}" ]] || fail "IMAGE_REGISTRY is not set"
}

compose() {
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

require_secret() {
    local name="$1"
    [[ -s "$SECRETS_DIR/$name" ]] || fail "Missing or empty secret: $SECRETS_DIR/$name"
}

wait_for_postgres() {
    local container status
    for _ in $(seq 1 60); do
        container="$(compose ps -q postgres || true)"
        if [[ -n "$container" ]]; then
            status="$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || true)"
            [[ "$status" == "healthy" ]] && return 0
        fi
        sleep 2
    done
    fail "Postgres did not become healthy in time"
}

owner_db_url() {
    local service="$1"
    local database="$2"
    local password
    password="$(cat "$SECRETS_DIR/${service}_owner_db_password")"
    printf 'postgresql+asyncpg://%s_owner:%s@postgres:5432/%s' "$service" "$password" "$database"
}

grant_app_privileges() {
    local service="$1"
    local database="$2"
    local owner="${service}_owner"
    local app="${service}_app"

    compose exec -T postgres psql -v ON_ERROR_STOP=1 -U postgres -d "$database" <<SQL
GRANT CONNECT ON DATABASE $database TO $app;
GRANT USAGE ON SCHEMA public TO $app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $app;
ALTER DEFAULT PRIVILEGES FOR ROLE $owner IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $app;
ALTER DEFAULT PRIVILEGES FOR ROLE $owner IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO $app;
SQL
}

check_placeholders() {
    local value="$1"
    local name="$2"
    case "$value" in
        *REPLACE*|*example.com*)
            fail "$name still contains a placeholder: $value"
            ;;
    esac
}

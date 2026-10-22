#!/usr/bin/env bash
# One-time host preparation for the Oryon Foods production stack.
#
# Generates Docker secrets, JWT keys, database URLs, Redis config, and the
# rendered Traefik configuration. Safe to re-run: existing secrets are never
# overwritten.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$DEPLOY_DIR/.env"
SECRETS_DIR="$DEPLOY_DIR/secrets"
GENERATED_DIR="$DEPLOY_DIR/generated"
DATA_ROOT="${DATA_ROOT:-/srv/oryonfoods}"

log() { printf '[bootstrap] %s\n' "$*"; }
fail() { printf '[bootstrap] ERROR: %s\n' "$*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || fail "Run this script as root (it creates /srv data directories and root-owned secrets)."
command -v openssl >/dev/null 2>&1 || fail "openssl is required."
command -v docker >/dev/null 2>&1 || fail "Docker is required."
command -v restic >/dev/null 2>&1 || \
    log "warning: restic is not installed; backups will fail until it is (host/harden-host.sh installs it)."

if [[ ! -f "$ENV_FILE" ]]; then
    cp "$DEPLOY_DIR/.env.example" "$ENV_FILE"
    chmod 600 "$ENV_FILE"
    fail "Created $ENV_FILE. Edit the domains, ACME email, CORS origin, admin email, and image tag, then re-run."
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

require_value() {
    local name="$1"
    local value="${!name:-}"
    [[ -n "$value" ]] || fail "$name is not set in $ENV_FILE"
}

require_value AUTH_HOST
require_value INVENTORY_HOST
require_value POS_HOST
require_value ACME_EMAIL
require_value CORS_ALLOWED_ORIGINS
require_value ADMIN_EMAIL
require_value ADMIN_FULL_NAME

case "$AUTH_HOST$INVENTORY_HOST$POS_HOST$ACME_EMAIL$CORS_ALLOWED_ORIGINS$ADMIN_EMAIL" in
    *REPLACE*|*example.com*)
        fail "Replace the example.com/REPLACE values in $ENV_FILE before bootstrapping production."
        ;;
esac

# ── Filesystem layout ────────────────────────────────────────
install -d -m 700 "$SECRETS_DIR"
install -d -m 700 "$GENERATED_DIR"
install -d -m 700 "$GENERATED_DIR/letsencrypt"
install -d -m 700 "$DEPLOY_DIR/backups"

# Container UIDs are fixed in the service Dockerfiles: postgres=70,
# redis=999:1000, and the API runtime user=10001.
install -d -o 70 -g 70 -m 700 "$DATA_ROOT/postgres"
install -d -o 999 -g 1000 -m 750 "$DATA_ROOT/redis"
install -d -o 10001 -g 10001 -m 750 "$DATA_ROOT/item_images"
install -d -o 10001 -g 10001 -m 750 "$DATA_ROOT/receipts"
chown 70:70 "$DATA_ROOT/postgres"
chmod 700 "$DATA_ROOT/postgres"
chown 999:1000 "$DATA_ROOT/redis"
chmod 750 "$DATA_ROOT/redis"
chown 10001:10001 "$DATA_ROOT/item_images" "$DATA_ROOT/receipts"
chmod 750 "$DATA_ROOT/item_images" "$DATA_ROOT/receipts"

generate_secret() {
    local file="$SECRETS_DIR/$1"
    if [[ ! -s "$file" ]]; then
        openssl rand -hex 32 > "$file"
        chmod 600 "$file"
        log "Generated $1"
    fi
}

# Random credentials used by Postgres, Redis, and service-to-service calls.
for name in \
    postgres_password \
    identity_owner_db_password identity_app_db_password \
    inventory_owner_db_password inventory_app_db_password \
    pos_owner_db_password pos_app_db_password \
    redis_password internal_service_token; do
    generate_secret "$name"
done

# The first platform admin's password. Retrieve it after bootstrap with:
#   sudo cat /opt/oryonfoods/secrets/admin_password
if [[ ! -s "$SECRETS_DIR/admin_password" ]]; then
    openssl rand -hex 24 > "$SECRETS_DIR/admin_password"
    chmod 600 "$SECRETS_DIR/admin_password"
    log "Generated the initial platform admin password"
fi

# Provider credentials cannot be generated. Create the files so the stack is
# complete, then require the operator to fill the ones in use.
for name in at_api_key brevo_api_key mailjet_api_key mailjet_secret_key \
            whatsapp_app_secret whatsapp_webhook_verify_token; do
    if [[ ! -e "$SECRETS_DIR/$name" ]]; then
        : > "$SECRETS_DIR/$name"
        chmod 600 "$SECRETS_DIR/$name"
    fi
done

# Offsite backup credentials. Leave the B2 files empty until a repository exists.
if [[ ! -s "$SECRETS_DIR/restic_password" ]]; then
    openssl rand -hex 32 > "$SECRETS_DIR/restic_password"
    chmod 600 "$SECRETS_DIR/restic_password"
    log "Generated the restic repository password (store a copy offline)"
fi
for name in b2_account_id b2_account_key; do
    if [[ ! -e "$SECRETS_DIR/$name" ]]; then
        : > "$SECRETS_DIR/$name"
        chmod 600 "$SECRETS_DIR/$name"
    fi
done

# ── JWT keypair ──────────────────────────────────────────────
if [[ ! -s "$SECRETS_DIR/jwt_private.pem" ]]; then
    openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 \
        -out "$SECRETS_DIR/jwt_private.pem"
    chmod 600 "$SECRETS_DIR/jwt_private.pem"
    log "Generated the JWT private key"
fi
if [[ ! -s "$SECRETS_DIR/jwt_public.pem" ]]; then
    openssl pkey -in "$SECRETS_DIR/jwt_private.pem" -pubout \
        -out "$SECRETS_DIR/jwt_public.pem"
    chmod 644 "$SECRETS_DIR/jwt_public.pem"
    log "Generated the JWT public key"
fi

# ── Database and Redis URLs (read by pydantic-settings secrets_dir) ──
write_url() {
    local file="$SECRETS_DIR/$1"
    local value="$2"
    printf '%s' "$value" > "$file"
    chmod 600 "$file"
}

write_url identity_db_url \
    "postgresql+asyncpg://identity_app:$(cat "$SECRETS_DIR/identity_app_db_password")@postgres:5432/oryonfoods_auth"
write_url inventory_db_url \
    "postgresql+asyncpg://inventory_app:$(cat "$SECRETS_DIR/inventory_app_db_password")@postgres:5432/oryonfoods_inventory"
write_url pos_db_url \
    "postgresql+asyncpg://pos_app:$(cat "$SECRETS_DIR/pos_app_db_password")@postgres:5432/oryonfoods_pos"
write_url identity_redis_url \
    "redis://:$(cat "$SECRETS_DIR/redis_password")@redis:6379/0"

# ── Redis config ─────────────────────────────────────────────
cat > "$GENERATED_DIR/redis.conf" <<EOF
bind 0.0.0.0
protected-mode yes
port 6379
requirepass $(cat "$SECRETS_DIR/redis_password")
appendonly yes
appendfsync everysec
maxmemory 256mb
maxmemory-policy allkeys-lru
dir /data
EOF
chown 999:1000 "$GENERATED_DIR/redis.conf"
chmod 640 "$GENERATED_DIR/redis.conf"

# ── Traefik ──────────────────────────────────────────────────
acme_email_escaped="${ACME_EMAIL//&/\\&}"
sed "s|__ACME_EMAIL__|$acme_email_escaped|g" \
    "$DEPLOY_DIR/traefik/traefik.yml.template" \
    > "$GENERATED_DIR/traefik.yml"
chmod 644 "$GENERATED_DIR/traefik.yml"

allowlist_yaml=""
IFS=',' read -r -a cidrs <<< "${ADMIN_ALLOWLIST:-127.0.0.1/32}"
for cidr in "${cidrs[@]}"; do
    cidr="$(printf '%s' "$cidr" | tr -d '[:space:]')"
    [[ -n "$cidr" ]] || continue
    if ! printf '%s' "$cidr" | grep -Eq '^[0-9a-fA-F:.]+/[0-9]{1,3}$'; then
        fail "Invalid ADMIN_ALLOWLIST CIDR: $cidr"
    fi
    allowlist_yaml+="\"$cidr\", "
done
allowlist_yaml="${allowlist_yaml%, }"
[[ -n "$allowlist_yaml" ]] || fail "ADMIN_ALLOWLIST produced an empty allowlist"

sed "s|__ADMIN_ALLOWLIST__|$allowlist_yaml|" \
    "$DEPLOY_DIR/traefik/dynamic.yml.template" \
    > "$GENERATED_DIR/dynamic.yml"
chmod 644 "$GENERATED_DIR/dynamic.yml"

if [[ ! -f "$GENERATED_DIR/letsencrypt/acme.json" ]]; then
    touch "$GENERATED_DIR/letsencrypt/acme.json"
fi
chmod 600 "$GENERATED_DIR/letsencrypt/acme.json"

# Compose ignores uid/gid/mode on non-Swarm file secrets; set the host-side
# ownership that the container users actually read.
fix_secret_permissions

chmod 600 "$ENV_FILE"

log "Secrets and rendered configuration are ready."
log "Next: fill the provider secret files in $SECRETS_DIR, then run scripts/deploy.sh."
log "Provider files: at_api_key, brevo_api_key, whatsapp_app_secret, whatsapp_webhook_verify_token."
log "Optional: mailjet_* if EMAIL_PROVIDER=mailjet, and b2_* / restic settings for backups."

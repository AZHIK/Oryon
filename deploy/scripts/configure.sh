#!/usr/bin/env bash
# Interactive first-run configuration for the Oryon Foods production stack.
#
# Writes .env and the provider credential files, then leaves secret generation
# and rendered configuration to bootstrap.sh. Safe to re-run: existing values
# are offered as defaults and non-empty credential files are kept unless a new
# value is entered.
#
# Usage:
#   sudo ./scripts/configure.sh
#
# Credentials are read with echo disabled and are never passed on the command
# line, so they do not appear in shell history or the process list.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_root
command -v openssl >/dev/null 2>&1 || fail "openssl is required."

if [[ ! -t 0 ]]; then
    fail "configure.sh is interactive; run it from a terminal."
fi

ENV_FILE="$DEPLOY_DIR/.env"
SECRETS_DIR="$DEPLOY_DIR/secrets"
DEFAULT_DOMAIN="oryonfoods.com"

# ── Helpers ──────────────────────────────────────────────────
env_value() {
    local key="$1" line
    [[ -f "$ENV_FILE" ]] || return 0
    line="$(grep -E "^${key}=" "$ENV_FILE" | tail -n 1 || true)"
    [[ -n "$line" ]] || return 0
    line="${line#*=}"
    line="${line%\"}"
    line="${line#\"}"
    printf '%s' "$line"
}

ask() {
    local prompt="$1" default="${2:-}" answer
    if [[ -n "$default" ]]; then
        read -r -p "  ${prompt} [${default}]: " answer || fail "input closed"
        printf '%s' "${answer:-$default}"
    else
        while :; do
            read -r -p "  ${prompt}: " answer || fail "input closed"
            [[ -n "$answer" ]] && break
            printf '  a value is required\n'
        done
        printf '%s' "$answer"
    fi
}

ask_optional() {
    local prompt="$1" default="${2:-}" answer
    if [[ -n "$default" ]]; then
        read -r -p "  ${prompt} [${default}]: " answer || fail "input closed"
        printf '%s' "${answer:-$default}"
    else
        read -r -p "  ${prompt} (optional): " answer || fail "input closed"
        printf '%s' "$answer"
    fi
}

validate_host() {
    local value="$1" label="$2"
    [[ "$value" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$ ]] \
        || fail "${label} is not a valid hostname: ${value}"
    case "$value" in
        *example.com*|*REPLACE*)
            fail "${label} still contains a placeholder: ${value}"
            ;;
    esac
}

validate_email() {
    local value="$1" label="$2"
    [[ "$value" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] \
        || fail "${label} is not a valid email address: ${value}"
    case "$value" in
        *example.com*|*REPLACE*)
            fail "${label} still contains a placeholder: ${value}"
            ;;
    esac
}

validate_cidrs() {
    local value="$1" cidr
    local -a cidrs
    IFS=',' read -r -a cidrs <<< "$value"
    [[ "${#cidrs[@]}" -gt 0 ]] || fail "ADMIN_ALLOWLIST is empty"
    for cidr in "${cidrs[@]}"; do
        cidr="${cidr// /}"
        [[ -n "$cidr" ]] || continue
        [[ "$cidr" =~ ^[0-9a-fA-F:.]+/[0-9]{1,3}$ ]] \
            || fail "ADMIN_ALLOWLIST contains an invalid CIDR: ${cidr}"
    done
}

validate_origins() {
    local value="$1" origin
    local -a origins
    IFS=',' read -r -a origins <<< "$value"
    for origin in "${origins[@]}"; do
        origin="${origin// /}"
        [[ -n "$origin" ]] || continue
        [[ "$origin" == https://* ]] \
            || fail "CORS origins must use https://: ${origin}"
        case "$origin" in
            *localhost*|*127.0.0.1*)
                fail "CORS origins must not contain localhost: ${origin}"
                ;;
            *example.com*|*REPLACE*)
                fail "CORS origin still contains a placeholder: ${origin}"
                ;;
        esac
    done
}

escape_double() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

list_ghcr_tags() {
    local owner="$1" token tags
    command -v curl >/dev/null 2>&1 || return 0

    token="$(curl -fsS --max-time 5 \
        "https://ghcr.io/token?scope=repository:${owner}/oryon-identity:pull&service=ghcr.io" \
        2>/dev/null | sed -n 's/.*"token":"\([^"]*\)".*/\1/p' || true)"
    [[ -n "$token" ]] || return 0

    tags="$(curl -fsS --max-time 5 -H "Authorization: Bearer ${token}" \
        "https://ghcr.io/v2/${owner}/oryon-identity/tags/list" 2>/dev/null \
        | grep -o '"sha-[0-9a-f]\{40\}"' | tr -d '"' | sort -u || true)"
    [[ -n "$tags" ]] || return 0
    printf '%s\n' "$tags"
}

write_secret() {
    local name="$1" value="$2"
    ( umask 077; printf '%s' "$value" > "$SECRETS_DIR/$name" )
    chmod 600 "$SECRETS_DIR/$name"
}

ask_secret() {
    local name="$1" label="$2" required="$3"
    local path="$SECRETS_DIR/$name" value=""

    [[ -s "$path" ]] && printf '  %s: already set (Enter to keep)\n' "$label"
    while :; do
        read -r -s -p "  ${label}: " value || fail "input closed"
        printf '\n'
        if [[ -n "$value" ]]; then
            write_secret "$name" "$value"
            return 0
        fi
        [[ -s "$path" ]] && return 0
        [[ "$required" == "1" ]] || return 0
        printf '  %s is required\n' "$label"
    done
}

write_env() {
    local tmp
    tmp="$(mktemp "${ENV_FILE}.XXXXXX")"

    {
        printf '# Generated by scripts/configure.sh. Edit and re-run bootstrap.sh\n'
        printf '# after changing any value. Secret material lives in secrets/.\n\n'
        printf 'AUTH_HOST=%s\n' "$AUTH_HOST"
        printf 'INVENTORY_HOST=%s\n' "$INVENTORY_HOST"
        printf 'POS_HOST=%s\n' "$POS_HOST"
        printf '\nACME_EMAIL=%s\n' "$ACME_EMAIL"
        printf 'CORS_ALLOWED_ORIGINS="%s"\n' "$(escape_double "$CORS_ALLOWED_ORIGINS")"
        printf 'ADMIN_ALLOWLIST="%s"\n' "$ADMIN_ALLOWLIST"
        printf '\nIMAGE_REGISTRY=%s\n' "$IMAGE_REGISTRY"
        printf 'IMAGE_TAG=%s\n' "$IMAGE_TAG"
        printf 'TRAEFIK_IMAGE=%s\n' "$TRAEFIK_IMAGE"
        printf 'SOCKET_PROXY_IMAGE=%s\n' "$SOCKET_PROXY_IMAGE"
        printf 'POSTGRES_IMAGE=%s\n' "$POSTGRES_IMAGE"
        printf 'REDIS_IMAGE=%s\n' "$REDIS_IMAGE"
        printf '\nSMS_PROVIDER=africastalking\n'
        printf 'AT_USERNAME=%s\n' "$AT_USERNAME"
        printf 'AT_SENDER_ID=%s\n' "$AT_SENDER_ID"
        printf '\nEMAIL_PROVIDER=%s\n' "$EMAIL_PROVIDER"
        printf 'BREVO_FROM_EMAIL=%s\n' "$BREVO_FROM_EMAIL"
        printf 'BREVO_FROM_NAME="%s"\n' "$(escape_double "$BREVO_FROM_NAME")"
        printf '\nWHATSAPP_GRAPH_BASE_URL=%s\n' "$WHATSAPP_GRAPH_BASE_URL"
        printf 'WHATSAPP_GRAPH_VERSION=%s\n' "$WHATSAPP_GRAPH_VERSION"
        printf '\nADMIN_EMAIL=%s\n' "$ADMIN_EMAIL"
        printf 'ADMIN_FULL_NAME="%s"\n' "$(escape_double "$ADMIN_FULL_NAME")"
        printf '\nRESTIC_REPOSITORY=%s\n' "$RESTIC_REPOSITORY"
        printf 'RESTIC_PASSWORD_FILE=%s\n' "$RESTIC_PASSWORD_FILE"
        printf 'B2_ACCOUNT_ID_FILE=%s\n' "$B2_ACCOUNT_ID_FILE"
        printf 'B2_ACCOUNT_KEY_FILE=%s\n' "$B2_ACCOUNT_KEY_FILE"
        printf 'BACKUP_HEALTHCHECK_URL=%s\n' "$BACKUP_HEALTHCHECK_URL"
        printf 'BACKUP_SECRETS=%s\n' "$BACKUP_SECRETS"
    } > "$tmp"

    chmod 600 "$tmp"
    mv -f "$tmp" "$ENV_FILE"
}

# ── Prompts ──────────────────────────────────────────────────
printf '\nOryon Foods production configuration\n'
printf 'Press Enter to accept the value in [brackets].\n\n'

existing_auth="$(env_value AUTH_HOST)"
existing_domain="${existing_auth#auth.}"
domain="$(ask "Base domain" "${existing_domain:-$DEFAULT_DOMAIN}")"
validate_host "$domain" "Base domain"

existing_host="$(env_value AUTH_HOST)"
AUTH_HOST="$(ask "Identity hostname" "${existing_host:-auth.$domain}")"
validate_host "$AUTH_HOST" "AUTH_HOST"

existing_host="$(env_value INVENTORY_HOST)"
INVENTORY_HOST="$(ask "Inventory hostname" "${existing_host:-inventory.$domain}")"
validate_host "$INVENTORY_HOST" "INVENTORY_HOST"

existing_host="$(env_value POS_HOST)"
POS_HOST="$(ask "POS hostname" "${existing_host:-pos.$domain}")"
validate_host "$POS_HOST" "POS_HOST"

existing_value="$(env_value CORS_ALLOWED_ORIGINS)"
CORS_ALLOWED_ORIGINS="$(ask "Browser CORS origin(s), comma-separated" "${existing_value:-https://app.$domain}")"
validate_origins "$CORS_ALLOWED_ORIGINS"

existing_value="$(env_value ACME_EMAIL)"
ACME_EMAIL="$(ask "Let's Encrypt email" "${existing_value:-ops@$domain}")"
validate_email "$ACME_EMAIL" "ACME_EMAIL"

existing_value="$(env_value ADMIN_EMAIL)"
ADMIN_EMAIL="$(ask "Platform admin email" "${existing_value:-admin@$domain}")"
validate_email "$ADMIN_EMAIL" "ADMIN_EMAIL"

existing_value="$(env_value ADMIN_FULL_NAME)"
ADMIN_FULL_NAME="$(ask_optional "Platform admin name" "${existing_value:-Platform Administrator}")"
[[ -n "$ADMIN_FULL_NAME" ]] || ADMIN_FULL_NAME="Platform Administrator"

existing_value="$(env_value ADMIN_ALLOWLIST)"
ADMIN_ALLOWLIST="$(ask "Admin allowlist CIDR(s)" "${existing_value:-127.0.0.1/32}")"
validate_cidrs "$ADMIN_ALLOWLIST"

printf '\n  The admin allowlist keeps /admin and platform login off the public\n'
printf '  internet. Add your office/VPN CIDR after the smoke test passes.\n\n'

existing_value="$(env_value IMAGE_REGISTRY)"
IMAGE_REGISTRY="$(ask "Image registry" "${existing_value:-ghcr.io/azhik}")"
IMAGE_REGISTRY="${IMAGE_REGISTRY,,}"
[[ "$IMAGE_REGISTRY" =~ ^[a-z0-9.-]+/[a-z0-9._/-]+$ ]] \
    || fail "IMAGE_REGISTRY must look like registry/namespace: ${IMAGE_REGISTRY}"

existing_tag="$(env_value IMAGE_TAG)"
if [[ "$IMAGE_REGISTRY" == "ghcr.io/"* ]]; then
    owner="${IMAGE_REGISTRY#ghcr.io/}"
    published_tags="$(list_ghcr_tags "$owner" || true)"
    if [[ -n "$published_tags" ]]; then
        printf '  Published tags for %s/oryon-identity:\n' "$owner"
        while IFS= read -r tag; do
            printf '    %s\n' "$tag"
        done <<< "$published_tags"
    fi
fi
IMAGE_TAG="$(ask "Image tag (sha-<full-git-sha>)" "$existing_tag")"
[[ "$IMAGE_TAG" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$ ]] \
    || fail "IMAGE_TAG is not a valid tag: ${IMAGE_TAG}"
case "$IMAGE_TAG" in *REPLACE*) fail "IMAGE_TAG still contains a placeholder" ;; esac

AT_USERNAME="$(ask "Africa's Talking username" "$(env_value AT_USERNAME)")"
[[ "$AT_USERNAME" != "sandbox" ]] \
    || fail "AT_USERNAME must be the production username, not 'sandbox'"
case "$AT_USERNAME" in *REPLACE*|*example.com*) fail "AT_USERNAME still contains a placeholder" ;; esac

AT_SENDER_ID="$(ask_optional "SMS sender ID" "$(env_value AT_SENDER_ID)")"
[[ -n "$AT_SENDER_ID" ]] || AT_SENDER_ID="ORYON"

existing_value="$(env_value EMAIL_PROVIDER)"
EMAIL_PROVIDER="$(ask "Email provider (brevo/mailjet)" "${existing_value:-brevo}")"
case "$EMAIL_PROVIDER" in
    brevo|mailjet) ;;
    *) fail "EMAIL_PROVIDER must be brevo or mailjet" ;;
esac

existing_value="$(env_value BREVO_FROM_EMAIL)"
BREVO_FROM_EMAIL="$(ask "Sender email address" "${existing_value:-no-reply@$domain}")"
validate_email "$BREVO_FROM_EMAIL" "BREVO_FROM_EMAIL"

existing_value="$(env_value BREVO_FROM_NAME)"
BREVO_FROM_NAME="$(ask_optional "Sender display name" "${existing_value:-Oryon Foods}")"
[[ -n "$BREVO_FROM_NAME" ]] || BREVO_FROM_NAME="Oryon Foods"

WHATSAPP_GRAPH_BASE_URL="$(env_value WHATSAPP_GRAPH_BASE_URL)"
WHATSAPP_GRAPH_BASE_URL="${WHATSAPP_GRAPH_BASE_URL:-https://graph.facebook.com}"
WHATSAPP_GRAPH_VERSION="$(env_value WHATSAPP_GRAPH_VERSION)"
WHATSAPP_GRAPH_VERSION="${WHATSAPP_GRAPH_VERSION:-v21.0}"

RESTIC_REPOSITORY="$(env_value RESTIC_REPOSITORY)"
RESTIC_PASSWORD_FILE="$(env_value RESTIC_PASSWORD_FILE)"
RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-$SECRETS_DIR/restic_password}"
B2_ACCOUNT_ID_FILE="$(env_value B2_ACCOUNT_ID_FILE)"
B2_ACCOUNT_ID_FILE="${B2_ACCOUNT_ID_FILE:-$SECRETS_DIR/b2_account_id}"
B2_ACCOUNT_KEY_FILE="$(env_value B2_ACCOUNT_KEY_FILE)"
B2_ACCOUNT_KEY_FILE="${B2_ACCOUNT_KEY_FILE:-$SECRETS_DIR/b2_account_key}"
BACKUP_HEALTHCHECK_URL="$(env_value BACKUP_HEALTHCHECK_URL)"
BACKUP_SECRETS="$(env_value BACKUP_SECRETS)"
BACKUP_SECRETS="${BACKUP_SECRETS:-0}"

TRAEFIK_IMAGE="$(env_value TRAEFIK_IMAGE)"
TRAEFIK_IMAGE="${TRAEFIK_IMAGE:-traefik:v3.1}"
SOCKET_PROXY_IMAGE="$(env_value SOCKET_PROXY_IMAGE)"
SOCKET_PROXY_IMAGE="${SOCKET_PROXY_IMAGE:-tecnativa/docker-socket-proxy:0.2}"
POSTGRES_IMAGE="$(env_value POSTGRES_IMAGE)"
POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:16.4-alpine}"
REDIS_IMAGE="$(env_value REDIS_IMAGE)"
REDIS_IMAGE="${REDIS_IMAGE:-redis:7.4-alpine}"

# ── Confirm and write ────────────────────────────────────────
printf '\nSummary:\n'
printf '  identity     https://%s\n' "$AUTH_HOST"
printf '  inventory    https://%s\n' "$INVENTORY_HOST"
printf '  pos          https://%s\n' "$POS_HOST"
printf '  ACME email   %s\n' "$ACME_EMAIL"
printf '  CORS         %s\n' "$CORS_ALLOWED_ORIGINS"
printf '  admin        %s\n' "$ADMIN_EMAIL"
printf '  allowlist    %s\n' "$ADMIN_ALLOWLIST"
printf '  images       %s/oryon-*:%s\n' "$IMAGE_REGISTRY" "$IMAGE_TAG"
printf '  SMS          Africa'\''s Talking (%s)\n' "$AT_USERNAME"
printf '  email        %s from %s\n' "$EMAIL_PROVIDER" "$BREVO_FROM_EMAIL"

confirm=""
read -r -p "Write .env and continue to provider credentials? [y/N]: " confirm || fail "input closed"
[[ "$confirm" =~ ^[Yy]$ ]] || fail "aborted; nothing was written"

install -d -m 700 "$SECRETS_DIR"
chown 0:0 "$SECRETS_DIR"

printf '\nProvider credentials (input is hidden; Enter keeps an existing value)\n'
ask_secret at_api_key "Africa's Talking API key" 1
if [[ "$EMAIL_PROVIDER" == "brevo" ]]; then
    ask_secret brevo_api_key "Brevo API key" 1
else
    ask_secret mailjet_api_key "Mailjet API key" 1
    ask_secret mailjet_secret_key "Mailjet secret key" 1
fi
ask_secret whatsapp_app_secret "WhatsApp app secret" 1
ask_secret whatsapp_webhook_verify_token "WhatsApp webhook verify token" 0

if [[ ! -s "$SECRETS_DIR/whatsapp_webhook_verify_token" ]]; then
    verify_token="$(openssl rand -hex 24)"
    write_secret whatsapp_webhook_verify_token "$verify_token"
    printf '\nGenerated WhatsApp verify token (use it in the Meta webhook setup):\n  %s\n' "$verify_token"
fi

write_env

printf '\nWrote %s (mode 600) and provider credentials in %s.\n' "$ENV_FILE" "$SECRETS_DIR"
printf '\nNext:\n'
printf '  sudo ./scripts/bootstrap.sh\n'
printf '  sudo ./scripts/deploy.sh\n'
printf '\nThen run the smoke test and allowlist your admin IP (docs/deployment).\n'

#!/usr/bin/env bash
# Deploy or update the Oryon Foods production stack.
#
# Prerequisites:
#   - bootstrap.sh has been run and provider secrets are filled in
#   - DNS points at this host and ports 80/443 are reachable
#   - the requested immutable image tag exists in the registry
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_cmd docker
require_root
load_env
fix_secret_permissions

require_env ACME_EMAIL CORS_ALLOWED_ORIGINS ADMIN_EMAIL AT_USERNAME BREVO_FROM_EMAIL

check_placeholders "$AUTH_HOST" AUTH_HOST
check_placeholders "$INVENTORY_HOST" INVENTORY_HOST
check_placeholders "$POS_HOST" POS_HOST
check_placeholders "$ACME_EMAIL" ACME_EMAIL
check_placeholders "$CORS_ALLOWED_ORIGINS" CORS_ALLOWED_ORIGINS
check_placeholders "$ADMIN_EMAIL" ADMIN_EMAIL
check_placeholders "$IMAGE_REGISTRY" IMAGE_REGISTRY
check_placeholders "$IMAGE_TAG" IMAGE_TAG
check_placeholders "$AT_USERNAME" AT_USERNAME
check_placeholders "$BREVO_FROM_EMAIL" BREVO_FROM_EMAIL

for secret in \
    postgres_password redis_password \
    identity_owner_db_password identity_app_db_password \
    inventory_owner_db_password inventory_app_db_password \
    pos_owner_db_password pos_app_db_password \
    identity_db_url identity_redis_url \
    inventory_db_url pos_db_url \
    jwt_private.pem jwt_public.pem \
    internal_service_token admin_password \
    at_api_key whatsapp_app_secret; do
    require_secret "$secret"
done
case "${EMAIL_PROVIDER:-brevo}" in
    brevo) require_secret brevo_api_key ;;
    mailjet) require_secret mailjet_api_key; require_secret mailjet_secret_key ;;
    *) fail "Unsupported EMAIL_PROVIDER: ${EMAIL_PROVIDER}" ;;
esac
if [[ "${SMS_PROVIDER:-africastalking}" != "africastalking" ]]; then
    fail "SMS_PROVIDER must be africastalking in production (console is rejected)."
fi
if [[ "${AT_USERNAME}" == "sandbox" ]]; then
    fail "AT_USERNAME must be the production Africa's Talking username, not 'sandbox'."
fi
case "$CORS_ALLOWED_ORIGINS" in
    *localhost*|*127.0.0.1*)
        fail "CORS_ALLOWED_ORIGINS must not contain localhost origins in production."
        ;;
esac
if [[ "${EMAIL_PROVIDER:-brevo}" == "console" ]]; then
    fail "EMAIL_PROVIDER=console is rejected in production."
fi
for rendered in "$GENERATED_DIR/traefik.yml" "$GENERATED_DIR/dynamic.yml" "$GENERATED_DIR/redis.conf"; do
    [[ -s "$rendered" ]] || fail "Missing rendered configuration: $rendered (run bootstrap.sh)"
done

compose config -q

# Certificates are issued with the HTTP-01 challenge on the first start, so the
# hostnames must already resolve. Fail before starting the stack instead of
# letting the smoke test time out with an opaque curl error.
if [[ "${SKIP_DNS_CHECK:-0}" != "1" ]]; then
    require_cmd getent
    for host in "$AUTH_HOST" "$INVENTORY_HOST" "$POS_HOST"; do
        if ! getent hosts "$host" >/dev/null 2>&1; then
            fail "DNS does not resolve $host. Create its A/AAAA record before deploying, or set SKIP_DNS_CHECK=1 to bypass this check."
        fi
    done
fi

log "Pulling images ${IMAGE_REGISTRY}/oryon-{identity,inventory,pos}:${IMAGE_TAG}"
if [[ "${SKIP_PULL:-0}" != "1" ]]; then
    if ! compose pull; then
        fail "Image pull failed. If the GHCR packages are private, log in first: printf '%s' \"\$GHCR_TOKEN\" | docker login ghcr.io -u <github-user> --password-stdin"
    fi
fi

log "Starting Postgres and Redis"
compose up -d postgres redis
wait_for_postgres

log "Applying database migrations"
"$SCRIPT_DIR/migrate.sh"

log "Seeding reference data and the first platform admin"
"$SCRIPT_DIR/seed.sh"

log "Starting the API and edge stack"
compose up -d --remove-orphans --wait --wait-timeout 300

log "Running smoke tests"
"$SCRIPT_DIR/smoke-test.sh"

log "Deployment complete."

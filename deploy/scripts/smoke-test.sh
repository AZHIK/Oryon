#!/usr/bin/env bash
# Verify the public edge: TLS works, HTTP redirects, HSTS is present, and
# internal/admin paths are not public. Run after every deployment.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

require_cmd curl
require_root
load_env

status_of() {
    curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "$1" || true
}

post_status_of() {
    curl -sS -o /dev/null -w '%{http_code}' --max-time 15 \
        -X POST -H 'Content-Type: application/json' --data '{}' "$1" || true
}

headers_of() {
    curl -sS -D - -o /dev/null --max-time 15 "$1" || true
}

wait_for_health() {
    local host="$1"
    local code=""
    for _ in $(seq 1 30); do
        code="$(status_of "https://$host/health")"
        if [[ "$code" == "200" ]]; then
            log "healthy  https://$host/health"
            return 0
        fi
        sleep 5
    done
    fail "Health check failed for https://$host/health (last HTTP $code)"
}

expect_redirect() {
    local host="$1"
    local code=""
    for _ in $(seq 1 12); do
        code="$(status_of "http://$host/health")"
        case "$code" in
            301|308)
                log "redirect http://$host -> https"
                return 0
                ;;
        esac
        sleep 5
    done
    fail "Expected HTTP->HTTPS redirect for $host, got HTTP $code"
}

expect_hsts() {
    local host="$1"
    local headers
    headers="$(headers_of "https://$host/health")"
    if ! grep -qi '^strict-transport-security:' <<<"$headers"; then
        fail "Missing HSTS header for https://$host/health"
    fi
    log "hsts     https://$host"
}

expect_not_public() {
    local url="$1"
    local code
    code="$(status_of "$url")"
    case "$code" in
        401|403|404) log "blocked  $url (HTTP $code)" ;;
        200) fail "This endpoint is publicly reachable: $url" ;;
        5*) fail "Upstream error for $url while checking exposure (HTTP $code)" ;;
        *) log "warning: unexpected status $code for $url" ;;
    esac
}

# Internal service endpoints are protected by Traefik deny-all, so an external
# request must be rejected at the edge with 403, not merely by application auth.
expect_edge_denied() {
    local url="$1"
    local code
    code="$(post_status_of "$url")"
    [[ "$code" == "403" ]] || fail "Expected edge denial (403) for $url, got HTTP $code"
    log "denied   $url (HTTP 403)"
}

for host in "$AUTH_HOST" "$INVENTORY_HOST" "$POS_HOST"; do
    expect_redirect "$host"
    wait_for_health "$host"
    expect_hsts "$host"
done

# Identity: admin, platform-auth, docs, OpenAPI, and readiness paths must not be
# reachable from the public internet. /admin is the real router prefix.
expect_not_public "https://$AUTH_HOST/admin"
expect_not_public "https://$AUTH_HOST/admin/users"
expect_not_public "https://$AUTH_HOST/admin/groups"
expect_not_public "https://$AUTH_HOST/docs"
expect_not_public "https://$AUTH_HOST/openapi.json"
expect_not_public "https://$AUTH_HOST/health/ready"
expect_not_public "https://$AUTH_HOST/api/v1/auth/platform/login"

# Inventory: docs/readiness are restricted and internal events are edge-denied.
expect_not_public "https://$INVENTORY_HOST/docs"
expect_not_public "https://$INVENTORY_HOST/health/ready"
expect_edge_denied "https://$INVENTORY_HOST/api/v1/internal/businesses/00000000-0000-0000-0000-000000000000/stock-events"

# POS: docs/readiness are restricted.
expect_not_public "https://$POS_HOST/docs"
expect_not_public "https://$POS_HOST/health/ready"

log "Smoke tests passed."

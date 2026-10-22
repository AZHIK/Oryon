#!/usr/bin/env bash
# Restrict Docker-published ports at the host firewall.
#
# Docker writes its own iptables rules that bypass UFW, so the DOCKER-USER
# chain is the authoritative ingress filter. Traefik is the only service with
# published ports; allow only 80/443 from the internet and drop everything
# else that is forwarded from the default interface.
set -euo pipefail

IFACE="${DOCKER_INGRESS_IFACE:-$(ip route show default | awk '{print $5; exit}')}"
[[ -n "$IFACE" ]] || { echo "Cannot detect the default network interface" >&2; exit 1; }

apply_family() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || return 0

    "$cmd" -N DOCKER-USER 2>/dev/null || true

    add_rule() {
        local table="$1"
        shift
        if ! "$table" -C DOCKER-USER "$@" 2>/dev/null; then
            "$table" -I DOCKER-USER 1 "$@"
        fi
    }

    add_rule "$cmd" -m conntrack --ctstate RELATED,ESTABLISHED -j RETURN
    add_rule "$cmd" -i lo -j RETURN
    add_rule "$cmd" -i "$IFACE" -p tcp -m multiport --dports 80,443 -j RETURN

    # Keep the drop rule at the end so future allow rules can be prepended.
    if ! "$cmd" -C DOCKER-USER -i "$IFACE" -m comment --comment "oryonfoods edge" -j DROP 2>/dev/null; then
        "$cmd" -A DOCKER-USER -i "$IFACE" -m comment --comment "oryonfoods edge" -j DROP
    fi
}

apply_family iptables
# IPv6 may be disabled on the VPS; do not fail the unit if so.
apply_family ip6tables || true

echo "Docker ingress restricted on interface $IFACE to TCP 80/443."

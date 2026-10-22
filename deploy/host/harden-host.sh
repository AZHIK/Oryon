#!/usr/bin/env bash
# Baseline hardening for a fresh Ubuntu 24.04 VPS running the Oryon Foods stack.
#
# This is intentionally conservative: it enables UFW, fail2ban, unattended
# upgrades, journald limits, Docker ingress filtering, and the sysctl profile.
# SSH password hardening is opt-in because enabling it before a working SSH key
# would lock you out.
#
# Run as root on the VPS after installing Docker and before the first deploy.
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "Run as root" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SSH_PORT="${SSH_PORT:-22}"
RESTART_DOCKER="${RESTART_DOCKER:-0}"
SSH_HARDEN="${SSH_HARDEN:-0}"
SET_TIMEZONE="${SET_TIMEZONE:-UTC}"

log() { printf '[harden] %s\n' "$*"; }

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates curl fail2ban iptables python3 restic ufw unattended-upgrades util-linux

# ── Kernel/network profile ───────────────────────────────────
install -m 644 "$SCRIPT_DIR/sysctl-oryonfoods.conf" /etc/sysctl.d/99-oryonfoods.conf
sysctl --system >/dev/null

if [[ -n "$SET_TIMEZONE" ]]; then
    timedatectl set-timezone "$SET_TIMEZONE"
fi

# ── journald retention ───────────────────────────────────────
install -d -m 755 /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/99-oryonfoods.conf <<'EOF'
[Journal]
SystemMaxUse=1G
SystemKeepFree=2G
MaxRetentionSec=30day
EOF
systemctl restart systemd-journald

# ── Docker daemon defaults ───────────────────────────────────
if command -v docker >/dev/null 2>&1; then
    if [[ -f /etc/docker/daemon.json ]]; then
        cp -a /etc/docker/daemon.json "/etc/docker/daemon.json.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    fi
    install -m 644 "$SCRIPT_DIR/daemon.json" /etc/docker/daemon.json
    python3 -m json.tool /etc/docker/daemon.json >/dev/null
    log "Docker daemon configuration installed."
    if [[ "$RESTART_DOCKER" == "1" ]]; then
        log "Restarting Docker (containers will restart according to their policy)."
        systemctl restart docker
    else
        log "Docker not restarted. Run 'systemctl restart docker' during a maintenance window."
    fi
else
    log "Docker is not installed yet; skipping daemon.json."
fi

# ── Host firewall ────────────────────────────────────────────
ufw default deny incoming
ufw default allow outgoing
ufw limit "$SSH_PORT/tcp"
ufw allow 80,443/tcp
ufw --force enable
log "UFW enabled: SSH $SSH_PORT, HTTP 80, HTTPS 443."

# ── Docker ingress filtering (DOCKER-USER) ───────────────────
install -d -m 755 /opt/oryonfoods/host
install -m 755 "$SCRIPT_DIR/docker-user-firewall.sh" /opt/oryonfoods/host/docker-user-firewall.sh
if [[ -f "$DEPLOY_DIR/systemd/oryonfoods-firewall.service" ]]; then
    install -m 644 "$DEPLOY_DIR/systemd/oryonfoods-firewall.service" \
        /etc/systemd/system/oryonfoods-firewall.service
    systemctl daemon-reload
    systemctl enable --now oryonfoods-firewall.service
else
    /opt/oryonfoods/host/docker-user-firewall.sh
fi

# ── fail2ban ─────────────────────────────────────────────────
install -d -m 755 /etc/fail2ban/jail.d
cat > /etc/fail2ban/jail.d/oryonfoods.local <<EOF
[sshd]
enabled = true
port = $SSH_PORT
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
EOF
systemctl enable --now fail2ban

# ── Unattended security updates ──────────────────────────────
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
systemctl enable --now unattended-upgrades

# ── SSH hardening (opt-in) ───────────────────────────────────
if [[ "$SSH_HARDEN" == "1" ]]; then
    if [[ ! -s /root/.ssh/authorized_keys ]]; then
        echo "Refusing SSH hardening: /root/.ssh/authorized_keys is missing or empty." >&2
        echo "Install your public key and verify key-based login first." >&2
        exit 1
    fi
    install -d -m 755 /etc/ssh/sshd_config.d
    if [[ -f /etc/ssh/sshd_config.d/99-oryonfoods.conf ]]; then
        cp -a /etc/ssh/sshd_config.d/99-oryonfoods.conf \
            "/etc/ssh/sshd_config.d/99-oryonfoods.conf.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    fi
    install -m 600 "$SCRIPT_DIR/sshd-hardening.conf.example" \
        /etc/ssh/sshd_config.d/99-oryonfoods.conf
    sshd -t
    systemctl reload ssh 2>/dev/null || systemctl reload sshd
    log "SSH password authentication disabled. Keep this session open until a new login is tested."
else
    log "SSH hardening skipped. Review host/sshd-hardening.conf.example and set SSH_HARDEN=1 when ready."
fi

log "Host baseline complete."

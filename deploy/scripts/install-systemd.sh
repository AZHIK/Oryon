#!/usr/bin/env bash
# Install the systemd units for the production package.
#
# The backup timer is enabled only when ENABLE_BACKUP=1 so a fresh host does
# not start failing nightly backups before a restic repository is configured.
set -euo pipefail

[[ "$(id -u)" -eq 0 ]] || { echo "Run as root" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

install -m 644 "$DEPLOY_DIR/systemd/oryonfoods-firewall.service" \
    /etc/systemd/system/oryonfoods-firewall.service
systemctl daemon-reload
systemctl enable --now oryonfoods-firewall.service

if [[ "${ENABLE_BACKUP:-0}" == "1" ]]; then
    install -m 644 "$DEPLOY_DIR/systemd/oryonfoods-backup.service" \
        /etc/systemd/system/oryonfoods-backup.service
    install -m 644 "$DEPLOY_DIR/systemd/oryonfoods-backup.timer" \
        /etc/systemd/system/oryonfoods-backup.timer
    systemctl daemon-reload
    systemctl enable --now oryonfoods-backup.timer
    echo "Backup timer enabled."
else
    echo "Backup units not enabled. Re-run with ENABLE_BACKUP=1 after configuring restic."
fi

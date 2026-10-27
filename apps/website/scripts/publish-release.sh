#!/usr/bin/env bash
#
# Publish a Windows installer to the website's download directory.
#
# The site probes /downloads/latest.json and the stable .exe alias at runtime,
# so publishing a new build does not require a website rebuild or redeploy.
#
# Usage:
#   ./publish-release.sh <installer.exe> [version]
#
# Environment:
#   ORYON_DOWNLOADS_DIR      target directory (default: /srv/oryon/downloads)
#   ORYON_DOWNLOAD_BASE_URL  public base URL (default: https://oryonfoods.com/downloads)
#
# Run this on the host that serves the website, after copying the installer
# there. The directory is mounted read-only into the Nginx container.

set -euo pipefail

DOWNLOADS_DIR="${ORYON_DOWNLOADS_DIR:-/srv/oryon/downloads}"
BASE_URL="${ORYON_DOWNLOAD_BASE_URL:-https://oryonfoods.com/downloads}"
STABLE_NAME="Oryon-windows-x64-setup.exe"

usage() {
  cat <<'EOF'
Publish a Windows installer to the website's download directory.

Usage:
  ./publish-release.sh <installer.exe> [version]

  version defaults to the version in Oryon-<version>-windows-x64-setup.exe.

Environment:
  ORYON_DOWNLOADS_DIR      target directory (default: /srv/oryon/downloads)
  ORYON_DOWNLOAD_BASE_URL  public base URL (default: https://oryonfoods.com/downloads)

The script writes:
  Oryon-<version>-windows-x64-setup.exe   versioned, immutable
  Oryon-windows-x64-setup.exe             stable alias -> newest version
  SHA256SUMS.txt                          checksums for every version
  latest.json                             version, size, checksum for the site
EOF
}

case "${1:-}" in
  -h | --help | "")
    usage
    exit 0
    ;;
esac

INSTALLER="$1"
VERSION="${2:-}"

if [[ ! -f "$INSTALLER" ]]; then
  echo "error: installer not found: $INSTALLER" >&2
  exit 1
fi

FILE_NAME="$(basename "$INSTALLER")"

if [[ -z "$VERSION" ]]; then
  if [[ "$FILE_NAME" =~ ^Oryon-([0-9]+\.[0-9]+\.[0-9]+)-windows-x64-setup\.exe$ ]]; then
    VERSION="${BASH_REMATCH[1]}"
  else
    echo "error: could not read the version from '$FILE_NAME'." >&2
    echo "       pass it explicitly: $0 '$INSTALLER' 1.0.0" >&2
    exit 1
  fi
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: version must be major.minor.patch, got '$VERSION'" >&2
  exit 1
fi

TARGET_NAME="Oryon-${VERSION}-windows-x64-setup.exe"
TARGET_PATH="${DOWNLOADS_DIR}/${TARGET_NAME}"
STABLE_PATH="${DOWNLOADS_DIR}/${STABLE_NAME}"

install -d -m 755 "$DOWNLOADS_DIR"

# Stage then rename, so a visitor never downloads a half-written file.
TMP_PATH="${DOWNLOADS_DIR}/.${TARGET_NAME}.tmp"
cp -- "$INSTALLER" "$TMP_PATH"
chmod 644 "$TMP_PATH"
mv -f "$TMP_PATH" "$TARGET_PATH"

# The website links to this stable alias; point it at the newest build.
ln -sfn "$TARGET_NAME" "$STABLE_PATH"

SIZE_BYTES="$(stat -c '%s' "$TARGET_PATH")"
SIZE_MB="$(awk -v bytes="$SIZE_BYTES" 'BEGIN { printf "%.1f", bytes / 1048576 }')"
SHA256="$(sha256sum "$TARGET_PATH" | awk '{ print $1 }')"

# Keep checksums for every version still in the directory.
(
  cd "$DOWNLOADS_DIR"
  sha256sum Oryon-[0-9]*-windows-x64-setup.exe > SHA256SUMS.txt
)

# Write the manifest atomically. The site reads this to show version and size.
MANIFEST_TMP="${DOWNLOADS_DIR}/.latest.json.tmp"
cat > "$MANIFEST_TMP" <<JSON
{
  "version": "${VERSION}",
  "sizeMb": ${SIZE_MB},
  "sha256": "${SHA256}",
  "url": "${BASE_URL}/${STABLE_NAME}",
  "releasedAt": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
}
JSON
chmod 644 "$MANIFEST_TMP" "$DOWNLOADS_DIR/SHA256SUMS.txt"
mv -f "$MANIFEST_TMP" "${DOWNLOADS_DIR}/latest.json"

echo "Published ${TARGET_NAME}"
echo "  url:    ${BASE_URL}/${STABLE_NAME}"
echo "  size:   ${SIZE_MB} MB"
echo "  sha256: ${SHA256}"

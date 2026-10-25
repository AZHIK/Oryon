#!/usr/bin/env bash
#
# Regenerates every platform launcher icon from
# apps/restaurant_app/assets/app_icons/app_icon.png.
#
# The source artwork is a transparent PNG, so all outputs are flattened onto
# white: iOS/App Store icons must be fully opaque, and a shared background
# keeps the icon identical across Android, iOS, web and Windows.
#
# Requires ImageMagick 7 (`magick`).
#
# Usage: scripts/generate_app_icons.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/apps/restaurant_app"
SRC="$APP/assets/app_icons/app_icon.png"

if ! command -v magick >/dev/null 2>&1; then
  echo "error: ImageMagick 7 is required (the 'magick' command was not found)." >&2
  exit 1
fi
if [[ ! -f "$SRC" ]]; then
  echo "error: source icon not found: $SRC" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Artwork occupies 88% of the canvas, leaving breathing room for rounded
# launcher masks without shrinking the icon needlessly.
MASTER="$WORK/master-1024.png"
magick "$SRC" \
  -background white -alpha remove -alpha off \
  -filter Lanczos -resize '901x901' \
  -gravity center -background white -extent 1024x1024 \
  -strip "$MASTER"

# make_icon <size> <destination>
make_icon() {
  magick "$MASTER" -filter Lanczos -resize "${1}x${1}" -strip "$2"
}

# make_maskable_icon <size> <destination>
# Keeps the artwork inside the maskable safe zone (content ends up at ~70% of
# the canvas) while filling the full square with the white background.
make_maskable_icon() {
  local size="$1" inner="$(( $1 * 80 / 100 ))"
  magick "$MASTER" -filter Lanczos -resize "${inner}x${inner}" \
    -gravity center -background white -extent "${size}x${size}" -strip "$2"
}

# --- Android -----------------------------------------------------------------
ANDROID_RES="$APP/android/app/src/main/res"
make_icon 48 "$ANDROID_RES/mipmap-mdpi/ic_launcher.png"
make_icon 72 "$ANDROID_RES/mipmap-hdpi/ic_launcher.png"
make_icon 96 "$ANDROID_RES/mipmap-xhdpi/ic_launcher.png"
make_icon 144 "$ANDROID_RES/mipmap-xxhdpi/ic_launcher.png"
make_icon 192 "$ANDROID_RES/mipmap-xxxhdpi/ic_launcher.png"

# --- iOS ---------------------------------------------------------------------
IOS_DIR="$APP/ios/Runner/Assets.xcassets/AppIcon.appiconset"
declare -A IOS_SIZES=(
  ["Icon-App-20x20@1x.png"]=20
  ["Icon-App-20x20@2x.png"]=40
  ["Icon-App-20x20@3x.png"]=60
  ["Icon-App-29x29@1x.png"]=29
  ["Icon-App-29x29@2x.png"]=58
  ["Icon-App-29x29@3x.png"]=87
  ["Icon-App-40x40@1x.png"]=40
  ["Icon-App-40x40@2x.png"]=80
  ["Icon-App-40x40@3x.png"]=120
  ["Icon-App-60x60@2x.png"]=120
  ["Icon-App-60x60@3x.png"]=180
  ["Icon-App-76x76@1x.png"]=76
  ["Icon-App-76x76@2x.png"]=152
  ["Icon-App-83.5x83.5@2x.png"]=167
  ["Icon-App-1024x1024@1x.png"]=1024
)
for name in "${!IOS_SIZES[@]}"; do
  make_icon "${IOS_SIZES[$name]}" "$IOS_DIR/$name"
done

# --- Web ---------------------------------------------------------------------
WEB_DIR="$APP/web"
make_icon 32 "$WEB_DIR/favicon.png"
make_icon 192 "$WEB_DIR/icons/Icon-192.png"
make_icon 512 "$WEB_DIR/icons/Icon-512.png"
make_maskable_icon 192 "$WEB_DIR/icons/Icon-maskable-192.png"
make_maskable_icon 512 "$WEB_DIR/icons/Icon-maskable-512.png"

# --- Windows -----------------------------------------------------------------
magick "$MASTER" -define icon:auto-resize=256,128,64,48,32,24,16 \
  "$APP/windows/runner/resources/app_icon.ico"

echo "App icons regenerated from ${SRC#"$ROOT"/}"

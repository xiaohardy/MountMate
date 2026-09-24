#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

work="$(mktemp -d "${TMPDIR:-/tmp}/mountmate-icon.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/AppIcon.iconset"
swift scripts/draw-icon.swift Resources/AppIcon.png

for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" Resources/AppIcon.png --out "$work/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -s format png -z "$double" "$double" Resources/AppIcon.png --out "$work/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$work/AppIcon.iconset" -o Resources/AppIcon.icns
echo "Created Resources/AppIcon.png and Resources/AppIcon.icns"

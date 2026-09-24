#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
build_path="$(mktemp -d "${TMPDIR:-/tmp}/mountmate-build.XXXXXX")"
trap 'rm -rf "$build_path"' EXIT
mkdir -p "$build_path/module-cache" "$build_path/cache"
export CLANG_MODULE_CACHE_PATH="$build_path/module-cache"
export XDG_CACHE_HOME="$build_path/cache"

swift build --scratch-path "$build_path" --disable-sandbox -c release
binary_dir="$(swift build --scratch-path "$build_path" --disable-sandbox -c release --show-bin-path)"
if (( $# > 0 )); then
    app="$1"
else
    app="$(mktemp -d "${TMPDIR:-/tmp}/mountmate-app.XXXXXX")/MountMate.app"
fi
test ! -e "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/MountMate" "$app/Contents/MacOS/MountMate"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp Resources/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"
cp -R "$binary_dir/MountMate_MountMateCore.bundle" "$app/Contents/Resources/"
chmod +x "$app/Contents/MacOS/MountMate"

# Local test builds are ad hoc signed; public downloads need Developer ID signing and notarization.
# Finder metadata is not part of the signature and must be removed before signing.
xattr -cr "$app"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
file "$app/Contents/MacOS/MountMate" | grep -q 'arm64'
test -f "$app/Contents/Resources/AppIcon.icns"
resource_bundle="$app/Contents/Resources/MountMate_MountMateCore.bundle"
test -s "$resource_bundle/en.json" || test -s "$resource_bundle/Contents/Resources/en.json"

echo "Created and verified $app"

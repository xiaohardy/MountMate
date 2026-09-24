#!/bin/zsh
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
build_path="$(mktemp -d "${TMPDIR:-/tmp}/mountmate-build.XXXXXX")"
trap 'rm -rf "$build_path"' EXIT
mkdir -p "$build_path/module-cache" "$build_path/cache" "$build_path/source"
cp "$project_root/Package.swift" "$build_path/source/Package.swift"
cp -R "$project_root/Sources" "$build_path/source/Sources"
cp -R "$project_root/Tests" "$build_path/source/Tests"
export CLANG_MODULE_CACHE_PATH="$build_path/module-cache"
export XDG_CACHE_HOME="$build_path/cache"

if (( $# > 0 )); then
    case "$1" in
        /*) app="$1" ;;
        *) app="$project_root/$1" ;;
    esac
else
    app="$(mktemp -d "${TMPDIR:-/tmp}/mountmate-app.XXXXXX")/MountMate.app"
fi
cd "$build_path/source"
swift build --scratch-path "$build_path/scratch" --disable-sandbox -c release
binary_dir="$(swift build --scratch-path "$build_path/scratch" --disable-sandbox -c release --show-bin-path)"
test ! -e "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/MountMate" "$app/Contents/MacOS/MountMate"
cp "$project_root/Resources/Info.plist" "$app/Contents/Info.plist"
cp "$project_root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
cp -R "$binary_dir/MountMate_MountMateCore.bundle" "$app/Contents/Resources/"
for localization in "$project_root"/Resources/*.lproj; do
    cp -R "$localization" "$app/Contents/Resources/"
done
chmod +x "$app/Contents/MacOS/MountMate"

# This script creates ad hoc signed preview builds. A normal trusted release needs Developer ID signing and notarization.
# Finder metadata is not part of the signature and must be removed before signing.
xattr -cr "$app"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
file "$app/Contents/MacOS/MountMate" | grep -q 'arm64'
test -f "$app/Contents/Resources/AppIcon.icns"
resource_bundle="$app/Contents/Resources/MountMate_MountMateCore.bundle"
test -s "$resource_bundle/en.json" || test -s "$resource_bundle/Contents/Resources/en.json"

echo "Created and verified $app"

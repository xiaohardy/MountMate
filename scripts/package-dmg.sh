#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."

version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info.plist)"
dmg="$PWD/dist/MountMate-$version-build$build-preview-arm64.dmg"
work="$(mktemp -d "${TMPDIR:-/tmp}/mountmate-dmg.XXXXXX")"
mountpoint="$work/mounted"
attached=0
cleanup() {
    if (( attached )); then hdiutil detach "$mountpoint" -quiet || true; fi
    rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/stage" "$mountpoint" dist
scripts/build-app.sh "$work/stage/MountMate.app"
if LC_ALL=C grep -a -Eq '/Users/|/home/' "$work/stage/MountMate.app/Contents/MacOS/MountMate"; then
    echo "Installer executable contains a personal build path." >&2
    exit 1
fi
ln -s /Applications "$work/stage/Applications"
hdiutil create -quiet -ov -format UDZO -fs HFS+ -volname "MountMate $version" -srcfolder "$work/stage" "$dmg"
hdiutil verify "$dmg" >/dev/null
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$mountpoint" "$dmg"
attached=1
installed="$mountpoint/MountMate.app"
test "$(find "$mountpoint" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" = 2
codesign --verify --strict "$installed"
file "$installed/Contents/MacOS/MountMate" | grep -q 'arm64'
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$installed/Contents/Info.plist")" = "$version"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$installed/Contents/Info.plist")" = "$build"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$installed/Contents/Info.plist")" = true
test -s "$installed/Contents/Resources/AppIcon.icns"
resource_bundle="$installed/Contents/Resources/MountMate_MountMateCore.bundle"
for language in en de es fr ja pt-BR zh-Hans zh-Hant; do
    test -s "$resource_bundle/$language.json" || test -s "$resource_bundle/Contents/Resources/$language.json"
    test -s "$installed/Contents/Resources/$language.lproj/InfoPlist.strings"
done
test "$(readlink "$mountpoint/Applications")" = /Applications
echo "Verified installer: $dmg"
shasum -a 256 "$dmg"

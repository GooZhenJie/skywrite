#!/bin/bash
# Adds a release to appcast.xml, the list of versions that Skywrite's "Check for Updates…" reads. SUFeedURL in
# Skywrite/Info.plist points at this file on the main branch.
#
#   scripts/update-appcast.sh <release-notes.md>
#
# Run it after scripts/build-release.sh "Skywrite Code Signing", once per release. It signs
# .build/release/Skywrite-<version>.zip with the EdDSA private key in your login keychain, made once with Sparkle's
# generate_keys, and adds an item whose download is that zip attached to the GitHub release v<version>. The release
# notes are Markdown; Sparkle shows them in its update window. Translations of the notes sit next to them, named
# <version>.zh-Hans.md and <version>.zh-Hant.md, and are added by scripts/add-translated-release-notes.py.
#
# Publish the GitHub release with the zip before pushing the new appcast.xml to main: as soon as main has the new item,
# Skywrite offers the update to everyone who checks.
#
# To try an update on your own Mac before publishing:
#   --download-url-prefix <url>   where the zip will be downloaded from (default: the GitHub release for this version)
#   --appcast <path>              the appcast to add the release to (default: appcast.xml in this checkout)
set -euo pipefail

cd "$(dirname "$0")/.."
appcast="appcast.xml"
prefix=""
notes=""
while [ $# -gt 0 ]; do
    case "$1" in
        --download-url-prefix) prefix="$2"; shift 2 ;;
        --appcast) appcast="$2"; shift 2 ;;
        *) notes="$1"; shift ;;
    esac
done
if [ -z "$notes" ] || [ ! -f "$notes" ]; then
    echo "Usage: scripts/update-appcast.sh <release-notes.md> [--download-url-prefix <url>] [--appcast <path>]" >&2
    exit 1
fi

output=".build/release"
app="$output/DerivedData/Build/Products/Release/Skywrite.app"
tools="$output/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")
zip="$output/Skywrite-$version.zip"
if [ ! -f "$zip" ]; then
    echo "$zip is missing. Run scripts/build-release.sh first." >&2
    exit 1
fi
prefix="${prefix:-https://github.com/GooZhenJie/skywrite/releases/download/v$version/}"

# generate_appcast reads every archive in a folder, so the folder holds only this release's zip, its notes (same name,
# .md) and the current appcast. The older items already in the appcast are kept as they are.
staging="$output/appcast"
rm -rf "$staging"
mkdir -p "$staging"
cp "$zip" "$staging/"
cp "$notes" "$staging/Skywrite-$version.md"
if [ -f "$appcast" ]; then
    cp "$appcast" "$staging/appcast.xml"
fi

"$tools/generate_appcast" "$staging" \
    -o "$staging/appcast.xml" \
    --download-url-prefix "$prefix" \
    --embed-release-notes \
    --link "https://github.com/GooZhenJie/skywrite/releases" \
    --maximum-versions 0 \
    --maximum-deltas 0
cp "$staging/appcast.xml" "$appcast"
python3 scripts/add-translated-release-notes.py "$appcast" "$version" "$notes"
echo "Added Skywrite $version to $appcast, downloading from $prefix"

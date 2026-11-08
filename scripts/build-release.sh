#!/bin/bash
# Builds Skywrite for release: a signed Skywrite.app and a zip of it to attach to a GitHub release.
#
#   scripts/build-release.sh                          # ad-hoc signature, which anyone can build
#   scripts/build-release.sh "Skywrite Code Signing"  # sign with a certificate in your keychain
#
# Anything after the certificate is passed to xcodebuild as build settings, for trying an update on your own Mac, e.g.
#   scripts/build-release.sh "Skywrite Code Signing" MARKETING_VERSION=0.1.1 CURRENT_PROJECT_VERSION=2 \
#       SKYWRITE_FEED_URL=http://127.0.0.1:<port>/appcast.xml
#
# Official releases are signed with the self-signed "Skywrite Code Signing" certificate. As long as every release is
# signed with the same certificate, macOS keeps Skywrite's Accessibility permission when people update. An ad-hoc
# signature is different for every build, so macOS asks for the permission again after each one.
#
# Everything goes to .build/release/.
set -euo pipefail

cd "$(dirname "$0")/.."
identity="${1:--}"
shift || true
output=".build/release"
app="$output/DerivedData/Build/Products/Release/Skywrite.app"

# ARCHS=arm64 builds for Apple silicon only. Skywrite has never been run on an Intel Mac, so releases don't include an
# Intel build; on an Intel Mac, macOS says the app isn't supported instead of running untested code. Sparkle.framework
# stays as Sparkle ships it. CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO leaves out get-task-allow, which lets debuggers attach
# and only belongs in builds you run from Xcode. Xcode 27 logs a harmless "IDESchemeActionsInvocationRecord ... missing
# operatingSystemVersion" line for the generic destination; it's filtered out so that only real warnings and errors show.
xcodebuild -quiet \
    -project Skywrite.xcodeproj \
    -scheme Skywrite \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$output/DerivedData" \
    ARCHS=arm64 \
    CODE_SIGN_STYLE=Manual \
    "CODE_SIGN_IDENTITY=$identity" \
    DEVELOPMENT_TEAM= \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    ${@+"$@"} \
    clean build \
    2> >(grep -v "IDESchemeActionsInvocationRecord" >&2)

# --deep also checks Sparkle.framework and the helpers inside it.
codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$app/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$app/Contents/Info.plist")
zip="$output/Skywrite-$version.zip"
rm -f "$zip"
# ditto keeps the bundle's symbolic links and extended attributes, which a signed app needs to stay valid. These are
# the options Sparkle's "Publishing an update" page gives for a zip (read 2026-11-08).
ditto -c -k --sequesterRsrc --keepParent "$app" "$zip"

echo "Skywrite $version ($build), signed as: $(codesign -d -r- "$app" 2>&1 | sed -nE 's/^(# )?designated => //p')"
echo "App: $app"
echo "Zip: $zip"
shasum -a 256 "$zip"

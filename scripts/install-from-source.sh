#!/bin/bash
# Builds Skywrite from this checkout and installs it in /Applications, replacing the copy that's there.
#
#   scripts/install-from-source.sh                       # ad-hoc signature
#   scripts/install-from-source.sh "<your certificate>"  # sign with a certificate in your keychain
#
# Needs macOS 26 and Xcode. Your notes and settings aren't kept inside the app, so replacing it keeps them. The copy
# being replaced goes to the Trash.
#
# A build you make yourself isn't marked as downloaded, so macOS opens it without asking. But with an ad-hoc signature
# macOS sees every build as a new app: if you use Press Twice to make notes, turn Skywrite off and on again in
# System Settings > Privacy & Security > Accessibility after each install.
set -euo pipefail

cd "$(dirname "$0")/.."
scripts/build-release.sh "$@"
app=".build/release/DerivedData/Build/Products/Release/Skywrite.app"
target="/Applications/Skywrite.app"
bundle_identifier="io.github.goozhenjie.skywrite"

running() {
    pgrep -qx Skywrite
}

# Copy the new app next to the old one first, so a failed copy leaves the installed Skywrite untouched.
staged="$target.new"
if [ -e "$staged" ]; then
    /usr/bin/trash "$staged"
fi
ditto "$app" "$staged"

if running; then
    echo "Quitting Skywrite…"
    # Asks Skywrite to quit the way its Quit command does, so it saves its notes first. Done through AppKit rather
    # than an Apple Event, which would need Automation permission for Terminal.
    osascript -l JavaScript -e "
        ObjC.import('AppKit');
        const apps = \$.NSRunningApplication.runningApplicationsWithBundleIdentifier('$bundle_identifier');
        for (let index = 0; index < apps.count; index++) { apps.objectAtIndex(index).terminate; }
    " > /dev/null
    for _ in $(seq 1 50); do
        running || break
        sleep 0.2
    done
    if running; then
        /usr/bin/trash "$staged"
        echo "Skywrite is still running. Quit it from its menu bar icon, then run this script again." >&2
        exit 1
    fi
fi

if [ -e "$target" ]; then
    /usr/bin/trash "$target"
fi
mv "$staged" "$target"
# Finder and the Dock only notice a new icon when the app's modification date changes.
touch "$target"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$target"
open "$target"
echo "Installed $target"

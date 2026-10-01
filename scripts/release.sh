#!/bin/zsh
# Builds a Developer ID–signed, notarized, stapled Snap.app and zips it for a GitHub release.
# One-time setup: xcrun notarytool store-credentials snap-notary --apple-id <id> --team-id <team>
set -euo pipefail
cd "${0:A:h}/.."
profile="${SNAP_NOTARY_PROFILE:-snap-notary}"
identities="$(security find-identity -v -p codesigning)"
export SNAP_SIGNING_IDENTITY="${SNAP_SIGNING_IDENTITY:-$(print -r -- "$identities" | awk '/"Developer ID Application:/ { print $2 }')}"
if [[ -z "$SNAP_SIGNING_IDENTITY" || "$SNAP_SIGNING_IDENTITY" == *$'\n'* ]]; then
    print -u2 "Releases need exactly one Developer ID Application identity, or set SNAP_SIGNING_IDENTITY."
    exit 1
fi

./scripts/build.sh release
bundle="$PWD/build/Snap.app"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist")"
zip="$PWD/build/Snap-$version.zip"

rm -f "$zip"
ditto -c -k --keepParent "$bundle" "$zip"
xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait
xcrun stapler staple "$bundle"
rm -f "$zip"
ditto -c -k --keepParent "$bundle" "$zip"
spctl --assess --type execute --verbose=2 "$bundle"
print "Release archive: $zip"

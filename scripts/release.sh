#!/bin/zsh
# Builds a Developer ID–signed, notarized, stapled Snap.app and packages it as a zip and a DMG for a GitHub release.
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

# The DMG holds the stapled app plus an Applications link for drag-to-install, and is notarized on its own.
dmg="$PWD/build/Snap-$version.dmg"
staging="$PWD/build/dmg"
rm -rf "$staging" "$dmg"
mkdir -p "$staging"
ditto "$bundle" "$staging/Snap.app"
ln -s /Applications "$staging/Applications"
hdiutil create -volname "Snap $version" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$dmg"
rm -rf "$staging"
codesign --force --sign "$SNAP_SIGNING_IDENTITY" --timestamp "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
xcrun stapler staple "$dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
print "Release archives: $zip $dmg"

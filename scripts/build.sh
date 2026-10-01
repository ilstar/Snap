#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
configuration="${1:-debug}"
if [[ "$configuration" != debug && "$configuration" != release ]]; then
    print -u2 "Usage: scripts/build.sh [debug|release]"
    exit 1
fi
if pgrep -x Snap > /dev/null; then
    print -u2 "Quit Snap before rebuilding. Replacing a running app can invalidate its permission identity."
    exit 1
fi

# A certificate-backed designated requirement stays stable when the executable changes.
# Ad-hoc signatures instead identify one exact build, so they lose TCC grants on rebuild.
signing_identity="${SNAP_SIGNING_IDENTITY:-}"
if [[ -z "$signing_identity" ]]; then
    identities="$(security find-identity -v -p codesigning)"
    signing_identity="$(print -r -- "$identities" | awk '/"Developer ID Application:/ { print $2 }')"
    if [[ -z "$signing_identity" ]]; then
        signing_identity="$(print -r -- "$identities" | awk '/"Apple Development:/ { print $2 }')"
    fi
    if [[ -z "$signing_identity" || "$signing_identity" == *$'\n'* ]]; then
        print -u2 "Set SNAP_SIGNING_IDENTITY to a code-signing certificate name or SHA-1."
        print -u2 "For disposable builds only, SNAP_SIGNING_IDENTITY=- opts into ad-hoc signing; permissions will not survive rebuilds."
        exit 1
    fi
fi
if [[ "$signing_identity" == "-" ]]; then
    print -u2 "Warning: ad-hoc signing requires granting Accessibility access again after each changed build."
fi
export CLANG_MODULE_CACHE_PATH="$PWD/build/module-cache"
export SWIFT_MODULECACHE_PATH="$PWD/build/module-cache"
swift build --disable-sandbox --scratch-path build/swift -c "$configuration"
bin_path="$(swift build --disable-sandbox --scratch-path build/swift -c "$configuration" --show-bin-path)"
bundle="$PWD/build/Snap.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$bin_path/Snap" "$bundle/Contents/MacOS/Snap"
cp Resources/Info.plist "$bundle/Contents/Info.plist"
swift scripts/make-icon.swift "$PWD/build"
iconutil -c icns "$PWD/build/Snap.iconset" -o "$bundle/Contents/Resources/Snap.icns"
sign_options=()
if [[ "$signing_identity" != "-" ]]; then
    # Hardened runtime and a secure timestamp are required for notarization.
    sign_options=(--options runtime --timestamp)
fi
codesign --force --sign "$signing_identity" --identifier com.fred.snap "${sign_options[@]}" "$bundle"
codesign --verify --deep --strict "$bundle"
print "Built $bundle"

#!/usr/bin/env bash
# Signs (Developer ID + hardened runtime), notarizes, staples and packages the macOS app.
#   tools/ci/macos_package.sh <Diceroll.app> <version> <out_dir>
# Produces <out_dir>/Diceroll-<version>-macos.zip (ditto) and Diceroll-<version>-macos.dmg.
#
# Every signing step is optional and driven by the environment (CI secrets):
#   MACOS_CERT_P12_BASE64 + MACOS_CERT_PASSWORD   "Developer ID Application" cert (.p12, base64)
#   MACOS_SIGN_IDENTITY                           optional; default: the first Developer ID Application
#   APPLE_API_KEY_P8 + APPLE_API_KEY_ID + APPLE_API_ISSUER_ID   App Store Connect API key
#                                                 (notarytool; team key with Developer access)
# Without a certificate the app keeps Godot's ad-hoc signature (users must right-click > Open,
# or run `xattr -dr com.apple.quarantine Diceroll.app`); without an API key it's signed but
# not notarized. Secrets are written only to $RUNNER_TEMP and removed on exit.
set -euo pipefail
app="$1"
version="$2"
out="$3"
[ -d "$app" ] || { echo "macos_package: no app at $app" >&2; exit 1; }
mkdir -p "$out"
tmp="$(mktemp -d "${RUNNER_TEMP:-/tmp}/macsign.XXXXXX")"
keychain="$tmp/signing.keychain-db"
cleanup() {
	security delete-keychain "$keychain" >/dev/null 2>&1 || true
	rm -rf "$tmp"
}
trap cleanup EXIT

signed=0
if [ -n "${MACOS_CERT_P12_BASE64:-}" ]; then
	echo "==> importing the Developer ID certificate into a temporary keychain"
	kc_pass="$(openssl rand -hex 16)"
	printf '%s' "$MACOS_CERT_P12_BASE64" | base64 --decode >"$tmp/cert.p12"
	security create-keychain -p "$kc_pass" "$keychain"
	security set-keychain-settings -lut 3600 "$keychain"
	security unlock-keychain -p "$kc_pass" "$keychain"
	security import "$tmp/cert.p12" -k "$keychain" -P "${MACOS_CERT_PASSWORD:-}" -T /usr/bin/codesign >/dev/null
	security set-key-partition-list -S apple-tool:,apple: -s -k "$kc_pass" "$keychain" >/dev/null
	# shellcheck disable=SC2046
	security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')
	identity="${MACOS_SIGN_IDENTITY:-$(security find-identity -v -p codesigning "$keychain" | grep -o '"Developer ID Application[^"]*"' | head -1 | tr -d '"')}"
	[ -n "$identity" ] || { echo "macos_package: no Developer ID Application identity in the .p12" >&2; exit 1; }
	echo "==> codesign (hardened runtime): $identity"
	# A GDScript-only game needs no extra entitlements (no JIT, no unsigned libraries).
	codesign --force --deep --options runtime --timestamp --keychain "$keychain" -s "$identity" "$app"
	codesign --verify --deep --strict --verbose=2 "$app"
	signed=1
else
	echo "==> no MACOS_CERT_P12_BASE64: keeping the ad-hoc signature (not notarized)"
fi

if [ $signed = 1 ] && [ -n "${APPLE_API_KEY_P8:-}" ]; then
	echo "==> notarizing (notarytool, App Store Connect API key)"
	printf '%s\n' "$APPLE_API_KEY_P8" >"$tmp/AuthKey.p8"
	ditto -c -k --keepParent "$app" "$tmp/notarize.zip"
	xcrun notarytool submit "$tmp/notarize.zip" --key "$tmp/AuthKey.p8" --key-id "$APPLE_API_KEY_ID" \
		--issuer "$APPLE_API_ISSUER_ID" --wait --timeout 30m
	xcrun stapler staple "$app"
	spctl --assess --type execute --verbose "$app"
elif [ $signed = 1 ]; then
	echo "==> no APPLE_API_KEY_P8: signed but not notarized"
fi

zip="$out/Diceroll-$version-macos.zip"
dmg="$out/Diceroll-$version-macos.dmg"
rm -f "$zip" "$dmg"
ditto -c -k --keepParent "$app" "$zip"
stage="$tmp/dmg"
mkdir -p "$stage"
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"
hdiutil create -quiet -volname "Diceroll $version" -srcfolder "$stage" -ov -format UDZO "$dmg"
if [ $signed = 1 ]; then
	codesign --force --timestamp --keychain "$keychain" -s "$identity" "$dmg"
fi
ls -la "$out"

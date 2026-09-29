#!/usr/bin/env bash
# iOS / iPadOS build (one universal iPhone + iPad binary; preset "iOS", targeted_device_family=2).
#   tools/ci/ios_build.sh <version> <out_dir>
#
# Signed path (all set): APPLE_TEAM_ID, APPLE_API_KEY_P8, APPLE_API_KEY_ID,
# APPLE_API_ISSUER_ID. xcodebuild archives with automatic signing, creating/refreshing the
# certificates and provisioning profiles through the App Store Connect API key
# (-allowProvisioningUpdates), then exports <out>/Diceroll-<v>-ios.ipa (method app-store-connect,
# ready for TestFlight). The key needs the "Admin" or "App Manager" role for profile creation.
#
# Always: <out>/Diceroll-<v>-ios-sideload.ipa, an unsigned device build (CODE_SIGNING_ALLOWED=NO)
# with the standard Payload/Diceroll.app layout: SideStore / AltStore re-sign it with the user's
# Apple ID (published with the AltStore source, tools/ci/altstore_source.py).
# Unsigned path only: <out>/Diceroll-<v>-ios-simulator.zip (Simulator .app).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
version="$1"
out="$2"
mkdir -p "$out"
out="$(cd "$out" && pwd)" # absolute: the zips below run from other directories
tmp="$(mktemp -d "${RUNNER_TEMP:-/tmp}/iosbuild.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

signed=0
if [ -n "${APPLE_TEAM_ID:-}" ] && [ -n "${APPLE_API_KEY_P8:-}" ] && [ -n "${APPLE_API_KEY_ID:-}" ] && [ -n "${APPLE_API_ISSUER_ID:-}" ]; then
	signed=1
fi

# Godot writes the Xcode project (+ .pck); the team id is injected only for the export.
DICEROLL_TEAM_ID="${APPLE_TEAM_ID:-}" tools/export.sh ios --no-sim
proj="$ROOT/build/ios/Diceroll.xcodeproj"

if [ $signed = 1 ]; then
	printf '%s\n' "$APPLE_API_KEY_P8" >"$tmp/AuthKey.p8"
	auth=(-allowProvisioningUpdates -authenticationKeyPath "$tmp/AuthKey.p8"
		-authenticationKeyID "$APPLE_API_KEY_ID" -authenticationKeyIssuerID "$APPLE_API_ISSUER_ID")
	echo "==> xcodebuild archive (automatic signing, team $APPLE_TEAM_ID)"
	xcodebuild -project "$proj" -scheme Diceroll -configuration Release -destination generic/platform=iOS \
		-archivePath "$tmp/Diceroll.xcarchive" "${auth[@]}" CODE_SIGN_STYLE=Automatic \
		DEVELOPMENT_TEAM="$APPLE_TEAM_ID" archive >"$tmp/archive.log" 2>&1 \
		|| { grep -E "error:|ld: |Undefined symbols|warning: .*sign" "$tmp/archive.log" | head -40 >&2; exit 1; }
	cat >"$tmp/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$APPLE_TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>destination</key><string>export</string>
</dict></plist>
EOF
	xcodebuild -exportArchive -archivePath "$tmp/Diceroll.xcarchive" -exportOptionsPlist "$tmp/ExportOptions.plist" \
		-exportPath "$tmp/export" "${auth[@]}" >"$tmp/export.log" 2>&1 \
		|| { grep -E "error" "$tmp/export.log" | head -30 >&2; exit 1; }
	mv "$tmp/export/"*.ipa "$out/Diceroll-$version-ios.ipa"
fi

echo "==> unsigned device build (sideload IPA)"
xcodebuild -project "$proj" -scheme Diceroll -configuration Release -destination generic/platform=iOS \
	-derivedDataPath "$tmp/dd" CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build >"$tmp/device.log" 2>&1 \
	|| { grep -E "error:|ld: |Undefined symbols|referenced from" "$tmp/device.log" | head -40 >&2; exit 1; }
mkdir -p "$tmp/Payload"
cp -R "$tmp/dd/Build/Products/Release-iphoneos/Diceroll.app" "$tmp/Payload/"
(cd "$tmp" && zip -qry "$out/Diceroll-$version-ios-sideload.ipa" Payload)

if [ $signed = 0 ]; then
	echo "==> no Apple signing secrets: Simulator build"
	# Simulator build (tools/export.sh adds the arm64 simulator slice to libgodot).
	tools/export.sh ios
	(cd "$ROOT/build/ios_dd/Build/Products/Release-iphonesimulator" && zip -qr "$out/Diceroll-$version-ios-simulator.zip" Diceroll.app)
fi
ls -la "$out"

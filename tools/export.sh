#!/bin/bash
# Diceroll export pipeline (Godot 4.7.2, presets in export_presets.cfg).
#
# Usage: tools/export.sh <target> [options]
#
#   macos   build/macos/Diceroll.app (universal, ad-hoc signed, not notarized)
#   ios     build/ios/Diceroll.xcodeproj (Xcode project), then an iOS Simulator build
#           (build/ios_dd/Build/Products/Release-iphonesimulator/Diceroll.app)
#   web     build/web/index.html (single-threaded "nothreads" template: no COOP/COEP needed)
#   windows build/windows/Diceroll.exe (+ .pck; x86_64)
#   linux   build/linux-x86_64/Diceroll.x86_64 (+ .pck)
#   linux-arm64  build/linux-arm64/Diceroll.arm64 (+ .pck; ARM Linux boards/laptops)
#   android build/android/Diceroll.apk (prebuilt template, arm64; sideload/testing)
#   android-aab  build/android/Diceroll.aab (Gradle build, installs res://android/build; Play)
#           Android needs JAVA_HOME (JDK 17+) and ANDROID_HOME (SDK). Signing: release keystore via
#           GODOT_ANDROID_KEYSTORE_RELEASE_{PATH,USER,PASSWORD}; otherwise a debug keystore is
#           created (build/android/debug.keystore) and used for both debug and release exports.
#   pck     build/pck/Diceroll-desktop.pck (full content pack for the desktop auto-updater)
#   all     macos + ios + web
#   icon    re-render the app icon + derived assets (tools/icon/build_icons.sh -> assets/icon/);
#           ("doubles" monogram; per-size iOS files in assets/icon/ios, single die below 114 px)
#
# Options:
#   --debug             export with debug templates (default: release)
#   --run               macos: launch the app in the background (open -g), print its log, kill it
#                       ios:   install + launch in a booted simulator (booted headless via simctl;
#                              Simulator.app is never opened)
#                       web:   serve build/web on 127.0.0.1 and curl-check index.html/.js/.wasm/.pck
#   --shot=/abs.png     with --run (macos/ios): save a screenshot there
#   --scenario=NAME     with --run (macos/ios): pass `-- --scenario=NAME` to the game (harness)
#   --wait=SECONDS      with --run: seconds before screenshot / kill (default 8)
#   --device="NAME"     simulator name (default "iPhone 17 Pro")
#   --no-sim            ios: export the Xcode project only, skip the simulator build
#
# Env: DICEROLL_TEAM_ID  Apple team id for the iOS export. The committed preset leaves it
#      empty; Godot refuses to export iOS without one, so a placeholder is injected for the
#      duration of the export (the simulator build doesn't sign, so it's never used).
#      Set it to your real team id for device builds.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
GODOT="${GODOT:-godot}"
TARGET="${1:-}"
[ $# -gt 0 ] && shift
MODE=release
RUN=0
SHOT=""
SCENARIO=""
WAIT=8
DEVICE="iPhone 17 Pro"
SIM_BUILD=1
for a in "$@"; do
	case "$a" in
		--debug) MODE=debug ;;
		--run) RUN=1 ;;
		--shot=*) SHOT="${a#--shot=}" ;;
		--scenario=*) SCENARIO="${a#--scenario=}" ;;
		--wait=*) WAIT="${a#--wait=}" ;;
		--device=*) DEVICE="${a#--device=}" ;;
		--no-sim) SIM_BUILD=0 ;;
		*) echo "export.sh: unknown option '$a'" >&2; exit 2 ;;
	esac
done

die() { echo "export.sh: ERROR: $*" >&2; exit 1; }
step() { echo "==> $*"; }

command -v "$GODOT" >/dev/null || die "godot not found (set GODOT=/path/to/godot)"
[ -z "$SHOT" ] || [[ "$SHOT" = /* ]] || die "--shot needs an absolute path"

# Runs a headless Godot export; fails loudly on "ERROR:" lines (Godot often exits 0 anyway).
godot_export() {
	local preset="$1" out="$2" log
	log="$(mktemp -t diceroll_export).log"
	mkdir -p "$(dirname "$out")"
	step "godot --export-$MODE \"$preset\" -> $out"
	if ! "$GODOT" --headless --path "$ROOT" "--export-$MODE" "$preset" "$out" >"$log" 2>&1 \
		|| grep -q "^ERROR:" "$log"; then
		grep -A3 "^ERROR:" "$log" >&2 || tail -30 "$log" >&2
		rm -f "$log"
		die "export of preset '$preset' failed"
	fi
	rm -f "$log"
}

ensure_import() {
	# Keep build output out of Godot's filesystem scan (and out of every .pck).
	mkdir -p "$ROOT/build" && touch "$ROOT/build/.gdignore"
	# First run in a fresh checkout: nothing is imported yet.
	[ -d "$ROOT/.godot/imported" ] || { step "importing assets"; "$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true; }
}

# --- macOS ---------------------------------------------------------------------------
do_macos() {
	local app="$ROOT/build/macos/Diceroll.app"
	rm -rf "$app"
	godot_export macOS "$app"
	[ -x "$app/Contents/MacOS/Diceroll" ] || die "macOS export produced no binary"
	codesign --verify "$app" 2>/dev/null || die "macOS app signature invalid"
	echo "    $app ($(lipo -archs "$app/Contents/MacOS/Diceroll"), $(codesign -dv "$app" 2>&1 | grep -o 'Signature=.*'))"
	[ $RUN = 1 ] || return 0
	local log
	log="$(mktemp -t diceroll_macos).log"
	local user=()
	[ -n "$SCENARIO" ] && user+=("--scenario=$SCENARIO")
	[ -n "$SHOT" ] && user+=("--shot=$SHOT" "--wait=$((WAIT > 2 ? 2 : WAIT))")
	step "launching in background (open -g), log: $log"
	# Off-screen window; the harness (tools/shot.gd) never takes focus when --shot is given.
	open -g -n -W -a "$app" --args --position -4000,-4000 --resolution 540x960 --log-file "$log" \
		${user[@]+"--"} ${user[@]+"${user[@]}"} &
	local pid=$! t=0
	while kill -0 $pid 2>/dev/null && [ $t -lt $((WAIT + 20)) ]; do sleep 1; t=$((t + 1)); [ -z "$SHOT" ] && [ $t -ge "$WAIT" ] && break; done
	pkill -f "$app/Contents/MacOS/Diceroll" 2>/dev/null || true
	wait $pid 2>/dev/null || true
	cat "$log"
	if grep -q "SCRIPT ERROR\|^ERROR:" "$log"; then die "errors in macOS run log ($log)"; fi
	[ -z "$SHOT" ] || [ -f "$SHOT" ] || die "no screenshot written to $SHOT"
	[ -z "$SHOT" ] || echo "    screenshot: $SHOT"
}

# --- iOS -----------------------------------------------------------------------------
PRESETS_BAK=""
restore_presets() { [ -n "$PRESETS_BAK" ] && [ -f "$PRESETS_BAK" ] && /bin/mv -f "$PRESETS_BAK" "$ROOT/export_presets.cfg"; PRESETS_BAK=""; }
trap restore_presets EXIT INT TERM

do_ios() {
	local proj="$ROOT/build/ios/Diceroll.xcodeproj" team="${DICEROLL_TEAM_ID:-SIMULATOR0}"
	command -v xcodebuild >/dev/null || die "xcodebuild not found (install Xcode)"
	PRESETS_BAK="$(mktemp -t diceroll_presets)"
	/bin/cp -f "$ROOT/export_presets.cfg" "$PRESETS_BAK"
	sed -i '' "s/^application\/app_store_team_id=\"\"/application\/app_store_team_id=\"$team\"/" "$ROOT/export_presets.cfg"
	godot_export iOS "$proj"
	restore_presets
	[ -d "$proj" ] || die "iOS export produced no Xcode project"
	echo "    $proj (team id: $team)"
	[ $SIM_BUILD = 1 ] || return 0

	# The official template's simulator slice is x86_64-only (Rosetta). Add an arm64
	# simulator slice made from the device library (tools/ios_sim_retarget.py).
	local xcf="$ROOT/build/ios/Diceroll.xcframework" tmp="$ROOT/build/ios_sim_cache"
	local sim="$xcf/ios-arm64_x86_64-simulator/libgodot.a"
	mkdir -p "$tmp"
	if ! lipo -archs "$sim" | grep -qw arm64; then
		step "adding arm64 simulator slice to libgodot.a"
		python3 "$ROOT/tools/ios_sim_retarget.py" "$xcf/ios-arm64/libgodot.a" "$tmp/libgodot.arm64-sim.a" >/dev/null
		/bin/cp -f "$sim" "$tmp/libgodot.x86_64-sim.a"
		lipo -create "$tmp/libgodot.arm64-sim.a" "$tmp/libgodot.x86_64-sim.a" -output "$tmp/libgodot.fat.a"
		/bin/mv -f "$tmp/libgodot.fat.a" "$sim"
	fi

	local cfg=Release; [ $MODE = debug ] && cfg=Debug
	local xlog="$ROOT/build/ios_xcodebuild.log"
	step "xcodebuild $cfg for iOS Simulator ($DEVICE), log: $xlog"
	if ! xcodebuild -project "$proj" -scheme Diceroll -configuration $cfg -sdk iphonesimulator \
		-destination "platform=iOS Simulator,name=$DEVICE" -derivedDataPath "$ROOT/build/ios_dd" \
		CODE_SIGNING_ALLOWED=NO build >"$xlog" 2>&1; then
		grep -E "error:|Undefined symbols|referenced from" "$xlog" | head -20 >&2
		die "xcodebuild failed (see $xlog)"
	fi
	local app="$ROOT/build/ios_dd/Build/Products/$cfg-iphonesimulator/Diceroll.app"
	echo "    $app"
	[ $RUN = 1 ] || return 0

	local udid
	udid="$(xcrun simctl list devices available | grep -F "    $DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
	[ -n "$udid" ] || die "no available simulator named '$DEVICE' (xcrun simctl list devices)"
	step "booting $DEVICE ($udid) headless"
	xcrun simctl boot "$udid" 2>/dev/null || true   # already booted is fine
	xcrun simctl bootstatus "$udid" -b >/dev/null
	xcrun simctl install "$udid" "$app"
	local user=()
	[ -n "$SCENARIO" ] && user+=("--" "--scenario=$SCENARIO")
	step "launching gg.vlad.diceroll"
	xcrun simctl launch --terminate-running-process "$udid" gg.vlad.diceroll ${user[@]+"${user[@]}"}
	sleep "$WAIT"
	if [ -n "$SHOT" ]; then
		mkdir -p "$(dirname "$SHOT")"
		xcrun simctl io "$udid" screenshot "$SHOT" >/dev/null 2>&1 || die "simulator screenshot failed"
		echo "    screenshot: $SHOT"
	fi
	xcrun simctl terminate "$udid" gg.vlad.diceroll 2>/dev/null || true
	echo "    NOTE: Godot 4.7's Metal/Vulkan renderers refuse the Simulator GPU (no image cube"
	echo "    arrays) and show an alert; this proves build/install/launch, not rendering."
}

# --- Web -----------------------------------------------------------------------------
do_web() {
	local out="$ROOT/build/web"
	rm -rf "$out"
	godot_export Web "$out/index.html"
	for f in index.html index.js index.wasm index.pck; do [ -s "$out/$f" ] || die "web export missing $f"; done
	grep -q "GODOT_THREADS_ENABLED = false" "$out/index.html" || die "web export is not the nothreads variant"
	echo "    $out ($(du -sh "$out" | cut -f1))"
	[ $RUN = 1 ] || return 0
	local port=8765
	step "serving $out on http://127.0.0.1:$port"
	python3 -m http.server $port --bind 127.0.0.1 --directory "$out" >/dev/null 2>&1 &
	local pid=$!
	sleep 1
	local bad=0
	for f in index.html index.js index.wasm index.pck; do
		local r
		r="$(curl -s -o /dev/null -w "%{http_code} %{size_download} %{content_type}" "http://127.0.0.1:$port/$f" || true)"
		echo "    $f -> $r"
		[[ "$r" = 200* ]] || bad=1
	done
	kill $pid 2>/dev/null || true
	[ $bad = 0 ] || die "web server check failed"
}

# --- Windows / Linux / content pack ----------------------------------------------------
do_desktop() { # do_desktop <preset> <out>
	local preset="$1" out="$2"
	rm -rf "$(dirname "$out")"
	godot_export "$preset" "$out"
	[ -s "$out" ] || die "$preset export produced no binary"
	echo "    $out ($(du -sh "$(dirname "$out")" | cut -f1))"
}

do_pck() {
	# Full game PCK for the desktop updater (game/update): the Linux preset's resources
	# (S3TC/BPTC textures work on every desktop GPU incl. Apple Silicon).
	local out="$ROOT/build/pck/Diceroll-desktop.pck" log
	mkdir -p "$(dirname "$out")"
	log="$(mktemp -t diceroll_export).log"
	step "godot --export-pack Linux -> $out"
	if ! "$GODOT" --headless --path "$ROOT" --export-pack Linux "$out" >"$log" 2>&1 || grep -q "^ERROR:" "$log"; then
		grep -A3 "^ERROR:" "$log" >&2 || tail -30 "$log" >&2
		rm -f "$log"
		die "pck export failed"
	fi
	rm -f "$log"
	echo "    $out ($(du -h "$out" | cut -f1))"
}

# --- Android -------------------------------------------------------------------------
android_env() {
	[ -n "${JAVA_HOME:-}" ] || die "JAVA_HOME is not set (JDK 17+)"
	[ -n "${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}" ] || die "ANDROID_HOME is not set"
	if [ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
		# No release keystore: sign with a throwaway debug key (sideload/testing only; the Play
		# Store rejects debug-signed bundles).
		local ks="$ROOT/build/android/debug.keystore"
		mkdir -p "$(dirname "$ks")"
		[ -f "$ks" ] || "$JAVA_HOME/bin/keytool" -genkeypair -v -keystore "$ks" -storepass android \
			-alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
			-dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1 || die "keytool failed"
		export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ks" GODOT_ANDROID_KEYSTORE_RELEASE_USER=androiddebugkey
		export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
		echo "    (no release keystore: signing with the debug key $ks)"
	fi
	# Godot only defaults the SDK paths from JAVA_HOME / ANDROID_HOME when its editor settings don't
	# already hold a value; on CI (fresh settings, possibly created by an earlier --import with
	# empty values) pin them explicitly.
	if [ -n "${CI:-}" ]; then
		local es
		for es in "$HOME/.config/godot"/editor_settings-4*.tres "$HOME/Library/Application Support/Godot"/editor_settings-4*.tres; do
			[ -f "$es" ] || continue
			grep -v '^export/android/java_sdk_path\|^export/android/android_sdk_path' "$es" >"$es.tmp"
			printf 'export/android/java_sdk_path = "%s"\nexport/android/android_sdk_path = "%s"\n' \
				"$JAVA_HOME" "${ANDROID_HOME:-$ANDROID_SDK_ROOT}" >>"$es.tmp"
			mv "$es.tmp" "$es"
		done
	fi
	export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$GODOT_ANDROID_KEYSTORE_RELEASE_PATH}"
	export GODOT_ANDROID_KEYSTORE_DEBUG_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-$GODOT_ANDROID_KEYSTORE_RELEASE_USER}"
	export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-$GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD}"
}

do_android() {
	android_env
	local out="$ROOT/build/android/Diceroll.apk"
	rm -f "$out"
	godot_export Android "$out"
	[ -s "$out" ] || die "Android export produced no APK"
	echo "    $out ($(du -h "$out" | cut -f1))"
}

do_android_aab() {
	android_env
	local out="$ROOT/build/android/Diceroll.aab"
	rm -f "$out"
	# The Gradle build needs the android build template in res://android/build (git-ignored).
	if [ ! -f "$ROOT/android/build/build.gradle" ]; then
		step "installing the Android build template"
		"$GODOT" --headless --path "$ROOT" --install-android-build-template --export-release "Android AAB" "$out" >/dev/null 2>&1 || true
		mkdir -p "$ROOT/android" && touch "$ROOT/android/.gdignore"
	fi
	godot_export "Android AAB" "$out"
	[ -s "$out" ] || die "Android export produced no AAB"
	echo "    $out ($(du -h "$out" | cut -f1))"
}

# --- Icon ----------------------------------------------------------------------------
do_icon() {
	# Renders tools/icon (scenario app_icon) and derives iOS/macOS/icns assets in assets/icon/.
	"$ROOT/tools/icon/build_icons.sh"
}

case "$TARGET" in
	macos) ensure_import; do_macos ;;
	ios) ensure_import; do_ios ;;
	web) ensure_import; do_web ;;
	windows) ensure_import; do_desktop Windows "$ROOT/build/windows/Diceroll.exe" ;;
	linux) ensure_import; do_desktop Linux "$ROOT/build/linux-x86_64/Diceroll.x86_64" ;;
	linux-arm64) ensure_import; do_desktop "Linux ARM64" "$ROOT/build/linux-arm64/Diceroll.arm64" ;;
	android) ensure_import; do_android ;;
	android-aab) ensure_import; do_android_aab ;;
	pck) ensure_import; do_pck ;;
	all) ensure_import; do_macos; do_ios; do_web ;;
	icon) do_icon ;;
	*) sed -n '2,43p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
step "done"

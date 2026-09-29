#!/usr/bin/env bash
# CI-portable screenshot runner: renders scenarios across the device matrix of
# tools/shoot_matrix.sh (the lists are read from that file, so they never drift).
#
#   tools/ci/shoot_ci.sh [--set=quick|all|desktop|mobile|duo|dpi|zoom] [--scenarios="a b c"]
#                        [--out=DIR] [--wait=SECONDS] [--timeout=SECONDS] [--list]
#
# Defaults: --set=quick, scenarios from tools/ci/scenarios_<set>.txt (or scenarios_quick.txt),
# --out=build/shots, --wait=4. Writes DIR/<scenario>__<device>.png, DIR/results.tsv
# (scenario device resolution status seconds) and DIR/logs/*.log; exits 1 if any shot failed or
# any log has a SCRIPT ERROR.
#
# How Godot is started (never `open` on CI, never a focus-stealing window locally):
#   Linux  : one Xvfb server for the whole run, Godot on the Vulkan Forward+ renderer through Mesa
#            lavapipe (software Vulkan). The first shot compiles shaders (~45 s), later ones take
#            ~7 s. Needs: xvfb mesa-vulkan-drivers (see .github/actions/setup-diceroll).
#   macOS CI (CI=true): the Godot binary directly, off-screen (--position -4000,-4000), Metal.
#   macOS local: `open -g` in the background exactly like tools/shoot.sh (no focus stealing).
# Env: GODOT (binary; default `godot`), GODOT_APP (macOS local, default /Applications/Godot.app).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
GODOT="${GODOT:-godot}"
SET=quick
SCENARIOS=""
OUT="$ROOT/build/shots"
WAIT=4
TIMEOUT=120
LIST=0
for a in "$@"; do
	case "$a" in
		--set=*) SET="${a#--set=}" ;;
		--scenarios=*) SCENARIOS="${a#--scenarios=}" ;;
		--out=*) OUT="${a#--out=}" ;;
		--wait=*) WAIT="${a#--wait=}" ;;
		--timeout=*) TIMEOUT="${a#--timeout=}" ;;
		--list) LIST=1 ;;
		-h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "shoot_ci: unknown option '$a'" >&2; exit 2 ;;
	esac
done
case "$OUT" in /*) ;; *) OUT="$ROOT/$OUT" ;; esac

# --- device list (parsed from tools/shoot_matrix.sh: VAR="\n name WxH safe [scale]\n ...") -------
block() { sed -n "/^$1=\"/,/^\"/p" "$ROOT/tools/shoot_matrix.sh" | sed '1d;$d'; }
case "$SET" in
	desktop) DEVICES="$(block DESKTOP)" ;;
	mobile) DEVICES="$(block MOBILE; block DUO)" ;;
	duo) DEVICES="$(block DUO)" ;;
	quick) DEVICES="$(block QUICK)" ;;
	dpi) DEVICES="$(block DPI)" ;;
	zoom) DEVICES="$(block ZOOM)" ;;
	all) DEVICES="$(block DESKTOP; block MOBILE; block DUO; block DPI; block ZOOM)" ;;
	*) echo "shoot_ci: unknown set '$SET'" >&2; exit 2 ;;
esac
if [ -z "$SCENARIOS" ]; then
	f="$ROOT/tools/ci/scenarios_$SET.txt"
	[ -f "$f" ] || f="$ROOT/tools/ci/scenarios_quick.txt"
	SCENARIOS="$(grep -v '^#' "$f" | tr '\n' ' ')"
fi
if [ $LIST = 1 ]; then
	echo "scenarios: $SCENARIOS"
	echo "$DEVICES" | awk 'NF { print "device:", $1, $2 }'
	exit 0
fi

mkdir -p "$OUT/logs"
RESULTS="$OUT/results.tsv"
[ -f "$RESULTS" ] || printf 'scenario\tdevice\tresolution\tstatus\tseconds\n' >"$RESULTS"

OS="$(uname -s)"
XVFB_PID=""
cleanup() { [ -n "$XVFB_PID" ] && kill "$XVFB_PID" 2>/dev/null; true; }
trap cleanup EXIT INT TERM

if [ "$OS" = Linux ] && [ -z "${DISPLAY:-}" ]; then
	command -v Xvfb >/dev/null || { echo "shoot_ci: Xvfb missing (apt install xvfb)" >&2; exit 1; }
	# Big enough for every matrix entry (largest: 1920x1080 and 804x1748 portrait).
	Xvfb :99 -screen 0 2600x2000x24 -nolisten tcp >/dev/null 2>&1 &
	XVFB_PID=$!
	export DISPLAY=:99
	sleep 1
fi

# Runs one shot; prints the log to $2.
godot_shot() { # godot_shot <log> <res> <harness args...>
	local log="$1" res="$2"
	shift 2
	if [ "$OS" = Darwin ] && [ -z "${CI:-}" ]; then
		# Local Mac: background launch (same approach as tools/shoot.sh), never focus-stealing.
		open -g -n -W -a "${GODOT_APP:-/Applications/Godot.app}" --args --path "$ROOT" \
			--position -4000,-4000 --resolution "$res" --log-file "$log" -- "$@" >/dev/null 2>&1
	elif [ "$OS" = Darwin ]; then
		"$GODOT" --path "$ROOT" --position -4000,-4000 --resolution "$res" --audio-driver Dummy \
			-- "$@" >"$log" 2>&1
	else
		timeout $((TIMEOUT + 30)) "$GODOT" --path "$ROOT" --rendering-driver vulkan --resolution "$res" \
			--audio-driver Dummy -- "$@" >"$log" 2>&1
	fi
}

fail=0
total=0
for scenario in $SCENARIOS; do
	while read -r name res safe scale; do
		[ -n "$name" ] || continue
		total=$((total + 1))
		png="$OUT/${scenario}__${name}.png"
		log="$OUT/logs/${scenario}__${name}.log"
		rm -f "$png"
		args=("--scenario=$scenario" "--shot=$png" "--wait=$WAIT" "--timeout=$TIMEOUT" "--safe=$safe")
		[ -n "${scale:-}" ] && args+=("--ui-scale=$scale")
		t0=$(date +%s)
		godot_shot "$log" "$res" "${args[@]}"
		dt=$(($(date +%s) - t0))
		status=ok
		if ! grep -q "SHOT_SAVED" "$log" 2>/dev/null || [ ! -s "$png" ]; then
			status=fail
		elif grep -q "SCRIPT ERROR" "$log"; then
			status=script_error
		fi
		[ $status = ok ] || fail=$((fail + 1))
		printf '%s\t%s\t%s\t%s\t%s\n' "$scenario" "$name" "$res" "$status" "$dt" >>"$RESULTS"
		printf '%-12s %-24s %-16s %-10s %4ss\n' "$status" "$scenario" "$name" "$res" "$dt"
		if [ $status != ok ]; then
			grep -E "SCRIPT ERROR|ERROR:|at: " "$log" | head -8 | sed 's/^/    | /'
		fi
	done <<<"$DEVICES"
done
echo "shoot_ci: $((total - fail))/$total shots ok -> $OUT"
[ $fail = 0 ]

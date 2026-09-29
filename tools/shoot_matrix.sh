#!/bin/sh
# Screenshots one scenario across the standard device matrix (desktop resolutions up to
# 1080p, iPhones and iPads in both orientations), in the background like tools/shoot.sh.
# Phones/tablets use their logical point sizes (same aspect ratio as the real screen) and
# emulate the notch / home-indicator safe area via --safe (see UiTheme.safe_margins).
#
# Usage: tools/shoot_matrix.sh <scenario> <out_dir> [set] [extra harness args...]
#   set: all (default: desktop+mobile+duo+dpi+zoom) | desktop | mobile | duo | dpi | zoom | quick
#   dpi  = same device at @1x/@2x pixel density (macOS clamps windows to the display
#          height, so @3x phones can't render off-screen; the UI is vector, @2x covers it)
#   zoom = UI zoom via content_scale_factor (--ui-scale), like OS scaling / a UI-size option
#   e.g. tools/shoot_matrix.sh game_rolled /tmp/shots/m quick --wait=3
# iPhone 17 and 17 Pro share 402x874 pt, so one entry covers both.
# Writes <out_dir>/<scenario>__<device>.png and prints one line per device.
set -e
scenario="$1"; out="$2"; set_="${3:-all}"
[ $# -ge 2 ] || { echo "usage: $0 <scenario> <out_dir> [all|desktop|mobile|quick] [args...]"; exit 2; }
shift 2; [ $# -gt 0 ] && shift
mkdir -p "$out"
here="$(cd "$(dirname "$0")" && pwd)"

# name  WxH  safe(top,bottom,left,right as fractions)  [ui-scale]
DESKTOP="
pc_720p         1280x720   0,0,0,0
pc_1366x768     1366x768   0,0,0,0
pc_1280x800     1280x800   0,0,0,0
pc_1440x900     1440x900   0,0,0,0
pc_1600x900     1600x900   0,0,0,0
pc_1080p        1920x1080  0,0,0,0
"
MOBILE="
iphone17_17pro  402x874    0.071,0.039,0,0
iphone17promax  440x956    0.066,0.036,0,0
iphone17_land   874x402    0,0.052,0.071,0.071
ipadmini        744x1133   0.021,0.018,0,0
ipadmini_land   1133x744   0.032,0.027,0,0
ipadpro13       1032x1376  0.017,0.015,0,0
ipadpro13_land  1376x1032  0.023,0.02,0,0
"
# iPhone Duo (foldable, Sept 2026; apple.com/iphone-duo/specs): outer 5.4" 1398x2034 @460ppi,
# inner 7.6" 1878x2670 @430ppi. Point sizes assume @3x (Apple doesn't publish them); layout only
# depends on aspect + relative size. Both screens have a Dynamic Island -> top inset emulated.
DUO="
duo_outer       466x678    0.087,0.05,0,0
duo_inner       626x890    0.066,0.038,0,0
duo_inner_land  890x626    0.094,0.054,0.03,0.03
"
QUICK="
pc_1080p        1920x1080  0,0,0,0
pc_1366x768     1366x768   0,0,0,0
iphone17_17pro  402x874    0.071,0.039,0,0
duo_outer       466x678    0.087,0.05,0,0
ipadpro13_land  1376x1032  0.023,0.02,0,0
"
DPI="
iphone17_1x     402x874    0.071,0.039,0,0
iphone17_2x     804x1748   0.071,0.039,0,0
pc_1080p_1x     1920x1080  0,0,0,0
"
ZOOM="
pc_1080p_z080   1920x1080  0,0,0,0     0.8
pc_1080p_z125   1920x1080  0,0,0,0     1.25
pc_1080p_z150   1920x1080  0,0,0,0     1.5
pc_1366_z125    1366x768   0,0,0,0     1.25
iphone17_z125   402x874    0.071,0.039,0,0  1.25
ipadmini_z125   744x1133   0.021,0.018,0,0  1.25
"
case "$set_" in
	desktop) list="$DESKTOP" ;;
	mobile) list="$MOBILE$DUO" ;;
	duo) list="$DUO" ;;
	quick) list="$QUICK" ;;
	dpi) list="$DPI" ;;
	zoom) list="$ZOOM" ;;
	*) list="$DESKTOP$MOBILE$DUO$DPI$ZOOM" ;;
esac

echo "$list" | while read -r name res safe scale; do
	[ -n "$name" ] || continue
	png="$out/${scenario}__${name}.png"
	zoom=""; [ -n "$scale" ] && zoom="--ui-scale=$scale"
	if "$here/shoot.sh" "$scenario" "$png" "$res" --safe="$safe" $zoom "$@" 2>&1 | grep -q "SHOT_SAVED"; then
		echo "ok   $name ($res) -> $png"
	else
		echo "FAIL $name ($res)"
	fi
done

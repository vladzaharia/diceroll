#!/bin/sh
# Background screenshot runner: launches Godot without activating it (open -g),
# with its window off-screen, so it never steals focus or input.
# Usage: tools/shoot.sh <scenario> <out.png> [WxH] [extra harness args...]
#   e.g. tools/shoot.sh board_act1 /tmp/shots/b.png 720x1280 --wait=2 --frames=3
# Prints the Godot log (errors included) after the run.
set -e
cd "${GODOT_PROJECT:-$(dirname "$0")/..}"
scenario="$1"; out="$2"; res="${3:-720x1280}"
shift 2; [ $# -gt 0 ] && shift
log="$(mktemp -t godot_shot).log"
open -g -n -W -a /Applications/Godot.app --args \
	--path "$PWD" --position -4000,-4000 --resolution "$res" --log-file "$log" \
	-- --scenario="$scenario" --shot="$out" "$@"
grep -v "^$" "$log" | grep -v "Godot Engine v\|Metal 4\|^$" || true
rm -f "$log"

#!/bin/bash
# Renders the app icon in-engine (background, never steals focus) and derives every asset.
#
#   tools/icon/build_icons.sh            (also: tools/export.sh icon)
#
# Outputs (assets/icon/):
#   icon.png         1024 full-bleed, opaque RGB, square corners: iOS / App Store (iOS applies the mask)
#   icon_dark.png    1024 iOS 18 dark-appearance variant (opaque)
#   icon_tinted.png  1024 iOS 18 tinted variant (grayscale, opaque)
#   icon_macos.png   1024 macOS grid: 824 px squircle body + drop shadow, transparent outside
#                    (also the project/window icon, config/icon)
#   icon.icns        macOS bundle icon (16..512@2x, iconutil)
# build/icon/preview_sizes.png: 1024/180/120/60/29 px preview (iOS mask) on light + dark home screens
# build/icon/grid.png (only with ICON_REFS=<dir of competitor icons>): crowded home-screen mock
# Art: tools/icon/icon_art.gd (in-engine, concept IconArt.FINAL = "hero": the knight standing on a
# giant die, gold pool of light on navy; hero_dark for the dark appearance). tools/icon/vector_art.py
# holds the 2D/SVG exploration concepts (monogram, loop, ...), rendered with cairosvg.
# Needs Godot (GODOT_APP, default /Applications/Godot.app via tools/shoot.sh), python3 + Pillow
# (a venv is created under build/icon-venv if Pillow is missing), iconutil.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/assets/icon"
TMP="$ROOT/build/icon"
mkdir -p "$OUT" "$TMP"
touch "$ROOT/build/.gdignore"

PY=python3
if ! "$PY" -c "import PIL" 2>/dev/null; then
	if [ ! -x "$ROOT/build/icon-venv/bin/python" ]; then
		echo "==> creating build/icon-venv with Pillow"
		python3 -m venv "$ROOT/build/icon-venv"
		"$ROOT/build/icon-venv/bin/pip" -q install Pillow
	fi
	PY="$ROOT/build/icon-venv/bin/python"
fi
T="$ROOT/tools/icon/icon_tools.py"

[ -d "$ROOT/.godot/imported" ] || godot --headless --path "$ROOT" --import >/dev/null 2>&1 || true

render() {  # scenario out.png
	rm -f "$2"
	echo "==> rendering $1"
	GODOT_PROJECT="$ROOT" "$ROOT/tools/shoot.sh" "$1" "$2" 1024x1024 --wait=2 | grep -v "^SCENARIO_STARTED\|^SHOT_SAVED" || true
	[ -f "$2" ] || { echo "build_icons: render of $1 failed" >&2; exit 1; }
}
render app_icon "$TMP/render.png"
render icon_hero_dark "$TMP/render_dark.png"

echo "==> deriving icons"
"$PY" "$T" ios "$TMP/render.png" "$OUT/icon.png"
"$PY" "$T" ios "$TMP/render_dark.png" "$OUT/icon_dark.png"
"$PY" "$T" tinted "$TMP/render_dark.png" "$OUT/icon_tinted.png"
"$PY" "$T" macos "$TMP/render.png" "$OUT/icon_macos.png"
rm -rf "$TMP/Diceroll.iconset"
"$PY" "$T" iconset "$OUT/icon_macos.png" "$TMP/Diceroll.iconset"
iconutil -c icns "$TMP/Diceroll.iconset" -o "$OUT/icon.icns"
"$PY" "$T" sheet "$TMP/preview_sizes.png" "Diceroll=$OUT/icon.png" "dark=$OUT/icon_dark.png" "tinted=$OUT/icon_tinted.png"
# Optional crowded home-screen mock: ICON_REFS=/dir/with/competitor/*.jpg|png (not in the repo).
if [ -n "${ICON_REFS:-}" ] && [ -d "$ICON_REFS" ]; then
	refs=()
	for f in "$ICON_REFS"/*.jpg "$ICON_REFS"/*.png; do
		[ -f "$f" ] || continue
		b="$(basename "$f")"; refs+=("${b%%[_.]*}=$f")
		[ ${#refs[@]} -ge 15 ] && break
	done
	"$PY" "$T" grid "$TMP/grid.png" "Diceroll=$OUT/icon.png" "dark=$OUT/icon_dark.png" -- "${refs[@]}"
	echo "    grid mock: $TMP/grid.png"
fi
for f in icon.png icon_dark.png icon_tinted.png icon_macos.png; do
	echo "    $f: $(sips -g pixelWidth -g pixelHeight -g hasAlpha "$OUT/$f" | tail -3 | awk '{printf "%s=%s ", $1, $2}')"
done
echo "    icon.icns: $(du -h "$OUT/icon.icns" | cut -f1)"

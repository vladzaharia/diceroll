#!/bin/bash
# Renders the app icon ("doubles": a gold D-die in front of a red one; below DOUBLES_MIN px a single
# gold D-die, see tools/icon/monogram.py; SVG via cairosvg) and derives every asset.
#
#   tools/icon/build_icons.sh            (also: tools/export.sh icon)
#
# Outputs (assets/icon/):
#   icon.png         1024 full-bleed, opaque RGB, square corners: iOS / App Store (iOS applies the mask)
#   icon_dark.png    1024 iOS 18 dark-appearance variant (opaque)
#   icon_tinted.png  1024 iOS 18 tinted variant (grayscale luminance: light die, black ground, opaque)
#   icon_macos.png   1024 macOS grid: 824 px squircle body + drop shadow, transparent outside
#                    (also the project/window icon, config/icon)
#   icon.icns        macOS bundle icon (16..512@2x, iconutil): doubles >= 128 px, single die below
#   ios/icon_<px>[_dark|_tinted].png  every iOS size in the Godot preset (40..1024), opaque; export_presets.cfg
#                    points each icons/<key> (+ _dark/_tinted) at these
# build/icon/preview_sizes.png: 1024/180/120/60/29 px preview (iOS mask) on light + dark home screens
# build/icon/size_ladder.png: the exact per-size files (iOS normal/dark/tinted + macOS iconset), 1:1
# build/icon/grid.png (only with ICON_REFS=<dir of competitor icons>): crowded home-screen mock
# Art: tools/icon/monogram.py (shipped icon + monogram concept family). Exploration only:
# tools/icon/vector_art.py (2D concepts) and tools/icon/icon_art.gd (in-engine 3D concepts, scenarios
# icon_<concept>, e.g. the knight-on-a-die "hero").
# Needs python3 + Pillow + cairosvg (a venv is created under build/icon-venv if missing; cairosvg
# needs the cairo library, e.g. `brew install cairo`), iconutil.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
OUT="$ROOT/assets/icon"
TMP="$ROOT/build/icon"
mkdir -p "$OUT" "$TMP"
touch "$ROOT/build/.gdignore"

PY=python3
if ! "$PY" -c "import PIL, cairosvg" 2>/dev/null; then
	if ! "$ROOT/build/icon-venv/bin/python" -c "import PIL, cairosvg" 2>/dev/null; then
		echo "==> creating build/icon-venv with Pillow + cairosvg"
		python3 -m venv "$ROOT/build/icon-venv"
		"$ROOT/build/icon-venv/bin/pip" -q install Pillow cairosvg
	fi
	PY="$ROOT/build/icon-venv/bin/python"
fi
T="$ROOT/tools/icon/icon_tools.py"

echo "==> rendering the doubles icon (single die below DOUBLES_MIN px)"
rm -rf "$TMP/ios"
"$PY" "$ROOT/tools/icon/monogram.py" ship "$TMP"

echo "==> deriving icons"
"$PY" "$T" ios "$TMP/render.png" "$OUT/icon.png"
"$PY" "$T" ios "$TMP/render_dark.png" "$OUT/icon_dark.png"
"$PY" "$T" tinted "$TMP/render_tint.png" "$OUT/icon_tinted.png"
# iOS per-size icons (every Godot 4.7 iOS preset size, normal/dark/tinted; exact-size vector renders)
rm -rf "$OUT/ios"; mkdir -p "$OUT/ios"
for f in "$TMP"/ios/icon_*.png; do
	b="$(basename "$f")"
	case "$b" in
		*_tinted.png) "$PY" "$T" flatten "$f" "$OUT/ios/$b" tinted ;;
		*) "$PY" "$T" flatten "$f" "$OUT/ios/$b" ;;
	esac
done
# macOS: doubles on the grid for 128 px and up, the single die for 16/32/64
"$PY" "$T" macos "$TMP/render.png" "$OUT/icon_macos.png"
"$PY" "$T" macos "$TMP/render_single.png" "$TMP/icon_macos_single.png"
rm -rf "$TMP/Diceroll.iconset"
"$PY" "$T" iconset_split "$OUT/icon_macos.png" "$TMP/icon_macos_single.png" "$TMP/Diceroll.iconset" 128
iconutil -c icns "$TMP/Diceroll.iconset" -o "$OUT/icon.icns"
"$PY" "$T" sheet "$TMP/preview_sizes.png" "Diceroll=$OUT/icon.png" "dark=$OUT/icon_dark.png" "tinted=$OUT/icon_tinted.png"
"$PY" "$T" ladder "$TMP/size_ladder.png" "$OUT/ios" "$TMP/Diceroll.iconset"
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

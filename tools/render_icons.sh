#!/bin/sh
# Renders the "rendered" UI icons (ui/icons/rendered/<id>.png, see RenderedIcons) from the
# KayKit props in assets/kaykit (run tools/import_assets.sh first), in the background like
# tools/shoot.sh, then imports them. Writes a contact sheet to ${1:-/tmp/rendered_icons.png}.
set -e
here="$(cd "$(dirname "$0")" && pwd)"
cd "${GODOT_PROJECT:-$here/..}"
"$here/shoot.sh" render_icons "${1:-/tmp/rendered_icons.png}" 760x760 --wait=5 | grep -E "RENDERED_ICON|SHOT_SAVED|ERROR" || true
godot --headless --path . --import >/dev/null 2>&1 || true
ls ui/icons/rendered/*.png

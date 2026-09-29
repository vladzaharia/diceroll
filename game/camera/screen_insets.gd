class_name ScreenInsets
extends RefCounted
## Measures, at runtime, the screen space the HUD actually covers, so the 3D camera frames
## the board / fight in the free area between them (safe areas, UI size and OS zoom
## included, since everything is read from the live controls in canvas pixels).
##
##   rig.insets_source = func() -> Dictionary: return ScreenInsets.measure(ui, view)
##
## Result (canvas px): top (below the top HUD + passives + AUTO cluster when it sits under
## the HUD), board_bottom (above the board bottom bar / tray), combat_bottom (above the
## combat panel / tray), left / right (safe side margins), view. Empty when no gameplay HUD
## is shown (title, menus): the rig then uses its default rects.

## Breathing room between the HUD and the framed content.
const GAP := 10.0


static func measure(ui: UiRoot, view: Vector2) -> Dictionary:
	var out := {"view": view, "top": UiTheme.EDGE, "board_bottom": view.y - UiTheme.EDGE,
		"combat_bottom": view.y - UiTheme.EDGE, "left": UiTheme.EDGE, "right": UiTheme.EDGE}
	if ui == null or not ui.is_inside_tree() or view.x <= 0.0:
		return out
	var safe := UiTheme.safe_margins(ui)
	out.left = safe.left
	out.right = safe.right
	var top := safe.top
	if not (ui.board_hud.visible or ui.combat_hud.visible):
		return {}  # no gameplay HUD (title, menus): the rig's default framing rects
	for hud: HudTop in [ui.board_hud.top, ui.combat_hud.top]:
		top = maxf(top, hud.global_position.y + hud.content_bottom())
	var ah := ui.auto_hud
	if ah != null and ah.visible and ah.cluster != null and ah.cluster.visible:
		var r := ah.cluster.get_global_rect()
		if r.end.y < view.y * 0.5:
			top = maxf(top, r.end.y)
	out.top = top + GAP
	out.board_bottom = ui.board_hud.content_top(view) - GAP
	out.combat_bottom = ui.combat_hud.content_top(view) - GAP
	return out

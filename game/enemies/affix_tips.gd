class_name AffixTips
extends Control
## Tooltips for the affix badges under enemy HP bars (§3A.6): hovering (desktop) or long-pressing
## (touch) a badge opens a small card with the affix name, its one-line rule and the live value
## ("Frenzied +4/+6", "Next hex in 2 actions"). Lives on the GameOverlay and never takes input:
## it polls the pointer against the badges' screen positions (44 px touch targets).
##
##   AffixTips.ensure(c)                 # once per controller (EncounterCards does it)
##   AffixTips.of(c).show_tip(0, 0)      # scenarios: enemy 0's first badge

const TOUCH := 22.0       # min badge radius in px (a 44 px target)
const HOVER_DELAY := 0.12
const PRESS_DELAY := 0.35

var c: GameController
var _panel: PanelContainer
var _over := Vector2i(-1, -1)
var _over_t := 0.0
var _shown := Vector2i(-1, -1)
var _pinned := 0.0


static func ensure(ctrl: GameController) -> AffixTips:
	var t := of(ctrl)
	if t == null:
		t = AffixTips.new()
		t.c = ctrl
		t.name = "AffixTips"
		ctrl.overlay.add_child(t)
	return t


static func of(ctrl: GameController) -> AffixTips:
	return ctrl.overlay.get_node_or_null("AffixTips") as AffixTips if ctrl and ctrl.overlay else null


func _ready() -> void:
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)


func _process(dt: float) -> void:
	if c == null or not c.in_combat or c.stage == null:
		if _panel.visible:
			_hide()
		return
	if _pinned > 0.0:
		_pinned -= dt
		if _pinned <= 0.0:
			_hide()
		return
	var hit := badge_at(get_viewport().get_mouse_position())
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if hit != _over:
		_over = hit
		_over_t = 0.0
	else:
		_over_t += dt
	if hit.x >= 0 and _over_t >= (PRESS_DELAY if pressed else HOVER_DELAY):
		if hit != _shown:
			show_tip(hit.x, hit.y, 0.0)
	elif hit.x < 0 and _shown.x >= 0:
		_hide()


## (enemy index, badge index) under a viewport point, or (-1, -1).
func badge_at(pos: Vector2) -> Vector2i:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_d := INF
	for i in c.stage.huds.size():
		var hud: UnitHud = c.stage.huds[i]
		if not hud.visible or int(c.stage.data[i].get("hp", 0)) <= 0:
			continue
		for k in hud.affix_badges.size():
			var b := hud.affix_badges[k]
			var r := _screen_radius(cam, b)
			var sp := _to_overlay(cam.unproject_position(b.global_position))
			var d := sp.distance_to(_to_overlay(pos))
			if d <= maxf(r.y, TOUCH) and d < best_d:
				best_d = d
				best = Vector2i(i, k)
	return best


## Badge centre (overlay coords) and radius in px.
func _screen_radius(cam: Camera3D, b: MeshInstance3D) -> Vector2:
	var p := b.global_position
	var edge := p + cam.global_basis.x * (UnitHud.AFFIX_SIZE * 0.5 * b.global_basis.get_scale().x)
	var a := _to_overlay(cam.unproject_position(p))
	var e := _to_overlay(cam.unproject_position(edge))
	return Vector2(0, a.distance_to(e))


func _to_overlay(vp: Vector2) -> Vector2:
	# viewport pixels -> this control's (canvas-scaled) coordinates
	return get_global_transform_with_canvas().affine_inverse() * vp


## Shows the tip for enemy i's badge k (pinned for `pin` seconds; 0 = follows the pointer).
func show_tip(i: int, k: int, pin := 3.0) -> void:
	if i < 0 or i >= c.stage.huds.size():
		return
	var hud: UnitHud = c.stage.huds[i]
	if k < 0 or k >= hud.affixes.size():
		return
	var a := String(hud.affixes[k])
	var col := SkinRules.affix_color(a)
	# the shared tooltip recipe (UiTooltip): rim in the affix colour, its icon, the rule and
	# the live value
	UiTooltip.fill(_panel, AffixDefs.name_of(a), "", String(AffixDefs.card(a).desc), col,
		{"icon": String(SkinRules.AFFIXES[a].icon), "icon_px": 44, "status": live_value(a, i),
		"max_w": minf(360.0, size.x - 120.0)})
	_panel.visible = true
	var cam := get_viewport().get_camera_3d()
	var anchor := Rect2()
	if cam:
		var b := hud.affix_badges[k]
		var at := _to_overlay(cam.unproject_position(b.global_position))
		var g := get_global_transform() * at
		anchor = Rect2(g - Vector2(26, 26), Vector2(52, 52))
	# under the badge, flipped above near the bottom, clamped inside the safe area
	UiTooltip.place(_panel, self, anchor)
	_shown = Vector2i(i, k)
	_pinned = pin


func _hide() -> void:
	_panel.visible = false
	_shown = Vector2i(-1, -1)


## The live number for the tooltip, read from the flow's combat state (display only).
func live_value(a: String, i: int) -> String:
	var e: Dictionary = c.stage.data[i]
	if c.flow and c.flow.combat and i < c.flow.combat.enemies.size():
		e = c.flow.combat.enemies[i]
	match a:
		"armored":
			return "Block %d, never expires" % int(e.get("block", 0))
		"thorned":
			return "Reflects %d" % int(e.get("thorns_value", AffixDefs.THORNS_EARLY))
		"warded":
			var others := 0
			for j in c.stage.data.size():
				if j != i and int(c.stage.data[j].get("hp", 0)) > 0 and not "ward_allies" in (c.stage.data[j].get("traits", []) as Array):
					others += 1
			return "Active: %d %s shield it" % [others, "ally" if others == 1 else "allies"] if others > 0 else "Inactive: no unwarded ally left"
		"piercing":
			return "Your Block does nothing against it"
		"frenzied":
			return "Frenzied +%d/+%d" % [int(e.get("frenzy", 0)), EnemyDefs.FRENZY_MAX]
		"regenerating":
			var h := maxi(1, int(round(int(e.get("max_hp", 1)) * AffixDefs.REGEN_PCT)))
			return "Suppressed: poisoned" if int(e.get("poison", 0)) > 0 else "Heals %d each action" % h
		"vampiric":
			return "Its attacks heal it"
		"hexing":
			var n := int(e.get("actions", 0))
			var j := ((AffixDefs.HEX_EVERY - n % AffixDefs.HEX_EVERY) % AffixDefs.HEX_EVERY) + 1
			return "Hexes on its next action" if j == 1 else "Next hex in %d actions" % j
		"frostbound":
			return "First attack chills: spent" if bool(e.get("chilled", false)) else "First attack chills: ready"
		"gilded":
			return "x3 gold, +%d pet charge on kill" % AffixDefs.GILDED_PET_CHARGE
	return ""

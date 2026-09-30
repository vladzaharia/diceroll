class_name UnitHud
extends Node3D
## World-anchored enemy HUD: HP bar (with trailing damage, block frame, boss phase ticks),
## HP numbers, a block badge, the intent badge + value, and status pips. The node turns to
## face the active camera every frame, so the layout stays screen-aligned and crisp.
##
## Badges (intent, traits, affixes, scare, brave, statuses) share badge.gdshader: the RhosGFX
## icon (Icons.tex fixed raster) as style C (full-colour glyph, navy disc, accent rim) when the
## badge is 40 px or more on screen, style B (white glyph on an accent disc) when it is small.
## Without the pack the intents keep the SDF glyphs (intent_icon.gdshader) and the rest the
## legacy glyphs. Everything sits under `_root`, which carries the --ui-scale factor and a
## phone size floor (see _process), so tweens on the node's own scale keep working.

const INTENT_KINDS := {"attack": 0, "block": 1, "buff": 2, "curse": 3, "summon": 4, "aim": 6, "chaos": 7,
	"heal": 8, "drain": 9, "burn": 10, "chill": 11, "scorch": 12, "rally": 2, "bury": 17, "moonfall": 18}
## Trait chips under the HP bar (intent_icon.gdshader kinds).
const TRAIT_KINDS := {"armor": 13, "thorns": 14, "ward": 15, "pierce": 16}
const INTENT_COLORS := {
	"attack": Color(0.9, 0.24, 0.22), "block": Color(0.28, 0.55, 0.95), "buff": Color(0.98, 0.55, 0.18),
	"curse": Color(0.6, 0.3, 0.9), "summon": Color(0.35, 0.7, 0.45), "aim": Color(0.42, 0.46, 0.6),
	"chaos": Color(0.85, 0.28, 0.72), "heal": Color(0.3, 0.72, 0.36), "drain": Color(0.66, 0.12, 0.24),
	"burn": Color(0.95, 0.42, 0.12), "chill": Color(0.36, 0.68, 0.92), "scorch": Color(0.78, 0.28, 0.08),
	"armor": Color(0.5, 0.5, 0.56), "thorns": Color(0.42, 0.62, 0.26), "ward": Color(0.56, 0.36, 0.86),
	"pierce": Color(0.9, 0.4, 0.22), "rally": Color(0.86, 0.3, 0.12),
	"bury": Color(0.78, 0.58, 0.28), "moonfall": Color(0.42, 0.44, 0.82),
}
## Traits without a drawn chip kind use their affix badge glyph (frenzy on the Orc Raider).
const TRAIT_ICONS := {"frenzy": "affix_frenzied", "ward_allies": "affix_warded"}
const AFFIX_SHADER := preload("res://game/world/shaders/affix_badge.gdshader")
const BADGE_SHADER := preload("res://game/world/shaders/badge.gdshader")
const AFFIX_SIZE := 0.32
const BAR_SIZE := Vector2(1.3, 0.2)
## Status pips under the HP bar (style B), in this order: data key -> [icon id, colour].
const STATUSES := {"poison": ["poison", Color("7ad35a")], "frozen": ["frozen", Color("6ab8ee")],
	"weakened": ["weakened", Color(0.36, 0.62, 0.24)], "frenzy": ["frenzy", Color(0.93, 0.36, 0.2)]}
const STATUS_SIZE := 0.3
## Badge style by on-screen disc size (base 720-canvas px): style C at STYLE_C_PX and up,
## style B at STYLE_B_PX and below (the spec's 40 px / 28 px on screen), blended between.
const STYLE_C_PX := 46.0
const STYLE_B_PX := 34.0
## Phone floor: the intent disc is never drawn smaller than this (base canvas px, about 36 pt on
## an iPhone; desktops and iPads are well above it), up to MAX_BOOST x the authored size.
const MIN_INTENT_PX := 64.0
const MAX_BOOST := 1.6
## Label3D outline (navy, not brown: contrast on the dark Moonlit / Magma boards).
const OUTLINE_COL := Color(0.043, 0.047, 0.1, 1.0)
const OUTLINE_PX := 16

var bar: MeshInstance3D
var hp_label: Label3D
var name_label: Label3D
var intent_badge: MeshInstance3D
var intent_label: Label3D
var block_badge: MeshInstance3D
var block_label: Label3D
var status_label: Label3D
## Status pips row (replaces the old status text line; status_label stays, hidden, for tests).
var status_row: Node3D
var _status_key := ""
## Everything the HUD draws hangs under this (the scale floor / --ui-scale factor).
var _root := Node3D.new()
var _boost := 1.0
## Badge meshes whose style follows their on-screen size: [mesh, authored size].
var _styled: Array = []
var trait_chips: Array[MeshInstance3D] = []
var _traits: Array = []
## Affix badges (up to 2) in a row under the HP bar; `affixes` is what they show.
var affix_badges: Array[MeshInstance3D] = []
var affixes: Array = []
var _affix_count: Label3D
## The Moon King's moon meter (data keys moon / moon_max / moon_blood): a moon disc that fills
## with the tide, pips for the tide steps; hidden for everyone else.
var moon_badge: MeshInstance3D
var _moon_mat: ShaderMaterial
var _moon := -99
var _moon_fill := 0.0
var _moon_tween: Tween
const MOON_SIZE := 0.64
## A short-lived note under the HP bar (the moon meter's "TIDE 2/4"): laid out in the HUD's own
## frame, below the status line and affix row, so it never covers the intent, HP or the moon.
var note_label: Label3D
var _note_tween: Tween

## BOO! (Monster Kid): a cowering enemy's intent shows a scared face; a Brave chip after.
var scare_badge: MeshInstance3D
var brave_chip: MeshInstance3D
const SCARE_COLOR := Color(0.36, 0.62, 0.24)

var _bar_mat: ShaderMaterial
var _intent_mat: ShaderMaterial
var _block_mat: ShaderMaterial
var _hp := -1
var _max_hp := 1
var _ghost := 1.0
var _ghost_tween: Tween
var _intent_key := ""


func _init() -> void:
	name = "UnitHud"
	_root.name = "Root"
	add_child(_root)
	bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = BAR_SIZE
	bar.mesh = q
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = preload("res://game/world/shaders/hp_bar.gdshader")
	_bar_mat.set_shader_parameter("size", BAR_SIZE)
	_style_bar(_bar_mat)
	_bar_mat.render_priority = 10
	bar.material_override = _bar_mat
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(bar)
	hp_label = _label(52, Color(1, 1, 1), 12)
	hp_label.position = Vector3(0, 0.005, 0.01)
	hp_label.outline_size = OUTLINE_PX
	_root.add_child(hp_label)
	intent_badge = _badge(0.46) if not Icons.is_mapped("intent_attack") else badge("intent_attack", INTENT_COLORS.attack, 0.46)
	_intent_mat = intent_badge.material_override
	_track(intent_badge, 0.46)
	intent_badge.position = Vector3(-0.2, 0.42, 0)
	_root.add_child(intent_badge)
	intent_label = _label(96, Color(1.0, 0.97, 0.9), 12)
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	intent_label.position = Vector3(0.06, 0.42, 0.01)
	_root.add_child(intent_label)
	if Icons.is_mapped("intent_block"):
		# a blue flat round badge with an ink number (spec 4.2)
		block_badge = badge("", UiPalette.PACK_BLUE, 0.36, 0.0)
		_block_mat = block_badge.material_override
	else:
		block_badge = _badge(0.36)
		_block_mat = block_badge.material_override
		_block_mat.set_shader_parameter("kind", 1)
		_block_mat.set_shader_parameter("bg_color", INTENT_COLORS["block"])
	block_badge.position = Vector3(-BAR_SIZE.x * 0.5 - 0.1, 0.0, 0.005)
	_root.add_child(block_badge)
	block_label = _label(60, Color(1, 1, 1), 13)
	block_label.position = block_badge.position + Vector3(0, -0.005, 0.01)
	block_label.outline_size = OUTLINE_PX
	if Icons.is_mapped("intent_block"):
		block_label.modulate = UiPalette.TEXT_DARK
		block_label.outline_size = 0
	_root.add_child(block_label)
	status_label = _label(54, Color(0.6, 1.0, 0.45), 12)
	status_label.position = Vector3(0, -0.2, 0.01)
	status_label.visible = false
	_root.add_child(status_label)
	status_row = Node3D.new()
	status_row.name = "Statuses"
	status_row.position = Vector3(0, -0.24, 0.006)
	_root.add_child(status_row)
	scare_badge = affix_badge("intent_cower", SCARE_COLOR, 0.46)
	_track(scare_badge, 0.46)
	scare_badge.name = "Cower"
	scare_badge.position = Vector3(0.0, 0.42, 0.0)
	scare_badge.visible = false
	_root.add_child(scare_badge)
	brave_chip = affix_badge("trait_brave", Color(0.72, 0.56, 0.2), 0.28)
	_track(brave_chip, 0.28)
	brave_chip.name = "Brave"
	brave_chip.position = Vector3(-BAR_SIZE.x * 0.5 - 0.1, 0.0, 0.006)
	brave_chip.visible = false
	_root.add_child(brave_chip)
	name_label = _label(64, Color(1.0, 0.86, 0.5), 12)
	name_label.position = Vector3(0, 0.82, 0.01)
	name_label.visible = false
	_root.add_child(name_label)
	moon_badge = MeshInstance3D.new()
	moon_badge.name = "MoonMeter"
	moon_badge.mesh = Props.quad(MOON_SIZE)
	_moon_mat = ShaderMaterial.new()
	_moon_mat.shader = preload("res://game/world/shaders/moon_meter.gdshader")
	_moon_mat.render_priority = 11
	if Icons.is_mapped("moon_full"):
		_moon_mat.set_shader_parameter("moon_tex", Icons.tex("moon_full", 256))
		_moon_mat.set_shader_parameter("use_tex", 1.0)
		_moon_mat.set_shader_parameter("rim_color", OUTLINE_COL)
	moon_badge.material_override = _moon_mat
	moon_badge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon_badge.position = Vector3(BAR_SIZE.x * 0.5 + 0.12, 0.5, 0.0)
	moon_badge.visible = false
	_root.add_child(moon_badge)
	note_label = _label(72, Color.WHITE, 14)
	note_label.name = "Note"
	note_label.visible = false
	_root.add_child(note_label)


func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var s := scale
		global_basis = cam.global_basis.orthonormalized().scaled(s)
		_fit_screen(cam)


## The world HUD's share of the UI size: the window's content scale (--ui-scale, the Settings
## UI size), damped, so the 3D HUDs grow with the 2D HUD. Used by UnitHud, Fx.popup_text and the board
## markers.
static func world_ui_scale(node: Node) -> float:
	if node == null or not node.is_inside_tree():
		return 1.0
	var w := node.get_window()
	# damped (square root): the 3D HUDs share the board with their neighbours, so at 150 % they
	# grow about 1.22x instead of crowding each other
	return sqrt(clampf(w.content_scale_factor, 0.6, 2.0)) if w else 1.0


## Base-canvas px (the 720-wide layout canvas, before --ui-scale) per world unit at `at`.
static func canvas_px_per_unit(node: Node, cam: Camera3D, at: Vector3) -> float:
	if cam.is_position_behind(at):
		return 0.0
	# unproject_position gives the viewport's logical (canvas) coordinates, which --ui-scale
	# shrinks: multiply back to the base canvas
	var a := cam.unproject_position(at)
	var b := cam.unproject_position(at + cam.global_basis.x)
	var w := node.get_window()
	return a.distance_to(b) * (w.content_scale_factor if w else 1.0)


## --ui-scale factor and the phone floor on `_root`, then each badge's style from its size.
func _fit_screen(cam: Camera3D) -> void:
	var ppu := canvas_px_per_unit(self, cam, global_position)
	if ppu <= 0.0:
		return
	var s := maxf(scale.x, 0.01)
	# the floor is measured on the settled HUD (not mid rise-in, when scale is tiny)
	if s > 0.5:
		var boost := clampf(MIN_INTENT_PX / maxf(0.46 * ppu * s, 1.0), 1.0, MAX_BOOST)
		if absf(boost - _boost) > 0.02:
			_boost = boost
	var f := world_ui_scale(self) * _boost
	if not _root.scale.is_equal_approx(Vector3.ONE * f):
		_root.scale = Vector3.ONE * f
	for e in _styled:
		var mi: MeshInstance3D = e[0]
		if not is_instance_valid(mi):
			continue
		var m := mi.material_override as ShaderMaterial
		if m == null or m.shader != BADGE_SHADER:
			continue
		var px := float(e[1]) * ppu * s * _boost
		var st := clampf((px - STYLE_B_PX) / (STYLE_C_PX - STYLE_B_PX), 0.0, 1.0)
		if absf(float(m.get_shader_parameter("style")) - st) > 0.05:
			m.set_shader_parameter("style", st)


func _track(mi: MeshInstance3D, size: float) -> void:
	_styled = _styled.filter(func(e: Array) -> bool: return is_instance_valid(e[0]))
	_styled.append([mi, size])


## data: {hp, max_hp, block, intent:{kind, value}, boss, name, poison, frozen, phase}
func set_data(data: Dictionary, animate := true) -> void:
	var hp := int(data.get("hp", 0))
	var max_hp := maxi(int(data.get("max_hp", 1)), 1)
	var frac := clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var boss := bool(data.get("boss", false))
	_bar_mat.set_shader_parameter("segments", 2.0 if boss else 1.0)
	_bar_mat.set_shader_parameter("fill", frac)
	if not animate or _hp < 0 or hp > _hp:
		_set_ghost(frac)
	elif hp < _hp:
		if _ghost_tween:
			_ghost_tween.kill()
		_ghost_tween = create_tween()
		_ghost_tween.tween_interval(0.35)
		_ghost_tween.tween_method(_set_ghost, _ghost, frac, 0.45).set_trans(Tween.TRANS_CUBIC)
		_punch(bar)
	_hp = hp
	_max_hp = max_hp
	hp_label.text = "%d/%d" % [hp, max_hp]
	var block := int(data.get("block", 0))
	_bar_mat.set_shader_parameter("shielded", 1.0 if block > 0 else 0.0)
	block_badge.visible = block > 0
	block_label.visible = block > 0
	block_label.text = str(block)
	var intent: Dictionary = data.get("intent", {})
	set_intent(String(intent.get("kind", "")), int(intent.get("value", 0)), animate)
	var st := PackedStringArray()
	var pips := {}
	if int(data.get("poison", 0)) > 0:
		st.append("POISON %d" % int(data.get("poison", 0)))
		pips["poison"] = str(int(data.get("poison", 0)))
	if bool(data.get("frozen", false)):
		st.append("FROZEN")
		pips["frozen"] = ""
	if bool(data.get("weakened", false)):
		st.append("SPOOKED")
		pips["weakened"] = ""
	status_label.text = "  ".join(st)
	status_label.modulate = Fx.STATUS_COLORS["poison"] if int(data.get("poison", 0)) > 0 else Fx.STATUS_COLORS["frost"]
	if bool(data.get("weakened", false)) and int(data.get("poison", 0)) <= 0 and not bool(data.get("frozen", false)):
		status_label.modulate = SCARE_COLOR.lightened(0.45)
	if data.has("affixes"):
		set_affixes(data.affixes, int(data.get("frenzy", 0)))
	if int(data.get("frenzy", 0)) > 0 and not affixes.has("frenzied"):
		st.append("FRENZY +%d" % int(data.frenzy))
		pips["frenzy"] = "+%d" % int(data.frenzy)
		status_label.text = "  ".join(st)
		status_label.modulate = SkinRules.AFFIXES.frenzied.color
	set_statuses(pips, animate)
	if data.has("traits"):
		set_traits(data.traits)
	if data.has("moon"):
		set_moon(int(data.moon), int(data.get("moon_max", 4)), bool(data.get("moon_blood", false)), animate)
	set_scared(bool(data.get("cower", false)), bool(data.get("brave", false)), animate)
	var nm := String(data.get("name", ""))
	var mini := bool(data.get("miniboss", false))
	name_label.visible = (boss or mini) and nm != ""
	name_label.text = nm.to_upper()
	name_label.modulate = Color(1.0, 0.7, 0.45) if mini else Color(1.0, 0.86, 0.5)


func set_intent(kind: String, value: int, animate := true) -> void:
	var key := "%s:%d" % [kind, value]
	intent_badge.visible = kind != ""
	intent_label.visible = kind != "" and value > 0 and not kind in ["curse", "summon", "aim", "chaos", "scorch"]
	if kind == "":
		_intent_key = key
		return
	if _intent_mat.shader == BADGE_SHADER:
		var id := "intent_" + kind
		_intent_mat.set_shader_parameter("icon", Icons.tex(id if Icons.is_mapped(id) else "intent_unknown", 256))
	else:
		_intent_mat.set_shader_parameter("kind", int(INTENT_KINDS.get(kind, 5)))
	_intent_mat.set_shader_parameter("bg_color", INTENT_COLORS.get(kind, Color(0.5, 0.5, 0.5)))
	intent_label.text = str(value)
	var centred := not intent_label.visible
	intent_badge.position.x = 0.0 if centred else -0.2
	if animate and key != _intent_key:
		_punch(intent_badge, 1.35)
	_intent_key = key


## The moon meter: `value` of `max` tide steps (a negative start shows as empty), red in the blood
## moon (phase 2). Animates the fill and punches on a change.
func set_moon(value: int, max_v: int, blood := false, animate := true) -> void:
	moon_badge.visible = true
	_moon_mat.set_shader_parameter("pips", maxi(max_v, 1))
	_moon_mat.set_shader_parameter("lit", clampi(value, 0, max_v))
	_moon_mat.set_shader_parameter("blood", 1.0 if blood else 0.0)
	var f := clampf(float(value) / float(maxi(max_v, 1)), 0.0, 1.0)
	if _moon_tween:
		_moon_tween.kill()
	if animate and value != _moon and _moon != -99:
		_moon_tween = create_tween()
		_moon_tween.tween_method(_set_moon_fill, _moon_fill, f, 0.45).set_trans(Tween.TRANS_CUBIC)
		_moon_tween.parallel().tween_method(func(v: float) -> void: _moon_mat.set_shader_parameter("pulse", v), 0.8, 0.0, 0.6)
		_punch(moon_badge, 1.35)
	else:
		_set_moon_fill(f)
	_moon = value


## Pops `text` in under the HP bar (below the status line / affix row), holds, fades out.
func flash_note(text: String, color: Color, hold := 0.9) -> void:
	note_label.text = text
	note_label.modulate = color
	note_label.outline_modulate.a = 1.0
	note_label.position = Vector3(0, -0.66 if not affixes.is_empty() else -0.44, 0.012)
	note_label.visible = true
	if _note_tween:
		_note_tween.kill()
	note_label.scale = Vector3.ONE * 0.3
	_note_tween = create_tween()
	_note_tween.tween_property(note_label, "scale", Vector3.ONE * 1.15, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_note_tween.tween_property(note_label, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	_note_tween.tween_interval(hold)
	_note_tween.tween_property(note_label, "modulate:a", 0.0, 0.3)
	_note_tween.parallel().tween_property(note_label, "outline_modulate:a", 0.0, 0.3)
	_note_tween.tween_callback(func() -> void: note_label.visible = false)


func _set_moon_fill(v: float) -> void:
	_moon_fill = v
	_moon_mat.set_shader_parameter("fill", v)

## BOO!: `cower` swaps the intent for the scared face (its next action is skipped); `brave`
## (scared once this fight) shows a small chip left of the HP bar, under the block badge.
func set_scared(cower: bool, brave: bool, animate := true) -> void:
	if cower != scare_badge.visible:
		scare_badge.visible = cower
		if cower and animate:
			_punch(scare_badge, 1.4)
	intent_badge.visible = intent_badge.visible and not cower
	intent_label.visible = intent_label.visible and not cower
	var show_brave := brave and not cower and not block_badge.visible
	if show_brave != brave_chip.visible:
		brave_chip.visible = show_brave
		if show_brave and animate:
			_punch(brave_chip, 1.3)


## Trait chips (armor, thorns, ward, pierce) to the right of the HP bar.
func set_traits(traits: Array) -> void:
	# an affix's badge already shows the trait it grants
	var covered := SkinRules.affix_traits(affixes)
	var list: Array = traits.filter(func(t: Variant) -> bool:
		return (TRAIT_KINDS.has(String(t)) or TRAIT_ICONS.has(String(t))) and not covered.has(String(t)))
	if list == _traits:
		return
	_traits = list.duplicate()
	for c in trait_chips:
		c.queue_free()
	trait_chips.clear()
	for k in list.size():
		var t := String(list[k])
		var chip: MeshInstance3D
		if TRAIT_KINDS.has(t) and Icons.is_mapped("trait_" + t):
			chip = badge("trait_" + t, INTENT_COLORS.get(t, Color(0.5, 0.5, 0.5)), 0.3)
		elif TRAIT_KINDS.has(t):
			chip = _badge(0.3)
			var m: ShaderMaterial = chip.material_override
			m.set_shader_parameter("kind", int(TRAIT_KINDS[t]))
			m.set_shader_parameter("bg_color", INTENT_COLORS.get(t, Color(0.5, 0.5, 0.5)))
		else:
			chip = affix_badge(String(TRAIT_ICONS[t]), SkinRules.TRAITS[t].color, 0.3)
		chip.name = "Trait_" + t
		chip.position = Vector3(BAR_SIZE.x * 0.5 + 0.2 + 0.32 * k, 0.0, 0.005)
		_root.add_child(chip)
		trait_chips.append(chip)
		_track(chip, 0.3)
		_punch(chip, 1.3)


## Affix badges under the HP bar (AffixDefs ids, max 2); a Frenzied badge shows its stacks.
func set_affixes(list: Array, frenzy := 0) -> void:
	var ids: Array = list.filter(func(a: Variant) -> bool: return SkinRules.AFFIXES.has(String(a))).slice(0, 2)
	if ids != affixes:
		affixes = ids.duplicate()
		for b in affix_badges:
			b.queue_free()
		affix_badges.clear()
		if _affix_count:
			_affix_count.queue_free()
			_affix_count = null
		for k in ids.size():
			var a := String(ids[k])
			var b := affix_badge(String(SkinRules.AFFIXES[a].icon), SkinRules.AFFIXES[a].color, AFFIX_SIZE)
			b.name = "Affix_" + a
			b.position = Vector3((float(k) - (ids.size() - 1) * 0.5) * (AFFIX_SIZE + 0.05), -0.29, 0.006)
			_root.add_child(b)
			affix_badges.append(b)
			_track(b, AFFIX_SIZE)
			_punch(b, 1.3)
			if a == "frenzied":
				_affix_count = _label(44, Color(1.0, 0.95, 0.85), 14)
				_affix_count.outline_size = OUTLINE_PX
				_affix_count.position = b.position + Vector3(AFFIX_SIZE * 0.42, -AFFIX_SIZE * 0.3, 0.01)
				_root.add_child(_affix_count)
		status_label.position.y = -0.2 if ids.is_empty() else -0.56
		status_row.position.y = -0.24 if ids.is_empty() else -0.6
	if _affix_count:
		_affix_count.text = "+%d" % frenzy if frenzy > 0 else ""


## A proc: the affix's badge flashes and punches.
func flash_affix(a: String) -> void:
	var k := affixes.find(a)
	if k < 0 or k >= affix_badges.size():
		return
	var b := affix_badges[k]
	_punch(b, 1.5)
	var m := b.material_override as ShaderMaterial
	var t := b.create_tween()
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("glow", v), 0.9, 0.0, 0.5)


## Status pips (style B, STATUS_SIZE) with a count beside those that carry one:
## `pips` = {status key: count text ("" = none)}, in STATUSES order, centred under the bar.
func set_statuses(pips: Dictionary, animate := true) -> void:
	var key := str(pips)
	if key == _status_key:
		return
	var was := _status_key
	_status_key = key
	for c in status_row.get_children():
		c.queue_free()
	var items: Array = []
	for k in STATUSES:
		if pips.has(k):
			items.append([k, String(pips[k])])
	var widths: Array = []
	var total := 0.0
	for it in items:
		var w := STATUS_SIZE + (0.07 * float(String(it[1]).length()) + 0.04 if String(it[1]) != "" else 0.0)
		widths.append(w)
		total += w
	total += 0.06 * maxf(float(items.size() - 1), 0.0)
	var x := -total * 0.5
	for n in items.size():
		var k := String(items[n][0])
		var spec: Array = STATUSES[k]
		var b := affix_badge(String(spec[0]), spec[1], STATUS_SIZE, 0.0)
		b.name = "Status_" + k
		b.position = Vector3(x + STATUS_SIZE * 0.5, 0, 0)
		status_row.add_child(b)
		if String(items[n][1]) != "":
			var l := _label(50, (spec[1] as Color).lerp(Color.WHITE, 0.45), 14)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			l.outline_size = OUTLINE_PX
			l.text = String(items[n][1])
			l.position = Vector3(x + STATUS_SIZE + 0.02, -0.005, 0.01)
			status_row.add_child(l)
		if animate and was != "" and not was.contains(k):
			_punch(b, 1.35)
		x += float(widths[n]) + 0.06


## Unified world badge (badge.gdshader): pack icon `icon` (Icons.tex fixed raster; "" = a plain
## disc) with `color` as the rim (style 1 = C) or the disc (style 0 = B). The unit HUD sets the
## style per frame from the badge's size on screen.
static func badge(icon: String, color: Color, size: float, style := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Props.quad(size)
	var m := ShaderMaterial.new()
	m.shader = BADGE_SHADER
	m.render_priority = 11
	m.set_shader_parameter("icon", Icons.tex(icon, 256 if size >= 0.4 else 192) if icon != "" else _blank())
	m.set_shader_parameter("bg_color", color)
	m.set_shader_parameter("rim_color", OUTLINE_COL)
	m.set_shader_parameter("disc_color", UiPalette.NAVY)
	m.set_shader_parameter("style", style)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static var _blank_tex: Texture2D


static func _blank() -> Texture2D:
	if _blank_tex == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_blank_tex = ImageTexture.create_from_image(img)
	return _blank_tex


## Round glyph badge (an icon on a coloured disc): the unified badge when the pack maps `icon`
## (`style` as badge(); board chips pass 0 = B), else the legacy look (UiIcons glyph).
static func affix_badge(icon: String, color: Color, size: float, style := 1.0) -> MeshInstance3D:
	if Icons.is_mapped(icon):
		return badge(icon, color, size, style)
	var mi := MeshInstance3D.new()
	mi.mesh = Props.quad(size)
	var m := ShaderMaterial.new()
	m.shader = AFFIX_SHADER
	m.render_priority = 11
	m.set_shader_parameter("icon", Icons.tex(icon, 96, Color(1.0, 0.97, 0.9)))
	m.set_shader_parameter("bg_color", color.darkened(0.15))
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func set_opacity(a: float) -> void:
	for c in affix_badges:
		(c.material_override as ShaderMaterial).set_shader_parameter("opacity", a)
	if _affix_count:
		_affix_count.modulate.a = a
		_affix_count.outline_modulate.a = a
	for c in trait_chips:
		(c.material_override as ShaderMaterial).set_shader_parameter("opacity", a)
	for c in [scare_badge, brave_chip]:
		((c as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("opacity", a)
	for m in [_bar_mat, _intent_mat, _block_mat, _moon_mat]:
		(m as ShaderMaterial).set_shader_parameter("opacity", a)
	for l in [hp_label, intent_label, block_label, status_label, name_label]:
		(l as Label3D).modulate.a = a
		(l as Label3D).outline_modulate.a = a
	for c in status_row.get_children():
		if c is MeshInstance3D:
			((c as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("opacity", a)
		elif c is Label3D:
			(c as Label3D).modulate.a = a
			(c as Label3D).outline_modulate.a = a


func _set_ghost(v: float) -> void:
	_ghost = v
	_bar_mat.set_shader_parameter("ghost", v)


func _punch(n: Node3D, amount := 1.15) -> void:
	var t := n.create_tween()
	t.tween_property(n, "scale", Vector3.ONE * amount, 0.07)
	t.tween_property(n, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _label(size: int, color: Color, priority: int) -> Label3D:
	var l := Label3D.new()
	l.font = Props.font(true)
	l.font_size = size
	l.pixel_size = 0.0034
	l.modulate = color
	l.outline_size = 20
	l.outline_modulate = OUTLINE_COL
	l.no_depth_test = true
	l.double_sided = true
	l.fixed_size = false
	l.render_priority = priority
	l.outline_render_priority = priority - 1
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return l


## HP bar colours from the pack palette (spec 4.2: red fill, SLATE well, darkbrown frame).
static func _style_bar(m: ShaderMaterial) -> void:
	if not UiSkin.has("bar_enemy", "background"):
		return
	m.set_shader_parameter("fill_color", UiPalette.PACK_RED)
	m.set_shader_parameter("well_color", UiPalette.SLATE.darkened(0.45))
	m.set_shader_parameter("frame_color", UiPalette.WOOD_DARK.darkened(0.35))
	m.set_shader_parameter("ghost_color", Color("ffe39a"))
	m.set_shader_parameter("flat_band", 1.0)


## Legacy SDF intent badge (fallback without the pack).
func _badge(size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Props.quad(size)
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/world/shaders/intent_icon.gdshader")
	m.render_priority = 11
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

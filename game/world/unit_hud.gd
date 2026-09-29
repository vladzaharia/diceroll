class_name UnitHud
extends Node3D
## World-anchored enemy HUD: HP bar (with trailing damage, block frame, boss phase ticks),
## HP numbers, a block badge, the intent badge + value, and status pips. The node turns to
## face the active camera every frame, so the layout stays screen-aligned and crisp.

const INTENT_KINDS := {"attack": 0, "block": 1, "buff": 2, "curse": 3, "summon": 4, "aim": 6, "chaos": 7,
	"heal": 8, "drain": 9, "burn": 10, "chill": 11, "scorch": 12, "rally": 2}
## Trait chips under the HP bar (intent_icon.gdshader kinds).
const TRAIT_KINDS := {"armor": 13, "thorns": 14, "ward": 15, "pierce": 16}
const INTENT_COLORS := {
	"attack": Color(0.9, 0.24, 0.22), "block": Color(0.28, 0.55, 0.95), "buff": Color(0.98, 0.55, 0.18),
	"curse": Color(0.6, 0.3, 0.9), "summon": Color(0.35, 0.7, 0.45), "aim": Color(0.42, 0.46, 0.6),
	"chaos": Color(0.85, 0.28, 0.72), "heal": Color(0.3, 0.72, 0.36), "drain": Color(0.66, 0.12, 0.24),
	"burn": Color(0.95, 0.42, 0.12), "chill": Color(0.36, 0.68, 0.92), "scorch": Color(0.78, 0.28, 0.08),
	"armor": Color(0.5, 0.5, 0.56), "thorns": Color(0.42, 0.62, 0.26), "ward": Color(0.56, 0.36, 0.86),
	"pierce": Color(0.9, 0.4, 0.22), "rally": Color(0.86, 0.3, 0.12),
}
## Traits without a drawn chip kind use their affix badge glyph (frenzy on the Orc Raider).
const TRAIT_ICONS := {"frenzy": "affix_frenzied", "ward_allies": "affix_warded"}
const AFFIX_SHADER := preload("res://game/world/shaders/affix_badge.gdshader")
const AFFIX_SIZE := 0.32
const BAR_SIZE := Vector2(1.3, 0.2)

var bar: MeshInstance3D
var hp_label: Label3D
var name_label: Label3D
var intent_badge: MeshInstance3D
var intent_label: Label3D
var block_badge: MeshInstance3D
var block_label: Label3D
var status_label: Label3D
var trait_chips: Array[MeshInstance3D] = []
var _traits: Array = []
## Affix badges (up to 2) in a row under the HP bar; `affixes` is what they show.
var affix_badges: Array[MeshInstance3D] = []
var affixes: Array = []
var _affix_count: Label3D

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
	bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = BAR_SIZE
	bar.mesh = q
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = preload("res://game/world/shaders/hp_bar.gdshader")
	_bar_mat.set_shader_parameter("size", BAR_SIZE)
	_bar_mat.render_priority = 10
	bar.material_override = _bar_mat
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar)
	hp_label = _label(52, Color(1, 1, 1), 12)
	hp_label.position = Vector3(0, 0.005, 0.01)
	hp_label.outline_size = 14
	add_child(hp_label)
	intent_badge = _badge(0.46)
	_intent_mat = intent_badge.material_override
	intent_badge.position = Vector3(-0.2, 0.42, 0)
	add_child(intent_badge)
	intent_label = _label(96, Color(1.0, 0.97, 0.9), 12)
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	intent_label.position = Vector3(0.06, 0.42, 0.01)
	add_child(intent_label)
	block_badge = _badge(0.36)
	_block_mat = block_badge.material_override
	_block_mat.set_shader_parameter("kind", 1)
	_block_mat.set_shader_parameter("bg_color", INTENT_COLORS["block"])
	block_badge.position = Vector3(-BAR_SIZE.x * 0.5 - 0.1, 0.0, 0.005)
	add_child(block_badge)
	block_label = _label(60, Color(1, 1, 1), 13)
	block_label.position = block_badge.position + Vector3(0, -0.005, 0.01)
	block_label.outline_size = 12
	add_child(block_label)
	status_label = _label(54, Color(0.6, 1.0, 0.45), 12)
	status_label.position = Vector3(0, -0.2, 0.01)
	add_child(status_label)
	name_label = _label(64, Color(1.0, 0.86, 0.5), 12)
	name_label.position = Vector3(0, 0.82, 0.01)
	name_label.visible = false
	add_child(name_label)


func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		var s := scale
		global_basis = cam.global_basis.orthonormalized().scaled(s)


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
	if int(data.get("poison", 0)) > 0:
		st.append("POISON %d" % int(data.get("poison", 0)))
	if bool(data.get("frozen", false)):
		st.append("FROZEN")
	status_label.text = "  ".join(st)
	status_label.modulate = Fx.STATUS_COLORS["poison"] if int(data.get("poison", 0)) > 0 else Fx.STATUS_COLORS["frost"]
	if data.has("affixes"):
		set_affixes(data.affixes, int(data.get("frenzy", 0)))
	if int(data.get("frenzy", 0)) > 0 and not affixes.has("frenzied"):
		st.append("FRENZY +%d" % int(data.frenzy))
		status_label.text = "  ".join(st)
		status_label.modulate = SkinRules.AFFIXES.frenzied.color
	if data.has("traits"):
		set_traits(data.traits)
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
	_intent_mat.set_shader_parameter("kind", int(INTENT_KINDS.get(kind, 5)))
	_intent_mat.set_shader_parameter("bg_color", INTENT_COLORS.get(kind, Color(0.5, 0.5, 0.5)))
	intent_label.text = str(value)
	var centred := not intent_label.visible
	intent_badge.position.x = 0.0 if centred else -0.2
	if animate and key != _intent_key:
		_punch(intent_badge, 1.35)
	_intent_key = key


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
		if TRAIT_KINDS.has(t):
			chip = _badge(0.3)
			var m: ShaderMaterial = chip.material_override
			m.set_shader_parameter("kind", int(TRAIT_KINDS[t]))
			m.set_shader_parameter("bg_color", INTENT_COLORS.get(t, Color(0.5, 0.5, 0.5)))
		else:
			chip = affix_badge(String(TRAIT_ICONS[t]), SkinRules.TRAITS[t].color, 0.3)
		chip.name = "Trait_" + t
		chip.position = Vector3(BAR_SIZE.x * 0.5 + 0.2 + 0.32 * k, 0.0, 0.005)
		add_child(chip)
		trait_chips.append(chip)
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
			add_child(b)
			affix_badges.append(b)
			_punch(b, 1.3)
			if a == "frenzied":
				_affix_count = _label(44, Color(1.0, 0.95, 0.85), 14)
				_affix_count.outline_size = 12
				_affix_count.position = b.position + Vector3(AFFIX_SIZE * 0.42, -AFFIX_SIZE * 0.3, 0.01)
				add_child(_affix_count)
		status_label.position.y = -0.2 if ids.is_empty() else -0.56
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


## Round glyph badge (UiIcons icon on a coloured disc).
static func affix_badge(icon: String, color: Color, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Props.quad(size)
	var m := ShaderMaterial.new()
	m.shader = AFFIX_SHADER
	m.render_priority = 11
	m.set_shader_parameter("icon", UiIcons.tex(icon, 96, Color(1.0, 0.97, 0.9)))
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
	for m in [_bar_mat, _intent_mat, _block_mat]:
		(m as ShaderMaterial).set_shader_parameter("opacity", a)
	for l in [hp_label, intent_label, block_label, status_label, name_label]:
		(l as Label3D).modulate.a = a
		(l as Label3D).outline_modulate.a = a


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
	l.outline_modulate = Color(0.1, 0.05, 0.08, 1.0)
	l.no_depth_test = true
	l.double_sided = true
	l.fixed_size = false
	l.render_priority = priority
	l.outline_render_priority = priority - 1
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return l


func _badge(size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Props.quad(size)
	var m := ShaderMaterial.new()
	m.shader = preload("res://game/world/shaders/intent_icon.gdshader")
	m.render_priority = 11
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

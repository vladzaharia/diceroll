class_name ClassBadge
extends PanelContainer
## The class mechanic badge at the head of the HUD's passives bar: mechanic icon + a live
## state line ("OATH 4", "AIM ×1.3", "STEP 2/2", "SEEDS 2", "BONES 1/2", "TURRET ×0.75",
## "★ BOO!"). Classes without a mechanic show their class icon and name. It pulses on every
## class_triggered event; tap / hover opens the rule (HudTop tooltip).

signal tapped

var class_id := ""
var mechanic := ""
var color := UiPalette.GOLD_BRIGHT
var _icon: TextureRect
var _label: Label
var _dim := false
var _pulse: Tween


static func make(p_class: String) -> ClassBadge:
	var b := ClassBadge.new()
	b.set_class(p_class)
	return b


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var row := UiTheme.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = UiIcons.rect("star", 32)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)
	_label = UiTheme.label("", 20, UiPalette.TEXT, true, 5)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)
	custom_minimum_size.y = 44


func set_class(p_class: String) -> void:
	class_id = p_class
	mechanic = HeroDefs.mechanic(p_class)
	color = ClassInfo.mechanic_color(mechanic) if mechanic != "" else UiPalette.class_color(p_class)
	_icon.texture = UiIcons.tex(UiIcons.mechanic_icon(mechanic) if mechanic != "" else UiIcons.class_icon(p_class), 64)
	_label.text = (ClassInfo.mechanic_name(mechanic) if mechanic != "" else String(HeroDefs.DATA.get(p_class, {}).get("name", ""))).to_upper()
	_style()


## Live state line from the run (combat or board).
func sync(flow: GameFlow) -> void:
	if flow == null:
		return
	if flow.run.class_id != class_id:
		set_class(flow.run.class_id)
	var st := state_text(flow)
	_label.text = String(st[0])
	_dim = bool(st[1])
	_style()


## [text, dimmed] for the badge.
static func state_text(flow: GameFlow) -> Array:
	var run := flow.run
	var c := flow.combat if flow.phase == GameFlow.Phase.COMBAT else null
	match HeroDefs.mechanic(run.class_id):
		"oath":
			var o := c.oath if c != null and c.oath > 0 else ClassLogic.pool_oath(run.dice)
			return ["OATH %d" % o if o > 0 else "OATH", false]
		"aim":
			var am := ClassLogic.aim_mult(c.dice_values.size() if c != null else run.dice.size())
			if c != null and c.rerolls_used_this_turn > 0:
				return ["AIM LOST", true]
			return ["AIM ×%s" % ClassInfo._num(am), false]
		"shadow_step":
			if c != null:
				var left := ClassLogic.NINJA_REFUNDS_PER_TURN - c.refunds_this_turn
				return ["STEP %d/%d" % [left, ClassLogic.NINJA_REFUNDS_PER_TURN], left <= 0]
			return ["SHADOW STEP", flow.board_refunds >= ClassLogic.NINJA_BOARD_REFUNDS]
		"overgrowth":
			var n := 0
			for d in run.dice:
				if d.has_tag("seed"):
					n += 1
			return ["SEEDS %d" % n, false]
		"bone_harvest":
			if c != null:
				return ["BONES %d/%d" % [c.bones_raised, ClassLogic.BONE_MAX], c.bones_raised >= ClassLogic.BONE_MAX]
			return ["BONES", false]
		"turret":
			var tier := int(BiomeDefs.DEFS[run.biome()].tier) if BiomeDefs.has(run.biome()) else run.act
			return ["TURRET ×%s" % ClassInfo._num(float(ClassLogic.TURRET_T[clampi(tier, 1, 3) - 1])), false]
		"boo":
			if c != null:
				var any := false
				for i in c.enemies.size():
					if c.alive(i) and not bool(c.enemies[i].get("brave", false)):
						any = true
				return ["★ BOO!", not any]
			return ["★ BOO!", false]
	return [String(HeroDefs.DATA.get(run.class_id, {}).get("name", "")).to_upper(), false]


## A trigger: flash in the mechanic colour and punch.
func pulse() -> void:
	if not is_inside_tree():
		return
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	pivot_offset = size * 0.5
	scale = Vector2.ONE * 1.28
	modulate = Color(1.6, 1.5, 1.2)
	_pulse = create_tween().set_parallel(true)
	_pulse.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pulse.tween_property(self, "modulate", Color.WHITE, 0.5)


func rule_text() -> String:
	return ClassInfo.rule(mechanic) if mechanic != "" else ClassInfo.tagline(class_id)


func _style() -> void:
	var c := color.darkened(0.45) if _dim else color
	add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.05, 0.05, 0.12, 0.88), 22, 2, Color(c, 0.9 if not _dim else 0.5)), 10, 4))
	_label.label_settings = UiTheme.label_settings(20, c.lightened(0.25) if not _dim else UiPalette.TEXT_MUTED, true, 5)
	_icon.modulate = Color.WHITE if not _dim else Color(1, 1, 1, 0.5)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit()
		accept_event()
	var st := event as InputEventScreenTouch
	if st and st.pressed:
		tapped.emit()
		accept_event()

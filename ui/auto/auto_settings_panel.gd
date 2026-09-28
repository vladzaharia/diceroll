class_name AutoSettingsPanel
extends UiModal
## AUTO settings: what AUTO plays (scope chips), when it pauses and hands control back
## (HP slider + switches), its focus and how it treats the mini-boss. Edits an AutoRules
## and saves it right away (AutoConfig, user://settings.cfg [auto]); emits rules_changed.
## Two columns in landscape, one in portrait.

signal rules_changed(rules: AutoRules)

const SCOPES := [["board", "Board", "dice"], ["combat", "Combat", "sword"], ["drafts", "Drafts", "star"],
	["shop", "Shop", "coin"], ["forge", "Forge", "anvil"], ["events", "Events", "question"], ["portal", "Portal", "portal"]]
const STOPS := [["stop_before_miniboss", "Before the mini-boss", "skull"], ["stop_before_boss", "Before the final boss", "crown"],
	["stop_on_boss_passive", "A boss passive is offered", "star"], ["stop_on_shop", "At shops AUTO skips", "coin"]]
const FOCUS_LABELS := {"balanced": "Balanced", "damage": "Damage", "defense": "Defense", "economy": "Economy"}
const MINIBOSS_LABELS := {"auto": "If winnable", "always": "Always", "never": "Avoid"}
## AutoRules.skill (when core has it): how sharp AUTO plays.
const SKILLS := ["realistic", "expert"]
const SKILL_LABELS := {"realistic": "Realistic", "expert": "Expert"}
const HP_MAX := 0.6

var rules: AutoRules
var _cols: BoxContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _scope_btns: Dictionary = {}
var _stop_rows: Dictionary = {}
var _focus_btns: Dictionary = {}
var _mb_btns: Dictionary = {}
var _skill_btns: Dictionary = {}
var _skill_box: Control
var _hp_slider: HSlider
var _hp_value: Label
var _wide := true


func _build() -> void:
	set_title("AUTO", AutoButton.ACCENT.darkened(0.15))
	max_width = 1120.0
	rules = AutoConfig.load_rules()
	var intro := UiTheme.para("AUTO plays for you, one visible step at a time. Tap any game control to take over.", 22, UiPalette.TEXT_DIM, 500)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(intro)
	_cols = HBoxContainer.new()
	_cols.add_theme_constant_override("separation", 34)
	body.add_child(_cols)
	_left = UiTheme.vbox(14)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right = UiTheme.vbox(10)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cols.add_child(_left)
	_cols.add_child(_right)

	# --- scope
	_left.add_child(section_label("AUTO plays"))
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 10)
	_left.add_child(flow)
	for s in SCOPES:
		var b := GameButton.make(s[1], s[2], GameButton.Kind.SECONDARY, 24)
		b.toggle_mode = true
		b.toggle_primary = true
		b.min_height = 70
		b.pad_x = 18
		b.icon_px = 28
		b.toggled.connect(_on_scope.bind(String(s[0]), b))
		flow.add_child(b)
		_scope_btns[s[0]] = b

	# --- focus
	_left.add_child(UiTheme.spacer(2))
	_left.add_child(section_label("Focus"))
	_left.add_child(_segmented(AutoRules.FOCUSES, FOCUS_LABELS, _focus_btns, _on_focus))
	_left.add_child(section_label("Mini-boss fight"))
	_left.add_child(_segmented(AutoRules.MINIBOSS_MODES, MINIBOSS_LABELS, _mb_btns, _on_miniboss))
	# skill: only when AutoRules has it (shown by refresh())
	_skill_box = UiTheme.vbox(10)
	_skill_box.add_child(section_label("Skill"))
	_skill_box.add_child(_segmented(SKILLS, SKILL_LABELS, _skill_btns, _on_skill))
	_skill_box.visible = false
	_left.add_child(_skill_box)

	# --- stop conditions
	_right.add_child(section_label("Pause AUTO when"))
	var hp := UiTheme.vbox(2)
	_right.add_child(hp)
	var head := UiTheme.hbox(12)
	hp.add_child(head)
	head.add_child(UiIcons.rect("heart", 32))
	var hl := UiTheme.label("HP drops below", 25, UiPalette.TEXT, true, 0)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	_hp_value = UiTheme.label("Off", 25, UiPalette.GOLD_BRIGHT, true, 0)
	head.add_child(_hp_value)
	_hp_slider = HSlider.new()
	_hp_slider.min_value = 0.0
	_hp_slider.max_value = HP_MAX
	_hp_slider.step = 0.05
	_hp_slider.custom_minimum_size = Vector2(200, 52)
	_hp_slider.focus_mode = Control.FOCUS_NONE
	_hp_slider.value_changed.connect(_on_hp)
	_hp_slider.drag_ended.connect(func(_c: bool) -> void: UiTheme.sfx("click"))
	hp.add_child(_hp_slider)
	for s in STOPS:
		var row := _SwitchRow.make(String(s[1]), String(s[2]))
		row.toggled.connect(_on_stop.bind(String(s[0])))
		_right.add_child(row)
		_stop_rows[s[0]] = row

	body.add_child(UiTheme.spacer(4))
	var foot := UiTheme.hbox(14)
	body.add_child(foot)
	var reset := GameButton.make("DEFAULTS", "reroll", GameButton.Kind.SECONDARY, 26)
	reset.icon_tint = UiPalette.GOLD_BRIGHT
	reset.min_height = 88
	reset.pressed.connect(func() -> void:
		rules = AutoRules.new()
		_commit())
	foot.add_child(reset)
	var done := GameButton.make("DONE", "check", GameButton.Kind.PRIMARY, 34)
	done.icon_tint = UiPalette.TEXT_DARK
	done.min_height = 88
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(func() -> void: close())
	foot.add_child(done)
	resized.connect(_arrange)
	refresh()


func _segmented(ids: Array, labels: Dictionary, store: Dictionary, cb: Callable) -> Control:
	var row := UiTheme.hbox(8)
	for id in ids:
		var b := GameButton.make(String(labels[id]), "", GameButton.Kind.SECONDARY, 23)
		b.toggle_mode = true
		b.toggle_primary = true
		b.min_height = 66
		b.pad_x = 10
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(cb.bind(String(id)))
		row.add_child(b)
		store[id] = b
	return row


## Portrait: one column; landscape (wide panel): scope/focus left, stop conditions right.
func _arrange() -> void:
	var wide := size.x > size.y * 1.1 and size.x >= 1100.0
	if wide == _wide and _cols.get_parent() != null:
		return
	_wide = wide
	var want: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new()
	want.add_theme_constant_override("separation", 34 if wide else 16)
	var idx := _cols.get_index()
	_cols.remove_child(_left)
	_cols.remove_child(_right)
	body.remove_child(_cols)
	_cols.queue_free()
	_cols = want
	_cols.add_child(_left)
	_cols.add_child(_right)
	body.add_child(_cols)
	body.move_child(_cols, idx)
	relayout()


func refresh(_flow: GameFlow = null) -> void:
	for k in _scope_btns:
		var b: GameButton = _scope_btns[k]
		b.set_pressed_no_signal(bool(rules.get(k)))
		_tint_chip(b)
		b.call("_refresh")
	for k in _stop_rows:
		(_stop_rows[k] as _SwitchRow).set_on(bool(rules.get(k)))
	var shop_stop: _SwitchRow = _stop_rows["stop_on_shop"]
	shop_stop.set_dimmed(rules.shop)
	for k in _focus_btns:
		(_focus_btns[k] as GameButton).set_pressed_no_signal(k == rules.focus)
		(_focus_btns[k] as GameButton).call("_refresh")
	for k in _mb_btns:
		(_mb_btns[k] as GameButton).set_pressed_no_signal(k == rules.fight_miniboss)
		(_mb_btns[k] as GameButton).call("_refresh")
	var has_skill := "skill" in rules
	_skill_box.visible = has_skill
	if has_skill:
		var sk := String(rules.get("skill"))
		for k in _skill_btns:
			(_skill_btns[k] as GameButton).set_pressed_no_signal(k == sk)
			(_skill_btns[k] as GameButton).call("_refresh")
	_hp_slider.set_value_no_signal(rules.stop_hp_below)
	_hp_value.text = _hp_text(rules.stop_hp_below)
	relayout()


static func _hp_text(v: float) -> String:
	return "Off" if v <= 0.001 else "%d%%" % int(round(v * 100.0))


func _tint_chip(b: GameButton) -> void:
	b.icon_tint = UiPalette.TEXT_DARK if b.button_pressed else UiPalette.TEXT_DIM
	b.icon_name = b.icon_name


func _on_scope(on: bool, key: String, b: GameButton) -> void:
	rules.set(key, on)
	_tint_chip(b)
	_commit(false)


func _on_stop(on: bool, key: String) -> void:
	rules.set(key, on)
	_commit(false)


func _on_focus(id: String) -> void:
	rules.focus = id
	_commit()


func _on_miniboss(id: String) -> void:
	rules.fight_miniboss = id
	_commit()


func _on_skill(id: String) -> void:
	if "skill" in rules:
		rules.set("skill", id)
	_commit()


func _on_hp(v: float) -> void:
	rules.stop_hp_below = v
	_hp_value.text = _hp_text(v)
	_commit(false)


func _commit(full_refresh := true) -> void:
	AutoConfig.save_rules(rules)
	if full_refresh:
		refresh()
	else:
		(_stop_rows["stop_on_shop"] as _SwitchRow).set_dimmed(rules.shop)
	rules_changed.emit(rules)


## A full-width row: icon, label and a drawn on/off switch. Tap anywhere toggles.
class _SwitchRow:
	extends BaseButton

	var on := false
	var dimmed := false
	var _label: Label
	var _icon: TextureRect
	var _hover := false
	var _knob := 0.0
	var _tw: Tween

	static func make(text: String, icon: String) -> _SwitchRow:
		var r := _SwitchRow.new()
		r.toggle_mode = true
		r.focus_mode = Control.FOCUS_NONE
		r.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		r.custom_minimum_size = Vector2(300, 62)
		r._icon = UiIcons.rect(icon, 30)
		r._icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(r._icon)
		r._label = UiTheme.label(text, 24, UiPalette.TEXT, false, 0, false, 600)
		r._label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r._label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		r.add_child(r._label)
		r.toggled.connect(r._on_toggled)
		r.mouse_entered.connect(func() -> void:
			r._hover = true
			r.queue_redraw())
		r.mouse_exited.connect(func() -> void:
			r._hover = false
			r.queue_redraw())
		r.resized.connect(r._place)
		return r

	func set_on(v: bool) -> void:
		on = v
		set_pressed_no_signal(v)
		_knob = 1.0 if v else 0.0
		queue_redraw()

	func set_dimmed(v: bool) -> void:
		dimmed = v
		modulate.a = 0.5 if v else 1.0
		tooltip_text = "AUTO shops for you (Shop is on), so it never stops there." if v else ""

	func _on_toggled(v: bool) -> void:
		on = v
		UiTheme.sfx("click")
		if _tw and _tw.is_valid():
			_tw.kill()
		_tw = create_tween()
		_tw.tween_property(self, "_knob", 1.0 if v else 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tw.parallel().tween_method(func(_x: float) -> void: queue_redraw(), 0.0, 1.0, 0.16)

	func _place() -> void:
		_icon.position = Vector2(12, (size.y - 30) * 0.5)
		_icon.size = Vector2(30, 30)
		var lh := _label.get_minimum_size().y
		_label.position = Vector2(56, (size.y - lh) * 0.5)
		_label.size = Vector2(maxf(size.x - 56 - 96, 40), lh)

	func _draw() -> void:
		var full := Rect2(Vector2.ZERO, size)
		draw_style_box(UiTheme.box(Color(1, 1, 1, 0.07 if _hover else 0.035), 16), full)
		var tw := 70.0
		var th := 38.0
		var tr := Rect2(size.x - tw - 12.0, (size.y - th) * 0.5, tw, th)
		var off := Color(0.12, 0.13, 0.26)
		var col := off.lerp(AutoButton.ACCENT, _knob)
		draw_style_box(UiTheme.box(UiPalette.OUTLINE, int(th * 0.5) + 2), tr.grow(2))
		draw_style_box(UiTheme.box(col, int(th * 0.5)), tr)
		var kx := lerpf(tr.position.x + th * 0.5, tr.end.x - th * 0.5, _knob)
		var kc := Vector2(kx, tr.position.y + th * 0.5)
		draw_circle(kc + Vector2(0, 2), th * 0.5 - 3.0, Color(0, 0, 0, 0.3))
		draw_circle(kc, th * 0.5 - 4.0, UiPalette.TEXT if _knob > 0.5 else UiPalette.TEXT_DIM)

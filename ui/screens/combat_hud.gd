class_name CombatHud
extends Control
## Combat HUD. Top: HudTop (with hero block shield). Bottom (above the dice tray): live combo
## preview (name, ×mult, projected damage), combo cheat-sheet popover, reroll pips, Reroll
## (enabled when dice are marked and rerolls remain) and a big ATTACK button.
## Enemy HP/intent bars are world-anchored (game/), not here.

signal reroll_pressed
signal attack_pressed
signal pause_pressed

const ORDER := ["six_kind", "five_kind", "four_kind", "full_house", "straight", "small_straight", "three_kind", "two_pair", "pair", "high_roller"]
const EXAMPLES := {
	"six_kind": "6 same", "five_kind": "5 same", "four_kind": "4 same", "full_house": "3 + 2",
	"straight": "1-5 / 2-6", "small_straight": "4 in a row", "three_kind": "3 same", "two_pair": "2 + 2",
	"pair": "2 same", "high_roller": "anything",
}

var top: HudTop
var reroll_btn: GameButton
var attack_btn: GameButton
var help_btn: GameButton
var combo_name: Label
var combo_mult: Label
## Class bonus on this attack ("OATH", "AIM ×1.3"), next to the multiplier.
var class_tag: Label
var dmg_label: Label
var hint_label: Label
var pips: HBoxContainer
var sheet: PanelContainer
var _sheet_rows: Dictionary = {}
var _panel: PanelContainer
var _bottom: VBoxContainer
var _last_combo := ""
## True while the game plays events back: Reroll / Attack are disabled.
var busy := false


func _init() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top = HudTop.new()
	top.treasury.visible = false
	top.pause_pressed.connect(func() -> void: pause_pressed.emit())
	add_child(top)

	_bottom = UiTheme.vbox(14)
	add_child(_bottom)

	# combo preview
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.panel_box("hud"), 22, 12))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(_panel)
	var row := UiTheme.hbox(14)
	_panel.add_child(row)
	var names := UiTheme.vbox(-4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(names)
	var cap := UiTheme.label("COMBO", 18, UiPalette.TEXT_MUTED, false, 0, false, 700)
	names.add_child(cap)
	var nr := UiTheme.hbox(12)
	names.add_child(nr)
	combo_name = UiTheme.label("Pair", 38, UiPalette.GOLD_BRIGHT, true, 7)
	nr.add_child(combo_name)
	combo_mult = UiTheme.label("×1.5", 32, UiPalette.TEXT, true, 6)
	nr.add_child(combo_mult)
	class_tag = UiTheme.label("", 22, UiPalette.GOLD_BRIGHT, true, 5)
	class_tag.visible = false
	class_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nr.add_child(class_tag)
	var dmg := PanelContainer.new()
	dmg.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.35, 0.06, 0.1, 0.8), 18, 2, Color(1, 0.45, 0.4, 0.4)), 14, 6))
	dmg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dmg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dmg)
	var dr := UiTheme.hbox(6)
	dmg.add_child(dr)
	dr.add_child(UiIcons.rect("sword", 34))
	dmg_label = UiTheme.label("18", 36, UiPalette.TEXT, true, 6)
	dr.add_child(dmg_label)
	help_btn = GameButton.round_icon("question", 72)
	help_btn.icon_px = 40
	help_btn.kind = GameButton.Kind.GHOST
	help_btn.icon_tint = UiPalette.GOLD
	help_btn.toggle_mode = true
	help_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	help_btn.toggled.connect(func(on: bool) -> void: show_sheet(on))
	row.add_child(help_btn)

	# hint + pips
	var hr := UiTheme.hbox(12)
	hr.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom.add_child(hr)
	pips = UiTheme.hbox(4)
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	hr.add_child(pips)
	hint_label = UiTheme.label("Tap dice to mark them for a reroll", 24, UiPalette.TEXT, false, 5, false, 600)
	hr.add_child(hint_label)

	# buttons
	var br := UiTheme.hbox(16)
	_bottom.add_child(br)
	reroll_btn = GameButton.make("REROLL", "reroll", GameButton.Kind.SECONDARY, 32)
	reroll_btn.icon_tint = UiPalette.GOLD_BRIGHT
	reroll_btn.min_height = 112
	reroll_btn.pad_x = 22
	reroll_btn.pressed.connect(func() -> void: reroll_pressed.emit())
	br.add_child(reroll_btn)
	attack_btn = GameButton.make("ATTACK", "sword", GameButton.Kind.PRIMARY, 50)
	attack_btn.icon_tint = UiPalette.TEXT
	attack_btn.min_height = 112
	attack_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attack_btn.sfx_id = "swing"
	attack_btn.pressed.connect(func() -> void: attack_pressed.emit())
	br.add_child(attack_btn)

	_build_sheet()
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func _build_sheet() -> void:
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.panel_box("main"), 24, 18))
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.visible = false
	add_child(sheet)
	var col := UiTheme.vbox(4)
	sheet.add_child(col)
	var head := UiTheme.label("COMBOS", 28, UiPalette.GOLD, true, 5)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	col.add_child(UiTheme.spacer(4))
	for id in ORDER:
		var r := PanelContainer.new()
		r.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(1, 1, 1, 0.0), 12), 12, 4))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(r)
		var h := UiTheme.hbox(10)
		r.add_child(h)
		var n := UiTheme.label(String(Combo.TABLE[id].name), 26, UiPalette.TEXT, true, 0)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var ex := UiTheme.label(String(EXAMPLES[id]), 20, UiPalette.TEXT_MUTED, false, 0, false, 500)
		h.add_child(ex)
		var m := UiTheme.label("×" + _fmt(float(Combo.TABLE[id].mult)), 26, UiPalette.GOLD_BRIGHT, true, 0)
		m.custom_minimum_size.x = 76
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(m)
		_sheet_rows[id] = r
	var foot := UiTheme.label("Damage = all pips × multiplier + ATK", 20, UiPalette.TEXT_DIM, false, 0, false, 500)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(UiTheme.spacer(6))
	col.add_child(foot)


func show_sheet(on: bool) -> void:
	if help_btn.button_pressed != on:
		help_btn.set_pressed_no_signal(on)
	if on:
		sheet.visible = true
		_layout()
		sheet.pivot_offset = Vector2(sheet.size.x * 0.5, sheet.size.y)
		sheet.scale = Vector2(0.9, 0.9)
		sheet.modulate.a = 0.0
		var t := create_tween().set_parallel(true)
		t.tween_property(sheet, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(sheet, "modulate:a", 1.0, 0.12)
		UiTheme.sfx("page")
	else:
		sheet.visible = false


func _layout() -> void:
	if size.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	var w := minf(UiTheme.MODAL_MAX_W, size.x - safe.left - safe.right)
	_bottom.reset_size()
	var h := _bottom.get_combined_minimum_size().y
	var slot := UiTheme.side_slot(size, safe)
	if slot.size.x > 0.0:
		w = slot.size.x
		_bottom.size = Vector2(w, h)
		_bottom.position = Vector2(slot.position.x, slot.end.y - h)
	else:
		_bottom.size = Vector2(w, h)
		_bottom.position = Vector2((size.x - w) * 0.5, UiTheme.tray_rect(size, safe).position.y - 20.0 - h)
	if sheet.visible:
		var sw := minf(560.0, w)
		sheet.reset_size()
		sheet.size.x = sw
		var sh := sheet.get_combined_minimum_size().y
		sheet.position = Vector2((size.x - sw) * 0.5, _bottom.position.y - sh - 14.0)


func refresh(flow: GameFlow) -> void:
	top.refresh(flow)
	var c := flow.combat
	visible = c != null
	if c == null:
		return
	var p := project(flow)
	var cname := String(p.name)
	combo_name.text = cname
	combo_mult.text = "×" + _fmt(float(p.mult))
	var cls := String(p.get("class", ""))
	class_tag.visible = cls != ""
	class_tag.text = cls
	class_tag.label_settings = UiTheme.label_settings(22, ClassInfo.mechanic_color(HeroDefs.mechanic(flow.run.class_id)).lightened(0.2), true, 5)
	dmg_label.text = str(int(p.total))
	if cname != _last_combo and _last_combo != "" and is_inside_tree():
		UiTheme.pop(combo_name, 1.15, 0.25)
	_last_combo = cname
	for id in _sheet_rows:
		var on: bool = id == String(p.id)
		var r: PanelContainer = _sheet_rows[id]
		r.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(UiPalette.GOLD, 0.22) if on else Color(0, 0, 0, 0), 12, 2 if on else 0, UiPalette.GOLD_LINE), 12, 4))
	var marked := 0
	for m in c.marked:
		if m:
			marked += 1
	var total := maxi(flow.run.combat_rerolls, c.rerolls_left)
	UiTheme.clear(pips)
	for i in total:
		var on := i < c.rerolls_left
		var ic := UiIcons.rect("reroll", 30, UiPalette.GOLD_BRIGHT if on else Color(0.45, 0.43, 0.55))
		ic.modulate.a = 1.0 if on else 0.55
		pips.add_child(ic)
	reroll_btn.sub_text = "%d left" % c.rerolls_left
	reroll_btn.set_enabled(not busy and marked > 0 and c.rerolls_left > 0)
	attack_btn.set_enabled(not busy)
	if c.rerolls_left <= 0:
		hint_label.text = "No rerolls left. Attack!"
	elif marked == 0:
		hint_label.text = "Tap dice to mark them for a reroll"
	else:
		hint_label.text = "%d %s marked for reroll" % [marked, "die" if marked == 1 else "dice"]
	_layout()


## Damage preview that mirrors CombatState.attack without side effects.
static func project(flow: GameFlow) -> Dictionary:
	var c := flow.combat
	var run := flow.run
	var combo := c.current_combo(run)
	var eff: Array = combo.values
	var group: Array = combo.group
	var mult := float(combo.mult)
	var sum := 0
	var bonus := 0
	var pool := c.pool_dice(run)
	for i in pool.size():
		var pips_v := int(eff[i]) if i < eff.size() else 0
		var rune := pool[i].rune
		sum += pips_v * (2 if rune == "heavy" else 1)
		if rune == "blade" and group.has(i):
			bonus += pips_v
		if rune == "echo" and group.has(i):
			mult += 0.5
	# class bonuses (mirrors CombatState.attack): the Paladin's Oath set, the Ranger's Aim
	var cls := ""
	var ob := ClassLogic.oath_bonus(c.oath, String(combo.id), group, eff) if c.oath > 0 else [0.0, 0]
	if float(ob[0]) > 0.0:
		mult += float(ob[0])
		sum += int(ob[1])
		cls = "OATH"
	var factor := 1.0
	if HeroDefs.mechanic(run.class_id) == "aim" and c.rerolls_used_this_turn == 0:
		factor = ClassLogic.aim_mult(c.dice_values.size())
		cls = "AIM ×%s" % ClassInfo._num(factor)
	var total := int(floor((sum + bonus) * mult * factor)) + run.atk
	return {"id": combo.id, "name": combo.name, "mult": mult, "total": total, "group": group, "class": cls}


## Top edge (canvas y) of the bottom panel; 3D framing should stay above it.
func content_top(view: Vector2) -> float:
	return UiTheme.bottom_bar_top(view, _bottom.get_combined_minimum_size().y, UiTheme.safe_margins(self))


## Disables Reroll / Attack while events play; the next refresh() restores them.
func set_busy(on: bool) -> void:
	busy = on
	if on:
		reroll_btn.set_enabled(false)
		attack_btn.set_enabled(false)


func on_event(ev: Dictionary, flow: GameFlow) -> void:
	top.on_event(ev, flow)
	match String(ev.get("type", "")):
		"dice_rolled", "die_marked", "combat_turn_started":
			refresh(flow)


static func _fmt(m: float) -> String:
	return str(int(m)) if is_equal_approx(m, round(m)) else ("%.1f" % m)

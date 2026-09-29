class_name MetaHud
extends Control
## In-run meta HUD strip: the pet's charge meter (portrait medallion + pip ring) and the
## potion belt (2-3 slots). Portrait: right-aligned under the HUD chips row (gold / lap);
## landscape: the free band left of the dice tray (the same place on the board and in combat).
##
##   hud.tops = [board_hud.top, combat_hud.top]     # it follows whichever is visible
##   hud.command.connect(...)                        # "use_potion", [slot]
##   hud.refresh(flow)                               # after every sync
##
## Tap a potion to drink it (disabled when it can't be drunk now: combat-only types outside a
## fight, one per combat turn, Healing Draught at full HP). Long-press or hover shows its
## tooltip, as does the pet medallion. Event animations (MetaBeats) use fly_in / fly_out /
## set_belt / set_charge / fire / level_toast / chip.

signal command(name: String, args: Array)

const SLOT_PX := 54
const SLOT_PX_LAND := 76
const METER_PX := 60
const METER_PX_LAND := 84
const LONG_PRESS := 0.42
const CHARGE_TEXT := {
	"pair_plus": "Charges on every attack with a Pair or better.",
	"low_die": "Charges on every die showing 2 or less when you attack.",
	"six": "Charges on every 6 you attack with.",
	"kept": "Charges on every die you keep (never rerolled) when you attack.",
	"attack_intent": "Charges on every enemy attack intent.",
	"board_double": "Charges on every board move made with doubles.",
}

## The HudTops it can anchor to (the visible one wins).
var tops: Array = []
var strip: PanelContainer
var meter: _Meter
var slots: Array[_Slot] = []
var belt: Array = []
var cap := 0
var pet_id := ""
var pet_level := 0

var _row: BoxContainer
var _mode := "top"
var _tip: PanelContainer
var _tip_tween: Tween
var _flow: GameFlow
var _reasons: Array = []
var _landscape := false
var _flying := 0


func _init() -> void:
	name = "MetaHud"
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.05, 0.05, 0.13, 0.72), 22, 2, UiPalette.GOLD_FAINT, 8, Color(0, 0, 0, 0.3), Vector2(0, 3)), 8, 6))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	_row = UiTheme.hbox(6)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_child(_row)
	meter = _Meter.new()
	meter.hud = self
	_row.add_child(meter)
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 6
	add_child(_tip)
	visible = false


func _process(_dt: float) -> void:
	_place()


# ======================================================================= state

## Full sync from the flow (belt, cap, pet, charge, legality).
func refresh(flow: GameFlow) -> void:
	_flow = flow
	var run := flow.run
	pet_id = run.pet_id()
	pet_level = run.pet_level()
	meter.visible = pet_id != ""
	if pet_id != "":
		meter.setup(pet_id, pet_level)
		meter.set_charge(int(run.pet_state.get("charge", 0)), PetDefs.size(pet_id), false)
	if _flying == 0:
		set_belt(Array(run.belt), run.potion_cap)
	else:
		cap = run.potion_cap
	_update_legal()
	_place()


## Shows `b` (potion type ids) in `c` slots.
func set_belt(b: Array, c := -1) -> void:
	belt = b.duplicate()
	if c >= 0:
		cap = c
	while slots.size() < cap:
		var s := _Slot.new()
		s.hud = self
		s.index = slots.size()
		_row.add_child(s)
		slots.append(s)
	while slots.size() > cap:
		slots.pop_back().queue_free()
	var px := SLOT_PX_LAND if _landscape else SLOT_PX
	for i in slots.size():
		slots[i].custom_minimum_size = Vector2(px, px)
		slots[i].set_type(String(belt[i]) if i < belt.size() else "")
	_update_legal()


func set_charge(c: int, n: int, animate := true) -> void:
	meter.set_charge(c, n, animate)


## The pet fired: the medallion flashes and its ring empties.
func fire() -> void:
	meter.fire()


func _update_legal() -> void:
	_reasons.clear()
	for i in slots.size():
		var why := _why_not(String(belt[i]) if i < belt.size() else "")
		_reasons.append(why)
		slots[i].set_enabled(why == "" and i < belt.size())


## "" when potion `type` can be drunk now, else the reason.
func _why_not(type: String) -> String:
	if type == "" or _flow == null:
		return "Empty slot"
	if _flow.is_over():
		return "The run is over"
	var in_combat := _flow.phase == GameFlow.Phase.COMBAT
	if PotionDefs.combat_only(type) and not in_combat:
		return "Only in combat"
	if in_combat and _flow.combat and _flow.combat.potion_turn == _flow.combat.turn:
		return "One potion per turn"
	if type == "healing" and _flow.run.hp >= _flow.run.max_hp:
		return "HP is full"
	return ""


func _tap(i: int) -> void:
	if i >= belt.size():
		show_slot_tip(i)
		return
	var why := String(_reasons[i]) if i < _reasons.size() else ""
	if why != "":
		UiTheme.sfx("error")
		show_slot_tip(i)
		UiTheme.pop(slots[i], 0.9, 0.2)
		return
	hide_tip()
	command.emit("use_potion", [i])


# ======================================================================= layout

func _visible_top() -> HudTop:
	for t in tops:
		var ht := t as HudTop
		if ht and ht.is_visible_in_tree():
			return ht
	return null


func _place() -> void:
	var top := _visible_top()
	var want := top != null and _flow != null and not _flow.is_over() and (cap > 0 or pet_id != "")
	if visible != want:
		visible = want
	if not want or size.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	var mode := _pick_mode(safe)
	if mode != _mode:
		_mode = mode
		_landscape = mode != "top"
		_set_vertical(mode == "side_v")
		set_belt(belt)
		meter.custom_minimum_size = Vector2.ONE * (METER_PX_LAND if _landscape else METER_PX)
	strip.reset_size()
	var s := strip.get_combined_minimum_size()
	strip.size = s
	var band := (size.x - UiTheme.tray_width(size)) * 0.5
	if _mode == "side_h":
		# landscape: centred in the band left of the tray, level with the tray
		var th := UiTheme.tray_height(size)
		var x0 := safe.left
		strip.position = Vector2(x0 + (band - x0 - s.x) * 0.5, size.y - th * 0.5 - s.y * 0.5)
	elif _mode == "side_v":
		# narrower landscape (4:3 tablets): a column in the band left of the tray, bottom-aligned
		var x0 := safe.left
		strip.position = Vector2(x0 + (band - x0 - s.x) * 0.5, size.y - safe.bottom - 24.0 - s.y)
	if _mode != "top":
		for t in tops:
			(t as HudTop).reserve_right = 0.0
			(t as HudTop).extra_bottom = 0.0
	else:
		var r := top.chips_rect()
		var at := Vector2(r.end.x - s.x, r.end.y + 8.0) - global_position
		strip.position = at
		for t in tops:
			(t as HudTop).reserve_right = s.x + 16.0
			(t as HudTop).extra_bottom = strip.get_global_rect().end.y - (t as HudTop).global_position.y


## "side_h" (a row left of the tray, wide landscape), "side_v" (a column there, 4:3 landscape)
## or "top" (under the HUD chips row: portrait, and landscape too narrow for the band).
func _pick_mode(safe: UiTheme.Margins) -> String:
	if size.x <= size.y:
		return "top"
	var band := (size.x - UiTheme.tray_width(size)) * 0.5 - safe.left
	var n := cap + (1 if pet_id != "" else 0)
	var len := n * (SLOT_PX_LAND + 8) + 30
	if band >= len + 32.0:
		return "side_h"
	if band >= METER_PX_LAND + 40.0 and size.y - 260.0 >= len:
		return "side_v"
	return "top"


func _set_vertical(on: bool) -> void:
	if (_row is VBoxContainer) == on:
		return
	var nr: BoxContainer = UiTheme.vbox(8) if on else UiTheme.hbox(6)
	nr.alignment = BoxContainer.ALIGNMENT_CENTER
	var kids := _row.get_children()
	for k in kids:
		_row.remove_child(k)
		nr.add_child(k)
	strip.remove_child(_row)
	_row.queue_free()
	_row = nr
	strip.add_child(_row)


## Screen centre of belt slot i (global canvas coordinates).
func slot_center(i: int) -> Vector2:
	if i < 0 or i >= slots.size():
		return strip.get_global_rect().get_center()
	return slots[i].get_global_rect().get_center()


func meter_center() -> Vector2:
	return meter.get_global_rect().get_center()


# ======================================================================= animations

## A potion bottle flies from `from` (canvas point) into the slot it lands in; then the belt
## shows `new_belt`. Await it.
func fly_in(type: String, from: Vector2, new_belt: Array, new_cap := -1) -> void:
	if not visible:
		set_belt(new_belt, new_cap)
		return
	_flying += 1
	var slot := clampi(new_belt.size() - 1, 0, maxi(slots.size() - 1, 0))
	var to := slot_center(slot)
	var b := _bottle(type, 58)
	b.position = from - b.size * 0.5
	var start := b.position
	var end := to - b.size * 0.5
	var ctrl := (start + end) * 0.5 + Vector2(0, -160)
	b.scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.tween_property(b, "scale", Vector2(1.3, 1.3), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_method(func(u: float) -> void:
		var a := start.lerp(ctrl, u)
		var c := ctrl.lerp(end, u)
		b.position = a.lerp(c, u)
		b.rotation = sin(u * PI) * 0.6
		b.scale = Vector2.ONE * lerpf(1.3, 0.9, u), 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	b.queue_free()
	_flying -= 1
	set_belt(new_belt, new_cap)
	if slot < slots.size():
		slots[slot].burst()
	UiTheme.sfx("buff")


## The bottle in `slot` pops out and flies to `to` (the hero); the belt then shows `new_belt`.
func fly_out(slot: int, type: String, to: Vector2, new_belt: Array) -> void:
	var from := slot_center(slot)
	if slot >= 0 and slot < slots.size():
		slots[slot].set_type("")
		slots[slot].burst(Color(1, 1, 1, 0.9))
	var b := _bottle(type, 56)
	b.position = from - b.size * 0.5
	var start := b.position
	var end := to - b.size * 0.5
	var ctrl := (start + end) * 0.5 + Vector2(0, -120)
	var t := create_tween()
	t.tween_property(b, "scale", Vector2(1.35, 1.35), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_method(func(u: float) -> void:
		var a := start.lerp(ctrl, u)
		var c := ctrl.lerp(end, u)
		b.position = a.lerp(c, u)
		b.rotation = -u * 2.2, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(b, "scale", Vector2(0.6, 0.6), 0.42)
	t.tween_property(b, "modulate:a", 0.0, 0.1)
	await t.finished
	b.queue_free()
	set_belt(new_belt)


func _bottle(type: String, px: int) -> TextureRect:
	var b := TextureRect.new()
	b.texture = UiIcons.tex("potion_" + type if UiIcons.exists("potion_" + type) else "potion", px, Color.WHITE)
	b.size = Vector2(px, px)
	b.pivot_offset = b.size * 0.5
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.z_index = 8
	add_child(b)
	return b


## Automatic level-up: a "LEVEL N  +X MAX HP" badge pops beside the level medallion.
func level_toast(level: int, hp_gained: int, healed := 0) -> void:
	var top := _visible_top()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.12, 0.07, 0.24, 0.95), 22, 3, UiPalette.XP, 12, Color(0.6, 0.35, 1.0, 0.45), Vector2.ZERO), 16, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 7
	var col := UiTheme.vbox(-2)
	p.add_child(col)
	col.add_child(UiTheme.label("LEVEL %d!" % level, 30, UiPalette.XP.lightened(0.45), true, 7))
	var r := UiTheme.hbox(6)
	col.add_child(r)
	r.add_child(UiIcons.rect("heart", 30))
	r.add_child(UiTheme.label("+%d MAX HP" % hp_gained, 26, UiPalette.HP_BRIGHT.lightened(0.2), true, 6))
	if healed > 0:
		r.add_child(UiTheme.label("·  +%d" % healed, 22, UiPalette.HEAL, true, 5))
	add_child(p)
	p.reset_size()
	var s := p.get_combined_minimum_size()
	p.size = s
	var at := Vector2(24, 140)
	if top:
		var br := top.level_badge.get_global_rect()
		at = Vector2(br.position.x + br.size.x * 0.15, br.end.y + 12.0) - global_position
		UiTheme.pop(top.level_badge, 1.35, 0.5)
		_ring(top.level_badge.get_global_rect().get_center() - global_position, UiPalette.XP)
	at.x = clampf(at.x, 8.0, size.x - s.x - 8.0)
	p.position = at + Vector2(0, 16)
	p.pivot_offset = Vector2(0, 0)
	p.scale = Vector2(0.4, 0.4)
	p.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(p, "modulate:a", 1.0, 0.15)
	t.tween_property(p, "position:y", at.y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(2.2)
	t.chain().set_parallel(true)
	t.tween_property(p, "modulate:a", 0.0, 0.35)
	t.tween_property(p, "position:y", at.y - 24.0, 0.35)
	t.chain().tween_callback(p.queue_free)


## An expanding ring at a canvas point (level badge pulse, meter fire).
func _ring(at: Vector2, color: Color, r0 := 30.0, r1 := 90.0) -> void:
	var ring := _RingFx.new()
	ring.color = color
	ring.position = at
	ring.r0 = r0
	ring.r1 = r1
	ring.z_index = 7
	add_child(ring)


## A small chip (icon + text) popping at a canvas point: trait triggers, Crowns.
func chip(at: Vector2, text: String, icon := "", color: Color = UiPalette.GOLD_BRIGHT, hold := 0.9) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.06, 0.05, 0.14, 0.92), 18, 2, color, 8, Color(color, 0.35), Vector2.ZERO), 10, 4))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 7
	var r := UiTheme.hbox(6)
	p.add_child(r)
	if icon != "" and UiIcons.exists(icon):
		r.add_child(UiIcons.rect(icon, 28))
	r.add_child(UiTheme.label(text, 22, color.lightened(0.25), true, 5))
	add_child(p)
	p.reset_size()
	var s := p.get_combined_minimum_size()
	p.size = s
	var pos := at - global_position - Vector2(s.x * 0.5, s.y)
	pos.x = clampf(pos.x, 8.0, size.x - s.x - 8.0)
	p.position = pos
	p.pivot_offset = s * 0.5
	p.scale = Vector2(0.3, 0.3)
	var t := create_tween()
	t.tween_property(p, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(p, "scale", Vector2.ONE, 0.1)
	t.tween_property(p, "modulate", Color(1.6, 1.6, 1.6), 0.08)
	t.tween_property(p, "modulate", Color.WHITE, 0.16)
	t.tween_interval(hold)
	t.tween_property(p, "position:y", pos.y - 30.0, 0.35)
	t.parallel().tween_property(p, "modulate:a", 0.0, 0.35)
	t.tween_callback(p.queue_free)


# ======================================================================= tooltips

func show_slot_tip(i: int) -> void:
	if i < 0 or i >= slots.size():
		return
	var type := String(belt[i]) if i < belt.size() else ""
	if type == "":
		_show_tip(slots[i], "Empty slot", "Potions come from shops, chests, minigames and pets.", UiPalette.TEXT_DIM, "")
		return
	var why := String(_reasons[i]) if i < _reasons.size() else ""
	var status := "Tap to drink" if why == "" else why
	var d: Dictionary = PotionDefs.DEFS[type]
	var extra := "  ·  combat only" if PotionDefs.combat_only(type) else ""
	_show_tip(slots[i], String(d.name), String(d.desc) + extra, POTION_COLORS.get(type, UiPalette.HP_BRIGHT), status)


func show_meter_tip() -> void:
	if pet_id == "":
		return
	var cd := PetDefs.card(pet_id, pet_level)
	var body := "%s\n%s" % [String(cd.fires), String(CHARGE_TEXT.get(String(cd.charge_on), ""))]
	var ch := "%d / %d charge" % [meter.charge, meter.size_pips]
	_show_tip(meter, "%s  L%d" % [String(cd.name), pet_level], body, PetView.LOOKS.get(pet_id, [UiPalette.GOLD])[0], ch)


const POTION_COLORS := {
	"healing": Color("ff7a86"), "stoneskin": Color("b8c6dc"), "reroll_tonic": Color("ffc24a"), "cleanse": Color("7fe0ff"),
}


func _show_tip(anchor: Control, title: String, body: String, color: Color, status: String) -> void:
	UiTheme.clear(_tip)
	_tip.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.05, 0.05, 0.12, 0.97), 16, 2, color, 10, Color(0, 0, 0, 0.4)), 16, 10))
	var col := UiTheme.vbox(2)
	_tip.add_child(col)
	col.add_child(UiTheme.label(title, 26, color.lightened(0.2), true, 5))
	var desc := UiTheme.para(body, 21, UiPalette.TEXT_DIM, 500)
	desc.custom_minimum_size.x = minf(360.0, size.x - 60.0)
	col.add_child(desc)
	if status != "":
		col.add_child(UiTheme.label(status, 20, UiPalette.GOLD_BRIGHT if status == "Tap to drink" else UiPalette.TEXT_MUTED, false, 0, false, 700))
	_tip.visible = true
	_tip.reset_size()
	var s := _tip.get_combined_minimum_size()
	_tip.size = s
	var r := anchor.get_global_rect()
	var at := Vector2(r.get_center().x - s.x * 0.5, r.end.y + 10.0) - global_position
	if at.y + s.y > size.y - 20.0:
		at.y = r.position.y - s.y - 10.0 - global_position.y
	at.x = clampf(at.x, 12.0, size.x - s.x - 12.0)
	_tip.position = at
	_tip.modulate.a = 1.0
	if _tip_tween and _tip_tween.is_valid():
		_tip_tween.kill()
	_tip_tween = create_tween()
	_tip_tween.tween_interval(2.8)
	_tip_tween.tween_property(_tip, "modulate:a", 0.0, 0.25)
	_tip_tween.tween_callback(func() -> void: _tip.visible = false)


func hide_tip() -> void:
	if _tip_tween and _tip_tween.is_valid():
		_tip_tween.kill()
	_tip.visible = false


# ======================================================================= widgets

## One belt slot: tap drinks, long-press / hover shows the tooltip.
class _Slot:
	extends Control
	var hud: MetaHud
	var index := 0
	var type := ""
	var enabled := true
	var _icon: TextureRect
	var _down := -1.0
	var _long := false
	var _glow := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_icon = TextureRect.new()
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_icon)
		resized.connect(_fit)
		mouse_entered.connect(func() -> void: hud.show_slot_tip(index))
		mouse_exited.connect(func() -> void: hud.hide_tip())

	func _fit() -> void:
		var m := size.x * 0.04
		_icon.position = Vector2(m, m * 0.5)
		_icon.size = size - Vector2(m * 2.0, m * 2.0)
		pivot_offset = size * 0.5

	func set_type(t: String) -> void:
		type = t
		var px := int(maxf(size.x, 48.0) * 1.6)
		_icon.texture = UiIcons.tex("potion_" + t if t != "" and UiIcons.exists("potion_" + t) else "potion_empty", px, Color.WHITE)
		queue_redraw()

	func set_enabled(on: bool) -> void:
		enabled = on
		_icon.modulate = Color.WHITE if on or type == "" else Color(0.72, 0.72, 0.78, 0.8)
		queue_redraw()

	func burst(col := Color(1.0, 0.9, 0.5)) -> void:
		UiTheme.pop(self, 1.3, 0.35)
		hud._ring(get_global_rect().get_center() - hud.global_position, col, size.x * 0.3, size.x * 0.9)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var c := UiPalette.NAVY_2 if type != "" else Color(0.03, 0.03, 0.09, 0.5)
		var sb := UiTheme.box(c, 16, 2, UiPalette.GOLD_LINE if (enabled and type != "") else Color(1, 1, 1, 0.12))
		draw_style_box(sb, r)

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		var st := e as InputEventScreenTouch
		var pressed := false
		var released := false
		if mb and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed = mb.pressed
			released = not mb.pressed
		elif st:
			pressed = st.pressed
			released = not st.pressed
		else:
			return
		accept_event()
		if pressed:
			_down = Time.get_ticks_msec() / 1000.0
			_long = false
			_hold()
		elif released and _down >= 0.0:
			var held := Time.get_ticks_msec() / 1000.0 - _down
			_down = -1.0
			if not _long and held < LONG_PRESS:
				hud._tap(index)

	func _hold() -> void:
		var at := _down
		await get_tree().create_timer(LONG_PRESS).timeout
		if is_equal_approx(_down, at) and _down >= 0.0:
			_long = true
			hud.show_slot_tip(index)


## Pet medallion: portrait, charge pips around it, level tag; flashes when the pet fires.
class _Meter:
	extends Control
	var hud: MetaHud
	var pet := ""
	var level := 1
	var charge := 0
	var size_pips := 0
	var accent := Color.WHITE
	var _tex: Texture2D
	var _flash := 0.0
	var _t := 0.0
	var _pop: Array[float] = []

	func _init() -> void:
		custom_minimum_size = Vector2(METER_PX, METER_PX)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void: hud.show_meter_tip())
		mouse_exited.connect(func() -> void: hud.hide_tip())

	func setup(id: String, lvl: int) -> void:
		if id == pet and lvl == level:
			return
		pet = id
		level = lvl
		accent = PetView.LOOKS.get(id, [UiPalette.GOLD])[0]
		_tex = UiIcons.tex("pet_" + id, 96, Color.WHITE) if UiIcons.exists("pet_" + id) else null
		queue_redraw()

	func set_charge(c: int, n: int, animate: bool) -> void:
		var was := charge
		size_pips = n
		charge = clampi(c, 0, n)
		_pop.resize(n)
		if animate:
			for i in range(was, charge):
				_pop[i] = 1.0
			if charge >= n and was < n:
				UiTheme.pop(self, 1.2, 0.35)
		queue_redraw()

	func fire() -> void:
		_flash = 1.0
		UiTheme.pop(self, 1.3, 0.4)
		hud._ring(get_global_rect().get_center() - hud.global_position, accent, size.x * 0.4, size.x * 1.2)
		set_charge(0, size_pips, false)

	func _process(dt: float) -> void:
		_t += dt
		var busy := _flash > 0.0 or charge >= size_pips
		_flash = maxf(0.0, _flash - dt * 2.0)
		for i in _pop.size():
			if _pop[i] > 0.0:
				_pop[i] = maxf(0.0, _pop[i] - dt * 2.5)
				busy = true
		if busy:
			queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		var st := e as InputEventScreenTouch
		if (mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) or (st and st.pressed):
			accept_event()
			hud.show_meter_tip()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var full := size_pips > 0 and charge >= size_pips
		if full:
			var k := 0.5 + 0.5 * sin(_t * 6.0)
			draw_circle(c, r + 3.0, Color(accent, 0.25 + 0.25 * k))
		draw_circle(c + Vector2(0, 3), r - 2.0, Color(0, 0, 0, 0.35))
		draw_circle(c, r - 2.0, UiPalette.OUTLINE)
		draw_circle(c, r - 4.0, Color(0.07, 0.07, 0.16, 0.95))
		# pip ring: one arc segment per pip
		var ring_r := r - 8.0
		var n := maxi(size_pips, 1)
		var gap := 0.22 if n > 1 else 0.0
		for i in size_pips:
			var a0 := -PI * 0.5 + TAU * float(i) / n + gap * 0.5
			var a1 := -PI * 0.5 + TAU * float(i + 1) / n - gap * 0.5
			var on := i < charge
			var col := accent.lightened(0.15) if on else Color(1, 1, 1, 0.14)
			var w := 7.0 + (4.0 * _pop[i] if i < _pop.size() else 0.0)
			draw_arc(c, ring_r, a0, a1, 12, col, w, true)
		if _tex:
			var ir := r - 15.0
			draw_texture_rect(_tex, Rect2(c - Vector2(ir, ir), Vector2(ir, ir) * 2.0), false)
		if _flash > 0.0:
			draw_circle(c, r - 4.0, Color(accent.lightened(0.5), _flash * 0.6))
		# level tag
		var f := UiTheme.display_font()
		var txt := "L%d" % level
		var fs := int(r * 0.42)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tag := Rect2(Vector2(c.x - tw * 0.5 - 6.0, size.y - fs - 2.0), Vector2(tw + 12.0, fs + 4.0))
		draw_style_box(UiTheme.box(UiPalette.GOLD_DEEP if level >= PetDefs.MAX_LEVEL else UiPalette.NAVY_3, 8, 2, UiPalette.OUTLINE), tag)
		draw_string_outline(f, Vector2(tag.position.x + 6.0, tag.end.y - 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, UiPalette.OUTLINE)
		draw_string(f, Vector2(tag.position.x + 6.0, tag.end.y - 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiPalette.TEXT)


## Expanding, fading ring (canvas).
class _RingFx:
	extends Node2D
	var color := Color.WHITE
	var r0 := 30.0
	var r1 := 90.0
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt / 0.45
		if _t >= 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var e := 1.0 - pow(1.0 - _t, 3.0)
		draw_arc(Vector2.ZERO, lerpf(r0, r1, e), 0, TAU, 40, Color(color, 1.0 - _t), 6.0 * (1.0 - _t) + 1.0, true)

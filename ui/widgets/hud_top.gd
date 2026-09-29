class_name HudTop
extends Control
## Shared top HUD: level/XP medallion, HP bar (+ hero block shield), gold, treasury,
## lap chip ("LAP 6/15" + this biome's lap pips, tinted per biome) and the pause button,
## with the passives bar (tap / hover an icon for its name and effect) underneath.
## Anchored to the top edge inside the safe area; centred and width-capped in landscape.
##
## Counters only move on refresh() (a full sync once playback ends) and on the events
## that carry the change, so rewards never jump ahead of their animations.

signal pause_pressed

const MAX_W := 980.0
const ROMAN := ["I", "II", "III", "IV"]
## Biome accent per act (lap pips, chip rim).
const BIOME_COLORS := [Color("ffb36a"), Color("ff8a3a"), Color("b58aff")]
const PASSIVE_PX := 44

var level_badge: LevelBadge
var hp_bar: StatBar
var gold: Counter
var treasury: Counter
var pause_btn: GameButton
var act_label: Label
var lap_pips: HBoxContainer
var block_badge: Control
var passives: HFlowContainer
var _passive_ids: Array = []
var _tip: PanelContainer
var _tip_tween: Tween
var _act_chip: PanelContainer
var _act := 1
var _lap := 1
## The run's biome ids per tier (lap chip colour and tooltip); empty = legacy act colours.
var route: Array = []
var _block_label: Label
var _row: HBoxContainer
var _scrim: TextureRect
var _hp_wrap: Control
var _block := 0
## Burn stacks on the hero (Magma): a flame badge with the count, left of the block shield.
var burn_badge: Control
var _burn_label: Label
var _burn := 0
## Width kept free at the right end of the passives bar (the meta HUD strip sits there).
var reserve_right := 0.0:
	set(v):
		if not is_equal_approx(v, reserve_right):
			reserve_right = v
			_layout()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.full_rect(self)
	_scrim = TextureRect.new()
	_scrim.texture = UiTheme.vgradient(Color(0.02, 0.02, 0.07, 0.6), Color(0.02, 0.02, 0.07, 0.0))
	_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_row = UiTheme.hbox(14)
	add_child(_row)
	level_badge = LevelBadge.make(100)
	_row.add_child(level_badge)

	var mid := UiTheme.vbox(10)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(mid)
	# HP row: heart overlapping the bar's left end, block shield on the right end
	_hp_wrap = Control.new()
	_hp_wrap.custom_minimum_size = Vector2(200, 50)
	_hp_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_hp_wrap)
	hp_bar = StatBar.make(UiPalette.HP, 44)
	hp_bar.text_size = 28
	_hp_wrap.add_child(hp_bar)
	var heart := UiIcons.rect("heart", 58)
	heart.name = "Heart"
	_hp_wrap.add_child(heart)
	block_badge = Control.new()
	block_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block_badge.custom_minimum_size = Vector2(62, 62)
	block_badge.visible = false
	_hp_wrap.add_child(block_badge)
	var sh := UiIcons.rect("shield", 62)
	block_badge.add_child(sh)
	_block_label = UiTheme.label("0", 26, UiPalette.TEXT, true, 6)
	_block_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_block_label.size = Vector2(62, 56)
	block_badge.add_child(_block_label)
	burn_badge = Control.new()
	burn_badge.name = "Burn"
	burn_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burn_badge.visible = false
	_hp_wrap.add_child(burn_badge)
	burn_badge.add_child(UiIcons.rect("intent_burn", 54, Color("ff8a3a")))
	_burn_label = UiTheme.label("0", 24, UiPalette.TEXT, true, 6)
	_burn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_burn_label.position = Vector2(0, 12)
	_burn_label.size = Vector2(54, 44)
	burn_badge.add_child(_burn_label)
	_hp_wrap.resized.connect(_place_hp)

	var chips := UiTheme.hbox(10)
	mid.add_child(chips)
	gold = Counter.make("coin", 0, 28, UiPalette.TEXT)
	chips.add_child(gold)
	treasury = Counter.make("chest", 10, 22, UiPalette.GOLD_BRIGHT)
	treasury.tooltip_text = "Treasury bank: land on the Treasury corner to cash out."
	chips.add_child(treasury)

	var right := UiTheme.vbox(10)
	_row.add_child(right)
	pause_btn = GameButton.round_icon("pause", 88)
	pause_btn.icon_tint = UiPalette.TEXT
	pause_btn.kind = GameButton.Kind.GHOST
	pause_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	right.add_child(pause_btn)

	var act := PanelContainer.new()
	act.add_theme_stylebox_override("panel", UiTheme.panel_box("pill"))
	act.mouse_filter = Control.MOUSE_FILTER_PASS
	_act_chip = act
	# lap chip lives on the chips row, right aligned
	var fill := UiTheme.spacer(0, true)
	chips.add_child(fill)
	chips.add_child(act)
	var ar := UiTheme.hbox(8)
	act.add_child(ar)
	act_label = UiTheme.label("LAP 1/15", 22, UiPalette.GOLD, true, 5)
	ar.add_child(act_label)
	lap_pips = UiTheme.hbox(4)
	lap_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	ar.add_child(lap_pips)

	passives = HFlowContainer.new()
	passives.add_theme_constant_override("h_separation", 6)
	passives.add_theme_constant_override("v_separation", 6)
	passives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(passives)
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	_tip.z_index = 5
	add_child(_tip)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


func _layout() -> void:
	var view := size
	if view.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	var w := minf(MAX_W, view.x - safe.left - safe.right)
	_row.position = Vector2((view.x - w) * 0.5, safe.top)
	_row.size = Vector2(w, 0)
	_row.reset_size()
	_row.size.x = w
	passives.position = Vector2(_row.position.x + 4.0, _row.position.y + _row.size.y + 8.0)
	var pw := maxf(w - 8.0 - reserve_right, 120.0)
	passives.size = Vector2(pw, 0)
	passives.reset_size()
	passives.size.x = pw
	var extra := passives.size.y + 8.0 if not _passive_ids.is_empty() else 0.0
	_scrim.position = Vector2.ZERO
	_scrim.size = Vector2(view.x, safe.top + _row.size.y + extra + 90.0)


## Bottom (local y) of anything docked under the row (the meta HUD strip); content_bottom()
## covers it, so what stacks under the HUD (the AUTO cluster) stays clear.
var extra_bottom := 0.0


## Global rect of the lap chip (the meta HUD strip anchors under it).
func chips_rect() -> Rect2:
	return _act_chip.get_global_rect()


## Bottom edge of the HUD block (row + passives bar), in local coordinates.
func content_bottom() -> float:
	var b := _row.position.y + _row.size.y
	if not _passive_ids.is_empty():
		b = passives.position.y + passives.size.y
	return maxf(b, extra_bottom)


func _place_hp() -> void:
	var s := _hp_wrap.size
	hp_bar.position = Vector2(30, (s.y - 44) * 0.5)
	hp_bar.size = Vector2(s.x - 30 - (26.0 if block_badge.visible else 0.0), 44)
	var heart := _hp_wrap.get_node("Heart") as Control
	heart.position = Vector2(-4, (s.y - 58) * 0.5)
	heart.size = Vector2(58, 58)
	block_badge.position = Vector2(s.x - 62, (s.y - 62) * 0.5)
	block_badge.size = Vector2(62, 62)
	burn_badge.position = Vector2(s.x - (122.0 if block_badge.visible else 60.0), (s.y - 54) * 0.5)
	burn_badge.size = Vector2(54, 54)


## Burn stacks on the hero (0 hides the badge).
func set_burn(v: int, animate := false) -> void:
	var was := _burn
	_burn = maxi(v, 0)
	burn_badge.visible = _burn > 0
	_burn_label.text = str(_burn)
	_place_hp()
	if animate and _burn > was:
		UiTheme.pop(burn_badge, 1.3, 0.3)


## Full sync from the flow (no animation).
func refresh(flow: GameFlow, animate := false) -> void:
	var run := flow.run
	hp_bar.set_values(run.hp, run.max_hp, animate)
	gold.set_value(run.gold, animate)
	treasury.set_value(run.treasury, animate)
	var prev := Balance.xp_for_level(run.level - 1) if run.level > 1 else 0
	var need := Balance.xp_for_level(run.level)
	level_badge.set_level(run.level, float(run.xp - prev) / float(maxi(1, need - prev)), animate)
	route = Array(run.route)
	set_lap(run.act, run.lap)
	set_block(run.block if flow.phase == GameFlow.Phase.COMBAT else 0, animate)
	set_burn(flow.combat.hero_burn if flow.phase == GameFlow.Phase.COMBAT and flow.combat else 0)
	set_passives(Array(run.passives))


## Takes over another HudTop's shown numbers (combat HUD -> board HUD after a fight) so the
## rewards that follow animate from what the player last saw.
func copy_from(o: HudTop) -> void:
	hp_bar.set_values(o.hp_bar.value, o.hp_bar.max_value, false)
	gold.set_value(o.gold.value, false)
	treasury.set_value(o.treasury.value, false)
	level_badge.set_level(o.level_badge.level, o.level_badge.xp_frac, false)
	route = o.route
	set_lap(o._act, o._lap)
	set_passives(o._passive_ids)


## XP bar for `xp` total at the level currently shown (capped at full; level-ups come from
## their own events).
func show_xp(xp: int, animate := true) -> void:
	var lv := level_badge.level
	var prev := Balance.xp_for_level(lv - 1) if lv > 1 else 0
	var need := Balance.xp_for_level(lv)
	level_badge.set_level(lv, float(xp - prev) / float(maxi(1, need - prev)), animate)


func set_lap(act: int, lap: int) -> void:
	_act = act
	_lap = lap
	var final := lap >= Balance.TOTAL_LAPS
	var bc := biome_color(act)
	act_label.text = "FINAL LAP" if final else "LAP %d/%d" % [lap, Balance.TOTAL_LAPS]
	act_label.label_settings = UiTheme.label_settings(22, UiPalette.HP_BRIGHT if final else bc.lerp(UiPalette.GOLD_BRIGHT, 0.45), true, 5)
	_act_chip.tooltip_text = "%s  ·  Tier %s  ·  Lap %d of %d" % [biome_name(act),
		ROMAN[clampi(act - 1, 0, 3)], lap, Balance.TOTAL_LAPS]
	var sb := UiTheme.panel_box("pill").duplicate() as StyleBoxFlat
	sb.border_color = Color(bc, 0.7)
	_act_chip.add_theme_stylebox_override("panel", sb)
	_set_laps(act, lap)


## Rebuilds the passives bar (ids in pickup order).
func set_passives(ids: Array) -> void:
	if ids == _passive_ids and passives.get_child_count() == ids.size():
		return
	_passive_ids = ids.duplicate()
	UiTheme.clear(passives)
	for id in ids:
		_add_passive_icon(String(id))
	_layout()


## Adds one passive to the bar with a pop (passive_gained).
func add_passive(id: String) -> void:
	if _passive_ids.has(id):
		return
	_passive_ids.append(id)
	var p := _add_passive_icon(id)
	_layout()
	if is_inside_tree():
		p.flash()


func flash_passive(id: String) -> void:
	for c in passives.get_children():
		if c is PassiveIcon and (c as PassiveIcon).id == id:
			(c as PassiveIcon).flash()


func _add_passive_icon(id: String) -> PassiveIcon:
	var p := PassiveIcon.make(id, PASSIVE_PX, true)
	p.tapped.connect(show_tip.bind(p))
	p.mouse_entered.connect(func() -> void: show_tip(id, p))
	p.mouse_exited.connect(hide_tip)
	passives.add_child(p)
	return p


## Tooltip under a passive icon: name (rarity colour) + description.
func show_tip(id: String, anchor: Control = null) -> void:
	if not Passives.DEFS.has(id):
		return
	var d: Dictionary = Passives.DEFS[id]
	var rc := UiPalette.passive_color(String(d.rarity))
	UiTheme.clear(_tip)
	_tip.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.05, 0.05, 0.12, 0.96), 16, 2, rc, 10, Color(0, 0, 0, 0.4)), 16, 10))
	var col := UiTheme.vbox(2)
	_tip.add_child(col)
	var head := UiTheme.hbox(8)
	col.add_child(head)
	head.add_child(UiTheme.label(String(d.name), 26, rc.lightened(0.3), true, 5))
	var tag := "BOSS" if String(d.rarity) == "boss" else String(d.rarity).to_upper()
	head.add_child(UiTheme.label(tag, 15, rc, false, 0, false, 800))
	var desc := UiTheme.para(String(d.desc), 21, UiPalette.TEXT_DIM, 500)
	desc.custom_minimum_size.x = minf(380.0, size.x - 60.0)
	col.add_child(desc)
	_tip.visible = true
	_tip.reset_size()
	var s := _tip.get_combined_minimum_size()
	_tip.size = s
	var at := Vector2(24, content_bottom() + 10.0)
	if anchor:
		var r := anchor.get_global_rect()
		at = Vector2(r.position.x + r.size.x * 0.5 - s.x * 0.5, r.end.y + 8.0) - global_position
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


func set_block(v: int, animate := false) -> void:
	var was := _block
	_block = v
	block_badge.visible = v > 0
	_block_label.text = str(v)
	_place_hp()
	if animate and v > was:
		UiTheme.pop(block_badge, 1.3, 0.3)


## Accent colour / name of the biome at tier `act` on this run's route.
func biome_color(act: int) -> Color:
	if act >= 1 and act <= route.size():
		return UiPalette.biome_color(String(route[act - 1]))
	return BIOME_COLORS[clampi(act - 1, 0, 2)]


func biome_name(act: int) -> String:
	if act >= 1 and act <= route.size():
		return BiomeDefs.name_of(String(route[act - 1]))
	return String(SummaryScreen.ACT_NAMES[clampi(act - 1, 0, 2)])


func _set_laps(act: int, lap: int) -> void:
	UiTheme.clear(lap_pips)
	var first := int(Balance.BIOME_LAPS[clampi(act - 1, 0, Balance.BIOME_LAPS.size() - 1)])
	var bc := biome_color(act)
	for i in Balance.LAPS_PER_ACT:
		var n := first + i
		var dot := _Pip.new()
		dot.state = 2 if n < lap else (1 if n == lap else 0)
		dot.color = bc
		dot.boss = n == Balance.TOTAL_LAPS
		dot.custom_minimum_size = Vector2(16, 16)
		lap_pips.add_child(dot)


## Animation hooks for gameplay events.
func on_event(ev: Dictionary, flow: GameFlow) -> void:
	match String(ev.get("type", "")):
		"gold_changed":
			gold.set_value(int(ev.total), true)
			if ev.has("treasury"):
				treasury.set_value(int(ev.treasury), true)
		"hp_changed":
			hp_bar.set_values(int(ev.total), int(ev.get("max_hp", flow.run.max_hp)), true)
		"damage":
			if str(ev.get("target", "")) == "hero":
				hp_bar.set_values(int(ev.get("hp", flow.run.hp)), int(ev.get("max_hp", flow.run.max_hp)), true)
				set_block(int(ev.get("block", flow.run.block)), false)
		"block_gained":
			if str(ev.get("target", "")) == "hero":
				set_block(maxi(int(ev.get("total", flow.run.block)), 0), true)
		"combat_turn_started":
			set_block(0)
		"status":
			if str(ev.get("target", "")) == "hero" and String(ev.get("status", "")) == "burn":
				set_burn(int(ev.get("value", 0)), true)
		"combat_started":
			set_burn(0)
		"board_rolled":
			if int(ev.get("treasury_added", 0)) <= 0:
				treasury.set_value(int(ev.get("treasury", flow.run.treasury)), true)
		"level_up":
			var lv := int(ev.get("level", level_badge.level + 1))
			var prev := Balance.xp_for_level(lv - 1) if lv > 1 else 0
			var need := int(ev.get("next", Balance.xp_for_level(lv)))
			var xp := int(ev.get("xp", flow.run.xp))
			level_badge.set_level(lv, float(xp - prev) / float(maxi(1, need - prev)), true)
		"combat_won":
			set_burn(0)
			show_xp(flow.run.xp, true)
		"lap_completed":
			if not bool(ev.get("boss", false)):
				set_lap(_act, int(ev.lap) + 1)
		"act_started":
			set_lap(int(ev.get("act", _act)), int(ev.get("lap", _lap)))
			treasury.set_value(int(ev.get("treasury", flow.run.treasury)), false)


class _Pip:
	extends Control
	## 0 = future, 1 = current, 2 = done
	var state := 0
	var color: Color = UiPalette.GOLD
	## The final lap (the boss) is drawn as a small skull-red diamond.
	var boss := false

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		if boss:
			var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
			draw_colored_polygon(pts, UiPalette.OUTLINE)
			var k := r - 2.5
			var inner := PackedVector2Array([c + Vector2(0, -k), c + Vector2(k, 0), c + Vector2(0, k), c + Vector2(-k, 0)])
			draw_colored_polygon(inner, UiPalette.DANGER if state > 0 else UiPalette.DANGER_DARK)
			return
		draw_circle(c, r, UiPalette.OUTLINE)
		match state:
			2:
				draw_circle(c, r - 2.5, color.darkened(0.1))
			1:
				draw_circle(c, r - 2.5, color.darkened(0.35))
				draw_circle(c, r - 5.5, color.lightened(0.45))
			_:
				draw_circle(c, r - 2.5, Color(1, 1, 1, 0.12))


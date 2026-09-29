class_name RouteStrip
extends VBoxContainer
## The run's route: three biome stops (medallion, name, lap range, optional one-line twist)
## joined by arrows, and the two boss stops (lap-7 mini-boss, lap-15 final boss) under them.
## Used by the route card (full), the pause menu and the summary (compact).
##
##   var s := RouteStrip.make(flow.route_info(), flow.run.act, flow.run.lap, false)

## GameFlow.route_info() shape.
var info: Dictionary = {}
## Current tier (1..3); 0 = none highlighted (route card at run start highlights tier 1).
var current := 0
## Current lap (lap pips under each stop; 0 hides them).
var lap := 0
var compact := false
## Bosses beaten flags for the summary (ticks on the boss chips).
var beaten := {"miniboss": false, "boss": false}


static func make(p_info: Dictionary, p_current := 0, p_lap := 0, p_compact := false) -> RouteStrip:
	var s := RouteStrip.new()
	s.info = p_info
	s.current = p_current
	s.lap = p_lap
	s.compact = p_compact
	s.add_theme_constant_override("separation", 10 if p_compact else 18)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s._rebuild()
	return s


func _rebuild() -> void:
	UiTheme.clear(self)
	var route: Array = info.get("route", [])
	var row := UiTheme.hbox(4 if compact else 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	for t in route.size():
		if t > 0:
			var arrow := UiIcons.rect("arrow_right", 26 if compact else 34, UiPalette.TEXT_MUTED)
			arrow.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			arrow.custom_minimum_size.y = 64 if compact else 104
			row.add_child(arrow)
		row.add_child(_stop(route[t], t + 1))
	var bosses := UiTheme.hbox(12)
	bosses.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bosses)
	var mb: Dictionary = info.get("miniboss", {})
	var fb: Dictionary = info.get("boss", {})
	if not mb.is_empty():
		bosses.add_child(_boss_chip("skull", "LAP %d  ·  MINI-BOSS" % Balance.MINIBOSS_LAP if not compact else "LAP %d" % Balance.MINIBOSS_LAP,
			String(mb.get("name", "")), Color("ff9a3a"), bool(beaten.miniboss)))
	if not fb.is_empty():
		bosses.add_child(_boss_chip("crown", "LAP %d  ·  FINAL BOSS" % Balance.TOTAL_LAPS if not compact else "LAP %d" % Balance.TOTAL_LAPS,
			String(fb.get("name", "")), UiPalette.DANGER.lightened(0.15), bool(beaten.boss)))


func _stop(b: Dictionary, tier: int) -> Control:
	var id := String(b.get("id", ""))
	var bc := UiPalette.biome_color(id)
	var here := tier == current
	var past := current > 0 and tier < current
	var col := UiTheme.vbox(2 if compact else 4)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.custom_minimum_size.x = 140 if compact else 172
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var px := 64 if compact else 104
	var med := OptionCard.Medallion.make(UiIcons.biome_icon(id), px, null, bc if (here or current == 0) else bc.darkened(0.35))
	med.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	med.modulate = Color(1, 1, 1, 0.55) if past else Color.WHITE
	col.add_child(med)
	var first := int(Balance.BIOME_LAPS[clampi(tier - 1, 0, Balance.BIOME_LAPS.size() - 1)])
	var last := first + Balance.LAPS_PER_ACT - 1
	var cap := UiTheme.label("TIER %s  ·  LAPS %d–%d" % [["I", "II", "III"][clampi(tier - 1, 0, 2)], first, last] if not compact
		else "LAPS %d–%d" % [first, last], 14 if compact else 16, bc.lightened(0.25) if here or current == 0 else UiPalette.TEXT_MUTED, false, 0, false, 800)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	var nm := UiTheme.label(String(b.get("name", id)).to_upper(), 20 if compact else 28,
		bc.lerp(UiPalette.GOLD_BRIGHT, 0.3) if here or current == 0 else UiPalette.TEXT_DIM, true, 5)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(nm)
	if lap > 0:
		var pips := UiTheme.hbox(3)
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(pips)
		for k in Balance.LAPS_PER_ACT:
			var n := first + k
			var dot := HudTop._Pip.new()
			dot.state = 2 if n < lap else (1 if n == lap else 0)
			dot.color = bc
			dot.boss = n == Balance.TOTAL_LAPS
			dot.custom_minimum_size = Vector2(14, 14)
			pips.add_child(dot)
	if not compact and String(b.get("desc", "")) != "":
		var d := UiTheme.para(String(b.desc), 19, UiPalette.TEXT_DIM, 500)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.custom_minimum_size.x = 160
		col.add_child(d)
	return col


func _boss_chip(icon: String, caption: String, name: String, color: Color, done: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(UiPalette.NAVY_2, 18, 2, Color(color, 0.45)), 14 if compact else 18, 8))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(10)
	p.add_child(row)
	row.add_child(UiIcons.rect("check" if done else icon, 34 if compact else 44, UiPalette.HEAL if done else color))
	var col := UiTheme.vbox(-4)
	row.add_child(col)
	col.add_child(UiTheme.label(caption, 13 if compact else 15, color.lightened(0.2), false, 0, false, 800))
	col.add_child(UiTheme.label(name.to_upper(), 20 if compact else 26, UiPalette.TEXT, true, 5))
	return p

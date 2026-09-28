class_name GameOverlay
extends Control
## Screen-space presentation layer owned by the GameController (sits above the HUD):
## toasts, big announcements (act / boss / level up), small popups anchored to a screen
## point (rune triggers over tray dice; nearby popups stack instead of overlapping), the
## trap / duel mini dice, passive cards and pops, the boss name card and vignette, the
## swirling biome-change dissolve and the black fade. Purely visual; never blocks input
## (except while faded to black or dissolved).

## Presentation speed (game speed setting). Durations are divided by it.
var speed := 1.0

var _fade: ColorRect
var _toasts: Control
var _popups: Control
var _announce: VBoxContainer
var _ann_title: Label
var _ann_sub: Label
var _ann_tween: Tween
var _toast_count := 0
var _dissolve: ColorRect
var _vignette: TextureRect
var _vig_tween: Tween
## Live popups: [{pos: Vector2, until: msec}] for stacking.
var _live_pops: Array = []
## Returns true while a modal is open; toasts are skipped then (the modal shows the change).
var modal_check: Callable


func _init() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popups = Control.new()
	_popups.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.full_rect(_popups))
	_toasts = Control.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.full_rect(_toasts))
	_announce = UiTheme.vbox(-6)
	_announce.alignment = BoxContainer.ALIGNMENT_CENTER
	_announce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_announce)
	_ann_title = UiTheme.label("", 84, UiPalette.GOLD_BRIGHT, true, 16)
	_ann_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.add_child(_ann_title)
	_ann_sub = UiTheme.label("", 34, UiPalette.TEXT, true, 8)
	_ann_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.add_child(_ann_sub)
	_announce.visible = false
	_vignette = TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.0, 0.04, 0.35), Color(0.02, 0.0, 0.04, 0.95)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.45)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 256
	gt.height = 256
	_vignette.texture = gt
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	_vignette.visible = false
	add_child(UiTheme.full_rect(_vignette))
	move_child(_vignette, 0)
	_dissolve = ColorRect.new()
	_dissolve.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dm := ShaderMaterial.new()
	dm.shader = preload("res://game/flow/dissolve.gdshader")
	_dissolve.material = dm
	_dissolve.visible = false
	add_child(UiTheme.full_rect(_dissolve))
	_fade = ColorRect.new()
	_fade.color = Color(0.01, 0.01, 0.03, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.full_rect(_fade))


func _d(t: float) -> float:
	return t / maxf(speed, 0.01)


# --- fade --------------------------------------------------------------------------------

func fade_out(time := 0.45) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, _d(time)).set_trans(Tween.TRANS_SINE)
	await t.finished


func fade_in(time := 0.6) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", 0.0, _d(time)).set_trans(Tween.TRANS_SINE)
	await t.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_black(on: bool) -> void:
	_fade.color.a = 1.0 if on else 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


## Swirling iris dissolve (biome change). cover = true closes the screen toward `center`
## (normalised screen point) in `color` with a glowing `edge`; false opens it again. Await it.
func dissolve(cover: bool, color: Color, edge: Color, time := 0.7, center := Vector2(0.5, 0.42)) -> void:
	var m := _dissolve.material as ShaderMaterial
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("edge", edge)
	m.set_shader_parameter("center", center)
	m.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_dissolve.visible = true
	_dissolve.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_method(func(v: float) -> void: m.set_shader_parameter("progress", v),
		0.0 if cover else 1.0, 1.0 if cover else 0.0, _d(time)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	if not cover:
		_dissolve.visible = false
		_dissolve.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Darkens the screen edges (0 = off). Non-blocking.
func vignette(alpha: float, time := 0.5) -> void:
	if _vig_tween and _vig_tween.is_valid():
		_vig_tween.kill()
	_vignette.visible = true
	_vig_tween = create_tween()
	_vig_tween.tween_property(_vignette, "modulate:a", alpha, _d(time)).set_trans(Tween.TRANS_SINE)
	if alpha <= 0.0:
		_vig_tween.tween_callback(func() -> void: _vignette.visible = false)


## Boss name card: a dark band across the screen with the name slamming in (non-blocking).
func boss_card(title: String, subtitle: String, color: Color = UiPalette.DANGER, hold := 1.6) -> void:
	var band := Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	move_child(band, _fade.get_index())
	var h := 210.0
	var y := size.y * 0.3 - h * 0.5
	band.position = Vector2(0, y)
	band.size = Vector2(size.x, h)
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	g.colors = PackedColorArray([Color(0.05, 0.0, 0.03, 0.0), Color(0.05, 0.0, 0.03, 0.88), Color(0.05, 0.0, 0.03, 0.88), Color(0.05, 0.0, 0.03, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.size = band.size
	band.add_child(bg)
	for ly in [8.0, h - 12.0]:
		var line := ColorRect.new()
		line.color = Color(color, 0.85)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.position = Vector2(size.x * 0.08, ly)
		line.size = Vector2(size.x * 0.84, 4)
		band.add_child(line)
	var col := UiTheme.vbox(-8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(col)
	var fs := 96
	var tw := UiTheme.display_font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.6
	if tw > size.x - 40.0:
		fs = int(fs * (size.x - 40.0) / tw)
	var tl := UiTheme.label(title, fs, color.lightened(0.25), true, int(fs * 0.18))
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tl)
	var sl := UiTheme.label(subtitle.to_upper(), 28, UiPalette.GOLD_BRIGHT, true, 6)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sl)
	col.reset_size()
	col.size = Vector2(size.x, h)
	col.position = Vector2.ZERO
	col.pivot_offset = col.size * 0.5
	col.scale = Vector2(2.2, 2.2)
	col.modulate.a = 0.0
	band.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(band, "modulate:a", 1.0, _d(0.15))
	t.parallel().tween_property(col, "scale", Vector2.ONE, _d(0.28)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(col, "modulate:a", 1.0, _d(0.12))
	t.tween_interval(_d(hold))
	t.tween_property(band, "modulate:a", 0.0, _d(0.4))
	t.tween_callback(band.queue_free)


## "New passive" card sliding in under the top HUD: rarity-ringed icon, name, description.
## Non-blocking; holds for `hold` seconds.
func passive_card(id: String, hold := 1.7) -> void:
	if not Passives.DEFS.has(id):
		return
	var d: Dictionary = Passives.DEFS[id]
	var rar := String(d.rarity)
	var rc := UiPalette.passive_color(rar)
	var p := PanelContainer.new()
	var sb := UiTheme.pad(UiTheme.box(Color(0.06, 0.06, 0.14, 0.95), 26, 3, rc, 18, Color(rc, 0.35), Vector2.ZERO), 22, 14)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	move_child(p, _fade.get_index())
	var row := UiTheme.hbox(16)
	p.add_child(row)
	row.add_child(PassiveIcon.make(id, 84))
	var col := UiTheme.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var cap := "BOSS PASSIVE" if rar == "boss" else "NEW PASSIVE"
	col.add_child(UiTheme.label(cap, 18, rc.lightened(0.2), false, 0, false, 800))
	col.add_child(UiTheme.label(String(d.name), 36, UiPalette.TEXT, true, 6))
	var desc := UiTheme.para(String(d.desc), 22, UiPalette.TEXT_DIM, 500)
	desc.custom_minimum_size.x = minf(420.0, size.x - 220.0)
	col.add_child(desc)
	p.reset_size()
	var s := p.get_combined_minimum_size()
	p.size = s
	var y := size.y * 0.16
	p.position = Vector2((size.x - s.x) * 0.5, y - 60.0)
	p.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(p, "position:y", y, _d(0.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(p, "modulate:a", 1.0, _d(0.2))
	t.tween_interval(_d(hold))
	t.tween_property(p, "modulate:a", 0.0, _d(0.35))
	t.parallel().tween_property(p, "position:y", y - 40.0, _d(0.35))
	t.tween_callback(p.queue_free)


## Small passive trigger pop: the passive's icon flashes at a screen point with a short label.
func passive_pop(at: Vector2, id: String, text := "") -> void:
	var rc := UiPalette.passive_color(Passives.rarity(id)) if Passives.DEFS.has(id) else UiPalette.GOLD
	var row := UiTheme.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(PassiveIcon.make(id, 52))
	if text != "":
		row.add_child(UiTheme.label(text, 26, rc.lightened(0.35), true, 7))
	_popups.add_child(row)
	row.reset_size()
	var s := row.get_combined_minimum_size()
	var p := _stack(at - Vector2(s.x * 0.5, s.y), s)
	row.position = p
	row.pivot_offset = s * 0.5
	row.scale = Vector2(0.2, 0.2)
	var t := create_tween()
	t.tween_property(row, "scale", Vector2(1.15, 1.15), _d(0.16)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(row, "scale", Vector2.ONE, _d(0.12))
	t.tween_property(row, "position:y", p.y - 46.0, _d(0.8)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(row, "modulate:a", 0.0, _d(0.35)).set_delay(_d(0.45))
	t.tween_callback(row.queue_free)


# --- announcements -------------------------------------------------------------------------

## Big centred title + subtitle that pops in, holds, and fades (non-blocking).
func announce(title: String, subtitle := "", color: Color = UiPalette.GOLD_BRIGHT, hold := 1.1) -> void:
	_ann_title.text = title
	var fs := 84
	var tw := UiTheme.display_font().get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.5
	if tw > size.x - 48.0:
		fs = int(fs * (size.x - 48.0) / tw)
	_ann_title.label_settings = UiTheme.label_settings(fs, color, true, int(fs * 0.19))
	_ann_sub.text = subtitle
	_ann_sub.visible = subtitle != ""
	_announce.visible = true
	_announce.reset_size()
	var s := _announce.get_combined_minimum_size()
	_announce.size = Vector2(size.x, s.y)
	_announce.position = Vector2(0, size.y * 0.3 - s.y * 0.5)
	_announce.pivot_offset = _announce.size * 0.5
	_announce.scale = Vector2(0.4, 0.4)
	_announce.modulate.a = 0.0
	if _ann_tween and _ann_tween.is_valid():
		_ann_tween.kill()
	_ann_tween = create_tween()
	_ann_tween.set_parallel(true)
	_ann_tween.tween_property(_announce, "scale", Vector2.ONE, _d(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ann_tween.tween_property(_announce, "modulate:a", 1.0, _d(0.15))
	_ann_tween.chain().tween_interval(_d(hold))
	_ann_tween.chain().tween_property(_announce, "modulate:a", 0.0, _d(0.3))
	_ann_tween.chain().tween_callback(func() -> void: _announce.visible = false)


# --- toasts --------------------------------------------------------------------------------

## Pill message above the bottom HUD that rises and fades. `y_ratio` is the screen height
## fraction it appears at.
func toast(text: String, icon := "", color: Color = UiPalette.TEXT, y_ratio := 0.47) -> void:
	if modal_check.is_valid() and bool(modal_check.call()):
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.panel_box("pill"), 24, 12))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UiTheme.hbox(10)
	p.add_child(row)
	if icon != "" and UiIcons.exists(icon):
		row.add_child(UiIcons.rect(icon, 36))
	row.add_child(UiTheme.label(text, 28, color, true, 0, true))
	_toasts.add_child(p)
	p.reset_size()
	var slot := _toast_count % 3
	_toast_count += 1
	var y := size.y * y_ratio - slot * 66.0
	p.position = Vector2((size.x - p.size.x) * 0.5, y)
	p.pivot_offset = p.size * 0.5
	p.scale = Vector2(0.6, 0.6)
	p.modulate.a = 0.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(p, "scale", Vector2.ONE, _d(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(p, "modulate:a", 1.0, _d(0.15))
	t.chain().tween_interval(_d(1.3))
	t.chain().set_parallel(true)
	t.tween_property(p, "position:y", y - 50.0, _d(0.4))
	t.tween_property(p, "modulate:a", 0.0, _d(0.4))
	t.chain().tween_callback(func() -> void:
		p.queue_free()
		_toast_count = maxi(_toast_count - 1, 0))


# --- popups --------------------------------------------------------------------------------

## Small floating label (optionally with an icon) at a screen point; rises and fades.
func popup(at: Vector2, text: String, color: Color, icon := "", font := 30) -> void:
	var row := UiTheme.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "" and UiIcons.exists(icon):
		row.add_child(UiIcons.rect(icon, int(font * 1.2)))
	row.add_child(UiTheme.label(text, font, color, true, 8))
	_popups.add_child(row)
	row.reset_size()
	var s := row.get_combined_minimum_size()
	var p := _stack(at - Vector2(s.x * 0.5, s.y), s)
	row.position = p
	row.pivot_offset = s * 0.5
	row.scale = Vector2(0.3, 0.3)
	var t := create_tween()
	t.tween_property(row, "scale", Vector2.ONE, _d(0.18)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(row, "position:y", p.y - 70.0, _d(0.9)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(row, "modulate:a", 0.0, _d(0.3))
	t.tween_callback(row.queue_free)


## Clamps a popup's top-left `p` (size `s`) on screen and moves it up past any live popup it
## would overlap, then records it (popups at the same die stack instead of piling up).
func _stack(p: Vector2, s: Vector2) -> Vector2:
	p.x = clampf(p.x, 8.0, size.x - s.x - 8.0)
	var now := Time.get_ticks_msec()
	var live: Array = []
	for lp in _live_pops:
		if int(lp.until) > now:
			live.append(lp)
	_live_pops = live
	var moved := true
	var guard := 0
	while moved and guard < 8:
		moved = false
		guard += 1
		for lp in _live_pops:
			var r: Rect2 = lp.rect
			if r.intersects(Rect2(p, s).grow(-4.0)):
				p.y = r.position.y - s.y - 2.0
				moved = true
	_live_pops.append({"rect": Rect2(p, s), "until": now + int(_d(0.55) * 1000.0)})
	return p


# --- mini dice (trap, duel) ------------------------------------------------------------------


## Tumbles 2D dice for `values` in a panel at the screen centre, then holds them. Await it.
## `caption` is shown above; `result` (with `result_color`) below once they settle.
func mini_dice(caption: String, groups: Array, result: String, result_color: Color) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.panel_box("main"), 30, 20))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var col := UiTheme.vbox(12)
	panel.add_child(col)
	var cap := UiTheme.label(caption, 32, UiPalette.GOLD, true, 6)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	var row := UiTheme.hbox(28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var faces: Array[DieFace] = []
	var finals: Array[int] = []
	for g in groups:
		var gcol := UiTheme.vbox(6)
		row.add_child(gcol)
		var grow := UiTheme.hbox(10)
		grow.alignment = BoxContainer.ALIGNMENT_CENTER
		gcol.add_child(grow)
		for v in g.values:
			var f := DieFace.make(randi_range(1, 6), "", false, 92)
			grow.add_child(f)
			faces.append(f)
			finals.append(int(v))
		if String(g.get("label", "")) != "":
			var gl := UiTheme.label(String(g.label), 24, UiPalette.TEXT_DIM, true, 0)
			gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gcol.add_child(gl)
	var res := UiTheme.label(result, 38, result_color, true, 8)
	res.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res.modulate.a = 0.0
	col.add_child(res)
	panel.reset_size()
	var s := panel.get_combined_minimum_size()
	panel.size = s
	panel.position = Vector2((size.x - s.x) * 0.5, size.y * 0.36 - s.y * 0.5)
	panel.pivot_offset = s * 0.5
	panel.scale = Vector2(0.7, 0.7)
	var t := create_tween()
	t.tween_property(panel, "scale", Vector2.ONE, _d(0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_sfx("dice_shake")
	var spins := 9
	for k in spins:
		for f in faces:
			f.value = randi_range(1, 6)
			f.rotation = randf_range(-0.35, 0.35)
			f.pivot_offset = f.size * 0.5
		await get_tree().create_timer(_d(0.06), false).timeout
	for i in faces.size():
		faces[i].value = finals[i]
		faces[i].rotation = 0.0
		UiTheme.pop(faces[i], 1.25, _d(0.2))
	Audio.play_sfx("dice_land")
	var rt := create_tween()
	rt.tween_property(res, "modulate:a", 1.0, _d(0.15))
	await get_tree().create_timer(_d(0.95), false).timeout
	var out := create_tween()
	out.tween_property(panel, "modulate:a", 0.0, _d(0.2))
	out.tween_callback(panel.queue_free)

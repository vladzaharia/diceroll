class_name GameOverlay
extends Control
## Screen-space presentation layer owned by the GameController (sits above the HUD):
## toasts, big announcements (act / boss / level up), small popups anchored to a screen
## point (rune triggers over tray dice), the trap / duel mini dice and the black fade used
## for act transitions. Purely visual; never blocks input (except while faded to black).

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
	var p := at - Vector2(s.x * 0.5, s.y)
	p.x = clampf(p.x, 8.0, size.x - s.x - 8.0)
	row.position = p
	row.pivot_offset = s * 0.5
	row.scale = Vector2(0.3, 0.3)
	var t := create_tween()
	t.tween_property(row, "scale", Vector2.ONE, _d(0.18)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(row, "position:y", p.y - 70.0, _d(0.9)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(row, "modulate:a", 0.0, _d(0.3))
	t.tween_callback(row.queue_free)


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

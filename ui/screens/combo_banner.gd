class_name ComboBanner
extends Control
## Big animated combo splash: rotating light rays, combo name, ×mult and damage. Scale,
## colour and flash grow with rarity (multiplier). Non-blocking (ignores mouse).
##
##   banner.on_event({type:"combo", name:"Full House", mult:3.5, total:64})
##   await banner.finished

signal finished

var tier := 0
## Keep the banner on screen (screenshots).
var hold := false
var _name: Label
var _mult: Label
var _total: Label
var _col: VBoxContainer
var _rays: _Rays
var _flash: ColorRect
var _tween: Tween


func _init() -> void:
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.95, 0.8, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.full_rect(_flash))
	_rays = _Rays.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rays)
	_col = UiTheme.vbox(-10)
	_col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_col)
	_name = UiTheme.label("", 80, UiPalette.GOLD_BRIGHT, true, 16)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_name)
	_mult = UiTheme.label("", 96, UiPalette.TEXT, true, 16)
	_mult.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_mult)
	_total = UiTheme.label("", 40, UiPalette.TEXT, true, 10)
	_total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(_total)
	visible = false


func on_event(ev: Dictionary) -> void:
	if String(ev.get("type", "")) == "combo":
		play(String(ev.name), float(ev.mult), int(ev.get("total", 0)))


static func tier_for(mult: float) -> int:
	if mult >= 5.0:
		return 2
	if mult >= 2.0:
		return 1
	return 0


func play(combo_name: String, mult: float, total := 0) -> void:
	tier = tier_for(mult)
	var scale_k: float = [0.72, 1.0, 1.25][tier]
	var name_col: Color = [UiPalette.TEXT, UiPalette.GOLD_BRIGHT, Color("ffe066")][tier]
	var outline_col: Color = [UiPalette.OUTLINE, Color("5a2a08"), Color("7a1020")][tier]
	var fs := int(78 * scale_k)
	# fit the name inside the screen width
	var tw := UiTheme.display_font().get_string_size(combo_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.4
	var avail := maxf(200.0, size.x - 64.0)
	if tw > avail:
		fs = int(fs * avail / tw)
	_name.text = combo_name.to_upper()
	_name.label_settings = _ls(fs, name_col, outline_col, int(fs * 0.2))
	_mult.text = "×" + CombatHud._fmt(mult)
	_mult.label_settings = _ls(int(fs * 1.25), UiPalette.TEXT, outline_col, int(fs * 0.24))
	_total.text = "%d DAMAGE" % total if total > 0 else ""
	_total.label_settings = _ls(int(40 * minf(scale_k, 1.1)), UiPalette.HP_BRIGHT, UiPalette.OUTLINE, 10)
	_total.visible = total > 0
	_rays.color = [Color(1, 1, 1, 0.0), Color(1.0, 0.8, 0.35, 0.22), Color(1.0, 0.55, 0.3, 0.32)][tier]
	_rays.visible = tier > 0
	visible = true
	await get_tree().process_frame
	_layout()
	if _tween and _tween.is_valid():
		_tween.kill()
	_col.modulate.a = 1.0
	_col.scale = Vector2(0.2, 0.2)
	_col.rotation = deg_to_rad(-6.0)
	_rays.modulate.a = 0.0
	_rays.scale = Vector2(0.4, 0.4)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_col, "scale", Vector2.ONE * 1.08, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_col, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_rays, "modulate:a", 1.0, 0.2)
	_tween.tween_property(_rays, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if tier == 2:
		_flash.color.a = 0.55
		_tween.tween_property(_flash, "color:a", 0.0, 0.35)
	_tween.chain().tween_property(_col, "scale", Vector2.ONE, 0.12)
	if hold:
		return
	_tween.chain().tween_interval(0.75 + 0.2 * tier)
	_tween.chain().tween_property(_col, "modulate:a", 0.0, 0.25)
	_tween.tween_property(_col, "position:y", _col.position.y - 60.0, 0.25)
	_tween.tween_property(_rays, "modulate:a", 0.0, 0.25)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		finished.emit())
	UiTheme.sfx(["hit", "crit", "fanfare"][tier])


func _layout() -> void:
	_col.reset_size()
	var cs := _col.get_combined_minimum_size()
	_col.size = cs
	var cy := size.y * 0.4
	_col.position = Vector2((size.x - cs.x) * 0.5, cy - cs.y * 0.5)
	_col.pivot_offset = cs * 0.5
	var rs := maxf(size.x, size.y) * 1.2
	_rays.size = Vector2(rs, rs)
	_rays.position = Vector2(size.x * 0.5, cy) - _rays.size * 0.5
	_rays.pivot_offset = _rays.size * 0.5


func _ls(fs: int, col: Color, outline: Color, osz: int) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = UiTheme.display_font()
	ls.font_size = fs
	ls.font_color = col
	ls.outline_size = osz
	ls.outline_color = outline
	ls.shadow_size = 4
	ls.shadow_color = Color(0, 0, 0, 0.5)
	ls.shadow_offset = Vector2(0, fs * 0.08)
	return ls


class _Rays:
	extends Control
	var color := Color(1, 0.8, 0.3, 0.25)
	var spin := 0.0

	func _process(delta: float) -> void:
		if visible:
			spin += delta * 0.35
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := size.x * 0.5
		var n := 14
		for i in n:
			var a := spin + TAU * i / n
			var w := TAU / n * 0.32
			var pts := PackedVector2Array([c, c + Vector2.from_angle(a - w) * r, c + Vector2.from_angle(a + w) * r])
			var cols := PackedColorArray([color, Color(color, 0.0), Color(color, 0.0)])
			draw_polygon(pts, cols)
		# soft core glow
		for k in 6:
			draw_circle(c, r * (0.22 - k * 0.03), Color(color, color.a * 0.35))

class_name PassiveIcon
extends Control
## Round passive ("relic") badge: rarity-coloured ring around the passive's glyph
## (ui/icons/passive_<id>.svg, tinted warm cream). Boss-tier passives get a gold double ring
## with studs and a soft glow. Emits `tapped(id)` on click / tap when `interactive`.
##
##   var p := PassiveIcon.make("pair_master", 40, true)
##   p.tapped.connect(func(id): show_tip(id))

signal tapped(id: String)

const GLYPH_TINT := Color("f7ecd4")

var id := ""
var interactive := false
var _pulse := 0.0


static func make(p_id: String, px := 40.0, p_interactive := false) -> PassiveIcon:
	var p := PassiveIcon.new()
	p.id = p_id
	p.interactive = p_interactive
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_STOP if p_interactive else Control.MOUSE_FILTER_IGNORE
	if p_interactive:
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if Passives.DEFS.has(p_id):
			p.tooltip_text = "%s\n%s" % [Passives.DEFS[p_id].name, Passives.DEFS[p_id].desc]
	return p


static func glyph(p_id: String) -> String:
	var name := "passive_" + p_id
	return name if Icons.exists(name) else "star"


func rarity() -> String:
	return Passives.rarity(id) if Passives.DEFS.has(id) else "common"


## Brief bright flash (passive triggered).
func flash() -> void:
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		_pulse = v
		queue_redraw(), 1.0, 0.0, 0.6)
	pivot_offset = size * 0.5
	UiTheme.pop(self, 1.35, 0.3)


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		UiTheme.sfx("click")
		tapped.emit(id)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var r := s * 0.5
	var rar := rarity()
	var ring := UiPalette.passive_color(rar)
	var boss := rar == "boss"
	if boss:
		for k in 3:
			draw_circle(c, r * (1.0 + 0.08 * (3 - k)), Color(ring, 0.1 + 0.05 * k))
	if _pulse > 0.0:
		draw_circle(c, r * (1.0 + 0.35 * _pulse), Color(ring, 0.45 * _pulse))
	draw_circle(c + Vector2(0, s * 0.05), r, Color(0, 0, 0, 0.35))
	draw_circle(c, r, UiPalette.OUTLINE)
	draw_circle(c, r - maxf(1.5, s * 0.04), ring.darkened(0.1))
	if boss:
		draw_arc(c, r - s * 0.13, 0.0, TAU, 32, UiPalette.OUTLINE, maxf(1.0, s * 0.035), true)
		for k in 8:
			var a := TAU * k / 8.0 - PI * 0.5
			draw_circle(c + Vector2(cos(a), sin(a)) * (r - s * 0.07), maxf(1.2, s * 0.035), Color("fff2c4"))
	draw_arc(c, r - s * 0.1, PI * 1.1, PI * 1.9, 16, Color(1, 1, 1, 0.3), maxf(1.0, s * 0.04), true)
	var inner := r - s * (0.17 if boss else 0.12)
	draw_circle(c, inner, UiPalette.INK.lerp(ring, 0.18))
	draw_circle(c - Vector2(0, inner * 0.3), inner * 0.7, Color(1, 1, 1, 0.05))
	var gs := inner * 1.42
	var tex := Icons.tex(glyph(id), int(maxf(s * 1.6, 24.0)), GLYPH_TINT.lerp(ring.lightened(0.4), 0.25))
	if tex:
		draw_texture_rect(tex, Rect2(c - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false)

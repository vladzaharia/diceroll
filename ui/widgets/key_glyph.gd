class_name KeyGlyph
extends Control
## A keyboard keycap / mouse glyph from the icon map's "input_glyphs" (vector-keyboard-controls).
## The pack draws key letters as SVG <text>, which Godot's rasteriser drops, so the art is
## imported with its text stripped and this widget draws the label itself in Lilita One
## (#476475, centred at 0.40 of the height because of the key's lip). Used by the GameButton
## hover keycap and the Settings -> Controls list (slice e). Without the pack it draws a
## rounded key with the label, so it never renders empty.
##
##   var k := KeyGlyph.make("key_r", 26)       # 26 px tall
##   k.label_text                                # "R" (from icon_map "label")

const INK := Color("476475")
const LABEL_Y := 0.40

var glyph_id := ""
var label_text := ""
var px := 26.0
var _tex: Texture2D


static func make(id: String, height := 26.0) -> KeyGlyph:
	var k := KeyGlyph.new()
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.set_glyph(id, height)
	return k


## Short label of a glyph id ("key_space" -> "SPACE"), from the map, else derived from the id.
## A mapped glyph whose label is null (arrows, blank key, mouse) is pure art: no label.
static func label_of(id: String) -> String:
	var e: Variant = Icons.entries().get(id, null)
	if e is Dictionary and e.has("label"):
		var lab: Variant = e["label"]
		return lab if lab is String else ""
	return id.trim_prefix("key_").trim_prefix("mouse_").to_upper()


func set_glyph(id: String, height := -1.0) -> void:
	glyph_id = id
	if height > 0.0:
		px = height
	label_text = label_of(id)
	_tex = Icons.texture(id, int(ceil(px * 2.0))) if Icons.is_mapped(id) else null
	custom_minimum_size = _natural_size()
	size = custom_minimum_size
	queue_redraw()


func _natural_size() -> Vector2:
	if _tex != null:
		var s := _tex.get_size()
		return Vector2(px * s.x / maxf(s.y, 1.0), px)
	var f := UiTheme.display_font()
	var w := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(px * 0.46)).x
	return Vector2(maxf(px, w + px * 0.6), px)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _tex != null:
		draw_texture_rect(_tex, r, false)
	else:
		draw_style_box(UiTheme.box(Color("dfe6ea"), int(px * 0.22), 2, INK), Rect2(0, 0, size.x, size.y * 0.9))
	if label_text == "" or glyph_id.begins_with("mouse"):
		return
	var f := UiTheme.display_font()
	var fs := int(px * (0.46 if label_text.length() <= 1 else 0.34))
	var tw := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var maxw := size.x * 0.78
	if tw > maxw and tw > 0.0:
		fs = maxi(8, int(fs * maxw / tw))
		tw = f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := size.y * LABEL_Y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
	draw_string(f, Vector2((size.x - tw) * 0.5, base), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)

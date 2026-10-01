class_name ControlsList
extends VBoxContainer
## Settings -> Controls (desktop only, spec 6): every keyboard shortcut with its keycaps, built
## from InputActions.list() so it can't go stale. Slice (c) hosts it in the Settings panel
## (and the pause menu's "Controls" entry / F1 open that section); on touch the host hides it.
##
##   var c := ControlsList.make()        # group headings + one row per action
##   c.rebuild()                         # after a rebinding
##
## Row: [keycaps] label. Several keys join with "/" ([SPACE] / [ENTER]); a key run ("range"
## rows: 1-6, 1-3) shows its first and last key ([1] - [6]).

const GLYPH_PX := 34.0

var glyph_px := GLYPH_PX
const LABEL_PX := 22


## `glyph_px`: keycap height (Settings passes 40 so the key labels stay legible on the
## 0.75 phone frame).
static func make(glyph_px := GLYPH_PX) -> ControlsList:
	var c := ControlsList.new()
	c.glyph_px = glyph_px
	c.rebuild()
	return c


func _init() -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func rebuild() -> void:
	UiTheme.clear(self)
	var group := ""
	for row in InputActions.list():
		if String(row.group) != group:
			group = String(row.group)
			add_child(UiModal.section_label(group))
		add_child(_row(row))


## Glyph ids as shown in a row ("range" rows keep the first and last).
static func shown_glyphs(row: Dictionary) -> Array:
	var g: Array = row.get("glyphs", [])
	if bool(row.get("range", false)) and g.size() > 2:
		return [g[0], g[-1]]
	return g


func _row(row: Dictionary) -> Control:
	var h := UiTheme.hbox(12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var keys := UiTheme.hbox(6)
	keys.custom_minimum_size.x = 200
	keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(keys)
	var g := shown_glyphs(row)
	for i in g.size():
		if i > 0:
			var sep := "–" if bool(row.get("range", false)) else "/"
			var l := UiTheme.label(sep, LABEL_PX, UiPalette.TEXT_DIM, false, 0, false, 700)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			keys.add_child(l)
		var k := KeyGlyph.make(String(g[i]), glyph_px)
		k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		keys.add_child(k)
	var t := UiTheme.label(String(row.label), LABEL_PX, UiPalette.TEXT, false, 0, false, 600)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(t)
	return h

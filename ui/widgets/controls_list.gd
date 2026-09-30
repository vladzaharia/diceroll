class_name ControlsList
extends VBoxContainer
## Settings -> Controls (spec 6, desktop only): every keyboard shortcut with its keycaps, built
## live from the action table (InputActions.list()), grouped Run / Combat / Menus / Minigames.
## This is the one place keys are taught: there are no permanent keycap badges anywhere else.
##
##   body.add_child(ControlsList.make())

## Keycap height in the list (spec 6: KeyGlyph at 34 px).
const KEY_PX := 34.0


static func make() -> ControlsList:
	var c := ControlsList.new()
	c.name = "Controls"
	c.add_theme_constant_override("separation", 8)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c._build()
	return c


func _build() -> void:
	add_child(UiModal.section_label("Controls"))
	var rows := InputActions.list()
	for g in InputActions.groups():
		var gl := UiTheme.label(g.to_upper(), 17, UiPalette.TEXT_MUTED, false, 0, false, 800)
		add_child(gl)
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UiTheme.inset_box())
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		var col := UiTheme.vbox(6)
		box.add_child(col)
		for r: Dictionary in rows:
			if String(r["group"]) == g:
				col.add_child(row(r))


## One row: the keycaps (a "range" row shows first-last, e.g. [1]-[6]; alternatives are
## separated by "/") and the action's label.
static func row(r: Dictionary) -> HBoxContainer:
	var h := UiTheme.hbox(12)
	h.name = "Row_" + String(r["action"])
	var keys := HBoxContainer.new()
	keys.add_theme_constant_override("separation", 6)
	keys.alignment = BoxContainer.ALIGNMENT_BEGIN
	keys.custom_minimum_size.x = 190
	h.add_child(keys)
	var glyphs: Array = r.get("glyphs", [])
	if bool(r.get("range", false)) and glyphs.size() > 2:
		glyphs = [glyphs[0], "-", glyphs[glyphs.size() - 1]]
	for i in glyphs.size():
		var gid := String(glyphs[i])
		if gid == "-":
			keys.add_child(_sep("–"))
			continue
		if i > 0 and String(glyphs[i - 1]) != "-":
			keys.add_child(_sep("/"))
		var k := KeyGlyph.make(gid, KEY_PX)
		k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		keys.add_child(k)
	var l := UiTheme.label(String(r["label"]), 22, UiPalette.TEXT, false, 0, false, 600)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	h.add_child(l)
	return h


static func _sep(t: String) -> Label:
	var s := UiTheme.label(t, 20, UiPalette.TEXT_MUTED, true, 0)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return s

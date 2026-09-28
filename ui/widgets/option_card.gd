class_name OptionCard
extends BaseButton
## Wide selectable card: medallion (icon or rune socket), title, tag chip, description and an
## optional price pill. Rarity colour tints the medallion ring and the left accent. Used by
## the draft, shop and event choices.
##
##   var c := OptionCard.make("Frost Rune", "Shows 1: target skips its next action.", "rune_frost")
##   c.set_rune("frost")         # rune socket instead of plain icon + rarity frame
##   c.set_price(50, can_afford)
##   c.selected = true

var selected := false:
	set(v):
		selected = v
		queue_redraw()
		if v and is_inside_tree():
			UiTheme.pop(self, 1.03, 0.2)
var accent: Color = UiPalette.GOLD
var sold := false
## Boss-tier look: gold double frame with a warm glow.
var premium := false:
	set(v):
		premium = v
		queue_redraw()
var _faces_row: HBoxContainer
var _hover := false
var _title: Label
var _tag: Label
var _tag_panel: PanelContainer
var _desc: Label
var _medal_holder: CenterContainer
var _price: PanelContainer
var _price_label: Label
var _right: Control
var _stamp: Label


static func make(title: String, desc: String, icon := "", icon_tint: Variant = null) -> OptionCard:
	var c := OptionCard.new()
	c._build(title, desc)
	if icon != "":
		c.set_icon(icon, icon_tint)
	else:
		c._medal_holder.visible = false
	return c


func _build(title: String, desc: String) -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var m := UiTheme.margin(null, 18, 14, 18, 14)
	UiTheme.full_rect(m)
	add_child(m)
	var row := UiTheme.hbox(18)
	m.add_child(row)
	_medal_holder = CenterContainer.new()
	_medal_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_medal_holder.custom_minimum_size = Vector2(84, 84)
	row.add_child(_medal_holder)
	var col := UiTheme.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	var tr := UiTheme.hbox(10)
	col.add_child(tr)
	_title = UiTheme.label(title, 30, UiPalette.TEXT, true, 0, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.add_child(_title)
	_tag_panel = PanelContainer.new()
	_tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tag_panel.visible = false
	tr.add_child(_tag_panel)
	_tag = UiTheme.label("", 16, UiPalette.TEXT, false, 0, false, 700)
	_tag_panel.add_child(_tag)
	_desc = UiTheme.para(desc, 22, UiPalette.TEXT_DIM, 500)
	col.add_child(_desc)
	_faces_row = UiTheme.hbox(5)
	_faces_row.visible = false
	col.add_child(_faces_row)
	_right = UiTheme.vbox(0)
	_right.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_right)
	_price = PanelContainer.new()
	_price.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(0.03, 0.03, 0.08, 0.8), 22, 2, UiPalette.GOLD_FAINT), 14, 6))
	_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_price.visible = false
	_right.add_child(_price)
	var pr := UiTheme.hbox(6)
	_price.add_child(pr)
	pr.add_child(UiIcons.rect("coin", 30))
	_price_label = UiTheme.label("0", 28, UiPalette.GOLD_BRIGHT, true, 0)
	pr.add_child(_price_label)
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())
	pressed.connect(func() -> void: UiTheme.sfx("page"))
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func set_icon(icon: String, tint: Variant = null) -> void:
	UiTheme.clear(_medal_holder)
	_medal_holder.visible = true
	var med := Medallion.make(icon, 80, tint, accent)
	_medal_holder.add_child(med)


func set_rune(rune: String) -> void:
	UiTheme.clear(_medal_holder)
	_medal_holder.visible = true
	_medal_holder.add_child(RuneBadge.make(rune, 80))
	var rarity := Runes.rarity(rune)
	set_tag(rarity.to_upper() + " RUNE", UiPalette.rarity_color(rarity))


## A die of `kind`: the medallion becomes a die (its best face, kind mark) and a row of
## all six faces appears under the description.
func set_die(kind: String, rune := "") -> void:
	UiTheme.clear(_medal_holder)
	_medal_holder.visible = true
	var faces := DiceKinds.faces(kind)
	var best := 0
	for v in faces:
		best = maxi(best, v)
	var big := DieFace.make(best, rune, false, 74)
	big.kind = kind
	_medal_holder.add_child(big)
	UiTheme.clear(_faces_row)
	for v in faces:
		var f := DieFace.make(v, rune, false, 34)
		f.kind = kind
		_faces_row.add_child(f)
	_faces_row.visible = true
	var rar := String(DiceKinds.def(kind).rarity)
	set_tag(rar.to_upper() + " DIE", UiPalette.kind_color(kind) if kind != "standard" else UiPalette.rarity_color(rar))


## A passive: rarity-ringed passive badge and a "<RARITY> PASSIVE" tag (boss tier: premium).
func set_passive(id: String) -> void:
	UiTheme.clear(_medal_holder)
	_medal_holder.visible = true
	_medal_holder.add_child(PassiveIcon.make(id, 80))
	var rar := Passives.rarity(id) if Passives.DEFS.has(id) else "common"
	set_tag(("BOSS" if rar == "boss" else rar.to_upper()) + " PASSIVE", UiPalette.passive_color(rar))
	premium = rar == "boss"


func set_tag(text: String, color: Color) -> void:
	accent = color
	_tag.text = text
	_tag.label_settings = UiTheme.label_settings(16, color.lightened(0.25), false, 0, UiPalette.OUTLINE, false, 700)
	_tag_panel.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(color, 0.16), 10, 2, Color(color, 0.55)), 10, 2))
	_tag_panel.visible = text != ""
	for c in _medal_holder.get_children():
		if c is Medallion:
			(c as Medallion).ring = color
			c.queue_redraw()
	queue_redraw()


func set_price(price: int, affordable: bool) -> void:
	_price.visible = true
	_price_label.text = str(price)
	_price_label.label_settings = UiTheme.label_settings(28, UiPalette.GOLD_BRIGHT if affordable else UiPalette.HP_BRIGHT, true, 0)


func set_sold(on: bool) -> void:
	sold = on
	disabled = on
	modulate = Color(1, 1, 1, 0.45) if on else Color.WHITE
	if on and _stamp == null:
		_stamp = UiTheme.label("SOLD", 30, UiPalette.HP_BRIGHT, true, 6)
		_price.visible = false
		_right.add_child(_stamp)
	queue_redraw()


func set_enabled(on: bool) -> void:
	disabled = not on
	modulate = Color.WHITE if on else Color(1, 1, 1, 0.5)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW


func _get_minimum_size() -> Vector2:
	return get_child(0).get_combined_minimum_size() if get_child_count() > 0 else Vector2(200, 100)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if premium:
		var gl := 0.35 + (0.25 if selected else 0.0)
		draw_style_box(UiTheme.box(Color(0, 0, 0, 0), 26, 0, Color.TRANSPARENT, 26, Color(1.0, 0.62, 0.15, gl), Vector2.ZERO), rect)
	if selected:
		draw_style_box(UiTheme.box(Color(0, 0, 0, 0), 24, 0, Color.TRANSPARENT, 20, Color(1.0, 0.72, 0.2, 0.5), Vector2.ZERO), rect)
	var bg := UiPalette.NAVY_2
	if selected:
		bg = UiPalette.NAVY_3
	elif _hover and not disabled:
		bg = UiPalette.NAVY_2.lightened(0.05)
	draw_style_box(UiTheme.box(UiPalette.OUTLINE, 26), rect.grow(2))
	draw_style_box(UiTheme.box(bg, 24, 0, Color.TRANSPARENT, 10, Color(0, 0, 0, 0.3), Vector2(0, 5)), rect)
	# top sheen
	var sheen := UiTheme.box(Color(1, 1, 1, 0.04), 24)
	sheen.corner_radius_bottom_left = 0
	sheen.corner_radius_bottom_right = 0
	draw_style_box(sheen, Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.45)))
	# accent edge
	if premium:
		# warm inner wash + gold double frame with corner studs
		var wash := UiTheme.box(Color(1.0, 0.6, 0.15, 0.08), 24)
		draw_style_box(wash, rect)
		var outer := UiTheme.box(Color.TRANSPARENT, 24, 3, UiPalette.GOLD_BRIGHT)
		outer.draw_center = false
		draw_style_box(outer, rect)
		var inner := UiTheme.box(Color.TRANSPARENT, 18, 2, Color(UiPalette.GOLD, 0.6))
		inner.draw_center = false
		draw_style_box(inner, rect.grow(-7))
		for p in [Vector2(14, 14), Vector2(rect.size.x - 14, 14), Vector2(14, rect.size.y - 14), Vector2(rect.size.x - 14, rect.size.y - 14)]:
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)]), UiPalette.GOLD_BRIGHT)
		return
	var edge := UiTheme.box(Color.TRANSPARENT, 24, 3 if not selected else 4, UiPalette.GOLD_BRIGHT if selected else Color(accent, 0.5))
	edge.draw_center = false
	draw_style_box(edge, rect)



class Medallion:
	extends Control
	var icon := ""
	var tint: Variant = null
	var ring: Color = UiPalette.GOLD

	static func make(p_icon: String, px: float, p_tint: Variant, p_ring: Color) -> Medallion:
		var m := Medallion.new()
		m.icon = p_icon
		m.tint = p_tint
		m.ring = p_ring
		m.custom_minimum_size = Vector2(px, px)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return m

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size * 0.5
		var r := s * 0.5
		draw_circle(c + Vector2(0, s * 0.05), r, Color(0, 0, 0, 0.35))
		draw_circle(c, r, UiPalette.OUTLINE)
		draw_circle(c, r - 2.0, ring.darkened(0.15))
		draw_arc(c, r - s * 0.1, PI * 1.1, PI * 1.9, 16, Color(1, 1, 1, 0.3), s * 0.04, true)
		var inner := r - s * 0.12
		draw_circle(c, inner, UiPalette.INK.lerp(ring, 0.12))
		draw_circle(c - Vector2(0, inner * 0.3), inner * 0.7, Color(1, 1, 1, 0.04))
		var gs := inner * 1.35
		var tex := UiIcons.tex(icon, int(s * 1.6), tint)
		draw_texture_rect(tex, Rect2(c - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false)

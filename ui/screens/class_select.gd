class_name ClassSelect
extends Control
## Class select: a turning 3D hero (HeroPortrait, in the equipped Wardrobe look and Armory
## items), a grid of class chips (11 classes), the class name, its mechanic badge with the rule,
## stats, the class's kit (equipped items with their tiers; the signature kit without a
## profile), the starting dice with their kinds (each die's six faces; the Pretend ★ is a star) and Start.
## With a profile (set_profile) locked classes show their unlock and the secret Monster Kid is
## a "???" mystery chip with only its hint; Start is disabled on them. Portrait stacks the
## preview over the info; landscape puts them side by side.
## Emits class_chosen(class_id), back_pressed.

signal class_chosen(class_id: String)
signal back_pressed

const TAGLINES := ClassInfo.TAGLINES

var selected := "knight"
var profile: Profile
var start_btn: GameButton
var back_btn: GameButton
var portrait: HeroPortrait
var _chips: Array[GameButton] = []
var _grid: GridContainer
var _info: VBoxContainer
var _name: Label
var _tagline: Label
var _detail: VBoxContainer
var _header: Label
var _panel: PanelContainer
var _scroll: ScrollContainer
var _bg: _Backdrop


func _init() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	_bg = _Backdrop.new()
	add_child(UiTheme.full_rect(_bg))
	portrait = HeroPortrait.new()
	portrait.zoom = 1.12
	add_child(portrait)
	_header = UiTheme.label("CHOOSE YOUR HERO", 44, UiPalette.GOLD_BRIGHT, true, 10, true)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_header)
	back_btn = GameButton.round_icon("arrow_left", 88)
	back_btn.kind = GameButton.Kind.GHOST
	back_btn.icon_tint = UiPalette.TEXT
	back_btn.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back_btn)

	_panel = UiTheme.panel("main")
	add_child(_panel)
	var outer := UiTheme.vbox(12)
	_panel.add_child(outer)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	outer.add_child(_grid)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_scroll)
	_info = UiTheme.vbox(12)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_info)
	_name = UiTheme.label("", 48, UiPalette.TEXT, true, 8, true)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_child(_name)
	_tagline = UiTheme.para("", 22, UiPalette.TEXT_DIM, 500)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_child(_tagline)
	_detail = UiTheme.vbox(12)
	_info.add_child(_detail)
	start_btn = GameButton.make("START RUN", "arrow_right", GameButton.Kind.PRIMARY, 44)
	start_btn.icon_tint = UiPalette.TEXT_DARK
	start_btn.min_height = 108
	start_btn.pressed.connect(func() -> void:
		if _open(selected):
			class_chosen.emit(selected))
	outer.add_child(start_btn)
	_build_chips()
	resized.connect(_layout)


func _ready() -> void:
	select(selected, false)
	_layout()


## Locks / secret state from a profile (null = every class open, the no-profile game).
func set_profile(p: Profile) -> void:
	profile = p
	_build_chips()
	if not _open(selected):
		selected = "knight"
	select(selected, false)


func _open(id: String) -> bool:
	return profile == null or profile.class_allowed(id)


func _build_chips() -> void:
	UiTheme.clear(_grid)
	_chips.clear()
	for id in HeroDefs.IDS:
		var open := _open(String(id))
		var secret := not open and ClassCard.is_secret(String(id))
		var label := "???" if secret else String(HeroDefs.DATA[id].name)
		var icon := "question" if secret else UiIcons.class_icon(String(id))
		var b := GameButton.make(label, icon, GameButton.Kind.SECONDARY, 18)
		b.toggle_mode = true
		b.toggle_primary = true
		b.pad_x = 6
		b.min_height = 76
		b.icon_px = 30
		b.icon_tint = UiPalette.class_color(String(id)) if open else UiPalette.TEXT_MUTED
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.x = 60
		if not open:
			b.modulate = Color(1, 1, 1, 0.7)
		b.pressed.connect(select.bind(String(id)))
		_grid.add_child(b)
		_chips.append(b)


func select(id: String, animate := true) -> void:
	selected = id
	var open := _open(id)
	var secret := not open and ClassCard.is_secret(id)
	for i in _chips.size():
		_chips[i].set_pressed_no_signal(HeroDefs.IDS[i] == id)
		_chips[i].call("_refresh")
	var def: Dictionary = HeroDefs.DATA[id]
	_name.text = "???" if secret else String(def.name)
	_name.label_settings = UiTheme.label_settings(48, UiPalette.class_color(id).lightened(0.25) if open else UiPalette.TEXT_MUTED, true, 8, UiPalette.OUTLINE, true)
	UiTheme.clear(_detail)
	if secret:
		_tagline.text = "A secret hero hides in the camp's stories."
		var c := CampUi.locked_card()
		var h := UiTheme.para(ClassCard.secret_hint(id), 24, Color("c9b6ea"), 600)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(h)
		_detail.add_child(c)
	else:
		_tagline.text = ClassInfo.tagline(id)
		if not open:
			var lc := CampUi.locked_card()
			lc.add_child(CampUi.lock_line(ClassCard.unlock_text(profile, id), 21))
			_detail.add_child(lc)
		_detail.add_child(ClassDetail.mechanic_badge(id, 20))
		_detail.add_child(ClassDetail.stats_row(id))
		_detail.add_child(UiModal.section_label("Kit"))
		var strip := KitStrip.of_profile(profile, id, 60) if profile != null and open else KitStrip.of_kit(id, 60)
		_detail.add_child(strip)
		var names := UiTheme.para(strip.names_text(), 18, UiPalette.TEXT_DIM, 600)
		names.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_detail.add_child(names)
		_detail.add_child(UiModal.section_label("Starting dice"))
		_detail.add_child(ClassDetail.dice_rows(id, 34))
	start_btn.set_enabled(open)
	var skin := profile.equipped_skin(id) if profile != null and open else "default"
	var pres := profile.prestige_on(id) if profile != null and open else false
	portrait.ring_color = UiPalette.class_color(id) if open else Color(0.4, 0.38, 0.55)
	portrait.set_hero(id, skin, pres, animate, ArmoryLook.of_profile(profile, id, skin, pres) if profile != null and open else {})
	portrait.silhouette = not open
	if animate:
		UiTheme.pop(_name, 1.1, 0.25)
		portrait.cheer()
	_layout.call_deferred()


func _layout() -> void:
	if size.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	var portrait_mode := UiTheme.is_portrait(size)
	back_btn.reset_size()
	back_btn.position = Vector2(safe.left, safe.top)
	_header.size = Vector2(size.x, 88)
	_header.position = Vector2(0, safe.top)
	_grid.columns = 4 if portrait_mode else 4
	_info.custom_minimum_size.x = 0
	var info_h := _info.get_combined_minimum_size().y
	if portrait_mode:
		var w := minf(UiTheme.MODAL_MAX_W, size.x - safe.left - safe.right)
		var top := safe.top + 90.0
		var avail := size.y - safe.bottom - top
		# the preview keeps at least a third of the height; the info scrolls beyond that
		var chrome := _grid.get_combined_minimum_size().y + start_btn.get_combined_minimum_size().y + 24.0 + 60.0
		var ph := minf(chrome + info_h, avail - maxf(avail * 0.3, 240.0))
		_scroll.custom_minimum_size = Vector2(0, maxf(160.0, ph - chrome))
		_panel.reset_size()
		_panel.size = Vector2(w, ph)
		_panel.position = Vector2((size.x - w) * 0.5, size.y - safe.bottom - ph)
		portrait.position = Vector2(0, top)
		portrait.size = Vector2(size.x, maxf(200.0, _panel.position.y - top + 20.0))
	else:
		var w := minf(UiTheme.MODAL_MAX_W, size.x * 0.5)
		var x := size.x * 0.5 + (size.x * 0.5 - w) * 0.3
		var top := safe.top + 96.0
		var avail := size.y - safe.bottom - top - 10.0
		var chrome := _grid.get_combined_minimum_size().y + start_btn.get_combined_minimum_size().y + 24.0 + 60.0
		var ph := minf(chrome + info_h, avail)
		_scroll.custom_minimum_size = Vector2(0, maxf(120.0, ph - chrome))
		_panel.reset_size()
		_panel.size = Vector2(w, ph)
		_panel.position = Vector2(x, top + (avail - ph) * 0.5)
		portrait.position = Vector2(size.x * 0.03, safe.top + 40.0)
		portrait.size = Vector2(size.x * 0.46, size.y - safe.top - safe.bottom - 40.0)
		_header.size = Vector2(w, 88)
		_header.position = Vector2(x, _panel.position.y - 96.0)


class _Backdrop:
	extends Control
	## Radial dusk gradient behind the class preview.
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0e0f24"))
		var c := Vector2(size.x * (0.5 if size.y > size.x else 0.26), size.y * 0.3)
		var r := maxf(size.x, size.y) * 0.62
		for i in 28:
			var k := float(i) / 28.0
			draw_circle(c, r * (1.0 - k), Color("2a2560").lerp(Color("5a3a7a"), k * k).darkened(0.1) * Color(1, 1, 1, 0.08 + k * 0.05))
		var g := Vector2(c.x, size.y * 0.3 + 60)
		for i in 10:
			draw_circle(g, 180.0 - i * 16.0, Color(1.0, 0.72, 0.3, 0.025))

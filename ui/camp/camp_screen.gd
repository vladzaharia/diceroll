class_name CampScreen
extends Control
## The Camp hub overlay, drawn over the 3D CampScene: the Crowns / Sigils header (always
## visible, also above the building screens), a floating label on each station (tap = open;
## locked stations show their unlock), the loadout summary and START RUN (opens the run setup),
## CONTINUE RUN when a run save exists, home and settings. Owns the Camp building screens.
##
##   camp.scene = camp_scene                 # for projecting station labels
##   camp.show_profile(profile, has_save)    # after every Camp command
##   camp.open_station("armory")
##
## Emits command(cmd) for Camp.apply(), start_run, home_pressed, continue_pressed,
## settings_pressed.

signal command(cmd: Array)
signal start_run
signal home_pressed
signal continue_pressed
signal settings_pressed

var scene: CampScene
var profile: Profile
var can_continue := false
var revealing := false
var _skip_hint: Label

var header: PanelContainer
var home_btn: GameButton
var settings_btn: GameButton
var start_btn: GameButton
var continue_btn: GameButton
var armory: ArmoryModal
var workshop: WorkshopModal
var pet_den: PetDenModal
var arcade: ArcadeModal
var setup: RunSetupModal
var wardrobe: WardrobeModal
## The Wardrobe entry in the bottom panel (red NEW dot while unseen skins wait).
var wardrobe_btn: GameButton
var _wardrobe_dot: Control
var welcome: WelcomeModal
var tags: Dictionary = {}

var _crowns_l: Label
var _sigils_l: Label
var _crowns := -1
var _sigils := -1
var _bottom: PanelContainer
var _loadout: HBoxContainer
var _tag_layer: Control
var _modals: Array[CampModal] = []


func _init() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var vg := _Shade.new()
	add_child(UiTheme.full_rect(vg))
	_tag_layer = Control.new()
	_tag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.full_rect(_tag_layer))
	for id in CampInfo.STATION_IDS:
		var t := StationTag.new()
		t.station = String(id)
		t.pressed.connect(open_station.bind(String(id)))
		_tag_layer.add_child(t)
		tags[id] = t
	# bottom: loadout summary + START RUN (+ CONTINUE RUN)
	_bottom = PanelContainer.new()
	_bottom.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(UiPalette.PANEL_SOFT, 30, 2, UiPalette.GOLD_FAINT, 18, Color(0, 0, 0, 0.45), Vector2(0, 6)), 18, 14))
	_bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bottom)
	var col := UiTheme.vbox(12)
	_bottom.add_child(col)
	_loadout = UiTheme.hbox(10)
	col.add_child(_loadout)
	var btns := UiTheme.hbox(12)
	col.add_child(btns)
	continue_btn = GameButton.make("CONTINUE", "arrow_right", GameButton.Kind.SECONDARY, 28)
	continue_btn.icon_tint = UiPalette.GOLD
	continue_btn.min_height = 100
	continue_btn.pressed.connect(func() -> void: continue_pressed.emit())
	btns.add_child(continue_btn)
	start_btn = GameButton.make("START RUN", "dice", GameButton.Kind.PRIMARY, 40)
	start_btn.min_height = 100
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.pressed.connect(func() -> void: open_station("setup"))
	btns.add_child(start_btn)
	# building screens
	armory = ArmoryModal.new()
	workshop = WorkshopModal.new()
	pet_den = PetDenModal.new()
	arcade = ArcadeModal.new()
	setup = RunSetupModal.new()
	wardrobe = WardrobeModal.new()
	_modals = [armory, workshop, pet_den, arcade, setup, wardrobe]
	for m in _modals:
		add_child(m)
		m.camp_command.connect(func(c: Array) -> void: command.emit(c))
		m.open_station.connect(func(id: String) -> void:
			m.close()
			open_station(id))
	setup.start_pressed.connect(func() -> void:
		setup.close()
		start_run.emit())
	welcome = WelcomeModal.new()
	add_child(welcome)
	# header (drawn above the building screens)
	header = PanelContainer.new()
	header.add_theme_stylebox_override("panel", UiTheme.panel_box("pill"))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	var hrow := UiTheme.hbox(22)
	header.add_child(hrow)
	var cr := CampUi.crowns(0, 30)
	_crowns_l = cr.get_child(1)
	hrow.add_child(cr)
	var sg := CampUi.sigils(0, 30)
	_sigils_l = sg.get_child(1)
	hrow.add_child(sg)
	home_btn = GameButton.round_icon("home", 76)
	home_btn.kind = GameButton.Kind.GHOST
	home_btn.icon_tint = UiPalette.TEXT
	home_btn.pressed.connect(func() -> void: home_pressed.emit())
	add_child(home_btn)
	settings_btn = GameButton.round_icon("gear", 76)
	settings_btn.kind = GameButton.Kind.GHOST
	settings_btn.icon_tint = UiPalette.GOLD
	settings_btn.pressed.connect(func() -> void: settings_pressed.emit())
	add_child(settings_btn)
	_skip_hint = UiTheme.label("TAP TO SKIP", 22, UiPalette.TEXT_DIM, false, 4, true, 700)
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint.visible = false
	add_child(_skip_hint)
	resized.connect(_layout)
	_bottom.minimum_size_changed.connect(_layout.call_deferred)


func _ready() -> void:
	_layout()


## Refreshes everything for `p` (header, tags, loadout, the open screen).
func show_profile(p: Profile, p_can_continue := false) -> void:
	profile = p
	can_continue = p_can_continue
	_set_currency(p.crowns, p.sigils)
	continue_btn.visible = can_continue
	start_btn.text = "NEW RUN" if can_continue else "START RUN"
	_build_loadout(p)
	var cat := Camp.new(p).catalog()
	for id in tags:
		var t: StationTag = tags[id]
		var st := CampInfo.station_state(p, String(id))
		t.set_state(bool(st.locked), String(st.text), _ready_count(cat, String(id)))
	for m in _modals:
		if m.visible and m.is_open():
			m.show_profile(p)
	_layout()


func open_station(id: String) -> void:
	if profile == null:
		return
	if id != "setup" and tags.has(id) and (tags[id] as StationTag).locked:
		UiTheme.sfx("error")
		UiTheme.pop(tags[id], 1.1, 0.25)
		return
	for m in _modals:
		if m.visible and m != modal(id):
			m.close()
	var m := modal(id)
	if m == null:
		return
	if scene and id != "setup":
		scene.bump(id)
	m.show_profile(profile)
	if not m.is_open():
		m.open()


func modal(id: String) -> CampModal:
	match id:
		"armory": return armory
		"workshop": return workshop
		"pet_den": return pet_den
		"arcade": return arcade
		"setup": return setup
		"wardrobe": return wardrobe
	return null


func any_open() -> bool:
	for m in _modals:
		if m.visible and m.is_open():
			return true
	return welcome.visible and welcome.is_open()


## While the camp plays its build-out reveal: the labels and the bottom panel step aside and a
## "tap to skip" hint shows.
func set_revealing(on: bool) -> void:
	revealing = on
	_bottom.visible = not on
	_skip_hint.visible = on
	for id in tags:
		(tags[id] as Control).visible = not on


func show_welcome() -> void:
	welcome.open()


func close_all() -> void:
	for m in _modals:
		if m.visible:
			m.close()
	if welcome.visible:
		welcome.close()


## Normalised free rects [portrait, landscape] between the header and the bottom panel,
## where the 3D camp is framed.
func free_rects() -> Array:
	var vs := size if size.x > 0.0 else get_viewport_rect().size
	var top := (header.position.y + header.size.y + 70.0) / maxf(vs.y, 1.0)
	var bottom := (_bottom.position.y - 8.0) / maxf(vs.y, 1.0)
	var r := Rect2(0.04, top, 0.92, maxf(0.2, bottom - top))
	return [r, Rect2(0.06, top, 0.88, maxf(0.2, bottom - top))]


func _ready_count(cat: Array, station: String) -> int:
	var tracks := {"armory": ["armory"], "workshop": ["workshop"], "pet_den": ["pet_den"], "arcade": ["arcade"]}
	var kinds := {"armory": ["gear"], "workshop": ["packs"], "pet_den": ["pets"], "arcade": ["minigames"]}
	var n := 0
	for item in cat:
		if not bool(item.affordable):
			continue
		# the Armory shop's items are a browse, not a nudge: ranks, the pouch and blueprints count
		if station == "armory" and String(item.kind) == "items":
			continue
		if (tracks[station] as Array).has(String(item.track)) or (String(item.track) == "sigils" and (kinds[station] as Array).has(String(item.kind))):
			n += 1
	return n


func _set_currency(c: int, s: int) -> void:
	for pair in [[_crowns_l, _crowns, c], [_sigils_l, _sigils, s]]:
		var l: Label = pair[0]
		var old: int = pair[1]
		var nv: int = pair[2]
		if old < 0 or not is_inside_tree() or old == nv:
			l.text = CampUi._num(nv)
			continue
		var tw := l.create_tween()
		tw.tween_method(func(v: float) -> void: l.text = CampUi._num(int(round(v))), float(old), float(nv), 0.45)
		UiTheme.pop(l.get_parent(), 1.15, 0.3)
	_crowns = c
	_sigils = s


func _build_loadout(p: Profile) -> void:
	UiTheme.clear(_loadout)
	var cls := String(p.loadout.get("class", "knight"))
	var med := OptionCard.Medallion.make(UiIcons.class_icon(cls), 58, null, UiPalette.GOLD)
	_loadout.add_child(med)
	var col := UiTheme.vbox(-2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_loadout.add_child(col)
	col.add_child(UiTheme.label(String(HeroDefs.DATA[cls].name) if HeroDefs.DATA.has(cls) else cls, 28, UiPalette.TEXT, true, 5))
	var mode := "SHORT ROAD" if String(p.loadout.get("mode", "standard")) == "short" else "STANDARD"
	var asc := int(p.ascension.get("selected", 0))
	var sub := mode + ("  ·  ASCENSION %d" % asc if asc > 0 else "")
	col.add_child(UiTheme.label(sub, 17, UiPalette.GOLD if asc == 0 else UiPalette.HP_BRIGHT, false, 0, false, 700))
	var pet := String(p.loadout.get("pet", ""))
	if pet != "":
		_loadout.add_child(_badge(String(CampInfo.PET_ICON.get(pet, "heart")), CampInfo.PET_COLOR.get(pet, UiPalette.GOLD), "L%d" % p.pet_level(pet)))
	for id in p.loadout.get("minigames", []):
		_loadout.add_child(_badge(String(CampInfo.MINIGAME_ICON.get(String(id), "star")), CampInfo.MINIGAME_COLOR.get(String(id), UiPalette.GOLD), ""))
	_loadout.add_child(_wardrobe_entry(p))


## The Wardrobe button (hanger), with a red dot while skins wait unseen.
func _wardrobe_entry(p: Profile) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(72, 72)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	wardrobe_btn = GameButton.round_icon("wardrobe", 72)
	wardrobe_btn.kind = GameButton.Kind.SECONDARY
	wardrobe_btn.icon_tint = Color("c79bff")
	wardrobe_btn.tooltip_text = "Wardrobe"
	wardrobe_btn.pressed.connect(open_station.bind("wardrobe"))
	holder.add_child(wardrobe_btn)
	_wardrobe_dot = WardrobeModal._Dot.new()
	_wardrobe_dot.size = Vector2(22, 22)
	_wardrobe_dot.position = Vector2(52, -2)
	_wardrobe_dot.visible = not (p.cosmetics.get("unseen", []) as Array).is_empty()
	holder.add_child(_wardrobe_dot)
	return holder


func _badge(icon: String, color: Color, text: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(52, 52)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var m := OptionCard.Medallion.make(icon, 52, color, color)
	holder.add_child(m)
	if text != "":
		var l := UiTheme.label(text, 15, UiPalette.TEXT, true, 4)
		l.position = Vector2(26, 32)
		holder.add_child(l)
	return holder


func _layout() -> void:
	if size.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	header.reset_size()
	var hs := header.get_combined_minimum_size()
	header.size = hs
	header.position = Vector2((size.x - hs.x) * 0.5, safe.top + 4.0)
	home_btn.reset_size()
	home_btn.position = Vector2(safe.left, safe.top - 2.0)
	settings_btn.reset_size()
	settings_btn.position = Vector2(size.x - safe.right - settings_btn.get_combined_minimum_size().x, safe.top - 2.0)
	_skip_hint.size = Vector2(size.x, 40)
	_skip_hint.position = Vector2(0, size.y - safe.bottom - 70)
	var w := minf(620.0, size.x - safe.left - safe.right)
	_bottom.reset_size()
	var bh := _bottom.get_combined_minimum_size().y
	_bottom.size = Vector2(w, bh)
	_bottom.position = Vector2((size.x - w) * 0.5, size.y - safe.bottom - bh)
	for m in _modals:
		m.top_inset = header.position.y + hs.y + 14.0 - safe.top
	if scene:
		var r := free_rects()
		scene.set_safe_rects(r[0], r[1])


func _process(_dt: float) -> void:
	if not visible or scene == null or not is_instance_valid(scene) or not scene.is_inside_tree():
		return
	var cam := scene.camera()
	var hide := any_open() or revealing
	scene.set_life_paused(any_open())
	for id in tags:
		var t: StationTag = tags[id]
		var w := scene.station_anchor(String(id))
		if cam.is_position_behind(w):
			t.visible = false
			continue
		var p := cam.unproject_position(w)
		t.reset_size()
		var ts := t.get_combined_minimum_size()
		t.size = ts
		var x := clampf(p.x - ts.x * 0.5, 8.0, size.x - ts.x - 8.0)
		var y := clampf(p.y - ts.y, header.position.y + header.size.y + 6.0, _bottom.position.y - ts.y - 6.0)
		t.position = Vector2(x, y)
		t.visible = true
		t.modulate.a = move_toward(t.modulate.a, 0.0 if hide else 1.0, 0.12)


## Soft dark gradient at the top and bottom so the header and panel read over the scene.
class _Shade:
	extends Control
	var _tex: Texture2D

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	var _bot: Texture2D

	func _draw() -> void:
		if _tex == null:
			var ink := Color(0.02, 0.02, 0.07)
			_tex = UiTheme.vgradient(Color(ink, 0.6), Color(ink, 0.0))
			_bot = UiTheme.vgradient(Color(ink, 0.0), Color(ink, 0.7))
		draw_texture_rect(_tex, Rect2(0, 0, size.x, size.y * 0.16), false)
		draw_texture_rect(_bot, Rect2(0, size.y * 0.72, size.x, size.y * 0.28), false)


## A station's floating label: medallion + name + status (locked text / purchases ready).
class StationTag:
	extends PanelContainer
	signal pressed
	var station := ""
	var locked := false
	var _name: Label
	var _sub: Label
	var _med: OptionCard.Medallion
	var _dot: PanelContainer
	var _dot_l: Label
	var _down := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _ready() -> void:
		var d: Dictionary = CampInfo.STATIONS[station]
		var row := UiTheme.hbox(10)
		add_child(row)
		_med = OptionCard.Medallion.make(String(d.icon), 50, d.color, d.color)
		_med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_med)
		var col := UiTheme.vbox(-4)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		_name = UiTheme.label(String(d.name), 24, UiPalette.TEXT, true, 5)
		col.add_child(_name)
		_sub = UiTheme.label(String(d.blurb), 16, UiPalette.TEXT_DIM, false, 0, false, 700)
		_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sub.custom_minimum_size.x = 150
		col.add_child(_sub)
		_dot = PanelContainer.new()
		_dot.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(UiPalette.HP, 14, 2, UiPalette.OUTLINE), 7, 1))
		_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dot_l = UiTheme.label("", 16, UiPalette.TEXT, false, 0, false, 800)
		_dot.add_child(_dot_l)
		_dot.visible = false
		# a plain Control holder: the PanelContainer would otherwise stretch the badge over the tag
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(holder)
		holder.add_child(_dot)
		_dot.position = Vector2(-2, -22)
		_style()

	func set_state(p_locked: bool, text: String, n_ready: int) -> void:
		if _name == null:
			await ready
		locked = p_locked
		var d: Dictionary = CampInfo.STATIONS[station]
		_sub.text = text if locked else (String(d.blurb) if n_ready == 0 else "%d ready to buy" % n_ready)
		_sub.label_settings = UiTheme.label_settings(16, UiPalette.TEXT_MUTED if locked else (UiPalette.HEAL if n_ready > 0 else UiPalette.TEXT_DIM), false, 0, UiPalette.OUTLINE, false, 700)
		_sub.custom_minimum_size.x = 170 if locked else 0
		_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if locked else TextServer.AUTOWRAP_OFF
		_name.label_settings = UiTheme.label_settings(24, UiPalette.TEXT_MUTED if locked else UiPalette.TEXT, true, 5)
		_med.icon = String(d.icon)
		_med.ring = UiPalette.TEXT_MUTED if locked else d.color
		_med.tint = UiPalette.TEXT_MUTED if locked else d.color
		_med.queue_redraw()
		_dot.visible = n_ready > 0 and not locked
		_dot_l.text = str(n_ready)
		_style()

	func _style() -> void:
		var d: Dictionary = CampInfo.STATIONS[station]
		var sb := UiTheme.box(Color(0.06, 0.06, 0.15, 0.88), 30, 2, Color(1, 1, 1, 0.1) if locked else Color(d.color, 0.7), 10, Color(0, 0, 0, 0.4), Vector2(0, 4))
		UiTheme.pad(sb, 10, 6)
		sb.content_margin_right = 18
		add_theme_stylebox_override("panel", sb)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_down = true
			accept_event()
		elif _down:
			_down = false
			accept_event()
			UiTheme.sfx("click")
			pressed.emit()


## First-launch welcome.
class WelcomeModal:
	extends UiModal

	func _build() -> void:
		set_title("WELCOME TO CAMP", UiPalette.GOLD)
		var t := UiTheme.para("This is home between runs. Every run pays Crowns, even a loss, and your firsts earn Sigils.", 24, UiPalette.TEXT, 500)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(t)
		var t2 := UiTheme.para("Spend them here: gear at the Armory, dice packs at the Workshop, pets in the Den, minigames at the Arcade. More opens up as you play.",
			21, UiPalette.TEXT_DIM, 500)
		t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(t2)
		var row := UiTheme.hbox(22)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		body.add_child(row)
		for id in CampInfo.STATION_IDS:
			var d: Dictionary = CampInfo.STATIONS[id]
			row.add_child(OptionCard.Medallion.make(String(d.icon), 64, d.color, d.color))
		var go := GameButton.make("LET'S GO", "arrow_right", GameButton.Kind.PRIMARY, 36)
		go.icon_tint = UiPalette.TEXT_DARK
		go.pressed.connect(func() -> void: close())
		body.add_child(go)

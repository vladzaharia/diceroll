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
var _skip_hint: Control

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
var _tag_layer: _TagLayer
## Stations' "ready to buy" counts (shown inside the station screen, not on the tag).
var _ready_n: Dictionary = {}
## Tags in compact mode (smaller medallion and name) when the free band is short or crowded.
var _compact := false
## Seconds a Camp toast holds before it rises away (scenarios raise it for screenshots).
var toast_hold := 1.3
var _modals: Array[CampModal] = []


func _init() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var vg := _Shade.new()
	add_child(UiTheme.full_rect(vg))
	_tag_layer = _TagLayer.new()
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
	_bottom.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.panel_box("hud") if UiTheme.skinned("panel_hud") \
		else UiTheme.box(UiPalette.PANEL_SOFT, 30, 2, UiPalette.GOLD_FAINT, 18, Color(0, 0, 0, 0.45), Vector2(0, 6)), 18, 14))
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
	var cr := _amount("crown", CampUi.CROWN_COLOR)
	_crowns_l = cr.get_child(1)
	hrow.add_child(cr)
	var sg := _amount("sigil", CampUi.SIGIL_COLOR)
	_sigils_l = sg.get_child(1)
	hrow.add_child(sg)
	home_btn = GameButton.round_icon("home", 84)
	home_btn.kind = GameButton.Kind.GHOST
	home_btn.icon_tint = UiPalette.TEXT
	home_btn.pressed.connect(func() -> void: home_pressed.emit())
	add_child(home_btn)
	settings_btn = GameButton.round_icon("gear", 84)
	settings_btn.kind = GameButton.Kind.GHOST
	settings_btn.icon_tint = UiPalette.GOLD
	settings_btn.pressed.connect(func() -> void: settings_pressed.emit())
	add_child(settings_btn)
	_skip_hint = _SkipHint.new()
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
		_ready_n[id] = _ready_count(cat, String(id))
		t.lock_text = String(st.text)
		t.set_state(bool(st.locked), String(st.text), int(_ready_n[id]))
	for id in _ready_n:
		var sm := modal(String(id))
		if sm:
			sm.ready_count = int(_ready_n[id])
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
		# the unlock condition, as tap feedback (the tag itself only shows the padlock)
		var t: StationTag = tags[id]
		toast("%s: %s" % [String(CampInfo.STATIONS[id].name), t.lock_text], "lock", UiPalette.TEXT, "info")
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


## Top edge (canvas px) for Camp toasts: just above the bottom panel (or the screen's lower
## third while a station screen covers it).
func toast_y() -> float:
	var vs := size if size.x > 0.0 else get_viewport_rect().size
	if any_open() or not _bottom.visible:
		return vs.y * 0.7
	return maxf(vs.y * 0.3, _bottom.position.y - 100.0)


## A Camp toast (the shared Toast helper) above the bottom panel, drawn over the Camp's
## shading and its station screens.
func toast(text: String, icon := "", color: Color = UiPalette.TEXT, rim: Variant = null) -> PanelContainer:
	var o := {"y": toast_y(), "step": -70.0, "font": 26, "hold": toast_hold}
	if rim != null:
		o["rim"] = rim
	return Toast.show(self, text, icon, color, o)


## A currency counter: the pack icon (crown / purple sigil gem, full colour) + the amount.
func _amount(icon: String, legacy_tint: Color) -> HBoxContainer:
	var row := UiTheme.hbox(6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(CampArt.icon(icon, 34, legacy_tint))
	row.add_child(UiTheme.label("0", 30, UiPalette.TEXT, true, 5))
	return row


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
	var med := CampArt.medal(Icons.class_icon(cls), 58, UiPalette.class_color(cls))
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
		_loadout.add_child(_badge(String(CampInfo.PET_GLYPH.get(pet, "station_pet_den")), CampInfo.PET_COLOR.get(pet, UiPalette.GOLD), "L%d" % p.pet_level(pet)))
	for id in p.loadout.get("minigames", []):
		_loadout.add_child(_badge(String(CampInfo.MINIGAME_GLYPH.get(String(id), "station_arcade")), CampInfo.MINIGAME_COLOR.get(String(id), UiPalette.GOLD), ""))
	_loadout.add_child(_wardrobe_entry(p))


## The Wardrobe button (the hat), with a red NEW dot inside its corner while skins wait unseen.
func _wardrobe_entry(p: Profile) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(80, 80)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	wardrobe_btn = GameButton.round_icon(CampArt.resolve(String(CampInfo.STATION_ICON.wardrobe)), 80)
	wardrobe_btn.kind = GameButton.Kind.GHOST
	wardrobe_btn.icon_tint = Color("c79bff")
	wardrobe_btn.tooltip_text = "Wardrobe"
	wardrobe_btn.pressed.connect(open_station.bind("wardrobe"))
	holder.add_child(wardrobe_btn)
	_wardrobe_dot = CampArt.pin(CampArt.new_dot(20), "tr", 6.0)
	_wardrobe_dot.visible = not (p.cosmetics.get("unseen", []) as Array).is_empty()
	holder.add_child(_wardrobe_dot)
	return holder


func _badge(icon: String, color: Color, text: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(52, 52)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var m := CampArt.medal(icon, 52, color)
	holder.add_child(m)
	if text != "":
		# the level sits inside the badge's lower-right corner
		var l := UiTheme.label(text, 16, UiPalette.TEXT, true, 4)
		holder.add_child(CampArt.pin(l, "br", 0.0))
	return holder


func _layout() -> void:
	if size.x <= 0.0:
		return
	var safe := UiTheme.safe_margins(self)
	header.reset_size()
	var hs := header.get_combined_minimum_size()
	header.size = hs
	home_btn.reset_size()
	var bh0 := home_btn.get_combined_minimum_size().y
	var top := safe.top + 4.0
	header.position = Vector2((size.x - hs.x) * 0.5, top + maxf(0.0, (bh0 - hs.y) * 0.5))
	home_btn.position = Vector2(safe.left, top)
	settings_btn.reset_size()
	settings_btn.position = Vector2(size.x - safe.right - settings_btn.get_combined_minimum_size().x, top)
	_skip_hint.reset_size()
	var sk := _skip_hint.get_combined_minimum_size()
	_skip_hint.size = sk
	_skip_hint.position = Vector2((size.x - sk.x) * 0.5, size.y - safe.bottom - sk.y - 24.0)
	var w := minf(620.0, size.x - safe.left - safe.right)
	_bottom.reset_size()
	var bh := _bottom.get_combined_minimum_size().y
	_bottom.size = Vector2(w, bh)
	_bottom.position = Vector2((size.x - w) * 0.5, size.y - safe.bottom - bh)
	for m in _modals:
		m.top_inset = header.position.y + hs.y + 14.0 - safe.top
	# short free band (Duo outer, landscape phones): compact tags from the start
	_compact = (_bottom.position.y - _top_limit()) < 800.0
	for id in tags:
		(tags[id] as StationTag).set_compact(_compact)
	if scene:
		var r := free_rects()
		scene.set_safe_rects(r[0], r[1])


## Lowest edge of the top chrome (header pill, Home and Settings) plus a gap: tags stay below it.
func _top_limit() -> float:
	var y := header.position.y + header.size.y
	for b: Control in [home_btn, settings_btn]:
		y = maxf(y, b.position.y + b.get_combined_minimum_size().y)
	return y + 10.0


func _process(_dt: float) -> void:
	if not visible or scene == null or not is_instance_valid(scene) or not scene.is_inside_tree():
		return
	var cam := scene.camera()
	var hide := any_open() or revealing
	scene.set_life_paused(any_open())
	var safe := UiTheme.safe_margins(self)
	var band_top := _top_limit()
	var band_bot := (_bottom.position.y if _bottom.visible else size.y - safe.bottom) - 10.0
	var lo_x := safe.left + 8.0
	var hi_x := size.x - safe.right - 8.0
	var items: Array = []
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
		items.append({"t": t, "anchor": p, "r": _clamp_rect(Rect2(p.x - ts.x * 0.5, p.y - ts.y, ts.x, ts.y), lo_x, hi_x, band_top, band_bot)})
	var clear := _relax(items, lo_x, hi_x, band_top, band_bot)
	if not clear and not _compact:
		# the tags don't fit side by side at full size: go compact (for this layout)
		_compact = true
		for id in tags:
			(tags[id] as StationTag).set_compact(true)
	var stems: Array = []
	for it in items:
		var t: StationTag = it.t
		var r: Rect2 = it.r
		t.position = r.position
		t.visible = true
		t.modulate.a = move_toward(t.modulate.a, 0.0 if hide else 1.0, 0.12)
		# displaced from its station: a short stem back to the anchor (when the anchor is in view)
		var a: Vector2 = it.anchor
		var foot := Vector2(clampf(a.x, r.position.x + 24.0, r.end.x - 24.0), r.end.y)
		if foot.distance_to(a) > 24.0 and a.y > r.end.y and a.y < band_bot and a.x > lo_x and a.x < hi_x:
			stems.append([foot, a, t.rim_color(), t.modulate.a])
	_tag_layer.stems = stems
	_tag_layer.queue_redraw()


static func _clamp_rect(r: Rect2, lo_x: float, hi_x: float, top: float, bot: float) -> Rect2:
	r.position.x = clampf(r.position.x, lo_x, maxf(lo_x, hi_x - r.size.x))
	r.position.y = clampf(r.position.y, top, maxf(top, bot - r.size.y))
	return r


## Pushes overlapping tag rects apart (along the axis of least overlap), inside the band.
## Returns false when some still overlap.
static func _relax(items: Array, lo_x: float, hi_x: float, top: float, bot: float) -> bool:
	const GAP := 8.0
	for _i in 8:
		var moved := false
		items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.r as Rect2).position.y < (b.r as Rect2).position.y)
		for i in items.size():
			for j in range(i + 1, items.size()):
				var a: Rect2 = items[i].r
				var b: Rect2 = items[j].r
				if not a.grow(GAP * 0.5).intersects(b.grow(GAP * 0.5)):
					continue
				var ox := minf(a.end.x, b.end.x) - maxf(a.position.x, b.position.x) + GAP
				var oy := minf(a.end.y, b.end.y) - maxf(a.position.y, b.position.y) + GAP
				if oy <= ox:
					a.position.y -= oy * 0.5
					b.position.y += oy * 0.5
				else:
					var s := ox * 0.5 * (1.0 if a.get_center().x <= b.get_center().x else -1.0)
					a.position.x -= s
					b.position.x += s
				items[i].r = _clamp_rect(a, lo_x, hi_x, top, bot)
				items[j].r = _clamp_rect(b, lo_x, hi_x, top, bot)
				moved = true
		if not moved:
			return true
	for i in items.size():
		for j in range(i + 1, items.size()):
			if (items[i].r as Rect2).intersects(items[j].r as Rect2):
				return false
	return true


## The tag layer: draws the stems from displaced tags to their stations.
class _TagLayer:
	extends Control
	var stems: Array = []

	func _draw() -> void:
		for s in stems:
			var a: Vector2 = s[0]
			var b: Vector2 = s[1]
			var al := float(s[3])
			draw_line(a, b, Color(UiPalette.OUTLINE, 0.8 * al), 6.0, true)
			draw_line(a, b, Color(s[2] as Color, 0.9 * al), 3.0, true)
			draw_circle(b, 6.0, Color(UiPalette.OUTLINE, 0.8 * al))
			draw_circle(b, 4.0, Color(s[2] as Color, al))


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
		draw_texture_rect(_tex, Rect2(0, 0, size.x, size.y * 0.2), false)
		draw_texture_rect(_bot, Rect2(0, size.y * 0.72, size.x, size.y * 0.28), false)




## "TAP TO SKIP" during the build-out reveal: a pill with the skip glyph.
class _SkipHint:
	extends PanelContainer

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_stylebox_override("panel", UiTheme.panel_box("pill"))
		var row := UiTheme.hbox(8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(row)
		row.add_child(CampArt.icon("skip", 26, UiPalette.TEXT_DIM))
		row.add_child(UiTheme.label("TAP TO SKIP", 22, UiPalette.TEXT_DIM, false, 0, false, 700))


## A station's floating tag: the station medallion + name; a count badge (1-3, a dot above)
## or a padlock sits inside its right end. The unlock condition shows as a toast on tap and
## the "N ready to buy" line lives inside the station screen.
class StationTag:
	extends PanelContainer
	signal pressed
	var station := ""
	var locked := false
	## The unlock condition (tap feedback while locked).
	var lock_text := ""
	var compact := false
	var _name: Label
	var _med: OptionCard.Medallion
	var _end: HBoxContainer
	var _n := 0
	var _down := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _ready() -> void:
		var d: Dictionary = CampInfo.STATIONS[station]
		var row := UiTheme.hbox(10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(row)
		_med = CampArt.medal(String(CampInfo.STATION_ICON[station]), 50, d.color)
		_med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_med)
		_name = UiTheme.label(String(d.name), 26, UiPalette.TEXT, true, 5)
		_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_name)
		_end = UiTheme.hbox(0)
		_end.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_end)
		_apply()

	func set_state(p_locked: bool, text: String, n_ready: int) -> void:
		locked = p_locked
		lock_text = text
		_n = n_ready
		tooltip_text = text if locked else ""
		if _name != null:
			_apply()

	func set_compact(on: bool) -> void:
		if compact == on:
			return
		compact = on
		if _name != null:
			_apply()

	func rim_color() -> Color:
		return UiPalette.TEXT_MUTED if locked else Color(CampInfo.STATIONS[station].color)

	## The ready count on the tag (0 = none); tests read it.
	func ready_count() -> int:
		return 0 if locked else _n

	func _apply() -> void:
		var d: Dictionary = CampInfo.STATIONS[station]
		var px := 40.0 if compact else 50.0
		_med.custom_minimum_size = Vector2(px, px)
		_med.saturation = 0.0 if locked else 1.0
		_med.ring = d.color
		_med.icon = CampArt.resolve(String(CampInfo.STATION_ICON[station]))
		_med.tint = UiPalette.TEXT_MUTED if locked else d.color
		_med.queue_redraw()
		_name.label_settings = UiTheme.label_settings(21 if compact else 26, UiPalette.TEXT_DIM if locked else UiPalette.TEXT, true, 5)
		for c in _end.get_children():
			_end.remove_child(c)
			c.queue_free()
		if locked:
			_end.add_child(CampArt.lock_icon(22 if compact else 26))
		elif _n > 0:
			_end.add_child(CampArt.count_badge(_n))
		_end.visible = _end.get_child_count() > 0
		var sb := UiTheme.tag_box(rim_color())
		if compact:
			sb.content_margin_top = 5
			sb.content_margin_bottom = 5
			sb.content_margin_left = 8
			sb.content_margin_right = 12
		else:
			sb.content_margin_left = 10
			sb.content_margin_right = 16
		add_theme_stylebox_override("panel", sb)
		reset_size()

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


## First-launch welcome (forced: LET'S GO is its only exit; Enter presses it).
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
			row.add_child(CampArt.medal(String(CampInfo.STATION_ICON[id]), 64, d.color))
		var go := GameButton.make("LET'S GO", "arrow_right", GameButton.Kind.PRIMARY, 36)
		go.icon_tint = UiPalette.TEXT_DARK
		go.pressed.connect(func() -> void: close())
		body.add_child(go)
		primary_action = go

extends "res://tests/test_case.gd"
## NEW RUN window (docs/design/2026-10-01-new-run-window.md): two columns on wide canvases and
## one on phones, START RUN in the footer outside the scroll (Enter), the hero / Ascension keys,
## locked heroes and biomes that show their unlock hint, loadout tiles that open their stations
## and the icons it draws.


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	return k


func _mid() -> Profile:
	return Profile.from_dict(MetaPresets.get_preset("mid"))


func _modal(p: Profile, view := Vector2(720, 1280)) -> RunSetupModal:
	var rs := RunSetupModal.new()
	rs.size = view
	rs.show_profile(p)
	rs.show_now()
	return rs


func _done(rs: RunSetupModal) -> void:
	rs.free()
	Character.clear_cache()


func _names(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		out.append(String(c.name))
	return out


func test_wide_canvas_has_two_columns_in_order() -> void:
	var rs := _modal(_mid(), Vector2(2000, 1280))
	assert_true(rs.wide, "a 2000-wide canvas lays out wide")
	assert_eq(rs.max_width, RunSetupModal.WIDE_W, "the wide panel width")
	var cols := rs.body.find_child("Columns", false, false)
	assert_true(cols != null and cols.get_child_count() == 2, "two columns")
	assert_eq(_names(cols.get_child(0)), ["Hero"], "left: the hero")
	assert_eq(_names(cols.get_child(1)), ["Route", "Loadout"], "right: route, then loadout")
	_done(rs)


func test_phone_canvas_is_one_column_in_order() -> void:
	var rs := _modal(_mid())
	assert_true(not rs.wide, "720 wide is the phone layout")
	assert_eq(rs.max_width, RunSetupModal.NARROW_W, "the phone panel width")
	assert_true(rs.body.find_child("Columns", false, false) == null, "no columns")
	assert_eq(_names(rs.body), ["Hero", "Route", "Loadout"], "hero, route, loadout top to bottom")
	for s in ["Section_Hero", "Section_Route", "Section_Loadout"]:
		assert_true(rs.body.find_child(s, true, false) != null, "section header %s" % s)
	_done(rs)


func test_start_run_sits_in_the_footer_and_enter_starts() -> void:
	var p := _mid()
	p.ascension = {"unlocked": 3, "selected": 2}
	p.loadout["mode"] = "short"
	var rs := _modal(p)
	var go := rs.start_button
	assert_true(rs.primary_action == go, "START RUN is the primary action")
	assert_true(not rs._scroll.is_ancestor_of(go), "START RUN is outside the scroll (never scrolls away)")
	assert_true(rs.panel.is_ancestor_of(go), "inside the panel (no spill)")
	assert_true(go.text == "START RUN" and go.kind == GameButton.Kind.PRIMARY, "primary START RUN")
	assert_eq(go.shortcut_hint, "key_enter", "Enter keycap (hover only)")
	assert_true(go.sub_text.contains("Knight") and go.sub_text.contains("Short Road") and go.sub_text.contains("Ascension 2"),
		"the summary under START RUN: %s" % go.sub_text)
	var started := [0]
	rs.start_pressed.connect(func() -> void: started[0] += 1)
	rs._input(_key(KEY_ENTER))
	assert_eq(started[0], 1, "Enter starts the run")
	assert_true(rs.dismissible and rs.close_button != null, "the corner x is the one exit")
	rs._input(_key(KEY_ESCAPE))
	assert_true(not rs.is_open(), "Esc closes")
	_done(rs)


func test_no_bottom_close_button() -> void:
	var rs := _modal(_mid(), Vector2(2000, 1280))
	for b in rs.find_children("*", "GameButton", true, false):
		var t := String((b as GameButton).text).to_upper()
		assert_true(not t in ["CLOSE", "DONE", "BACK", "CANCEL"], "no exit-only button (%s)" % t)
	_done(rs)


func test_arrow_keys_switch_hero_and_ascension() -> void:
	var p := _mid()
	p.ascension = {"unlocked": 3, "selected": 1}
	var rs := _modal(p)
	var got: Array = []
	rs.camp_command.connect(func(c: Array) -> void: got.append(c))
	var open: Array = []
	for id in HeroDefs.IDS:
		if p.class_allowed(String(id)):
			open.append(String(id))
	assert_true(open.size() >= 2, "mid profile has several heroes")
	rs._input(_key(KEY_RIGHT))
	assert_eq(got.back(), ["set_class", open[1]], "-> = next unlocked hero")
	rs._input(_key(KEY_LEFT))
	assert_eq(got.back(), ["set_class", open.back()], "<- from the first wraps to the last")
	rs._input(_key(KEY_UP))
	assert_eq(got.back(), ["set_ascension", 2], "up = Ascension +1")
	rs._input(_key(KEY_DOWN))
	assert_eq(got.back(), ["set_ascension", 0], "down = Ascension -1")
	got.clear()
	p.ascension.selected = 3
	rs.show_profile(p)
	rs._input(_key(KEY_UP))
	assert_true(got.is_empty(), "no level above the unlocked one")
	_done(rs)


func test_locked_hero_shows_its_unlock_hint() -> void:
	var p := _mid()
	var rs := _modal(p)
	var got: Array = []
	rs.camp_command.connect(func(c: Array) -> void: got.append(c))
	var locked := ""
	for id in HeroDefs.IDS:
		if not p.class_allowed(String(id)) and not ClassCard.is_secret(String(id)):
			locked = String(id)
			break
	assert_true(locked != "", "mid has a locked hero")
	var tile: RunSetupModal.HeroTile = rs.body.find_child("Hero_" + locked, true, false)
	assert_true(tile != null and not tile.enabled, "locked tile is greyed / not selectable")
	tile.activate()
	assert_true(got.is_empty(), "a locked hero is never picked")
	var hint: Label = rs._class_hint
	assert_true(hint.text.begins_with(String(HeroDefs.DATA[locked].name) + ":"), "its unlock hint shows: %s" % hint.text)
	assert_true(hint.text.contains(ClassCard.unlock_text(p, locked)), "the milestone text")
	var sel: RunSetupModal.HeroTile = rs.body.find_child("Hero_knight", true, false)
	assert_true(sel.selected, "the current hero is selected")
	sel.activate()
	assert_true(got.is_empty(), "re-picking the selected hero sends nothing")
	var other: RunSetupModal.HeroTile = rs.body.find_child("Hero_barbarian", true, false)
	if other.enabled:
		other.activate()
		assert_eq(got.back(), ["set_class", "barbarian"], "an open hero is picked")
	_done(rs)


func test_secret_hero_stays_a_mystery() -> void:
	var p := _mid()
	if p.class_allowed("monster_kid"):
		return
	var rs := _modal(p)
	var tile: RunSetupModal.HeroTile = rs.body.find_child("Hero_monster_kid", true, false)
	assert_eq(tile.state, ClassCard.State.SECRET, "the Monster Kid is a secret")
	var texts: Array = []
	for l in tile.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	assert_true(texts.has("???") and not texts.has(String(HeroDefs.DATA.monster_kid.name)), "never its name")
	_done(rs)


func test_locked_biomes_are_greyed_with_a_hint() -> void:
	var rs := _modal(Profile.fresh(), Vector2(2000, 1280))
	var chips := rs.body.find_children("Biome_*", "", true, false)
	assert_eq(chips.size(), 10, "standard: every biome of the three stages")
	var locked := 0
	for c in chips:
		if not (c as RunSetupModal.BiomeChip).owned:
			locked += 1
	assert_true(locked > 0, "a fresh profile has locked biomes")
	assert_true(rs._biome_hint != null and rs._biome_hint.text.contains(":"), "the first locked biome's hint shows")
	var crypt: RunSetupModal.BiomeChip = rs.body.find_child("Biome_crypt", true, false)
	crypt.peeked.emit()
	assert_true(rs._biome_hint.text.begins_with(BiomeDefs.name_of("crypt")), "peeking a biome shows its hint")
	_done(rs)


func test_short_road_pool_has_two_stages() -> void:
	var p := _mid()
	p.loadout["mode"] = "short"
	var rs := _modal(p)
	var pool := rs.body.find_child("Pool", true, false)
	assert_eq(pool.get_child_count(), 2, "stage 1 and stage 2")
	var mc: RunSetupModal.ModeCard = rs.body.find_child("Mode_short", true, false)
	assert_true(mc.selected, "Short Road selected")
	_done(rs)


func test_loadout_tiles_open_their_stations() -> void:
	var rs := _modal(_mid())
	var got: Array = []
	rs.open_station.connect(func(id: String) -> void: got.append(id))
	for pair in [["Tile_pet", "pet_den"], ["Tile_minigames", "arcade"], ["Tile_potions", "armory"], ["Tile_dice", "workshop"]]:
		var t: RunSetupModal.LoadoutTile = rs.body.find_child(String(pair[0]), true, false)
		assert_true(t != null, "tile %s" % pair[0])
		t.activate()
		assert_eq(got.back(), pair[1], "%s opens %s" % pair)
	_done(rs)


func test_locked_station_tile_does_nothing() -> void:
	var rs := _modal(Profile.fresh())
	var got: Array = []
	rs.open_station.connect(func(id: String) -> void: got.append(id))
	var t: RunSetupModal.LoadoutTile = rs.body.find_child("Tile_pet", true, false)
	assert_true(not t.enabled, "the Pet Den is locked on a fresh profile")
	t.activate()
	assert_true(got.is_empty(), "a locked tile opens nothing")
	_done(rs)


func test_ascension_locked_then_rules_stack() -> void:
	var rs := _modal(Profile.fresh())
	var asc := rs.body.find_child("Ascension", true, false)
	assert_true(asc != null and asc.find_child("AscUp", true, false) == null, "locked before the first win: no steppers")
	_done(rs)
	var p := _mid()
	p.ascension = {"unlocked": 5, "selected": 4}
	rs = _modal(p)
	var rules := rs.body.find_child("Rules", true, false)
	assert_eq(rules.get_child_count(), 4, "levels 1..4 stack")
	var up: GameButton = rs.body.find_child("AscUp", true, false)
	var down: GameButton = rs.body.find_child("AscDown", true, false)
	assert_true(not up.disabled and not down.disabled, "both steppers usable mid-ladder")
	assert_eq(up.shortcut_hint, "key_up", "up key in the + tooltip")
	_done(rs)


func test_tap_targets_and_text_sizes() -> void:
	var rs := _modal(_mid())
	# round buttons (Armory, Ascension steppers) draw at 64 px inside GameButton's 88 px hit
	# rect (tests/test_ui_reskin_a.gd covers that rule)
	for t in rs.body.find_children("Hero_*", "", true, false):
		assert_true((t as Control).custom_minimum_size.y >= UiTheme.TOUCH, "hero tile >= 88 px tall (44 pt)")
	for n in ["Tile_pet", "Tile_minigames", "Tile_potions", "Tile_dice", "Mode_standard", "Mode_short"]:
		var c: Control = rs.body.find_child(n, true, false)
		assert_true(c.custom_minimum_size.y >= UiTheme.TOUCH, "%s >= 88 px tall" % n)
	for l in rs.find_children("*", "Label", true, false):
		var lab := l as Label
		if lab.label_settings != null and lab.text != "":
			assert_true(lab.label_settings.font_size >= 16, "text >= 16 px: '%s' (%d)" % [lab.text, lab.label_settings.font_size])
	_done(rs)


func test_run_setup_icons_are_mapped() -> void:
	var map: Dictionary = Icons.load_map_file(Icons.MAP_PATH)
	for id in ["helmet", "flag", "pouch", "speed", "hourglass", "biome_glade", "crown", "minus", "plus", "ascension",
			"chevron_right", "potion_healing", "lock", "check", "heart", "sword", "reroll", "dice", "question", "station_armory"]:
		assert_true(map.has(id), "icon_map has %s" % id)

extends "res://tests/test_case.gd"
## UI reskin slice (d): every Camp icon id is in ui/icons/icon_map.json (and distinct where the
## screen needs it: 12 pets, 8 packs), CampArt falls back to a drawn glyph without the pack,
## the station tag's count policy, and the Camp modals' Enter / Esc paths.


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	return k


func _mid() -> Profile:
	return Profile.from_dict(MetaPresets.get_preset("mid"))


## Every pack id the Camp screens draw.
func _camp_ids() -> Array:
	var ids: Array = []
	for d: Dictionary in [CampInfo.STATION_ICON, CampInfo.PET_GLYPH, CampInfo.MINIGAME_GLYPH, CampInfo.PACK_ICON,
			CampInfo.SLOT_GLYPH, CampInfo.GROUP_GLYPH, CampInfo.UPGRADE_ICON]:
		for v in d.values():
			ids.append(String(v))
	for t in [1, 2, 3]:
		ids.append(String(CampArt.TIER_ICON[t]))
	ids.append_array(["crown", "sigil", "home", "gear", "skip", "lock", "unlock", "look_hidden", "bad_fit", "blueprint",
		"craft", "kit", "pet_charge", "pet_xp", "rank", "skin_prestige", "trophy_gold", "plus", "flag", "star", "pack", "boss"])
	for k in DiceKinds.IDS:
		ids.append("kind_" + String(k))
	return ids


func test_every_camp_icon_id_is_mapped() -> void:
	var map: Dictionary = Icons.load_map_file(Icons.MAP_PATH)
	assert_true(not map.is_empty(), "icon map readable")
	for id in _camp_ids():
		assert_true(map.has(id) and String((map[id] as Dictionary).get("svg", "")) != "", "icon_map has %s" % id)
	# the pet portraits stay unmapped (in-run HUD art); the Camp uses the petg_* glyphs
	for pet in PetDefs.IDS:
		assert_true(not map.has("pet_" + String(pet)), "pet_%s stays a portrait" % pet)


func test_camp_icon_sets_cover_the_content_and_are_distinct() -> void:
	assert_eq(CampInfo.PET_GLYPH.size(), PetDefs.IDS.size(), "a glyph per pet")
	for pet in PetDefs.IDS:
		assert_true(CampInfo.PET_GLYPH.has(pet), "pet glyph " + String(pet))
		assert_true(CampInfo.PET_COLOR.has(pet), "pet colour " + String(pet))
	assert_eq(_unique(CampInfo.PET_GLYPH.values()), PetDefs.IDS.size(), "12 distinct pet glyphs (no heart fallback)")
	for mg in MinigameDefs.IDS:
		assert_true(CampInfo.MINIGAME_GLYPH.has(mg), "minigame glyph " + String(mg))
	for pk in UnlockDefs.PACK_IDS:
		assert_true(CampInfo.PACK_ICON.has(pk), "pack icon " + String(pk))
	assert_eq(_unique(CampInfo.PACK_ICON.values()), UnlockDefs.PACK_IDS.size(), "8 distinct pack icons")
	assert_eq(String(CampInfo.STATION_ICON.armory), "station_armory", "the Armory is the anvil station")
	assert_eq(String(CampInfo.STATION_ICON.wardrobe), "wardrobe_hats", "the Wardrobe is the hat")


func test_glyph_of_every_unlock_is_mapped() -> void:
	var map: Dictionary = Icons.load_map_file(Icons.MAP_PATH)
	for m in UnlockDefs.MILESTONES:
		for u in m.unlocks:
			var g := CampInfo.glyph_of(String(u[0]), String(u[1]))
			assert_true(map.has(g) or UiIcons.exists(g), "milestone reward %s/%s -> %s" % [u[0], u[1], g])
	assert_eq(CampInfo.glyph_of("bosses", "boss_lich"), "boss")
	assert_eq(CampInfo.glyph_of("packs", "storm"), "pack_storm")


func test_legacy_fallback_without_the_pack() -> void:
	Icons.set_map({})
	for id in _camp_ids():
		var r := CampArt.resolve(id)
		assert_true(r == "" or UiIcons.exists(r), "%s falls back to a drawn glyph (%s)" % [id, r])
		var c := CampArt.icon(id, 24)
		assert_true(c is Control, "icon control for " + id)
		c.free()
	var m := CampArt.medal("petg_wick", 64, UiPalette.GOLD, true)
	assert_true(UiIcons.exists(m.icon), "medallion glyph without the pack")
	m.free()
	Icons.set_map(null)


func test_count_badge_policy() -> void:
	for n in [1, 2, 3]:
		var b := CampArt.count_badge(n)
		assert_true(b is PanelContainer, "number badge for %d" % n)
		var l := b.get_child(0) as Label
		assert_eq(l.text, str(n))
		b.free()
	var d := CampArt.count_badge(11)
	assert_true(d is CampArt.Dot, "a dot above 3")
	d.free()


func test_station_tag_badge_and_lock() -> void:
	var t := CampScreen.StationTag.new()
	t.station = "pet_den"
	t.set_state(false, "", 11)
	t._ready()
	assert_eq(t.ready_count(), 11)
	assert_true(t._end.get_child(0) is CampArt.Dot, "11 ready: a dot, not a nag number")
	t.set_state(true, "Reach lap 5.", 3)
	assert_eq(t.ready_count(), 0, "locked: no count")
	assert_eq(t.lock_text, "Reach lap 5.")
	assert_true(t.tooltip_text != "", "locked tag explains itself")
	t.set_compact(true)
	assert_true(t._med.custom_minimum_size.x < 50.0, "compact medallion")
	t.free()


func test_tag_resolver_separates_overlaps() -> void:
	var items: Array = []
	for i in 4:
		items.append({"r": Rect2(300 + i * 10, 400 + i * 6, 260, 64)})
	var ok := CampScreen._relax(items, 8.0, 712.0, 200.0, 1200.0)
	assert_true(ok, "four stacked tags separate")
	for i in items.size():
		var r: Rect2 = items[i].r
		assert_true(r.position.y >= 200.0 and r.end.y <= 1200.0 and r.position.x >= 8.0 and r.end.x <= 712.0, "inside the band")
		for j in range(i + 1, items.size()):
			assert_true(not r.intersects(items[j].r), "no overlap %d/%d" % [i, j])


func test_station_modals_are_dismissible_and_esc_closes() -> void:
	var p := _mid()
	for m: CampModal in [ArmoryModal.new(), WardrobeModal.new(), PetDenModal.new(), WorkshopModal.new(), ArcadeModal.new()]:
		assert_true(m.dismissible, "station: the corner x")
		assert_true(m.close_button.visible, "close button shown")
		m.size = Vector2(720, 1280)
		m.show_profile(p)
		m.show_now()
		m._input(_key(KEY_ESCAPE))
		assert_true(not m.is_open(), "Esc closes the station")
		m.free()
	Character.clear_cache()


func test_ready_line_moves_into_the_station() -> void:
	var m := PetDenModal.new()
	m.ready_count = 3
	m.show_profile(_mid())
	assert_true(m.body.get_child(0).name == "ReadyLine", "N ready to buy sits under the plaque")
	m.ready_count = 0
	m.show_profile(_mid())
	assert_true(m.body.get_child(0).name != "ReadyLine", "none when nothing is ready")
	m.free()


func test_run_setup_enter_starts_and_welcome_enter_goes() -> void:
	var p := _mid()
	var rs := RunSetupModal.new()
	rs.size = Vector2(720, 1280)
	rs.show_profile(p)
	rs.show_now()
	assert_true(rs.primary_action is GameButton and (rs.primary_action as GameButton).text == "START RUN", "START RUN is primary")
	var started := [0]
	rs.start_pressed.connect(func() -> void: started[0] += 1)
	rs._input(_key(KEY_ENTER))
	assert_eq(started[0], 1, "Enter starts the run")
	rs._input(_key(KEY_ESCAPE))
	assert_true(not rs.is_open(), "Esc closes the run setup")
	rs.free()
	var w := CampScreen.WelcomeModal.new()
	w.size = Vector2(720, 1280)
	w.show_now()
	assert_true(w.primary_action != null, "LET'S GO is primary")
	assert_true(not w.dismissible, "the welcome is forced")
	w._input(_key(KEY_ENTER))
	assert_true(not w.is_open(), "Enter = LET'S GO")
	w.free()
	Character.clear_cache()


func test_armory_craft_has_no_enter() -> void:
	var p := _mid()
	p.crowns = 999
	var m := ArmoryModal.new()
	m.profile = p
	m.view_class = "knight"
	m.sel_slot = "weapon"
	m.focus = "sword"
	var chips: Array = Camp.new(p).variant_chips("sword")
	for ch in chips:
		if String(ch.state) == "craftable":
			m.chip = String(ch.id)
	m.show_profile(p)
	assert_true(m.primary_action == null, "crafting spends Crowns: Enter never confirms it")
	m.free()
	Character.clear_cache()


func _unique(a: Array) -> int:
	var seen := {}
	for v in a:
		seen[String(v)] = true
	return seen.size()

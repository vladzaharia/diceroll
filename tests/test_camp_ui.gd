extends "res://tests/test_case.gd"
## Camp hub presentation helpers: profile persistence (ProfileStore), the Camp info helpers
## (lock texts, station states, nearest goals) and the run -> bank loop the UI drives.

const PATH := "user://test_profile_store.json"


func test_profile_store_round_trip() -> void:
	ProfileStore.delete(PATH)
	assert_true(ProfileStore.load_profile(PATH) == null, "no file -> null")
	var p := Profile.fresh()
	p.crowns = 57
	p.sigils = 3
	p.grant("gear", "helm")
	p.gear["helm"] = 2
	p.loadout.mode = "short"
	assert_true(ProfileStore.save(p, PATH), "saved")
	var q := ProfileStore.load_profile(PATH)
	assert_true(q != null, "loaded")
	assert_eq(q.to_dict(), p.to_dict(), "round trip")
	assert_true(not FileAccess.file_exists(PATH + ".tmp"), "temp file renamed away")
	ProfileStore.delete(PATH)


func test_profile_store_unreadable_is_fresh() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_true(ProfileStore.load_profile(PATH) == null, "garbage -> null (caller starts fresh)")
	ProfileStore.delete(PATH)


func test_station_states() -> void:
	var p := Profile.fresh()
	assert_true(bool(CampInfo.station_state(p, "armory").locked), "fresh: Armory locked")
	assert_true(bool(CampInfo.station_state(p, "pet_den").locked), "fresh: Pet Den locked")
	assert_true(not bool(CampInfo.station_state(p, "workshop").locked), "Workshop open")
	assert_true(not bool(CampInfo.station_state(p, "arcade").locked), "Arcade open")
	assert_eq(String(CampInfo.station_state(p, "armory").text), "Finish your first run.")
	p.grant("gear", "helm")
	p.grant("pets", "pumpkin_sprite")
	assert_true(not bool(CampInfo.station_state(p, "armory").locked), "Armory opens with the Helm")
	assert_true(not bool(CampInfo.station_state(p, "pet_den").locked), "Pet Den opens with a pet")


func test_lock_text_and_names() -> void:
	assert_true(CampInfo.lock_text("classes", "barbarian").contains("Win 45 fights"), "milestone text")
	assert_true(CampInfo.lock_text("classes", "barbarian").contains("8 Sigils"), "sigil price")
	assert_eq(CampInfo.name_of("packs", "gamblers_kit"), "Gambler's Kit")
	assert_eq(CampInfo.name_of("features", "loadout_slot"), "Third Minigame Slot")
	for kind in UnlockDefs.KINDS:
		for id in UnlockDefs.all_ids(kind):
			assert_true(CampInfo.name_of(kind, String(id)) != "", "name for %s/%s" % [kind, id])
			assert_true(UiIcons.exists(CampInfo.icon_of(kind, String(id))), "icon for %s/%s" % [kind, id])


func test_nearest_goals() -> void:
	var p := Profile.fresh()
	var g := CampInfo.nearest_goals(p, 3)
	assert_eq(g.size(), 3, "three goals")
	for x in g:
		assert_true(int(x.cur) < int(x.need), "goal not met yet: %s" % x.title)
	# a Crowns goal appears once gear is unlocked and not affordable
	p.grant("gear", "helm")
	var has_crowns := false
	for x in CampInfo.nearest_goals(p, 3):
		if String(x.icon) == "crown":
			has_crowns = true
	assert_true(has_crowns, "cheapest Crowns item listed")


## The UI loop: a run from the profile (meta layer on), banked as a loss, unlocks the first
## milestones; the profile file carries them.
func test_run_bank_loop() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	var f := GameFlow.new_run("knight", 5, Balance.BOARD_SIZE, {"profile": p.to_dict(), "mode": "standard", "ascension": 0})
	assert_true(not f.run.meta.is_empty(), "meta run")
	f.run.lap = 6
	f.run.act = 2
	var ev: Array[Dictionary] = []
	f._finish(false, ev)
	var stats: Dictionary = ev.back().stats
	var bank := camp.bank_run(stats)
	var types := []
	for e in bank:
		types.append(String(e.type))
	assert_true(types.has("run_banked"), "banked")
	assert_true(p.owns("gear", "helm"), "first run unlocks the Helm")
	assert_true(p.owns("pets", "pumpkin_sprite"), "lap 5 unlocks the Pumpkin Sprite")
	assert_true(p.crowns > 0, "a loss pays Crowns")
	assert_eq(int(p.records.runs), 1)
	ProfileStore.save(p, PATH)
	var q := ProfileStore.load_profile(PATH)
	assert_true(q.owns("gear", "helm") and q.crowns == p.crowns, "persisted")
	ProfileStore.delete(PATH)


## Level-ups are automatic: a won fight never opens a level-up draft.
func test_level_up_is_not_a_draft() -> void:
	var p := Profile.fresh()
	var f := GameFlow.new_run("knight", 3, Balance.BOARD_SIZE, {"profile": p.to_dict()})
	f.run.xp = Balance.xp_for_level(1) - 1
	f.debug_open("combat", "skeleton_minion")
	var saw_level := false
	for k in 60:
		if f.phase != GameFlow.Phase.COMBAT:
			break
		var evs := f.apply(Bot.next_command(f))
		for e in evs:
			if String(e.type) == "level_up":
				saw_level = true
				assert_true(bool(e.get("auto", false)), "auto level-up")
	assert_true(saw_level, "leveled up")
	assert_true(not (f.phase == GameFlow.Phase.DRAFT and String(f.offer.get("source", "")) == "level"), "no level draft")

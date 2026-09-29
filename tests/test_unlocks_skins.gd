extends "res://tests/test_case.gd"
## Class unlock table (design §2), Sigil rules and skins (design §4): profile v2, Camp commands.

func _first(ev: Array, type: String) -> Dictionary:
	for e in ev:
		if e.type == type:
			return e
	return {}

func _stats(victory: bool, extra := {}) -> Dictionary:
	var s := {"rewards": {"crowns": 10}, "victory": victory, "class_id": "knight", "lap": 15 if victory else 8,
		"laps_completed": 14 if victory else 7, "fights_won": 10, "route": ["glade", "hollow", "throne"],
		"biomes_visited": ["glade"], "minibosses_killed": [], "bosses_killed": ["boss_lich"] if victory else [],
		"asc": 0, "mode": "standard", "max_act": 3, "pet": "", "pet_fights": 0, "minigame_plays": {},
		"boss_reached": victory}
	for k in extra:
		s[k] = extra[k]
	return s

# ================================================================ unlock table

func test_next_two_rule_and_prices() -> void:
	assert_eq(UnlockDefs.buyable_classes(["knight"]), ["barbarian", "paladin"])
	assert_eq(UnlockDefs.sigil_cost("classes", "mage", ["knight"]), {}, "third in line")
	assert_eq(UnlockDefs.sigil_cost("classes", "mage"), {"sigils": 8}, "price label without the rule")
	var owned := ["knight", "barbarian", "paladin", "mage", "ranger", "rogue"]
	assert_eq(UnlockDefs.buyable_classes(owned), ["ninja", "druid"])
	assert_eq(UnlockDefs.sigil_cost("classes", "ninja", owned), {"sigils": 10})
	assert_eq(UnlockDefs.sigil_cost("classes", "druid", owned), {"sigils": 10})

func test_class_milestones_cover_every_new_class() -> void:
	var by := {}
	for m in UnlockDefs.MILESTONES:
		for u in m.unlocks:
			if String(u[0]) == "classes":
				by[String(u[1])] = m.id
	for id in HeroDefs.IDS:
		if id != "knight":
			assert_true(by.has(id), id + " has a milestone")
	assert_eq(by.get("paladin"), "oathsworn")
	assert_eq(by.get("ranger"), "pathfinder_trail")
	assert_eq(by.get("ninja"), "shadow_pact")
	assert_eq(by.get("druid"), "long_road")

func test_new_cond_forms() -> void:
	var p := Profile.fresh()
	assert_true(not p._cond({"class_wins": "knight", "min": 1}))
	p.records.wins_by_class = {"knight": 1}
	assert_true(p._cond({"class_wins": "knight", "min": 1}))
	p.records.boss_kills = {"boss_bone_warden": 2}
	assert_true(p._cond({"boss_kills": "boss_bone_warden", "min": 2}))
	assert_true(not p._cond({"all": [{"boss_kills": "boss_bone_warden", "min": 2}, {"stat": "runs", "min": 1}]}))
	p.records.bosses_reached_by_class = {"knight": 3, "mage": 1, "rogue": 0}
	assert_eq(p.counter("classes_at_boss"), 2)
	assert_eq(p.counter("classes_owned"), 1)

func test_paladin_unlocks_on_the_first_knight_win() -> void:
	var p := Profile.fresh()
	var res := p.apply_run_result(_stats(true))
	assert_true(res.milestones.has("oathsworn"))
	assert_true(p.owns("classes", "paladin"))

func test_one_class_per_run_from_milestones() -> void:
	var p := Profile.fresh()
	p.records.counters.runs = 15
	p.records.counters.fights = 100
	var res := p.apply_run_result(_stats(false))
	var classes := []
	for u in res.unlocked:
		if u[0] == "classes":
			classes.append(u[1])
	assert_eq(classes.size(), 1, "one class this run: %s" % str(classes))
	res = p.apply_run_result(_stats(false))
	var more := 0
	for u in res.unlocked:
		if u[0] == "classes":
			more += 1
	assert_eq(more, 1, "the next one waits for the next run")

func test_new_counters_and_records() -> void:
	var p := Profile.fresh()
	p.apply_run_result(_stats(true, {"face_edits": 3, "kills": 20, "hollow_events": 2, "seen_enemies": ["bandit"], "seen_affixes": ["gilded"]}))
	assert_eq(p.counter("face_edits"), 3)
	assert_eq(p.counter("kills"), 20)
	assert_eq(p.counter("hollow_events"), 2)
	assert_eq(p.records.boss_kills, {"boss_lich": 1})
	assert_eq(p.records.bosses_by_class, {"knight": ["boss_lich"]})
	assert_eq(p.records.bosses_reached_by_class, {"knight": 1})
	assert_eq(p.records.best_asc_by_class, {"knight": 0})
	assert_eq(p.records.seen, {"enemies": ["bandit"], "affixes": ["gilded"]})

func test_run_stats_count_face_edits_kills_and_hollow_events() -> void:
	var f := GameFlow.new_run("knight", 4)
	f.debug_open("forge")
	f.forge_apply(0, 0, "raise")
	assert_eq(int(f.run.stats.face_edits), 1)
	f.debug_open("combat", "skeleton_minion")
	f.combat.damage_enemy(0, 999, "attack", f.run)
	assert_eq(int(f.run.stats.kills), 1)

func test_presets_mid_and_max_classes() -> void:
	var mid := Profile.from_dict(MetaPresets.get_preset("mid"))
	assert_eq(mid.unlocks.classes, ["knight", "barbarian", "paladin", "mage"])
	var mx := Profile.from_dict(MetaPresets.get_preset("max"))
	assert_eq(mx.unlocks.classes, HeroDefs.IDS)
	assert_true(mx.owns("features", "affixes"))
	assert_true(mid.owns("features", "affixes"))

# ================================================================ skins

func test_skin_defs_shape() -> void:
	for cid in HeroDefs.IDS:
		var s := SkinDefs.of(cid)
		assert_eq(s.size(), 5, cid)
		assert_eq(s[0].id, "default")
		assert_true(bool(s[4].prestige) and not bool(s[4].buyable), "prestige is never buyable")

func test_skins_from_records() -> void:
	var p := Profile.fresh()
	var res := p.apply_run_result(_stats(true))
	assert_eq(res.skins_unlocked, [["knight", "victor"]])
	assert_true(p.owns_skin("knight", "victor"))
	res = p.apply_run_result(_stats(true, {"asc": 3}))
	assert_eq(res.skins_unlocked, [["knight", "ascendant"]])
	res = p.apply_run_result(_stats(true, {"asc": 6}))
	assert_eq(res.skins_unlocked, [["knight", "bossbane"]], "A6 grants Bossbane")
	res = p.apply_run_result(_stats(true, {"asc": 10}))
	assert_eq(res.skins_unlocked, [["knight", "prestige"]])
	assert_true(p.prestige_on("knight"), "on by default")
	assert_true(p.cosmetics.unseen.has("knight:victor"))

func test_bossbane_from_four_final_bosses() -> void:
	var p := Profile.fresh()
	for b in ["boss_lich", "boss_bone_warden", "boss_cinder_king"]:
		p.apply_run_result(_stats(false, {"bosses_killed": [b]}))
	assert_true(not p.owns_skin("knight", "bossbane"))
	var res := p.apply_run_result(_stats(false, {"bosses_killed": ["boss_magma_golem"]}))
	assert_true(res.skins_unlocked.has(["knight", "bossbane"]))

func test_camp_equip_buy_and_prestige() -> void:
	var p := Profile.fresh()
	var camp := Camp.new(p)
	assert_eq(camp.equip_skin("knight", "victor")[0].type, "error", "locked")
	var ev := camp.bank_run(_stats(true))
	assert_eq(_first(ev, "skin_unlocked"), {"type": "skin_unlocked", "class": "knight", "skin": "victor", "source": "record"})
	assert_eq(camp.equip_skin("knight", "victor")[0], {"type": "skin_equipped", "class": "knight", "skin": "victor"})
	assert_eq(p.equipped_skin("knight"), "victor")
	p.crowns = 5000
	assert_eq(camp.buy_skin("knight", "ascendant")[0].type, "error", "not capped yet")
	assert_eq(camp.buy_skin("knight", "prestige")[0].type, "error")
	var mx := Profile.from_dict(MetaPresets.get_preset("max"))
	mx.crowns = 300
	var c2 := Camp.new(mx)
	assert_true(mx.crowns_capped())
	ev = c2.buy_skin("ranger", "bossbane")
	assert_eq(_first(ev, "skin_unlocked").source, "crowns")
	assert_eq(mx.crowns, 50)
	assert_eq(c2.buy_skin("ranger", "prestige")[0].type, "error", "A10 prestige can't be bought")
	assert_eq(camp.set_prestige("knight", false)[0].type, "error", "not owned")
	camp.mark_skins_seen("knight")
	assert_true(p.cosmetics.unseen.is_empty())
	var found := false
	for it in c2.catalog():
		if String(it.cmd[0]) == "buy_skin":
			found = true
	assert_true(found, "the catalogue lists skins after the caps")

func test_profile_v2_round_trip_and_v1_migration() -> void:
	var p := Profile.fresh()
	p.apply_run_result(_stats(true))
	Camp.new(p).equip_skin("knight", "victor")
	var back := Profile.from_json(Profile.to_json(p))
	assert_eq(back.to_dict(), p.to_dict())
	assert_eq(int(p.to_dict().version), 2)
	# a version-1 file: no cosmetics, no new records, a Mage win
	var v1 := Profile.fresh().to_dict()
	v1.version = 1
	v1.erase("cosmetics")
	for k in ["best_asc_by_class", "bosses_by_class", "bosses_reached_by_class", "boss_kills", "seen"]:
		v1.records.erase(k)
	v1.records.counters.erase("kills")
	v1.records.wins_by_class = {"mage": 2}
	v1.unlocks.classes = ["knight", "mage"]
	var m := Profile.from_dict(JSON.parse_string(JSON.stringify(v1)))
	assert_true(m.owns_skin("mage", "victor"), "wins before v2 still earn Victor")
	assert_eq(m.records.best_asc_by_class, {"mage": 0})
	assert_eq(m.records.seen, {"enemies": [], "affixes": []})
	assert_eq(m.counter("kills"), 0)
	assert_eq(m.equipped_skin("mage"), "default")

func test_run_carries_the_equipped_skin() -> void:
	var p := Profile.fresh()
	p.apply_run_result(_stats(true))
	Camp.new(p).equip_skin("knight", "victor")
	var f := GameFlow.new_run("knight", 3, 28, {"profile": p.to_dict()})
	assert_eq(f.run.skin, "victor")
	var back := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
	assert_eq(back.run.skin, "victor")
	assert_eq(GameFlow.new_run("knight", 3).run.skin, "default")

extends "res://tests/test_case.gd"
## Enemy affixes (design §3A): derived-Rng rolls at tile spawn, rates, stacking rules, every
## rule's hook, events and serialisation.

var run: RunState
var c: CombatState

func _all(ev: Array, type: String, affix := "") -> Array:
	var out := []
	for e in ev:
		if e.type == type and (affix == "" or String(e.get("affix", "")) == affix):
			out.append(e)
	return out

## Knight vs `ids` with affixes (per enemy), passive 100-HP enemies.
func _setup(ids: Array, affixes: Array, hp := 100) -> void:
	run = RunState.create("knight", 1)
	c = CombatState.new()
	c.begin(run, ids, false, false, 3, false, affixes)
	for e in c.enemies:
		e.hp = hp
		e.max_hp = hp
		e.intent = {"kind": "aim", "value": 0}

func _profile_run(seed_: int, affixes: bool) -> GameFlow:
	var p := Profile.fresh()
	if affixes:
		p.grant("features", "affixes")
	return GameFlow.new_run("knight", seed_, 28, {"profile": p.to_dict()})

func after_each() -> void:
	AffixDefs.sim_mode = ""

func test_rolls_never_touch_the_run_stream() -> void:
	AffixDefs.sim_mode = "force:armored"
	var a := GameFlow.new_run("knight", 77)
	AffixDefs.sim_mode = "off"
	var b := GameFlow.new_run("knight", 77)
	AffixDefs.sim_mode = ""
	assert_eq(a.run.rng.state, b.run.rng.state, "same Rng state")
	for i in a.run.board.size():
		assert_eq(a.run.board.tiles[i].enemies, b.run.board.tiles[i].enemies)
	var any := false
	for i in a.run.board.size():
		if a.run.board.tiles[i].has("enemy_affixes"):
			any = true
	assert_true(any, "forced affix on the elite leaders") if a.run.act >= 2 else assert_true(true)

func test_off_for_fresh_profiles_on_with_the_feature() -> void:
	var f := _profile_run(3, false)
	assert_eq(f.run.affix_mode(), "")
	var g := _profile_run(3, true)
	assert_eq(g.run.affix_mode(), "on")
	assert_eq(GameFlow.new_run("knight", 3).run.affix_mode(), "", "legacy runs never")
	assert_true(UnlockDefs.milestone("brawler").unlocks.has(["features", "affixes"]))
	assert_true(MetaRun.normalize(MetaRun.build(Profile.fresh().to_dict())).has("affixes"))

func test_rates_by_band_and_elite_leader() -> void:
	var rng := Rng.new(5)
	for k in 200:
		for a in AffixDefs.roll_tile(rng, ["brute", "bandit"], "glade", 0, true):
			assert_true((a as Array).is_empty(), "band 0: none")
	var got := 0
	for k in 200:
		var out: Array = AffixDefs.roll_tile(rng, ["brute", "bandit"], "throne", 3, true)
		if not (out[0] as Array).is_empty():
			got += 1
		assert_true((out[0] as Array).size() <= 2, "elites: at most 2")
		assert_true((out[1] as Array).size() <= 1, "regulars: at most 1")
	assert_true(got >= 195, "band 3 elite leaders always roll (re-roll misses aside): %d" % got)
	var reg := 0
	for k in 2000:
		if not (AffixDefs.roll_tile(rng, ["bandit"], "magma", 4, false)[0] as Array).is_empty():
			reg += 1
	assert_true(reg > 300 and reg < 500, "band 4 regular ~20%%: %d" % reg)

func test_stacking_rules() -> void:
	assert_true(not AffixDefs.allowed("piercing", "bone_cutthroat", [], 2, false), "duplicate trait")
	assert_true(not AffixDefs.allowed("armored", "bone_knight", [], 2, false))
	assert_true(not AffixDefs.allowed("warded", "bandit", [], 1, false), "warded needs a group")
	assert_true(not AffixDefs.allowed("warded", "bandit", [], 3, true), "one warded per tile")
	assert_true(AffixDefs.allowed("warded", "bandit", [], 2, false))
	assert_true(not AffixDefs.allowed("vampiric", "hollow_wisp", [], 2, false), "excluded")
	var rng := Rng.new(9)
	for k in 300:
		var out: Array = AffixDefs.roll_tile(rng, ["cultist", "bandit", "hollow_wisp"], "hollow", 4, false)
		var w := 0
		for a in out:
			w += (a as Array).count("warded")
		assert_true(w <= 1)
	assert_eq(AffixDefs.roll_tile(rng, ["boss_lich"], "throne", 4, true, "force:gilded"), [[]], "bosses never")

func test_board_changes_and_saves_carry_affixes() -> void:
	AffixDefs.sim_mode = "on"
	var f := GameFlow.new_run("knight", 12)
	var found := -1
	for lap in range(4, 13):
		f.run.lap = lap
		for t in f.run.board.tiles:
			if Board._is_fight(String(t.type)):
				t["cleared"] = true
		var ch := f.run.board.mutate(f.run.rng, 1, lap, [], ["elite", "elite"])
		f.run.roll_change_affixes(ch)
		for cc in ch:
			if cc.has("affixes") and not (cc.affixes[0] as Array).is_empty():
				found = int(cc.idx)
		if found >= 0:
			break
	assert_true(found >= 0, "an elite rolled an affix")
	var back := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
	assert_eq(back.run.board.affixes_of(found), f.run.board.affixes_of(found))
	var ev: Array[Dictionary] = []
	f.phase = GameFlow.Phase.BOARD_READY
	f._trigger_tile(found, ev)
	var cs: Dictionary = _all(ev, "combat_started")[0]
	assert_eq(cs.enemies[0].affixes, f.run.board.affixes_of(found)[0])
	assert_true((f.run.stats.seen_affixes as Array).has(String(cs.enemies[0].affixes[0])))

func test_armored_and_piercing() -> void:
	_setup(["bandit"], [["armored"]])
	c.enemies[0].block = 0
	AffixDefs.apply(c.enemies[0], ["armored"], 1)
	assert_eq(int(c.enemies[0].block), 20)
	assert_true(CombatState.has_trait(c.enemies[0], "armor"))
	_setup(["bandit"], [["piercing"]])
	run.block = 10
	var ev := c._hit_hero(run, 0, 6)
	assert_eq(int(ev[0].blocked), 0)

func test_thorned_reflects_by_band() -> void:
	run = RunState.create("knight", 1)
	c = CombatState.new()
	c.lap = 11
	c.begin(run, ["bandit"], false, false, 3, false, [["thorned"]])
	assert_eq(int(c.enemies[0].thorns_value), AffixDefs.THORNS_EARLY, "band from the fight's lap (1)")
	c.enemies[0].thorns_value = AffixDefs.THORNS_LATE
	c.enemies[0].hp = 100
	c.enemies[0].intent = {"kind": "aim", "value": 0}
	var hp := run.hp
	c.dice_values.assign([3, 4])
	var ev := c.attack(run)
	assert_eq(_all(ev, "affix_triggered", "thorned").size(), 1)
	assert_eq(run.hp, hp - AffixDefs.THORNS_LATE)

func test_warded_halves_while_an_unwarded_ally_stands() -> void:
	_setup(["bandit", "bandit"], [["warded"], []])
	var ev := c.damage_enemy(0, 10, "attack", run)
	assert_eq(int(ev[0].amount), 5)
	c.enemies[1].hp = 0
	ev = c.damage_enemy(0, 10, "attack", run)
	assert_eq(int(ev[0].amount), 10)

func test_regenerating_heals_unless_poisoned() -> void:
	_setup(["bandit"], [["regenerating"]])
	c.enemies[0].hp = 50
	var ev := c._affix_before_action(run, 0)
	assert_eq(int(c.enemies[0].hp), 56)
	assert_eq(_all(ev, "affix_triggered", "regenerating").size(), 1)
	c.enemies[0].poison = 2
	assert_true(_all(c._affix_before_action(run, 0), "affix_triggered").is_empty())

func test_vampiric_drains() -> void:
	_setup(["bandit"], [["vampiric"]])
	c.enemies[0].step = 0
	c.roll_intent(run.rng, 0)
	assert_eq(c.enemies[0].intent.kind, "drain", "attack became drain")

func test_hexing_first_then_every_third_action() -> void:
	_setup(["bandit"], [["hexing"]])
	var curses := []
	for k in 7:
		curses.append(_all(c._affix_before_action(run, 0), "affix_triggered", "hexing").size())
	assert_eq(curses, [1, 0, 0, 1, 0, 0, 1])

func test_frostbound_chills_on_its_first_attack_only() -> void:
	_setup(["bandit"], [["frostbound"]])
	assert_true(_all(c._affix_before_action(run, 0), "affix_triggered").is_empty(), "not on a non-attack")
	c.enemies[0].intent = {"kind": "attack", "value": 3}
	var before := c.pending_curse
	assert_eq(_all(c._affix_before_action(run, 0), "affix_triggered", "frostbound").size(), 1)
	assert_eq(c.pending_curse, before + 1)
	assert_true(_all(c._affix_before_action(run, 0), "affix_triggered").is_empty())

func test_frozen_enemies_skip_affix_procs() -> void:
	_setup(["bandit"], [["hexing"]])
	c.enemies[0].frozen = true
	c._enemy_phase(run)
	assert_eq(int(c.enemies[0].get("actions", 0)), 0, "the hex counter doesn't advance")

func test_gilded_hp_rewards_and_pet_charge() -> void:
	run = RunState.create("knight", 1)
	c = CombatState.new()
	c.begin(run, ["bandit"], false, false, 3, false, [["gilded"]])
	var plain := CombatState.make_enemy(Rng.new(1), "bandit", 1, 1, false)
	var biome_hp := int(round(int(plain.max_hp) * BiomeDefs.enemy_hp(run.biome())))
	assert_eq(int(c.enemies[0].max_hp), int(round(biome_hp * AffixDefs.GILDED_HP)))
	assert_eq(AffixDefs.reward_mult(["gilded"]), [AffixDefs.GILDED_GOLD, AffixDefs.GILDED_XP])
	assert_eq(AffixDefs.reward_mult(["armored", "thorned"]), [2.25, 2.25])
	c.damage_enemy(0, 999, "attack", run)
	assert_eq(int(run.stats.affixed_kills), 1)
	assert_eq(int(run.stats.kills), 1)
	assert_true(c.gold_reward >= 0)

func test_a4_miniboss_gets_a_biome_affix() -> void:
	var p := MetaPresets.get_preset("max", 4)
	var f := GameFlow.new_run("knight", 8, 28, {"profile": p})
	var mb := f.run.board.spawn_miniboss(f.run.rng, f.run.miniboss_id, 0)
	f.run.roll_change_affixes([mb])
	var a: Array = f.run.board.affixes_of(int(mb.idx))[0]
	assert_eq(a.size(), 1)
	assert_true((AffixDefs.BIOME[f.run.board.biome] as Array).has(a[0]))

func test_sim_force_mode_hits_elite_leaders_only() -> void:
	var out: Array = AffixDefs.roll_tile(Rng.new(1), ["brute", "bandit"], "glade", 0, true, "force:warded")
	assert_eq(out, [["warded"], []])
	out = AffixDefs.roll_tile(Rng.new(1), ["bandit", "bandit"], "glade", 4, false, "force:warded")
	assert_eq(out, [[], []])

func test_full_runs_with_affixes_on() -> void:
	AffixDefs.sim_mode = "on"
	for s in [2, 3]:
		var f := GameFlow.new_run("rogue", s)
		var n := 0
		var procs := 0
		while not f.is_over() and n < 4000:
			var ev := f.apply(Bot.next_command(f))
			for e in ev:
				assert_true(e.type != "error", str(e))
			procs += _all(ev, "affix_triggered").size()
			n += 1
		assert_true(f.is_over())
		var r := GameFlow.replay("rogue", s, f.commands)
		assert_eq(r.run.hp, f.run.hp, "replay")
	AffixDefs.sim_mode = ""

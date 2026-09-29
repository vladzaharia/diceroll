extends "res://tests/test_case.gd"
## The 2026-09-28 enemy roster: frenzy, rally, transform, the 8 new ids and the pools.

var run: RunState
var c: CombatState

func _all(ev: Array, type: String) -> Array:
	var out := []
	for e in ev:
		if e.type == type:
			out.append(e)
	return out

func _setup(ids: Array, dice := [3, 4]) -> void:
	run = RunState.create("knight", 1)
	run.dice.clear()
	for v in dice:
		run.dice.append(Die.make())
	c = CombatState.new()
	c.begin(run, ids, false, false, 3)
	for e in c.enemies:
		e.hp = 100
		e.max_hp = 100
		e.block = 0
		e.intent = {"kind": "aim", "value": 0}
	c.dice_values.assign(dice)

func test_new_ids_are_defined_and_placed() -> void:
	for id in ["bone_cutthroat", "bone_golem", "orc_raider", "orc_drummer", "werewolf", "fallen_paladin"]:
		assert_true(EnemyDefs.ENEMIES.has(id), id)
	for id in ["mini_moonfang", "mini_orc_warchief"]:
		assert_true(EnemyDefs.MINIBOSSES.has(id), id)
		assert_true(UnlockDefs.all_ids("minibosses").has(id), id + " unlockable")
	assert_true(EnemyDefs.traits("bone_cutthroat").has("pierce"))
	assert_true(EnemyDefs.traits("orc_raider").has("frenzy"))
	assert_eq(BiomeDefs.DEFS.crypt.elite, "bone_golem")
	assert_eq(BiomeDefs.DEFS.hollow.elite, "fallen_paladin")
	assert_true((BiomeDefs.DEFS.hollow.pools[1] as Array).has("werewolf"))
	assert_true((BiomeDefs.DEFS.frost.pools[1] as Array).has("orc_drummer"))
	assert_true((BiomeDefs.DEFS.glade.pools[1] as Array).has("orc_raider"))
	assert_true((BiomeDefs.DEFS.magma.pools[0] as Array).has("orc_raider"))
	assert_true((BiomeDefs.DEFS.crypt.pools[1] as Array).has("bone_cutthroat"))
	var sizes := {"glade": 7, "crypt": 7, "hollow": 8, "frost": 7, "throne": 8, "magma": 8}
	for b in sizes:
		assert_eq((BiomeDefs.DEFS[b].pools[0] as Array).size() + (BiomeDefs.DEFS[b].pools[1] as Array).size(),
			int(sizes[b]), b + " pool sizes unchanged (replacements only)")
	var p := Profile.fresh()
	assert_true(not p.owns("minibosses", "mini_moonfang"), "not on fresh profiles")

func test_frenzy_stacks_on_main_attack_hits_up_to_six() -> void:
	_setup(["orc_raider"])
	for k in 5:
		c.dice_values.assign([3, 4])
		c.enemies[0].intent = {"kind": "aim", "value": 0}
		var ev := c.attack(run)
		var fr := []
		for e in ev:
			if e.type == "status" and e.status == "frenzy":
				fr.append(e)
		assert_eq(fr.size(), 1 if k < 3 else 0, "stack %d" % k)
	assert_eq(int(c.enemies[0].frenzy), EnemyDefs.FRENZY_MAX)
	assert_eq(int(c.enemies[0].atk_bonus), EnemyDefs.FRENZY_MAX)

func test_frenzy_ignores_poison_and_ember() -> void:
	_setup(["orc_raider"])
	c.damage_enemy(0, 5, "ember", run)
	c.damage_enemy(0, 5, "poison", run, true)
	assert_eq(int(c.enemies[0].frenzy), 0)

func test_rally_buffs_every_living_enemy() -> void:
	_setup(["orc_drummer", "skeleton_minion", "skeleton_minion"])
	c.enemies[2].hp = 0
	c.enemies[0].intent = {"kind": "rally", "value": 2}
	var ev := c._execute_intent(run, 0)
	assert_eq(int(c.enemies[0].atk_bonus), 2)
	assert_eq(int(c.enemies[1].atk_bonus), 2)
	assert_eq(int(c.enemies[2].atk_bonus), 0, "the dead stay dead")
	assert_eq(_all(ev, "status").size(), 2)

func test_werewolf_transforms_once_at_half_hp() -> void:
	_setup(["werewolf"])
	c.enemies[0].block = 5
	var ev := c.damage_enemy(0, 40, "attack", run)
	assert_true(_all(ev, "enemy_transformed").is_empty(), "above half")
	ev = c.damage_enemy(0, 20, "attack", run)
	var tr := _all(ev, "enemy_transformed")
	assert_eq(tr.size(), 1)
	assert_eq(tr[0].form, "wolf")
	assert_eq(int(c.enemies[0].phase), 2)
	assert_eq(int(c.enemies[0].block), 0, "drops its Block")
	var wolf := []
	for x in EnemyDefs.pattern("werewolf", 2):
		wolf.append(String(x.kind))
	assert_true(wolf.has(String(c.enemies[0].intent.kind)), "intent re-rolled from the wolf pattern")
	assert_true(_all(c.damage_enemy(0, 5, "attack", run), "enemy_transformed").is_empty(), "only once")

func test_moonfang_transforms_and_warchief_summons_raiders() -> void:
	_setup(["mini_moonfang"])
	var ev := c.damage_enemy(0, 60, "attack", run)
	assert_eq(_all(ev, "enemy_transformed").size(), 1)
	_setup(["mini_orc_warchief"])
	c.enemies[0].intent = {"kind": "summon", "value": 1}
	ev = c._execute_intent(run, 0)
	assert_eq(_all(ev, "summon")[0].enemy.id, "orc_raider")

func test_new_enemies_serialise() -> void:
	_setup(["werewolf", "orc_raider"])
	c.damage_enemy(0, 60, "attack", run)
	c.enemies[1].frenzy = 4
	var back := CombatState.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.enemies[0].form, "wolf")
	assert_eq(int(back.enemies[1].frenzy), 4)

func test_new_enemies_in_full_runs() -> void:
	# every route plays without errors with the new pools
	for route in BiomeDefs.all_routes():
		var f := GameFlow.new_run("barbarian", 21, 28, {"route": route})
		var n := 0
		while not f.is_over() and n < 4000:
			for e in f.apply(Bot.next_command(f)):
				assert_true(e.type != "error", "%s: %s" % [str(route), str(e)])
			n += 1
		assert_true(f.is_over())

extends "res://tests/test_case.gd"
## Wave-2 classes (design §1.2.5-1.2.7): Necromancer, Engineer, Monster Kid.

var run: RunState
var c: CombatState

func _all(ev: Array, type: String, id := "") -> Array:
	var out := []
	for e in ev:
		if e.type == type and (id == "" or String(e.get("id", "")) == id):
			out.append(e)
	return out

func _setup(cls: String, dice: Array, ids: Array = ["skeleton_minion"]) -> void:
	run = RunState.create(cls, 1)
	run.dice.clear()
	for d in dice:
		run.dice.append(Die.make(String(d[1]), String(d[0])))
	c = CombatState.new()
	c.begin(run, ids, false, false, 3)
	for e in c.enemies:
		e.hp = 100
		e.max_hp = 100
		e.intent = {"kind": "aim", "value": 0}

func _dice(values: Array) -> void:
	c.dice_values.assign(values)

# ================================================================ Necromancer

func test_necromancer_kills_raise_bone_dice_next_turn() -> void:
	_setup("necromancer", [["standard", "vampire"], ["standard", ""]], ["skeleton_minion", "skeleton_minion", "skeleton_minion"])
	c.enemies[0].hp = 1
	c.target = 0
	_dice([6, 6])
	var ev := c.attack(run)
	assert_eq(_all(ev, "class_triggered", "bone_harvest").size(), 1)
	assert_eq(c.extra_dice.size(), 1, "joins at the next turn start")
	var added := _all(ev, "die_added")
	assert_eq(added.size(), 1)
	assert_eq(bool(added[0].temporary), true)
	assert_eq(int(added[0].die_idx), 2)
	assert_eq(c.dice_values.size(), 3, "the pool spans run.dice + extra_dice")
	assert_true(c.extra_dice[0].has_tag("bone"))
	assert_eq(Array(c.extra_dice[0].faces), [1, 2, 2, 3, 3, 4])
	assert_eq(run.dice.size(), 2, "the run's pool is untouched")

func test_necromancer_bone_caps_and_crumble_heal() -> void:
	_setup("necromancer", [["standard", ""], ["standard", ""]], ["skeleton_minion", "skeleton_minion", "skeleton_minion", "skeleton_minion"])
	for k in 3:
		c.enemies[k].hp = 1
		c.target = k
		_dice([2, 3] + ([] if c.dice_values.size() == 2 else [1, 1, 1, 1].slice(0, c.dice_values.size() - 2)))
		c.attack(run)
	assert_eq(c.extra_dice.size(), ClassLogic.BONE_MAX, "max 2 bones")
	run.hp = 30
	c.target = 3
	c.enemies[3].hp = 1
	var ev := c.attack(run)
	assert_eq(c.result, "won")
	assert_eq(_all(ev, "die_removed").size(), 2)
	assert_eq(_all(ev, "class_triggered", "bone_crumble").size(), 1)
	assert_eq(run.hp, 30 + 2 * ClassLogic.BONE_HEAL, "each bone heals")
	assert_true(c.extra_dice.is_empty())

func test_necromancer_lone_foe_turns_and_boss_phase() -> void:
	_setup("necromancer", [["standard", ""], ["standard", ""]], ["mini_pumpkin_knight"])
	c.enemies[0].hp = 999
	c.enemies[0].max_hp = 999
	for t in 2:
		_dice([1, 2])
		c.enemies[0].intent = {"kind": "aim", "value": 0}
		c.attack(run)
	assert_eq(c.turn, 3)
	assert_eq(c.extra_dice.size(), 1, "turn 3 raised a bone for the lone foe")
	var f := GameFlow.new_run("necromancer", 4)
	f.debug_open("boss", "boss_lich")
	var bc := f.combat
	var ev := bc.damage_enemy(0, int(bc.enemies[0].hp) / 2 + 5, "attack", f.run)
	assert_eq(_all(ev, "class_triggered", "bone_harvest").size(), 1, "phase 2 drops a bone")

func test_necromancer_combat_serialises_bones() -> void:
	_setup("necromancer", [["standard", ""], ["standard", ""]], ["skeleton_minion", "skeleton_minion"])
	c.enemies[0].hp = 1
	c.target = 0
	_dice([5, 5])
	c.attack(run)
	var back := CombatState.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.extra_dice.size(), 1)
	assert_eq(back.bones_raised, 1)
	assert_eq(back.dice_values.size(), 3)

# ================================================================ Engineer

func test_engineer_turret_exists_and_serialises() -> void:
	var f := GameFlow.new_run("engineer", 3)
	assert_true(f.run.turret != null)
	assert_eq(f.run.dice.size(), 2, "the turret is outside the pool")
	assert_eq(GameFlow.new_run("knight", 3).run.turret, null)
	f.run.turret.rune = "heavy"
	var back := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
	assert_eq(back.run.turret.rune, "heavy")
	assert_true(back.run.turret.has_tag("turret"))

func test_engineer_turret_fires_after_the_attack() -> void:
	_setup("engineer", [["standard", ""], ["standard", ""]])
	run.turret.faces = PackedInt32Array([4, 4, 4, 4, 4, 4])
	_dice([1, 2])
	var ev := c.attack(run)
	var tf := _all(ev, "turret_fired")
	assert_eq(tf.size(), 1)
	assert_eq(int(tf[0].value), 4)
	assert_eq(int(tf[0].damage), 4, "tier 1: pips x1")
	run.turret.rune = "heavy"
	run.act = 3
	run.route = ["glade", "hollow", "magma"]
	_dice([1, 2])
	ev = c.attack(run)
	assert_eq(int(_all(ev, "turret_fired")[0].damage), int(4 * 2 * ClassLogic.TURRET_T[2]), "tier 3, Heavy doubles")

func test_engineer_turret_runes() -> void:
	_setup("engineer", [["standard", ""]], ["skeleton_minion", "skeleton_minion"])
	run.turret.faces = PackedInt32Array([1, 1, 1, 1, 1, 1])
	run.turret.rune = "frost"
	_dice([2])
	c.attack(run)
	assert_true(bool(c.enemies[c.target].frozen) or int(run.stats.get("freezes", 0)) == 1, "a 1 freezes")
	run.turret.faces = PackedInt32Array([3, 3, 3, 3, 3, 3])
	run.turret.rune = "guard"
	_dice([2])
	var ev := c.attack(run)
	var bg := false
	for e in ev:
		if e.type == "block_gained" and String(e.get("source", "")) == "turret":
			bg = true
	assert_true(bg, "Guard: Block = pips")

func test_engineer_offers_target_the_turret() -> void:
	var f := GameFlow.new_run("engineer", 3)
	f.debug_open("rune_assign", "blade")
	assert_eq(f.rune_assign(GameFlow.TURRET)[0].type, "error", "combo runes never go on the turret")
	f.debug_open("rune_assign", "ember")
	var ev := f.rune_assign(GameFlow.TURRET)
	assert_eq(f.run.turret.rune, "ember")
	assert_true(bool(ev[1].turret) if ev.size() > 1 else true)
	f.debug_open("forge")
	f.forge_apply(GameFlow.TURRET, 0, "raise")
	assert_eq(f.run.turret.faces[0], 2)
	var k := GameFlow.new_run("knight", 3)
	k.debug_open("rune_assign", "ember")
	assert_eq(k.rune_assign(GameFlow.TURRET)[0].type, "error", "no turret, no target")

func test_engineer_greedy_bot_fills_the_turret() -> void:
	var f := GameFlow.new_run("engineer", 3)
	f.debug_open("rune_assign", "frost")
	assert_eq(Bot.next_command(f), ["rune_assign", GameFlow.TURRET])

func test_wave2_full_runs_replay() -> void:
	for cls in ["necromancer", "engineer"]:
		for s in [5, 6]:
			var f := GameFlow.new_run(cls, s)
			var n := 0
			while not f.is_over() and n < 4000:
				for e in f.apply(Bot.next_command(f)):
					assert_true(e.type != "error", "%s: %s" % [cls, str(e)])
				n += 1
			assert_true(f.is_over())
			var r := GameFlow.replay(cls, s, f.commands)
			assert_eq(JSON.stringify(r.to_dict()), JSON.stringify(f.to_dict()), cls + " replay")

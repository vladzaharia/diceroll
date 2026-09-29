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

func test_wave2_full_runs_replay() -> void:
	for cls in ["necromancer"]:
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

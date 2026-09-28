extends "res://tests/test_case.gd"
## Bot.decide in combat: expected-value rerolls, locked dice, targets, single steps.

## A fight with the given dice (kinds) showing `values`, `rerolls` left, and enemies given as
## [{id, hp, intent_kind, intent_value}].
func _fight(kinds: Array, values: Array, rerolls: int, foes: Array, runes: Array = []) -> GameFlow:
	var f := GameFlow.new_run("knight", 5)
	f.run.dice.clear()
	for i in kinds.size():
		f.run.dice.append(Die.make(String(runes[i]) if i < runes.size() else "", String(kinds[i])))
	var ids: Array = []
	for e in foes:
		ids.append(String(e.id))
	f.debug_open("combat", ",".join(ids))
	var c := f.combat
	for i in foes.size():
		c.enemies[i].hp = int(foes[i].hp)
		c.enemies[i].max_hp = int(foes[i].hp)
		c.enemies[i].block = 0
		c.enemies[i].intent = {"kind": String(foes[i].get("kind", "attack")), "value": int(foes[i].get("value", 5))}
	c.dice_values.assign(values)
	c.rerolls_left = rerolls
	c.locked.fill(false)
	c.marked.fill(false)
	c.rerolled.fill(false)
	c.target = 0
	f.run.block = 0
	return f

## Applies decisions until the attack (or `max_steps`); returns the commands taken.
func _steps(f: GameFlow, max_steps := 20) -> Array:
	var out: Array = []
	var rules := AutoRules.new()
	for k in max_steps:
		var d := Bot.decide(f, rules)
		out.append(d.cmd)
		if d.cmd[0] == "combat_attack" or d.cmd[0] == "combat_reroll":
			return out
		f.apply(d.cmd)
	return out

func test_keeps_three_of_a_kind() -> void:
	var f := _fight(["standard", "standard", "standard", "standard", "standard"], [5, 5, 5, 2, 1], 1,
		[{"id": "brute", "hp": 400}])
	var cmds := _steps(f)
	assert_eq(cmds.back(), ["combat_reroll"], "rerolls")
	assert_eq(f.combat.marked, [false, false, false, true, true] as Array[bool], "keeps the three 5s")

func test_single_steps() -> void:
	var f := _fight(["standard", "standard", "standard", "standard", "standard"], [5, 5, 5, 2, 1], 1,
		[{"id": "brute", "hp": 400}])
	var d := Bot.decide(f, AutoRules.new())
	assert_eq(String(d.cmd[0]), "combat_toggle", "first step marks one die")
	assert_true(String(d.reason).contains("Rerolling 2 dice"), d.reason)
	assert_true(String(d.reason).contains("%"), "reason reports a chance: " + String(d.reason))

func test_respects_locked() -> void:
	var f := _fight(["standard", "standard", "standard", "standard", "standard"], [5, 5, 5, 2, 1], 1,
		[{"id": "brute", "hp": 400}])
	f.combat.locked[3] = true
	var cmds := _steps(f)
	for c in cmds:
		assert_true(c != ["combat_toggle", 3], "never toggles a cursed die")
	assert_eq(f.combat.marked[4], true, "still rerolls the free low die")

func test_attacks_when_no_rerolls() -> void:
	var f := _fight(["standard", "standard", "standard"], [1, 2, 4], 0, [{"id": "brute", "hp": 400}])
	var d := Bot.decide(f, AutoRules.new())
	assert_eq(d.cmd, ["combat_attack"])

func test_keeps_lethal_hand() -> void:
	# 6-6-6 = Three of a Kind 18 x 2.5 = 45 kills the 40 HP brute: no reason to reroll.
	var f := _fight(["standard", "standard", "standard"], [6, 6, 6], 2, [{"id": "brute", "hp": 40, "value": 12}])
	var d := Bot.decide(f, AutoRules.new())
	assert_eq(d.cmd, ["combat_attack"], String(d.reason))

## Kills the enemy with the biggest incoming attack among those it can kill.
func test_targets_killable_biggest_threat() -> void:
	# Pair of 6s: (6+6+1) x 1.5 = 19 damage.
	var f := _fight(["standard", "standard", "standard"], [6, 6, 1], 0, [
		{"id": "skeleton_minion", "hp": 60, "value": 3},
		{"id": "skeleton_minion", "hp": 12, "value": 4},
		{"id": "skeleton_minion", "hp": 15, "value": 11},
	])
	var d := Bot.decide(f, AutoRules.new())
	assert_eq(d.cmd, ["combat_set_target", 2], String(d.reason))
	f.apply(d.cmd)
	d = Bot.decide(f, AutoRules.new())
	assert_eq(d.cmd, ["combat_attack"])

func test_no_kill_hits_biggest_threat() -> void:
	var f := _fight(["standard", "standard"], [1, 2], 0, [
		{"id": "skeleton_minion", "hp": 50, "value": 3},
		{"id": "skeleton_minion", "hp": 50, "value": 12},
	])
	var d := Bot.decide(f, AutoRules.new())
	assert_eq(d.cmd, ["combat_set_target", 1], String(d.reason))

## Unmarks dice the player marked when the plan keeps them.
func test_fixes_player_marks() -> void:
	var f := _fight(["standard", "standard", "standard"], [6, 6, 6], 1, [{"id": "brute", "hp": 400}])
	f.combat.marked[0] = true
	var d := Bot.decide(f, AutoRules.new())
	assert_eq(d.cmd, ["combat_toggle", 0], "unmarks the 6")

func test_wild_die_kept() -> void:
	var f := _fight(["standard", "standard", "standard", "standard"], [6, 6, 2, 3], 1, [{"id": "brute", "hp": 400}], ["", "", "wild", ""])
	_steps(f)
	assert_eq(f.combat.marked[2], false, "never rerolls the Wild die")
	assert_eq(f.combat.marked[3], true, "rerolls the stray 3")

## The bot's fast combo evaluator matches Combo.evaluate exactly (mult, group, values).
func test_fast_combo_matches_combo() -> void:
	var rng := Rng.new(42)
	Bot.clear_cache()
	for k in 4000:
		var n := rng.randi_range(1, 6)
		var vals: Array[int] = []
		var wild: Array[bool] = []
		var pv := PackedInt32Array()
		var wm := 0
		for i in n:
			var v := rng.randi_range(0, 9) if rng.chance(0.3) else rng.randi_range(1, 6)
			vals.append(v)
			pv.append(v)
			var w := rng.chance(0.12)
			wild.append(w)
			if w:
				wm |= 1 << i
		var want := Combo.evaluate(vals, wild)
		var got := Bot._combo(pv, wm)
		var gm := 0
		for g in want.group:
			gm |= 1 << int(g)
		if float(got[0]) != float(want.mult) or int(got[1]) != gm or Array(got[2]) != Array(want.values) or String(got[4]) != String(want.id):
			assert_true(false, "mismatch %s wild %s: want %s %s %s got %s" % [str(vals), str(wild), want.id, str(want.group), str(want.values), str(got)])
			return

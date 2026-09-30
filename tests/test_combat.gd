extends "res://tests/test_case.gd"

var run: RunState
var c: CombatState

## Sets up a knight with plain dice (runes given) against `ids`.
func _setup(runes: Array, ids: Array = ["skeleton_minion"], boss := false) -> void:
	run = RunState.create("knight", 1)
	run.dice.clear()
	for r in runes:
		run.dice.append(Die.make(r))
	c = CombatState.new()
	c.begin(run, ids, false, boss, 3)
	for e in c.enemies:
		e.hp = 100
		e.max_hp = 100
		e.intent = {"kind": "aim", "value": 0}

func _dice(values: Array) -> void:
	c.dice_values.assign(values)

func _types(ev: Array) -> Array:
	var out := []
	for e in ev:
		out.append(e.type)
	return out

func _first(ev: Array, type: String) -> Dictionary:
	for e in ev:
		if e.type == type:
			return e
	return {}

func _all(ev: Array, type: String) -> Array:
	var out := []
	for e in ev:
		if e.type == type:
			out.append(e)
	return out

func test_begin_emits_start_events() -> void:
	run = RunState.create("knight", 1)
	c = CombatState.new()
	var ev := c.begin(run, ["skeleton_minion", "skeleton_archer"], false, false, 3)
	var t := _types(ev)
	assert_eq(t[0], "combat_started")
	assert_true(t.has("enemy_intent"))
	assert_true(t.has("combat_turn_started"))
	assert_true(t.has("dice_rolled"))
	assert_eq(c.enemies.size(), 2)
	assert_eq(c.enemies[0].hp, int(round(12 * Balance.enemy_scale(1))), "lap1 minion hp")
	assert_eq(c.turn, 1)
	assert_eq(c.rerolls_left, 2)
	assert_eq(c.dice_values.size(), 2)
	var dr := _first(ev, "dice_rolled")
	assert_eq(dr.context, "combat")
	assert_eq(dr.values.size(), 2)

func test_enemy_scaling() -> void:
	run = RunState.create("knight", 1)
	run.act = 2
	run.lap = 3
	c = CombatState.new()
	c.begin(run, ["skeleton_warrior"], false, false, 3)
	# warrior base 20 scaled by lap 3, then by the biome's enemy HP
	assert_eq(c.enemies[0].hp, int(round(int(round(20 * Balance.enemy_scale(3))) * BiomeDefs.enemy_hp(run.biome()))))
	assert_near(Balance.enemy_scale(1), Balance.ENEMY_BASE_SCALE)
	assert_true(Balance.enemy_scale(15) > Balance.enemy_scale(7), "scales smoothly by lap")

func test_damage_formula_pair() -> void:
	_setup(["", "", ""])
	_dice([2, 2, 5])
	var ev := c.attack(run)
	var combo := _first(ev, "combo")
	assert_eq(combo.name, "Pair")
	assert_eq(combo.total, 13, "(2+2+5)*1.5 = 13")
	var dmg := _first(ev, "damage")
	assert_eq(dmg.target, 0)
	assert_eq(dmg.amount, 13)
	assert_eq(dmg.hp, 87)
	assert_eq(c.enemies[0].hp, 87)

func test_hero_atk_is_flat() -> void:
	_setup(["", "", ""])
	run.atk = 3
	_dice([2, 2, 5])
	var ev := c.attack(run)
	assert_eq(_first(ev, "combo").total, 16)

func test_heavy_doubles_pips() -> void:
	_setup(["heavy", "", ""])
	_dice([2, 2, 5])
	var ev := c.attack(run)
	assert_eq(_first(ev, "combo").total, 16, "(4+2+5)*1.5: Heavy in the scoring pair")

func test_heavy_only_in_group() -> void:
	_setup(["", "", "heavy"])
	_dice([2, 2, 5])
	var ev := c.attack(run)
	assert_eq(_first(ev, "combo").total, 13, "(2+2+5)*1.5: Heavy outside the group does nothing")
	assert_true(_first(ev, "rune_fired").is_empty(), "no Heavy event outside the group")

func test_heavy_caps_at_two_dice() -> void:
	_setup(["heavy", "heavy", "heavy"])
	_dice([3, 3, 3])
	var ev := c.attack(run)
	assert_eq(_first(ev, "combo").total, 37, "(6+6+3)*2.5: only HEAVY_MAX=2 Heavy dice double")

func test_only_one_wild_die_counts() -> void:
	_setup(["wild", "wild", ""])
	_dice([1, 1, 5])
	var cb := c.current_combo(run)
	assert_eq(String(cb.id), "pair", "one Wild pairs with the 5; the second Wild is a plain 1")

func test_blade_only_in_group() -> void:
	_setup(["blade", "", ""])
	_dice([2, 2, 5])
	assert_eq(_first(c.attack(run), "combo").total, 16, "(9+2)*1.5 = 16.5")
	_setup(["", "", "blade"])
	_dice([2, 2, 5])
	assert_eq(_first(c.attack(run), "combo").total, 13, "blade out of group")

func test_echo_adds_half_mult() -> void:
	_setup(["echo", "", ""])
	_dice([2, 2, 5])
	var combo := _first(c.attack(run), "combo")
	assert_near(combo.mult, 2.0)
	assert_eq(combo.total, 18)

func test_guard_block_absorbs() -> void:
	_setup(["guard", "", ""])
	c.enemies[0].intent = {"kind": "attack", "value": 6}
	_dice([4, 1, 3])
	var hp0 := run.hp
	var ev := c.attack(run)
	var bg := _first(ev, "block_gained")
	assert_eq(bg.target, "hero")
	assert_eq(bg.amount, 4)
	var hit: Dictionary = {}
	for e in _all(ev, "damage"):
		if e.target is String and e.target == "hero":
			hit = e
	assert_eq(hit.blocked, 4)
	assert_eq(hit.amount, 2)
	assert_eq(run.hp, hp0 - 2)
	assert_eq(run.block, 0, "block reset at start of next turn")

func test_enemy_block_absorbs() -> void:
	_setup(["", "", ""])
	c.enemies[0].block = 5
	_dice([2, 2, 5])
	var dmg := _first(c.attack(run), "damage")
	assert_eq(dmg.blocked, 5)
	assert_eq(dmg.amount, 8)

func test_venom_poison_and_tick() -> void:
	_setup(["venom", "", ""])
	_dice([2, 2, 5])
	var ev := c.attack(run)
	# 13 attack, poison 2 applied, ticks 2 at enemy action, stacks -> 1
	assert_eq(c.enemies[0].hp, 100 - 13 - 2)
	assert_eq(c.enemies[0].poison, 1)
	var sources := []
	for e in _all(ev, "damage"):
		sources.append(e.source)
	assert_true(sources.has("poison"))

func test_poison_tick_can_kill_and_win() -> void:
	_setup(["", "", ""])
	c.enemies[0].hp = 20
	c.enemies[0].poison = 15
	_dice([1, 2, 4]) # high roller 4 -> 7 dmg
	var ev := c.attack(run)
	assert_eq(c.result, "won")
	assert_true(_types(ev).has("enemy_died"))
	assert_true(_types(ev).has("combat_won"))

func test_ember_hits_all_on_six() -> void:
	_setup(["ember", "", ""], ["skeleton_minion", "skeleton_minion"])
	_dice([6, 1, 3])
	c.attack(run)
	# target: 10 (high roller 6+1+3=10) + 6; other: 6
	assert_eq(c.enemies[0].hp, 100 - 10 - 6)
	assert_eq(c.enemies[1].hp, 100 - 6)

func test_ember_no_fire_without_six() -> void:
	_setup(["ember", "", ""], ["skeleton_minion", "skeleton_minion"])
	_dice([5, 1, 3])
	c.attack(run)
	assert_eq(c.enemies[1].hp, 100)

func test_frost_freezes_target() -> void:
	_setup(["frost", "", ""])
	c.enemies[0].intent = {"kind": "attack", "value": 9}
	_dice([1, 3, 5])
	var hp0 := run.hp
	var ev := c.attack(run)
	assert_eq(run.hp, hp0, "frozen enemy skipped its attack")
	assert_eq(c.enemies[0].frozen, false, "frozen consumed")
	var st := _all(ev, "status")
	assert_true(st.size() >= 2)

func test_thunder_on_reroll() -> void:
	_setup(["thunder", "", ""])
	_dice([1, 3, 5])
	c.rerolled[0] = true
	var ev := c.attack(run)
	var fired := false
	for e in _all(ev, "rune_fired"):
		if e.rune == "thunder":
			fired = true
	assert_true(fired)
	assert_eq(c.enemies[0].hp, 100 - 9 - 1)
	_setup(["thunder", "", ""])
	_dice([1, 3, 5])
	c.attack(run)
	assert_eq(c.enemies[0].hp, 100 - 9, "no thunder when kept")

func test_lucky_banks_reroll() -> void:
	_setup(["lucky", "", ""])
	_dice([1, 3, 5])
	var ev := c.attack(run)
	assert_eq(c.rerolls_left, 3, "2 + 1 banked")
	assert_eq(run.banked_rerolls, 0)
	var ct := _first(ev, "combat_turn_started")
	assert_eq(ct.rerolls_left, 3)

func test_lucky_not_when_rerolled_and_cap() -> void:
	_setup(["lucky", "", ""])
	_dice([1, 3, 5])
	c.rerolled[0] = true
	c.attack(run)
	assert_eq(c.rerolls_left, 2)
	_setup(["lucky", "lucky", "lucky"])
	_dice([1, 3, 5])
	c.attack(run)
	assert_eq(c.rerolls_left, 4, "max +2 banked")

func test_vampire_heals_on_kill() -> void:
	_setup(["vampire", "", ""], ["skeleton_minion", "skeleton_minion"])
	run.hp = 30
	c.enemies[0].hp = 5
	_dice([4, 4, 1])
	var ev := c.attack(run)
	assert_eq(run.hp, 34)
	var hc := _first(ev, "hp_changed")
	assert_eq(hc.amount, 4)
	assert_eq(hc.source, "vampire")

func test_vampire_no_heal_without_kill() -> void:
	_setup(["vampire", "", ""])
	run.hp = 30
	_dice([4, 4, 1])
	var ev := c.attack(run)
	assert_eq(run.hp, 30, "no kill, no lifesteal")
	assert_true(_first(ev, "rune_fired").is_empty())

func test_rune_stack_cap_blade() -> void:
	# three Blade dice in a Three of a Kind: only RUNE_STACK_MAX (2) add their pips
	_setup(["blade", "blade", "blade"])
	_dice([4, 4, 4])
	var ev := c.attack(run)
	assert_eq(Balance.RUNE_STACK_MAX, 2)
	assert_eq(_first(ev, "combo").total, int((12 + 8) * 2.5), "(12 + 2 blades x4) x2.5")
	assert_eq(_all(ev, "rune_fired").size(), 2)

func test_rune_stack_cap_guard() -> void:
	_setup(["guard", "guard", "guard"])
	run.block = 0
	_dice([5, 3, 6])
	var ev := c.attack(run)
	var got := 0
	for e in _all(ev, "rune_fired"):
		got += int(e.value)
	assert_eq(got, 8, "first two Guard dice in pool order: 5 + 3")

func test_rune_active_mask() -> void:
	_setup(["blade", "ember", "blade", "ember", "ember"])
	_dice([6, 6, 6, 2, 6])
	var combo := c.current_combo(run)
	var act := c.rune_active(run, combo.group, combo.values)
	assert_eq(act, [true, true, true, false, true] as Array[bool], "4-kind of 6s: both Blades, the Embers showing 6 (max 2 act)")

func test_gilded_combo_gold() -> void:
	_setup(["gilded", "", ""])
	run.gold = 0
	_dice([4, 4, 1])
	c.attack(run)
	assert_eq(run.gold, 2)

func test_wild_in_combat() -> void:
	_setup(["", "", "wild"])
	_dice([6, 6, 1])
	var combo := _first(c.attack(run), "combo")
	assert_eq(combo.name, "Three of a Kind")
	assert_eq(combo.total, 45, "(6+6+6)*2.5")

func test_toggle_and_reroll() -> void:
	_setup(["", "", ""])
	var ev := c.toggle(1)
	assert_eq(ev[0].type, "die_marked")
	assert_eq(ev[0].marked, true)
	ev = c.reroll(run)
	assert_eq(ev[0].type, "dice_rolled")
	assert_eq(ev[0].indices, [1])
	assert_eq(c.rerolls_left, 1)
	assert_eq(c.rerolled[1], true)
	assert_eq(c.marked[1], false)
	assert_eq(c.reroll(run)[0].type, "error", "nothing marked")
	c.toggle(0)
	c.reroll(run)
	assert_eq(c.rerolls_left, 0)
	assert_eq(c.toggle(2)[0].type, "error", "no rerolls left")

func test_curse_locks_die_next_turn() -> void:
	_setup(["", "", ""], ["cultist"])
	c.enemies[0].intent = {"kind": "curse", "value": 1}
	_dice([1, 3, 5])
	var ev := c.attack(run)
	var n := 0
	var locked_idx := -1
	for i in c.locked.size():
		if c.locked[i]:
			n += 1
			locked_idx = i
	assert_eq(n, 1, "one die locked")
	assert_eq(c.toggle(locked_idx)[0].type, "error")
	assert_eq(_first(ev, "combat_turn_started").locked, [locked_idx])

func test_set_target() -> void:
	_setup(["", "", ""], ["skeleton_minion", "skeleton_minion"])
	assert_eq(c.set_target(1)[0].type, "target_changed")
	assert_eq(c.target, 1)
	c.enemies[0].hp = 0
	assert_eq(c.set_target(0)[0].type, "error")
	assert_eq(c.set_target(5)[0].type, "error")

func test_retarget_after_death() -> void:
	_setup(["", "", ""], ["skeleton_minion", "skeleton_minion"])
	c.enemies[0].hp = 5
	_dice([1, 3, 5])
	c.attack(run)
	assert_eq(c.target, 1)

func test_buff_increases_future_attacks() -> void:
	_setup(["", "", ""], ["bandit"])
	c.enemies[0].intent = {"kind": "buff", "value": 2}
	c.enemies[0].step = 0 # next cycle entry: attack 7
	_dice([1, 3, 5])
	c.attack(run)
	assert_eq(c.enemies[0].atk_bonus, 2)
	# bandit cycle next is attack 7 (+2)
	assert_eq(c.enemies[0].intent.kind, "attack")
	assert_eq(c.enemies[0].intent.value, int(round(7 * Balance.enemy_scale(1))) + 2)

func test_enemy_block_intent_and_reset() -> void:
	_setup(["", "", ""], ["skeleton_warrior"])
	c.enemies[0].intent = {"kind": "block", "value": 6}
	_dice([1, 3, 5])
	c.attack(run)
	assert_eq(c.enemies[0].block, 6)

func test_boss_phase_and_summon() -> void:
	run = RunState.create("knight", 1)
	run.dice.append(Die.new())
	c = CombatState.new()
	c.begin(run, ["boss_bone_warden"], false, true, 0)
	assert_eq(c.enemies[0].hp, int(EnemyDefs.BOSSES.boss_bone_warden.hp), "bosses are not scaled")
	assert_eq(c.enemies[0].boss, true)
	c.enemies[0].hp = 120
	c.enemies[0].max_hp = 120
	c.enemies[0].intent = {"kind": "summon", "value": 1}
	c.dice_values.assign([6, 6, 6]) # three 6s = 45
	var ev := c.attack(run)
	assert_eq(c.enemies[0].hp, 75)
	assert_true(_types(ev).has("summon"))
	assert_eq(c.enemies.size(), 2)
	assert_eq(c.enemies[1].id, "skeleton_warrior", "the Warden raises warriors")
	c.dice_values.assign([6, 6, 6])
	c.target = 0
	ev = c.attack(run)
	var bp := _first(ev, "boss_phase")
	assert_eq(bp.phase, 2)
	assert_eq(c.enemies[0].phase, 2)

func test_lich_chaos_and_restore() -> void:
	run = RunState.create("knight", 1)
	c = CombatState.new()
	c.begin(run, ["boss_lich"], false, true, 0)
	c.enemies[0].intent = {"kind": "chaos", "value": 1}
	c.dice_values.assign([1, 2, 4])
	var ev := c.attack(run)
	var st := {}
	for e in _all(ev, "status"):
		if e.status == "chaos":
			st = e
	assert_true(not st.is_empty(), "chaos fired")
	assert_eq(run.dice[st.die_idx].faces[st.face_idx], 1)
	assert_eq(c.chaos.size(), 1)
	var orig: int = c.chaos[0].value
	c.enemies[0].hp = 1
	c.enemies[0].block = 0
	c.dice_values.assign([1, 2, 4])
	c.attack(run)
	assert_eq(c.result, "won")
	assert_eq(run.dice[st.die_idx].faces[st.face_idx], orig, "restored after fight")

func test_win_rewards() -> void:
	run = RunState.create("knight", 1)
	c = CombatState.new()
	c.begin(run, ["skeleton_minion", "skeleton_archer"], false, false, 3)
	for e in c.enemies:
		e.hp = 1
	c.dice_values.assign([6, 6, 6])
	c.enemies[1].hp = 0
	var ev := c.attack(run)
	var w := _first(ev, "combat_won")
	assert_eq(w.gold, 9)
	assert_eq(w.xp, 7)
	assert_eq(c.result, "won")

func test_lose() -> void:
	_setup(["", "", ""])
	run.hp = 3
	c.enemies[0].intent = {"kind": "attack", "value": 5}
	_dice([1, 3, 5])
	var ev := c.attack(run)
	assert_eq(c.result, "lost")
	assert_eq(run.hp, 0)
	var last_dmg: Dictionary = _all(ev, "damage").back()
	assert_eq(last_dmg.target, "hero")
	assert_eq(last_dmg.lethal, true)
	assert_true(not _types(ev).has("combat_turn_started"), "no new turn after death")

func test_round_trip_mid_combat() -> void:
	_setup(["venom", "lucky", ""], ["cultist", "skeleton_archer"])
	_dice([2, 2, 5])
	c.attack(run)
	c.toggle(0)
	var d := c.to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d))
	var c2 := CombatState.from_dict(parsed)
	assert_eq(JSON.stringify(c2.to_dict()), JSON.stringify(d))

func test_enemy_block_reset_emits_event() -> void:
	_setup(["", "", ""], ["skeleton_warrior"])
	c.enemies[0].block = 7
	c.enemies[0].poison = 2
	c.enemies[0].intent = {"kind": "attack", "value": 1}
	var ev := c._enemy_phase(run)
	var bg := {}
	var bg_i := -1
	var dmg_i := -1
	for k in ev.size():
		if ev[k].type == "block_gained" and bg_i < 0:
			bg = ev[k]
			bg_i = k
		if ev[k].type == "damage" and str(ev[k].source) == "poison" and dmg_i < 0:
			dmg_i = k
	assert_eq(bg, {"type": "block_gained", "target": 0, "amount": -7, "total": 0})
	assert_true(bg_i >= 0 and bg_i < dmg_i, "block reset before poison tick")
	# no event when there was no block
	_setup(["", "", ""], ["skeleton_warrior"])
	c.enemies[0].intent = {"kind": "attack", "value": 1}
	assert_true(not _types(c._enemy_phase(run)).has("block_gained"))

func test_chaos_restore_emits_face_changed() -> void:
	run = RunState.create("knight", 1)
	c = CombatState.new()
	c.begin(run, ["skeleton_minion"], false, false, 0)
	c.chaos.append({"die": 1, "face": 5, "value": run.dice[1].faces[5]})
	var orig: int = run.dice[1].faces[5]
	run.dice[1].faces[5] = 1
	c.enemies[0].hp = 1
	c.enemies[0].block = 0
	c.dice_values.assign([6, 6, 6])
	var ev := c.attack(run)
	assert_eq(c.result, "won")
	var fc := _first(ev, "face_changed")
	assert_eq(fc, {"type": "face_changed", "die_idx": 1, "face_idx": 5, "value": orig, "faces": Array(run.dice[1].faces)})

func test_summon_at_cap_blocks_immediately() -> void:
	run = RunState.create("knight", 1)
	run.dice.append(Die.new())
	c = CombatState.new()
	c.begin(run, ["boss_bone_warden"], false, true, 0)
	for k in 3:
		c.enemies.append(CombatState.make_enemy(run.rng, "skeleton_minion", 1, 1, false, true))
	c.enemies[0].step = 2 # next pattern entry: summon
	c.roll_intent(run.rng, 0)
	assert_eq(c.enemies[0].intent, {"kind": "block", "value": 8})
	assert_eq(c.enemies[0].step, 3, "step still advances by one")

func test_combat_started_carries_intents() -> void:
	run = RunState.create("knight", 1)
	c = CombatState.new()
	var ev := c.begin(run, ["boss_bone_warden"], false, true, 0)
	var cs := _first(ev, "combat_started")
	assert_eq(cs.enemies[0].intent, {"kind": "attack", "value": 20})
	assert_true(_types(ev).has("enemy_intent"))

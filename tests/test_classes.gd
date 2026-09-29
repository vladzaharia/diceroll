extends "res://tests/test_case.gd"
## New hero classes (docs/design/2026-09-28-classes-enemies-skins.md §1): HeroDefs fields,
## Die.tags, ClassLogic hooks and the class_triggered event.

const P := GameFlow.Phase

var run: RunState
var c: CombatState

func _types(ev: Array) -> Array:
	var out := []
	for e in ev:
		out.append(e.type)
	return out

func _all(ev: Array, type: String, id := "") -> Array:
	var out := []
	for e in ev:
		if e.type == type and (id == "" or String(e.get("id", "")) == id):
			out.append(e)
	return out

## `cls` run with the given dice ([kind, rune] pairs) against `ids` (tough, passive enemies).
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

# ================================================================ shared

func test_hero_defs_have_the_new_fields() -> void:
	for id in HeroDefs.IDS:
		var d: Dictionary = HeroDefs.DATA[id]
		for k in ["kinds", "tags", "combat_rerolls", "mechanic", "style"]:
			assert_true(d.has(k), "%s has %s" % [id, k])
		assert_eq((d.kinds as Array).size(), (d.runes as Array).size(), id + " kinds parallel runes")
		assert_eq((d.tags as Array).size(), (d.runes as Array).size(), id + " tags parallel runes")
		for k in d.kinds:
			assert_true(DiceKinds.DEFS.has(String(k)), "%s kind %s" % [id, k])
		var g := GameFlow.new_run(id, 3)
		assert_eq(g.run.combat_rerolls, int(d.combat_rerolls), id + " rerolls")
		for i in g.run.dice.size():
			assert_eq(g.run.dice[i].kind, String(d.kinds[i]), "%s die %d kind" % [id, i])
			assert_eq(g.run.dice[i].has_tag(String(d.tags[i])), String(d.tags[i]) != "", "%s die %d tag" % [id, i])
	for id in ["knight", "barbarian", "mage", "rogue"]:
		assert_eq(HeroDefs.mechanic(id), "", id + " has no class mechanic")
	assert_eq(HeroDefs.IDS.slice(0, 8), ["knight", "barbarian", "paladin", "mage", "ranger", "rogue", "ninja", "druid"])

func test_die_tags_round_trip_and_old_saves() -> void:
	var d := Die.make("", "low")
	d.add_tag("seed")
	d.add_tag("seed")
	assert_eq(Array(d.tags), ["seed"])
	var back := Die.from_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	assert_true(back.has_tag("seed"))
	var old := Die.from_dict({"faces": [1, 2, 3, 4, 5, 6], "rune": "", "kind": "standard"})
	assert_eq(old.tags.size(), 0)
	assert_true(not Die.make().to_dict().has("tags"), "untagged dice keep the old save shape")

func test_old_classes_never_trigger_class_events() -> void:
	for cls in ["knight", "barbarian", "mage", "rogue"]:
		var f := GameFlow.new_run(cls, 11)
		var n := 0
		while not f.is_over() and n < 3000:
			var ev := f.apply(Bot.next_command(f))
			n += 1
			assert_true(_all(ev, "class_triggered").is_empty(), cls + " has no class events")
		assert_true(f.is_over(), cls + " run ends")

func test_new_classes_play_full_runs_and_replay() -> void:
	for cls in ["paladin", "ranger", "ninja", "druid"]:
		var seen := 0
		var f: GameFlow
		for s in [5, 6, 7]:
			f = GameFlow.new_run(cls, s)
			var n := 0
			while not f.is_over() and n < 4000:
				var ev := f.apply(Bot.next_command(f))
				for e in ev:
					assert_true(e.type != "error", "%s: %s" % [cls, str(e)])
				seen += _all(ev, "class_triggered").size()
				n += 1
			assert_true(f.is_over(), cls + " run ends")
		assert_true(seen > 0, cls + " mechanic fired")
		var r := GameFlow.replay(cls, 7, f.commands)
		assert_eq(r.run.hp, f.run.hp, cls + " replay hp")
		assert_eq(r.run.to_dict().dice, f.run.to_dict().dice, cls + " replay dice")

func test_combat_state_serialises_class_fields() -> void:
	_setup("ninja", [["standard", "thunder"], ["odd", ""]])
	c.rerolls_used_this_turn = 2
	c.refunds_this_turn = 1
	c.oath = 4
	var back := CombatState.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.rerolls_used_this_turn, 2)
	assert_eq(back.refunds_this_turn, 1)
	assert_eq(back.oath, 4)

# ================================================================ Paladin

func test_paladin_oath_value() -> void:
	assert_eq(ClassLogic.oath_of([[3, 3, 3, 4, 4, 4], [3, 3, 3, 4, 4, 4]]), 4, "ties go to the higher value")
	assert_eq(ClassLogic.oath_of([[1, 2, 3, 4, 5, 6], [2, 2, 4, 4, 6, 6], [0, 0, 6, 6, 6, 6]]), 6)
	assert_eq(ClassLogic.oath_of([[0, 0, 0, 0, 0, 0]]), 0, "blanks never count")
	assert_eq(ClassLogic.oath_of([[1, 1, 3, 3, 5, 5], [1, 2, 3, 4, 5, 6]]), 5)
	var f := GameFlow.new_run("paladin", 2)
	f.debug_open("combat", "skeleton_minion")
	assert_eq(f.combat.oath, 4, "Twin + Standard: ties go to 4")
	assert_eq(f.run.dice[0].kind, "twin")
	assert_eq(f.run.dice[1].kind, String(HeroDefs.DATA.paladin.kinds[1]))

func test_paladin_oath_pair_worked_example() -> void:
	_setup("paladin", [["twin", ""], ["twin", ""]])
	assert_eq(c.oath, 4)
	_dice([4, 4])
	var ev := c.attack(run)
	var cb: Dictionary = _all(ev, "combo")[0]
	var pips := 2 * ClassLogic.PALADIN_OATH_PIP
	assert_eq(int(cb.total), int(floor((8 + pips) * (1.5 + ClassLogic.PALADIN_OATH_MULT))), "(4+4+pips) x (1.5+mult)")
	var kept := _all(ev, "class_triggered", "oath_kept")
	assert_eq(kept.size(), 1)
	assert_eq(int(kept[0].value), pips)

func test_paladin_oath_ignores_other_sets_and_straights() -> void:
	_setup("paladin", [["twin", ""], ["twin", ""], ["twin", ""]])
	_dice([3, 3, 3])
	var ev := c.attack(run)
	assert_eq(int(_all(ev, "combo")[0].total), int(9 * float(Combo.TABLE.three_kind.mult)), "a Three of 3s is plain")
	assert_true(_all(ev, "class_triggered", "oath_kept").is_empty())
	assert_eq(ClassLogic.oath_bonus(4, "small_straight", [0, 1, 2, 3], [1, 2, 3, 4])[0], 0.0)
	assert_eq(ClassLogic.oath_bonus(4, "high_roller", [0], [4, 4]), [0.0, 0])
	assert_eq(ClassLogic.oath_bonus(4, "two_pair", [0, 1, 2, 3], [4, 4, 6, 6]), [ClassLogic.PALADIN_OATH_MULT, 2 * ClassLogic.PALADIN_OATH_PIP], "either sub-set")
	assert_eq(ClassLogic.oath_bonus(4, "full_house", [0, 1, 2, 3, 4], [2, 2, 2, 4, 4]), [ClassLogic.PALADIN_OATH_MULT, 2 * ClassLogic.PALADIN_OATH_PIP])

func test_paladin_sanctify_at_biome_change() -> void:
	var f := GameFlow.new_run("paladin", 4)
	f.run.dice[1] = Die.make("", "standard")
	var ev := ClassLogic.on_biome(f.run)
	var fc := _all(ev, "face_changed")
	assert_eq(fc.size(), 1)
	assert_eq(fc[0].source, "sanctify")
	assert_eq(int(fc[0].die_idx), 1, "the die with the fewest Oath faces")
	assert_eq(Array(f.run.dice[1].faces), [4, 2, 3, 4, 5, 6], "its lowest non-Oath face becomes the Oath")
	assert_eq(int(f.run.dice[1].edited[0]), 1, "gold rim")
	assert_eq(_all(ev, "class_triggered", "sanctify").size(), 1)
	ClassLogic.on_biome(f.run)
	assert_true(ClassLogic.on_biome(f.run).is_empty(), "two per run")

func test_paladin_shop_weights_twin_and_even() -> void:
	var rng := Rng.new(9)
	var n := {"twin": 0, "even": 0}
	var base := {"twin": 0, "even": 0}
	for k in 4000:
		var a := DiceKinds.random_kind_biased(rng, [], ClassLogic.PALADIN_SHOP_KINDS)
		var b := DiceKinds.random_kind_biased(rng, [], {})
		if n.has(a):
			n[a] += 1
		if base.has(b):
			base[b] += 1
	assert_true(n.twin > base.twin * 1.3, "twin x2: %d vs %d" % [n.twin, base.twin])
	assert_true(n.even > base.even * 1.3, "even x2: %d vs %d" % [n.even, base.even])
	assert_eq(DiceKinds.random_kind_biased(Rng.new(1), ["standard"], ClassLogic.PALADIN_SHOP_KINDS), "standard", "locked kinds stay out")

# ================================================================ Ranger

func test_ranger_aim_without_rerolls() -> void:
	_setup("ranger", [["standard", ""], ["standard", ""]])
	_dice([5, 3])
	var ev := c.attack(run)
	assert_eq(int(_all(ev, "combo")[0].total), int(floor(8 * ClassLogic.aim_mult(2))), "High Roller sums every die")
	assert_eq(_all(ev, "class_triggered", "aim").size(), 1)

func test_ranger_no_aim_after_a_reroll() -> void:
	_setup("ranger", [["standard", ""], ["standard", ""]])
	c.toggle(1)
	c.reroll(run)
	assert_eq(c.rerolls_used_this_turn, 1)
	_dice([5, 3])
	var ev := c.attack(run)
	assert_eq(int(_all(ev, "combo")[0].total), 8)
	assert_true(_all(ev, "class_triggered", "aim").is_empty())
	assert_eq(c.rerolls_used_this_turn, 0, "reset next turn")

func test_ranger_piercing_shot_carries_overkill_once() -> void:
	_setup("ranger", [["standard", ""], ["standard", ""]], ["skeleton_minion", "skeleton_minion", "skeleton_minion"])
	c.enemies[0].hp = 3
	c.enemies[1].hp = 2
	c.enemies[1].block = 1
	c.target = 0
	_dice([6, 6])
	# pair of 6s: 12 x 1.5 = 18 x Aim; the overkill beyond 3 HP carries to enemy 1 (block 1, hp 2) once
	var ev := c.attack(run)
	var ps := _all(ev, "class_triggered", "piercing_shot")
	assert_eq(ps.size(), 1)
	assert_eq(int(ps[0].value), int(floor((int(floor(18 * ClassLogic.aim_mult(2))) - 3) * ClassLogic.RANGER_PIERCE_PCT)))
	assert_eq(int(ps[0].enemy_idx), 1)
	assert_true(not c.alive(1))
	assert_eq(int(c.enemies[2].hp), 100, "only one carry")

func test_ranger_no_carry_when_the_target_lives() -> void:
	_setup("ranger", [["standard", ""]], ["skeleton_minion", "skeleton_minion"])
	_dice([2])
	var ev := c.attack(run)
	assert_true(_all(ev, "class_triggered", "piercing_shot").is_empty())

# ================================================================ Ninja

func test_ninja_starts_with_three_rerolls() -> void:
	_setup("ninja", [["standard", "thunder"], ["odd", ""]])
	assert_eq(c.rerolls_left, 3)

func test_ninja_refunds_matching_rerolls_twice_per_turn() -> void:
	_setup("ninja", [["standard", ""], ["standard", ""], ["standard", ""]])
	# Twin-like fixed dice: make every reroll match by giving the rerolled die only 3s
	run.dice[1].faces = PackedInt32Array([3, 3, 3, 3, 3, 3])
	_dice([3, 5, 6])
	for k in 3:
		c.toggle(1)
		var ev := c.reroll(run)
		if k < 2:
			assert_eq(_all(ev, "class_triggered", "shadow_step").size(), 1, "refund %d" % k)
		else:
			assert_true(_all(ev, "class_triggered", "shadow_step").is_empty(), "max 2 per turn")
	assert_eq(c.rerolls_left, 2, "3 - 3 used + 2 refunded")
	assert_eq(c.refunds_this_turn, 2)

func test_ninja_no_refund_without_a_match_or_on_blank() -> void:
	assert_true(not ClassLogic.rerolled_match([1, 2, 3], [0]))
	assert_true(ClassLogic.rerolled_match([2, 2, 3], [0]))
	assert_true(not ClassLogic.rerolled_match([0, 0, 3], [0]), "blanks never match")
	assert_true(ClassLogic.rerolled_match([5, 1, 5], [2]))

func test_ninja_and_encore_never_double_refund() -> void:
	_setup("ninja", [["standard", ""], ["standard", ""]])
	run.passives.append("encore")
	run.dice[1].faces = PackedInt32Array([3, 3, 3, 3, 3, 3])
	_dice([3, 5])
	c.toggle(1)
	var before := c.rerolls_left
	var ev := c.reroll(run)
	assert_eq(_all(ev, "passive_triggered").size(), 1, "Encore refunds")
	assert_true(_all(ev, "class_triggered", "shadow_step").is_empty(), "Shadow Step does not refund the same reroll")
	assert_eq(c.rerolls_left, before)

func test_ninja_board_reroll_doubles_are_refunded_once() -> void:
	var f := GameFlow.new_run("ninja", 3)
	for d in f.run.dice:
		d.faces = PackedInt32Array([2, 2, 2, 2, 2, 2])
	f.roll_board()
	var left := f.board_rerolls_left
	var ev := f.board_reroll()
	assert_eq(_all(ev, "class_triggered", "shadow_step").size(), 1)
	assert_eq(f.board_rerolls_left, left, "refunded")
	ev = f.board_reroll()
	assert_true(_all(ev, "class_triggered", "shadow_step").is_empty(), "max 1 per board turn")
	assert_eq(f.board_rerolls_left, left - 1)

# ================================================================ Druid

func test_druid_seed_grows_every_lap() -> void:
	var f := GameFlow.new_run("druid", 3)
	assert_true(f.run.dice[0].has_tag("seed"))
	assert_eq(f.run.dice[0].kind, String(HeroDefs.DATA.druid.kinds[0]))
	f.run.dice[0] = Die.make("", "low")
	f.run.dice[0].add_tag("seed")
	var ev := ClassLogic.on_lap(f.run)
	var fc := _all(ev, "face_changed")
	assert_eq(fc.size(), 1)
	assert_eq(fc[0].source, "growth")
	assert_eq(Array(f.run.dice[0].faces), [2, 1, 2, 2, 3, 3])
	assert_eq(Array(f.run.dice[1].faces), [1, 2, 3, 4, 5, 6], "untagged dice don't grow")
	for k in 40:
		ClassLogic.on_lap(f.run)
	assert_eq(Array(f.run.dice[0].faces), [6, 6, 6, 6, 6, 6], "capped at the raise cap")
	assert_true(_all(ClassLogic.on_lap(f.run), "face_changed").is_empty())

func test_druid_blank_face_grows_first() -> void:
	var f := GameFlow.new_run("druid", 3)
	f.run.dice[0].faces = PackedInt32Array([0, 0, 6, 6, 6, 6])
	ClassLogic.on_lap(f.run)
	assert_eq(Array(f.run.dice[0].faces), [1, 0, 6, 6, 6, 6])

func test_druid_lap_completion_in_flow_grows_seeds() -> void:
	var f := GameFlow.new_run("druid", 3)
	f.run.pos = f.run.board.size() - 2
	var before := f.run.dice[0].face_sum()
	var ev := f._move(4, false)
	assert_eq(f.run.dice[0].face_sum(), before + 1)
	assert_eq(_all(ev, "class_triggered", "overgrowth").size(), 1)

func test_druid_new_seed_each_biome_max_three() -> void:
	var f := GameFlow.new_run("druid", 3)
	f.run.dice.append(Die.make("", "high"))
	f.run.dice.append(Die.make("", "odd"))
	var ev := ClassLogic.on_biome(f.run)
	assert_eq(_all(ev, "die_tagged").size(), 1)
	assert_true(f.run.dice[3].has_tag("seed"), "lowest face sum untagged die (Odd)")
	ClassLogic.on_biome(f.run)
	assert_true(f.run.dice[1].has_tag("seed"))
	assert_true(ClassLogic.on_biome(f.run).is_empty(), "max 3 seeds")
	assert_true(not f.run.dice[2].has_tag("seed"))

func test_druid_wild_bond_pet_charge() -> void:
	var p := Profile.fresh(false)
	p.grant("pets", "pumpkin_sprite")
	p.loadout.pet = "pumpkin_sprite"
	var f := GameFlow.new_run("druid", 3, 28, {"profile": p.to_dict()})
	var ev := f.debug_open("combat", "skeleton_minion")
	assert_eq(int(f.run.pet_state.get("charge", 0)), 1)
	assert_eq(_all(ev, "class_triggered", "wild_bond").size(), 1)
	var k := GameFlow.new_run("knight", 3, 28, {"profile": p.to_dict()})
	k.debug_open("combat", "skeleton_minion")
	assert_eq(int(k.run.pet_state.get("charge", 0)), 0)

extends "res://tests/test_case.gd"
## Passive abilities: content, sources, per-passive effects, mini-bosses.

const P := GameFlow.Phase

var run: RunState
var c: CombatState

# ---------------------------------------------------------------- helpers

func _setup(passives: Array, runes: Array = ["", "", ""], ids: Array = ["skeleton_minion"]) -> void:
	run = RunState.create("knight", 1)
	run.max_hp = 70
	run.hp = 70
	run.dice.clear()
	for r in runes:
		run.dice.append(Die.make(r))
	for p in passives:
		run.passives.append(p)
	c = CombatState.new()
	c.begin(run, ids, false, false, 3)
	for e in c.enemies:
		e.hp = 100
		e.max_hp = 100
		e.intent = {"kind": "aim", "value": 0}

func _dice(values: Array) -> void:
	c.dice_values.assign(values)

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

func _triggered(ev: Array, id: String) -> Dictionary:
	for e in ev:
		if e.type == "passive_triggered" and e.id == id:
			return e
	return {}

func _hit(values: Array, passives: Array, runes: Array = []) -> int:
	var r: Array = runes if not runes.is_empty() else []
	if r.is_empty():
		for v in values:
			r.append("")
	_setup(passives, r)
	_dice(values)
	var ev := c.attack(run)
	return int(_first(ev, "combo").total)

func _flow(cls := "knight", s := 1) -> GameFlow:
	var f := GameFlow.new_run(cls, s, 24)
	f.run.max_hp = 70
	f.run.hp = 70
	for i in f.run.board.size():
		if not f.run.board.is_corner(i):
			f.run.board.tiles[i] = Board.make_tile("empty")
	return f

func _force_roll(f: GameFlow, values: Array) -> void:
	f.phase = P.BOARD_ROLLED
	var r: Array[int] = []
	r.assign(values)
	f.board_roll = r

func _win(f: GameFlow) -> Array[Dictionary]:
	for e in f.combat.enemies:
		if e.hp > 0:
			e.hp = 1
			e.block = 0
	var v: Array[int] = []
	for i in f.run.dice.size():
		v.append(6)
	f.combat.dice_values = v
	return f.combat_attack()

func _drain_drafts(f: GameFlow) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	for k in 10:
		if f.phase != P.DRAFT and f.phase != P.FORGE:
			break
		if f.offer.kind == "passive":
			break
		if f.offer.kind == "draft":
			ev.append_array(f.pick_draft(0))
		elif f.offer.kind == "rune_assign":
			ev.append_array(f.rune_assign(0))
		else:
			ev.append_array(f.forge_apply(0, 0, "skip"))
	return ev

# ---------------------------------------------------------------- content

func test_table() -> void:
	assert_eq(Passives.IDS.size(), 32)
	assert_eq(Passives.of_rarity("boss").size(), 8)
	var regular := 0
	for id in Passives.IDS:
		var d: Dictionary = Passives.DEFS[id]
		for k in ["name", "desc", "rarity", "icon"]:
			assert_true(d.has(k), "%s has %s" % [id, k])
		assert_true(["common", "uncommon", "rare", "boss"].has(String(d.rarity)))
		if d.rarity != "boss":
			regular += 1
	assert_eq(regular, 24)
	assert_eq(Passives.DEFS.size(), 32)

func test_regular_rolls_never_boss_and_skip_owned() -> void:
	for s in 60:
		var r := Rng.new(s)
		var got := Passives.roll_regular(r, 3, ["pair_master"])
		assert_eq(got.size(), 3)
		for id in got:
			assert_true(not Passives.is_boss(id), "no boss passive from regular roll")
			assert_true(id != "pair_master", "owned excluded")
		assert_eq(got.size(), {got[0]: 1, got[1]: 1, got[2]: 1}.size(), "distinct")

func test_boss_roll_excludes_owned_and_falls_back() -> void:
	var owned: Array = Passives.of_rarity("boss").slice(0, 7)
	var got := Passives.roll_boss(Rng.new(4), 3, owned)
	assert_eq(got.size(), 3)
	assert_eq(got[0], Passives.of_rarity("boss")[7], "the only boss passive left comes first")
	assert_eq(Passives.rarity(got[1]), "rare", "fallback rare")
	var all_boss := Passives.roll_boss(Rng.new(4), 3, [])
	for id in all_boss:
		assert_true(Passives.is_boss(id))

# ---------------------------------------------------------------- sources

func test_elite_rewards_regular_passive_choice() -> void:
	var f := _flow()
	f.run.board.tiles[3] = Board.make_tile("elite", ["brute"], true)
	_force_roll(f, [3, 3])
	f.choose_move(0)
	assert_eq(f.phase, P.COMBAT)
	_win(f)
	_drain_drafts(f)
	assert_eq(f.offer.kind, "passive")
	assert_eq(f.offer.source, "elite")
	assert_eq(f.offer.options.size(), 3)
	for o in f.offer.options:
		for k in ["id", "label", "desc", "rarity"]:
			assert_true(o.has(k))
		assert_true(not Passives.is_boss(o.id), "elite never gives boss passives")
	var id: String = f.offer.options[1].id
	var ev := f.pick_draft(1)
	assert_true(f.run.passives.has(id))
	assert_eq(_first(ev, "passive_gained").id, id)

func test_boss_tier_never_from_regular_sources() -> void:
	for s in 40:
		var f := _flow("knight", s)
		f.run.gold = 999
		for it in f._shop_stock():
			if it.id == "passive":
				assert_true(not Passives.is_boss(it.passive), "shop passive not boss")
				assert_eq(it.price, int(Balance.PASSIVE_PRICE[Passives.rarity(it.passive)]))
		var ev: Array[Dictionary] = []
		f._open_event(ev, "shrine")
		for ch in f.offer.choices:
			if ch.has("passive"):
				assert_true(not Passives.is_boss(ch.passive), "shrine passive not boss")
		f.phase = P.BOARD_READY
		f._open_passive_choice("elite", ev)
		for o in f.offer.options:
			assert_true(not Passives.is_boss(o.id))

func test_shop_passive_purchase() -> void:
	var f := _flow()
	f.run.gold = 200
	f.phase = P.SHOP
	f.offer = {"kind": "shop", "items": [{"id": "passive", "label": "Thorns", "desc": "", "price": 60, "needs_die": false, "sold": false, "passive": "thorns"}]}
	var ev := f.shop_buy(0)
	assert_true(f.run.passives.has("thorns"))
	assert_eq(f.run.gold, 140)
	assert_eq(_first(ev, "passive_gained").id, "thorns")

func test_shrine_offers_passives() -> void:
	var f := _flow()
	var ev: Array[Dictionary] = []
	f._open_event(ev, "shrine")
	var n := 0
	for ch in f.offer.choices:
		if ch.has("passive"):
			n += 1
	assert_eq(n, 2)
	var id: String = f.offer.choices[0].passive
	var out := f.event_choose(0)
	assert_true(f.run.passives.has(id))
	assert_eq(_first(out, "passive_gained").id, id)

func test_elite_sometimes_offers_boss_tier() -> void:
	var boss_offers := 0
	var regular_offers := 0
	for s in 60:
		var f := _flow("knight", s)
		f.run.xp = 0
		f.run.board.tiles[3] = Board.make_tile("elite", ["brute"], true)
		_force_roll(f, [3, 1])
		f.choose_move(0)
		_win(f)
		_drain_drafts(f)
		assert_eq(f.offer.kind, "passive")
		assert_eq(f.offer.source, "elite")
		var tiers := {}
		for o in f.offer.options:
			tiers[Passives.is_boss(o.id)] = true
		assert_eq(tiers.size(), 1, "one tier per offer")
		if tiers.has(true):
			boss_offers += 1
		else:
			regular_offers += 1
	assert_true(boss_offers > 0, "rare boss-tier elite drop")
	assert_true(regular_offers > boss_offers * 3, "mostly regular (%d vs %d)" % [regular_offers, boss_offers])

func test_final_boss_no_reward() -> void:
	var f := _flow()
	f.run.act = 3
	f.run.lap = Balance.TOTAL_LAPS
	f.run.pos = 22
	_force_roll(f, [2, 2])
	f.choose_move(0)
	assert_eq(f.combat.enemies[0].id, EnemyDefs.FINAL_BOSS)
	_win(f)
	assert_eq(f.phase, P.VICTORY)

func test_passives_round_trip() -> void:
	var f := _flow()
	f.run.passives.assign(["thorns", "phoenix"])
	f.run.passive_state = {"second_wind_used": true, "phoenix_act": 1}
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(f.to_dict()))
	var g := GameFlow.from_dict(parsed)
	assert_eq(Array(g.run.passives), ["thorns", "phoenix"])
	assert_eq(g.run.passive_state.phoenix_act, 1)
	assert_eq(JSON.stringify(g.to_dict()), JSON.stringify(f.to_dict()))

# ---------------------------------------------------------------- combat passives

func test_baseline_damage() -> void:
	assert_eq(_hit([2, 2, 5], []), 13, "pair: 9 x1.5")

func test_pair_master() -> void:
	assert_eq(_hit([2, 2, 5], ["pair_master"]), 18)
	assert_eq(_hit([2, 2, 5, 5], ["pair_master"]), 35, "two pair 14 x2.5")

func test_triple_threat() -> void:
	assert_eq(_hit([5, 5, 5], ["triple_threat"]), 52)

func test_crowd_pleaser() -> void:
	assert_eq(_hit([2, 2, 5], ["crowd_pleaser"]), 22, "pair scores x2.5")
	assert_eq(_hit([2, 2, 5], ["crowd_pleaser", "pair_master"]), 27)

func test_straight_shooter() -> void:
	assert_eq(_hit([1, 2, 3, 4], ["straight_shooter"]), 33)

func test_snake_eyes() -> void:
	assert_eq(_hit([1, 3, 5], ["snake_eyes"]), 14)
	assert_eq(_hit([1, 1, 5], ["snake_eyes"]), 20, "pair of 1s: 7x1.5=10 +10")

func test_boxcars() -> void:
	assert_eq(_hit([6, 6, 2], ["boxcars"]), 30)

func test_gold_tooth() -> void:
	_setup(["gold_tooth"])
	var g := run.gold
	_dice([6, 6, 2])
	var ev := c.attack(run)
	assert_eq(run.gold, g + 2)
	assert_eq(_triggered(ev, "gold_tooth").value, 2)

func test_steady_hand() -> void:
	assert_eq(_hit([1, 3, 5], ["steady_hand"]), 12)
	_setup(["steady_hand"])
	_dice([1, 3, 5])
	c.rerolled[0] = true
	assert_eq(int(_first(c.attack(run), "combo").total), 11)

func test_loaded_hands() -> void:
	_setup(["loaded_hands"])
	assert_eq(c.rerolls_left, 3)
	_dice([1, 3, 5])
	c.attack(run)
	assert_eq(c.rerolls_left, 2, "only the first turn")

func test_rune_echo_sometimes_doubles() -> void:
	var doubled := 0
	var single := 0
	for s in 40:
		_setup(["rune_echo"], ["blade", "", ""])
		run.rng = Rng.new(s)
		_dice([6, 6, 1])
		var ev := c.attack(run)
		var total := int(_first(ev, "combo").total)
		if total == 37:
			doubled += 1
			assert_true(not _triggered(ev, "rune_echo").is_empty())
		else:
			assert_eq(total, 28)
			single += 1
	assert_true(doubled > 0 and single > doubled, "about 25%% doubles (%d/%d)" % [doubled, single])

func test_resonance() -> void:
	assert_eq(_hit([6, 6, 1], [], ["blade", "", ""]), 28, "13 + 6 blade = 19 x1.5")
	assert_eq(_hit([6, 6, 1], ["resonance"], ["blade", "", ""]), 37, "13 + 12 = 25 x1.5")
	_setup(["resonance"], ["guard", "", ""])
	_dice([4, 4, 1])
	var ev := c.attack(run)
	var gained := 0
	for e in _all(ev, "block_gained"):
		if e.target == "hero" and e.amount > 0:
			gained += int(e.amount)
	assert_eq(gained, 8, "guard in combo fires twice")

func test_thorns() -> void:
	_setup(["thorns"])
	c.enemies[0].intent = {"kind": "attack", "value": 5}
	_dice([1, 3, 5])
	var ev := c.attack(run)
	assert_eq(c.enemies[0].hp, 100 - 9 - 3)
	assert_eq(_triggered(ev, "thorns").value, 3)

func test_iron_skin() -> void:
	_setup(["iron_skin"])
	assert_eq(run.block, 3)
	c.enemies[0].intent = {"kind": "attack", "value": 5}
	_dice([1, 3, 5])
	c.attack(run)
	assert_eq(run.hp, 68)
	assert_eq(run.block, 3, "fresh block on the next turn")

func test_bloodthirst() -> void:
	_setup(["bloodthirst"])
	run.hp = 50
	c.enemies[0].hp = 5
	_dice([1, 3, 5])
	var ev := c.attack(run)
	assert_eq(run.hp, 53)
	assert_eq(_triggered(ev, "bloodthirst").value, 3)

func test_opening_salvo() -> void:
	_setup(["opening_salvo"])
	_dice([2, 2, 5])
	assert_eq(int(_first(c.attack(run), "combo").total), 20)
	_dice([2, 2, 5])
	assert_eq(int(_first(c.attack(run), "combo").total), 13, "only the first attack")

func test_glass_cannon() -> void:
	assert_eq(_hit([2, 2, 5], ["glass_cannon"]), 20)
	var f := _flow()
	f.phase = P.DRAFT
	f.offer = {"kind": "passive", "options": [Passives.option("glass_cannon")], "source": "elite"}
	f.pick_draft(0)
	assert_eq(f.run.max_hp, 56)
	assert_eq(f.run.hp, 56)

func test_midas_fist() -> void:
	_setup(["midas_fist"])
	run.gold = 80
	_dice([2, 2, 5])
	assert_eq(int(_first(c.attack(run), "combo").total), 23)
	_setup(["midas_fist"])
	run.gold = 500
	_dice([2, 2, 5])
	assert_eq(int(_first(c.attack(run), "combo").total), 28, "capped at +15")

func test_full_house_party() -> void:
	_setup(["full_house_party"], ["", "", "", "", ""])
	run.hp = 40
	_dice([4, 4, 4, 2, 2])
	var ev := c.attack(run)
	assert_eq(run.hp, 48)
	assert_eq(_triggered(ev, "full_house_party").value, 8)

func test_second_wind_once_per_run() -> void:
	_setup(["second_wind"])
	run.hp = 5
	c.enemies[0].intent = {"kind": "attack", "value": 20}
	_dice([1, 3, 5])
	var ev := c.attack(run)
	assert_eq(run.hp, 1)
	assert_eq(c.result, "")
	assert_true(not _triggered(ev, "second_wind").is_empty())
	assert_eq(run.passive_state.get("second_wind_used", false), true)
	c.enemies[0].intent = {"kind": "attack", "value": 20}
	_dice([1, 3, 5])
	c.attack(run)
	assert_eq(c.result, "lost")

func test_phoenix_recharges_each_act() -> void:
	_setup(["phoenix"])
	run.hp = 5
	c.enemies[0].intent = {"kind": "attack", "value": 20}
	_dice([1, 3, 5])
	c.attack(run)
	assert_eq(run.hp, 1)
	c.enemies[0].intent = {"kind": "attack", "value": 20}
	_dice([1, 3, 5])
	c.attack(run)
	assert_eq(c.result, "lost", "spent this act")
	_setup(["phoenix"])
	run.passive_state = {"phoenix_act": 1}
	run.act = 2
	c.act = 2
	run.hp = 5
	c.enemies[0].intent = {"kind": "attack", "value": 20}
	_dice([1, 3, 5])
	c.attack(run)
	assert_eq(run.hp, 1, "recharged in act 2")

func test_encore_refunds_improving_reroll() -> void:
	_setup(["encore"], ["", ""])
	run.dice[1].faces = PackedInt32Array([6, 6, 6, 6, 6, 6])
	_dice([6, 1])
	var before := c.rerolls_left
	c.toggle(1)
	var ev := c.reroll(run)
	assert_eq(c.dice_values, [6, 6] as Array[int])
	assert_eq(c.rerolls_left, before, "refunded")
	assert_true(not _triggered(ev, "encore").is_empty())
	# no improvement -> spent
	c.toggle(1)
	c.reroll(run)
	assert_eq(c.rerolls_left, before - 1)

func test_scholar() -> void:
	_setup(["scholar"])
	c.enemies[0].hp = 1
	_dice([1, 3, 5])
	c.attack(run)
	assert_eq(c.xp_reward, 4, "3 xp x1.25 -> 4")

# ---------------------------------------------------------------- board & economy passives

func test_double_trouble() -> void:
	var f := _flow()
	f.run.passives.append("double_trouble")
	_force_roll(f, [3, 3])
	var ev := f.choose_move(0)
	assert_eq(f.run.banked_rerolls, 1)
	assert_eq(_triggered(ev, "double_trouble").value, 1)
	_force_roll(f, [2, 3])
	f.choose_move(0)
	assert_eq(f.run.banked_rerolls, 1, "no double no bank")

func test_fast_feet() -> void:
	var f := _flow()
	f.run.passives.append("fast_feet")
	_force_roll(f, [2, 2])
	var ev := f.choose_move(0)
	assert_eq(f.run.pos, 4)
	assert_eq(_all(ev, "hero_moved").size(), 2)
	assert_eq(f.phase, P.BOARD_READY)
	_force_roll(f, [0, 0])
	f.choose_move(0)
	assert_eq(f.run.pos, 4, "blank doubles do nothing")

func test_pathfinder() -> void:
	var f := _flow()
	f.run.passives.append("pathfinder")
	f.roll_board()
	assert_eq(f.board_rerolls_left, 2)

func test_treasure_sense() -> void:
	var seen := false
	for s in 20:
		var f := _flow("knight", s)
		f.run.passives.append("treasure_sense")
		f.run.board.tiles[2] = Board.make_tile("chest")
		_force_roll(f, [2, 2])
		var ev := f.choose_move(0)
		var g := _first(ev, "gold_changed")
		if not g.is_empty() and g.source == "chest":
			seen = true
			assert_true(g.amount >= 18 and g.amount <= 36, "chest gold x1.5 (%d)" % g.amount)
	assert_true(seen)

func test_piggy_bank() -> void:
	var f := _flow()
	f.run.passives.append("piggy_bank")
	f.run.gold = 100
	f.run.pos = 22
	_force_roll(f, [3, 3])
	var ev := f.choose_move(0)
	var g := {}
	for e in ev:
		if e.type == "gold_changed" and e.source == "piggy_bank":
			g = e
	assert_eq(g.amount, 10)
	f.run.gold = 1000
	f.shop_leave()
	f.run.pos = 22
	_force_roll(f, [3, 3])
	ev = f.choose_move(0)
	for e in ev:
		if e.type == "gold_changed" and e.source == "piggy_bank":
			assert_eq(e.amount, 15, "capped")

func test_haggler() -> void:
	var f := _flow()
	f.run.passives.append("haggler")
	var it := f._shop_item("potion", {})
	assert_eq(it.price, 16)

func test_blacksmith_two_edits() -> void:
	var f := _flow()
	f.run.passives.append("blacksmith")
	_force_roll(f, [6, 6])
	f.choose_move(0)
	assert_eq(f.phase, P.FORGE)
	assert_eq(f.offer.uses, 2)
	f.forge_apply(0, 0, "raise")
	assert_eq(f.phase, P.FORGE, "second edit")
	assert_eq(f.offer.uses, 1)
	f.forge_apply(0, 1, "raise")
	assert_eq(f.phase, P.BOARD_READY)
	assert_eq(f.run.dice[0].faces[0], 2)
	assert_eq(f.run.dice[0].faces[1], 3)

func test_collector() -> void:
	var f := _flow()
	f.phase = P.DRAFT
	f.offer = {"kind": "passive", "options": [Passives.option("collector")], "source": "elite"}
	f.pick_draft(0)
	assert_eq(f.run.max_hp, 75, "knight has 1 rune")
	f.phase = P.DRAFT
	f.offer = {"kind": "rune_assign", "rune": "blade"}
	f.rune_assign(1)
	assert_eq(f.run.max_hp, 80)
	f.phase = P.DRAFT
	f.offer = {"kind": "rune_assign", "rune": "frost"}
	f.rune_assign(1)
	assert_eq(f.run.max_hp, 80, "replacing a rune adds nothing")

func test_extra_hand() -> void:
	var f := _flow()
	while f.run.dice.size() < Balance.MAX_DICE:
		f.run.dice.append(Die.new())
	f.phase = P.DRAFT
	f.offer = {"kind": "passive", "options": [Passives.option("extra_hand")], "source": "boss"}
	var ev := f.pick_draft(0)
	assert_eq(f.run.dice.size(), 6)
	assert_eq(f.run.max_dice(), 6)
	assert_true(not _first(ev, "die_added").is_empty())

func test_rune_bloom() -> void:
	var f := _flow()
	f.phase = P.DRAFT
	f.offer = {"kind": "passive", "options": [Passives.option("rune_bloom")], "source": "boss"}
	var ev := f.pick_draft(0)
	for d in f.run.dice:
		assert_true(d.rune != "", "every die has a rune")
	assert_eq(f.run.dice[0].rune, "guard", "existing rune kept")
	assert_eq(_all(ev, "rune_assigned").size(), 1)
	f.run.dice.append(Die.new())
	var ev2: Array[Dictionary] = []
	f.run.lap = 6
	f._new_biome(0, ev2)
	assert_true(f.run.dice[2].rune != "", "blooms again at act start")

func test_pickup_events_for_all() -> void:
	for id in Passives.IDS:
		var f := _flow()
		f.phase = P.DRAFT
		f.offer = {"kind": "passive", "options": [Passives.option(id)], "source": "boss" if Passives.is_boss(id) else "elite"}
		var ev := f.pick_draft(0)
		assert_eq(_first(ev, "passive_gained").id, id)
		assert_true(f.run.has_passive(id))
		assert_eq(f.phase, P.BOARD_READY)

# ---------------------------------------------------------------- mini-bosses

## Walks the hero across Start once, starting at `lap`.
func _cross(f: GameFlow, lap: int) -> Array[Dictionary]:
	f.run.lap = lap
	f.run.act = Balance.act_for_lap(lap)
	f.run.pos = f.run.board.size() - 2
	_force_roll(f, [3, 5])
	var ev := f.choose_move(0)
	if f.phase == P.SHOP:
		ev.append_array(f.shop_leave())
	return ev

func _minis(f: GameFlow) -> Array[int]:
	var out: Array[int] = []
	for i in f.run.board.size():
		if f.run.board.tiles[i].type == "miniboss":
			out.append(i)
	return out

func test_miniboss_spawns_when_lap_7_starts() -> void:
	for s in 25:
		for size in [24, 28, 32]:
			var f := GameFlow.new_run("knight", s, size)
			_cross(f, 5)
			assert_eq(_minis(f).size(), 0, "not in lap 6")
			var ev := _cross(f, 6)
			assert_eq(f.run.lap, 7)
			var m := _minis(f)
			assert_eq(m.size(), 1, "one mini-boss (seed %d size %d)" % [s, size])
			if m.is_empty():
				continue
			var idx: int = m[0]
			var n := f.run.board.size()
			var d := (idx - f.run.pos + n) % n
			assert_true(mini(d, n - d) > 3, "not within 3 tiles of the hero")
			assert_true(not f.run.board.is_corner(idx))
			assert_eq(Array(f.run.board.tiles[idx].enemies), ["mini_pumpkin_knight"], "act 2 biome mini-boss")
			var found := false
			for e in ev:
				if e.type == "board_mutated":
					for ch in e.changes:
						if ch.idx == idx and ch.type == "miniboss":
							found = true
			assert_true(found, "reported in board_mutated")
			_cross(f, 7)
			assert_eq(_minis(f).size(), 1, "persists into lap 8")
			_cross(f, 10)
			assert_eq(f.run.act, 3)
			assert_eq(_minis(f).size(), 0, "gone when lap 11 starts")

func test_miniboss_ids() -> void:
	assert_eq(EnemyDefs.ACT_MINIBOSS, ["mini_bone_champion", "mini_pumpkin_knight", "mini_grave_mage"])
	for id in EnemyDefs.ACT_MINIBOSS:
		assert_true(EnemyDefs.MINIBOSSES.has(id))

func test_miniboss_fight_rewards_boss_passive() -> void:
	var f := _flow()
	f.run.board.tiles[5] = Board.make_tile("miniboss", ["mini_pumpkin_knight"])
	_force_roll(f, [5, 1])
	var ev := f.choose_move(0)
	var cs := _first(ev, "combat_started")
	assert_eq(cs.miniboss, true)
	assert_eq(f.combat.enemies[0].id, "mini_pumpkin_knight")
	assert_true(f.combat.enemies[0].hp > 90, "tanky")
	ev = _win(f)
	assert_true(_first(ev, "combat_won").gold > 0)
	_drain_drafts(f)
	assert_eq(f.offer.kind, "passive")
	assert_eq(f.offer.source, "miniboss")
	for o in f.offer.options:
		assert_eq(o.rarity, "boss")
	f.pick_draft(0)
	assert_eq(f.run.board.tiles[5].enemies.size(), 0, "cleared")

func test_miniboss_vanishes_when_final_boss_starts() -> void:
	var f := _flow()
	f.run.board.tiles[10] = Board.make_tile("miniboss", ["mini_pumpkin_knight"])
	f.run.lap = Balance.TOTAL_LAPS
	f.run.pos = 22
	_force_roll(f, [2, 2])
	var ev := f.choose_move(0)
	assert_eq(f.phase, P.COMBAT)
	assert_eq(f.run.board.tiles[10].type, "empty")
	var found := false
	for e in ev:
		if e.type == "board_mutated":
			for ch in e.changes:
				if ch.idx == 10 and ch.type == "empty":
					found = true
	assert_true(found)

# ---------------------------------------------------------------- run structure (15 laps)

func test_structure_constants() -> void:
	assert_eq(Balance.TOTAL_LAPS, 15)
	assert_eq(Balance.act_for_lap(1), 1)
	assert_eq(Balance.act_for_lap(5), 1)
	assert_eq(Balance.act_for_lap(6), 2)
	assert_eq(Balance.act_for_lap(10), 2)
	assert_eq(Balance.act_for_lap(11), 3)
	assert_eq(Balance.act_for_lap(15), 3)
	var shops: Array = []
	for lap in range(1, 15):
		if Balance.is_shop_lap(lap):
			shops.append(lap)
	assert_eq(shops, [3, 5, 6, 9, 10, 12], "every 3 laps plus biome changes")

func test_lap_completion_without_shop() -> void:
	var f := GameFlow.new_run("knight", 3)
	var ev := _cross(f, 1)
	assert_eq(_first(ev, "lap_completed").lap, 1)
	assert_eq(f.run.lap, 2)
	for e in ev:
		assert_true(not (e.type == "offer_opened" and e.offer.kind == "shop"), "no shop after lap 1")

func test_biome_change_regenerates_board() -> void:
	var f := GameFlow.new_run("knight", 4)
	f.run.max_hp = 100
	f.run.hp = 50
	f.run.lap = 5
	f.run.pos = 26
	_force_roll(f, [4, 4])
	var ev := f.choose_move(0)
	assert_eq(f.run.lap, 6)
	assert_eq(f.run.act, 2)
	assert_eq(f.run.pos, 2, "hero keeps their position")
	var as_ := _first(ev, "act_started")
	assert_eq(as_.act, 2)
	assert_eq(as_.biome, "hollow")
	assert_eq(as_.lap, 6)
	assert_eq(as_.board.tiles.size(), 28)
	assert_eq(_count_type(f, "elite"), 1, "later biomes carry an elite")
	var t := String(f.run.board.tiles[2].type)
	assert_true(t != "enemy" and t != "elite", "landing tile is never a fight")
	var heals := 0
	for e in ev:
		if e.type == "hp_changed" and e.source == "act_start":
			heals = e.amount
	assert_eq(heals, 30, "30% biome heal")
	assert_eq(f.phase, P.SHOP, "shop at biome change")

func _count_type(f: GameFlow, type: String) -> int:
	var n := 0
	for t in f.run.board.tiles:
		if t.type == type:
			n += 1
	return n

func test_no_mid_run_bosses() -> void:
	var f := GameFlow.new_run("knight", 8)
	for lap in range(1, Balance.TOTAL_LAPS):
		var ev := _cross(f, lap)
		for e in ev:
			assert_true(e.type != "combat_started" or not e.boss, "no boss before the last lap")
	var ev := _cross(f, Balance.TOTAL_LAPS)
	assert_eq(f.phase, P.COMBAT)
	assert_eq(f.combat.enemies[0].id, "boss_lich")

extends "res://tests/test_case.gd"

const P := GameFlow.Phase

## Arithmetic in these tests assumes a 70 HP hero, independent of balance tuning.
func _flow(cls := "knight", s := 1) -> GameFlow:
	var f := GameFlow.new_run(cls, s, 24)
	f.run.max_hp = 70
	f.run.hp = 70
	return f

## All non-corner tiles empty so movement tests are predictable.
func _blank(f: GameFlow) -> void:
	for i in 24:
		if not f.run.board.is_corner(i):
			f.run.board.tiles[i] = Board.make_tile("empty")

func _put(f: GameFlow, idx: int, tile: Dictionary) -> void:
	f.run.board.tiles[idx] = tile

## Forces a board roll so the next confirm_move() moves `steps` (one die shows `steps`,
## the rest are blanks, so it is never a double).
func _force_roll(f: GameFlow, steps: int) -> void:
	f.phase = P.BOARD_ROLLED
	var r: Array[int] = [steps]
	for i in range(1, f.run.dice.size()):
		r.append(0)
	f._select_move(r)

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

func _snap(f: GameFlow) -> String:
	return JSON.stringify(f.to_dict())

## Wins the current fight in one attack.
func _win_fight(f: GameFlow) -> Array[Dictionary]:
	for e in f.combat.enemies:
		if e.hp > 0:
			e.hp = 1
			e.block = 0
	f.combat.dice_values.assign([6, 6, 6])
	return f.combat_attack()

func test_new_run_classes() -> void:
	for id in HeroDefs.IDS:
		var g := GameFlow.new_run(id, 1)
		assert_eq(g.run.hp, int(HeroDefs.DATA[id].hp))
		assert_eq(g.run.max_hp, int(HeroDefs.DATA[id].hp))
	var k := GameFlow.new_run("knight", 1)
	assert_eq(k.phase, P.BOARD_READY)
	assert_eq(k.run.dice.size(), 2)
	assert_eq(k.run.dice[0].rune, "guard")
	assert_eq(k.run.act, 1)
	assert_eq(k.run.lap, 1)
	assert_eq(k.run.pos, 0)
	assert_eq(k.run.combat_rerolls, 2)
	var b := _flow("barbarian")
	assert_eq(b.run.atk, 2)
	assert_eq(b.run.dice[0].rune, "heavy")
	var m := _flow("mage")
	assert_eq([m.run.dice[0].rune, m.run.dice[1].rune], ["ember", "echo"])
	var r := _flow("rogue")
	assert_eq(r.run.board_rerolls, 2)
	assert_eq([r.run.dice[0].rune, r.run.dice[1].rune], ["venom", "lucky"])

func test_illegal_commands_error_and_do_not_mutate() -> void:
	var f := _flow()
	var before := _snap(f)
	var calls := [
		func(): return f.board_reroll(),
		func(): return f.choose_move(0),
		func(): return f.combat_toggle(0),
		func(): return f.combat_reroll(),
		func(): return f.combat_set_target(0),
		func(): return f.combat_attack(),
		func(): return f.pick_draft(0),
		func(): return f.shop_buy(0, 0),
		func(): return f.shop_reroll(),
		func(): return f.shop_leave(),
		func(): return f.forge_apply(0, 0, "raise"),
		func(): return f.event_choose(0),
		func(): return f.portal_pick(19),
		func(): return f.rune_assign(0),
	]
	for c in calls:
		var ev: Array = c.call()
		assert_eq(ev.size(), 1)
		assert_eq(ev[0].type, "error")
		assert_true(String(ev[0].msg) != "")
	assert_eq(_snap(f), before, "nothing changed")
	f.roll_board()
	var rolled := _snap(f)
	assert_eq(f.roll_board()[0].type, "error", "cannot roll twice")
	assert_eq(f.combat_attack()[0].type, "error", "not in combat")
	assert_eq(_snap(f), rolled)

func test_roll_board_and_reroll() -> void:
	var f := _flow()
	var ev := f.roll_board()
	assert_eq(f.phase, P.BOARD_ROLLED)
	var dr := _first(ev, "dice_rolled")
	assert_eq(dr.context, "board")
	assert_eq(dr.values.size(), 2)
	var br := _first(ev, "board_rolled")
	assert_eq(br.values, dr.values)
	assert_eq(br.chosen, [0, 1], "a 2-die pool moves both dice")
	assert_eq(br.move, dr.values[0] + dr.values[1])
	assert_eq(br.target, br.move % 24)
	assert_eq(br.targets, [br.target])
	assert_eq(f.landing_preview(), [br.target] as Array[int])
	assert_eq(f.board_reroll()[0].type, "dice_rolled")
	assert_eq(f.board_reroll()[0].type, "error", "only one board reroll for knight")

func test_rogue_two_board_rerolls() -> void:
	var f := _flow("rogue")
	f.roll_board()
	assert_eq(f.board_reroll()[0].type, "dice_rolled")
	assert_eq(f.board_reroll()[0].type, "dice_rolled")
	assert_eq(f.board_reroll()[0].type, "error")

func test_treasury_doubles() -> void:
	for s in 30:
		var f := _flow("knight", s)
		f.run.dice.append(Die.new())
		f.run.dice.append(Die.new())
		var before := f.run.treasury
		var ev := f.roll_board()
		var br := _first(ev, "board_rolled")
		var pv := GameFlow.pair_value_of(f.board_roll, f.board_choice)
		var add := pv * Balance.TREASURY_PAIR_MULT
		assert_eq(br.double, pv > 0)
		assert_eq(br.pair_value, pv)
		assert_eq(br.treasury_added, add)
		assert_eq(f.run.treasury, before + add)

func test_move_to_empty() -> void:
	var f := _flow()
	_blank(f)
	_force_roll(f, 3)
	var ev := f.choose_move(0)
	var hm := _first(ev, "hero_moved")
	assert_eq(hm.path, [1, 2, 3])
	assert_eq(hm.teleport, false)
	assert_eq(f.run.pos, 3)
	assert_eq(f.phase, P.BOARD_READY)
	assert_eq(_first(ev, "tile_triggered").tile_type, "empty")

func test_gilded_move_gold() -> void:
	var f := _flow()
	_blank(f)
	f.run.dice[0].rune = "gilded"
	f.run.gold = 0
	_force_roll(f, 4)
	var ev := f.confirm_move()
	assert_eq(f.run.gold, 4)
	assert_eq(_first(ev, "rune_fired").rune, "gilded")

func test_enemy_fight_win_clears_tile() -> void:
	var f := _flow()
	_blank(f)
	_put(f, 3, Board.make_tile("enemy", ["skeleton_minion"]))
	_force_roll(f, 3)
	var ev := f.choose_move(0)
	assert_eq(f.phase, P.COMBAT)
	assert_true(f.combat != null)
	assert_true(_types(ev).has("combat_started"))
	var gold0 := f.run.gold
	ev = _win_fight(f)
	assert_true(_types(ev).has("combat_won"))
	assert_eq(f.combat, null)
	assert_eq(f.phase, P.BOARD_READY)
	assert_eq(f.run.gold, gold0 + 4)
	assert_eq(f.run.xp, 3)
	assert_eq(f.run.board.tiles[3].enemies.size(), 0, "tile cleared")
	# landing again does not fight
	f.run.pos = 0
	_force_roll(f, 3)
	f.choose_move(0)
	assert_eq(f.phase, P.BOARD_READY)

func test_level_up_drafts_queue() -> void:
	var f := _flow()
	_blank(f)
	_put(f, 3, Board.make_tile("enemy", ["brute"]))
	# brute gives 9 XP: start just below the level-2 threshold so it crosses levels 2 and 3
	f.run.xp = Balance.xp_for_level(2) - 9
	_force_roll(f, 3)
	f.choose_move(0)
	var ev := _win_fight(f)
	var lv := []
	for e in ev:
		if e.type == "level_up":
			lv.append(e.level)
	assert_eq(lv, [2, 3])
	assert_eq(f.phase, P.DRAFT)
	assert_eq(f.offer.kind, "draft")
	assert_eq(f.offer.options.size(), 3)
	# pick until both drafts resolved (handle follow-up modals)
	var guard := 0
	var drafts := 0
	while f.phase != P.BOARD_READY and guard < 10:
		guard += 1
		if f.offer.kind == "draft":
			drafts += 1
			f.pick_draft(0)
		elif f.offer.kind == "rune_assign":
			f.rune_assign(1)
		elif f.offer.kind == "forge":
			f.forge_apply(0, 0, "raise")
	assert_eq(drafts, 2)
	assert_eq(f.phase, P.BOARD_READY)

func _draft_with(f: GameFlow, option: Dictionary) -> void:
	f.phase = P.DRAFT
	f.offer = {"kind": "draft", "options": [option], "source": "level"}

func test_draft_options() -> void:
	var f := _flow()
	_draft_with(f, {"id": "new_die", "label": "", "desc": ""})
	var ev := f.pick_draft(0)
	assert_eq(f.run.dice.size(), 3)
	assert_true(_types(ev).has("die_added"))
	assert_true(_types(ev).has("offer_closed"))
	assert_eq(f.phase, P.BOARD_READY)
	_draft_with(f, {"id": "max_hp", "label": "", "desc": ""})
	f.run.hp = 50
	f.pick_draft(0)
	assert_eq(f.run.max_hp, 78)
	assert_eq(f.run.hp, 58)
	_draft_with(f, {"id": "combat_reroll", "label": "", "desc": ""})
	f.pick_draft(0)
	assert_eq(f.run.combat_rerolls, 3)
	_draft_with(f, {"id": "rune", "label": "", "desc": "", "rune": "blade"})
	f.pick_draft(0)
	assert_eq(f.phase, P.DRAFT)
	assert_eq(f.offer, {"kind": "rune_assign", "rune": "blade"})
	assert_eq(f.pick_draft(0)[0].type, "error", "not a draft offer")
	assert_eq(f.rune_assign(9)[0].type, "error")
	f.rune_assign(2)
	assert_eq(f.run.dice[2].rune, "blade")
	assert_eq(f.phase, P.BOARD_READY)
	_draft_with(f, {"id": "face_raise", "label": "", "desc": ""})
	f.pick_draft(0)
	assert_eq(f.phase, P.FORGE)
	assert_eq(f.forge_apply(0, 0, "mirror", 5)[0].type, "error", "draft forge is raise only")
	f.forge_apply(1, 0, "raise")
	assert_eq(f.run.dice[1].faces[0], 2)
	assert_eq(f.phase, P.BOARD_READY)

func test_draft_generation_respects_caps() -> void:
	var f := _flow()
	for i in 3:
		f.run.dice.append(Die.new())
	f.run.combat_rerolls = 4
	for k in 20:
		var ev: Array[Dictionary] = []
		f.phase = P.BOARD_READY
		f._open_draft(ev)
		for o in f.offer.options:
			assert_true(o.id != "new_die" and o.id != "combat_reroll", "capped options excluded")

func test_pass_start_lap_and_shop() -> void:
	var f := _flow()
	_blank(f)
	f.run.lap = 3 # completing lap 3 opens the shop
	f.run.pos = 22
	f.run.hp = 40
	_force_roll(f, 5)
	var ev := f.choose_move(0)
	assert_eq(_first(ev, "hero_moved").path, [23, 0, 1, 2, 3])
	var lc := _first(ev, "lap_completed")
	assert_eq(lc.lap, 3)
	assert_eq(lc.healed, int(round(70 * Balance.LAP_HEAL_PCT)))
	assert_eq(f.run.lap, 4)
	assert_eq(f.run.pos, 3)
	assert_true(_types(ev).has("board_mutated"))
	assert_eq(f.phase, P.SHOP)
	assert_eq(f.offer.kind, "shop")
	assert_true(f.offer.items.size() >= 3 and f.offer.items.size() <= 4)
	for it in f.offer.items:
		for k in ["id", "label", "desc", "price", "needs_die", "sold"]:
			assert_true(it.has(k), "shop item has " + k)
	# landing tile (3) was protected from mutation and resolves after the shop
	f.shop_leave()
	assert_eq(f.phase, P.BOARD_READY)

func test_land_on_start_opens_shop() -> void:
	var f := _flow()
	_blank(f)
	f.run.lap = 9
	f.run.pos = 20
	_force_roll(f, 4)
	f.choose_move(0)
	assert_eq(f.run.pos, 0)
	assert_eq(f.run.lap, 10)
	assert_eq(f.phase, P.SHOP)
	f.shop_leave()
	assert_eq(f.phase, P.BOARD_READY)

func _shop_with(f: GameFlow, items: Array) -> void:
	f.phase = P.SHOP
	f.offer = {"kind": "shop", "items": items}

func _item(id: String, price: int, needs_die: bool, rune := "") -> Dictionary:
	var d := {"id": id, "label": id, "desc": "", "price": price, "needs_die": needs_die, "sold": false}
	if rune != "":
		d.rune = rune
	return d

func test_shop_purchases() -> void:
	var f := _flow()
	f.run.gold = 300
	_shop_with(f, [_item("die", 40, false), _item("rune", 50, true, "frost"), _item("potion", 20, false),
		_item("face_raise", 25, true), _item("combat_reroll", 90, false)])
	var ev := f.shop_buy(0)
	assert_eq(f.run.dice.size(), 3)
	assert_eq(f.run.gold, 260)
	assert_eq(_first(ev, "gold_changed").amount, -40)
	assert_eq(f.shop_buy(0)[0].type, "error", "sold")
	assert_eq(f.shop_buy(1)[0].type, "error", "rune needs a die")
	f.shop_buy(1, 2)
	assert_eq(f.run.dice[2].rune, "frost")
	f.run.hp = 10
	f.shop_buy(2)
	assert_eq(f.run.hp, 10 + 25, "35% of 70 = 24.5 -> 25")
	f.shop_buy(3, 1)
	assert_eq(f.run.dice[1].faces[0], 2, "lowest face raised")
	f.shop_buy(4)
	assert_eq(f.run.combat_rerolls, 3)
	assert_eq(f.run.shop_reroll_bought, true)
	assert_eq(f.run.gold, 300 - 40 - 50 - 20 - 25 - 90)
	assert_eq(f.phase, P.SHOP)

func test_shop_not_enough_gold_and_restock() -> void:
	var f := _flow()
	f.run.gold = 15
	_shop_with(f, [_item("die", 40, false)])
	var before := _snap(f)
	assert_eq(f.shop_buy(0)[0].type, "error")
	assert_eq(_snap(f), before)
	var ev := f.shop_reroll()
	assert_eq(f.run.gold, 5)
	assert_true(_types(ev).has("offer_opened"))
	assert_eq(f.shop_reroll()[0].type, "error", "cannot afford restock")

func test_forge_tile() -> void:
	var f := _flow()
	_blank(f)
	_force_roll(f, 6)
	var ev := f.choose_move(0)
	assert_eq(f.phase, P.FORGE)
	assert_eq(_first(ev, "offer_opened").offer.kind, "forge")
	assert_eq(f.forge_apply(0, 5, "raise")[0].type, "error", "6 cannot be raised")
	assert_eq(f.forge_apply(0, 0, "mirror", 0)[0].type, "error", "same face")
	ev = f.forge_apply(0, 0, "mirror", 5)
	assert_eq(f.run.dice[0].faces[0], 6)
	assert_eq(f.run.dice[0].edited[0], 1)
	assert_eq(_first(ev, "face_changed").value, 6)
	assert_eq(f.phase, P.BOARD_READY)
	f.phase = P.FORGE
	f.offer = {"kind": "forge", "ops": ["raise", "mirror"], "source": "tile"}
	f.forge_apply(0, 0, "skip")
	assert_eq(f.phase, P.BOARD_READY)

func test_treasury_tile() -> void:
	var f := _flow()
	_blank(f)
	f.run.pos = 8
	f.run.treasury = 34
	f.run.gold = 5
	_force_roll(f, 4)
	f.choose_move(0)
	assert_eq(f.run.gold, 39)
	assert_eq(f.run.treasury, 10)

func test_campfire_and_chest_consumed() -> void:
	var f := _flow()
	_blank(f)
	_put(f, 2, Board.make_tile("campfire"))
	f.run.hp = 20
	_force_roll(f, 2)
	f.choose_move(0)
	assert_eq(f.run.hp, 41, "30% of 70 = 21")
	assert_eq(f.run.board.tiles[2].type, "empty")
	_put(f, 4, Board.make_tile("chest"))
	_force_roll(f, 2)
	var gold0 := f.run.gold
	f.choose_move(0)
	assert_eq(f.run.board.tiles[4].type, "empty")
	assert_true(f.run.gold > gold0 or (f.phase == P.DRAFT and f.offer.options.size() == 3), "gold or rune choice")

func test_trap() -> void:
	for s in 12:
		var f := _flow("knight", s)
		_blank(f)
		_put(f, 2, Board.make_tile("trap"))
		_force_roll(f, 2)
		var ev := f.choose_move(0)
		var t := _first(ev, "trap")
		assert_eq(t.dodged, t.roll >= 4)
		assert_eq(t.damage, 0 if t.dodged else 8)
		assert_eq(f.run.hp, 70 - t.damage)
		assert_eq(f.run.board.tiles[2].type, "trap", "trap persists")

func test_trap_can_kill() -> void:
	var killed := false
	for s in 20:
		var f := _flow("knight", s)
		_blank(f)
		_put(f, 2, Board.make_tile("trap"))
		f.run.hp = 1
		_force_roll(f, 2)
		var ev := f.choose_move(0)
		if not _first(ev, "trap").dodged:
			assert_eq(f.phase, P.GAME_OVER)
			assert_eq(_first(ev, "game_over").victory, false)
			killed = true
	assert_true(killed)

func _event(f: GameFlow, id: String) -> void:
	var ev: Array[Dictionary] = []
	f.phase = P.BOARD_READY
	f._open_event(ev, id)
	assert_eq(f.phase, P.EVENT)
	for k in ["kind", "id", "title", "text", "choices"]:
		assert_true(f.offer.has(k), "event offer has " + k)
	for c in f.offer.choices:
		for k in ["label", "desc", "enabled"]:
			assert_true(c.has(k), "choice has " + k)

func test_event_tile_opens_event() -> void:
	var f := _flow()
	_blank(f)
	_put(f, 3, Board.make_tile("event"))
	_force_roll(f, 3)
	f.choose_move(0)
	assert_eq(f.phase, P.EVENT)
	assert_true(EventDefs.IDS.has(f.offer.id))
	assert_eq(f.run.board.tiles[3].type, "empty", "event consumed")

func test_event_idol() -> void:
	var f := _flow()
	_event(f, "idol")
	f.event_choose(0)
	assert_eq(f.run.hp, 55)
	for d in f.run.dice:
		assert_eq(d.faces[0], 2)
	assert_eq(f.phase, P.BOARD_READY)
	f.run.hp = 10
	_event(f, "idol")
	assert_eq(f.offer.choices[0].enabled, false)
	assert_eq(f.event_choose(0)[0].type, "error", "disabled choice")

func test_event_merchant() -> void:
	var f := _flow()
	_event(f, "merchant")
	f.event_choose(0)
	assert_eq(f.run.max_hp, 63)
	assert_eq(f.run.hp, 63)
	assert_eq(f.phase, P.DRAFT)
	assert_eq(f.offer.kind, "rune_assign")
	assert_eq(Runes.rarity(f.offer.rune), "rare")
	f.rune_assign(1)
	assert_eq(f.phase, P.BOARD_READY)
	_event(f, "merchant")
	f.event_choose(1)
	assert_eq(f.run.max_hp, 63, "decline")

func test_event_outbreak_and_garden() -> void:
	var f := _flow()
	_blank(f)
	f.run.pos = 3
	_event(f, "outbreak")
	var ev := f.event_choose(0)
	for i in [4, 5, 7]:
		assert_eq(f.run.board.tiles[i].type, "enemy", "tile %d" % i)
		assert_true(f.run.board.tiles[i].enemies.size() > 0)
	assert_eq(_first(ev, "board_mutated").changes.size(), 3)
	_event(f, "garden")
	f.event_choose(0)
	for i in [8, 9, 10]:
		assert_eq(f.run.board.tiles[i].type, "chest")

func test_event_duel() -> void:
	for s in 10:
		var f := _flow("knight", s)
		f.run.gold = 30
		_event(f, "duel")
		var ev := f.event_choose(1)
		var d := _first(ev, "duel")
		assert_eq(f.run.gold, 30 + 25 * d.outcome)
	var g := _flow()
	g.run.gold = 5
	_event(g, "duel")
	assert_eq(g.offer.choices[0].enabled, false)
	g.event_choose(2)
	assert_eq(g.run.gold, 5)

func test_event_shrine() -> void:
	var f := _flow()
	_event(f, "shrine")
	assert_eq(f.offer.choices.size(), 2)
	var id: String = f.offer.choices[0].passive
	f.event_choose(0)
	assert_true(f.run.passives.has(id))

func test_event_shrine_falls_back_to_blessings() -> void:
	var f := _flow()
	for id in Passives.IDS:
		if not Passives.is_boss(id):
			f.run.passives.append(id)
	_event(f, "shrine")
	assert_eq(f.offer.choices.size(), 2)
	var b: String = f.offer.choices[0].blessing
	var snap := {"atk": f.run.atk, "max_hp": f.run.max_hp, "gold": f.run.gold}
	f.event_choose(0)
	match b:
		"atk":
			assert_eq(f.run.atk, snap.atk + 1)
		"max_hp":
			assert_eq(f.run.max_hp, snap.max_hp + 10)
		"gold":
			assert_eq(f.run.gold, snap.gold + 15)
		"face":
			var total := 0
			for d in f.run.dice:
				total += d.face_sum()
			assert_eq(total, 21 * 2 + 1)

func test_portal() -> void:
	var f := _flow()
	_blank(f)
	f.run.pos = 14
	_force_roll(f, 4)
	f.choose_move(0)
	assert_eq(f.phase, P.PORTAL)
	assert_eq(f.offer.tiles, [19, 20, 21, 22, 23, 0, 1, 2])
	assert_eq(f.portal_pick(5)[0].type, "error", "out of range")
	var ev := f.portal_pick(21)
	var hm := _first(ev, "hero_moved")
	assert_eq(hm.teleport, true)
	assert_eq(hm.path, [21])
	assert_eq(f.run.pos, 21)
	assert_eq(f.phase, P.BOARD_READY)

func test_portal_across_start() -> void:
	var f := _flow()
	_blank(f)
	f.run.pos = 18
	f.run.lap = 3
	f.phase = P.PORTAL
	f.offer = {"kind": "portal", "tiles": [19, 20, 21, 22, 23, 0, 1, 2]}
	var ev := f.portal_pick(2)
	assert_true(_types(ev).has("lap_completed"))
	assert_eq(f.run.lap, 4)
	assert_eq(f.run.pos, 2)
	assert_eq(f.phase, P.SHOP)

func test_final_lap_completion_starts_boss() -> void:
	var f := _flow()
	_blank(f)
	f.run.lap = Balance.TOTAL_LAPS
	f.run.act = 3
	f.run.pos = 22
	_force_roll(f, 5)
	assert_eq(f.landing_preview()[0], 0, "preview stops on start")
	var ev := f.choose_move(0)
	assert_eq(_first(ev, "hero_moved").path, [23, 0])
	assert_eq(f.run.pos, 0)
	assert_eq(f.phase, P.COMBAT)
	assert_eq(f.combat.boss, true)
	assert_eq(f.combat.enemies[0].id, f.run.boss_id)
	assert_eq(_first(ev, "combat_started").boss, true)
	assert_eq(_first(ev, "lap_completed").lap, 15)

func test_final_boss_victory() -> void:
	var f := _flow()
	_blank(f)
	f.run.act = 3
	f.run.lap = Balance.TOTAL_LAPS
	f.run.pos = 22
	_force_roll(f, 5)
	f.choose_move(0)
	assert_eq(f.combat.enemies[0].id, f.run.boss_id)
	var ev := _win_fight(f)
	assert_eq(f.phase, P.VICTORY)
	var go := _first(ev, "game_over")
	assert_eq(go.victory, true)
	assert_true(go.stats.has("fights_won"))
	assert_eq(f.roll_board()[0].type, "error")

func test_hp_zero_game_over() -> void:
	var f := _flow()
	_blank(f)
	_put(f, 3, Board.make_tile("enemy", ["brute"]))
	_force_roll(f, 3)
	f.choose_move(0)
	f.run.hp = 1
	f.combat.enemies[0].hp = 500
	f.combat.enemies[0].intent = {"kind": "attack", "value": 30}
	f.combat.dice_values.assign([1, 2, 4])
	var ev := f.combat_attack()
	assert_eq(f.phase, P.GAME_OVER)
	assert_eq(_first(ev, "game_over").victory, false)
	assert_eq(f.combat, null)
	assert_eq(f.combat_attack()[0].type, "error")

func test_save_load_mid_combat() -> void:
	var f := _flow("rogue", 77)
	_blank(f)
	_put(f, 3, Board.make_tile("enemy", ["cultist", "skeleton_archer"]))
	_force_roll(f, 3)
	f.choose_move(0)
	f.combat_toggle(0)
	f.combat_reroll()
	var saved := JSON.stringify(f.to_dict())
	var g := GameFlow.from_dict(JSON.parse_string(saved))
	assert_eq(JSON.stringify(g.to_dict()), saved, "round trip identical")
	assert_eq(g.phase, P.COMBAT)
	# both continue identically
	for i in 6:
		if f.phase != P.COMBAT:
			break
		f.combat_attack()
		g.combat_attack()
	assert_eq(JSON.stringify(g.to_dict()), JSON.stringify(f.to_dict()), "continue identically")

func test_bot_run_replay_equality() -> void:
	for cls in HeroDefs.IDS:
		var f := GameFlow.new_run(cls, 1234)
		var errors := 0
		var n := 0
		while not f.is_over() and n < 3000:
			var cmd := Bot.next_command(f)
			var ev := f.apply(cmd)
			n += 1
			if not ev.is_empty() and ev[0].type == "error":
				errors += 1
		assert_eq(errors, 0, "bot issued no illegal commands (%s)" % cls)
		assert_true(f.is_over(), "run finished (%s)" % cls)
		var r := GameFlow.replay(cls, 1234, f.commands)
		assert_eq(JSON.stringify(r.to_dict()), JSON.stringify(f.to_dict()), "replay identical (%s)" % cls)
		var loaded := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
		assert_eq(JSON.stringify(loaded.to_dict()), JSON.stringify(f.to_dict()))

func test_replay_mid_run_and_resume_from_save() -> void:
	# play 150 commands, save, keep playing both the original and the loaded copy
	var f := GameFlow.new_run("mage", 99)
	for i in 150:
		if f.is_over():
			break
		f.apply(Bot.next_command(f))
	var g := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
	for i in 200:
		if f.is_over():
			break
		f.apply(Bot.next_command(f))
		g.apply(Bot.next_command(g))
	assert_eq(JSON.stringify(g.to_dict()), JSON.stringify(f.to_dict()))
	var r := GameFlow.replay("mage", 99, f.commands)
	assert_eq(JSON.stringify(r.to_dict()), JSON.stringify(f.to_dict()))

func test_elite_guarantees_passive_choice() -> void:
	var f := _flow()
	_blank(f)
	_put(f, 3, Board.make_tile("elite", ["brute"], true))
	_force_roll(f, 3)
	f.choose_move(0)
	assert_eq(f.combat.elite, true)
	assert_eq(f.combat.enemies[0].hp, int(round(38 * Balance.ELITE_HP_MULT * Balance.enemy_scale(1))))
	_win_fight(f)
	for k in 6:
		if f.phase == P.DRAFT and f.offer.kind == "passive":
			break
		if f.offer.kind == "draft":
			f.pick_draft(0)
		elif f.offer.kind == "rune_assign":
			f.rune_assign(0)
		elif f.phase == P.FORGE:
			f.forge_apply(0, 0, "skip")
	assert_eq(f.offer.kind, "passive")
	assert_eq(f.offer.source, "elite")
	assert_eq(f.offer.options.size(), 3)

func test_debug_open_scenarios() -> void:
	var expected := {"shop": P.SHOP, "draft": P.DRAFT, "rune_choice": P.DRAFT, "rune_assign": P.DRAFT, "passive": P.DRAFT,
		"forge": P.FORGE, "event": P.EVENT, "portal": P.PORTAL, "combat": P.COMBAT, "boss": P.COMBAT}
	for kind in expected:
		var f := _flow()
		var ev := f.debug_open(kind)
		assert_eq(f.phase, expected[kind], kind)
		assert_true(not ev.is_empty() and ev[0].type != "error", kind)
	var g := _flow()
	g.debug_open("event", "idol")
	assert_eq(g.offer.id, "idol")
	g.debug_open("combat", "brute,cultist")
	assert_eq(g.combat.enemies.size(), 2)
	assert_eq(g.debug_open("nope")[0].type, "error")

func test_illegal_in_other_phases() -> void:
	var f := _flow()
	f.debug_open("shop")
	var before := _snap(f)
	for ev in [f.roll_board(), f.combat_attack(), f.pick_draft(0), f.event_choose(0), f.forge_apply(0, 0, "raise")]:
		assert_eq(ev[0].type, "error")
	assert_eq(_snap(f), before)
	f.debug_open("combat")
	before = _snap(f)
	for ev in [f.roll_board(), f.shop_leave(), f.rune_assign(0), f.portal_pick(19), f.combat_set_target(7)]:
		assert_eq(ev[0].type, "error")
	assert_eq(_snap(f), before)

func test_hero_block_cleared_after_combat_win() -> void:
	var f := _flow()
	_blank(f)
	_put(f, 3, Board.make_tile("enemy", ["skeleton_minion"]))
	_force_roll(f, 3)
	f.choose_move(0)
	f.combat.dice_values.assign([6, 6, 6])
	for e in f.combat.enemies:
		e.hp = 1
		e.block = 0
	f.run.block = 9
	# knight's guard die adds block during the attack; whatever remains must be cleared
	var ev := f.combat_attack()
	assert_eq(f.run.block, 0, "hero block cleared after fight")
	var last := {}
	for e in ev:
		if e.type == "block_gained" and str(e.target) == "hero":
			last = e
	assert_eq(last.get("total", -1), 0, "final hero block event reports 0")
	assert_true(int(last.get("amount", 0)) < 0, "reset amount is negative")

func test_lap_heal_emits_hp_changed() -> void:
	var f := _flow()
	_blank(f)
	f.run.pos = 22
	f.run.hp = 40
	_force_roll(f, 5)
	var ev := f.choose_move(0)
	var hc := {}
	for e in ev:
		if e.type == "hp_changed" and e.source == "lap":
			hc = e
	var heal := int(round(70 * Balance.LAP_HEAL_PCT))
	assert_eq(hc, {"type": "hp_changed", "amount": heal, "total": 40 + heal, "source": "lap", "max_hp": 70})

func test_treasury_payout_reports_reset() -> void:
	var f := _flow()
	_blank(f)
	f.run.pos = 8
	f.run.treasury = 34
	f.run.gold = 5
	_force_roll(f, 4)
	var ev := f.choose_move(0)
	var gc := _first(ev, "gold_changed")
	assert_eq(gc, {"type": "gold_changed", "amount": 34, "total": 39, "source": "treasury", "treasury": Balance.TREASURY_START})

func test_act_started_reports_treasury() -> void:
	var f := _flow()
	var ev: Array[Dictionary] = []
	f.run.treasury = 77
	f.run.lap = 6
	f._new_biome(3, ev)
	assert_eq(_first(ev, "act_started").get("treasury", -1), 77, "the treasury carries over")

func test_portal_final_lap_stops_at_start() -> void:
	var f := _flow()
	_blank(f)
	f.run.lap = Balance.TOTAL_LAPS
	f.run.pos = 14
	_force_roll(f, 4)
	f.choose_move(0)
	assert_eq(f.phase, P.PORTAL)
	assert_eq(f.offer.tiles, [19, 20, 21, 22, 23, 0])
	f.debug_open("portal")
	assert_eq(f.offer.tiles, [19, 20, 21, 22, 23, 0], "debug portal from pos 18")
	var ev := f.portal_pick(0)
	assert_eq(f.phase, P.COMBAT)
	assert_eq(f.combat.boss, true)

# ================================================================ pool, die kinds, board size

func test_start_with_two_dice_max_five() -> void:
	assert_eq(Balance.MAX_DICE, 5)
	var want := {"knight": ["guard", ""], "barbarian": ["heavy", ""], "mage": ["ember", "echo"], "rogue": ["venom", "lucky"]}
	for id in HeroDefs.IDS:
		var g := GameFlow.new_run(id, 1)
		assert_eq(g.run.dice.size(), 2, id + " starts with 2 dice")
		assert_eq([g.run.dice[0].rune, g.run.dice[1].rune], want[id])
	assert_eq(GameFlow.new_run("barbarian", 1).run.atk, 2)

func test_zero_roll_stays_put() -> void:
	var f := _flow()
	_blank(f)
	f.run.pos = 5
	_put(f, 5, Board.make_tile("chest"))
	_force_roll(f, 0)
	assert_eq(f.landing_preview()[0], 5)
	var ev := f.choose_move(0)
	assert_eq(f.run.pos, 5)
	assert_true(not _types(ev).has("hero_moved"), "no hop for a blank")
	assert_true(_types(ev).has("hero_stayed"))
	assert_true(not _types(ev).has("tile_triggered"), "staying does not retrigger the tile")
	assert_eq(f.run.board.tiles[5].type, "chest")
	assert_eq(f.phase, P.BOARD_READY)

func test_treasury_ignores_blank_doubles_and_counts_high_values() -> void:
	var f := _flow()
	f.run.dice = [Die.make("", "gambler"), Die.make("", "gambler")] as Array[Die]
	for d in f.run.dice:
		d.faces = PackedInt32Array([0, 0, 0, 0, 0, 0])
	var before := f.run.treasury
	var ev := f.roll_board()
	assert_eq(_first(ev, "board_rolled").treasury_added, 0, "0-0 is not a double")
	assert_eq(f.run.treasury, before)
	var g := _flow()
	g.run.dice = [Die.make("", "giant"), Die.make("", "giant")] as Array[Die]
	for d in g.run.dice:
		d.faces = PackedInt32Array([9, 9, 9, 9, 9, 9])
	ev = g.roll_board()
	assert_eq(_first(ev, "board_rolled").treasury_added, 18)
	assert_eq(_first(ev, "board_rolled").values, [9, 9])

func test_draft_new_die_has_kind() -> void:
	var f := _flow()
	_draft_with(f, {"id": "new_die", "label": "Giant Die", "desc": "", "kind": "giant"})
	var ev := f.pick_draft(0)
	assert_eq(f.run.dice.back().kind, "giant")
	assert_eq(f.run.dice.back().faces, PackedInt32Array([4, 5, 6, 7, 8, 9]))
	var da := _first(ev, "die_added")
	assert_eq(da.kind, "giant")
	assert_eq(da.die.kind, "giant")

func test_draft_offers_new_die_while_pool_small() -> void:
	for s in 20:
		var f := _flow("knight", s)
		var ev: Array[Dictionary] = []
		f._open_draft(ev)
		var found := false
		for o in f.offer.options:
			if o.id == "new_die":
				found = true
				assert_true(DiceKinds.DEFS.has(o.kind), "draft die has a kind")
				assert_eq(o.label, DiceKinds.label(o.kind))
		assert_true(found, "pool < 5 always offers a new die (seed %d)" % s)

func test_shop_sells_die_kinds() -> void:
	var f := _flow()
	var seen_die := 0
	for s in 20:
		f.run.rng = Rng.new(s)
		var items := f._shop_stock()
		var dice := 0
		for it in items:
			if it.id == "die":
				dice += 1
				assert_true(DiceKinds.DEFS.has(it.kind))
				assert_eq(it.label, DiceKinds.label(it.kind))
				assert_eq(it.price, int(DiceKinds.DEFS[it.kind].price))
		assert_true(dice >= 1, "a small pool always sees a die in the shop")
		seen_die += dice
	f.run.gold = 999
	var item := _item("die", 45, false)
	item.kind = "gambler"
	_shop_with(f, [item])
	var ev := f.shop_buy(0)
	assert_eq(f.run.dice.back().kind, "gambler")
	assert_eq(_first(ev, "die_added").kind, "gambler")

func test_shop_no_die_when_pool_full() -> void:
	var f := _flow()
	while f.run.dice.size() < Balance.MAX_DICE:
		f.run.dice.append(Die.new())
	for s in 20:
		f.run.rng = Rng.new(s)
		for it in f._shop_stock():
			assert_true(it.id != "die", "no die when full")

func test_forge_giant_raises_past_six() -> void:
	var f := _flow()
	f.run.dice[0] = Die.make("", "giant")
	f.phase = P.FORGE
	f.offer = {"kind": "forge", "ops": ["raise", "mirror"], "source": "tile"}
	var ev := f.forge_apply(0, 2, "raise")
	assert_eq(f.run.dice[0].faces[2], 7)
	assert_eq(_first(ev, "face_changed").value, 7)
	f.phase = P.FORGE
	f.offer = {"kind": "forge", "ops": ["raise"], "source": "draft"}
	assert_eq(f.forge_apply(0, 5, "raise")[0].type, "error", "9 is the giant cap")
	f.run.dice[1] = Die.make("", "high")
	assert_eq(f.forge_apply(1, 5, "raise")[0].type, "error", "6 is the normal cap")

func test_shop_face_raise_on_giant() -> void:
	var f := _flow()
	f.run.gold = 99
	f.run.dice[0] = Die.make("", "giant")
	f.run.dice[0].faces = PackedInt32Array([9, 9, 9, 9, 9, 6])
	_shop_with(f, [_item("face_raise", 25, true)])
	f.shop_buy(0, 0)
	assert_eq(f.run.dice[0].faces[5], 7)

func test_event_dicesmith() -> void:
	var f := _flow()
	_event(f, "dicesmith")
	var c0: Dictionary = f.offer.choices[0]
	assert_true(DiceKinds.DEFS.has(c0.kind))
	var n := f.run.dice.size()
	var ev := f.event_choose(0)
	assert_eq(f.run.dice.size(), n + 1)
	assert_eq(f.run.dice.back().kind, c0.kind)
	assert_true(_types(ev).has("die_added"))
	# full pool: the choice reforges the weakest die, keeping its rune
	while f.run.dice.size() < Balance.MAX_DICE:
		f.run.dice.append(Die.make("", "low"))
	f.run.dice[0] = Die.make("guard", "low")
	for i in range(1, f.run.dice.size()):
		f.run.dice[i] = Die.make("", "high")
	_event(f, "dicesmith")
	var c: Dictionary = f.offer.choices[0]
	ev = f.event_choose(0)
	assert_eq(f.run.dice.size(), Balance.MAX_DICE)
	var dc := _first(ev, "die_changed")
	assert_eq(dc.die_idx, 0)
	assert_eq(f.run.dice[0].kind, c.kind)
	assert_eq(f.run.dice[0].rune, "guard", "rune kept")

func test_board_32_run() -> void:
	var f := GameFlow.new_run("knight", 3, 32)
	assert_eq(f.run.board.size(), 32)
	assert_eq(f.run.board_size, 32)
	f.run.max_hp = 70
	f.run.hp = 70
	for i in 32:
		if not f.run.board.is_corner(i):
			f.run.board.tiles[i] = Board.make_tile("empty")
	f.run.pos = 30
	_force_roll(f, 4)
	assert_eq(f.landing_preview()[0], 2)
	var ev := f.choose_move(0)
	assert_eq(_first(ev, "hero_moved").path, [31, 0, 1, 2])
	assert_eq(f.run.lap, 2)
	f.shop_leave()
	# portal on 24 reaches 10 tiles
	f.run.pos = 20
	_force_roll(f, 4)
	f.choose_move(0)
	assert_eq(f.phase, P.PORTAL)
	assert_eq(f.offer.tiles.size(), 10)
	assert_eq(f.offer.tiles[0], 25)
	f.portal_pick(31)
	assert_eq(f.run.pos, 31)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(f.to_dict()))
	var g := GameFlow.from_dict(parsed)
	assert_eq(g.run.board_size, 32)
	assert_eq(JSON.stringify(g.to_dict()), JSON.stringify(f.to_dict()))

func test_board_32_next_act_keeps_size() -> void:
	var f := GameFlow.new_run("knight", 5, 32)
	var ev: Array[Dictionary] = []
	f.run.lap = 6
	f._new_biome(0, ev)
	assert_eq(f.run.board.size(), 32)
	assert_eq(_first(ev, "act_started").board.tiles.size(), 32)

func test_board_32_replay() -> void:
	var f := GameFlow.new_run("rogue", 77, 32)
	for k in 400:
		if f.is_over():
			break
		f.apply(Bot.next_command(f))
	var r := GameFlow.replay("rogue", 77, f.commands, 32)
	assert_eq(JSON.stringify(r.to_dict()), JSON.stringify(f.to_dict()))

# ================================================================ automatic two-dice movement

func _pick(values: Array, s := 1) -> Array:
	var v: Array[int] = []
	v.assign(values)
	return Array(GameFlow.pick_move_dice(v, Rng.new(s)))

func _vals(values: Array, p: Array) -> Array:
	var out: Array = []
	for i in p:
		out.append(values[i])
	out.sort()
	return out

func test_move_one_die_of_each_top_value() -> void:
	# [2,2,2,5,6,6]: 2 has the most dice, 6 is second -> 2 + 6
	assert_eq(_vals([2, 2, 2, 5, 6, 6], _pick([2, 2, 2, 5, 6, 6])), [2, 6])
	assert_eq(_pick([2, 5, 2, 6, 6]), [0, 3], "first die of each value")
	assert_eq(_vals([3, 6, 6, 6, 3], _pick([3, 6, 6, 6, 3])), [3, 6])
	assert_eq(_pick([4, 4, 4, 1]), [0, 3], "trips + the other value")

func test_move_single_value_moves_two_of_it() -> void:
	assert_eq(_pick([4, 4, 4]), [0, 1])
	assert_eq(_pick([0, 5, 5, 0]), [1, 2], "blanks ignored, one value left")

func test_move_second_rank_tie_is_random_but_seeded() -> void:
	var seen := {}
	for s in 40:
		var p := _pick([2, 2, 5, 6], s)
		var v := _vals([2, 2, 5, 6], p)
		assert_true(v == [2, 5] or v == [2, 6], "2 plus 5 or 6: %s" % str(v))
		assert_eq(p, _pick([2, 2, 5, 6], s), "deterministic by seed")
		seen[str(v)] = true
	assert_eq(seen.size(), 2, "both tie-breaks happen")

func test_move_top_rank_tie_picks_two_of_the_tied() -> void:
	var seen := {}
	for s in 60:
		var v := _vals([5, 2, 5, 2, 6, 6], _pick([5, 2, 5, 2, 6, 6], s))
		assert_eq(v.size(), 2)
		assert_true(v[0] != v[1], "one die of each value")
		seen[str(v)] = true
	assert_eq(seen.size(), 3, "every pair of the tied values happens")

func test_move_all_unique_random_two() -> void:
	var seen := {}
	for s in 60:
		var p := _pick([1, 3, 4, 5, 6], s)
		assert_eq(p.size(), 2)
		assert_true(p[0] < p[1])
		seen[str(p)] = true
	assert_true(seen.size() > 5, "random pairs")

func test_move_pathfinders_eye_prefers_high() -> void:
	var v: Array[int] = [2, 2, 5, 6]
	for s in 20:
		assert_eq(Array(GameFlow.pick_move_dice(v, Rng.new(s), true)), [0, 3])

func test_move_ignores_blanks() -> void:
	for s in 20:
		assert_eq(_pick([0, 0, 3, 5], s), [2, 3], "zeros ignored (%d)" % s)
		var q := _pick([0, 0, 0, 4], s)
		assert_true(q.has(3), "the only live die moves")
	assert_eq(_pick([0, 6, 0, 6]), [1, 3], "a pair of 6s, not the blank pair")

func test_pair_value_rule() -> void:
	var cases := [
		[[2, 2, 2, 5, 6, 6], 2], [[2, 2, 6, 6], 6], [[2, 2, 5, 6], 2], [[1, 3, 4, 5, 6], 0],
		[[4, 4], 4], [[3, 5], 0], [[0, 0, 3], 0], [[0, 0, 3, 5], 0], [[4, 4, 0], 4],
	]
	for c in cases:
		var v: Array[int] = []
		v.assign(c[0])
		var p := GameFlow.pick_move_dice(v, Rng.new(3))
		assert_eq(GameFlow.pair_value_of(v, p), int(c[1]), str(c[0]))

func test_move_two_dice_pool_takes_both() -> void:
	assert_eq(_pick([0, 0]), [0, 1])
	assert_eq(_pick([6, 2]), [0, 1])

func test_confirm_move_and_phase_validation() -> void:
	var f := _flow()
	_blank(f)
	assert_eq(f.confirm_move()[0].type, "error", "nothing rolled")
	f.phase = P.BOARD_ROLLED
	var r: Array[int] = [2, 3]
	f._select_move(r)
	assert_eq(f.board_move, 5)
	assert_eq(f.landing_preview(), [5] as Array[int])
	var ev := f.confirm_move()
	assert_eq(f.run.pos, 5)
	assert_eq(_first(ev, "hero_moved").path, [1, 2, 3, 4, 5])
	assert_eq(f.commands.back(), ["confirm_move"])
	assert_eq(f.confirm_move()[0].type, "error", "already moved")
	assert_eq(f.board_reroll()[0].type, "error")

func test_choose_move_is_a_deprecated_alias() -> void:
	var f := _flow()
	_blank(f)
	f.phase = P.BOARD_ROLLED
	var r: Array[int] = [1, 1]
	f._select_move(r)
	f.choose_move(7)
	assert_eq(f.run.pos, 2)
	var g := GameFlow.replay("knight", 1, [["roll_board"], ["choose_move", 0]], 24)
	assert_eq(g.phase != P.BOARD_ROLLED, true, "old logs replay")

func test_gilded_fires_for_each_chosen_die() -> void:
	var f := _flow()
	_blank(f)
	f.run.dice[0].rune = "gilded"
	f.run.dice[1].rune = "gilded"
	f.run.gold = 0
	f.phase = P.BOARD_ROLLED
	var r: Array[int] = [2, 3]
	f._select_move(r)
	var ev := f.confirm_move()
	assert_eq(f.run.gold, 5)
	var n := 0
	for e in ev:
		if e.type == "rune_fired" and e.rune == "gilded":
			n += 1
	assert_eq(n, 2)

func test_treasury_on_any_pair_in_the_roll() -> void:
	var f := _flow()
	f.run.dice.append(Die.new())
	f.run.dice.append(Die.new())
	f.phase = P.BOARD_ROLLED
	var r: Array[int] = [5, 5, 2, 2]
	for s in 10:
		f.run.rng = Rng.new(s)
		f._select_move(r)
		assert_true(f.is_board_double())
		assert_eq(f.board_pair_value(), 5)
	var t: Array[int] = [3, 3, 1, 6]
	f._select_move(t)
	assert_true(f.is_board_double(), "a pair anywhere in the roll")
	assert_eq(f.board_pair_value(), 3)
	var u: Array[int] = [1, 2, 3, 4]
	f._select_move(u)
	assert_true(not f.is_board_double())
	assert_eq(f.board_pair_value(), 0)

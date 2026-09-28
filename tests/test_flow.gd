extends "res://tests/test_case.gd"

const P := GameFlow.Phase

## Arithmetic in these tests assumes a 70 HP hero, independent of balance tuning.
func _flow(cls := "knight", s := 1) -> GameFlow:
	var f := GameFlow.new_run(cls, s)
	f.run.max_hp = 70
	f.run.hp = 70
	return f

## All non-corner tiles empty so movement tests are predictable.
func _blank(f: GameFlow) -> void:
	for i in 24:
		if not Board.is_corner(i):
			f.run.board.tiles[i] = Board.make_tile("empty")

func _put(f: GameFlow, idx: int, tile: Dictionary) -> void:
	f.run.board.tiles[idx] = tile

## Forces a board roll so the next choose_move(0) moves `steps`.
func _force_roll(f: GameFlow, steps: int) -> void:
	f.phase = P.BOARD_ROLLED
	var r: Array[int] = []
	for i in f.run.dice.size():
		r.append(steps)
	f.board_roll = r

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
	assert_eq(k.run.dice.size(), 3)
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
	assert_eq(f.choose_move(9)[0].type, "error", "bad die")
	assert_eq(_snap(f), rolled)

func test_roll_board_and_reroll() -> void:
	var f := _flow()
	var ev := f.roll_board()
	assert_eq(f.phase, P.BOARD_ROLLED)
	var dr := _first(ev, "dice_rolled")
	assert_eq(dr.context, "board")
	assert_eq(dr.values.size(), 3)
	var br := _first(ev, "board_rolled")
	assert_eq(br.values, dr.values)
	assert_eq(br.targets, f.landing_preview())
	for i in 3:
		assert_eq(f.landing_preview()[i], f.board_roll[i] % 24)
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
		f.roll_board()
		var counts := {}
		for v in f.board_roll:
			counts[v] = counts.get(v, 0) + 1
		var add := 0
		for v in counts:
			if counts[v] >= 2:
				add += v * 2
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
	f.run.dice[1].rune = "gilded"
	f.run.gold = 0
	_force_roll(f, 4)
	var ev := f.choose_move(1)
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
	f.run.xp = 20 # brute gives 9 -> 29: level 2 (10) and 3 (25)
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
	assert_eq(f.run.dice.size(), 4)
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
	f.run.pos = 22
	f.run.hp = 40
	_force_roll(f, 5)
	var ev := f.choose_move(0)
	assert_eq(_first(ev, "hero_moved").path, [23, 0, 1, 2, 3])
	var lc := _first(ev, "lap_completed")
	assert_eq(lc.lap, 1)
	assert_eq(lc.healed, 11, "15% of 70 = 10.5 -> 11")
	assert_eq(f.run.lap, 2)
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
	f.run.pos = 20
	_force_roll(f, 4)
	f.choose_move(0)
	assert_eq(f.run.pos, 0)
	assert_eq(f.run.lap, 2)
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
	assert_eq(f.run.dice.size(), 4)
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
			assert_eq(total, 21 * 3 + 1)

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
	f.phase = P.PORTAL
	f.offer = {"kind": "portal", "tiles": [19, 20, 21, 22, 23, 0, 1, 2]}
	var ev := f.portal_pick(2)
	assert_true(_types(ev).has("lap_completed"))
	assert_eq(f.run.lap, 2)
	assert_eq(f.run.pos, 2)
	assert_eq(f.phase, P.SHOP)

func test_lap3_completion_starts_boss() -> void:
	var f := _flow()
	_blank(f)
	f.run.lap = 3
	f.run.pos = 22
	_force_roll(f, 5)
	assert_eq(f.landing_preview()[0], 0, "preview stops on start")
	var ev := f.choose_move(0)
	assert_eq(_first(ev, "hero_moved").path, [23, 0])
	assert_eq(f.run.pos, 0)
	assert_eq(f.phase, P.COMBAT)
	assert_eq(f.combat.boss, true)
	assert_eq(f.combat.enemies[0].id, "boss_bone_warden")
	assert_eq(_first(ev, "combat_started").boss, true)

func test_boss_win_next_act() -> void:
	var f := _flow()
	_blank(f)
	f.run.lap = 3
	f.run.pos = 22
	_force_roll(f, 5)
	f.choose_move(0)
	var ev := _win_fight(f)
	# resolve any level-up drafts
	var guard := 0
	while f.phase == P.DRAFT or f.phase == P.FORGE:
		guard += 1
		if guard > 10:
			break
		if f.offer.kind == "draft":
			ev.append_array(f.pick_draft(0))
		elif f.offer.kind == "rune_assign":
			ev.append_array(f.rune_assign(0))
		else:
			ev.append_array(f.forge_apply(0, 0, "raise"))
	var as_ := _first(ev, "act_started")
	assert_eq(as_.act, 2)
	assert_eq(as_.biome, "hollow")
	assert_eq(f.run.act, 2)
	assert_eq(f.run.lap, 1)
	assert_eq(f.run.pos, 0)
	assert_eq(f.run.board.tiles.size(), 24)
	assert_eq(f.phase, P.SHOP, "shop opens at act start")

func test_act3_boss_victory() -> void:
	var f := _flow()
	_blank(f)
	f.run.act = 3
	f.run.lap = 3
	f.run.pos = 22
	_force_roll(f, 5)
	f.choose_move(0)
	assert_eq(f.combat.enemies[0].id, "boss_lich")
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

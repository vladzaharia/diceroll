extends "res://tests/test_case.gd"
## The Last Camp (pre-boss camp): once per run, finishing the second-to-last lap.

const P := GameFlow.Phase

func _flow(mode := "standard", s := 3) -> GameFlow:
	var f := GameFlow.new_run("knight", s, 24, {"mode": mode})
	f.run.max_hp = 100
	f.run.hp = 40
	for i in 24:
		if not f.run.board.is_corner(i):
			f.run.board.tiles[i] = Board.make_tile("empty")
	return f

## Puts the hero 2 tiles before Start on `lap` and moves 4 (crosses Start, lands on tile 2).
func _cross(f: GameFlow, lap: int) -> Array[Dictionary]:
	f.run.lap = lap
	f.run.act = f.run.act_for_lap(lap)
	f.run.pos = 22
	f.phase = P.BOARD_ROLLED
	var r: Array[int] = [4]
	for i in range(1, f.run.dice.size()):
		r.append(0)
	f._select_move(r)
	return f.confirm_move()

func _first(ev: Array, type: String) -> Dictionary:
	for e in ev:
		if e.type == type:
			return e
	return {}

func _index_of(f: GameFlow, id: String) -> int:
	for i in f.offer.choices.size():
		if String(f.offer.choices[i].id) == id:
			return i
	return -1

func test_camp_opens_finishing_lap_14_before_the_shop() -> void:
	var f := _flow()
	var ev := _cross(f, 14)
	assert_eq(f.phase, P.EVENT, "camp phase")
	assert_eq(String(f.offer.kind), "camp")
	assert_eq(f.run.lap, 15, "the final lap starts")
	var co := _first(ev, "camp_opened")
	assert_true(not co.is_empty(), "camp_opened emitted")
	# lap heal 10% then the camp's 35%
	assert_eq(int(co.healed), 35, "camp heal")
	assert_eq(f.run.hp, 40 + 10 + 35)
	assert_eq(String(co.boss.id), f.run.boss_id)
	var ids: Array = []
	for c in f.offer.choices:
		ids.append(String(c.id))
	assert_eq(ids, ["potion", "rune", "steady"])
	assert_true(bool(f.run.stats.camped), "stats.camped")
	# the pick, then lap 14's shop (the last buy)
	f.event_choose(_index_of(f, "steady"))
	assert_eq(f.phase, P.SHOP, "the shop follows the camp")
	assert_eq(int(f.run.pet_state.get("steady", 0)), 1)
	assert_eq(String(f.run.stats.camp_pick), "steady")

func test_no_camp_on_other_laps() -> void:
	for lap in [1, 5, 13]:
		var f := _flow()
		_cross(f, lap)
		assert_true(String(f.offer.get("kind", "")) != "camp", "no camp after lap %d" % lap)
		assert_true(not f.run.stats.has("camped"))

func test_short_road_camp_before_its_final_lap() -> void:
	var f := _flow("short")
	_cross(f, 8)
	assert_true(String(f.offer.get("kind", "")) != "camp", "no camp after lap 8")
	var g := _flow("short")
	_cross(g, 9)
	assert_eq(String(g.offer.get("kind", "")), "camp", "camp after lap 9 of 10")
	assert_eq(g.run.lap, 10)

func test_camp_off_dial() -> void:
	Balance.camp_on = false
	var f := _flow()
	_cross(f, 14)
	Balance.camp_on = true
	assert_eq(f.phase, P.SHOP, "straight to the shop without the camp")
	assert_true(not f.run.stats.has("camped"))

func test_rune_pick_offers_two_runes() -> void:
	var f := _flow()
	_cross(f, 14)
	f.event_choose(_index_of(f, "rune"))
	assert_eq(f.phase, P.DRAFT)
	assert_eq(String(f.offer.source), "camp")
	assert_eq(f.offer.options.size(), Balance.CAMP_RUNE_CHOICES)
	var picked := String(f.offer.options[0].rune)
	f.pick_draft(0)
	assert_eq(String(f.offer.kind), "rune_assign")
	f.rune_assign(0)
	assert_eq(f.run.dice[0].rune, picked, "the picked rune is on die 1")
	assert_eq(int((f.run.stats.upgrades as Dictionary).get("camp", 0)), 1, "one camp upgrade")
	assert_eq(f.phase, P.SHOP)

func test_potion_pick() -> void:
	# legacy run (no belt): drunk at once for the shop potion's heal
	var f := _flow()
	_cross(f, 14)
	f.run.hp = 20
	f.event_choose(_index_of(f, "potion"))
	assert_eq(f.run.hp, 20 + 35)
	# with a belt with room: it goes on the belt
	var g := _flow()
	g.run.potion_cap = 2
	_cross(g, 14)
	g.event_choose(_index_of(g, "potion"))
	assert_eq(g.run.potions, 1)
	assert_eq(Array(g.run.belt), ["healing"])

func test_boss_is_tougher_after_the_camp_and_steady_hands() -> void:
	var f := _flow()
	var base_hp := int(EnemyDefs.def(f.run.boss_id).hp)
	f.debug_open("boss")
	assert_eq(int(f.combat.enemies[0].max_hp), base_hp, "no camp: base HP")
	var g := _flow()
	_cross(g, 14)
	g.event_choose(_index_of(g, "steady"))
	g.debug_open("boss")
	assert_eq(int(g.combat.enemies[0].max_hp), int(round(base_hp * Balance.camp_boss_mult(g.run.boss_id, false))), "camp: boss HP x its camp multiplier")
	assert_eq(g.combat.rerolls_left, g.run.combat_rerolls + 1, "Steady Hands: +1 reroll")
	# a regular fight after the camp keeps its rerolls
	g.debug_open("combat", "skeleton_minion")
	assert_eq(g.combat.rerolls_left, g.run.combat_rerolls)

func test_ascension_shrinks_the_camp_heal() -> void:
	var prof := MetaPresets.get_preset("max", 2)
	var f := GameFlow.new_run("knight", 3, 24, {"profile": prof, "ascension": 2})
	assert_near(f.run.camp_heal_pct(), Balance.CAMP_ASC_HEAL_PCT)
	var g := GameFlow.new_run("knight", 3, 24, {"profile": prof, "ascension": 1})
	assert_near(g.run.camp_heal_pct(), Balance.CAMP_HEAL_PCT)

func test_save_load_mid_camp_and_replay() -> void:
	var f := _flow()
	_cross(f, 14)
	var loaded := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
	assert_eq(loaded.phase, P.EVENT)
	assert_eq(String(loaded.offer.kind), "camp")
	assert_eq(loaded.offer.choices.size(), 3)
	loaded.event_choose(_index_of(loaded, "steady"))
	assert_eq(loaded.phase, P.SHOP)
	assert_eq(int(loaded.run.pet_state.get("steady", 0)), 1)
	# the camp flags survive a save
	var again := GameFlow.from_dict(JSON.parse_string(JSON.stringify(loaded.to_dict())))
	assert_true(bool(again.run.stats.camped))
	assert_eq(int(again.run.pet_state.get("steady", 0)), 1)

func test_replay_through_the_camp_is_deterministic() -> void:
	# a full greedy run crosses the camp; its command log replays to the same end
	var f := GameFlow.new_run("barbarian", 11)
	var n := 0
	while not f.is_over() and n < 20000:
		f.apply(Bot.next_command(f))
		n += 1
	var r := GameFlow.replay("barbarian", 11, f.commands)
	assert_eq(r.phase, f.phase)
	assert_eq(r.run.hp, f.run.hp)
	assert_eq(r.run.lap, f.run.lap)
	if f.run.lap >= 15:
		assert_true(bool(f.run.stats.get("camped", false)), "a run that reached lap 15 camped")

func test_bots_pick_a_camp_gift() -> void:
	for policy in ["greedy", "realistic", "expert"]:
		var f := _flow()
		_cross(f, 14)
		var cmd: Array
		if policy == "greedy":
			cmd = Bot.next_command(f)
		else:
			var d := Bot.decide(f, AutoRules.all_on("balanced", policy))
			assert_true(not bool(d.stop), "%s does not stop at the camp" % policy)
			cmd = d.cmd
		assert_eq(String(cmd[0]), "event_choose", policy)
		var ev := f.apply(cmd)
		assert_true(ev.is_empty() or String(ev[0].type) != "error", "%s pick is legal" % policy)
		assert_true(f.run.stats.has("camp_pick"), policy)

## Camp, gift, shop: returns the flow at the finale's BOARD_READY.
func _to_finale(f: GameFlow) -> void:
	_cross(f, f.run.camp_lap())
	f.event_choose(_index_of(f, "steady"))
	if f.phase == P.SHOP:
		f.shop_leave()

func test_camp_stops_on_start_and_the_finale_turns_every_tile() -> void:
	var f := _flow()
	var ev := _cross(f, 14)
	assert_eq(f.run.pos, 0, "the lap-14 finish stops on Start (the camp)")
	assert_true(_first(ev, "tile_triggered").is_empty(), "no tile triggers")
	f.event_choose(_index_of(f, "potion"))
	ev = f.shop_leave()
	assert_eq(f.phase, P.BOARD_READY, "the final roll waits")
	assert_true(f.run.finale, "finale flag")
	var fs := _first(ev, "finale_started")
	assert_true(not fs.is_empty(), "finale_started emitted")
	assert_eq((fs.changes as Array).size(), f.run.board.size())
	for t in f.run.board.tiles:
		assert_eq(String(t.type), "boss", "every tile is a boss tile")
	assert_eq(f.run.lap, 15, "the finale is lap 15")

func test_final_roll_lands_in_the_boss_fight() -> void:
	var f := _flow()
	_to_finale(f)
	f.run.board_rerolls = 3
	f.roll_board()
	assert_eq(f.board_rerolls_left, 0, "no rerolls on the final roll")
	var steps := f.board_move
	var laps := int(f.run.stats.get("laps_completed", 0))
	var ev := f.confirm_move()
	assert_eq(f.phase, P.COMBAT, "boss fight")
	assert_true(f.combat.boss)
	assert_eq(String(f.combat.enemies[0].id), f.run.boss_id)
	assert_eq(f.run.pos, steps % f.run.board.size(), "the hero lands where the roll says")
	assert_eq(f.combat.tile, f.run.pos, "the fight is on the landing tile")
	assert_eq(int(f.run.stats.laps_completed), laps + 1, "the final roll completes the final lap")
	assert_true(not _first(ev, "final_landing").is_empty())
	assert_eq(f.combat.rerolls_left, f.run.combat_rerolls + 1, "Steady Hands in the boss fight")

func test_save_load_mid_finale() -> void:
	var f := _flow()
	_to_finale(f)
	var g := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
	assert_true(g.run.finale)
	assert_eq(String(g.run.board.tiles[5].type), "boss")
	g.roll_board()
	g.confirm_move()
	assert_eq(g.phase, P.COMBAT)
	assert_true(g.combat.boss)
	# rolled but not moved: the save keeps the roll
	var h := _flow()
	_to_finale(h)
	h.roll_board()
	var k := GameFlow.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))
	assert_eq(k.phase, P.BOARD_ROLLED)
	assert_eq(k.board_move, h.board_move)
	k.confirm_move()
	assert_true(k.combat != null and k.combat.boss)

func test_short_road_finale() -> void:
	var f := _flow("short")
	_to_finale(f)
	assert_true(f.run.finale)
	assert_eq(f.run.lap, 10)
	f.roll_board()
	f.confirm_move()
	assert_true(f.combat.boss, "the Short Road's finale boss")

func test_auto_stops_for_the_final_roll() -> void:
	var f := _flow()
	_to_finale(f)
	var d := Bot.decide(f, AutoRules.new())
	assert_true(bool(d.stop), "AUTO (stop before boss) leaves the final roll to the player")
	var e := Bot.decide(f, AutoRules.all_on())
	assert_eq(String(e.cmd[0]), "roll_board")

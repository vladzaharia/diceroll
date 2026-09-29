extends "res://tests/test_case.gd"
## The four new biomes (docs/design/2026-09-29-new-biomes.md): tiers and routes, Deep Mines ore,
## Orc Warcamp drums, Sunscorched Ruins heat and oases, Moonlit Woods phases and the Full lap, the
## Sand Colossus and the Moon King, the Short Road's second-biome draw, milestones.

const P := GameFlow.Phase

var run: RunState
var c: CombatState

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

func _types(ev: Array) -> Array:
	var out := []
	for e in ev:
		out.append(e.type)
	return out

## A flow on `route` with every non-corner tile empty and a 100 HP hero, positioned in the biome
## of `act` (lap = that biome's first lap + `lap_off`).
func _flow(route: Array, act := 1, lap_off := 0, opts := {}) -> GameFlow:
	var o := opts.duplicate()
	o["route"] = route
	var f := GameFlow.new_run("knight", 1, 28, o)
	f.run.max_hp = 100
	f.run.hp = 100
	f.run.act = act
	f.run.lap = int(f.run.biome_laps()[act - 1]) + lap_off
	f.run.board = Board.generate(Rng.new(5), act, 28, f.run.eff_lap(), f.run.biome())
	for i in f.run.board.size():
		if not f.run.board.is_corner(i):
			f.run.board.tiles[i] = Board.make_tile("empty")
	return f

func _force_roll(f: GameFlow, values: Array) -> void:
	f.phase = P.BOARD_ROLLED
	var r: Array[int] = []
	r.assign(values)
	f._select_move(r)

## Moves the hero onto tile `idx` from idx - 3 with a [2, 1] roll.
func _land(f: GameFlow, idx: int) -> Array[Dictionary]:
	f.run.pos = idx - 3
	_force_roll(f, [2, 1])
	return f.confirm_move()

func _fight_in(f: GameFlow, ids: Array, elite := false, boss := false) -> Array[Dictionary]:
	run = f.run
	c = CombatState.new()
	return c.begin(run, ids, elite, boss, 3)

# ---------------------------------------------------------------- tiers, routes, tiles

func test_tiers_and_routes() -> void:
	assert_eq(BiomeDefs.TIERS.map(func(t): return t.size()), [3, 3, 4])
	assert_eq(BiomeDefs.all_routes().size(), 36)
	assert_eq(BiomeDefs.all_short_routes().size(), 21)
	for id in ["mines", "warcamp", "ruins", "moonlit"]:
		assert_true(BiomeDefs.has(id), id)
	assert_eq(BiomeDefs.twist_of("mines"), "ore")
	assert_eq(BiomeDefs.twist_of("warcamp"), "drums")
	assert_eq(BiomeDefs.twist_of("ruins"), "heat")
	assert_eq(BiomeDefs.twist_of("moonlit"), "moon")
	assert_eq(BiomeDefs.twist_of("glade"), "")
	# every existing Throne boss appears in exactly 2 biomes; 6 final bosses in total
	var where := {}
	for id in BiomeDefs.TIERS[2]:
		for b in BiomeDefs.DEFS[id].bosses:
			where[b] = int(where.get(b, 0)) + 1
	assert_eq(where.size(), 6)
	assert_eq(where.boss_lich, 2)
	assert_eq(where.boss_bone_warden, 2)
	assert_eq(BiomeDefs.DEFS.hollow.minibosses, ["mini_pumpkin_knight", "mini_grave_mage", "mini_moonfang"])
	assert_eq(BiomeDefs.DEFS.warcamp.minibosses, ["mini_orc_warchief", "mini_cinder_brute"])
	assert_eq(BiomeDefs.DEFS.moonlit.minibosses, ["mini_moonfang"])
	assert_eq(BiomeDefs.final_boss_candidates("warcamp"), ["boss_cinder_king", "boss_magma_golem"])
	assert_eq(BiomeDefs.final_boss_candidates("hollow"), ["boss_lich", "boss_bone_warden"])

func test_new_tile_mixes() -> void:
	var l := Board.layout_for(28, "mines")
	assert_eq([l.ore, l.chest, l.trap], [3, 3, 2])
	l = Board.layout_for(28, "warcamp")
	assert_eq([l.drum, l.enemy, l.event], [2, 8, 3])
	l = Board.layout_for(28, "ruins")
	assert_eq([l.oasis, l.campfire], [3, 1])
	l = Board.layout_for(28, "moonlit")
	assert_eq([l.event, l.trap], [5, 1])
	for id in ["mines", "warcamp", "ruins", "moonlit"]:
		var total := 0
		for t in Board.layout_for(28, id):
			total += int(Board.layout_for(28, id)[t])
		assert_eq(total, 24, id)

func test_drums_and_ore_never_on_tiles_1_2() -> void:
	for s in 60:
		for id in ["mines", "warcamp"]:
			var b := Board.generate(Rng.new(s), 1, 28, 1, id)
			for i in [1, 2]:
				assert_true(not ["drum", "ore", "enemy", "elite"].has(String(b.tiles[i].type)), "%s tile %d" % [id, i])
			assert_eq(b.count("drum" if id == "warcamp" else "ore"), 2 if id == "warcamp" else 3)

func test_twist_off_empties_tiles() -> void:
	BiomeDefs.twist_off = ["all"]
	var l := Board.layout_for(28, "mines")
	assert_true(not l.has("ore"))
	assert_eq(BiomeDefs.twist_of("mines"), "")
	BiomeDefs.twist_off = ["warcamp"]
	assert_true(not Board.layout_for(28, "warcamp").has("drum"))
	assert_eq(int(Board.layout_for(28, "mines").ore), 3)
	BiomeDefs.twist_off = []

# ---------------------------------------------------------------- Deep Mines

func test_ore_gold_then_cave_in() -> void:
	var f := _flow(["mines", "hollow", "throne"])
	f.run.board.tiles[5] = Board.make_tile("ore")
	var ev := _land(f, 5)
	assert_eq(f.phase, P.EVENT)
	assert_eq(f.offer.kind, "ore")
	assert_eq(f.offer.choices[0].gold, BiomeDefs.ORE_GOLD)
	var g0 := f.run.gold
	ev = f.event_choose(0)
	var om := _first(ev, "ore_mined")
	assert_eq([om.idx, om.choice, om.gold], [5, "gold", BiomeDefs.ORE_GOLD])
	var tc := _first(ev, "tile_changed")
	assert_eq([tc.idx, tc.tile_type, tc.source], [5, "trap", "cave_in"])
	assert_eq(f.run.board.tiles[5].type, "trap")
	assert_eq(f.run.gold, g0 + BiomeDefs.ORE_GOLD)
	assert_eq(f.phase, P.BOARD_READY)
	# the cave-in is an ordinary trap now (no Crypt gold)
	assert_true(_types(ev).find("ore_mined") < _types(ev).find("tile_changed"))

func test_ore_face_raise() -> void:
	var f := _flow(["mines", "hollow", "throne"])
	f.run.board.tiles[5] = Board.make_tile("ore")
	_land(f, 5)
	var ev := f.event_choose(1)
	assert_eq(_first(ev, "ore_mined").choice, "raise")
	assert_eq(f.phase, P.FORGE)
	assert_eq(f.offer.ops, ["raise"])
	assert_eq(f.offer.source, "ore")
	var before := f.run.dice[0].faces[0]
	f.forge_apply(0, 0, "raise")
	assert_eq(f.run.dice[0].faces[0], before + 1)
	assert_eq(f.phase, P.BOARD_READY)
	# replay reproduces it
	var r := GameFlow.replay("knight", 1, f.commands, 28, {"route": ["mines", "hollow", "throne"]})
	assert_true(r != null)

func test_ore_refill_and_trap_cap() -> void:
	var b := Board.generate(Rng.new(3), 1, 28, 2, "mines")
	for i in b.size():
		if not b.is_corner(i):
			b.tiles[i] = Board.make_tile("empty")
	b.mutate(Rng.new(1), 1, 2, [0])
	assert_eq(b.count("ore"), 3, "ore refills to 3")
	for i in range(3, 10):
		if not b.is_corner(i):
			b.tiles[i] = Board.make_tile("trap")
	for i in b.size():
		if b.tiles[i].type == "ore":
			b.tiles[i] = Board.make_tile("empty")
	assert_true(b.count("trap") >= BiomeDefs.MINES_TRAP_CAP)
	b.mutate(Rng.new(2), 1, 3, [0])
	assert_eq(b.count("ore"), 0, "no refill at the trap cap")

func test_rock_golem() -> void:
	var d := EnemyDefs.def("rock_golem")
	assert_eq([d.hp, d.gold, d.xp], [42, 14, 10])
	assert_eq(EnemyDefs.traits("rock_golem"), ["thorns"])
	assert_eq(Board.roll_enemies(Rng.new(1), 1, 4, true, "mines")[0], "rock_golem")
	assert_eq(AffixDefs.weights("mines").gilded, 3.0)
	assert_eq(AffixDefs.weights("glade").gilded, 1.0)

# ---------------------------------------------------------------- Orc Warcamp

func test_drums_rally_at_fight_start() -> void:
	var f := _flow(["glade", "warcamp", "throne"], 2)
	f.run.board.tiles[10] = Board.make_tile("drum")
	f.run.board.tiles[11] = Board.make_tile("drum")
	var ev := _fight_in(f, ["orc_raider", "bandit"])
	var r := _first(ev, "rally")
	assert_eq([r.source, r.value, r.drums], ["drum", 4, 2])
	assert_eq(c.enemies[0].atk_bonus, 4)
	assert_eq(c.enemies[1].atk_bonus, 4)
	assert_eq(_all(ev, "status").filter(func(e): return e.get("source", "") == "drum").size(), 2)
	# the first intent already carries the bonus
	var base := int(round(7 * Balance.enemy_atk_scale(f.run.eff_lap())))
	if c.enemies[1].intent.kind == "attack":
		assert_eq(c.enemies[1].intent.value, base + 4)
	# one drum: +2; no drums: nothing
	f.run.board.tiles[11] = Board.make_tile("empty")
	_fight_in(f, ["bandit"])
	assert_eq(c.enemies[0].atk_bonus, 2)
	f.run.board.tiles[10] = Board.make_tile("empty")
	ev = _fight_in(f, ["bandit"])
	assert_eq(c.enemies[0].atk_bonus, 0)
	assert_true(_first(ev, "rally").is_empty())

func test_attack_bonus_cap() -> void:
	var f := _flow(["glade", "warcamp", "throne"], 2)
	f.run.board.tiles[10] = Board.make_tile("drum")
	f.run.board.tiles[11] = Board.make_tile("drum")
	_fight_in(f, ["orc_raider", "orc_drummer"])
	assert_eq(c.enemies[0].atk_bonus, 4)
	# rally intent +2 twice, then frenzy: capped at +8 in total
	for k in 3:
		for e in c.enemies:
			e.intent = {"kind": "aim", "value": 0}
		c.enemies[1].intent = {"kind": "rally", "value": 2}
		c._execute_intent(f.run, 1)
	assert_eq(c.enemies[0].atk_bonus, EnemyDefs.ATK_BONUS_CAP)
	c._frenzy(0)
	assert_eq(c.enemies[0].atk_bonus, EnemyDefs.ATK_BONUS_CAP, "frenzy shares the cap")

func test_drum_smash_and_rebuild() -> void:
	var f := _flow(["glade", "warcamp", "throne"], 2)
	f.run.board.tiles[10] = Board.make_tile("drum")
	f.run.board.tiles[20] = Board.make_tile("drum")
	var g0 := f.run.gold
	var ev := _land(f, 10)
	var d := _first(ev, "drum_smashed")
	var g := int(round(BiomeDefs.DRUM_GOLD * Balance.gold_scale(f.run.eff_lap())))
	assert_eq([d.idx, d.gold, d.drums], [10, g, 1])
	assert_eq(f.run.board.tiles[10].type, "empty")
	assert_eq(f.run.gold, g0 + g)
	# the lap mutation rebuilds one drum, more than 3 tiles from the hero
	f.run.pos = 25
	_force_roll(f, [2, 1])
	ev = f.confirm_move()
	assert_eq(f.run.board.count("drum"), 2)
	var bm := _first(ev, "board_mutated")
	var reb: Array = bm.changes.filter(func(x): return x.get("source", "") == "rebuild")
	assert_eq(reb.size(), 1)
	var idx := int(reb[0].idx)
	var dist := mini((idx - f.run.pos + 28) % 28, (f.run.pos - idx + 28) % 28)
	assert_true(dist > 3 and idx > 2, "rebuilt at %d" % idx)
	# never more than 2
	f.run.pos = 25
	_force_roll(f, [2, 1])
	f.confirm_move()
	assert_eq(f.run.board.count("drum"), 2)

# ---------------------------------------------------------------- Sunscorched Ruins

func test_heat_and_oasis() -> void:
	var f := _flow(["glade", "hollow", "ruins"], 3)
	f.run.pos = 26
	f.run.hp = 50
	_force_roll(f, [2, 1])
	var ev := f.confirm_move()
	var h := _first(ev, "heat")
	assert_eq([h.damage, h.cooled, h.lap], [5, false, 11])
	assert_true(_types(ev).find("heat") < _types(ev).find("lap_completed"), "heat before the lap heal")
	assert_eq(f.run.hp, 50 - 5 + 10)
	# landing on an oasis heals 8% and cools the lap
	f.run.board.tiles[6] = Board.make_tile("oasis")
	f.run.hp = 50
	ev = _land(f, 6)
	var o := _first(ev, "oasis")
	assert_eq([o.idx, o.healed], [6, 8])
	assert_eq(f.run.cooled_lap, f.run.lap)
	assert_eq(f.run.board.tiles[6].type, "oasis", "oases persist")
	f.run.pos = 26
	_force_roll(f, [2, 1])
	ev = f.confirm_move()
	assert_eq(_first(ev, "heat").cooled, true)
	assert_eq(_first(ev, "heat").damage, 0)
	# never lethal
	f.run.hp = 1
	f.run.pos = 26
	_force_roll(f, [2, 1])
	ev = f.confirm_move()
	assert_eq(_first(ev, "heat").damage, 0)
	assert_true(f.run.hp >= 1)
	# round trip of cooled_lap
	f.run.cooled_lap = 12
	var g := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
	assert_eq(g.run.cooled_lap, 12)

func test_no_heat_elsewhere() -> void:
	var f := _flow(["glade", "hollow", "magma"], 3)
	f.run.pos = 26
	_force_roll(f, [2, 1])
	assert_true(_first(f.confirm_move(), "heat").is_empty())

func test_sand_colossus_bury() -> void:
	var f := _flow(["glade", "hollow", "ruins"], 3, 4)
	_fight_in(f, ["boss_sand_colossus"], false, true)
	assert_eq(c.enemies[0].max_hp, 1250)
	c.enemies[0].phase = 2
	c.enemies[0].traits = EnemyDefs.traits("boss_sand_colossus", 2).duplicate()
	c.enemies[0].intent = {"kind": "bury", "value": 2}
	c.dice_values.assign([0, 0])
	f.run.block = 0
	var ev := c.attack(f.run)
	assert_eq(_first(ev, "status").get("bury", false), true)
	assert_eq(c.enemies[0].block, 20, "10 Block per die buried")
	assert_eq(c.locked.count(true), 2, "two dice locked next turn")
	assert_eq(EnemyDefs.traits("boss_sand_colossus", 2), ["pierce"])

# ---------------------------------------------------------------- Moonlit Woods

func test_moon_phases() -> void:
	var f := _flow(["glade", "hollow", "moonlit"], 3)
	var got := []
	for l in range(11, 16):
		got.append(f.run.moon_phase(l))
	assert_eq(got, ["crescent", "half", "full", "half", "crescent"])
	assert_eq(f.run.moon_phase(9), "")
	f.run.lap = 12
	assert_eq(f.run.laps_to_full_moon(), 1)
	var s := _flow(["glade", "moonlit"], 2, 0, {"mode": "short"})
	assert_eq(s.run.moon_phase(8), "full", "Short Road Full lap is lap 8")
	assert_eq(s.run.moon_phase(6), "crescent")

func test_half_moon_transform_threshold() -> void:
	var f := _flow(["glade", "hollow", "moonlit"], 3, 1)
	_fight_in(f, ["werewolf"])
	assert_eq(c.transform_at, BiomeDefs.MOON_HALF_TRANSFORM)
	var mx := int(c.enemies[0].max_hp)
	c.enemies[0].hp = int(mx * 0.7)
	var ev := c.damage_enemy(0, int(mx * 0.7) - int(mx * 0.6), "thorns", f.run)
	assert_eq(c.enemies[0].phase, 2, "changes at <= 65% on the Half moon")
	assert_true(not _first(ev, "enemy_transformed").is_empty())
	f.run.lap = 11
	_fight_in(f, ["werewolf"])
	assert_eq(c.transform_at, 0.5)

func test_full_moon_fight() -> void:
	var f := _flow(["glade", "hollow", "moonlit"], 3, 2)
	var ev := _fight_in(f, ["werewolf", "bandit"])
	assert_eq(c.enemies[0].phase, 2)
	assert_eq(c.enemies[0].form, "wolf")
	var t := _first(ev, "enemy_transformed")
	assert_eq([t.enemy_idx, t.form, t.source], [0, "wolf", "moon"])
	assert_true(c.moon_full)
	for e in c.enemies:
		e.hp = 0
	c._win(f.run)
	var base := (8.0 + 8.0) * Balance.gold_scale(13)
	assert_eq(c.gold_reward, int(round(base * BiomeDefs.MOON_FULL_GOLD)))

func test_full_lap_mutation_elite_and_moon_chest() -> void:
	var f := _flow(["glade", "hollow", "moonlit"], 3, 1)
	f.run.pos = 26
	_force_roll(f, [2, 1])
	var ev := f.confirm_move()
	assert_eq(f.run.lap, 13)
	var mp := _all(ev, "moon_phase")
	assert_eq(mp.back().phase, "full")
	assert_eq(f.run.board.count("elite"), 2, "double elites on the Full lap")
	var tc := _first(ev, "tile_changed")
	assert_eq([tc.tile_type, tc.moon, tc.source], ["chest", true, "full_moon"])
	var d := (int(tc.idx) - f.run.pos + 28) % 28
	assert_true(d >= 3 and d <= 8, "3-8 tiles ahead (%d)" % d)
	# landing on it: a rune choice with a Rare or Epic
	var idx := int(tc.idx)
	var g := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
	assert_eq(g.run.board.tiles[idx].get("moon", false), true, "moon flag saved")
	f.run.board.tiles[idx] = Board.make_tile("chest")
	f.run.board.tiles[idx]["moon"] = true
	f.phase = P.BOARD_READY
	ev = _land(f, idx)
	assert_eq(f.phase, P.DRAFT)
	assert_eq(f.offer.source, "moon_chest")
	var shiny := false
	for o in f.offer.options:
		if Runes.rarity(String(o.rune)) != "common":
			shiny = true
	assert_true(shiny, "at least one Rare or Epic")
	assert_eq(f.run.board.tiles[idx].type, "empty")

func test_moon_chest_rare_guarantee_many_seeds() -> void:
	for s in 40:
		var f := _flow(["glade", "hollow", "moonlit"], 3, 2)
		f.run.rng = Rng.new(s)
		f.run.board.tiles[6] = Board.make_tile("chest")
		f.run.board.tiles[6]["moon"] = true
		_land(f, 6)
		var shiny := false
		for o in f.offer.options:
			if Runes.rarity(String(o.rune)) != "common":
				shiny = true
		assert_true(shiny, "seed %d" % s)

func test_moon_chest_fallbacks() -> void:
	var b := Board.generate(Rng.new(1), 3, 28, 12, "moonlit")
	for i in b.size():
		if not b.is_corner(i):
			b.tiles[i] = Board.make_tile("enemy", ["bandit"])
	b.tiles[15] = Board.make_tile("empty")
	assert_eq(int(b.place_moon_chest(1).idx), 15, "nearest Empty anywhere ahead")
	for i in b.size():
		if not b.is_corner(i):
			b.tiles[i] = Board.make_tile("enemy", ["bandit"])
	b.tiles[20] = Board.make_tile("event")
	assert_eq(int(b.place_moon_chest(1).idx), 20, "then the nearest Event")

# ---------------------------------------------------------------- the Moon King

func _moon_king(f: GameFlow) -> void:
	_fight_in(f, ["boss_moon_king"], false, true)
	for e in c.enemies:
		e.intent = {"kind": "aim", "value": 0}

## One attack with `vals` where every enemy idles.
func _swing(f: GameFlow, vals: Array) -> Array[Dictionary]:
	for e in c.enemies:
		e.intent = {"kind": "aim", "value": 0}
	c.dice_values.assign(vals)
	f.run.hp = 999
	f.run.max_hp = 999
	return c.attack(f.run)

func test_moon_meter_tide_and_clouds() -> void:
	var f := _flow(["glade", "hollow", "moonlit"], 3, 4)
	_moon_king(f)
	assert_eq(c.moon, 0)
	var ev := _swing(f, [0, 0])
	var mm := _all(ev, "moon_meter")
	assert_eq([mm.back().value, mm.back().delta, mm.back().source], [1, 1, "tide"])
	_swing(f, [0, 0])
	assert_eq(c.moon, 2)
	# two 1s push it back 2 before the tide adds 1
	ev = _swing(f, [1, 1])
	mm = _all(ev, "moon_meter")
	assert_eq([mm[0].source, mm[0].delta, mm[0].value], ["clouds", -2, 0])
	assert_eq(c.moon, 1)
	# a Wild never counts as 1
	f.run.dice[0].rune = "wild"
	ev = _swing(f, [1, 0])
	assert_eq(_all(ev, "moon_meter").size(), 1, "tide only")
	f.run.dice[0].rune = ""

func test_moonrise_and_moonfall() -> void:
	var f := _flow(["glade", "hollow", "moonlit"], 3, 4)
	_moon_king(f)
	c.moon = 3
	var ev := _swing(f, [0, 0])
	var bp := _first(ev, "boss_phase")
	assert_eq([bp.phase, bp.forced, bp.source, bp.form], [2, true, "moonrise", "wolf"])
	assert_eq(c.enemies[0].phase, 2)
	assert_eq(c.enemies[0].hp, 1300, "HP unchanged")
	assert_eq(c.moon, 0)
	# phase 2: a full meter turns the next intent into Moonfall (piercing 40)
	c.moon = 3
	ev = _swing(f, [0, 0])
	assert_eq(c.enemies[0].intent, {"kind": "moonfall", "value": EnemyDefs.MOONFALL})
	assert_eq(c.moon, 0)
	f.run.hp = 100
	f.run.max_hp = 100
	c.dice_values.assign([0, 0])
	var before := f.run.hp
	c.attack(f.run)
	# Block does not absorb Moonfall
	assert_true(before - f.run.hp >= EnemyDefs.MOONFALL or f.run.hp <= 0 or before - f.run.hp >= 40 - 0)

func test_moonfall_pierces_block() -> void:
	var f := _flow(["glade", "hollow", "moonlit"], 3, 4)
	_moon_king(f)
	c.enemies[0].intent = {"kind": "moonfall", "value": 40}
	f.run.hp = 100
	f.run.max_hp = 100
	f.run.block = 30
	var ev := c._execute_intent(f.run, 0)
	var dmg := _first(ev, "damage")
	assert_eq([dmg.amount, dmg.blocked, dmg.pierce], [40, 0, true])

func test_moon_king_a9_and_moonfang_link() -> void:
	var f := _flow(["glade", "hollow", "moonlit"], 3, 4, {"profile": MetaPresets.get_preset("max", 9)})
	_moon_king(f)
	assert_eq(c.moon, EnemyDefs.MOON_A9_START)
	var g := _flow(["glade", "hollow", "moonlit"], 3, 4)
	g.run.stats["minibosses_killed"] = ["mini_moonfang"]
	var ev := _fight_in(g, ["boss_moon_king"], false, true)
	assert_eq(c.moon, -1)
	assert_eq(_first(ev, "moon_meter").source, "moonfang")
	# the meter survives a save
	c.moon = 3
	var d := CombatState.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(d.moon, 3)
	# no meter on other bosses
	_fight_in(g, ["boss_lich"], false, true)
	assert_eq(c.moon_king(), -1)

func test_moon_king_summons_wolves() -> void:
	var f := _flow(["glade", "hollow", "moonlit"], 3, 4)
	_moon_king(f)
	c.enemies[0].intent = {"kind": "summon", "value": 1}
	var ev := c._execute_intent(f.run, 0)
	assert_eq(_first(ev, "summon").enemy.id, "wolf_bandit")

# ---------------------------------------------------------------- Short Road

func test_short_road_second_biome_draw() -> void:
	var seconds := {}
	for s in 300:
		var f := GameFlow.new_run("knight", s, 28, {"mode": "short"})
		assert_eq(f.run.route.size(), 2)
		assert_true(BiomeDefs.valid_short_route(f.run.route), str(f.run.route))
		seconds[f.run.route[1]] = true
		assert_true(BiomeDefs.DEFS[f.run.route[1]].minibosses.has(f.run.miniboss_id))
		assert_true(BiomeDefs.final_boss_candidates(f.run.route[1]).has(f.run.boss_id), "%s %s" % [f.run.route, f.run.boss_id])
	assert_eq(seconds.size(), 7)
	# forced routes
	var g := GameFlow.new_run("knight", 3, 28, {"mode": "short", "route": ["mines", "warcamp"]})
	assert_eq(Array(g.run.route), ["mines", "warcamp"])
	assert_true(["boss_cinder_king", "boss_magma_golem"].has(g.run.boss_id))
	var h := GameFlow.new_run("knight", 3, 28, {"mode": "short", "route": ["glade", "frost", "magma"]})
	assert_eq(Array(h.run.route), ["glade", "magma"])

func test_short_road_miniboss_and_pools() -> void:
	var f := GameFlow.new_run("knight", 4, 28, {"mode": "short", "route": ["glade", "frost"]})
	f.run.lap = 5
	f.run.pos = 26
	_force_roll(f, [2, 1])
	var ev := f.confirm_move()
	var a := _first(ev, "act_started")
	assert_eq(a.biome, "frost")
	assert_eq(f.run.board.count("miniboss"), 1, "the mini-boss arrives at lap 6")
	assert_eq(f.run.board.first_lap, 7)
	assert_eq(Board.enemy_pool(9, "frost", 7), BiomeDefs.DEFS.frost.pools[0], "laps 6-8 early")
	assert_eq(Board.enemy_pool(10, "frost", 7), BiomeDefs.DEFS.frost.pools[1], "laps 9-10 late")

func test_short_road_meta_draw_respects_unlocks() -> void:
	var p := MetaPresets.get_preset("fresh")
	for s in 40:
		var f := GameFlow.new_run("knight", s, 28, {"mode": "short", "profile": p})
		assert_true(["hollow", "throne"].has(f.run.route[1]), str(f.run.route))

# ---------------------------------------------------------------- whole runs

func test_new_routes_play_and_replay() -> void:
	var routes := [["mines", "warcamp", "moonlit"], ["mines", "warcamp", "ruins"], ["crypt", "hollow", "moonlit"]]
	for k in routes.size():
		var opts := {"route": routes[k]}
		var f := GameFlow.new_run("knight", 50 + k, 28, opts)
		var n := 0
		while not f.is_over() and n < 4000:
			var ev := f.apply(Bot.next_command(f))
			for e in ev:
				assert_true(e.type != "error", "%s: %s" % [routes[k], e.get("msg", "")])
			n += 1
		assert_true(f.is_over(), "run finishes")
		var r := GameFlow.replay("knight", 50 + k, f.commands, 28, opts)
		assert_eq(JSON.stringify(r.to_dict()), JSON.stringify(f.to_dict()), "replay %s" % [routes[k]])

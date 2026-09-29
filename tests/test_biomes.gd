extends "res://tests/test_case.gd"
## Biome routes, biome twists, biome enemies, mini-boss and final-boss rotations.

const P := GameFlow.Phase

var run: RunState
var c: CombatState

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

## A flow on `route` with every non-corner tile empty and a 100 HP hero.
func _flow(route: Array, s := 1) -> GameFlow:
	var f := GameFlow.new_run("knight", s, 28, {"route": route})
	f.run.max_hp = 100
	f.run.hp = 100
	for i in f.run.board.size():
		if not f.run.board.is_corner(i):
			f.run.board.tiles[i] = Board.make_tile("empty")
	return f

func _force_roll(f: GameFlow, values: Array) -> void:
	f.phase = P.BOARD_ROLLED
	var r: Array[int] = []
	r.assign(values)
	f._select_move(r)

func _count(b: Board, type: String) -> int:
	var n := 0
	for t in b.tiles:
		if t.type == type:
			n += 1
	return n

# ---------------------------------------------------------------- routes

func test_route_one_biome_per_tier_and_deterministic() -> void:
	var routes := {}
	var bosses := {}
	var minis := {}
	for s in 600:
		var f := GameFlow.new_run("knight", s)
		var g := GameFlow.new_run("knight", s)
		assert_eq(Array(f.run.route), Array(g.run.route), "same seed, same route")
		assert_eq(f.run.boss_id, g.run.boss_id)
		assert_eq(f.run.miniboss_id, g.run.miniboss_id)
		assert_true(BiomeDefs.valid_route(f.run.route), "valid route %s" % str(f.run.route))
		assert_true(BiomeDefs.miniboss_candidates(f.run.route).has(f.run.miniboss_id), "mini-boss from tier 2")
		assert_true(BiomeDefs.boss_candidates(f.run.route).has(f.run.boss_id), "boss from tier 3")
		assert_eq(f.run.board.biome, f.run.route[0], "the first board is the tier-1 biome")
		routes[",".join(f.run.route)] = true
		bosses[f.run.boss_id] = true
		minis[f.run.miniboss_id] = true
	assert_eq(routes.size(), 36, "every route shows up")
	assert_eq(bosses.size(), 6, "every final boss shows up")
	assert_eq(minis.size(), 7, "every tier-2 mini-boss shows up")

func test_forced_route_and_bosses() -> void:
	var f := GameFlow.new_run("mage", 5, 28, {"route": ["glade", "frost", "magma"], "miniboss": "mini_frost_warden", "boss": "boss_magma_golem"})
	assert_eq(Array(f.run.route), ["glade", "frost", "magma"])
	assert_eq(f.run.miniboss_id, "mini_frost_warden")
	assert_eq(f.run.boss_id, "boss_magma_golem")
	assert_eq(f.run.board.biome, "glade")
	var g := GameFlow.new_run("mage", 5, 28, {"route": ["crypt", "hollow", "throne"]})
	assert_true(["mini_pumpkin_knight", "mini_grave_mage", "mini_moonfang"].has(g.run.miniboss_id))
	assert_true(["boss_lich", "boss_bone_warden"].has(g.run.boss_id))
	# invalid overrides are ignored
	var h := GameFlow.new_run("mage", 5, 28, {"route": ["magma", "glade", "frost"], "boss": "nope"})
	assert_true(BiomeDefs.valid_route(h.run.route))
	assert_true(EnemyDefs.BOSSES.has(h.run.boss_id))

func test_candidates_per_biome() -> void:
	assert_eq(BiomeDefs.miniboss_candidates(["crypt", "hollow", "throne"]), ["mini_pumpkin_knight", "mini_grave_mage", "mini_moonfang"])
	assert_eq(BiomeDefs.miniboss_candidates(["crypt", "frost", "throne"]), ["mini_frost_warden", "mini_bone_champion"])
	assert_eq(BiomeDefs.miniboss_candidates(["mines", "warcamp", "ruins"]), ["mini_orc_warchief", "mini_cinder_brute"])
	assert_eq(BiomeDefs.boss_candidates(["mines", "warcamp", "ruins"]), ["boss_sand_colossus", "boss_bone_warden"])
	assert_eq(BiomeDefs.boss_candidates(["mines", "warcamp", "moonlit"]), ["boss_moon_king", "boss_lich"])
	assert_eq(BiomeDefs.boss_candidates(["crypt", "hollow", "throne"]), ["boss_lich", "boss_bone_warden"])
	assert_eq(BiomeDefs.boss_candidates(["crypt", "hollow", "magma"]), ["boss_cinder_king", "boss_magma_golem"])
	var finals := {}
	for id in BiomeDefs.DEFS:
		var d: Dictionary = BiomeDefs.DEFS[id]
		for m in d.minibosses:
			assert_true(EnemyDefs.MINIBOSSES.has(m), "mini-boss %s defined" % m)
		for b in d.bosses:
			assert_true(EnemyDefs.BOSSES.has(b), "boss %s defined" % b)
			assert_eq((EnemyDefs.BOSSES[b].phases as Array).size(), 2, "%s has 2 phases" % b)
			finals[b] = true
		for pool in d.pools:
			for e in pool:
				assert_true(EnemyDefs.ENEMIES.has(e), "enemy %s defined" % e)
		assert_true(EnemyDefs.ENEMIES.has(d.elite))
	assert_true(finals.size() >= 4, "at least 4 final bosses")
	assert_true(EnemyDefs.MINIBOSSES.has("mini_briar_beast") and EnemyDefs.MINIBOSSES.has("mini_cinder_brute"))
	var n := EnemyDefs.ENEMIES.size()
	assert_true(n >= 18 and n <= 22, "18-22 regular enemies (%d)" % n)

func test_route_info() -> void:
	var f := GameFlow.new_run("knight", 1, 28, {"route": ["crypt", "frost", "throne"], "miniboss": "mini_bone_champion", "boss": "boss_lich"})
	var info := f.route_info()
	assert_eq(info.route.size(), 3)
	assert_eq(info.route[0], {"id": "crypt", "name": "The Crypt", "desc": BiomeDefs.desc_of("crypt"), "twist": "", "look": "crypt"})
	assert_eq(info.route[1].name, "Frostpeak")
	assert_eq(info.route[2].name, "Bone Throne")
	assert_eq(info.miniboss, {"id": "mini_bone_champion", "name": "Bone Champion"})
	assert_eq(info.boss, {"id": "boss_lich", "name": "The Lich"})

func test_act_started_uses_route() -> void:
	var f := GameFlow.new_run("knight", 2, 28, {"route": ["glade", "frost", "magma"]})
	var ev: Array[Dictionary] = []
	f.run.lap = 6
	f._new_biome(3, ev)
	var a := _first(ev, "act_started")
	assert_eq([a.act, a.biome, a.biome_name], [2, "frost", "Frostpeak"])
	assert_eq(a.biome_desc, BiomeDefs.desc_of("frost"))
	ev.clear()
	f.run.lap = 11
	f._new_biome(3, ev)
	a = _first(ev, "act_started")
	assert_eq([a.act, a.biome, a.biome_name], [3, "magma", "Magma Depths"])
	assert_eq(f.run.board.biome, "magma")
	assert_eq(a.board.biome, "magma")

func test_summary_carries_route() -> void:
	var f := GameFlow.new_run("knight", 2, 28, {"route": ["glade", "frost", "magma"], "boss": "boss_cinder_king"})
	var s := f._summary()
	assert_eq(s.route, ["glade", "frost", "magma"])
	assert_eq(s.boss_id, "boss_cinder_king")

func test_route_round_trip() -> void:
	var f := GameFlow.new_run("rogue", 9, 28, {"route": ["glade", "frost", "magma"], "miniboss": "mini_bone_champion", "boss": "boss_cinder_king"})
	f.run.chill = 2
	var j := JSON.stringify(f.to_dict())
	var g := GameFlow.from_dict(JSON.parse_string(j))
	assert_eq(Array(g.run.route), ["glade", "frost", "magma"])
	assert_eq(g.run.miniboss_id, "mini_bone_champion")
	assert_eq(g.run.boss_id, "boss_cinder_king")
	assert_eq(g.run.chill, 2)
	assert_eq(g.run.board.biome, "glade")
	assert_eq(JSON.stringify(g.to_dict()), j)
	# old saves (no route) load with the legacy route and bosses
	var d: Dictionary = JSON.parse_string(j)
	d.run.erase("route")
	d.run.erase("boss_id")
	d.run.erase("miniboss_id")
	d.run.erase("chill")
	d.run.board.erase("biome")
	var old := GameFlow.from_dict(d)
	assert_eq(Array(old.run.route), BiomeDefs.DEFAULT_ROUTE)
	assert_eq(old.run.boss_id, "boss_lich")
	assert_eq(old.run.board.biome, "")

func test_replay_equality_every_route() -> void:
	var k := 0
	for route in BiomeDefs.all_routes():
		var cls: String = HeroDefs.IDS[k % 4]
		k += 1
		var opts := {"route": route}
		var f := GameFlow.new_run(cls, 300 + k, 28, opts)
		var n := 0
		var errors := 0
		while not f.is_over() and n < 4000:
			var ev := f.apply(Bot.next_command(f))
			n += 1
			if not ev.is_empty() and ev[0].type == "error":
				errors += 1
		assert_eq(errors, 0, "bot issued no illegal commands on %s" % str(route))
		assert_true(f.is_over(), "run finished on %s" % str(route))
		var r := GameFlow.replay(cls, 300 + k, f.commands, 28, opts)
		assert_eq(JSON.stringify(r.to_dict()), JSON.stringify(f.to_dict()), "replay identical on %s" % str(route))

# ---------------------------------------------------------------- tile mix and rosters

func test_biome_tile_mix() -> void:
	var expect := {
		"glade": {"campfire": 3, "chest": 5, "empty": 3},
		"crypt": {"trap": 4, "empty": 3},
		"hollow": {"event": 6, "empty": 3},
		"frost": {"ice": 3, "trap": 0, "empty": 4},
		"throne": {"elite": 1, "enemy": 6},
		"magma": {"lava": 3, "empty": 2},
	}
	for id in expect:
		var l := Board.layout_for(28, id)
		for type in expect[id]:
			assert_eq(int(l.get(type, 0)), int(expect[id][type]), "%s %s" % [id, type])
		var total := 0
		for type in l:
			total += int(l[type])
		assert_eq(total, 24, "%s fills the 24 edge tiles" % id)
	for size in [24, 28, 32]:
		for id in BiomeDefs.DEFS:
			var tier := int(BiomeDefs.DEFS[id].tier)
			var b := Board.generate(Rng.new(3), tier, size, int(Balance.BIOME_LAPS[tier - 1]), id)
			assert_eq(b.size(), size)
			assert_eq(b.biome, id)
	var throne := Board.generate(Rng.new(4), 3, 28, 11, "throne")
	assert_eq(_count(throne, "elite"), 2, "the throne carries two elites")
	var magma := Board.generate(Rng.new(4), 3, 28, 11, "magma")
	assert_eq(_count(magma, "lava"), 3)
	var frost := Board.generate(Rng.new(4), 2, 28, 6, "frost")
	assert_eq(_count(frost, "ice"), 3)
	assert_eq(_count(frost, "trap"), 0)

func test_biome_enemy_rosters() -> void:
	for id in BiomeDefs.DEFS:
		var d: Dictionary = BiomeDefs.DEFS[id]
		var first := int(Balance.BIOME_LAPS[int(d.tier) - 1])
		var allowed := {d.elite: true}
		for pool in d.pools:
			for e in pool:
				allowed[e] = true
		for lap in range(first, first + 5):
			for s in 4:
				var b := Board.generate(Rng.new(s + lap * 10), int(d.tier), 28, lap, id)
				for t in b.tiles:
					for e in t.enemies:
						assert_true(allowed.has(e), "%s lap %d: %s is in the roster" % [id, lap, e])
	assert_eq(Board.enemy_pool(1, "glade"), BiomeDefs.DEFS.glade.pools[0])
	assert_eq(Board.enemy_pool(4, "glade"), BiomeDefs.DEFS.glade.pools[1])
	assert_eq(Board.enemy_pool(13, "magma"), BiomeDefs.DEFS.magma.pools[0])
	assert_eq(Board.enemy_pool(14, "magma"), BiomeDefs.DEFS.magma.pools[1])
	assert_eq(Board.enemy_pool(1, ""), EnemyDefs.POOLS[0], "no biome: legacy band pools")
	var elite := Board.roll_enemies(Rng.new(1), 3, 12, true, "magma")
	assert_eq(elite[0], "magma_brute")

func test_throne_mutation_spawns_extra_elite() -> void:
	assert_eq(Board.mutate_spawns_for(28, "throne"), ["elite", "enemy", "elite"])
	assert_eq(Board.mutate_spawns_for(28, "magma"), ["enemy", "enemy", "elite"])
	assert_eq(Board.mutate_spawns_for(28), ["enemy", "enemy", "elite"])

# ---------------------------------------------------------------- twists

func test_glade_campfire_heals_more() -> void:
	var f := _flow(["glade", "hollow", "throne"])
	f.run.hp = 40
	f.run.board.tiles[5] = Board.make_tile("campfire")
	f.run.pos = 0
	_force_roll(f, [5, 0])
	var ev := f.confirm_move()
	var h := _first(ev, "hp_changed")
	assert_eq(h.source, "campfire")
	assert_eq(h.amount, 45)
	var g := _flow(["crypt", "hollow", "throne"])
	g.run.hp = 40
	g.run.board.tiles[5] = Board.make_tile("campfire")
	_force_roll(g, [5, 0])
	assert_eq(_first(g.confirm_move(), "hp_changed").amount, 30, "crypt campfire: 30%")

func test_crypt_dodged_trap_pays_gold() -> void:
	var paid := 0
	var hurt := 0
	for s in 30:
		var f := _flow(["crypt", "hollow", "throne"], s)
		f.run.board.tiles[5] = Board.make_tile("trap")
		_force_roll(f, [5, 0])
		var ev := f.confirm_move()
		var t := _first(ev, "trap")
		var g := _first(ev, "gold_changed")
		if t.dodged:
			assert_eq(g.get("source", ""), "crypt")
			assert_eq(g.amount, Balance.CRYPT_DODGE_GOLD)
			paid += 1
		else:
			assert_true(g.is_empty(), "no gold when hit")
			hurt += 1
	assert_true(paid > 0 and hurt > 0)
	var h := _flow(["glade", "hollow", "throne"], 1)
	for s in 5:
		h.run.hp = 100
		h.run.board.tiles[5] = Board.make_tile("trap")
		h.run.pos = 0
		_force_roll(h, [5, 0])
		assert_true(_first(h.confirm_move(), "gold_changed").is_empty(), "no dodge gold outside the crypt")

func test_hollow_event_heals() -> void:
	var f := _flow(["crypt", "hollow", "throne"])
	var ev: Array[Dictionary] = []
	f.run.lap = 6
	f._new_biome(0, ev)
	f.run.hp = 50
	f._open_event(ev, "garden")
	ev = f.event_choose(0)
	var h := {}
	for e in ev:
		if e.type == "hp_changed" and e.source == "hollow":
			h = e
	assert_eq(h.get("amount", 0), 8, "8% heal after an event")
	var g := _flow(["crypt", "frost", "throne"])
	g.run.hp = 50
	var ev2: Array[Dictionary] = []
	g._open_event(ev2, "garden")
	for e in g.event_choose(0):
		assert_true(not (e.type == "hp_changed" and e.source == "hollow"), "no heal outside the hollow")

func test_frost_ice_freezes_a_die_next_fight() -> void:
	var froze := 0
	var slid := 0
	for s in 30:
		var f := _flow(["crypt", "frost", "throne"], s)
		f.run.board = Board.generate(f.run.rng, 2, 28, 6, "frost")
		for i in f.run.board.size():
			if not f.run.board.is_corner(i):
				f.run.board.tiles[i] = Board.make_tile("empty")
		f.run.board.tiles[5] = Board.make_tile("ice")
		f.run.board.tiles[9] = Board.make_tile("enemy", ["skeleton_minion"])
		f.run.pos = 0
		var hp := f.run.hp
		_force_roll(f, [5, 0])
		var ev := f.confirm_move()
		var t := _first(ev, "trap")
		assert_eq(t.ice, true)
		assert_eq(t.damage, 0)
		assert_eq(f.run.hp, hp, "ice never damages")
		if t.dodged:
			slid += 1
			assert_eq(f.run.chill, 0)
			continue
		froze += 1
		assert_eq(f.run.chill, 1)
		_force_roll(f, [4, 0])
		ev = f.confirm_move()
		assert_eq(f.phase, P.COMBAT)
		var st := {}
		for e in ev:
			if e.type == "status" and e.status == "chill":
				st = e
		assert_eq(st.get("value", 0), 1, "chill announced at combat start")
		var turn := _first(ev, "combat_turn_started")
		assert_eq(turn.locked.size(), 1, "one die locked on turn 1")
		assert_eq(f.run.chill, 0, "chill spent")
	assert_true(froze > 0 and slid > 0)

func test_throne_elites_roll_boss_passives_more() -> void:
	var boss := 0
	var n := 200
	for s in n:
		var f := _flow(["crypt", "hollow", "throne"], s)
		f.run.board.biome = "throne"
		f.run.board.tiles[5] = Board.make_tile("elite", ["skeleton_minion"], true)
		_force_roll(f, [5, 0])
		f.confirm_move()
		for e in f.combat.enemies:
			e.hp = 1
		f.combat.dice_values.assign([6, 6])
		f.combat_attack()
		for k in 10:
			if f.phase == P.DRAFT and f.offer.kind == "passive":
				break
			if f.phase == P.DRAFT and f.offer.kind == "draft":
				f.pick_draft(0)
			elif f.phase == P.DRAFT and f.offer.kind == "rune_assign":
				f.rune_assign(0)
			elif f.phase == P.FORGE:
				f.forge_apply(0, 0, "skip")
		if f.offer.get("kind", "") == "passive" and String(f.offer.options[0].rarity) == "boss":
			boss += 1
	assert_true(boss > n * 0.2 and boss < n * 0.42, "about 30%% boss-tier (%d/%d)" % [boss, n])

func test_magma_lava_pass_and_land() -> void:
	var f := _flow(["crypt", "hollow", "magma"])
	f.run.board.tiles[2] = Board.make_tile("lava")
	f.run.board.tiles[3] = Board.make_tile("lava")
	f.run.board.tiles[5] = Board.make_tile("lava")
	f.run.pos = 0
	_force_roll(f, [5, 0])
	var ev := f.confirm_move()
	var lava := _all(ev, "lava")
	assert_eq(lava.size(), 3, "two passed + one landed")
	var pass_dmg := int(round(100 * Balance.LAVA_PASS_PCT))
	var land_dmg := int(round(100 * Balance.LAVA_LAND_PCT))
	assert_eq([lava[0].idx, lava[0].landed, lava[0].damage], [2, false, pass_dmg])
	assert_eq([lava[1].idx, lava[1].landed, lava[1].damage], [3, false, pass_dmg])
	assert_eq([lava[2].idx, lava[2].landed, lava[2].damage], [5, true, land_dmg])
	assert_eq(f.run.hp, 100 - 2 * pass_dmg - land_dmg)
	assert_eq(f.run.board.tiles[5].type, "lava", "lava persists")
	assert_eq(_types(ev).find("hero_moved") < _types(ev).find("lava"), true, "lava after the move")
	# never lethal
	f.run.hp = 2
	f.run.pos = 0
	_force_roll(f, [5, 0])
	f.confirm_move()
	assert_eq(f.run.hp, 1)
	assert_eq(f.phase, P.BOARD_READY)
	# portal teleports skip the lava in between
	f.run.hp = 50
	f.run.pos = 0
	f.phase = P.PORTAL
	f.offer = {"kind": "portal", "tiles": [4]}
	assert_true(_all(f.portal_pick(4), "lava").is_empty())

# ---------------------------------------------------------------- new enemies

func _fight(ids: Array, lap := 1) -> void:
	run = RunState.create("knight", 1)
	run.max_hp = 200
	run.hp = 200
	run.lap = lap
	c = CombatState.new()
	c.begin(run, ids, false, EnemyDefs.is_boss(String(ids[0])), 0)

## Every enemy idles except `idx`, which executes `intent`. The hero's attack deals nothing.
func _act(intent: Dictionary, idx := 0) -> Array[Dictionary]:
	for e in c.enemies:
		e.intent = {"kind": "aim", "value": 0}
	c.enemies[idx].intent = intent
	c.dice_values.assign([0, 0])
	return c.attack(run)

## Intent kinds over `n` rolls from step 0.
func _cycle(id: String, n: int) -> Array:
	_fight([id])
	c.enemies[0].step = 0
	var out := []
	for k in n:
		c.roll_intent(run.rng, 0)
		out.append(c.enemies[0].intent.kind)
	return out

func test_new_enemy_patterns() -> void:
	assert_eq(_cycle("thorn_sprite", 4), ["heal", "attack", "heal", "attack"])
	assert_eq(_cycle("wolf_bandit", 3), ["attack", "attack", "attack"])
	_fight(["wolf_bandit"])
	c.enemies[0].step = 2
	c.roll_intent(run.rng, 0)
	assert_eq(c.enemies[0].intent, {"kind": "attack", "value": int(round(9 * Balance.enemy_atk_scale(1)))}, "wolf pounce")
	assert_eq(_cycle("hollow_wisp", 2), ["drain", "block"])
	assert_eq(_cycle("frost_skeleton", 3), ["curse", "attack", "block"])
	assert_eq(_cycle("ice_archer", 2), ["aim", "chill"])
	assert_eq(_cycle("bone_knight", 3), ["block", "attack", "buff"])
	assert_eq(_cycle("magma_brute", 3), ["burn", "block", "attack"])
	var kinds := {}
	for k in _cycle("ember_imp", 20):
		kinds[k] = true
	assert_true(kinds.has("burn") and kinds.has("attack"), "ember imp mixes burn and attacks")
	assert_eq(_cycle("mini_frost_warden", 4), ["chill", "curse", "attack", "block"])
	assert_eq(_cycle("mini_briar_beast", 3), ["attack", "heal", "attack"])
	assert_eq(_cycle("mini_cinder_brute", 3), ["burn", "attack", "block"])

func test_heal_intent_heals_allies() -> void:
	_fight(["thorn_sprite", "skeleton_minion"])
	c.enemies[0].hp = 3
	c.enemies[1].hp = 2
	var ev := _act({"kind": "heal", "value": 5})
	var heals := _all(ev, "enemy_healed")
	assert_eq(heals.size(), 2)
	assert_eq(c.enemies[0].hp, 8)
	assert_eq(c.enemies[1].hp, mini(7, int(c.enemies[1].max_hp)))
	# no overheal
	c.enemies[0].hp = c.enemies[0].max_hp
	c.enemies[1].hp = c.enemies[1].max_hp
	assert_true(_all(_act({"kind": "heal", "value": 5}), "enemy_healed").is_empty())

func test_drain_heals_by_damage_dealt() -> void:
	_fight(["hollow_wisp"])
	c.enemies[0].hp = 4
	var ev := _act({"kind": "drain", "value": 6})
	var d := {}
	for e in ev:
		if e.type == "damage" and e.target is String:
			d = e
	assert_eq(d.amount, 6)
	assert_eq(_first(ev, "enemy_healed").amount, mini(6, int(c.enemies[0].max_hp) - 4))
	# fully blocked: no heal
	run.block = 0
	c.enemies[0].max_hp = 2000
	c.enemies[0].hp = 999
	for e in c.enemies:
		e.intent = {"kind": "drain", "value": 3}
	run.dice[0].rune = "guard"
	c.dice_values.assign([5, 0])
	ev = c.attack(run)
	assert_true(_all(ev, "enemy_healed").is_empty(), "blocked drain does not heal")

func test_burn_ticks_and_decays() -> void:
	_fight(["ember_imp"])
	c.enemies[0].hp = 999
	c.enemies[0].max_hp = 999
	var ev := _act({"kind": "burn", "value": 3})
	assert_eq(c.hero_burn, 2, "3 stacks, ticked once")
	var burn := {}
	for e in ev:
		if e.type == "damage" and String(e.get("source", "")) == "burn":
			burn = e
	assert_eq(burn.amount, 3)
	assert_eq(run.hp, 197)
	_act({"kind": "aim", "value": 0})
	assert_eq(run.hp, 195)
	_act({"kind": "aim", "value": 0})
	assert_eq(run.hp, 194)
	assert_eq(c.hero_burn, 0)
	_act({"kind": "aim", "value": 0})
	assert_eq(run.hp, 194, "burn gone")
	# burn ignores block and can kill
	c.hero_burn = 10
	run.hp = 5
	c.dice_values.assign([0, 0])
	c.enemies[0].intent = {"kind": "aim", "value": 0}
	c.attack(run)
	assert_eq(c.result, "lost")
	# burn scales at half the attack rate
	_fight(["ember_imp"], 15)
	c.enemies[0].step = 0
	var mult := Balance.enemy_atk_scale(15)
	assert_near(float(c.enemies[0].atk_mult), mult)
	var found := false
	for k in 30:
		c.roll_intent(run.rng, 0)
		if c.enemies[0].intent.kind == "burn":
			assert_eq(c.enemies[0].intent.value, int(round(2 * (1.0 + (mult - 1.0) * Balance.BURN_SCALE))))
			found = true
			break
	assert_true(found)

func test_chill_attacks_and_locks() -> void:
	_fight(["ice_archer"])
	c.enemies[0].hp = 999
	var ev := _act({"kind": "chill", "value": 7})
	var d := {}
	for e in ev:
		if e.type == "damage" and e.target is String:
			d = e
	assert_eq(d.amount, 7)
	var turn := _first(ev, "combat_turn_started")
	assert_eq(turn.locked.size(), 1, "one die locked next turn")

func test_frost_skeleton_curses_two() -> void:
	_fight(["frost_skeleton"])
	c.enemies[0].hp = 999
	var ev := _act({"kind": "curse", "value": 2})
	assert_eq(_first(ev, "combat_turn_started").locked.size(), 2)

func test_armor_block_persists() -> void:
	_fight(["bone_knight"])
	assert_eq(c.enemies[0].traits, ["armor"])
	c.enemies[0].hp = 999
	_act({"kind": "block", "value": 5})
	assert_eq(c.enemies[0].block, 5)
	_act({"kind": "block", "value": 5})
	assert_eq(c.enemies[0].block, 10, "armor keeps its Block")
	_fight(["skeleton_warrior"])
	c.enemies[0].hp = 999
	_act({"kind": "block", "value": 5})
	_act({"kind": "block", "value": 5})
	assert_eq(c.enemies[0].block, 5, "normal Block expires")

func test_briar_thorns_reflect() -> void:
	_fight(["mini_briar_beast"])
	assert_eq(c.enemies[0].traits, ["thorns"])
	c.enemies[0].intent = {"kind": "aim", "value": 0}
	c.dice_values.assign([6, 6])
	var ev := c.attack(run)
	var th := {}
	for e in ev:
		if e.type == "damage" and String(e.get("source", "")) == "thorns" and e.target is String:
			th = e
	assert_eq(th.get("amount", 0), Balance.ENEMY_THORNS)
	assert_eq(run.hp, 200 - Balance.ENEMY_THORNS)
	run.hp = 2
	c.enemies[0].intent = {"kind": "aim", "value": 0}
	c.dice_values.assign([6, 6])
	c.attack(run)
	assert_eq(run.hp, 1, "thorns never kill")

func test_warden_ward_and_warrior_summons() -> void:
	_fight(["boss_bone_warden"], 15)
	assert_eq(c.enemies[0].traits, [])
	c.enemies[0].hp = 575
	c.enemies[0].max_hp = 1150
	var ev := _act({"kind": "attack", "value": 1})
	assert_eq(c.enemies[0].phase, 1)
	c.enemies[0].hp = 570
	c.dice_values.assign([6, 6])
	c.enemies[0].intent = {"kind": "summon", "value": 2}
	ev = c.attack(run)
	assert_eq(c.enemies[0].phase, 2)
	assert_eq(_first(ev, "boss_phase").traits, ["ward"])
	assert_eq(_all(ev, "summon").size(), 2)
	var m: Dictionary = c.enemies[1]
	assert_eq(m.id, "skeleton_warrior")
	assert_eq(m.max_hp, int(round(20 * Balance.enemy_scale(15))), "legion scales to the fight's lap")
	# warded: half damage while minions stand
	for e in c.enemies:
		e.intent = {"kind": "aim", "value": 0}
	var before := int(c.enemies[0].hp)
	c.enemies[0].block = 0
	c.target = 0
	c.dice_values.assign([6, 6])
	ev = c.attack(run)
	var dmg := {}
	for e in ev:
		if e.type == "damage" and e.target is int and e.target == 0:
			dmg = e
	assert_eq(dmg.warded, true)
	var full := int(c.last_combo.total)
	assert_eq(before - int(c.enemies[0].hp), int(ceil(full / 2.0)))
	# minions gone: full damage
	for k in range(1, c.enemies.size()):
		c.enemies[k].hp = 0
	for e in c.enemies:
		e.intent = {"kind": "aim", "value": 0}
	before = int(c.enemies[0].hp)
	c.target = 0
	c.dice_values.assign([6, 6])
	c.attack(run)
	assert_eq(before - int(c.enemies[0].hp), int(c.last_combo.total))

func test_cinder_king_scorch_and_restore() -> void:
	var f := GameFlow.new_run("knight", 1, 28, {"route": ["crypt", "hollow", "magma"], "boss": "boss_cinder_king"})
	f.debug_open("boss")
	c = f.combat
	run = f.run
	assert_eq(c.enemies[0].id, "boss_cinder_king")
	var before := []
	for d in run.dice:
		before.append(Array(d.faces))
	c.enemies[0].intent = {"kind": "scorch", "value": 1}
	c.dice_values.assign([0, 0])
	var ev := c.attack(run)
	var st := {}
	for e in ev:
		if e.type == "status" and e.status == "scorch":
			st = e
	assert_true(not st.is_empty())
	assert_eq(run.dice[st.die_idx].faces[st.face_idx], 0, "face scorched to blank")
	for e in c.enemies:
		e.hp = 1
		e.block = 0
	c.dice_values.assign([6, 6])
	f.combat_attack()
	var after := []
	for d in run.dice:
		after.append(Array(d.faces))
	assert_eq(after, before, "scorched faces restored after the fight")

func test_magma_golem_armor_then_pierce() -> void:
	_fight(["boss_magma_golem"])
	assert_eq(c.enemies[0].traits, ["armor"])
	_act({"kind": "block", "value": 40})
	_act({"kind": "block", "value": 40})
	assert_eq(c.enemies[0].block, 80, "molten shell keeps its Block")
	# at half HP a blocked hit still flips the phase; the shell shatters
	c.enemies[0].hp = int(c.enemies[0].max_hp) / 2
	c.enemies[0].block = 20
	c.enemies[0].intent = {"kind": "aim", "value": 0}
	c.dice_values.assign([1, 0])
	var ev := c.attack(run)
	assert_eq(c.enemies[0].phase, 2)
	assert_eq(c.enemies[0].traits, ["pierce"])
	assert_eq(c.enemies[0].block, 0, "the shell shatters")
	var shatter := {}
	for e in ev:
		if e.type == "block_gained" and String(e.get("source", "")) == "shatter":
			shatter = e
	assert_eq(shatter.get("amount", 0), -19)
	# pierce: attacks ignore Block
	run.block = 50
	for e in c.enemies:
		e.intent = {"kind": "attack", "value": 10}
	run.dice[0].rune = ""
	c.dice_values.assign([0, 0])
	run.hp = 100
	var hp := run.hp
	ev = c.attack(run)
	var d := {}
	for e in ev:
		if e.type == "damage" and e.target is String and String(e.source) == "boss_magma_golem":
			d = e
	assert_eq(d.pierce, true)
	assert_eq(d.blocked, 0)
	assert_eq(hp - run.hp, 10)

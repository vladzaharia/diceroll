extends RefCounted
## Twist-moment scenarios for the 2026-09-29 biomes (screenshot harness, tools/shot.gd): the real
## game (GameController + GameFlow) on a new biome's board, playing the flow's own events so the
## beats, the board hooks and the HUD twist chip show exactly what a run would.
##
##  twist_ore          Deep Mines: the hero lands on an ore vein; the ore choice is open
##  twist_cave_in      ... then takes the gold (--choice=1: the Face Raise): pick, cave-in, trap
##  twist_drum_smash   Orc Warcamp: the hero lands on a war drum and smashes it
##  twist_drum_rally   Orc Warcamp: a fight starts with two drums standing (WAR DRUMS, +ATK)
##  twist_heat         Sunscorched Ruins: a lap ends without an oasis (heat)
##  twist_oasis        Sunscorched Ruins: the hero lands on an oasis (cool this lap)
##  twist_moon_phase   Moonlit Woods: lap 11 -> 12, the moon grows to Half (HUD glyph, sky moon)
##  twist_full_moon    Moonlit Woods: lap 12 -> 13, the Full moon: moon rune chest + announce
##  twist_moon_meter   The Moon King fight after --turns=N attacks (default 2): the tide fills the
##                     boss HUD's moon; --beat=clouds attacks with two 1s (clouds push it back),
##                     --beat=moonfall starts phase 2 at 3/4 so the tide turns into Moonfall
##  twist_bury         The Sand Colossus in phase 2 buries two dice
## Common args: --seed=N --class=<id> --speed=N --wait=S (catch the beat), --cards=1 (encounter
## cards on; off by default so they don't cover the beat).

const NAMES := ["twist_ore", "twist_cave_in", "twist_drum_smash", "twist_drum_rally", "twist_heat", "twist_oasis",
	"twist_moon_phase", "twist_full_moon", "twist_moon_meter", "twist_bury"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var d := _Driver.new()
	d.name = "TwistScenario"
	d.scenario = name
	return d


class _Driver extends Node:
	var scenario := ""
	var c: GameController
	var args: Dictionary = {}

	func _ready() -> void:
		args = Shot.args if Shot else {}
		c = GameController.new()
		c.autosave = false
		c.persist_profile = false
		c.minigame_fallback = false
		EncounterCards.reset()
		EncounterCards.cards_off = String(args.get("cards", "0")) == "0"
		add_child(c)
		c.set_speed(float(args.get("speed", "1")))
		match scenario:
			"twist_ore", "twist_cave_in":
				await _ore()
			"twist_drum_smash":
				await _land("warcamp", "drum")
			"twist_drum_rally":
				await _rally()
			"twist_heat":
				await _lap_end("ruins", 11)
			"twist_oasis":
				await _land("ruins", "oasis")
			"twist_moon_phase":
				await _lap_end("moonlit", 11)
			"twist_full_moon":
				await _lap_end("moonlit", 12)
			"twist_moon_meter":
				await _moon_king()
			"twist_bury":
				await _bury()

	## A run whose route holds `biome` (at its tier), on that biome's first lap (+ `lap_in`).
	func _flow(biome: String, opts := {}) -> GameFlow:
		var tier := BoardScenarios.tier_of(biome)
		var route: Array = ["crypt", "hollow", "throne"]
		route[tier - 1] = biome
		var o := {"route": route}
		o.merge(opts, true)
		var f := GameFlow.new_run(String(args.get("class", "knight")), int(args.get("seed", "7")), Balance.BOARD_SIZE, o)
		if tier > 1:
			f.run.act = tier
			f.run.lap = int(Balance.BIOME_LAPS[tier - 1])
			f.run.board = Board.generate(f.run.rng, tier, Balance.BOARD_SIZE, f.run.lap, f.run.biome())
			f.run.level = 2 + tier * 3
			f.run.max_hp += 16 * (tier - 1)
			f.run.hp = f.run.max_hp
			for k in ["high", "giant", "twin"].slice(0, tier):
				f.run.dice.append(Die.make("", k))
		return f

	func _start(f: GameFlow) -> void:
		c.start(f)
		c.ui.sync(f)
		await _pause(0.4)

	## First tile of `type` at least `min_idx` into the ring (-1 when none).
	func _find(f: GameFlow, type: String, min_idx := 4) -> int:
		for i in range(min_idx, f.run.board.size()):
			if String(f.run.board.tiles[i].type) == type:
				return i
		for i in f.run.board.size():
			if String(f.run.board.tiles[i].type) == type:
				return i
		return -1

	## Hops the hero `steps` tiles onto `idx` through the real flow move.
	func _move_onto(f: GameFlow, idx: int, steps := 3) -> void:
		var n := f.run.board.size()
		f.run.pos = posmod(idx - steps, n)
		c.board.place_hero(f.run.pos)
		c.rig.home(c.board.hero, true)
		await _pause(0.5)
		var ev := f._move(steps, false)
		f._advance(ev)
		await c.play_events(ev)

	func _land(biome: String, type: String) -> void:
		var f := _flow(biome)
		var idx := _find(f, type)
		if idx < 0:
			idx = 9
			f.run.board.tiles[idx] = Board.make_tile(type)
		await _start(f)
		await _move_onto(f, idx)

	func _ore() -> void:
		var f := _flow("mines")
		var idx := _find(f, "ore")
		await _start(f)
		await _move_onto(f, idx)
		if scenario == "twist_cave_in":
			await _pause(0.6)
			await c.run_command("event_choose", [int(args.get("choice", "0"))])

	## A Warcamp fight on an enemy tile with two drums standing.
	func _rally() -> void:
		var f := _flow("warcamp")
		var drums := f.run.board.count("drum")
		for i in range(4, f.run.board.size()):
			if drums >= 2:
				break
			if String(f.run.board.tiles[i].type) == "empty" and not f.run.board.is_corner(i):
				f.run.board.tiles[i] = Board.make_tile("drum")
				drums += 1
		var idx := _find(f, "enemy", 3)
		await _start(f)
		f.run.pos = idx
		c.board.place_hero(idx)
		c.rig.home(c.board.hero, true)
		await _pause(0.4)
		var ev: Array[Dictionary] = []
		f._start_combat(f.run.board.tiles[idx].enemies, false, false, idx, ev, false, f.run.board.affixes_of(idx))
		await c.play_events(ev)

	## The hero crosses Start at the end of `lap` (a real lap end: heat, moon phase, mutation).
	func _lap_end(biome: String, lap: int) -> void:
		var f := _flow(biome)
		f.run.lap = lap
		var n := f.run.board.size()
		await _start(f)
		f.run.pos = n - 2
		c.board.place_hero(f.run.pos)
		c.ui.sync(f)
		c.rig.home(c.board.hero, true)
		await _pause(0.5)
		var ev := f._move(3, false)
		f._advance(ev)
		await c.play_events(ev)

	func _boss(biome: String, boss: String) -> GameFlow:
		var f := _flow(biome, {"boss": boss})
		f.run.pos = 0
		f.run.lap = Balance.TOTAL_LAPS
		await _start(f)
		await c.play_events(f.debug_open("boss", boss))
		return f

	func _moon_king() -> void:
		var f := await _boss("moonlit", "boss_moon_king")
		var beat := String(args.get("beat", ""))
		if beat == "moonfall" and f.combat:
			var ev := f.combat._boss_phase2(0, f.run)
			f.combat.moon = EnemyDefs.MOON_MAX - 1
			ev.append({"type": "moon_meter", "value": f.combat.moon, "delta": 0, "source": "start", "max": EnemyDefs.MOON_MAX})
			ev.append({"type": "enemy_intent", "enemy_idx": 0, "intent": f.combat.enemies[0].intent.duplicate()})
			await c.play_events(ev)
		var turns := int(args.get("turns", "1" if beat == "moonfall" else "2"))
		for t in turns:
			if f.combat == null or f.phase != GameFlow.Phase.COMBAT:
				break
			if beat == "clouds" and t == turns - 1:
				for k in mini(2, f.combat.dice_values.size()):
					f.combat.dice_values[k] = 1
				c.tray.set_values(f.combat.dice_values)
				await _pause(0.3)
			await c.run_command("combat_attack")
		if beat == "moonfall" and f.combat:
			await c.run_command("combat_attack")

	func _bury() -> void:
		var f := await _boss("ruins", "boss_sand_colossus")
		if f.combat == null:
			return
		var ev := f.combat._boss_phase2(0, f.run)
		f.combat.enemies[0].intent = {"kind": "bury", "value": 2}
		ev.append({"type": "enemy_intent", "enemy_idx": 0, "intent": f.combat.enemies[0].intent.duplicate()})
		await c.play_events(ev)
		await c.run_command("combat_attack")

	func _pause(t: float) -> void:
		await get_tree().create_timer(t, true, false, true).timeout

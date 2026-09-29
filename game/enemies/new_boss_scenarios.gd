class_name NewBossScenarios
extends RefCounted
## Fights of the 2026-09-29 biomes for the screenshot harness (tools/shot.gd): the real game
## (GameController + GameFlow) on the biome's own board, driven through the real flow so the HUD,
## intents, meters and beats are what a player sees. (The bare `boss_sand_colossus` /
## `boss_moon_king` names are FoeScenarios' staged fights; these carry a `fight_` prefix.)
##
##  fight_sand_colossus          Sunscorched Ruins final boss, phase 1 (attack / block / summon)
##  fight_sand_colossus_sandstorm  its phase 2 begins (the sandstorm beat), then it Buries 2 dice:
##                               after one ATTACK the hero's turn starts with the buried dice locked
##  fight_moon_king              Moonlit Woods final boss, phase 1 with the moon meter at 2
##  fight_moon_king_moonrise     the tide fills the meter: Moonrise forces the wolf form (the beat)
##  fight_moon_king_moonfall     phase 2, the meter fills again: the next intent turns into Moonfall
##  fight_rock_golem             Deep Mines elite: the Rock Golem leading two regulars
##
## Args: --class=<hero> --seed=N --cards=1 (first-encounter cards; off by default so the fight
## shows) --speed=N --turns=N (extra ATTACK turns before the shot).

const NAMES := ["fight_sand_colossus", "fight_sand_colossus_sandstorm", "fight_moon_king", "fight_moon_king_moonrise",
	"fight_moon_king_moonfall", "fight_rock_golem"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var d := _Driver.new()
	d.name = "NewBossScenario"
	d.scenario = name
	return d


class _Driver extends Node:
	var scenario := ""
	var c: GameController
	var f: GameFlow
	var args: Dictionary = {}

	func _ready() -> void:
		args = Shot.args if Shot else {}
		c = GameController.new()
		c.autosave = false
		c.persist_profile = false
		c.minigame_fallback = false
		EncounterCards.reset()
		EncounterCards.cards_off = String(args.get("cards", "0")) != "1"
		add_child(c)
		c.set_speed(float(args.get("speed", "1.5")))
		var boss := scenario.begins_with("fight_sand") or scenario.begins_with("fight_moon")
		var route: Array = ["mines", "warcamp", "ruins"]
		if scenario.begins_with("fight_moon"):
			route = ["glade", "hollow", "moonlit"]
		var bid := "boss_sand_colossus" if scenario.begins_with("fight_sand") else "boss_moon_king"
		f = GameFlow.new_run(String(args.get("class", "knight")), int(args.get("seed", "7")), Balance.BOARD_SIZE,
			{"route": route, "boss": bid})
		if boss:
			_late_run(3)
			f.run.pos = 0
			f.run.lap = Balance.TOTAL_LAPS
		c.start(f)
		await c.wait(0.3)
		if boss:
			await c.play_events(f.debug_open("boss", bid))
		else:
			await _rock_golem()
		for t in int(args.get("turns", "0")):
			if f.phase == GameFlow.Phase.COMBAT:
				await c.run_command("combat_attack")
		match scenario:
			"fight_sand_colossus_sandstorm":
				await _phase2(0)
				# the phase-2 pattern opens with Bury 2: one ATTACK and the next turn starts buried
				if f.phase == GameFlow.Phase.COMBAT:
					await c.run_command("combat_attack")
			"fight_moon_king":
				await _meter(2)
			"fight_moon_king_moonrise":
				await _meter(EnemyDefs.MOON_MAX - 1)
				await c.wait(0.4)
				await c.play_events(f.combat._moon_tide(f.run))
			"fight_moon_king_moonfall":
				await _phase2(0)
				await _meter(EnemyDefs.MOON_MAX - 1)
				await c.wait(0.3)
				await c.play_events(f.combat._moon_tide(f.run))

	## A tier-`act` run: that tier's first lap, its board, a grown hero and dice pool.
	func _late_run(act: int) -> void:
		f.run.act = act
		f.run.lap = int(Balance.BIOME_LAPS[act - 1]) + 1
		f.run.board = Board.generate(f.run.rng, act, Balance.BOARD_SIZE, f.run.lap, f.run.biome())
		f.run.level = 2 + act * 3
		f.run.max_hp += 16 * (act - 1)
		f.run.hp = f.run.max_hp
		for k in ["high", "giant", "twin"].slice(0, act):
			f.run.dice.append(Die.make("", k))

	## The boss enters phase 2 through the real rule (CombatState._boss_phase2 + a fresh intent).
	func _phase2(i: int) -> void:
		var ev: Array[Dictionary] = f.combat._boss_phase2(i, f.run)
		f.combat.roll_intent(f.run.rng, i)
		ev.append({"type": "enemy_intent", "enemy_idx": i, "intent": f.combat.enemies[i].intent.duplicate()})
		await c.play_events(ev)

	## Sets the Moon King's meter (as a few tides would have) and plays the meter event.
	func _meter(v: int) -> void:
		if f.combat == null or f.combat.moon_king() < 0:
			return
		var d := v - int(f.combat.moon)
		f.combat.moon = v
		await c.play_events([{"type": "moon_meter", "value": v, "delta": d, "source": "tide", "max": EnemyDefs.MOON_MAX}])

	## Deep Mines, lap 3: the Rock Golem elite and two regulars on a fight tile of the Mines board.
	func _rock_golem() -> void:
		var pos := 3
		for i in [3, 4, 5, 6]:
			if not f.run.board.is_corner(i):
				pos = i
				break
		f.run.lap = 3
		f.run.pos = pos
		c.board.place_hero(pos)
		var ev: Array[Dictionary] = []
		f._start_combat(["rock_golem", "skeleton_minion", "bone_cutthroat"], true, false, pos, ev, false,
			[[], [], []])
		await c.play_events(ev)

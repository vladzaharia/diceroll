extends RefCounted
## Integration scenarios for the screenshot harness (tools/shot.gd): the real game
## (GameController + GameFlow) in a given state. They never touch the player's save.
##
##  game_title    title screen over the orbiting act 1 board
##  game_board    fresh run, BOARD_READY          game_rolled   after ROLL (targets shown)
##  game_combat   mid-fight, dice marked for a reroll
##  game_combo    mid-fight right after ATTACK (combo banner held on screen)
##  game_shop / game_draft / game_forge / game_event / game_portal   modals and picks
##  game_boss     act boss fight (--act=1..3)
##  game_victory / game_defeat   summary screens
##  game_continue runs --steps=N bot commands, JSON round-trips the run and presents it
##  game_manual   drives the UI like a player (ROLL -> tap die -> fight -> ATTACK -> draft),
##                saving a shot per step: <shot>_step_NN.png
##  play_auto     full run driven by Bot through the real presentation; periodic shots
##                <shot>_NN.png (--shots=N --every=S), final shot <shot>_final.png, quits at
##                game end or --timeout. Run it with a large --wait (e.g. --wait=5000).
##
## Common args: --class=knight|barbarian|mage|rogue --seed=N --act=N --speed=N

const NAMES := ["game_title", "game_board", "game_rolled", "game_combat", "game_combo", "game_shop", "game_draft",
	"game_forge", "game_event", "game_portal", "game_boss", "game_victory", "game_defeat", "game_manual", "game_continue", "play_auto"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var d := _Driver.new()
	d.name = "GameScenario"
	d.scenario = name
	return d


class _Driver extends Node:
	var scenario := ""
	var c: GameController
	var args: Dictionary = {}
	var _shot_base := ""
	var _t0 := 0

	func _ready() -> void:
		args = Shot.args if Shot else {}
		_shot_base = String(args.get("shot", "user://auto.png")).get_basename()
		c = GameController.new()
		c.autosave = false
		add_child(c)
		c.set_speed(float(args.get("speed", "3" if scenario == "play_auto" else "1")))
		match scenario:
			"game_title":
				c.show_title()
			"play_auto":
				await _auto()
			"game_manual":
				await _manual()
			"game_continue":
				_continue()
			_:
				await _state()

	func _flow() -> GameFlow:
		var cls := String(args.get("class", "knight"))
		var seed := int(args.get("seed", "7"))
		var f := GameFlow.new_run(cls, seed)
		var act := int(args.get("act", "1"))
		if act > 1:
			f.run.act = act
			f.run.board = Board.generate(f.run.rng, act)
			f.run.level = 2 + act * 3
			f.run.max_hp += 16 * (act - 1)
			f.run.hp = f.run.max_hp
			for k in act:
				f.run.dice.append(Die.new())
		return f

	func _state() -> void:
		var f := _flow()
		match scenario:
			"game_portal":
				f.run.pos = 18
			"game_boss":
				f.run.pos = 0
		c.start(f)
		await get_tree().create_timer(0.3).timeout
		match scenario:
			"game_rolled":
				await c.run_command("roll_board")
			"game_combat", "game_combo":
				var ids := String(args.get("enemies", "skeleton_warrior,skeleton_minion,skeleton_archer"))
				f.run.pos = 3
				c.board.place_hero(3)
				await c.play_events(f.debug_open("combat", ids))
				# mark dice for a reroll like a player would (bot choice), stop before ATTACK
				for k in 8:
					var cmd := Bot.next_command(f)
					if cmd[0] != "combat_toggle" and cmd[0] != "combat_set_target":
						break
					await c.run_command(cmd[0], cmd.slice(1))
				if scenario == "game_combo":
					c.ui.banner.hold = true
					if f.combat.rerolls_left > 0 and f.combat.marked.has(true):
						await c.run_command("combat_reroll")
					await c.run_command("combat_attack")
			"game_shop":
				f.run.gold = 120
				await c.play_events(f.debug_open("shop"))
			"game_draft":
				await c.play_events(f.debug_open("draft"))
			"game_forge":
				await c.play_events(f.debug_open("forge"))
			"game_event":
				await c.play_events(f.debug_open("event", String(args.get("event", "duel"))))
			"game_portal":
				await c.play_events(f.debug_open("portal"))
			"game_boss":
				await c.play_events(f.debug_open("boss"))
			"game_victory", "game_defeat":
				f.run.stats.merge({"fights_won": 21, "damage_dealt": 2140, "damage_taken": 388, "gold_earned": 512,
					"best_combo": "Full House", "best_mult": 4.0, "board_turns": 47, "max_act": 3 if scenario == "game_victory" else 2}, true)
				var ev: Array[Dictionary] = []
				f._finish(scenario == "game_victory", ev)
				await c.play_events(ev)

	## Plays --steps bot commands without presentation, round-trips the run through JSON (as
	## the save does) and presents the loaded copy: checks Continue for mid-run phases.
	func _continue() -> void:
		var f := _flow()
		for k in int(args.get("steps", "60")):
			if f.is_over():
				break
			f.apply(Bot.next_command(f))
		var loaded := GameFlow.from_dict(JSON.parse_string(JSON.stringify(f.to_dict())))
		print("CONTINUE phase=%s act=%d lap=%d pos=%d" % [GameFlow.phase_name(loaded.phase), loaded.run.act, loaded.run.lap, loaded.run.pos])
		c.start(loaded)

	# --- manual-style drive through the UI signals ------------------------------------------

	func _manual() -> void:
		var f := _flow()
		# Make the tiles 2..6 ahead enemies so any board roll lands in a fight.
		for i in range(1, 7):
			f.run.board.tiles[i] = Board.make_tile("enemy", ["skeleton_minion"])
		f.run.xp = 9  # the first win levels up -> draft
		c.start(f)
		var step := 0
		await _pause(0.8)
		step = await _step(step, "board ready")
		c.ui.board_hud.roll_pressed.emit()
		await c.idle
		step = await _step(step, "rolled")
		# tap the die with the highest value
		var best := 0
		for i in f.board_roll.size():
			if f.board_roll[i] > f.board_roll[best]:
				best = i
		c.tray.die_pressed.emit(best)
		await c.idle
		step = await _step(step, "fight started")
		var guard := 0
		while f.phase == GameFlow.Phase.COMBAT and guard < 30:
			guard += 1
			c.ui.combat_hud.attack_pressed.emit()
			await c.idle
			step = await _step(step, "after attack %d (phase %s)" % [guard, GameFlow.phase_name(f.phase)])
		if f.phase == GameFlow.Phase.DRAFT:
			await _pause(0.6)
			step = await _step(step, "draft open")
			c.ui.draft.draft_picked.emit(0)
			await c.idle
			step = await _step(step, "after draft pick (phase %s)" % GameFlow.phase_name(f.phase))
		print("MANUAL_DONE phase=%s hp=%d gold=%d level=%d" % [GameFlow.phase_name(f.phase), f.run.hp, f.run.gold, f.run.level])
		await _quit(0)

	func _step(n: int, what: String) -> int:
		await _pause(0.35)
		var path := "%s_step_%02d.png" % [_shot_base, n]
		await _save(path)
		print("STEP %02d %s -> %s" % [n, what, path])
		return n + 1

	# --- full auto run ------------------------------------------------------------------------

	func _auto() -> void:
		var f := _flow()
		var shots := int(args.get("shots", "25"))
		var every := float(args.get("every", "8"))
		var timeout := float(args.get("timeout", "1500"))
		_t0 = Time.get_ticks_msec()
		print("AUTO_START class=%s seed=%d speed=%.1f" % [f.run.class_id, f.run.seed, c.speed])
		c.start(f)
		_shooter(shots, every)
		var last_phase := -1
		var last_act := 0
		var errors := 0
		var stuck := 0
		while not f.is_over():
			if _elapsed() > timeout:
				print("AUTO_TIMEOUT after %.0fs phase=%s" % [_elapsed(), GameFlow.phase_name(f.phase)])
				await _quit(3)
				return
			if f.phase != last_phase or f.run.act != last_act:
				last_phase = f.phase
				last_act = f.run.act
				print("PHASE %s act=%d lap=%d pos=%d hp=%d/%d gold=%d lvl=%d dice=%d t=%.0fs" % [GameFlow.phase_name(f.phase),
					f.run.act, f.run.lap, f.run.pos, f.run.hp, f.run.max_hp, f.run.gold, f.run.level, f.run.dice.size(), _elapsed()])
			var cmd := Bot.next_command(f)
			var n := f.commands.size()
			var evs: Array = f.apply(cmd)
			for ev: Dictionary in evs:
				if String(ev.get("type", "")) == "error":
					errors += 1
					print("ERROR_EVENT %s -> %s" % [str(cmd), String(ev.get("msg", ""))])
			if f.commands.size() == n:
				stuck += 1
				if stuck > 5:
					print("AUTO_STUCK on %s" % str(cmd))
					await _quit(4)
					return
			else:
				stuck = 0
			await c.play_events(evs)
			# a real player needs a beat to look; keep it short at auto speed
			await c.wait(0.15)
		var won := f.phase == GameFlow.Phase.VICTORY
		print("AUTO_END %s act=%d lap=%d lvl=%d commands=%d errors=%d t=%.0fs" % ["VICTORY" if won else "GAME_OVER",
			f.run.act, f.run.lap, f.run.level, f.commands.size(), errors, _elapsed()])
		await _pause(2.5)
		await _save("%s_final.png" % _shot_base)
		await _quit(0)

	func _shooter(n: int, every: float) -> void:
		for i in n:
			await get_tree().create_timer(every, true, false, true).timeout
			if not is_inside_tree():
				return
			await _save("%s_%02d.png" % [_shot_base, i + 1])

	func _elapsed() -> float:
		return (Time.get_ticks_msec() - _t0) / 1000.0

	func _pause(t: float) -> void:
		await get_tree().create_timer(t, true, false, true).timeout

	func _save(path: String) -> void:
		if Shot and Shot.has_method("_save"):
			await Shot._save(path)

	func _quit(code: int) -> void:
		Audio.stop_all()
		c.queue_free()
		for i in 3:
			await get_tree().process_frame
		Character.clear_cache()
		get_tree().quit(code)

class_name AutoScenarios
extends RefCounted
## Speed / AUTO scenarios for the screenshot harness (registered through game/scenarios.gd):
##
##  ui_speed_auto     the run HUD with the speed pill, AUTO on, its reason ticker and the
##                    highlighted control (--view=board|combat, --speed=1|2|4)
##  ui_auto_settings  the AUTO settings panel over the board
##  game_auto         a run with AUTO switched on through the HUD toggle for --seconds=N
##                    (default 60) at --speed (default 2); shots <shot>_NN.png every --every
##                    seconds and <shot>_final.png (--auto-rules=default|all)
##
## play_auto --ui-auto=1 (game/scenarios.gd) plays a whole run through the same AUTO toggle
## path (AutoPilot + Bot.decide), see run_ui_auto().

const NAMES := ["ui_speed_auto", "ui_auto_settings", "game_auto"]


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var d := _Driver.new()
	d.name = "AutoScenario"
	d.scenario = name
	return d


## Rules for scripted runs: "all" = every scope on, no stops (plays to the end);
## "default" = the player defaults (stops before the boss, at shops, on boss passives).
static func rules_from(args: Dictionary) -> AutoRules:
	var r := AutoRules.all_on() if String(args.get("auto-rules", "all")) == "all" else AutoRules.new()
	var stop := String(args.get("stop", ""))
	for s in stop.split(",", false):
		match s:
			"boss": r.stop_before_boss = true
			"miniboss": r.stop_before_miniboss = true
			"passive": r.stop_on_boss_passive = true
			"shop":
				r.shop = false
				r.stop_on_shop = true
	if args.has("stop-hp"):
		r.stop_hp_below = float(args["stop-hp"])
	return r


## Turns AUTO on the way a player does: the HUD toggle -> UiRoot.menu("auto") -> AutoPilot.
static func toggle_on(c: GameController) -> void:
	c.ui.auto_hud.auto_btn.set_active(true)
	c.ui.auto_hud.auto_toggled.emit(true)


## Full run driven by AUTO through the real toggle path. When AUTO hands control back
## (a stop condition), plays one step as the player (manual path), then turns AUTO on again.
## Once, it also checks that a manual command takes over (AUTO turns off).
## Prints AUTO_HANDBACK / MANUAL_TAKEOVER / AUTO_END lines.
static func run_ui_auto(d: Node, c: GameController, f: GameFlow, args: Dictionary, shot_base: String) -> int:
	var rules := rules_from(args)
	c.auto.set_rules(rules)
	var timeout := float(args.get("timeout", "1500"))
	var t0 := Time.get_ticks_msec()
	var el := func() -> float: return (Time.get_ticks_msec() - t0) / 1000.0
	print("UI_AUTO_START class=%s seed=%d speed=%.1f rules=%s" % [f.run.class_id, f.run.seed, c.speed, JSON.stringify(rules.to_dict())])
	c.start(f)
	await d.get_tree().process_frame
	toggle_on(c)
	var handbacks := 0
	var takeover_checked := String(args.get("takeover", "1")) != "1"
	var last_n := -1
	var last_change := el.call()
	var last_phase := -1
	var last_act := 0
	var handback_shots := 0
	while not f.is_over():
		await d.get_tree().create_timer(0.1, true, false, true).timeout
		if not d.is_inside_tree():
			return 5
		if el.call() > timeout:
			print("AUTO_TIMEOUT after %.0fs phase=%s" % [el.call(), GameFlow.phase_name(f.phase)])
			return 3
		if f.phase != last_phase or f.run.act != last_act:
			last_phase = f.phase
			last_act = f.run.act
			print("PHASE %s act=%d lap=%d pos=%d hp=%d/%d gold=%d lvl=%d dice=%d steps=%d t=%.0fs" % [GameFlow.phase_name(f.phase),
				f.run.act, f.run.lap, f.run.pos, f.run.hp, f.run.max_hp, f.run.gold, f.run.level, f.run.dice.size(), c.auto.steps, el.call()])
		if f.commands.size() != last_n:
			last_n = f.commands.size()
			last_change = el.call()
		elif el.call() - last_change > 30.0:
			print("AUTO_STUCK phase=%s enabled=%s busy=%s can_act=%s" % [GameFlow.phase_name(f.phase), c.auto.enabled, c.busy, c.auto.can_act()])
			return 4
		if c.auto.enabled and not takeover_checked and f.phase == GameFlow.Phase.BOARD_READY and c.auto.steps > 12 and c.auto.can_act():
			# the player taps ROLL themselves: AUTO must turn off, the roll must still happen
			takeover_checked = true
			var n := f.commands.size()
			c.ui.board_hud.roll_pressed.emit()
			print("MANUAL_TAKEOVER auto_off=%s rolled=%s" % [not c.auto.enabled, f.commands.size() == n + 1])
			await _idle(c)
			toggle_on(c)
			continue
		if not c.auto.enabled and not c.busy and c.auto.can_act() and not f.is_over():
			handbacks += 1
			var why := String(c.auto.last_decision.get("stop_reason", ""))
			print("AUTO_HANDBACK #%d phase=%s lap=%d reason=\"%s\" auto_on=%s" % [handbacks, GameFlow.phase_name(f.phase), f.run.lap, why, c.auto.enabled])
			if handback_shots < 4 and shot_base != "":
				handback_shots += 1
				await d.get_tree().create_timer(0.5, true, false, true).timeout
				await _save("%s_handback_%02d.png" % [shot_base, handback_shots])
			# the player plays this step (the manual path), then turns AUTO back on
			var step := Bot.decide(f, AutoRules.all_on())
			if not bool(step.stop):
				var cmd: Array = step.cmd
				c.run_command(String(cmd[0]), cmd.slice(1))
				await _idle(c)
			if not f.is_over():
				toggle_on(c)
	var won := f.phase == GameFlow.Phase.VICTORY
	print("AUTO_END %s act=%d lap=%d lvl=%d commands=%d auto_steps=%d handbacks=%d t=%.0fs" % ["VICTORY" if won else "GAME_OVER",
		f.run.act, f.run.lap, f.run.level, f.commands.size(), c.auto.steps, handbacks, el.call()])
	return 0


static func _idle(c: GameController) -> void:
	for i in 200:
		await c.get_tree().create_timer(0.05, true, false, true).timeout
		if not c.busy and (c.flow == null or c.flow.is_over() or c.auto.can_act()):
			return


static func _save(path: String) -> void:
	var shot: Node = Engine.get_main_loop().root.get_node_or_null("Shot")
	if shot and shot.has_method("_save"):
		await shot._save(path)


class _Driver extends Node:
	var scenario := ""
	var c: GameController
	var args: Dictionary = {}
	var _shot_base := ""

	func _ready() -> void:
		var shot: Node = get_tree().root.get_node_or_null("Shot")
		args = shot.args if shot else {}
		_shot_base = String(args.get("shot", "user://auto.png")).get_basename()
		c = GameController.new()
		c.autosave = false
		add_child(c)
		c.set_speed(float(args.get("speed", "2")))
		var f := GameFlow.new_run(String(args.get("class", "knight")), int(args.get("seed", "7")))
		match scenario:
			"ui_speed_auto":
				await _speed_auto(f)
			"ui_auto_settings":
				c.start(f)
				await get_tree().create_timer(0.3).timeout
				c.ui.open_auto_settings()
			"game_auto":
				await _game_auto(f)

	func _speed_auto(f: GameFlow) -> void:
		c.auto.set_rules(AutoRules.new())
		if String(args.get("view", "board")) == "combat":
			c.start(f)
			await get_tree().create_timer(0.3).timeout
			f.run.pos = 3
			c.board.place_hero(f.run.pos)
			await c.play_events(f.debug_open("combat", "skeleton_warrior,skeleton_minion,skeleton_archer"))
			# play the first marks so a reroll plan is on screen
			for k in 2:
				var d := Bot.decide(f, c.auto.rules)
				if bool(d.stop) or String(d.cmd[0]) != "combat_toggle":
					break
				await c.run_command(String(d.cmd[0]), d.cmd.slice(1))
		else:
			c.start(f)
			await get_tree().create_timer(0.3).timeout
			await c.run_command("roll_board")
		await get_tree().create_timer(0.4).timeout
		c.ui.auto_hud.ticker_hold = 999.0
		c.auto.preview(60.0)

	func _game_auto(f: GameFlow) -> void:
		var secs := float(args.get("seconds", "60"))
		var every := float(args.get("every", "6"))
		c.auto.set_rules(AutoScenarios.rules_from(args))
		c.start(f)
		await get_tree().create_timer(0.4).timeout
		AutoScenarios.toggle_on(c)
		print("GAME_AUTO_START speed=%.1f seconds=%.0f" % [c.speed, secs])
		c.auto.stepped.connect(func(cmd: Array, why: String) -> void: print("STEP %s  %s" % [str(cmd), why]))
		c.auto.stopped.connect(func(why: String) -> void: print("AUTO_STOPPED %s" % why))
		var t := 0.0
		var k := 0
		while t < secs and not f.is_over():
			await get_tree().create_timer(every, true, false, true).timeout
			t += every
			k += 1
			await AutoScenarios._save("%s_%02d.png" % [_shot_base, k])
		c.ui.auto_hud.auto_toggled.emit(false)
		print("GAME_AUTO_END steps=%d phase=%s lap=%d hp=%d/%d" % [c.auto.steps, GameFlow.phase_name(f.phase), f.run.lap, f.run.hp, f.run.max_hp])
		await get_tree().create_timer(0.6, true, false, true).timeout
		await AutoScenarios._save("%s_final.png" % _shot_base)
		Audio.stop_all()
		c.queue_free()
		for i in 3:
			await get_tree().process_frame
		Character.clear_cache()
		get_tree().quit(0)

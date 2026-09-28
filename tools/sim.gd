extends SceneTree
## Balance simulator: plays N runs per class with the greedy Bot (the balance reference) or the
## player-facing AUTO policy (Bot.decide with every scope on and no stop conditions).
## Usage: godot --headless --path . -s tools/sim.gd -- --runs=300 --class=all --seed=1
##        [--board=24|28|32] [--route=glade,frost,magma] [--boss=boss_lich] [--verbose]
##        [--policy=greedy|smart] [--focus=balanced|damage|defense|economy]
## Without --route each run draws its own route (one biome per tier) and bosses from its seed.
## Prints per class: win%, avg act reached, avg board turns, avg combat turns, avg run length in
## commands; then win% per route, per final boss and per route + boss over all classes. Any
## error event or command-cap hit exits with code 1.

const MAX_COMMANDS := 20000

func _init() -> void:
	var runs := 100
	var cls := "all"
	var seed0 := 1
	var verbose := false
	var board := Balance.BOARD_SIZE
	var opts := {}
	var policy := "greedy"
	var focus := "balanced"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = arg.substr(7).to_int()
		elif arg.begins_with("--class="):
			cls = arg.substr(8)
		elif arg.begins_with("--seed="):
			seed0 = arg.substr(7).to_int()
		elif arg.begins_with("--board="):
			board = arg.substr(8).to_int()
		elif arg.begins_with("--route="):
			opts["route"] = Array(arg.substr(8).split(",", false))
			if not BiomeDefs.valid_route(opts.route):
				print("bad --route (want one biome per tier, e.g. glade,frost,magma): ", opts.route)
				quit(2)
				return
		elif arg.begins_with("--boss="):
			opts["boss"] = arg.substr(7)
		elif arg.begins_with("--policy="):
			policy = arg.substr(9)
			if not (policy in ["greedy", "smart"]):
				print("bad --policy (greedy|smart): ", policy)
				quit(2)
				return
		elif arg.begins_with("--focus="):
			focus = arg.substr(8)
			if not AutoRules.FOCUSES.has(focus):
				print("bad --focus (%s): %s" % ["|".join(AutoRules.FOCUSES), focus])
				quit(2)
				return
		elif arg == "--verbose":
			verbose = true
	var classes: Array = HeroDefs.IDS if cls == "all" else [cls]
	var total_errors := 0
	var total_stuck := 0
	var rows: Array = []
	var by_route := {}   # route -> [wins, runs]
	var by_boss := {}
	var by_combo := {}
	var by_mini := {}    # mini-boss -> [wins, fights]
	var rules := AutoRules.all_on(focus)
	var decide_us := 0
	var decide_max_us := 0
	var decide_calls := 0
	var stops := 0
	var t0 := Time.get_ticks_msec()
	for c in classes:
		var wins := 0
		var act_sum := 0
		var board_turns := 0
		var combat_turns := 0
		var cmd_sum := 0
		var level_sum := 0
		var lap_sum := 0
		var fights_won_sum := 0
		var deaths := {}
		var stuck := 0
		for r in runs:
			var s: int = seed0 + r * 7919
			var f := GameFlow.new_run(c, s, board, opts)
			var n := 0
			var last_fight := ""
			while not f.is_over() and n < MAX_COMMANDS:
				var cmd: Array
				if policy == "smart":
					var t1 := Time.get_ticks_usec()
					var d := Bot.decide(f, rules)
					var dt := Time.get_ticks_usec() - t1
					decide_us += dt
					decide_max_us = maxi(decide_max_us, dt)
					decide_calls += 1
					if d.stop:
						stops += 1
						cmd = Bot.next_command(f)
					else:
						cmd = d.cmd
				else:
					cmd = Bot.next_command(f)
				var ev := f.apply(cmd)
				n += 1
				for e in ev:
					if e.type == "error":
						total_errors += 1
						if total_errors <= 20:
							print("ERROR class=%s seed=%d phase=%s cmd=%s msg=%s" % [c, s, GameFlow.phase_name(f.phase), str(cmd), e.msg])
					elif e.type == "combat_started":
						var ids: Array = []
						for en in e.enemies:
							ids.append(en.id)
						last_fight = "A%d L%d %s" % [f.run.act, f.run.lap, ",".join(ids)]
					elif e.type == "combat_won" and e.get("miniboss", false):
						_tally(by_mini, f.run.miniboss_id, true)
			if not f.is_over():
				stuck += 1
				total_stuck += 1
			var won := f.phase == GameFlow.Phase.VICTORY
			if won:
				wins += 1
			else:
				var key := "boss" if last_fight.contains("boss_") else "act%d" % f.run.act
				if last_fight.contains("mini_"):
					key = "mini"
					_tally(by_mini, f.run.miniboss_id, false)
				deaths[key] = int(deaths.get(key, 0)) + 1
				if verbose:
					print("  died %s seed=%d route=%s at %s lvl=%d dice=%d" % [c, s, ",".join(f.run.route), last_fight, f.run.level, f.run.dice.size()])
			var route := ",".join(f.run.route)
			var reached := won or last_fight.contains("boss_")
			_tally(by_route, route, won, reached)
			_tally(by_boss, f.run.boss_id, won, reached)
			_tally(by_combo, route + " / " + f.run.boss_id, won, reached)
			act_sum += f.run.act
			board_turns += int(f.run.stats.get("board_turns", 0))
			combat_turns += int(f.run.stats.get("combat_turns", 0))
			cmd_sum += f.commands.size()
			level_sum += f.run.level
			lap_sum += f.run.lap
			fights_won_sum += int(f.run.stats.get("fights_won", 0))
		rows.append([c, 100.0 * wins / runs, float(act_sum) / runs, float(board_turns) / runs,
			float(combat_turns) / runs, float(cmd_sum) / runs, float(level_sum) / runs, float(fights_won_sum) / runs, deaths, stuck, float(lap_sum) / runs])
	print("")
	print("| class | win% | avg act | avg lap | avg board turns | avg combat turns | avg commands | avg level | avg fights won | deaths |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for row in rows:
		print("| %s | %.1f | %.2f | %.1f | %.1f | %.1f | %.0f | %.1f | %.1f | %s |" % [row[0], row[1], row[2], row[10], row[3], row[4], row[5], row[6], row[7], _fmt(row[8])])
		if row[9] > 0:
			print("  WARNING: %d runs hit the command cap" % row[9])
	_table("route", by_route)
	_table("final boss", by_boss)
	_table("route / final boss", by_combo)
	_table("mini-boss", by_mini, false)
	print("")
	print("policy=%s%s board=%d laps=%d opts=%s" % [policy, (" focus=" + focus) if policy == "smart" else "", board, Balance.TOTAL_LAPS, str(opts)])
	if policy == "smart":
		print("decide(): %d calls, avg %.2f ms, max %.1f ms, unexpected stops %d" % [decide_calls, decide_us / 1000.0 / maxi(1, decide_calls), decide_max_us / 1000.0, stops])
	print("runs/class=%d seed=%d errors=%d capped=%d time=%.1fs" % [runs, seed0, total_errors, total_stuck, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0 if total_errors == 0 and total_stuck == 0 else 1)

func _tally(d: Dictionary, key: String, won: bool, reached := false) -> void:
	var v: Array = d.get(key, [0, 0, 0])
	d[key] = [int(v[0]) + (1 if won else 0), int(v[1]) + 1, int(v[2]) + (1 if reached else 0)]

func _table(title: String, d: Dictionary, runs := true) -> void:
	if d.is_empty():
		return
	print("")
	if not runs:
		print("| %s | fights won%% | fights |" % title)
		print("|---|---|---|")
		for k in d:
			print("| %s | %.1f | %d |" % [k, 100.0 * d[k][0] / maxi(1, d[k][1]), d[k][1]])
		return
	print("| %s | win%% | runs | reached boss%% | boss win%% |" % title)
	print("|---|---|---|---|---|")
	var keys := d.keys()
	keys.sort()
	for k in keys:
		var v: Array = d[k]
		print("| %s | %.1f | %d | %.1f | %.1f |" % [k, 100.0 * v[0] / maxi(1, v[1]), v[1], 100.0 * v[2] / maxi(1, v[1]), 100.0 * v[0] / maxi(1, v[2])])

func _fmt(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort()
	var parts: Array = []
	for k in keys:
		parts.append("%s:%d" % [k, d[k]])
	return " ".join(parts)

extends SceneTree
## Balance simulator: plays N runs per class with the greedy Bot.
## Usage: godot --headless --path . -s tools/sim.gd -- --runs=300 --class=all --seed=1 [--board=32]
## Prints per class: win%, avg act reached, avg board turns, avg combat turns,
## avg run length in commands, plus any error events and command-cap hits (both must be zero;
## either one exits with code 1).

const MAX_COMMANDS := 20000

func _init() -> void:
	var runs := 100
	var cls := "all"
	var seed0 := 1
	var verbose := false
	var board := Balance.BOARD_SIZE
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = arg.substr(7).to_int()
		elif arg.begins_with("--class="):
			cls = arg.substr(8)
		elif arg.begins_with("--seed="):
			seed0 = arg.substr(7).to_int()
		elif arg.begins_with("--board="):
			board = arg.substr(8).to_int()
		elif arg == "--verbose":
			verbose = true
	var classes: Array = HeroDefs.IDS if cls == "all" else [cls]
	var total_errors := 0
	var total_stuck := 0
	var rows: Array = []
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
			var f := GameFlow.new_run(c, s, board)
			var n := 0
			var last_fight := ""
			while not f.is_over() and n < MAX_COMMANDS:
				var cmd := Bot.next_command(f)
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
			if not f.is_over():
				stuck += 1
				total_stuck += 1
			if f.phase == GameFlow.Phase.VICTORY:
				wins += 1
			else:
				var key := "boss" if last_fight.contains("boss_") else "act%d" % f.run.act
				if last_fight.contains("mini_"):
					key = "mini"
				deaths[key] = int(deaths.get(key, 0)) + 1
				if verbose:
					print("  died %s seed=%d at %s lvl=%d dice=%d" % [c, s, last_fight, f.run.level, f.run.dice.size()])
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
	print("")
	print("board=%d laps=%d" % [board, Balance.TOTAL_LAPS])
	print("runs/class=%d seed=%d errors=%d capped=%d time=%.1fs" % [runs, seed0, total_errors, total_stuck, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0 if total_errors == 0 and total_stuck == 0 else 1)

func _fmt(d: Dictionary) -> String:
	var keys := d.keys()
	keys.sort()
	var parts: Array = []
	for k in keys:
		parts.append("%s:%d" % [k, d[k]])
	return " ".join(parts)

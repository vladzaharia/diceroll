extends "res://tests/test_case.gd"
## decide() timing: must stay under 30 ms per call (cold caches) on the dev Mac. Prints timings.

const BUDGET_MS := 30.0

func _combat_flow(n_dice: int, rerolls: int, seed: int, runes: Array) -> GameFlow:
	var f := GameFlow.new_run("knight", seed)
	f.run.dice.clear()
	var kinds := ["standard", "giant", "loaded", "high", "standard", "twin"]
	for i in n_dice:
		f.run.dice.append(Die.make(String(runes[i % runes.size()]), kinds[i]))
	f.debug_open("combat", "bandit,brute,cultist")
	f.combat.rerolls_left = rerolls
	return f

func _time_decide(f: GameFlow) -> float:
	Bot.clear_cache()
	var t0 := Time.get_ticks_usec()
	Bot.decide(f, AutoRules.new())
	return (Time.get_ticks_usec() - t0) / 1000.0

func test_decide_under_budget() -> void:
	var worst := 0.0
	var lines: Array[String] = []
	var rune_sets := {"plain": [""], "runes": ["", "echo", "heavy", "thunder", "guard", "blade"], "wild": ["", "wild", "echo", "heavy", "thunder", "guard"]}
	for rs in rune_sets:
		for cfg in [[3, 2], [4, 2], [5, 1], [5, 2], [5, 4], [6, 2]]:
			var times: Array[float] = []
			for seed in [1, 2, 3]:
				var f := _combat_flow(cfg[0], cfg[1], seed, rune_sets[rs])
				times.append(_time_decide(f))
			times.sort()
			var med: float = times[1]
			worst = maxf(worst, med)
			lines.append("combat %s %d dice %d rerolls: median %.1f ms (max %.1f)" % [rs, cfg[0], cfg[1], med, times[2]])
	# a whole early run of mixed phases
	var g := GameFlow.new_run("mage", 9)
	var rules := AutoRules.all_on()
	var tmax := 0.0
	var tsum := 0.0
	var calls := 0
	var by_phase := {}
	Bot.clear_cache()
	for n in 1500:
		if g.is_over():
			break
		var ph := GameFlow.phase_name(g.phase)
		var t0 := Time.get_ticks_usec()
		var d := Bot.decide(g, rules)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		tmax = maxf(tmax, ms)
		tsum += ms
		calls += 1
		by_phase[ph] = maxf(float(by_phase.get(ph, 0.0)), ms)
		g.apply(d.cmd)
	lines.append("full run from cold caches: %d calls, avg %.2f ms, max %.1f ms, max by phase %s" % [calls, tsum / calls, tmax, str(by_phase)])
	for l in lines:
		print("  [bot perf] " + l)
	assert_true(worst < BUDGET_MS, "worst median combat decide() %.1f ms >= %.0f ms" % [worst, BUDGET_MS])
	assert_true(tmax < BUDGET_MS, "slowest decide() in a run %.1f ms >= %.0f ms" % [tmax, BUDGET_MS])

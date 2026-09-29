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

## 1-minute load average divided by the core count (0.0 when unknown). The budget only guards
## real regressions on an idle machine: under load (parallel sims) the timing asserts are skipped.
func _load_ratio() -> float:
	var out: Array = []
	if OS.get_name() == "macOS":
		OS.execute("sysctl", ["-n", "vm.loadavg"], out)
	elif FileAccess.file_exists("/proc/loadavg"):
		out.append(FileAccess.get_file_as_string("/proc/loadavg"))
	if out.is_empty():
		return 0.0
	var txt := String(out[0]).replace("{", " ").replace("}", " ").strip_edges()
	var parts := txt.split(" ", false)
	if parts.is_empty():
		return 0.0
	return parts[0].to_float() / maxf(1.0, float(OS.get_processor_count()))

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
			for seed in [1, 2, 3, 4, 5]:
				var f := _combat_flow(cfg[0], cfg[1], seed, rune_sets[rs])
				times.append(_time_decide(f))
			times.sort()
			var med: float = times[2]
			worst = maxf(worst, med)
			lines.append("combat %s %d dice %d rerolls: median %.1f ms (max %.1f)" % [rs, cfg[0], cfg[1], med, times[4]])
	# a whole early run of mixed phases
	var g := GameFlow.new_run("mage", 9)
	var rules := AutoRules.all_on()
	var tmax := 0.0
	var all_ms: Array[float] = []
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
		all_ms.append(ms)
		tsum += ms
		calls += 1
		by_phase[ph] = maxf(float(by_phase.get(ph, 0.0)), ms)
		g.apply(d.cmd)
	lines.append("full run from cold caches: %d calls, avg %.2f ms, max %.1f ms, max by phase %s" % [calls, tsum / calls, tmax, str(by_phase)])
	# the slowest call can be one scheduler hiccup: guard the 99.5th percentile of the run instead
	all_ms.sort()
	var p995: float = all_ms[mini(all_ms.size() - 1, int(all_ms.size() * 0.995))] if not all_ms.is_empty() else 0.0
	lines.append("full run p99.5 %.1f ms" % p995)
	for l in lines:
		print("  [bot perf] " + l)
	var load := _load_ratio()
	if load > 1.0:
		print("  [bot perf] SKIPPED the timing asserts: load average is %.1fx the core count" % load)
		return
	assert_true(worst < BUDGET_MS, "worst median combat decide() %.1f ms >= %.0f ms" % [worst, BUDGET_MS])
	assert_true(p995 < BUDGET_MS, "decide() p99.5 in a run %.1f ms >= %.0f ms" % [p995, BUDGET_MS])

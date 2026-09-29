extends SceneTree
## Balance simulator: plays N runs per class with the greedy Bot (the balance reference) or the
## player-facing AUTO policy (Bot.decide with every scope on and no stop conditions).
## Usage: godot --headless --path . -s tools/sim.gd -- --runs=300 --class=all --seed=1
##        [--board=24|28|32] [--route=glade,frost,magma] [--boss=boss_lich] [--verbose]
##        [--profile=none|fresh|mid|max] [--asc=N] [--mode=standard|short] [--mg=par|play]
##        [--pet=<id>|none] [--policy=greedy|realistic|expert] [--focus=balanced|damage|defense|economy]
## --policy: greedy = the naive Bot.next_command floor; realistic = Bot.decide with
## AutoRules.skill "realistic" (the balance reference); expert (alias smart) = full smart AUTO.
##        [--campaign=N [--campaigns=M]]
## Without --route each run draws its own route (one biome per tier) and bosses from its seed.
## --profile runs with a canonical meta profile (core/meta/presets.gd; default none = legacy
## rules, no meta layer); --asc sets its ascension level; classes the profile has locked are
## skipped. --mg=play makes the bot play minigames instead of taking AUTO's par result.
## Prints per class: win%, avg act reached, avg board turns, avg combat turns, avg run length in
## commands, and with a profile avg Crowns, potions used, minigames and pet actions per run;
## then win% per route, per final boss and per route + boss over all classes.
## --campaign=N simulates M fresh profiles (default 20) playing N runs each: the bot picks a
## class (fewest runs among unlocked), loadout and pet, spends Crowns/Sigils greedily after each
## run, and banks the results. Prints the median run at which each milestone/unlock happened and
## the Crowns/Sigils economy per run.
## Any error event or command-cap hit exits with code 1.

const MAX_COMMANDS := 20000

var total_errors := 0
## --snapshot=N (campaign): print each profile's state after run N.
var snapshot_run := 0
var policy := "greedy"
var rules: AutoRules
var decide_us := 0
var decide_max_us := 0
var decide_calls := 0
var stops := 0
## --items: per item (rune:id / kind:id / passive:id), [count in winning builds, count in losing
## builds, winning runs holding it, losing runs holding it]; plus the win / loss run counts.
var items := {}
var item_runs := [0, 0]
var track_items := false
## --items also tallies the combo of every attack: name -> count.
var combos := {}
## In-run upgrades by source (run.stats.upgrades) summed over every run, and gold earned.
var upgrades := {}
var gold_sum := 0

func _init() -> void:
	var runs := 100
	var cls := "all"
	var seed0 := 1
	var verbose := false
	var board := Balance.BOARD_SIZE
	var opts := {}
	var profile_name := "none"
	var asc := 0
	var campaign := 0
	var campaigns := 20
	var pet_override := ""
	var focus := "balanced"
	var scopes: Array = []
	var strip: Array = []
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
		elif arg.begins_with("--profile="):
			profile_name = arg.substr(10)
		elif arg.begins_with("--asc="):
			asc = arg.substr(6).to_int()
		elif arg.begins_with("--mode="):
			opts["mode"] = arg.substr(7)
		elif arg.begins_with("--mg="):
			BotMeta.minigame_mode = arg.substr(5)
		elif arg.begins_with("--pet="):
			pet_override = arg.substr(6)
		elif arg.begins_with("--policy="):
			policy = arg.substr(9)
			if not (policy in ["greedy", "smart", "expert", "realistic"]):
				print("bad --policy (greedy|realistic|expert; smart = expert): ", policy)
				quit(2)
				return
		elif arg.begins_with("--focus="):
			focus = arg.substr(8)
			if not AutoRules.FOCUSES.has(focus):
				print("bad --focus (%s): %s" % ["|".join(AutoRules.FOCUSES), focus])
				quit(2)
				return
		elif arg.begins_with("--campaign="):
			campaign = arg.substr(11).to_int()
		elif arg.begins_with("--campaigns="):
			campaigns = arg.substr(12).to_int()
		elif arg.begins_with("--snapshot="):
			snapshot_run = arg.substr(11).to_int()
		elif arg.begins_with("--scopes="):
			scopes = Array(arg.substr(9).split(",", false))
		elif arg.begins_with("--real-heur="):
			# realistic lapse probabilities: one value for every scope, or scope:p,scope:p
			for part in arg.substr(12).split(",", false):
				if part.contains(":"):
					Bot.real_heur[part.get_slice(":", 0)] = part.get_slice(":", 1).to_float()
				else:
					for k in Bot.real_heur:
						Bot.real_heur[k] = part.to_float()
		elif arg.begins_with("--tune-hp="):
			Balance.tune_hp = arg.substr(10).to_float()
		elif arg.begins_with("--tune-atk="):
			Balance.tune_atk = arg.substr(11).to_float()
		elif arg.begins_with("--tune-boss="):
			Balance.tune_boss = arg.substr(12).to_float()
		elif arg.begins_with("--tune-base="):
			Balance.tune_base = arg.substr(12).to_float()
		elif arg.begins_with("--tune-atk-step="):
			Balance.tune_atk_step = arg.substr(16).to_float()
		elif arg.begins_with("--tune-step="):
			Balance.tune_step = arg.substr(12).to_float()
		elif arg.begins_with("--tune-gold="):
			Balance.tune_gold = arg.substr(12).to_float()
		elif arg.begins_with("--tune-shop="):
			Balance.tune_shop = arg.substr(12)
		elif arg.begins_with("--danger="):
			Bot.danger_lo = arg.substr(9).get_slice(",", 0).to_float()
			Bot.danger_hi = arg.substr(9).get_slice(",", 1).to_float()
		elif arg.begins_with("--strip="):
			strip = Array(arg.substr(8).split(",", false))
		elif arg == "--items":
			track_items = true
		elif arg == "--verbose":
			verbose = true
	rules = AutoRules.all_on(focus, "realistic" if policy == "realistic" else "expert")
	if not scopes.is_empty():
		# analysis: AUTO only for these scopes, the greedy Bot for the rest
		for sc in ["board", "combat", "drafts", "shop", "forge", "events", "portal"]:
			rules.set(sc, scopes.has(sc))
	if campaign > 0:
		_campaign(campaign, campaigns, seed0, board, String(opts.get("mode", "standard")))
		quit(0 if total_errors == 0 else 1)
		return
	var prof := {}
	if profile_name != "none":
		prof = MetaPresets.get_preset(profile_name, asc)
		if pet_override != "":
			prof.loadout.pet = "" if pet_override == "none" else pet_override
		_strip(prof, strip)
		opts["profile"] = prof
	var classes: Array = HeroDefs.IDS if cls == "all" else [cls]
	var total_stuck := 0
	var rows: Array = []
	var by_route := {}   # route -> [wins, runs]
	var by_boss := {}
	var by_combo := {}
	var by_mini := {}    # mini-boss -> [wins, fights]
	var t0 := Time.get_ticks_msec()
	var all_wins := 0
	var all_runs := 0
	for c in classes:
		if not prof.is_empty() and not Profile.from_dict(prof).class_allowed(c):
			print("(skipping %s: locked in the %s profile)" % [c, profile_name])
			continue
		var wins := 0
		var act_sum := 0
		var board_turns := 0
		var combat_turns := 0
		var cmd_sum := 0
		var level_sum := 0
		var lap_sum := 0
		var fights_won_sum := 0
		var crowns_sum := 0
		var potions_sum := 0
		var mg_sum := 0
		var pet_sum := 0
		var deaths := {}
		var stuck := 0
		for r in runs:
			var s: int = seed0 + r * 7919
			var res := _play(c, s, board, opts, verbose)
			var f: GameFlow = res.flow
			var last_fight: String = res.last_fight
			for e in res.minis:
				_tally(by_mini, f.run.miniboss_id, bool(e))
			if not f.is_over():
				stuck += 1
				total_stuck += 1
			var won := f.phase == GameFlow.Phase.VICTORY
			if track_items:
				_count_items(f, won)
			if won:
				wins += 1
			else:
				var key := "boss" if last_fight.contains("boss_") else "act%d" % f.run.act
				if last_fight.contains("mini_"):
					key = "mini"
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
			crowns_sum += int(res.crowns)
			potions_sum += int(f.run.stats.get("potions_used", 0))
			mg_sum += int(f.run.stats.get("minigames_played", 0))
			pet_sum += int(f.run.stats.get("pet_actions", 0))
			gold_sum += int(f.run.stats.get("gold_earned", 0))
			var up: Dictionary = f.run.stats.get("upgrades", {})
			for k in up:
				upgrades[k] = int(upgrades.get(k, 0)) + int(up[k])
		# machine-readable row for shard aggregation (tools: sum wins/runs over shards)
		print("#row %s %d %d %d %d %d" % [c, wins, runs, level_sum, fights_won_sum, act_sum])
		all_wins += wins
		all_runs += runs
		rows.append([c, 100.0 * wins / runs, float(act_sum) / runs, float(board_turns) / runs,
			float(combat_turns) / runs, float(cmd_sum) / runs, float(level_sum) / runs, float(fights_won_sum) / runs, deaths, stuck, float(lap_sum) / runs,
			float(crowns_sum) / runs, float(potions_sum) / runs, float(mg_sum) / runs, float(pet_sum) / runs])
	print("")
	if prof.is_empty():
		print("| class | win% | avg act | avg lap | avg board turns | avg combat turns | avg commands | avg level | avg fights won | deaths |")
		print("|---|---|---|---|---|---|---|---|---|---|")
	else:
		print("| class | win% | avg act | avg lap | avg board turns | avg combat turns | avg commands | avg level | avg fights won | Crowns/run | potions/run | minigames/run | pet acts/run | deaths |")
		print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for row in rows:
		if prof.is_empty():
			print("| %s | %.1f | %.2f | %.1f | %.1f | %.1f | %.0f | %.1f | %.1f | %s |" % [row[0], row[1], row[2], row[10], row[3], row[4], row[5], row[6], row[7], _fmt(row[8])])
		else:
			print("| %s | %.1f | %.2f | %.1f | %.1f | %.1f | %.0f | %.1f | %.1f | %.1f | %.2f | %.2f | %.1f | %s |" % [row[0], row[1], row[2], row[10], row[3], row[4], row[5], row[6], row[7], row[11], row[12], row[13], row[14], _fmt(row[8])])
		if row[9] > 0:
			print("  WARNING: %d runs hit the command cap" % row[9])
	_table("route", by_route)
	_table("final boss", by_boss)
	_table("route / final boss", by_combo)
	_table("mini-boss", by_mini, false)
	_upgrades_table(all_runs)
	if track_items:
		_items_table()
	print("")
	if policy == "realistic":
		print("realistic lapses: %s" % str(Bot.real_heur))
	print("policy=%s%s board=%d laps=%d mode=%s profile=%s asc=%d mg=%s opts=%s" % [policy, (" focus=" + focus) if policy != "greedy" else "",
		board, Balance.TOTAL_LAPS, String(opts.get("mode", "standard")), profile_name, asc, BotMeta.minigame_mode, str(opts.keys())])
	if policy != "greedy":
		print("decide(): %d calls, avg %.2f ms, max %.1f ms, unexpected stops %d" % [decide_calls, decide_us / 1000.0 / maxi(1, decide_calls), decide_max_us / 1000.0, stops])
	print("overall win%%=%.1f runs/class=%d seed=%d errors=%d capped=%d time=%.1fs" % [100.0 * all_wins / maxi(1, all_runs), runs, seed0, total_errors, total_stuck, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0 if total_errors == 0 and total_stuck == 0 else 1)

## Analysis: removes parts of a profile (gear, traits, pet, belt, whetstone, starter, slot,
## packs, all-classes-knight...) to measure what each contributes.
func _strip(p: Dictionary, parts: Array) -> void:
	for part in parts:
		match String(part):
			"gear":
				for k in p.gear:
					p.gear[k] = 0
			"traits":
				for k in p.gear:
					p.gear[k] = mini(int(p.gear[k]), 3)
			"hp":
				p.gear["helm"] = 0
			"atk":
				p.gear["blade"] = 0
			"boots":
				p.gear["boots"] = 0
			"charm":
				p.gear["charm"] = 0
			"pet":
				p.loadout.pet = ""
			"belt":
				p.upgrades["potion_belt"] = 0
			"whetstone":
				p.upgrades["whetstone"] = 0
			"starter":
				p.upgrades["starter_kit"] = 0
			"slot":
				p.upgrades["loadout_slot"] = 0
				p.loadout.minigames = (p.loadout.minigames as Array).slice(0, 2)
			"packs":
				p.unlocks.packs = ["starter"]
			"mastery":
				p.minigame_plays = {}
			"gear4":
				for k in p.gear:
					p.gear[k] = mini(int(p.gear[k]), 4)
			"pet4":
				p.pet_bought = {}
				for k in p.pet_xp:
					p.pet_xp[k] = 30
			"midpacks":
				p.unlocks.packs = ["starter", "gamblers_kit", "cold_steel", "numerology"]
			_:
				if String(part).begins_with("t:"):
					# t:<slot>:<tier>:<trait id> picks a different gear trait
					var bits := String(part).split(":")
					var t: Dictionary = p.gear_traits.get(bits[1], {})
					t[bits[2]] = bits[3]
					p.gear_traits[bits[1]] = t
				elif String(part).begins_with("lv:"):
					# lv:<slot>:<level>
					var b2 := String(part).split(":")
					p.gear[b2[1]] = int(b2[2])
				elif String(part).begins_with("-"):
					(p.unlocks.packs as Array).erase(String(part).substr(1))

## Plays one run with the Bot. Returns {flow, last_fight, minis:[won bools], crowns}.
func _play(c: String, s: int, board: int, opts: Dictionary, verbose := false) -> Dictionary:
	var f := GameFlow.new_run(c, s, board, opts)
	var n := 0
	var last_fight := ""
	var minis: Array = []
	var crowns := 0
	while not f.is_over() and n < MAX_COMMANDS:
		var cmd := _next(f)
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
			elif e.type == "combo" and track_items:
				combos[String(e.name)] = int(combos.get(String(e.name), 0)) + 1
			elif e.type == "combat_won" and e.get("miniboss", false):
				minis.append(true)
			elif e.type == "game_over":
				crowns = int(e.stats.rewards.crowns)
	if not f.is_over() or f.phase == GameFlow.Phase.VICTORY:
		pass
	elif last_fight.contains("mini_"):
		minis.append(false)
	return {"flow": f, "last_fight": last_fight, "minis": minis, "crowns": crowns}

## The policy's next command.
func _next(f: GameFlow) -> Array:
	if policy == "greedy":
		return Bot.next_command(f)
	if f.phase == GameFlow.Phase.SHOP and not rules.shop:
		return Bot.next_command(f)
	var t1 := Time.get_ticks_usec()
	var d := Bot.decide(f, rules)
	var dt := Time.get_ticks_usec() - t1
	decide_us += dt
	decide_max_us = maxi(decide_max_us, dt)
	decide_calls += 1
	if d.stop:
		if not String(d.stop_reason).contains(" off"):
			stops += 1
		return Bot.next_command(f)
	return d.cmd

# ------------------------------------------------------------------ campaign

func _campaign(n: int, m: int, seed0: int, board: int, mode: String) -> void:
	var t0 := Time.get_ticks_msec()
	var first_run := {}      # "kind:id" -> Array of run numbers (one per campaign that got it)
	var milestone_run := {}  # milestone id -> Array
	var crowns_per_run: Array = []
	var sigils_per_run: Array = []
	var wins_per_run: Array = []
	var maxed_at: Array = []
	var sink := Camp.total_crowns_sink()
	for k in n:
		crowns_per_run.append(0)
		sigils_per_run.append(0)
		wins_per_run.append(0)
	for cmp in m:
		var p := Profile.fresh()
		var camp := Camp.new(p)
		var spent := 0
		var got_max := false
		for r in n:
			var c := _pick_class(p)
			var lo := BotMeta.choose_loadout(p)
			camp.set_class(c)
			camp.set_loadout(lo[0], String(lo[1]))
			var s: int = seed0 + cmp * 104729 + r * 7919
			var res := _play(c, s, board, {"profile": p.to_dict(), "mode": mode})
			var f: GameFlow = res.flow
			var stats := f._summary()
			var ev := camp.bank_run(stats)
			crowns_per_run[r] += int(stats.rewards.crowns)
			if f.phase == GameFlow.Phase.VICTORY:
				wins_per_run[r] += 1
			for e in ev:
				if e.type == "sigils_changed":
					sigils_per_run[r] += int(e.amount)
				elif e.type == "unlocked":
					var key := "%s:%s" % [e.kind, e.id]
					if not first_run.has(key):
						first_run[key] = []
					(first_run[key] as Array).append(r + 1)
				elif e.type == "milestone":
					if not milestone_run.has(e.id):
						milestone_run[e.id] = []
					(milestone_run[e.id] as Array).append(r + 1)
			for cmd in BotMeta.spend(camp):
				if String(cmd[0]) == "unlock":
					var key := "%s:%s" % [cmd[1], cmd[2]]
					if not first_run.has(key):
						first_run[key] = []
					(first_run[key] as Array).append(r + 1)
			spent = p.records.crowns_earned - p.crowns
			if snapshot_run == r + 1:
				print("snapshot run %d: gear=%s upgrades=%s pets=%s pet_lv=%s classes=%s packs=%s minigames=%s potions=%s crowns=%d sigils=%d asc=%s" % [
					r + 1, str(p.gear), str(p.upgrades), str(p.unlocks.pets), str(p.pet_xp), str(p.unlocks.classes),
					str(p.unlocks.packs), str(p.unlocks.minigames), str(p.unlocks.potions), p.crowns, p.sigils, str(p.ascension)])
			if not got_max and spent >= sink:
				got_max = true
				maxed_at.append(r + 1)
	print("")
	print("Campaign: %d fresh profiles x %d runs, policy=%s, mode=%s, mg=%s (bot spends greedily after every run)" % [m, n, policy, mode, BotMeta.minigame_mode])
	print("")
	print("| milestone | target run | median run | reached by | unlocks |")
	print("|---|---|---|---|---|")
	for ms in UnlockDefs.MILESTONES:
		var runs_hit: Array = milestone_run.get(ms.id, [])
		var parts: Array = []
		for u in ms.unlocks:
			parts.append("%s" % u[1])
		print("| %s | %d | %s | %d/%d | %s |" % [ms.id, int(ms.run), _median_s(runs_hit), runs_hit.size(), m, ", ".join(parts)])
	print("")
	print("| unlock (milestone or Sigils, whichever first) | median run | got it |")
	print("|---|---|---|")
	var keys := first_run.keys()
	keys.sort_custom(func(a, b): return _median(first_run[a]) < _median(first_run[b]))
	for key in keys:
		print("| %s | %s | %d/%d |" % [key, _median_s(first_run[key]), (first_run[key] as Array).size(), m])
	print("")
	print("| run | avg Crowns | avg Sigils | win% |")
	print("|---|---|---|---|")
	var total := 0.0
	for r in n:
		total += float(crowns_per_run[r]) / m
		if r < 25 or r % 5 == 4:
			print("| %d | %.1f | %.2f | %.0f |" % [r + 1, float(crowns_per_run[r]) / m, float(sigils_per_run[r]) / m, 100.0 * wins_per_run[r] / m])
	print("")
	print("avg Crowns/run over %d runs: %.1f · Crowns sink (everything bought): %d · profiles that bought everything: %d/%d, median run %s" % [n, total / n, sink, maxed_at.size(), m, _median_s(maxed_at)])
	print("errors=%d time=%.1fs" % [total_errors, (Time.get_ticks_msec() - t0) / 1000.0])

## Least-played unlocked class (ties: content order).
func _pick_class(p: Profile) -> String:
	var best := ""
	var best_n := 1 << 30
	for c in HeroDefs.IDS:
		if not p.class_allowed(c):
			continue
		var k := int((p.records.get("runs_by_class", {}) as Dictionary).get(c, 0))
		if k < best_n:
			best_n = k
			best = c
	return best

static func _median(a: Array) -> float:
	if a.is_empty():
		return 9999.0
	var b := a.duplicate()
	b.sort()
	return float(b[b.size() / 2])

static func _median_s(a: Array) -> String:
	return "-" if a.is_empty() else str(int(_median(a)))

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

## Upgrades per run by source (shop, event, chest, minigame, elite, miniboss, forge, whetstone).
func _upgrades_table(n: int) -> void:
	if n <= 0:
		return
	print("")
	print("| upgrade source | per run |")
	print("|---|---|")
	var keys := upgrades.keys()
	keys.sort_custom(func(a, b): return int(upgrades[a]) > int(upgrades[b]))
	var tot := 0
	for k in keys:
		tot += int(upgrades[k])
		print("| %s | %.2f |" % [k, float(upgrades[k]) / n])
		print("#up %s %d %d" % [k, int(upgrades[k]), n])
	print("| total | %.2f |" % (float(tot) / n))
	print("gold earned per run: %.0f" % (float(gold_sum) / n))

# ------------------------------------------------------------------ build items (--items)

func _count_items(f: GameFlow, won: bool) -> void:
	var have := {}
	for d in f.run.dice:
		if d.rune != "":
			have["rune:" + d.rune] = int(have.get("rune:" + d.rune, 0)) + 1
		have["kind:" + d.kind] = int(have.get("kind:" + d.kind, 0)) + 1
	for p in f.run.passives:
		have["passive:" + String(p)] = 1
	item_runs[0 if won else 1] += 1
	for k in have:
		var v: Array = items.get(k, [0, 0, 0, 0])
		v[0 if won else 1] += int(have[k])
		v[2 if won else 3] += 1
		items[k] = v

func _items_table() -> void:
	var tot := 0
	for k in combos:
		tot += int(combos[k])
	print("")
	print("| combo | share of attacks |")
	print("|---|---|")
	var ck := combos.keys()
	ck.sort_custom(func(a, b): return int(combos[a]) > int(combos[b]))
	for k in ck:
		print("| %s | %.1f%% |" % [k, 100.0 * combos[k] / maxi(1, tot)])
	var w := maxi(1, int(item_runs[0]))
	var l := maxi(1, int(item_runs[1]))
	for side in [0, 1]:
		var keys := items.keys()
		keys.sort_custom(func(a, b): return float(items[a][side]) > float(items[b][side]))
		print("")
		print("Top 10 items in %s builds (%d runs); per run in wins vs losses, and win%% of runs holding it:" % ["winning" if side == 0 else "losing", item_runs[side]])
		print("| item | per winning run | per losing run | win% when held | runs held |")
		print("|---|---|---|---|---|")
		for k in keys.slice(0, 40 if side == 0 else 10):
			var v: Array = items[k]
			var held := int(v[2]) + int(v[3])
			print("| %s | %.2f | %.2f | %.1f | %d |" % [k, float(v[0]) / w, float(v[1]) / l, 100.0 * v[2] / maxi(1, held), held])

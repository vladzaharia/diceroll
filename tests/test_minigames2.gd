extends "res://tests/test_case.gd"
## Minigames 2.0 (spec §16 "More minigames"): Bubble Shooter, Plinko, Shell Game, Memory Match,
## Fishing, Lucky Wheel and High-Low Ladder. Rules, determinism (same seed + inputs = same
## game), no hidden information in the public state, mid-game save/load, AUTO par, the gold
## signature prizes and the Arcade unlocks.

const P := GameFlow.Phase
const NEW := ["bubble_shooter", "plinko", "shell_game", "memory_match", "fishing", "lucky_wheel", "high_low"]


func _first(ev: Array, type: String) -> Dictionary:
	for e: Dictionary in ev:
		if String(e.get("type", "")) == type:
			return e
	return {}


## Plays a game to the end with the bot's public-state policy; returns the args it sent.
func _play(m: Minigame, stop_after := 999) -> Array:
	var sent: Array = []
	var guard := 0
	while not m.done and m.actions_left > 0 and guard < 80 and sent.size() < stop_after:
		guard += 1
		var a := BotMeta.play_args(m.id, m.public_state(), 7)
		if a.is_empty():
			break
		var r := m.action(a)
		assert_true(r.has("info"), "%s %s -> %s" % [m.id, str(a), str(r)])
		sent.append(a)
	return sent


func test_every_new_game_is_registered() -> void:
	for id in NEW:
		assert_true(MinigameDefs.has(id), id)
		assert_true(MinigameDefs.IDS.has(id), id)
		assert_true(MinigameDefs.MEDIAN.has(id), id)
		assert_true(float(MinigameDefs.SKILL_BAND_BY_ID.get(id, MinigameDefs.SKILL_BAND)) <= 0.15, "skill band capped: " + id)
		var m := Minigames.create(id, 5, 1)
		assert_true(m != null, id)
		assert_eq(m.id, id)
		assert_true(m.actions_left > 0 and not m.done, id)
		assert_true(MgLogic.HINTS.has(id) and MgLogic.UNITS.has(id) and MgLogic.GAME_COLORS.has(id), "screen texts " + id)
	assert_eq(MinigameDefs.IDS.size(), 11)


## Same seed + same inputs = the same game, and a JSON save taken mid-game resumes identically.
func test_determinism_and_mid_game_save() -> void:
	for id in NEW:
		for s in 6:
			var seed := 900 + s * 37
			var a := Minigames.create(id, seed, 1)
			var b := Minigames.create(id, seed, 1)
			assert_eq(JSON.stringify(a.public_state()), JSON.stringify(b.public_state()), id + " setup")
			var sent := _play(a, 3)
			for args in sent:
				b.action(args)
			assert_eq(JSON.stringify(a.public_state()), JSON.stringify(b.public_state()), id + " after 3")
			# save mid-game, continue both with the same inputs
			var c := Minigames.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
			assert_eq(JSON.stringify(c.public_state()), JSON.stringify(a.public_state()), id + " loaded")
			var rest := _play(a)
			for args in rest:
				var r := c.action(args)
				assert_true(r.has("info"), id + " resumed action")
			assert_eq(JSON.stringify(c.public_state()), JSON.stringify(a.public_state()), id + " resumed to the end")
			assert_eq(c.score(), a.score(), id)
			assert_true(a.done or a.actions_left <= 0, id + " finishes")


## Each game ends within a bounded number of actions (15-35 s of play) under the bot.
func test_games_finish() -> void:
	var cap := {"bubble_shooter": 10, "plinko": 3, "shell_game": 3, "memory_match": 60, "fishing": 6, "lucky_wheel": 4, "high_low": 40}
	for id in NEW:
		for s in 10:
			var m := Minigames.create(id, 3000 + s, 1)
			var sent := _play(m)
			assert_true(m.done or m.actions_left <= 0, id)
			assert_true(sent.size() <= int(cap[id]), "%s took %d actions" % [id, sent.size()])
			assert_true(m.score() >= 0.0, id)
			assert_eq(m.action(BotMeta.play_args(id, m.public_state())).has("error"), true, id + " refuses after the end")


# --- no hidden information in the public state -------------------------------------------

func test_memory_hides_face_down_cards() -> void:
	for s in 20:
		var m := Minigames.create("memory_match", 100 + s, 1) as MemoryMatch
		var st := m.public_state()
		assert_eq((st.cards as Array).count(0), 16)
		assert_true(not st.has("symbols"))
		# flip two different symbols: both go back face down, only the info showed them
		var i := 0
		var j := 1
		while m.symbols[j] == m.symbols[i]:
			j += 1
		var r1 := m.action([i])
		assert_eq(int(r1.info.symbol), m.symbols[i])
		assert_eq(int(m.public_state().open), i)
		assert_eq(int(m.public_state().open_symbol), m.symbols[i])
		var r2 := m.action([j])
		assert_eq(bool(r2.info.match), false)
		assert_eq(m.actions_left, MemoryMatch.MISSES - 1)
		var after := m.public_state()
		assert_eq((after.cards as Array).count(0), 16, "mismatched cards flip back")
		assert_eq(int(after.open), -1)
		# a pair stays up and scores
		var k := 0
		for q in 16:
			if q != i and m.symbols[q] == m.symbols[i]:
				k = q
		m.action([i])
		var r3 := m.action([k])
		assert_eq(bool(r3.info.match), true)
		assert_eq(int(m.public_state().cards[i]), m.symbols[i])
		assert_eq(int(m.score()), MemoryMatch.PAIR_POINTS)
		assert_true(m.action([i]).has("error"), "matched cards can't be flipped")


func test_memory_perfect_memory_clears_the_board() -> void:
	var m := Minigames.create("memory_match", 44, 1) as MemoryMatch
	# a cheat that knows the layout clears it with no misses
	for sym in range(1, 9):
		var cells: Array = []
		for i in 16:
			if m.symbols[i] == sym:
				cells.append(i)
		m.action([cells[0]])
		m.action([cells[1]])
	assert_true(m.done)
	assert_eq(int(m.score()), 8 * MemoryMatch.PAIR_POINTS + MemoryMatch.MISSES * MemoryMatch.MISS_LEFT_POINTS)


func test_shell_game_never_shows_the_answer_before_the_pick() -> void:
	for s in 30:
		var m := Minigames.create("shell_game", 200 + s, 1) as ShellGame
		for r in ShellGame.ROUNDS:
			var st := m.public_state()
			assert_true(not st.has("gem") and not st.has("answer"), "no answer in the public state")
			assert_eq((st.swaps as Array).size(), int(ShellGame.SWAPS[r]))
			assert_near(float(st.swap_time), float(ShellGame.SWAP_TIME[r]))
			for sw: Array in st.swaps:
				assert_true(int(sw[0]) != int(sw[1]) and int(sw[0]) >= 0 and int(sw[1]) < ShellGame.CUPS)
			var gem := ShellGame.follow(int(st.start), st.swaps)
			var pick := gem if s % 2 == 0 else (gem + 1) % 3
			var res := m.action([pick, 0.4 if r == 0 else 2.0])
			assert_eq(int(res.info.gem), gem)
			assert_eq(bool(res.info.correct), pick == gem)
			var want: int = (int(ShellGame.POINTS[r]) * (ShellGame.QUICK_MULT if r == 0 else 1)) if pick == gem else ShellGame.MISS
			assert_eq(int(res.info.points), want)
			assert_eq(bool(res.info.quick), pick == gem and r == 0)
		assert_true(m.done)
	# rounds get harder: more swaps, faster
	for r in range(1, ShellGame.ROUNDS):
		assert_true(int(ShellGame.SWAPS[r]) > int(ShellGame.SWAPS[r - 1]))
		assert_true(float(ShellGame.SWAP_TIME[r]) < float(ShellGame.SWAP_TIME[r - 1]))


func test_fishing_hides_the_fish_until_landed() -> void:
	var caught := 0
	for s in 30:
		var m := Minigames.create("fishing", 300 + s, 1) as Fishing
		var r := m.action(["cast", s % 3])
		assert_true(r.has("info"))
		var st := m.public_state()
		assert_eq(String(st.phase), "bite")
		assert_true(not st.has("fish") and not JSON.stringify(st).contains("\"%s\"" % String(m.fish.kind)), "the fish on the line is not public")
		assert_true(float(st.bite_at) > 0.0 and float(st.window) > 0.0)
		for nb in st.nibbles:
			assert_true(float(nb) <= float(st.bite_at) - Fishing.NIBBLE_GAP + 0.001, "nibbles come before the bite")
		assert_true(m.action(["cast", 0]).has("error"), "one cast at a time")
		var t := float(st.bite_at) + (0.1 if s % 3 != 2 else -0.2)
		var h := m.action(["hook", t])
		if s % 3 == 2:
			assert_eq(String(h.info.result), "spooked")
			assert_eq(int(h.info.points), 0)
		else:
			assert_eq(String(h.info.result), "caught")
			assert_true(bool(h.info.perfect))
			caught += 1
		assert_eq(String(m.public_state().phase), "cast")
		var late := m.action(["cast", 1])
		assert_true(late.has("info"))
		var h2 := m.action(["hook", float(late.info.bite_at) + float(late.info.window) + 0.05])
		assert_eq(String(h2.info.result), "missed")
		m.action(["cast", 0])
		var h3 := m.action(["hook", -1.0])
		assert_eq(String(h3.info.result), "missed")
		assert_true(m.done)
	assert_true(caught > 0)


func test_high_low_ladder_rules() -> void:
	for s in 60:
		var m := Minigames.create("high_low", 400 + s, 1) as HighLow
		var guard := 0
		while not m.done and guard < 40:
			guard += 1
			var st := m.public_state()
			assert_true(not st.has("next"), "the next roll is never public")
			var rung := int(st.rung)
			var g := "higher" if int(st.die) <= 3 else "lower"
			if s % 5 == 0 and rung >= 2:
				var c := m.action(["cash"])
				assert_true(bool(c.info.cash))
				assert_eq(int(m.score()), int(HighLow.PRIZES[rung]))
				break
			var r := m.action([g])
			match String(r.info.result):
				"up": assert_eq(int(r.info.rung), rung + 1)
				"push":
					assert_eq(int(r.info.rung), rung)
					assert_eq(int(r.info.roll), int(r.info.from))
				"bust":
					assert_eq(int(r.info.rung), HighLow.safety(rung))
					assert_true(m.done)
					assert_eq(int(m.score()), int(HighLow.PRIZES[HighLow.safety(rung)]))
		assert_true(m.done)
	assert_eq(HighLow.win_odds(1, "higher"), 1.0)
	assert_eq(HighLow.win_odds(3, "higher"), 0.6)
	assert_eq(HighLow.safety(2), 1)


func test_plinko_paths_and_odds() -> void:
	var golden_hits := 0
	for s in 40:
		var m := Minigames.create("plinko", 500 + s, 1) as Plinko
		var st := m.public_state()
		var vals: Array = st.buckets
		var sorted := vals.duplicate()
		sorted.sort()
		var want := Plinko.BUCKET_VALUES.duplicate()
		want.sort()
		assert_eq(sorted, want, "a shuffle of the bucket values")
		assert_eq((int(st.golden[0]) + int(st.golden[1])) % 2, 0, "the golden peg is reachable")
		for d in Plinko.DROPS:
			var slot := (s + d * 3) % Plinko.BUCKETS
			var r := m.action([slot])
			var path: Array = r.info.path
			assert_eq(path.size(), Plinko.ROWS + 1)
			assert_eq(int(path[0]), slot * 2)
			for k in Plinko.ROWS:
				assert_eq(absi(int(path[k + 1]) - int(path[k])), 1)
				assert_true(int(path[k + 1]) >= 0 and int(path[k + 1]) <= 2 * (Plinko.BUCKETS - 1))
			assert_eq(int(r.info.bucket), int(path[Plinko.ROWS]) / 2)
			assert_eq(int(r.info.value), int(vals[int(r.info.bucket)]))
			assert_eq(int(r.info.points), int(r.info.value) * (Plinko.GOLDEN_MULT if bool(r.info.golden) else 1))
			if bool(r.info.golden):
				golden_hits += 1
	assert_true(golden_hits > 0, "the golden peg gets hit sometimes")
	# odds sum to 1 and follow the board
	var o := Plinko.odds(4, [])
	var tot := 0.0
	for p in o.probs:
		tot += float(p)
	assert_near(tot, 1.0, 0.000001)
	assert_near(float(o.probs[4]), 70.0 / 256.0, 0.000001)


func test_lucky_wheel_spin_and_nudge() -> void:
	var nudged := 0
	for s in 30:
		var m := Minigames.create("lucky_wheel", 600 + s, 1) as LuckyWheel
		assert_true(m.action(["stop", 1.0]).has("error"), "spin first")
		var r := m.action(["spin"])
		var sp: Dictionary = m.public_state().spin
		assert_eq(String(m.public_state().phase), "spinning")
		assert_true(float(sp.total) >= 360.0 * LuckyWheel.TURNS[0])
		var natural := LuckyWheel.segment_at(LuckyWheel.angle_at(sp, float(sp.dur)))
		# an early tap slips: the wheel coasts to its natural stop
		var st := m.action(["stop", 0.5])
		assert_eq(bool(st.info.nudged), false)
		assert_eq(int(st.info.segment), natural)
		assert_eq(int(m.score()), m.segments[natural])
		# the brake in the window stops on the segment under the pointer
		m.action(["spin"])
		var sp2: Dictionary = m.public_state().spin
		var t := float(sp2.dur) - 0.5
		var r2 := m.action(["stop", t])
		assert_eq(bool(r2.info.nudged), true)
		assert_eq(int(r2.info.segment), LuckyWheel.segment_at(LuckyWheel.angle_at(sp2, t)))
		nudged += 1 if int(r2.info.segment) != int(r2.info.natural) else 0
		assert_true(m.done)
		# the bot's brake never does worse than coasting
		var m2 := Minigames.create("lucky_wheel", 600 + s, 1) as LuckyWheel
		m2.action(["spin"])
		var sp3: Dictionary = m2.public_state().spin
		var nat := m2.segments[LuckyWheel.segment_at(LuckyWheel.angle_at(sp3, float(sp3.dur)))]
		var bt := m2.best_stop(sp3)
		var r3 := m2.action(["stop", bt])
		assert_true(int(r3.info.value) >= nat)
	assert_true(nudged > 0, "the brake can change the result")


func test_bubble_shooter_flight_and_pops() -> void:
	var popped_any := false
	var dropped_any := false
	var bounced := false
	for s in 12:
		var m := Minigames.create("bubble_shooter", 700 + s, 1) as BubbleShooter
		var st := m.public_state()
		assert_eq((st.grid as Array).size(), BubbleShooter.ROWS * BubbleShooter.COLS)
		assert_true(int(st.next) >= 0 and int(st.current) >= 0)
		for k in 4:
			var ai := BubbleShooter.best_angle(m.public_state().grid, m.current) if k % 2 == 0 else (k * 29 + s * 7) % BubbleShooter.ANGLES
			var before: Array = m.public_state().grid
			var pred := BubbleShooter.simulate(before, m.current, ai)
			var colour := m.current
			var next := m.next_color
			var r := m.action([ai])
			assert_eq(int(r.info.cell), int(pred.cell), "the aim guide's rule is the core's")
			assert_eq(int(r.info.color), colour)
			assert_eq(m.current, next, "the preview bubble is loaded next")
			if int(r.info.cell) >= 0:
				var cell := int(r.info.cell)
				assert_eq(int(before[cell]), -1, "sticks into a free cell")
			popped_any = popped_any or not (r.info.popped as Array).is_empty()
			dropped_any = dropped_any or not (r.info.dropped as Array).is_empty()
			bounced = bounced or (r.info.path as Array).size() > 3
			assert_true((r.info.popped as Array).is_empty() or (r.info.popped as Array).size() >= BubbleShooter.MIN_POP)
			# nothing left floating
			assert_eq(BubbleShooter.floating(m.public_state().grid), [] as Array[int])
	assert_true(popped_any and dropped_any and bounced)
	# the straight-up shot flies straight up
	var t := BubbleShooter.trace(Minigames.create("bubble_shooter", 1, 1).public_state().grid, BubbleShooter.ANGLES / 2)
	assert_near(float(t.path[1][0]), BubbleShooter.LAUNCH.x, 0.001)


# --- flow: AUTO par, rewards -------------------------------------------------------------

func test_auto_par_and_played_games_through_the_flow() -> void:
	for id in NEW:
		var f := GameFlow.new_run("knight", 31, 28, {"profile": Profile.fresh().to_dict()})
		f.debug_open("minigame", id)
		assert_eq(BotMeta.minigame_command(f), ["minigame_auto"], id)
		var ev := f.minigame_auto()
		var res := _first(ev, "minigame_result")
		assert_eq(String(res.tier), "silver", id)
		assert_near(float(res.ratio), MinigameDefs.PAR, 0.001, id)
		# and played by hand through the flow
		var g := GameFlow.new_run("knight", 31, 28, {"profile": Profile.fresh().to_dict()})
		g.debug_open("minigame", id)
		var guard := 0
		while g.phase == P.MINIGAME and not bool(g.offer.done) and guard < 80:
			guard += 1
			BotMeta.minigame_mode = "play"
			var cmd := BotMeta.minigame_command(g)
			BotMeta.minigame_mode = "par"
			if cmd[0] != "minigame_action":
				break
			assert_eq(String(g.apply(cmd)[0].type), "minigame_update", id)
		var fin := _first(g.minigame_finish(), "minigame_result")
		assert_true(not fin.is_empty(), id)
		assert_eq(String(g.offer.kind), "reward", id)


func _gold_offer(id: String, seed := 5) -> GameFlow:
	var p := Profile.fresh()
	for pot in PotionDefs.IDS:
		p.grant("potions", pot)
	var f := GameFlow.new_run("knight", seed, 28, {"profile": p.to_dict()})
	f.debug_open("minigame", id)
	f.minigame = Minigames.create(id, 1, 1)
	f._minigame_result(1.5, false)
	return f


func _pick_sig(f: GameFlow, sig: String) -> Array[Dictionary]:
	var opts: Array = f.offer.options
	for i in opts.size():
		if String(opts[i].id) == sig:
			return f.pick_draft(i)
	assert_true(false, "no %s option in %s" % [sig, str(opts)])
	return []


func test_signature_prizes() -> void:
	var want := {"bubble_shooter": "sharpshooter", "plinko": "rare_rune", "shell_game": "heart_gem", "memory_match": "mirror_forge",
		"fishing": "potion_pair", "lucky_wheel": "passive_uncommon", "high_low": "high_roller"}
	var seen := {}
	for id in MinigameDefs.IDS:
		var sig := MinigameDefs.signature(id)
		assert_true(not seen.has(sig), "one signature per game: " + sig)
		seen[sig] = true
	for id in want:
		assert_eq(MinigameDefs.signature(id), want[id])
		var f := _gold_offer(id)
		assert_eq(String(f.offer.tier), "gold")
		assert_eq((f.offer.options as Array).size(), 3, id)
	# Sharpshooter: +ATK
	var f1 := _gold_offer("bubble_shooter")
	var atk := f1.run.atk
	_pick_sig(f1, "sharpshooter")
	assert_eq(f1.run.atk, atk + Balance.SHRINE_ATK)
	# Rare rune: a rune to assign
	var f2 := _gold_offer("plinko")
	_pick_sig(f2, "rare_rune")
	assert_eq(String(f2.offer.kind), "rune_assign")
	assert_eq(Runes.rarity(String(f2.offer.rune)), "rare")
	var rune := String(f2.offer.rune)
	f2.rune_assign(0)
	assert_eq(f2.run.dice[0].rune, rune)
	# Heart Gem: +max HP
	var f3 := _gold_offer("shell_game")
	var mhp := f3.run.max_hp
	_pick_sig(f3, "heart_gem")
	assert_eq(f3.run.max_hp, mhp + Balance.SHRINE_MAX_HP)
	# Mirror Forge: two edits, raise or mirror
	var f4 := _gold_offer("memory_match")
	_pick_sig(f4, "mirror_forge")
	assert_eq(f4.phase, P.FORGE)
	assert_eq(Array(f4.offer.ops), ["raise", "mirror"])
	var ev := f4.forge_apply(0, 0, "raise")
	assert_eq(f4.phase, P.FORGE, "a second edit")
	assert_true(_first(ev, "passive_triggered").is_empty(), "not the Blacksmith")
	f4.forge_apply(0, 1, "raise")
	assert_true(f4.phase != P.FORGE)
	# The Catch: two potions
	var f5 := _gold_offer("fishing")
	f5.run.belt.clear()
	f5.run.sync_potions()
	var opt: Dictionary = {}
	for o in f5.offer.options:
		if String(o.id) == "potion_pair":
			opt = o
	assert_true(String(opt.potion2) != "healing", "a second, different potion when one is unlocked")
	_pick_sig(f5, "potion_pair")
	assert_eq(Array(f5.run.belt), ["healing", String(opt.potion2)])
	# Uncommon passive: a choice of uncommon passives
	var f6 := _gold_offer("lucky_wheel")
	_pick_sig(f6, "passive_uncommon")
	assert_eq(String(f6.offer.kind), "passive")
	for o in f6.offer.options:
		assert_eq(Passives.rarity(String(o.id)), "uncommon")
	# High Roller: every die's lowest face +1
	var f7 := _gold_offer("high_low")
	var lows: Array = []
	for d in f7.run.dice:
		lows.append(d.faces[d.lowest_face()])
	_pick_sig(f7, "high_roller")
	for k in f7.run.dice.size():
		var sorted: Array = Array(f7.run.dice[k].faces).duplicate()
		sorted.sort()
		assert_true(int(sorted[0]) >= int(lows[k]), "lowest face raised")


# --- meta: Arcade unlocks ----------------------------------------------------------------

func test_arcade_unlocks_are_minor_milestones() -> void:
	var by_game := {}
	for m in UnlockDefs.MILESTONES:
		for u: Array in m.unlocks:
			if String(u[0]) == "minigames":
				by_game[String(u[1])] = m
	for id in NEW:
		assert_true(by_game.has(id), "a milestone unlocks " + id)
		var m: Dictionary = by_game[id]
		assert_eq((m.unlocks as Array).size(), 1, "minigame milestones unlock only the game (minor): " + id)
		assert_true(int(m.run) >= 2 and int(m.run) <= 22, id)
		assert_eq(UnlockDefs.sigil_cost("minigames", id), {"sigils": UnlockDefs.SIGIL_PRICE.minigames}, "Sigils can buy it early")
		assert_true(not UnlockDefs.STARTER.minigames.has(id), "not owned on a fresh profile")
	# spread through the campaign: no two new games on the same design run
	var runs := {}
	for id in NEW:
		var r := int(by_game[id].run)
		assert_true(not runs.has(r), "two minigames at run %d" % r)
		runs[r] = true
	# a banked run that meets a condition unlocks the game
	var p := Profile.fresh()
	var camp := Camp.new(p)
	var ev := camp.bank_run({"rewards": {"crowns": 10}, "victory": false, "class_id": "knight", "lap": 5, "laps_completed": 4,
		"fights_won": 5, "route": ["glade", "hollow", "throne"], "biomes_visited": ["glade"], "minibosses_killed": [], "bosses_killed": [],
		"asc": 0, "mode": "standard", "max_act": 1, "pet": "", "pet_fights": 0, "minigame_plays": {}, "minigames_played": 6})
	assert_true(p.owns("minigames", "plinko"), "6 minigames played -> Plinko")
	var got := false
	for e in ev:
		if String(e.type) == "unlocked" and String(e.id) == "plinko":
			got = true
	assert_true(got)

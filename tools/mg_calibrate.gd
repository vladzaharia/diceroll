extends SceneTree
## Minigame calibration (balance.md "Minigame calibration"): plays every minigame N times with a
## human-like player (its own RandomNumberGenerator for the human noise; the game itself stays
## deterministic from its seed) and prints median / quartiles / mean, the tier shares at the
## current MinigameDefs.MEDIAN and the expected reward value (review §5.4 parity: every game
## within ±10% of the mean at median play).
##   godot --headless --path . -s tools/mg_calibrate.gd -- [--n=3000] [--game=<id>] [--policy=human|expert|random]

## Reward value per tier in gold equivalents (bronze 12 gold, silver 25 gold, gold ~ rune of
## choice / potion + 20 gold / the signature); gold rewards scale with the skill band.
const TIER_VALUE := {"bronze": 12.0, "silver": 25.0, "gold": 45.0}

var h := RandomNumberGenerator.new()
var policy := "human"
## --measured: tiers at the measured median instead of MinigameDefs.MEDIAN (to pick MEDIAN).
var auto_med := false
var hist := false


func _init() -> void:
	var n := 3000
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = a.substr(4).to_int()
		elif a.begins_with("--game="):
			only = a.substr(7)
		elif a == "--hist":
			hist = true
		elif a == "--measured":
			auto_med = true
		elif a.begins_with("--policy="):
			policy = a.substr(9)
	h.seed = 12345
	var evs := {}
	print("game            median  q25  q75   mean   bronze silver gold   E[value]  (policy %s, n=%d)" % [policy, n])
	for id in MinigameDefs.IDS:
		if only != "" and id != only:
			continue
		var scores: Array = []
		var actions := 0
		for s in n:
			var m := Minigames.create(id, 7000 + s * 13, 1)
			actions += play(m)
			scores.append(m.score())
		scores.sort()
		var med := float(MinigameDefs.MEDIAN[id]) if not auto_med else _q(scores, 0.5)
		var tiers := {"bronze": 0, "silver": 0, "gold": 0}
		var ev := 0.0
		var mean := 0.0
		for sc in scores:
			var r := float(sc) / med
			var t := MinigameDefs.tier_for(r)
			tiers[t] += 1
			ev += TIER_VALUE[t] * (MinigameDefs.skill_mult(r, id) if t == "gold" else 1.0)
			mean += float(sc)
		ev /= n
		mean /= n
		evs[id] = ev
		if hist:
			var c := {}
			for sc in scores:
				c[int(sc)] = int(c.get(int(sc), 0)) + 1
			var line := ""
			for k in c:
				line += "%d:%.1f%% " % [k, 100.0 * c[k] / n]
			print("   hist " + line)
		print("%-15s %6.1f %4.0f %4.0f %6.2f   %5.1f%% %5.1f%% %5.1f%%   %6.2f   actions/play %.1f" % [id, _q(scores, 0.5), _q(scores, 0.25),
			_q(scores, 0.75), mean, 100.0 * tiers.bronze / n, 100.0 * tiers.silver / n, 100.0 * tiers.gold / n, ev, float(actions) / n])
	if evs.size() > 1:
		var avg := 0.0
		for k in evs:
			avg += float(evs[k])
		avg /= evs.size()
		for k in evs:
			print("  parity %-15s %+5.1f%%" % [k, 100.0 * (float(evs[k]) / avg - 1.0)])
	quit()


static func _q(a: Array, q: float) -> float:
	return float(a[clampi(int(q * (a.size() - 1)), 0, a.size() - 1)])


func _gauss(sd: float) -> float:
	return h.randfn(0.0, sd)


## Plays one game to the end with the policy; returns the number of actions.
func play(m: Minigame) -> int:
	var k := 0
	var mem := {}  # memory match: idx -> [symbol, turn seen]
	var turn := 0
	while not m.done and m.actions_left > 0 and k < 200:
		k += 1
		var st := m.public_state()
		var cmd: Array = []
		match m.id:
			"fossil_hunter":
				var c := BotMeta.fossil_pick(st)
				cmd = [c % int(st.w), c / int(st.w)]
			"bubble_breaker":
				var cl := BotMeta.bubble_pick(st)
				if cl < 0:
					break
				cmd = [cl / int(st.h), cl % int(st.h)]
			"scratch_off":
				cmd = [BotMeta.scratch_pick(st, h.randi())]
			"claw_machine":
				var x := (m as ClawMachine).best_target()
				cmd = [clampf(x + (_gauss(0.045) if policy == "human" else (0.0 if policy == "expert" else h.randf() - x)), 0.0, 1.0)]
			"bubble_shooter":
				cmd = [_shooter(st)]
			"plinko":
				cmd = [_plinko(st)]
			"shell_game":
				cmd = _shell(st)
			"memory_match":
				cmd = [_memory(st, mem, turn)]
			"fishing":
				cmd = _fishing(st)
			"lucky_wheel":
				cmd = _wheel(m as LuckyWheel, st)
			"high_low":
				cmd = [_high_low(st)]
		var res := m.action(cmd)
		if res.has("error"):
			push_error("%s %s: %s" % [m.id, str(cmd), res.error])
			break
		if m.id == "memory_match":
			var info: Dictionary = res.info
			mem[int(info.idx)] = [int(info.symbol), turn]
			if not bool(info.first):
				turn += 1
				if bool(info.match):
					mem.erase(int(info.idx))
					mem.erase(int(info.other))
	return k


# --- policies ------------------------------------------------------------------------------

func _shooter(st: Dictionary) -> int:
	var g: Array = st.grid
	var col := int(st.current)
	if policy == "random":
		return h.randi_range(0, BubbleShooter.ANGLES - 1)
	var best := BubbleShooter.best_angle(g, col)
	if policy == "expert":
		return best
	# human: usually goes for the best-looking shot, sometimes a merely decent one; the aim
	# itself wobbles a little (the guide helps)
	var target := best
	if h.randf() < 0.35:
		var opts: Array = []
		for ai in range(0, BubbleShooter.ANGLES, 3):
			var s := BubbleShooter.simulate(g, col, ai)
			if int(s.cell) >= 0 and int(s.points) > 0:
				opts.append(ai)
		if not opts.is_empty():
			target = int(opts[h.randi_range(0, opts.size() - 1)])
	return clampi(int(round(target + _gauss(2.0))), 0, BubbleShooter.ANGLES - 1)


func _plinko(st: Dictionary) -> int:
	var vals: Array = st.buckets
	if policy == "random":
		return h.randi_range(0, Plinko.BUCKETS - 1)
	var best := Plinko.best_slot(vals, st.golden)
	if policy == "expert":
		return best
	var r := h.randf()
	if r < 0.5:
		return best
	if r < 0.8:
		return vals.find(vals.max())
	return h.randi_range(0, Plinko.BUCKETS - 1)


func _shell(st: Dictionary) -> Array:
	var g := ShellGame.follow(int(st.start), st.swaps)
	if policy == "expert":
		return [g, 0.5]
	if policy == "random":
		return [h.randi_range(0, 2), 2.0]
	var lose := [0.025, 0.06, 0.11][int(st.round)] as float
	var pos := int(st.start)
	var lost := false
	for sw: Array in st.swaps:
		if pos == int(sw[0]) or pos == int(sw[1]):
			if h.randf() < lose:
				lost = true
		pos = ShellGame.follow(pos, [sw])
	# sure trackers tap at once (Sharp Eye), unsure ones hesitate
	if lost:
		return [h.randi_range(0, 2), 0.8 if h.randf() < 0.25 else 1.8]
	return [g, 0.7 if h.randf() < 0.7 else 1.6]


func _memory(st: Dictionary, mem: Dictionary, turn: int) -> int:
	var cards: Array = st.cards
	var open := int(st.open)
	var unknown: Array = []
	for i in cards.size():
		if int(cards[i]) == 0 and i != open and not mem.has(i):
			unknown.append(i)
	# what the player still remembers (older cards fade)
	var known := {}
	for i in mem:
		if int(cards[i]) != 0 or i == open:
			continue
		var age := turn - int(mem[i][1])
		var keep := 1.0 if policy == "expert" else (0.97 * pow(0.9, age))
		if policy == "random":
			keep = 0.0
		if h.randf() < keep:
			known[i] = int(mem[i][0])
	if open < 0:
		# a remembered pair: take it
		var by := {}
		for i in known:
			var s: int = known[i]
			if by.has(s):
				return int(by[s])
			by[s] = i
		if unknown.is_empty():
			return int(known.keys()[0]) if not known.is_empty() else _any(cards, open)
		return int(unknown[h.randi_range(0, unknown.size() - 1)])
	var want := int(st.open_symbol)
	for i in known:
		if int(known[i]) == want:
			return int(i)
	if not unknown.is_empty():
		return int(unknown[h.randi_range(0, unknown.size() - 1)])
	return _any(cards, open)


func _any(cards: Array, open: int) -> int:
	for i in cards.size():
		if int(cards[i]) == 0 and i != open:
			return i
	return 0


func _fishing(st: Dictionary) -> Array:
	if String(st.phase) == "cast":
		if policy == "random":
			return ["cast", h.randi_range(0, 2)]
		var r := h.randf()
		return ["cast", 2 if r < 0.45 else (1 if r < 0.8 else 0)]
	var bite := float(st.bite_at)
	if policy == "expert":
		return ["hook", bite + 0.2]
	if policy == "random":
		return ["hook", h.randf() * (bite + 1.5)]
	for nb in st.nibbles:
		if h.randf() < 0.12:
			return ["hook", float(nb) + 0.25]
	var react := maxf(0.16, 0.34 + _gauss(0.09))
	return ["hook", bite + react]


func _wheel(m: LuckyWheel, st: Dictionary) -> Array:
	if String(st.phase) == "spin":
		return ["spin"]
	var sp: Dictionary = st.spin
	var t := m.best_stop(sp)
	if policy == "random":
		return ["stop", -1.0]
	if policy == "expert":
		return ["stop", t]
	if t < 0.0 or h.randf() < 0.35:
		return ["stop", -1.0]
	return ["stop", t + _gauss(0.09)]


func _high_low(st: Dictionary) -> String:
	var die := int(st.die)
	var rung := int(st.rung)
	var g := HighLow.best_guess(die)
	if policy == "random":
		return "cash" if h.randf() < 0.2 else ("higher" if h.randf() < 0.5 else "lower")
	var p := HighLow.win_odds(die, g)
	var safe := HighLow.safety(rung)
	var now := float(HighLow.PRIZES[rung])
	var up := float(HighLow.PRIZES[mini(rung + 1, HighLow.PRIZES.size() - 1)])
	var ev := p * up + (1.0 - p) * float(HighLow.PRIZES[safe])
	if policy == "expert":
		return g if ev > now else "cash"
	# human: a personal nerve per game (cash out at rung `bold`, or already at `shy` when the
	# die shows a scary 3 or 4); set on the first guess
	if not _hl.has("bold") or rung == 0:
		_hl = {"shy": [2, 3, 3, 4][h.randi_range(0, 3)], "bold": [4, 5, 5, 6, 7][h.randi_range(0, 4)]}
	if rung >= int(_hl.bold) or ((die == 3 or die == 4) and rung >= int(_hl.shy)):
		return "cash"
	return g

var _hl := {}

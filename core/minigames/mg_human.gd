class_name MgHuman
extends RefCounted
## A human-like minigame player for calibration (tools/mg_calibrate.gd, tests): its own
## RandomNumberGenerator supplies the human noise (aim wobble, lapses, nerve), so the games stay
## deterministic from their seeds. Policies ("human" the calibration target; "expert" and
## "random" the skill bounds) only read the public state, like the screens, except where noted
## (the claw aims at the core's best capsule centre, then wobbles).
## Not used by the game itself.
##
##   var p := MgHuman.new(12345)          # policy "human"
##   var m := Minigames.create(id, seed, 1)
##   p.play(m)                            # plays to the end; returns the number of actions

var h := RandomNumberGenerator.new()
var policy := "human"
var _hl := {}


func _init(seed_value := 12345, p_policy := "human") -> void:
	h.seed = seed_value
	policy = p_policy


func _gauss(sd: float) -> float:
	return h.randfn(0.0, sd)


## Plays one game to the end with the policy; returns the number of actions.
func play(m: Minigame) -> int:
	var k := 0
	var mem := {}  # memory match: idx -> [symbol, turn seen]
	var turn := 0
	_hl = {}
	while not m.done and m.actions_left > 0 and k < 200:
		k += 1
		var st := m.public_state()
		var cmd: Array = []
		match m.id:
			"fossil_hunter":
				var c := BotMeta.fossil_pick(st)
				cmd = [c % int(st.w), c / int(st.w)]
			"bubble_breaker":
				cmd = _bubble(m as BubbleBreaker)
				if cmd.is_empty():
					break
			"scratch_off":
				cmd = [_scratch(st)]
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
				cmd = _wheel(st)
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

## Bubble Breaker: a person spots the biggest group most of the time, else one of the next
## biggest (expert: always the biggest; random: any group).
func _bubble(m: BubbleBreaker) -> Array:
	var cls := m.clusters()
	if cls.is_empty():
		return []
	var pick: Array = cls[0]
	if policy == "random":
		pick = cls[h.randi_range(0, cls.size() - 1)]
	elif policy == "human" and h.randf() < 0.45:
		pick = cls[h.randi_range(0, mini(2, cls.size() - 1))]
	var c := int(pick[0])
	return [c / BubbleBreaker.H, c % BubbleBreaker.H]


func _scratch(st: Dictionary) -> int:
	var open: Array = []
	for i in (st.cells as Array).size():
		if int(st.cells[i]) == 0:
			open.append(i)
	return int(open[h.randi_range(0, open.size() - 1)])


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


func _wheel(st: Dictionary) -> Array:
	if String(st.phase) == "spin":
		return ["spin"]
	var sp: Dictionary = st.spin
	var t := LuckyWheel.best_stop_for(st.segments, sp)
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
	if policy == "expert":
		return BotMeta.high_low_pick(st)
	# human: a personal nerve per game (cash out at rung `bold`, or already at `shy` when the
	# die shows a scary 3 or 4)
	if _hl.is_empty():
		_hl = {"shy": [2, 3, 3, 4][h.randi_range(0, 3)], "bold": [4, 5, 5, 6, 7][h.randi_range(0, 4)]}
	if rung >= int(_hl.bold) or ((die == 3 or die == 4) and rung >= int(_hl.shy)):
		return "cash"
	return g

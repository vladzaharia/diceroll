class_name ShellGame
extends Minigame
## Shell Game: a gem goes under one of CUPS cups (shown), the cups shuffle, pick the gem's cup.
## ROUNDS rounds, each with more and faster swaps (SWAPS[r] swaps of SWAP_TIME[r] seconds; the
## screen plays them at that pace in real time, never faster). Action args [cup position]
## (0 .. CUPS - 1, left to right after the shuffle).
## Rules are in core: each round's start position and swap sequence come from the minigame Rng
## when the round opens. The public state carries exactly what the player watches (where the
## gem starts, the swaps as they play) and never the answer: the final position appears only
## in a round's result, after the pick. A right pick scores POINTS[r], a wrong one MISS.
## Sharp Eye: a right pick made within QUICK seconds of the last swap doubles the round
## (args [cup, delay]: delay = seconds between the end of the shuffle and the tap, from the
## screen's clock; a missing / negative delay never counts as quick). Trackers who are sure
## pick at once; that is the skill spread above a clean sweep.
## Public: {cups, round, rounds, start (gem position at the start of the round), swaps [[a, b],
##          ...] (positions exchanged, in order), swap_time, results [{round, pick, gem,
##          correct, quick, points}]}.
## Info per pick: {round, pick, gem, correct, quick, points}.

const CUPS := 3
const ROUNDS := 3
const SWAPS := [5, 8, 11]
const SWAP_TIME := [0.46, 0.34, 0.25]
const POINTS := [2, 3, 4]
const MISS := 0
const QUICK := 1.2
const QUICK_MULT := 2
## Share of swaps that move the gem's cup (the rest are decoys between the other two).
const GEM_SWAP := 0.65

var rnd := 0
var gem_start := 0
var swaps: Array = []
var results: Array[Dictionary] = []

func _init() -> void:
	id = "shell_game"

func _setup() -> void:
	actions_left = ROUNDS
	rnd = 0
	results.clear()
	_deal()

## Opens round `rnd`: the gem's start and the swap sequence.
func _deal() -> void:
	gem_start = rng.randi_range(0, CUPS - 1)
	swaps.clear()
	var g := gem_start
	var last := [-1, -1]
	for k in int(SWAPS[rnd]):
		var pair: Array
		for tries in 4:
			if rng.chance(GEM_SWAP):
				var other := rng.randi_range(0, CUPS - 2)
				if other >= g:
					other += 1
				pair = [mini(g, other), maxi(g, other)]
			else:
				var rest: Array = []
				for c in CUPS:
					if c != g:
						rest.append(c)
				pair = [int(rest[0]), int(rest[1])]
			if pair != last:
				break
		swaps.append(pair)
		last = pair
		g = follow(g, [pair])

## Where a cup at position `pos` ends up after `seq` swaps.
static func follow(pos: int, seq: Array) -> int:
	var g := pos
	for s in seq:
		if g == int(s[0]):
			g = int(s[1])
		elif g == int(s[1]):
			g = int(s[0])
	return g

func _action(args: Array) -> Dictionary:
	if args.is_empty():
		return {"error": "pick needs [cup]"}
	var pick := int(args[0])
	if pick < 0 or pick >= CUPS:
		return {"error": "cup out of range"}
	var delay := float(args[1]) if args.size() > 1 else -1.0
	var gem := follow(gem_start, swaps)
	var ok := pick == gem
	var quick := ok and delay >= 0.0 and delay <= QUICK
	var pts: int = int(POINTS[rnd]) * (QUICK_MULT if quick else 1) if ok else MISS
	var res := {"round": rnd, "pick": pick, "gem": gem, "correct": ok, "quick": quick, "points": pts}
	results.append(res)
	actions_left -= 1
	rnd += 1
	if rnd < ROUNDS:
		_deal()
	else:
		swaps.clear()
	return {"info": res.duplicate()}

func score() -> float:
	var s := 0
	for r in results:
		s += int(r.points)
	return float(s)

func _public() -> Dictionary:
	var open := rnd < ROUNDS
	return {"cups": CUPS, "round": rnd, "rounds": ROUNDS, "start": gem_start if open else -1, "swaps": swaps.duplicate(true),
		"swap_time": float(SWAP_TIME[rnd]) if open else 0.0, "results": results.duplicate(true)}

func _save() -> Dictionary:
	return {"round": rnd, "start": gem_start, "swaps": swaps.duplicate(true), "results": results.duplicate(true)}

func _load(d: Dictionary) -> void:
	rnd = int(d.get("round", 0))
	gem_start = int(d.get("start", 0))
	swaps.clear()
	for s in d.get("swaps", []):
		swaps.append([int(s[0]), int(s[1])])
	results.clear()
	for r in d.get("results", []):
		results.append({"round": int(r.get("round", 0)), "pick": int(r.pick), "gem": int(r.gem), "correct": bool(r.correct),
			"quick": bool(r.get("quick", false)), "points": int(r.points)})

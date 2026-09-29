class_name Plinko
extends Minigame
## Plinko: a peg board of ROWS rows over BUCKETS prize buckets. Pick a drop slot (action args
## [slot], 0 .. BUCKETS - 1, one above each bucket); the die-ball bounces half a bucket left or
## right at every peg row (the minigame Rng draws the bounces when it is dropped, so nothing
## about the path is known before the drop) and the side walls turn it back. It lands in bucket
## slot + (rights - lefts) / 2. One peg is golden: a ball that bounces off it scores double.
## DROPS drops. Bucket prizes are a shuffled BUCKET_VALUES layout (public from the start, so
## the slot is a real choice: aim above the rich buckets, mind the golden peg).
## Public: {rows, buckets (values), golden [row, x2] (x2 = 2 x the peg's position in bucket
##          units), drops [{slot, path, bucket, value, golden, points}]}.
## Info per drop: {slot, path [x2 per row: the ball's position after each row, in half
##          buckets], bucket, value, golden, points}.
## Position unit: x2 = 2 x bucket index (0 .. 2 * (BUCKETS - 1)); pegs of row k sit at the
## half-way points the ball leaves from.

const ROWS := 8
const BUCKETS := 9
const DROPS := 3
const BUCKET_VALUES := [1, 1, 2, 2, 3, 3, 5, 6, 10]
const GOLDEN_MULT := 2

var buckets: Array[int] = []
## [row, x2] of the golden peg: a ball at position x2 entering row `row` bounces off it.
var golden: Array[int] = []
var drops: Array[Dictionary] = []

func _init() -> void:
	id = "plinko"

func _setup() -> void:
	actions_left = DROPS
	var vals: Array = BUCKET_VALUES.duplicate()
	rng.shuffle(vals)
	buckets.clear()
	for v in vals:
		buckets.append(int(v))
	# the golden peg: rows 2..5, somewhere a ball can reach (x2 parity alternates per row)
	var row := rng.randi_range(2, 5)
	var x2 := rng.randi_range(2, 2 * (BUCKETS - 1) - 2)
	if (x2 + row) % 2 == 1:
		x2 += 1 if x2 < 2 * (BUCKETS - 1) - 2 else -1
	golden = [row, x2]
	drops.clear()

## Positions (x2) of a ball dropped at `slot` for a sequence of bounces (true = right): the
## position at the top of every row, then the bucket's. Walls turn the ball back.
static func walk(slot: int, rights: Array) -> Array[int]:
	var x2 := slot * 2
	var out: Array[int] = [x2]
	for k in ROWS:
		var right := bool(rights[k])
		if x2 <= 0:
			right = true
		elif x2 >= 2 * (BUCKETS - 1):
			right = false
		x2 += 1 if right else -1
		out.append(x2)
	# 8 rows = an even number of half-steps: the ball ends on a bucket centre
	return out

func _action(args: Array) -> Dictionary:
	if args.is_empty():
		return {"error": "drop needs [slot]"}
	var slot := int(args[0])
	if slot < 0 or slot >= BUCKETS:
		return {"error": "slot out of range"}
	actions_left -= 1
	var rights: Array = []
	for k in ROWS:
		rights.append(rng.randf() < 0.5)
	var path := walk(slot, rights)
	var bucket := path[ROWS] / 2
	var gold := false
	for k in ROWS:
		if k == golden[0] and path[k] == golden[1]:
			gold = true
	var value := buckets[bucket]
	var pts := value * (GOLDEN_MULT if gold else 1)
	var d := {"slot": slot, "path": Array(path), "bucket": bucket, "value": value, "golden": gold, "points": pts}
	drops.append(d)
	return {"info": d.duplicate(true)}

func score() -> float:
	var s := 0
	for d in drops:
		s += int(d.points)
	return float(s)

## Probability of the ball reaching each bucket from `slot` (fair bounces, walls), plus the
## chance it touches the golden peg: {probs: [BUCKETS floats], golden: p}. Pure (bot / hints).
static func odds(slot: int, gold: Array) -> Dictionary:
	var dist := {slot * 2: 1.0}
	var pg := 0.0
	for k in ROWS:
		var nd := {}
		for x2 in dist:
			var p: float = dist[x2]
			if gold.size() == 2 and k == int(gold[0]) and int(x2) == int(gold[1]):
				pg += p
			if int(x2) <= 0:
				nd[1] = float(nd.get(1, 0.0)) + p
			elif int(x2) >= 2 * (BUCKETS - 1):
				nd[int(x2) - 1] = float(nd.get(int(x2) - 1, 0.0)) + p
			else:
				nd[int(x2) - 1] = float(nd.get(int(x2) - 1, 0.0)) + p * 0.5
				nd[int(x2) + 1] = float(nd.get(int(x2) + 1, 0.0)) + p * 0.5
		dist = nd
	var probs: Array = []
	probs.resize(BUCKETS)
	probs.fill(0.0)
	for x2 in dist:
		probs[int(x2) / 2] = float(probs[int(x2) / 2]) + float(dist[x2])
	return {"probs": probs, "golden": pg}

## Expected points of a drop at `slot` (golden peg counted as an average bonus).
static func expected(values: Array, gold: Array, slot: int) -> float:
	var o := odds(slot, gold)
	var ev := 0.0
	for b in BUCKETS:
		ev += float(o.probs[b]) * float(values[b])
	return ev * (1.0 + float(o.golden) * (GOLDEN_MULT - 1))

## The slot with the best expected points (ties: the more central slot).
static func best_slot(values: Array, gold: Array) -> int:
	var best := BUCKETS / 2
	var best_v := -INF
	for s in BUCKETS:
		var v := expected(values, gold, s) - absf(s - BUCKETS / 2) * 0.0001
		if v > best_v:
			best_v = v
			best = s
	return best

func _public() -> Dictionary:
	return {"rows": ROWS, "buckets": Array(buckets).duplicate(), "golden": Array(golden).duplicate(), "drops": drops.duplicate(true)}

func _save() -> Dictionary:
	return {"buckets": Array(buckets), "golden": Array(golden), "drops": drops.duplicate(true)}

func _load(d: Dictionary) -> void:
	buckets = Minigame.ints(d.get("buckets", []))
	golden = Minigame.ints(d.get("golden", []))
	drops.clear()
	for q in d.get("drops", []):
		drops.append({"slot": int(q.slot), "path": Array(Minigame.ints(q.path)), "bucket": int(q.bucket), "value": int(q.value),
			"golden": bool(q.golden), "points": int(q.points)})

class_name Combo
extends RefCounted
## Yahtzee-style combo detection over dice values 0..9 (0 = blank face, never part of a combo).
## Wild dice may become any value 1..WILD_MAX (6), never a blank and never 7..9.
## evaluate() returns {id, name, mult, group:Array[int] (dice indices), sum:int (group pips),
## values:Array[int] (effective values after Wild substitution)}.
## Best combo = highest multiplier; ties go to the higher group pip sum.

const TABLE := {
	"six_kind": {"name": "Six of a Kind", "mult": 8.0},
	"five_kind": {"name": "Five of a Kind", "mult": 6.0},
	"four_kind": {"name": "Four of a Kind", "mult": 4.0},
	"full_house": {"name": "Full House", "mult": 3.5},
	"straight": {"name": "Straight", "mult": 3.0},
	"small_straight": {"name": "Small Straight", "mult": 2.5},
	"three_kind": {"name": "Three of a Kind", "mult": 2.5},
	"two_pair": {"name": "Two Pair", "mult": 2.0},
	"pair": {"name": "Pair", "mult": 1.5},
	"high_roller": {"name": "High Roller", "mult": 1.0},
}

const MAX_VALUE := 9
const WILD_MAX := 6

const _KIND_IDS := {6: "six_kind", 5: "five_kind", 4: "four_kind", 3: "three_kind", 2: "pair"}

static func evaluate(values: Array[int], wild: Array[bool] = []) -> Dictionary:
	var wild_idx: Array[int] = []
	for i in values.size():
		if i < wild.size() and wild[i]:
			wild_idx.append(i)
	if wild_idx.is_empty():
		return _evaluate_fixed(values)
	var best: Dictionary = {}
	var assign: Array[int] = []
	assign.resize(wild_idx.size())
	assign.fill(1)
	# enumerate non-decreasing assignments (wild dice are interchangeable)
	while true:
		var vals: Array[int] = values.duplicate()
		for k in wild_idx.size():
			vals[wild_idx[k]] = assign[k]
		var c := _evaluate_fixed(vals)
		if best.is_empty() or _better(c, best):
			best = c
		# advance
		var p := assign.size() - 1
		while p >= 0 and assign[p] == WILD_MAX:
			p -= 1
		if p < 0:
			break
		assign[p] += 1
		for q in range(p + 1, assign.size()):
			assign[q] = assign[p]
	# A Wild outside the scoring group is free: it shows (and counts as) a 6.
	for i in wild_idx:
		if not (best.group as Array).has(i):
			best.values[i] = WILD_MAX
	return best

static func _better(a: Dictionary, b: Dictionary) -> bool:
	if a.mult != b.mult:
		return a.mult > b.mult
	return a.sum > b.sum

static func _make(id: String, group: Array[int], vals: Array[int]) -> Dictionary:
	var s := 0
	for i in group:
		s += vals[i]
	var e: Dictionary = TABLE[id]
	return {"id": id, "name": e.name, "mult": float(e.mult), "group": group, "sum": s, "values": vals.duplicate()}

static func _evaluate_fixed(vals: Array[int]) -> Dictionary:
	# Blank faces (0) never join a set or straight; values run 1..MAX_VALUE.
	var by_val := {}
	for v in range(1, MAX_VALUE + 1):
		by_val[v] = [] as Array[int]
	for i in vals.size():
		var v: int = clampi(vals[i], 0, MAX_VALUE)
		if v > 0:
			(by_val[v] as Array[int]).append(i)
	var best: Dictionary = {}
	var cands: Array[Dictionary] = []
	var present: Array[int] = []
	for v in range(1, MAX_VALUE + 1):
		if not (by_val[v] as Array[int]).is_empty():
			present.append(v)
	# N of a kind
	for v in present:
		var idx: Array[int] = by_val[v]
		for n in [6, 5, 4, 3, 2]:
			if idx.size() >= n:
				cands.append(_make(_KIND_IDS[n], idx.slice(0, n), vals))
				break
	# Full house and two pair
	for a in present:
		var ia: Array[int] = by_val[a]
		if ia.size() < 2:
			continue
		for b in present:
			if b == a:
				continue
			var ib: Array[int] = by_val[b]
			if ib.size() < 2:
				continue
			if ia.size() >= 3:
				var g: Array[int] = ia.slice(0, 3)
				g.append_array(ib.slice(0, 2))
				cands.append(_make("full_house", g, vals))
			if a > b:
				var g2: Array[int] = ia.slice(0, 2)
				g2.append_array(ib.slice(0, 2))
				cands.append(_make("two_pair", g2, vals))
	# Straights: runs of consecutive non-zero values
	for start in present:
		for length in [5, 4]:
			var ok := true
			var g3: Array[int] = []
			for v in range(start, start + length):
				if v > MAX_VALUE or (by_val[v] as Array[int]).is_empty():
					ok = false
					break
				g3.append((by_val[v] as Array[int])[0])
			if ok:
				cands.append(_make("straight" if length == 5 else "small_straight", g3, vals))
	# High roller
	if not vals.is_empty():
		var hi := 0
		for i in vals.size():
			if vals[i] > vals[hi]:
				hi = i
		cands.append(_make("high_roller", [hi] as Array[int], vals))
	for c in cands:
		if best.is_empty() or _better(c, best):
			best = c
	if best.is_empty():
		best = {"id": "high_roller", "name": "High Roller", "mult": 1.0, "group": [] as Array[int], "sum": 0, "values": vals.duplicate()}
	return best

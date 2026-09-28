class_name ClawMachine
extends Minigame
## Claw Machine: a row of 5 visible prizes, each {pos (centre, 0..1), width (hitbox), kind,
## points}. The UI runs the deterministic swing and sends the drop point as action args
## [position: float 0..1]. The claw grabs the prize whose hitbox contains the point (closest
## centre wins); no hidden slip, so the result depends only on the input. 2 grabs.
## Kinds (better = narrower, the legendary sits at the bottom of the pile visually):
## small 3 pts / 0.18 wide, medium 5 / 0.14, big 8 / 0.10, legendary 12 / 0.06.
## Score = points grabbed.

const GRABS := 2
const KINDS := ["small", "small", "medium", "big", "legendary"]
const POINTS := {"small": 3, "medium": 5, "big": 8, "legendary": 12}
const WIDTH := {"small": 0.18, "medium": 0.14, "big": 0.10, "legendary": 0.06}
const JITTER := 0.03

var prizes: Array[Dictionary] = []
var grabs: Array[Dictionary] = []

func _init() -> void:
	id = "claw_machine"

func _setup() -> void:
	actions_left = GRABS
	var kinds := KINDS.duplicate()
	rng.shuffle(kinds)
	prizes.clear()
	for k in kinds.size():
		var kind := String(kinds[k])
		var centre := (k + 0.5) / kinds.size() + (rng.randf() * 2.0 - 1.0) * JITTER
		prizes.append({"pos": snappedf(centre, 0.001), "width": float(WIDTH[kind]), "kind": kind,
			"points": int(POINTS[kind]), "taken": false})
	grabs.clear()

## Index of the prize under `x` (closest centre whose hitbox contains x), or -1.
func prize_at(x: float) -> int:
	var best := -1
	var best_d := INF
	for i in prizes.size():
		var p: Dictionary = prizes[i]
		if bool(p.taken):
			continue
		var d := absf(float(p.pos) - x)
		if d <= float(p.width) / 2.0 and d < best_d:
			best_d = d
			best = i
	return best

func _action(args: Array) -> Dictionary:
	if args.is_empty():
		return {"error": "drop needs [position]"}
	var x := clampf(float(args[0]), 0.0, 1.0)
	actions_left -= 1
	var i := prize_at(x)
	var info := {"x": x, "prize": i, "grabbed": i >= 0}
	if i >= 0:
		prizes[i].taken = true
		info["kind"] = String(prizes[i].kind)
	grabs.append(info.duplicate())
	return {"info": info}

func score() -> float:
	var s := 0
	for p in prizes:
		if bool(p.taken):
			s += int(p.points)
	return float(s)

## Centre of the best prize still in the machine (bot / AUTO aim), or -1.0.
func best_target() -> float:
	var best := -1
	for i in prizes.size():
		if not bool(prizes[i].taken) and (best < 0 or int(prizes[i].points) > int(prizes[best].points)):
			best = i
	return float(prizes[best].pos) if best >= 0 else -1.0

func _public() -> Dictionary:
	return {"prizes": prizes.duplicate(true), "grabs": grabs.duplicate(true)}

func _save() -> Dictionary:
	return {"prizes": prizes.duplicate(true), "grabs": grabs.duplicate(true)}

func _load(d: Dictionary) -> void:
	prizes.clear()
	for p in d.get("prizes", []):
		prizes.append({"pos": float(p.pos), "width": float(p.width), "kind": String(p.kind), "points": int(p.points), "taken": bool(p.taken)})
	grabs.clear()
	for q in d.get("grabs", []):
		var g := {"x": float(q.x), "prize": int(q.prize), "grabbed": bool(q.grabbed)}
		if q.has("kind"):
			g["kind"] = String(q.kind)
		grabs.append(g)

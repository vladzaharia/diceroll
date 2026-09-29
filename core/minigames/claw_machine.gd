class_name ClawMachine
extends Minigame
## Claw Machine: a glass cabinet whose floor is a heap of plush fluff with 7 prizes nestled
## in it, each {pos (centre, 0..1), width (hitbox), depth (0 = on top of the fluff .. 1 =
## buried at the bottom), kind, points, taken}. Everything is visible, so all of it is public.
## TWO CLAWS: before a grab the player may pick one, action args ["claw", "wide"|"narrow"]
## (free, no grab used); the drop is [position: float 0..1] with the current claw.
##   wide    REACH extra hitbox on each side, weak grip: buried prizes mostly slip
##   narrow  no extra reach (precise aim), strong grip: pulls half-buried and deep prizes
## The claw reaches the prize whose (hitbox + reach) contains the point, closest centre
## first. It holds it only inside the grip zone = reach zone * (1 - BURY[claw] * depth);
## a hit outside the grip SLIPS. No hidden roll: the result depends only on the inputs.
## A slip or a miss still brings up a puffball (FLUFF_POINTS, the consolation prize).
## Score = points + fluff. 2 grabs.

const GRABS := 2
const KINDS := ["coins", "coins", "potion", "nugget", "gem", "figure", "legendary"]
const POINTS := {"coins": 3, "potion": 4, "nugget": 4, "gem": 5, "figure": 8, "legendary": 12}
const WIDTH := {"coins": 0.1, "potion": 0.09, "nugget": 0.09, "gem": 0.08, "figure": 0.08, "legendary": 0.07}
## Depth range per kind [min, max].
const DEPTH := {"coins": [0.0, 0.3], "potion": [0.05, 0.35], "nugget": [0.1, 0.4], "gem": [0.25, 0.5], "figure": [0.35, 0.6],
	"legendary": [0.65, 0.8]}
const CLAWS := ["wide", "narrow"]
const REACH := {"wide": 0.03, "narrow": 0.0}
const BURY := {"wide": 1.0, "narrow": 0.45}
const FLUFF_POINTS := 1
const JITTER := 0.02

var prizes: Array[Dictionary] = []
var grabs: Array[Dictionary] = []
var fluff: int = 0
var claw: String = "wide"

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
		var dr: Array = DEPTH[kind]
		var depth := lerpf(float(dr[0]), float(dr[1]), rng.randf())
		prizes.append({"pos": snappedf(centre, 0.001), "width": float(WIDTH[kind]), "depth": snappedf(depth, 0.01),
			"kind": kind, "points": int(POINTS[kind]), "taken": false})
	grabs.clear()
	fluff = 0
	claw = "wide"

## Index of the prize the `c` claw reaches at `x` (closest centre whose hitbox + reach
## contains x), or -1.
func prize_at(x: float, c := "") -> int:
	var reach := float(REACH.get(c if c != "" else claw, 0.0))
	var best := -1
	var best_d := INF
	for i in prizes.size():
		var p: Dictionary = prizes[i]
		if bool(p.taken):
			continue
		var d := absf(float(p.pos) - x)
		if d <= float(p.width) / 2.0 + reach and d < best_d:
			best_d = d
			best = i
	return best

## Half width of the zone where claw `c` holds prize p (narrower the deeper it is buried).
static func grip_half(p: Dictionary, c: String) -> float:
	var reach := float(p.width) / 2.0 + float(REACH.get(c, 0.0))
	return reach * maxf(0.0, 1.0 - float(BURY.get(c, 1.0)) * float(p.get("depth", 0.0)))

func _action(args: Array) -> Dictionary:
	if args.is_empty():
		return {"error": "drop needs [position]"}
	if args[0] is String:
		if String(args[0]) != "claw" or args.size() < 2 or not CLAWS.has(String(args[1])):
			return {"error": "claw choice needs [\"claw\", \"wide\"|\"narrow\"]"}
		claw = String(args[1])
		return {"info": {"claw": claw}}
	var x := clampf(float(args[0]), 0.0, 1.0)
	actions_left -= 1
	var i := prize_at(x)
	var info := {"x": x, "claw": claw, "prize": i, "grabbed": false, "slipped": false, "fluff": false}
	if i >= 0:
		info["kind"] = String(prizes[i].kind)
		if absf(float(prizes[i].pos) - x) <= grip_half(prizes[i], claw):
			prizes[i].taken = true
			info.grabbed = true
		else:
			info.slipped = true
	if not bool(info.grabbed):
		fluff += 1
		info.fluff = true
	grabs.append(info.duplicate())
	return {"info": info}

func score() -> float:
	var s := fluff * FLUFF_POINTS
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
	return {"prizes": prizes.duplicate(true), "grabs": grabs.duplicate(true), "fluff": fluff, "claw": claw}

func _save() -> Dictionary:
	return {"prizes": prizes.duplicate(true), "grabs": grabs.duplicate(true), "fluff": fluff, "claw": claw}

func _load(d: Dictionary) -> void:
	prizes.clear()
	for p in d.get("prizes", []):
		prizes.append({"pos": float(p.pos), "width": float(p.width), "depth": float(p.get("depth", 0.0)), "kind": String(p.kind),
			"points": int(p.points), "taken": bool(p.taken)})
	grabs.clear()
	for q in d.get("grabs", []):
		var g := {"x": float(q.x), "claw": String(q.get("claw", "wide")), "prize": int(q.prize), "grabbed": bool(q.grabbed),
			"slipped": bool(q.get("slipped", false)), "fluff": bool(q.get("fluff", false))}
		if q.has("kind"):
			g["kind"] = String(q.kind)
		grabs.append(g)
	fluff = int(d.get("fluff", 0))
	claw = String(d.get("claw", "wide"))

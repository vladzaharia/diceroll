class_name ClawMachine
extends Minigame
## Claw Machine (capsule pile, user direction): the cabinet holds a pile of BALLS capsules,
## each with a prize inside. Public per ball: {pos (x, 0..1), depth (0 = top of the pile ..
## 1 = bottom), tier (common / rare / epic / legendary: the capsule's colour), taken}. What is
## inside is HIDDEN until the ball is won (contents come from the minigame Rng at setup).
## GRABS grabs; action args [position: float 0..1] (the UI's deterministic sweep).
## A grab scoops up to MAX_HOLD balls: every ball whose reach contains the point, the reach
## shrinking with depth (REACH * (1 - DEEP * depth), so the deep ones need a centred drop),
## closest first. On the lift each held ball may slip out: chance SLIP_PER_BALL per extra
## ball held + SLIP_DEPTH * its depth (rolled from the minigame Rng, so a save resumes
## identically). Won balls open in the tray; score = the points inside them.

const GRABS := 2
const BALLS := 18
const MAX_HOLD := 3
const REACH := 0.075
const DEEP := 0.8
const SLIP_PER_BALL := 0.14
const SLIP_DEPTH := 0.22
## Tier counts, depth ranges [min, max] and contents [[kind, points], ...] (one is drawn).
const TIERS := ["common", "rare", "epic", "legendary"]
const TIER_COUNT := {"common": 10, "rare": 5, "epic": 2, "legendary": 1}
const TIER_DEPTH := {"common": [0.0, 0.55], "rare": [0.15, 0.7], "epic": [0.45, 0.8], "legendary": [0.78, 0.95]}
const CONTENTS := {
	"common": [["coins", 2], ["potion", 2], ["coins", 3]],
	"rare": [["nugget", 3], ["gem", 4]],
	"epic": [["figure", 6], ["robot", 6]],
	"legendary": [["chest", 10]],
}

## Public part per ball + the hidden contents (kind, points) in a parallel array.
var balls: Array[Dictionary] = []
var contents: Array[Dictionary] = []
var grabs: Array[Dictionary] = []

func _init() -> void:
	id = "claw_machine"

func _setup() -> void:
	actions_left = GRABS
	balls.clear()
	contents.clear()
	var tiers: Array = []
	for t in TIERS:
		for k in int(TIER_COUNT[t]):
			tiers.append(t)
	rng.shuffle(tiers)
	for k in tiers.size():
		var t := String(tiers[k])
		var dr: Array = TIER_DEPTH[t]
		var pos := 0.04 + 0.92 * (k + rng.randf()) / tiers.size()
		balls.append({"pos": snappedf(pos, 0.001), "depth": snappedf(lerpf(float(dr[0]), float(dr[1]), rng.randf()), 0.01),
			"tier": t, "taken": false})
		var opts: Array = CONTENTS[t]
		var c: Array = opts[rng.randi_range(0, opts.size() - 1)]
		contents.append({"kind": String(c[0]), "points": int(c[1])})
	grabs.clear()

## Reach of the claw for a ball (half width around its centre).
static func reach_of(b: Dictionary) -> float:
	return REACH * (1.0 - DEEP * float(b.get("depth", 0.0)))

## The balls a drop at `x` scoops (public data only: positions and depths), closest first,
## at most MAX_HOLD.
static func scoop(pub_balls: Array, x: float) -> Array:
	var cand: Array = []
	for i in pub_balls.size():
		var b: Dictionary = pub_balls[i]
		if bool(b.get("taken", false)):
			continue
		var d := absf(float(b.pos) - x)
		if d <= reach_of(b):
			cand.append([d, i])
	cand.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var out: Array = []
	for c in cand.slice(0, MAX_HOLD):
		out.append(int(c[1]))
	return out

func _action(args: Array) -> Dictionary:
	if args.is_empty():
		return {"error": "drop needs [position]"}
	var x := snappedf(clampf(float(args[0]), 0.0, 1.0), 0.001)
	actions_left -= 1
	var held := scoop(balls, x)
	var won: Array = []
	var slipped: Array = []
	for i in held:
		var p := SLIP_PER_BALL * (held.size() - 1) + SLIP_DEPTH * float(balls[i].depth)
		if rng.randf() < p:
			slipped.append(i)
		else:
			balls[i].taken = true
			won.append({"ball": i, "kind": String(contents[i].kind), "points": int(contents[i].points), "tier": String(balls[i].tier)})
	var info := {"x": x, "held": held, "won": won, "slipped": slipped}
	grabs.append({"x": x, "held": held.duplicate(), "won": won.duplicate(true), "slipped": slipped.duplicate()})
	return {"info": info}

func score() -> float:
	var s := 0
	for i in balls.size():
		if bool(balls[i].taken):
			s += int(contents[i].points)
	return float(s)

## Centre of the most valuable-looking ball left (bot / AUTO aim), or -1.0.
func best_target() -> float:
	var best := -1
	for i in balls.size():
		if not bool(balls[i].taken) and (best < 0 or TIERS.find(balls[i].tier) > TIERS.find(balls[best].tier)):
			best = i
	return float(balls[best].pos) if best >= 0 else -1.0

func _public() -> Dictionary:
	# contents only for balls already won (they were opened in the tray)
	var won: Array = []
	for g in grabs:
		won.append_array(g.won)
	return {"balls": balls.duplicate(true), "grabs": grabs.duplicate(true), "won": won}

func _save() -> Dictionary:
	return {"balls": balls.duplicate(true), "contents": contents.duplicate(true), "grabs": grabs.duplicate(true)}

func _load(d: Dictionary) -> void:
	balls.clear()
	for b in d.get("balls", []):
		# re-snap: JSON round trips must give back the exact doubles the rules compare
		balls.append({"pos": snappedf(float(b.pos), 0.001), "depth": snappedf(float(b.depth), 0.01), "tier": String(b.tier),
			"taken": bool(b.taken)})
	contents.clear()
	for c in d.get("contents", []):
		contents.append({"kind": String(c.kind), "points": int(c.points)})
	grabs.clear()
	for q in d.get("grabs", []):
		var won: Array = []
		for w in q.get("won", []):
			won.append({"ball": int(w.ball), "kind": String(w.kind), "points": int(w.points), "tier": String(w.get("tier", ""))})
		grabs.append({"x": snappedf(float(q.x), 0.001), "held": Minigame.ints(q.get("held", [])), "won": won,
			"slipped": Minigame.ints(q.get("slipped", []))})

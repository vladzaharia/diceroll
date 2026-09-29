class_name Fishing
extends Minigame
## Fishing: CASTS casts. Each cast is two actions:
##   ["cast", spot]   spot 0 shallows / 1 reeds / 2 deep water. The minigame Rng decides the
##                    fish on the line (HIDDEN until it is landed), when it bites (bite_at,
##                    seconds after the bobber settles), the fake nibbles before it and the
##                    hook window (public: the bobber shows them as they happen).
##   ["hook", t]      t = seconds after the bobber settled when the player struck (the
##                    screen's clock; -1 = never). Before the bite: the fish is spooked
##                    (nothing). Within [bite_at, bite_at + window]: landed; a strike within
##                    PERFECT of the bite adds PERFECT_BONUS. Later: it got away.
## Deeper spots hold bigger fish but bite later, fake more nibbles and give a shorter window.
## Score = the points of the fish landed. actions_left = casts left (spent by the hook).
## Public: {phase "cast" | "bite", casts, spot, bite_at, window, nibbles [t], catches [{spot,
##          result "caught" | "spooked" | "missed", kind, points, perfect, t}]} (kind/points
##          only for landed fish).
## Info per action: cast {cast: true, spot, bite_at, window, nibbles}; hook {hook: true, t,
##          result, kind, points, perfect, bite_at}.

const CASTS := 3
const PERFECT := 0.28
const PERFECT_BONUS := 1
## Per spot: fish [kind, points, weight], bite range [min, max] s, nibbles [min, max], window s.
const SPOTS := [
	{"name": "Shallows", "fish": [["minnow", 2, 5], ["perch", 3, 4], ["boot", 1, 1]], "bite": [1.2, 2.2], "nibbles": [0, 1], "window": 0.8},
	{"name": "Reeds", "fish": [["bass", 4, 5], ["pike", 5, 3], ["weed", 1, 1]], "bite": [1.5, 2.7], "nibbles": [1, 2], "window": 0.62},
	{"name": "Deep", "fish": [["carp", 5, 4], ["catfish", 7, 3], ["koi", 10, 1], ["boot", 1, 2]], "bite": [1.9, 3.3], "nibbles": [1, 3], "window": 0.48},
]
## Nibbles never come this close before the bite (a readable gap).
const NIBBLE_GAP := 0.45

var phase := "cast"
var spot := -1
var bite_at := 0.0
var window := 0.0
var nibbles: Array[float] = []
var fish: Dictionary = {}
var catches: Array[Dictionary] = []

func _init() -> void:
	id = "fishing"

func _setup() -> void:
	actions_left = CASTS
	phase = "cast"
	catches.clear()

func _action(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"error": "fishing needs [\"cast\", spot] or [\"hook\", t]"}
	match String(args[0]):
		"cast":
			if phase != "cast":
				return {"error": "already casting"}
			var s := int(args[1])
			if s < 0 or s >= SPOTS.size():
				return {"error": "spot out of range"}
			_cast(s)
			return {"info": {"cast": true, "spot": spot, "bite_at": bite_at, "window": window, "nibbles": Array(nibbles)}}
		"hook":
			if phase != "bite":
				return {"error": "cast first"}
			var t := snappedf(float(args[1]), 0.001)
			var result := "missed"
			if t >= 0.0 and t < bite_at:
				result = "spooked"
			elif t >= bite_at and t <= bite_at + window:
				result = "caught"
			var perfect := result == "caught" and t - bite_at <= PERFECT
			var c := {"spot": spot, "result": result, "kind": "", "points": 0, "perfect": perfect, "t": t}
			if result == "caught":
				c.kind = String(fish.kind)
				c.points = int(fish.points) + (PERFECT_BONUS if perfect else 0)
			catches.append(c)
			actions_left -= 1
			phase = "cast"
			var info := c.duplicate()
			info["hook"] = true
			info["bite_at"] = bite_at
			fish = {}
			return {"info": info}
	return {"error": "unknown fishing action"}

func _cast(s: int) -> void:
	spot = s
	var d: Dictionary = SPOTS[s]
	var w := {}
	for f: Array in d.fish:
		w[f] = float(f[2])
	var f: Array = rng.weighted(w)
	fish = {"kind": String(f[0]), "points": int(f[1])}
	var br: Array = d.bite
	bite_at = snappedf(lerpf(float(br[0]), float(br[1]), rng.randf()), 0.01)
	window = float(d.window)
	nibbles.clear()
	var nr: Array = d.nibbles
	var n := rng.randi_range(int(nr[0]), int(nr[1]))
	var hi := bite_at - NIBBLE_GAP
	var at := 0.35
	for k in n:
		if at >= hi:
			break
		var t := snappedf(lerpf(at, hi, rng.randf() * (1.0 / float(n - k))), 0.01)
		nibbles.append(t)
		at = t + 0.35
	phase = "bite"

func score() -> float:
	var s := 0
	for c in catches:
		s += int(c.points)
	return float(s)

## The expected points of a spot for a player who lands every fish (bot / hints).
static func spot_value(s: int) -> float:
	var d: Dictionary = SPOTS[s]
	var tw := 0.0
	var ev := 0.0
	for f: Array in d.fish:
		tw += float(f[2])
		ev += float(f[1]) * float(f[2])
	return ev / tw

func _public() -> Dictionary:
	var biting := phase == "bite"
	return {"phase": phase, "casts": CASTS, "spot": spot if biting else -1, "bite_at": bite_at if biting else 0.0,
		"window": window if biting else 0.0, "nibbles": Array(nibbles).duplicate() if biting else [], "catches": catches.duplicate(true)}

func _save() -> Dictionary:
	return {"phase": phase, "spot": spot, "bite_at": bite_at, "window": window, "nibbles": Array(nibbles), "fish": fish.duplicate(),
		"catches": catches.duplicate(true)}

func _load(d: Dictionary) -> void:
	phase = String(d.get("phase", "cast"))
	spot = int(d.get("spot", -1))
	bite_at = snappedf(float(d.get("bite_at", 0.0)), 0.01)
	window = float(d.get("window", 0.0))
	nibbles.clear()
	for t in d.get("nibbles", []):
		nibbles.append(snappedf(float(t), 0.01))
	var f: Dictionary = d.get("fish", {})
	fish = {} if f.is_empty() else {"kind": String(f.kind), "points": int(f.points)}
	catches.clear()
	for c in d.get("catches", []):
		catches.append({"spot": int(c.spot), "result": String(c.result), "kind": String(c.kind), "points": int(c.points),
			"perfect": bool(c.perfect), "t": snappedf(float(c.t), 0.001)})

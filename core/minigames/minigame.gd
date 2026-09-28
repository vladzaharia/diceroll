class_name Minigame
extends RefCounted
## Base for the Arcade minigames. Each one is a deterministic state machine: its own Rng is
## seeded from the run Rng when the tile triggers (one draw), and after that only the player's
## inputs change it. Subclasses override _setup(), _action(), _public(), score(), _save(),
## _load().
##
## public_state() is the ONLY view the presentation gets (offer.state and minigame_update
## events). It never holds hidden information (unrevealed cells, fossil positions, the Rng).
## score() is the performance number MinigameDefs turns into a reward tier.

var id: String = ""
## Mastery level (1..5, from plays). Rewards scale with it in GameFlow; rules don't change.
var level: int = 1
var rng: Rng
var actions_left: int = 0
var done: bool = false

func start(p_seed: int, p_level: int) -> void:
	rng = Rng.new(p_seed)
	level = clampi(p_level, 1, MinigameDefs.MAX_MASTERY)
	done = false
	_setup()

## Applies one player action. Returns {error: msg} (nothing changed) or {info: Dictionary}
## describing what happened (only newly revealed, safe-to-show information).
func action(args: Array) -> Dictionary:
	if done or actions_left <= 0:
		return {"error": "no actions left"}
	var res := _action(args)
	if res.has("error"):
		return res
	if actions_left <= 0:
		done = true
	return res

func public_state() -> Dictionary:
	var s := _public()
	s["id"] = id
	s["actions_left"] = actions_left
	s["done"] = done
	s["score"] = score()
	return s

func score() -> float:
	return 0.0

func to_dict() -> Dictionary:
	return {"id": id, "level": level, "rng": rng.to_dict(), "actions_left": actions_left, "done": done, "data": _save()}

func load_dict(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	rng = Rng.from_dict(d.get("rng", {}))
	actions_left = int(d.get("actions_left", 0))
	done = bool(d.get("done", false))
	_load(d.get("data", {}))

# ------------------------------------------------------------------ overrides

func _setup() -> void:
	pass

func _action(_args: Array) -> Dictionary:
	return {"error": "not implemented"}

func _public() -> Dictionary:
	return {}

func _save() -> Dictionary:
	return {}

func _load(_d: Dictionary) -> void:
	pass

static func ints(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if a is Array or a is PackedInt32Array:
		for v in a:
			out.append(int(v))
	return out

class_name Minigames
extends RefCounted
## Factory and serialisation for the minigame state machines.

static func create(id: String, p_seed: int, level: int) -> Minigame:
	var m := _new(id)
	if m != null:
		m.start(p_seed, level)
	return m

static func from_dict(d: Dictionary) -> Minigame:
	var m := _new(String(d.get("id", "")))
	if m != null:
		m.load_dict(d)
	return m

static func _new(id: String) -> Minigame:
	match id:
		"fossil_hunter": return FossilHunter.new()
		"bubble_breaker": return BubbleBreaker.new()
		"scratch_off": return ScratchOff.new()
		"claw_machine": return ClawMachine.new()
	return null

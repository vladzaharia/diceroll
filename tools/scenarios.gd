class_name Scenarios
extends RefCounted
## Scenario registry for the screenshot harness (tools/shot.gd).
##
## Two ways to register a scenario:
##  1. REGISTRY below: name -> script with `static func build(name: String) -> Node`.
##  2. Convention (no edit here needed): any of PROVIDERS that exists is asked via its
##     `static func build(name: String) -> Node` (return null for names it doesn't own)
##     and, optionally, `static func names() -> PackedStringArray` for listings.
##     So game/world/scenarios.gd can add board_act1 etc. without touching this file.

const REGISTRY := {
	"actors": "res://game/actors/scenarios.gd",
	"actors_anims": "res://game/actors/scenarios.gd",
}

const PROVIDERS := [
	"res://game/actors/scenarios.gd",
	"res://game/world/scenarios.gd",
	"res://game/dice/scenarios.gd",
	"res://game/fx/scenarios.gd",
	"res://ui/scenarios.gd",
	"res://game/scenarios.gd",
	"res://game/camp/scenarios.gd",
	"res://game/pets/scenarios.gd",
	"res://game/minigames/scenarios.gd",
	"res://tools/icon_scenarios.gd",
]


static func build(name: String) -> Node:
	if REGISTRY.has(name):
		return load(REGISTRY[name]).build(name)
	for p in PROVIDERS:
		if ResourceLoader.exists(p):
			var n: Node = load(p).build(name)
			if n != null:
				return n
	return null


static func names() -> PackedStringArray:
	var out := PackedStringArray(REGISTRY.keys())
	for p in PROVIDERS:
		if ResourceLoader.exists(p):
			var s: Script = load(p)
			if s.get_script_method_list().any(func(m: Dictionary) -> bool: return m.name == "names"):
				for n in s.names():
					if not out.has(n):
						out.append(n)
	return out

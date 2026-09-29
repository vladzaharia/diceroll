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
	# hidden Developer menu (ui/modals/dev_menu.gd): opened as if the corner gesture fired
	"dev_menu": "res://ui/modals/dev_menu_scenarios.gd",
	"dev_menu_confirm": "res://ui/modals/dev_menu_scenarios.gd",
	"dev_menu_store": "res://ui/modals/dev_menu_scenarios.gd",
	"dev_menu_boot": "res://ui/modals/dev_menu_scenarios.gd",
}

const PROVIDERS := [
	"res://game/actors/scenarios.gd",
	"res://game/world/scenarios.gd",
	# the four 2026-09-29 biomes: boards, twist moments and their boss fights
	"res://game/world/biome_scenarios.gd",
	"res://game/flow/twist_scenarios.gd",
	"res://game/enemies/new_boss_scenarios.gd",
	"res://game/dice/scenarios.gd",
	"res://game/fx/scenarios.gd",
	"res://ui/scenarios.gd",
	"res://game/scenarios.gd",
	"res://game/camp/scenarios.gd",
	"res://game/pets/scenarios.gd",
	"res://game/minigames/scenarios.gd",
	"res://tools/icon_scenarios.gd",
	"res://ui/icons/rendered/rendered_icons.gd",
	"res://game/boot/scenarios.gd",
	"res://game/classes/class_scenarios.gd",
	"res://ui/camp/wardrobe_scenarios.gd",
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

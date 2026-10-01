class_name HeroDefs
extends RefCounted
## Class definitions. Per starting die (parallel arrays): `runes` (rune id, "" = plain),
## `kinds` (DiceKinds id) and `tags` (Die.tags entry, "" = none, e.g. "seed").
## `combat_rerolls`: rerolls per combat turn (default Balance.COMBAT_REROLLS).
## `mechanic`: the class mechanic id (ClassLogic; "" = none). `style`: attack style for the
## presentation (melee_1h | melee_2h | ranged | magic | dual | unarmed). `secret` (Monster Kid): the
## class shelf shows a "???" silhouette with the milestone hint until it is unlocked.
## docs/design/2026-09-28-classes-enemies-skins.md has the class sheets.

const DATA := {
	"knight": {"name": "Knight", "model": "knight", "hp": 60, "atk": 0, "runes": ["guard", ""], "board_rerolls": 1,
		"kinds": ["standard", "standard"], "tags": ["", ""], "combat_rerolls": 2, "mechanic": "", "style": "melee_1h"},
	"barbarian": {"name": "Barbarian", "model": "barbarian", "hp": 60, "atk": 2, "runes": ["heavy", ""], "board_rerolls": 1,
		"kinds": ["standard", "standard"], "tags": ["", ""], "combat_rerolls": 2, "mechanic": "", "style": "melee_2h"},
	"mage": {"name": "Mage", "model": "mage", "hp": 66, "atk": 0, "runes": ["ember", "echo"], "board_rerolls": 1,
		"kinds": ["standard", "standard"], "tags": ["", ""], "combat_rerolls": 2, "mechanic": "", "style": "magic"},
	"rogue": {"name": "Rogue", "model": "rogue", "hp": 57, "atk": 0, "runes": ["venom", "lucky"], "board_rerolls": 2,
		"kinds": ["standard", "standard"], "tags": ["", ""], "combat_rerolls": 2, "mechanic": "", "style": "dual"},
	# --- wave 1 (docs/design/2026-09-28-classes-enemies-skins.md §1.2)
	"paladin": {"name": "Paladin", "model": "paladin", "hp": 60, "atk": 0, "runes": ["", ""], "board_rerolls": 1,
		"kinds": ["twin", "standard"], "tags": ["", ""], "combat_rerolls": 2, "mechanic": "oath", "style": "melee_1h"},
	"ranger": {"name": "Ranger", "model": "ranger", "hp": 55, "atk": 0, "runes": ["blade", ""], "board_rerolls": 1,
		"kinds": ["loaded", "standard"], "tags": ["", ""], "combat_rerolls": 2, "mechanic": "aim", "style": "ranged"},
	"ninja": {"name": "Ninja", "model": "ninja", "hp": 58, "atk": 0, "runes": ["thunder", ""], "board_rerolls": 1,
		"kinds": ["standard", "odd"], "tags": ["", ""], "combat_rerolls": 3, "mechanic": "shadow_step", "style": "dual"},
	"druid": {"name": "Druid", "model": "druid", "hp": 61, "atk": 0, "runes": ["", ""], "board_rerolls": 1,
		"kinds": ["odd", "standard"], "tags": ["seed", ""], "combat_rerolls": 2, "mechanic": "overgrowth", "style": "magic"},
	# --- wave 2
	"necromancer": {"name": "Necromancer", "model": "necromancer", "hp": 54, "atk": 0, "runes": ["vampire", ""], "board_rerolls": 1,
		"kinds": ["standard", "standard"], "tags": ["", ""], "combat_rerolls": 2, "mechanic": "bone_harvest", "style": "magic"},
	"engineer": {"name": "Engineer", "model": "engineer", "hp": 54, "atk": 0, "runes": ["", ""], "board_rerolls": 1,
		"kinds": ["standard", "standard"], "tags": ["", ""], "combat_rerolls": 2, "mechanic": "turret", "style": "melee_1h",
		"turret_rune": "gilded"},
	# secret 11th class (hidden milestone trick_or_treat; never sold for Sigils)
	"monster_kid": {"name": "Monster Kid", "model": "monster_kid", "hp": 60, "atk": 0, "runes": ["", ""], "board_rerolls": 1,
		"kinds": ["pretend", "standard"], "tags": ["", ""], "combat_rerolls": 2, "mechanic": "boo", "style": "unarmed",
		"secret": true},
}

## Unlock order (UnlockDefs milestones, the Sigil "next two" rule and the class shelf).
const IDS := ["knight", "barbarian", "paladin", "mage", "ranger", "rogue", "ninja", "druid", "engineer", "necromancer", "monster_kid"]

## Mechanic names for the class badge (presentation).
const MECHANIC_NAMES := {"oath": "Oath", "aim": "Aim", "shadow_step": "Shadow Step", "overgrowth": "Overgrowth", "bone_harvest": "Bone Harvest", "turret": "Clockwork Turret", "boo": "BOO!"}

## Sim-only analysis dial (tools/sim.gd --hero=<id>.<field>=<value>): per-class field overrides.
## The game never sets it; the DATA values ARE the shipped numbers.
static var tune := {}

## DATA[id] with any sim overrides applied.
static func def(id: String) -> Dictionary:
	var d: Dictionary = DATA.get(id, DATA.knight)
	if not tune.has(id):
		return d
	var out := d.duplicate(true)
	for k in tune[id]:
		out[k] = tune[id][k]
	return out

## Field with its default for classes that leave it out.
static func field(id: String, key: String) -> Variant:
	var d: Dictionary = def(id)
	match key:
		"kinds":
			var k: Array = d.get("kinds", [])
			var out: Array = []
			for i in (d.runes as Array).size():
				out.append(String(k[i]) if i < k.size() else "standard")
			return out
		"tags":
			var t: Array = d.get("tags", [])
			var out2: Array = []
			for i in (d.runes as Array).size():
				out2.append(String(t[i]) if i < t.size() else "")
			return out2
		"combat_rerolls":
			return int(d.get("combat_rerolls", Balance.COMBAT_REROLLS))
		"mechanic":
			return String(d.get("mechanic", ""))
		"style":
			return String(d.get("style", "melee_1h"))
	return d.get(key)

static func mechanic(id: String) -> String:
	return String(field(id, "mechanic"))

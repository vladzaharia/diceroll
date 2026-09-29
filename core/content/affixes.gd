class_name AffixDefs
extends RefCounted
## Enemy affixes (docs/design/2026-09-28-classes-enemies-skins.md §3A): an extra rule on one
## enemy, stored in its dict as `affixes: [ids]`. Affixes roll when a tile's enemies spawn
## (board generation, lap mutation, event spawns, the A4+ mini-boss), from a derived Rng
## (Rng.new(hash([run.seed, "affix", lap, tile_idx, enemies]))), never the run's stream, so the
## board preview shows them and turning them off shifts no other draw. Tiles keep them in
## `enemy_affixes` (parallel to `enemies`); board change dicts carry `affixes`.
##
## Rules (CombatState hooks): trait affixes add a trait (armor, thorns, ward_allies, pierce,
## frenzy); regenerating heals REGEN_PCT of max HP at the start of each of its actions unless
## poisoned; vampiric turns attack intents into drain; hexing curses 1 die on its 1st action and
## every 3rd after; frostbound chills 1 die with its first attack; gilded x1.4 HP, gold x3,
## +GILDED_PET_CHARGE pet charge on kill. Every proc emits affix_triggered {enemy_idx, affix,
## value}.

const DATA := {
	"armored": {"name": "Armored", "trait": "armor", "desc": "Its Block never expires. Starts with Block equal to 20% of its max HP.",
		"exclude": ["bone_knight", "mini_bone_champion"]},
	"thorned": {"name": "Thorned", "trait": "thorns", "desc": "Hitting it with your attack reflects 3 damage (4 late). Never lethal.",
		"exclude": ["mini_briar_beast"]},
	"warded": {"name": "Warded", "trait": "ward_allies", "desc": "Takes half damage while any other non-warded enemy stands.",
		"exclude": [], "group": true},
	"piercing": {"name": "Piercing", "trait": "pierce", "desc": "Its attacks ignore your Block.", "exclude": ["bone_cutthroat"]},
	"frenzied": {"name": "Frenzied", "trait": "frenzy", "desc": "+2 attack each time it survives your attack (max +6).",
		"exclude": ["orc_raider"]},
	"regenerating": {"name": "Regenerating", "desc": "Heals 6% of its max HP when it acts, unless poisoned.",
		"exclude": ["thorn_sprite", "mini_briar_beast"]},
	"vampiric": {"name": "Vampiric", "desc": "Its attacks drain: it heals by the damage that gets through.",
		"exclude": ["hollow_wisp", "werewolf"]},
	"hexing": {"name": "Hexing", "desc": "Its first action curses 1 of your dice, then every 3rd action.",
		"exclude": ["cultist", "frost_skeleton"]},
	"frostbound": {"name": "Frostbound", "desc": "Its first attack also chills 1 of your dice.",
		"exclude": ["ice_archer", "mini_frost_warden"]},
	"gilded": {"name": "Gilded", "desc": "Tougher (x1.4 HP) and richer: x3 gold, +2 pet charge.", "exclude": []},
}

const IDS := ["armored", "thorned", "warded", "piercing", "frenzied", "regenerating", "vampiric", "hexing", "frostbound", "gilded"]

## Biome affixes weigh BIOME_WEIGHT each; gilded weighs GILDED_WEIGHT everywhere.
const BIOME := {
	"glade": ["thorned", "regenerating"],
	"crypt": ["armored", "hexing"],
	"hollow": ["vampiric", "hexing", "warded"],
	"frost": ["frostbound", "armored", "piercing"],
	"throne": ["armored", "warded", "hexing", "frenzied"],
	"magma": ["frenzied", "piercing", "thorned"],
	# 2026-09-29 new biomes (docs/design/2026-09-29-new-biomes.md)
	"mines": ["armored", "piercing"],
	"warcamp": ["frenzied", "thorned", "piercing"],
	"ruins": ["piercing", "hexing", "armored", "frenzied"],
	"moonlit": ["vampiric", "regenerating", "frenzied", "warded"],
}
## Per-biome gilded weight overrides (the Deep Mines is the economy biome).
const GILDED_BY_BIOME := {"mines": 3.0}
const BIOME_WEIGHT := 3.0
const GILDED_WEIGHT := 1.0

## Spawn rates by lap band ((lap - 1) / 3).
const REGULAR_CHANCE := [0.0, 0.06, 0.10, 0.15, 0.20]
const ELITE_CHANCE := [0.0, 0.5, 0.75, 1.0, 1.0]
const ELITE_SECOND := [0.0, 0.0, 0.0, 0.15, 0.30]
const REROLL_TRIES := 3

const ARMORED_BLOCK_PCT := 0.2
const THORNS_EARLY := 3
const THORNS_LATE := 4
const REGEN_PCT := 0.06
const HEX_EVERY := 3
const GILDED_HP := 1.4
const GILDED_GOLD := 3.0
const GILDED_XP := 1.5
const GILDED_PET_CHARGE := 2
## Gold and XP multiplier per non-gilded affix.
const REWARD_MULT := 1.5

## Sim-only dial (tools/sim.gd --affixes=off|on|force:<id>): "" = the profile decides.
## "force:<id>" puts that affix on every elite leader (and nothing else).
static var sim_mode := ""

static func name_of(id: String) -> String:
	return String(DATA[id].name) if DATA.has(id) else id

## Card data for the HUD badge / tooltip / Bestiary: {id, name, desc}.
static func card(id: String) -> Dictionary:
	return {"id": id, "name": name_of(id), "desc": String(DATA.get(id, {}).get("desc", ""))}

static func weights(biome: String) -> Dictionary:
	var w := {}
	for id in BIOME.get(biome, []):
		w[id] = BIOME_WEIGHT
	w["gilded"] = float(GILDED_BY_BIOME.get(biome, GILDED_WEIGHT))
	return w

## True when affix `a` may go on enemy `id` that already has `have` affixes (and its traits).
static func allowed(a: String, id: String, have: Array, group_size: int, warded_taken: bool) -> bool:
	if have.has(a):
		return false
	var d: Dictionary = DATA[a]
	if (d.exclude as Array).has(id):
		return false
	if d.has("trait") and EnemyDefs.traits(id).has(String(d.trait)):
		return false
	if bool(d.get("group", false)) and (group_size < 2 or warded_taken):
		return false
	return true

## One affix pick for enemy `id` (re-rolled up to REROLL_TRIES times when not allowed), "" = none.
static func pick(rng: Rng, id: String, biome: String, have: Array, group_size: int, warded_taken: bool) -> String:
	var w := weights(biome)
	for t in REROLL_TRIES:
		var a := String(rng.weighted(w))
		if allowed(a, id, have, group_size, warded_taken):
			return a
	return ""

## Affixes for a tile's enemies: [[ids] per enemy]. elite: the first enemy is the elite leader.
## mode: "on" (normal rates) or "force:<id>" (that affix on the elite leader only).
static func roll_tile(rng: Rng, enemies: Array, biome: String, band: int, elite: bool, mode := "on") -> Array:
	var out: Array = []
	var warded := false
	band = clampi(band, 0, REGULAR_CHANCE.size() - 1)
	for k in enemies.size():
		var id := String(enemies[k])
		var have: Array = []
		if EnemyDefs.is_boss(id):
			out.append(have)
			continue
		var leader := elite and k == 0
		if mode.begins_with("force:"):
			var fa := mode.substr(6)
			if leader and DATA.has(fa) and allowed(fa, id, have, enemies.size(), false):
				have.append(fa)
			out.append(have)
			continue
		var first: float = ELITE_CHANCE[band] if leader else REGULAR_CHANCE[band]
		if rng.chance(first):
			var a := pick(rng, id, biome, have, enemies.size(), warded)
			if a != "":
				have.append(a)
				warded = warded or a == "warded"
				if leader and rng.chance(float(ELITE_SECOND[band])):
					var b := pick(rng, id, biome, have, enemies.size(), warded)
					if b != "":
						have.append(b)
						warded = warded or b == "warded"
		out.append(have)
	return out

## The A4+ mini-boss: one affix from its biome's list (not gilded), re-rolled when not allowed.
static func roll_miniboss(rng: Rng, id: String, biome: String) -> Array:
	var ids: Array = (BIOME.get(biome, []) as Array).duplicate()
	for t in REROLL_TRIES + 3:
		if ids.is_empty():
			break
		var a := String(rng.pick(ids))
		if allowed(a, id, [], 1, false):
			return [a]
		ids.erase(a)
	return []

## Applies `affixes` to a freshly made enemy dict (after lap scaling and ascension).
static func apply(e: Dictionary, affixes: Array, band: int) -> void:
	e["affixes"] = []
	for a in affixes:
		var id := String(a)
		if not DATA.has(id):
			continue
		(e.affixes as Array).append(id)
		var d: Dictionary = DATA[id]
		if d.has("trait") and not (e.traits as Array).has(String(d.trait)):
			(e.traits as Array).append(String(d.trait))
		match id:
			"gilded":
				e.hp = maxi(1, int(round(int(e.hp) * GILDED_HP)))
				e.max_hp = e.hp
			"thorned":
				e["thorns_value"] = THORNS_LATE if band >= 3 else THORNS_EARLY
	if (e.affixes as Array).has("armored"):
		e.block = int(e.block) + int(round(int(e.max_hp) * ARMORED_BLOCK_PCT))

## Gold / XP multipliers for an enemy's affixes: [gold, xp].
static func reward_mult(affixes: Array) -> Array:
	var g := 1.0
	var x := 1.0
	for a in affixes:
		if String(a) == "gilded":
			g *= GILDED_GOLD
			x *= GILDED_XP
		elif DATA.has(String(a)):
			g *= REWARD_MULT
			x *= REWARD_MULT
	return [g, x]

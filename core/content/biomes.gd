class_name BiomeDefs
extends RefCounted
## Biomes (revision §15 replayability). Six biomes in three tiers; each run picks one per tier
## (RunState.route). A biome sets the board's tile mix, a gameplay twist, the enemy roster and
## (tier 2 / tier 3) the mini-boss and final-boss candidates.
##
## mix: deltas applied to Board.layout_for(size); Empty absorbs the difference.
## trap_tile: the tile type traps become in this biome (frost: "ice").
## pools: [early, late] regular enemy pools. "early" is the tier's first 3 laps.
## elite: the elite tile's leader enemy.
## minibosses / bosses: candidate ids drawn at run start (only the tier-2 biome's minibosses and
## the tier-3 biome's bosses are used by the run; the others are kept for future tier shuffles).
## mutate_elites: extra Enemy -> Elite swaps in the lap mutation.

const TIERS := [["glade", "crypt"], ["hollow", "frost"], ["throne", "magma"]]
## Used for old saves and for boards generated without a route.
const DEFAULT_ROUTE := ["crypt", "hollow", "throne"]

const DEFS := {
	"glade": {
		"name": "Verdant Glade", "tier": 1,
		"desc": "Sunlit meadows: extra campfires and chests, and campfires heal 45% instead of 30%.",
		"mix": {"campfire": 1, "chest": 1},
		"pools": [["thorn_sprite", "wolf_bandit", "skeleton_minion"],
			["thorn_sprite", "wolf_bandit", "skeleton_archer", "orc_raider"]],
		"elite": "brute",
		"minibosses": ["mini_briar_beast"], "bosses": [],
	},
	"crypt": {
		"name": "The Crypt", "tier": 1,
		"desc": "Spike traps line the halls, but every trap you dodge drops a few coins.",
		"mix": {"trap": 2},
		"pools": [["skeleton_minion", "skeleton_minion", "skeleton_archer"],
			["skeleton_minion", "skeleton_archer", "skeleton_warrior", "bone_cutthroat"]],
		"elite": "bone_golem",
		"minibosses": ["mini_bone_champion"], "bosses": [],
	},
	"hollow": {
		"name": "The Hollow", "tier": 2,
		"desc": "Restless spirits: events are twice as common, and finishing one heals 8% of your max HP.",
		"mix": {"event": 2},
		"pools": [["skeleton_archer", "cultist", "hollow_wisp", "bandit"],
			["cultist", "bandit", "hollow_wisp", "werewolf"]],
		"elite": "fallen_paladin",
		"minibosses": ["mini_pumpkin_knight", "mini_grave_mage", "mini_moonfang"], "bosses": [],
	},
	"frost": {
		"name": "Frostpeak", "tier": 2,
		"desc": "Traps are ice sheets: slipping on one freezes a die (locked) for the first turn of your next fight.",
		"mix": {"trap": 1}, "trap_tile": "ice",
		"pools": [["frost_skeleton", "ice_archer", "skeleton_warrior"],
			["frost_skeleton", "ice_archer", "skeleton_warrior", "orc_drummer"]],
		"elite": "brute",
		"minibosses": ["mini_frost_warden", "mini_bone_champion", "mini_orc_warchief"], "bosses": [],
	},
	"throne": {
		"name": "Bone Throne", "tier": 3,
		"desc": "The king's guard: twice as many elites, and each has double the chance to drop a boss-tier passive.",
		"mix": {"elite": 1, "enemy": -1},
		"pools": [["skeleton_warrior", "bone_knight", "cultist", "brute"],
			["bone_knight", "brute", "cultist", "bone_knight"]],
		"elite": "bone_knight",
		"mutate_elites": 1,
		"minibosses": ["mini_bone_champion"], "bosses": ["boss_lich", "boss_bone_warden"],
	},
	"magma": {
		"name": "Magma Depths", "tier": 3,
		"desc": "Lava tiles scorch you for 3% max HP when you pass over them and 10% when you land on them.",
		"mix": {"lava": 3},
		"pools": [["ember_imp", "ember_imp", "skeleton_warrior", "orc_raider"],
			["ember_imp", "magma_brute", "brute", "cultist"]],
		"elite": "magma_brute",
		"minibosses": ["mini_cinder_brute"], "bosses": ["boss_cinder_king", "boss_magma_golem"],
	},
}

static func has(id: String) -> bool:
	return DEFS.has(id)

static func name_of(id: String) -> String:
	return String(DEFS[id].name) if DEFS.has(id) else id

static func desc_of(id: String) -> String:
	return String(DEFS[id].desc) if DEFS.has(id) else ""

## One biome per tier, drawn with `rng` (always draws, so forcing a route never shifts the
## rest of the run's random stream).
static func pick_route(rng: Rng) -> Array[String]:
	var out: Array[String] = []
	for tier in TIERS:
		out.append(String(rng.pick(tier)))
	return out

## True when `route` has one valid biome per tier, in tier order.
static func valid_route(route: Array) -> bool:
	if route.size() != TIERS.size():
		return false
	for k in route.size():
		if not (TIERS[k] as Array).has(String(route[k])):
			return false
	return true

## Mini-boss candidates for a route (the tier-2 biome's list).
static func miniboss_candidates(route: Array) -> Array:
	return DEFS[String(route[1])].minibosses

## Final-boss candidates for a route (the tier-3 biome's list).
static func boss_candidates(route: Array) -> Array:
	return DEFS[String(route[2])].bosses

## Every route, in tier order (8 with 2 biomes per tier).
static func all_routes() -> Array:
	var out: Array = []
	for a in TIERS[0]:
		for b in TIERS[1]:
			for c in TIERS[2]:
				out.append([a, b, c])
	return out

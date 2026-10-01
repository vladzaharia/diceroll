class_name BiomeDefs
extends RefCounted
## Biomes (revision §15 replayability; docs/design/2026-09-29-new-biomes.md). Ten biomes in three
## tiers (3/3/4); each run picks one per tier (RunState.route). A biome sets the board's tile
## mix, a gameplay twist, the enemy roster and
## (tier 2 / tier 3) the mini-boss and final-boss candidates.
##
## mix: deltas applied to Board.layout_for(size); Empty absorbs the difference.
## trap_tile: the tile type traps become in this biome (frost: "ice").
## pools: [early, late] regular enemy pools. "early" is the tier's first 3 laps.
## elite: the elite tile's leader enemy.
## minibosses / bosses: candidate ids drawn at run start (only the tier-2 biome's minibosses and
## the tier-3 biome's bosses are used by the run; the others are kept for future tier shuffles).
## mutate_elites: extra Enemy -> Elite swaps in the lap mutation.
## twist (new biomes): the rule id GameFlow handles ("ore", "drums", "moon", "heat"; "" = the
## older biomes, whose twists are hard-wired by biome id). refill: {tile: n} Empty tiles turned
## back into that tile at each lap mutation (up to n on the board). look: presentation key.
## short_bosses (tier 2): final-boss candidates when the biome is the Short Road's second biome.
## enemy_hp: HP multiplier for the biome's regular and elite enemies (default 1.0; enemy_hp()).

const TIERS := [["glade", "crypt", "mines"], ["hollow", "frost", "warcamp"], ["throne", "magma", "ruins", "moonlit"]]
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
		"name": "The Crypt", "tier": 1, "enemy_hp": 1.03,
		"desc": "Spike traps line the halls, but every trap you dodge drops a few coins.",
		"mix": {"trap": 2},
		"pools": [["skeleton_minion", "skeleton_minion", "skeleton_archer"],
			["skeleton_minion", "skeleton_archer", "skeleton_warrior", "bone_cutthroat"]],
		"elite": "bone_golem",
		"minibosses": ["mini_bone_champion"], "bosses": [],
	},
	"hollow": {
		"name": "The Hollow", "tier": 2, "enemy_hp": 1.06,
		"desc": "Restless spirits: events are twice as common, and finishing one heals 3% of your max HP.",
		"mix": {"event": 2},
		"pools": [["werewolf", "cultist", "hollow_wisp", "bandit"],
			["cultist", "bandit", "hollow_wisp", "werewolf"]],
		"elite": "fallen_paladin",
		"minibosses": ["mini_pumpkin_knight", "mini_grave_mage", "mini_moonfang"], "bosses": [],
		"short_bosses": ["boss_lich", "boss_bone_warden"], "short_boss_hp": 0.83,
	},
	"frost": {
		"name": "Frostpeak", "tier": 2,
		"desc": "Traps are ice sheets: slipping on one freezes a die (locked) for the first turn of your next fight.",
		"mix": {"trap": 1}, "trap_tile": "ice",
		"pools": [["frost_skeleton", "ice_archer", "skeleton_warrior"],
			["frost_skeleton", "ice_archer", "skeleton_warrior", "orc_drummer"]],
		"elite": "brute",
		"minibosses": ["mini_frost_warden", "mini_bone_champion"], "bosses": [],
		"short_bosses": ["boss_bone_warden", "boss_lich"], "short_boss_hp": 0.8,
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
		"name": "Magma Depths", "tier": 3, "enemy_hp": 1.02,
		"desc": "Lava tiles scorch you for 3% max HP when you pass over them and 10% when you land on them.",
		"mix": {"lava": 3},
		"pools": [["ember_imp", "ember_imp", "skeleton_warrior", "orc_raider"],
			["ember_imp", "magma_brute", "brute", "cultist"]],
		"elite": "magma_brute",
		"minibosses": ["mini_cinder_brute"], "bosses": ["boss_cinder_king", "boss_magma_golem"],
	},
	# --- 2026-09-29 new biomes (docs/design/2026-09-29-new-biomes.md)
	"mines": {
		"name": "Deep Mines", "tier": 1, "twist": "ore", "look": "mines", "enemy_hp": 0.94,
		"desc": "Ore veins pay out gold or a Face Raise, but each vein you mine caves in and becomes a trap.",
		"mix": {"ore": 3}, "refill": {"ore": 3},
		"pools": [["skeleton_minion", "skeleton_minion", "skeleton_archer", "bone_cutthroat"],
			["skeleton_minion", "bone_cutthroat", "skeleton_warrior", "orc_raider"]],
		"elite": "rock_golem",
		"minibosses": ["mini_bone_champion"], "bosses": [],
	},
	"warcamp": {
		"name": "Orc Warcamp", "tier": 2, "twist": "drums", "look": "warcamp", "enemy_hp": 0.9,
		"desc": "War drums rally every orc in earshot: enemies gain +1 attack per standing drum. Land on a drum to smash it.",
		"mix": {"drum": 1}, # drum count = WARCAMP_DRUMS (Board.layout_for)
		"pools": [["orc_raider", "wolf_bandit", "bandit", "skeleton_archer"],
			["orc_raider", "orc_drummer", "wolf_bandit", "skeleton_warrior"]],
		"elite": "orc_raider",
		"minibosses": ["mini_orc_warchief", "mini_cinder_brute"], "bosses": [],
		"short_bosses": ["boss_cinder_king", "boss_magma_golem"], "short_boss_hp": 0.75,
	},
	"ruins": {
		"name": "Sunscorched Ruins", "tier": 3, "twist": "heat", "look": "ruins", "enemy_hp": 0.95,
		"desc": "The heat costs 8% of your max HP at the end of every lap unless you landed on an oasis during it. Oases heal 5%.",
		"mix": {"oasis": 3, "campfire": -1},
		"pools": [["bone_cutthroat", "skeleton_warrior", "bone_knight", "cultist"],
			["bone_cutthroat", "bone_golem", "bone_knight", "brute"]],
		"elite": "bone_golem",
		"minibosses": ["mini_bone_champion"], "bosses": ["boss_sand_colossus", "boss_bone_warden"],
	},
	"moonlit": {
		"name": "Moonlit Woods", "tier": 3, "twist": "moon", "look": "moonlit", "enemy_hp": 1.02,
		"desc": "The moon grows each lap. Under the full moon, werewolves are already changed, twice as many elites stalk the woods, fights pay 1.5x gold, and a moonlit rune chest appears.",
		"mix": {"event": 1, "trap": -1},
		"pools": [["werewolf", "wolf_bandit", "hollow_wisp", "orc_raider"],
			["werewolf", "werewolf", "brute", "wolf_bandit"]],
		"elite": "werewolf",
		"minibosses": ["mini_moonfang"], "bosses": ["boss_moon_king", "boss_lich"], "short_boss_hp": 0.73,
	},
}

# ---------------------------------------------------------------- new-biome twist numbers

## Deep Mines: an ore vein pays ORE_GOLD x lap gold scale or one Face Raise, then caves in (a trap).
static var ORE_GOLD := 20
## Lap mutation: ore tiles are refilled on Empty tiles up to the biome's refill count, unless the
## board already holds MINES_TRAP_CAP traps.
static var MINES_TRAP_CAP := 6
## Orc Warcamp: +DRUM_RALLY attack per standing drum for every enemy at fight start; smashing a drum
## pays DRUM_GOLD x gold scale; the lap mutation rebuilds one drum once every drum is smashed.
static var DRUM_RALLY := 1
static var DRUM_GOLD := 14
static var WARCAMP_DRUMS := 1
## Sunscorched Ruins: heat at each lap end (never lethal) unless you landed on an oasis that lap.
static var HEAT_PCT := 0.08
static var OASIS_HEAL_PCT := 0.05
## Moonlit Woods: phases by the lap's position in the biome (1..5); the Half moon raises the
## transform threshold, the Full moon pre-transforms, adds an elite and a moon rune chest and pays
## MOON_FULL_GOLD x fight gold.
const MOON_PHASES := ["crescent", "half", "full", "half", "crescent"]
const MOON_HALF_TRANSFORM := 0.65
const MOON_FULL_GOLD := 1.5
## Moon chest placement: the first Empty tile this many tiles ahead of the hero.
const MOON_CHEST_AHEAD := [3, 8]

## The twist numbers above are static vars so tools/sim.gd --bnum=<NAME>:<value> can sweep them;
## the game never changes them.
##
## Sim-only dial (tools/sim.gd --twist=off[:<biome>,...]): biome ids whose new twist is off ("all"
## = every new biome). A switched-off twist does nothing and its tiles (ore, drum, oasis) become
## Empty. The game never sets it.
static var twist_off: Array = []
## Sim-only dial (tools/sim.gd --biome-hp=<biome>:<mult>,...): overrides enemy_hp(). The game never sets it.
static var tune_enemy_hp := {}

static func has(id: String) -> bool:
	return DEFS.has(id)

static func name_of(id: String) -> String:
	return String(DEFS[id].name) if DEFS.has(id) else id

static func desc_of(id: String) -> String:
	return String(DEFS[id].desc) if DEFS.has(id) else ""

## The biome's active twist id ("ore", "drums", "moon", "heat"; "" = none or switched off).
static func twist_of(id: String) -> String:
	if not DEFS.has(id):
		return ""
	var t := String(DEFS[id].get("twist", ""))
	if t == "" or twist_off.has("all") or twist_off.has(id):
		return ""
	return t

## Presentation key of the biome (defaults to its id).
static func look_of(id: String) -> String:
	return String(DEFS[id].get("look", id)) if DEFS.has(id) else ""

## Tile types a twist owns (they become Empty when the twist is off).
const TWIST_TILES := {"ore": "ore", "drums": "drum", "heat": "oasis"}

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

## Mini-boss candidates for a route (the tier-2 biome's list; a Short Road route's second biome).
static func miniboss_candidates(route: Array) -> Array:
	return DEFS[String(route[1])].minibosses

## Final-boss candidates for a route (the tier-3 biome's list; a Short Road route's second biome).
static func boss_candidates(route: Array) -> Array:
	return final_boss_candidates(String(route.back()))

## Every route, in tier order (36 with tiers of 3/3/4).
static func all_routes() -> Array:
	var out: Array = []
	for a in TIERS[0]:
		for b in TIERS[1]:
			for c in TIERS[2]:
				out.append([a, b, c])
	return out

# ---------------------------------------------------------------- Short Road

## Biomes the Short Road's second biome is drawn from: tier 2 and tier 3, in content order.
static func short_second_biomes() -> Array:
	return (TIERS[1] as Array) + (TIERS[2] as Array)

## True when `route` is a Short Road route: [tier-1 biome, tier-2 or tier-3 biome].
static func valid_short_route(route: Array) -> bool:
	return route.size() == 2 and (TIERS[0] as Array).has(String(route[0])) and short_second_biomes().has(String(route[1]))

## Final-boss candidates when `biome` ends the run: a tier-3 biome's bosses, a tier-2 biome's
## short_bosses (Short Road only).
static func final_boss_candidates(biome: String) -> Array:
	var d: Dictionary = DEFS[biome]
	return d.bosses if not (d.bosses as Array).is_empty() else d.get("short_bosses", [])

## Short Road final-boss HP multiplier when `biome` ends the run: the biome's short_boss_hp (tier 2:
## the finale comes after easier tier-2 laps, so the boss keeps more HP), else SHORT_T3_BOSS_HP.
const SHORT_T3_BOSS_HP := 0.68

## Regular and elite enemies in the biome (not mini-bosses, not final bosses) have x this HP
## (DEFS "enemy_hp", default 1.0): the whole-game balance pass's route-spread lever
## (docs/plans/balance.md). tools/sim.gd --biome-hp=<biome>:<mult> overrides it (tune_enemy_hp).
static func enemy_hp(biome: String) -> float:
	if tune_enemy_hp.has(biome):
		return float(tune_enemy_hp[biome])
	return float(DEFS[biome].get("enemy_hp", 1.0)) if DEFS.has(biome) else 1.0

static func short_boss_hp(biome: String) -> float:
	if not DEFS.has(biome):
		return Balance.SHORT_BOSS_HP
	return float(DEFS[biome].get("short_boss_hp", SHORT_T3_BOSS_HP))

## Every Short Road route (21 = 3 tier-1 biomes x 7 second biomes).
static func all_short_routes() -> Array:
	var out: Array = []
	for a in TIERS[0]:
		for b in short_second_biomes():
			out.append([a, b])
	return out

class_name UnlockDefs
extends RefCounted
## Meta-layer tables (review §4–§6 plus the user decisions of 2026-09-28): what a fresh profile
## owns, the Workshop unlock packs, milestone unlocks, Sigil prices, Crowns upgrades and the
## Ascension ladder. Everything is deterministic: a milestone either happened or it didn't, and
## every price is fixed.

# ------------------------------------------------------------------ lockable content

## Unlock kinds. Every kind can be earned by a milestone; SIGIL_PRICE kinds can also be bought
## early with Sigils. "features" only come from milestones (they make a Crowns upgrade
## purchasable).
const KINDS := ["classes", "biomes", "bosses", "minibosses", "pets", "minigames", "packs", "gear", "potions", "features"]

const SIGIL_PRICE := {
	"classes": 8, "biomes": 5, "bosses": 4, "minibosses": 4, "pets": 6, "minigames": 6, "packs": 6, "gear": 4, "potions": 4,
}

## A fresh profile. Classes: Knight only (all four when the profile's lock_classes flag is off).
## Route: Glade -> Hollow -> Throne with the Pumpkin Knight and the Lich. No pet on run 1.
const STARTER := {
	"classes": ["knight"],
	"biomes": ["glade", "hollow", "throne"],
	"bosses": ["boss_lich"],
	"minibosses": ["mini_pumpkin_knight"],
	"pets": [],
	"minigames": ["scratch_off", "claw_machine"],
	"packs": ["starter"],
	"gear": [],
	"potions": ["healing"],
	"features": [],
}

## Workshop unlock packs (horizontal content for the drop pools). Class starting runes work on
## the class die even while their rune is locked; packs only add things to drops.
const PACKS := {
	"starter": {"name": "Starter", "runes": ["blade", "guard", "venom", "heavy", "vampire", "gilded"],
		"kinds": ["standard", "low", "high", "loaded"],
		"passives": ["pair_master", "gold_tooth", "steady_hand", "treasure_sense", "haggler", "scholar", "second_wind",
			"full_house_party", "pathfinder", "piggy_bank", "blacksmith", "bloodthirst",
			"crowd_pleaser", "fast_feet", "midas_fist"]},
	"gamblers_kit": {"name": "Gambler's Kit", "runes": ["lucky"], "kinds": ["gambler"],
		"passives": ["double_trouble", "encore"]},
	"cold_steel": {"name": "Cold Steel", "runes": ["frost"], "kinds": ["twin"], "passives": ["iron_skin", "thorns"]},
	"pyromancy": {"name": "Pyromancy", "runes": ["ember"], "kinds": [], "passives": ["boxcars", "opening_salvo", "glass_cannon"]},
	"storm": {"name": "Storm", "runes": ["thunder"], "kinds": [], "passives": ["loaded_hands", "collector"]},
	"numerology": {"name": "Numerology", "runes": [], "kinds": ["odd", "even"], "passives": ["straight_shooter", "snake_eyes"]},
	"resonance": {"name": "Resonance", "runes": ["echo"], "kinds": [], "passives": ["rune_echo", "resonance"]},
	"colossus": {"name": "Colossus", "runes": ["wild"], "kinds": ["giant"], "passives": ["triple_threat", "rune_bloom", "extra_hand", "phoenix"]},
}
const PACK_IDS := ["starter", "gamblers_kit", "cold_steel", "pyromancy", "storm", "numerology", "resonance", "colossus"]

## Passives that only make sense for gold; meta runs keep them out of elite/mini-boss rewards
## (they still appear in shops and shrines).
const ECONOMY_PASSIVES := ["gold_tooth", "piggy_bank", "treasure_sense", "haggler"]

## Pool toggle: at most this share of each unlocked pool (runes, kinds, passives) may be
## switched off in the Workshop.
const POOL_TOGGLE_MAX := 0.25

## All ids of an unlock kind.
static func all_ids(kind: String) -> Array:
	match kind:
		"classes": return HeroDefs.IDS.duplicate()
		"biomes":
			var b: Array = []
			for tier in BiomeDefs.TIERS:
				b.append_array(tier)
			return b
		"bosses": return ["boss_lich", "boss_bone_warden", "boss_cinder_king", "boss_magma_golem"]
		"minibosses": return ["mini_pumpkin_knight", "mini_grave_mage", "mini_frost_warden", "mini_bone_champion", "mini_briar_beast", "mini_cinder_brute", "mini_moonfang", "mini_orc_warchief"]
		"pets": return PetDefs.IDS.duplicate()
		"minigames": return MinigameDefs.IDS.duplicate()
		"packs": return PACK_IDS.duplicate()
		"gear": return GearDefs.SLOTS.duplicate()
		"potions": return PotionDefs.IDS.duplicate()
		"features": return ["potion_belt", "loadout_slot"]
		"runes": return Runes.IDS.duplicate()
		"kinds": return DiceKinds.IDS.duplicate()
		"passives": return Passives.IDS.duplicate()
	return []

## Drop pool ("runes" | "kinds" | "passives") granted by a list of owned packs, in content order.
static func pool_from_packs(packs: Array, kind: String) -> Array:
	var have := {}
	for p in packs:
		if PACKS.has(p):
			for id in PACKS[p].get(kind, []):
				have[id] = true
	var out: Array = []
	for id in all_ids(kind):
		if have.has(id):
			out.append(id)
	return out

## Sigil price to unlock `id` of `kind` early; {} when it can't be bought.
static func sigil_cost(kind: String, id: String) -> Dictionary:
	if not SIGIL_PRICE.has(kind) or not all_ids(kind).has(id):
		return {}
	return {"sigils": int(SIGIL_PRICE[kind])}

# ------------------------------------------------------------------ milestones

## Milestones, checked after every banked run against Profile.records (counters are cumulative
## over all runs; best_* are records). A milestone fires once and grants its unlocks for free.
## cond: {stat, min} or {any: [cond, ...]}. Stats: runs, laps, fights, minigames, rerolls, kept,
## poison_kills, cashouts, block, straights, minibosses_reached, minibosses_killed,
## bosses_reached, wins, act2_runs, act3_runs, frost_visits, throne_wins, mage_wins,
## full_runes, best_lap.
## `run` is the design target (median run number for the sim's greedy bot, fresh profile).
const MILESTONES := [
	{"id": "first_steps", "run": 1, "desc": "Finish your first run.", "cond": {"stat": "runs", "min": 1},
		"unlocks": [["gear", "helm"]]},
	{"id": "lap_five", "run": 1, "desc": "Reach lap 5.", "cond": {"stat": "best_lap", "min": 5},
		"unlocks": [["pets", "pumpkin_sprite"]]},
	{"id": "wanderer", "run": 2, "desc": "Complete 20 laps in total.", "cond": {"stat": "laps", "min": 20},
		"unlocks": [["gear", "blade"], ["biomes", "crypt"]]},
	{"id": "brawler", "run": 3, "desc": "Win 45 fights in total.", "cond": {"stat": "fights", "min": 45},
		"unlocks": [["classes", "barbarian"]]},
	{"id": "gate_crasher", "run": 4, "desc": "Reach the mini-boss twice.", "cond": {"stat": "minibosses_reached", "min": 2},
		"unlocks": [["packs", "gamblers_kit"], ["gear", "boots"]]},
	{"id": "arcade_regular", "run": 5, "desc": "Play 14 minigames.", "cond": {"stat": "minigames", "min": 14},
		"unlocks": [["minigames", "fossil_hunter"]]},
	{"id": "deep_delver", "run": 7, "desc": "Reach the third biome in 7 runs.", "cond": {"stat": "act3_runs", "min": 7},
		"unlocks": [["biomes", "frost"], ["potions", "stoneskin"]]},
	{"id": "boss_seen", "run": 6, "desc": "Reach the final boss 5 times.", "cond": {"stat": "bosses_reached", "min": 5},
		"unlocks": [["pets", "skull_buddy"], ["gear", "charm"], ["features", "potion_belt"]]},
	{"id": "frostbitten", "run": 8, "desc": "Visit Frostpeak.", "cond": {"stat": "frost_visits", "min": 1},
		"unlocks": [["packs", "cold_steel"]]},
	{"id": "champion", "run": 10, "desc": "Defeat 7 mini-bosses.", "cond": {"stat": "minibosses_killed", "min": 7},
		"unlocks": [["classes", "mage"], ["minibosses", "mini_grave_mage"]]},
	{"id": "straight_talk", "run": 11, "desc": "Score 70 Straights.", "cond": {"stat": "straights", "min": 70},
		"unlocks": [["packs", "numerology"]]},
	{"id": "arcade_fan", "run": 13, "desc": "Play 40 minigames.", "cond": {"stat": "minigames", "min": 40},
		"unlocks": [["minigames", "bubble_breaker"], ["features", "loadout_slot"]]},
	{"id": "plague", "run": 14, "desc": "Kill 30 enemies with Poison.", "cond": {"stat": "poison_kills", "min": 30},
		"unlocks": [["pets", "lantern_ghost"]]},
	{"id": "victor", "run": 5, "desc": "Win a run.", "cond": {"stat": "wins", "min": 1},
		"unlocks": [["packs", "colossus"], ["biomes", "magma"], ["bosses", "boss_cinder_king"], ["bosses", "boss_magma_golem"]]},
	{"id": "tinkerer", "run": 12, "desc": "Use 1,100 combat rerolls.", "cond": {"stat": "rerolls", "min": 1100},
		"unlocks": [["packs", "storm"], ["potions", "reroll_tonic"]]},
	{"id": "veteran", "run": 15, "desc": "Win 8 runs, or play 15.", "cond": {"any": [{"stat": "wins", "min": 8}, {"stat": "runs", "min": 15}]},
		"unlocks": [["classes", "rogue"]]},
	{"id": "patience", "run": 16, "desc": "Keep 2,000 dice unrerolled.", "cond": {"stat": "kept", "min": 2000},
		"unlocks": [["pets", "crystal_wisp"]]},
	{"id": "throne_breaker", "run": 17, "desc": "Win at the Bone Throne 5 times.", "cond": {"stat": "throne_wins", "min": 5},
		"unlocks": [["bosses", "boss_bone_warden"], ["minibosses", "mini_bone_champion"]]},
	{"id": "stonewall", "run": 19, "desc": "Gain 2,800 Block.", "cond": {"stat": "block", "min": 2800},
		"unlocks": [["pets", "guard_die"], ["potions", "cleanse"]]},
	{"id": "banker", "run": 18, "desc": "Cash out the Treasury 40 times.", "cond": {"stat": "cashouts", "min": 40},
		"unlocks": [["pets", "coin_mimic"]]},
	{"id": "warden_slayer", "run": 22, "desc": "Defeat 13 mini-bosses.", "cond": {"stat": "minibosses_killed", "min": 13},
		"unlocks": [["minibosses", "mini_frost_warden"], ["minibosses", "mini_briar_beast"], ["minibosses", "mini_cinder_brute"],
			["minibosses", "mini_moonfang"], ["minibosses", "mini_orc_warchief"]]},
	{"id": "archmage", "run": 20, "desc": "Win 3 runs with the Mage.", "cond": {"stat": "mage_wins", "min": 3},
		"unlocks": [["packs", "pyromancy"]]},
	{"id": "rune_lord", "run": 24, "desc": "In 15 runs, fight with 5 dice that all carry runes.", "cond": {"stat": "full_runes", "min": 15},
		"unlocks": [["packs", "resonance"]]},
]

static func milestone(id: String) -> Dictionary:
	for m in MILESTONES:
		if m.id == id:
			return m
	return {}

# ------------------------------------------------------------------ Crowns upgrades

## Bought with Camp.buy_upgrade(track, id). `requires` names a feature unlock (milestone).
const UPGRADES := {
	"workshop": {
		"whetstone": {"name": "Whetstone", "desc": "Start every run with 1 Face Raise.", "cost": {"crowns": 220}},
		"starter_kit": {"name": "Starter Kit", "desc": "Choose the kind of your second starting die: a sidegrade (Standard, Low, Odd).", "cost": {"crowns": 40}},
	},
	"armory": {
		"potion_belt": {"name": "Third Potion Slot", "desc": "The potion belt holds 3.", "cost": {"crowns": 150}, "requires": "potion_belt"},
	},
	"arcade": {
		"loadout_slot": {"name": "Third Minigame Slot", "desc": "Equip 3 minigames per run.", "cost": {"crowns": 200}, "requires": "loadout_slot"},
	},
}

## Starter Kit kinds: sidegrades only, never strictly better than a Standard die (2026-09-28:
## Loaded/Even as a starting die was worth about +5 pp).
const STARTER_KINDS := ["standard", "low", "odd"]

static func starter_kinds(pool: Array) -> Array:
	var out: Array = []
	for k in STARTER_KINDS:
		if pool.has(k) or k == "standard":
			out.append(k)
	return out

static func upgrade_def(track: String, id: String) -> Dictionary:
	return (UPGRADES.get(track, {}) as Dictionary).get(id, {})

# ------------------------------------------------------------------ ascension

const MAX_ASCENSION := 10

## Global ladder; level n includes every rule of levels 1..n. One system per level.
const ASCENSION := [
	{"level": 1, "key": "extra_elite", "desc": "Lap mutations spawn +1 Elite; elites have +15% HP."},
	{"level": 2, "key": "lap_heal", "desc": "Lap heal 10% -> 8%."},
	{"level": 3, "key": "shop_tax", "desc": "Shops cost +10%; restocks cost 12."},
	{"level": 4, "key": "miniboss_trait", "desc": "The mini-boss gains a trait; skipping it gives the final boss +10% HP."},
	{"level": 5, "key": "potions", "desc": "Start with 0 potions."},
	{"level": 6, "key": "enemy_stats", "desc": "Enemies (not bosses) have +4% HP and attack."},
	{"level": 7, "key": "biome_curse", "desc": "Each new biome curses one die face to 1 until you visit a Forge."},
	{"level": 8, "key": "hazards", "desc": "Traps, ice and lava hurt x1.5; +1 hazard tile per board."},
	{"level": 9, "key": "boss_phase", "desc": "The final boss starts with its phase-2 traits and +5% HP."},
	{"level": 10, "key": "double_boss", "desc": "Double final: then face the route's other final boss at 40% HP."},
]

const ASC_LAP_HEAL := 0.08
const ASC_SHOP_TAX := 1.1
const ASC_RESTOCK := 12
const ASC_SKIP_MINIBOSS_BOSS_HP := 1.10
## Potion heal at A5+ (2026-09-28: A5 only removes the starting potion; heal stays 30%).
const ASC_POTION_HEAL := 0.30
const ASC_ENEMY_STATS := 1.04
const ASC_ELITE_HP := 1.15
const ASC_HAZARD_MULT := 1.5
const ASC_BOSS_HP := 1.05
const ASC_SECOND_BOSS_HP := 0.4
## A4 mini-boss trait by the route's mini-boss biome.
const ASC_MINIBOSS_TRAIT := {"hollow": "thorns", "frost": "armor", "throne": "thorns", "magma": "armor", "glade": "armor", "crypt": "thorns"}

## The rule keys active at ascension n.
static func ascension_keys(n: int) -> Array:
	var out: Array = []
	for k in clampi(n, 0, MAX_ASCENSION):
		out.append(String(ASCENSION[k].key))
	return out

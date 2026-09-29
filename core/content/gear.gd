class_name GearDefs
extends RefCounted
## Armory gear (review §5.1). Four pieces, each unlocked by a milestone and levelled 1..8 with
## Crowns (COSTS[level] buys level+1; level 0 = unlocked but not crafted, the first purchase
## crafts it). Stats stay small, with hard caps; the depth is in one binary TRAIT choice at L4
## and one at L8 per piece, freely switchable at Camp.
##   helm   +1 max HP per level (cap +8)
##   blade  +0.125 ATK per level (cap +1)
##   boots  L1: +1 board reroll per biome. L2+: trap and lava damage -5% per level above 1
##   charm  +2% gold per level (cap +15%) on fight, chest and minigame gold

const MAX_LEVEL := 8
const SLOTS := ["helm", "blade", "boots", "charm"]
const COSTS := [10, 20, 30, 45, 60, 75, 80, 90]

const HP_PER_LEVEL := 1.0
const HP_CAP := 8
const ATK_PER_LEVEL := 0.125
const ATK_CAP := 1
const BOOTS_HAZARD_PER_LEVEL := 0.05
const GOLD_PER_LEVEL := 0.02
const GOLD_CAP := 0.15

const DEFS := {
	"helm": {"name": "Helm", "desc": "+1 max HP per level (max +8)."},
	"blade": {"name": "Blade", "desc": "+1 ATK at level 8."},
	"boots": {"name": "Boots", "desc": "+1 board reroll per biome. Traps and lava hurt 5% less per level above 1."},
	"charm": {"name": "Charm", "desc": "+2% gold per level (max +15%)."},
}

## Trait choices: TRAITS[slot][tier] = [option a, option b]; tier "4" unlocks at L4, "8" at L8.
const TRAITS := {
	"helm": {
		"4": ["helm_lap_heal", "helm_campfire"],
		"8": ["helm_last_stand", "helm_bulwark"],
	},
	"blade": {
		"4": ["blade_pair", "blade_high"],
		"8": ["blade_boss_opener", "blade_overflow"],
	},
	"boots": {
		"4": ["boots_portal", "boots_sure_foot"],
		"8": ["boots_pair_pick", "boots_treasury_step"],
	},
	"charm": {
		"4": ["charm_cheap_restock", "charm_free_restock"],
		"8": ["charm_shop_potion", "charm_treasury"],
	},
}

const TRAIT_DEFS := {
	"helm_lap_heal": {"name": "Hearty", "desc": "Lap heal +1%."},
	"helm_campfire": {"name": "Camper", "desc": "Campfires heal +10%."},
	"helm_last_stand": {"name": "Last Stand", "desc": "Once per run, a lethal hit leaves you at 1 HP if you were above 50% HP."},
	"helm_bulwark": {"name": "Bulwark", "desc": "Block 4 on turn 1 of every fight."},
	"blade_pair": {"name": "Twin Edge", "desc": "+2 damage on a Pair."},
	"blade_high": {"name": "Long Edge", "desc": "+3 damage on High Roller."},
	"blade_boss_opener": {"name": "Opener", "desc": "Your first attack against the final boss deals x1.3."},
	"blade_overflow": {"name": "Cleave", "desc": "A kill carries 50% of the excess damage to the next enemy."},
	"boots_portal": {"name": "Long Stride", "desc": "Portal range +2."},
	"boots_sure_foot": {"name": "Sure Foot", "desc": "Traps and ice: dodge on 3+."},
	"boots_pair_pick": {"name": "Pathfinder's Eye", "desc": "When values tie for the move, the higher value moves."},
	"boots_treasury_step": {"name": "Tithe", "desc": "Passing the Treasury banks +5."},
	"charm_cheap_restock": {"name": "Haggle", "desc": "Shop restocks cost 5 gold."},
	"charm_free_restock": {"name": "Regular", "desc": "One free restock per shop."},
	"charm_shop_potion": {"name": "Apothecary", "desc": "Every shop offers a potion."},
	"charm_treasury": {"name": "Interest", "desc": "Treasury cash-outs x1.25."},
}

const TRAIT_BONUS := {
	"helm_lap_heal": 0.01, "helm_campfire": 0.10, "helm_bulwark": 4, "blade_pair": 2, "blade_high": 3,
	"blade_boss_opener": 1.3, "blade_overflow": 0.5, "boots_portal": 2, "boots_sure_foot": 3,
	"boots_treasury_step": 5, "charm_cheap_restock": 5, "charm_treasury": 1.25,
}

## Crowns to go from `level` to level + 1; {} at max.
static func cost(slot: String, level: int) -> Dictionary:
	if not DEFS.has(slot) or level < 0 or level >= MAX_LEVEL:
		return {}
	return {"crowns": int(COSTS[level])}

## Stat bonuses for a {slot: level} map: {max_hp, atk, lap_rerolls, hazard_mult, gold_pct}.
static func stats(levels: Dictionary) -> Dictionary:
	var helm := int(levels.get("helm", 0))
	var blade := int(levels.get("blade", 0))
	var boots := int(levels.get("boots", 0))
	var charm := int(levels.get("charm", 0))
	return {
		"max_hp": mini(HP_CAP, int(floor(HP_PER_LEVEL * helm))),
		"atk": mini(ATK_CAP, int(floor(ATK_PER_LEVEL * blade))),
		"lap_rerolls": 1 if boots >= 1 else 0,
		"hazard_mult": 1.0 - BOOTS_HAZARD_PER_LEVEL * maxi(0, boots - 1),
		"gold_pct": minf(GOLD_CAP, GOLD_PER_LEVEL * charm),
	}

## Traits a piece at `level` may use for `tier` ("4" | "8").
static func trait_options(slot: String, tier: String) -> Array:
	return (TRAITS.get(slot, {}) as Dictionary).get(tier, [])

static func name_of(slot: String) -> String:
	return String(DEFS[slot].name) if DEFS.has(slot) else ""

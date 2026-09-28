class_name EnemyDefs
extends RefCounted
## Enemies and bosses. Ids are stable strings used by the presentation layer.
## Intent kinds: attack, block, buff, curse, summon, chaos, aim (does nothing; archer reload).
## mode "random": each turn picks a random pattern entry. mode "cycle": walks the pattern
## from a random starting offset.

const ENEMIES := {
	"skeleton_minion": {"name": "Skeleton Minion", "hp": 12, "gold": 4, "xp": 3, "mode": "random",
		"pattern": [{"kind": "attack", "value": 4}, {"kind": "attack", "value": 5}]},
	"skeleton_warrior": {"name": "Skeleton Warrior", "hp": 20, "gold": 6, "xp": 5, "mode": "random",
		"pattern": [{"kind": "attack", "value": 6}, {"kind": "block", "value": 6}]},
	"skeleton_archer": {"name": "Skeleton Archer", "hp": 14, "gold": 5, "xp": 4, "mode": "cycle",
		"pattern": [{"kind": "aim", "value": 0}, {"kind": "attack", "value": 8}]},
	"cultist": {"name": "Cultist", "hp": 16, "gold": 6, "xp": 5, "mode": "cycle",
		"pattern": [{"kind": "curse", "value": 1}, {"kind": "attack", "value": 5}]},
	"bandit": {"name": "Bandit", "hp": 18, "gold": 8, "xp": 5, "mode": "cycle",
		"pattern": [{"kind": "attack", "value": 7}, {"kind": "buff", "value": 2}]},
	"brute": {"name": "Brute", "hp": 38, "gold": 12, "xp": 9, "mode": "cycle",
		"pattern": [{"kind": "block", "value": 8}, {"kind": "attack", "value": 12}]},
}

## Bosses have two phases; phase 2 starts at or below half HP. Boss numbers are not scaled.
const BOSSES := {
	"boss_bone_warden": {"name": "Bone Warden", "hp": 200, "gold": 40, "xp": 20, "phases": [
		[{"kind": "attack", "value": 10}, {"kind": "block", "value": 12}, {"kind": "summon", "value": 1}],
		[{"kind": "attack", "value": 12}, {"kind": "summon", "value": 1}, {"kind": "attack", "value": 10}, {"kind": "block", "value": 12}],
	]},
	"boss_hollow_king": {"name": "Hollow King", "hp": 380, "gold": 60, "xp": 30, "phases": [
		[{"kind": "attack", "value": 18}, {"kind": "curse", "value": 2}, {"kind": "buff", "value": 3}],
		[{"kind": "attack", "value": 18}, {"kind": "attack", "value": 20}, {"kind": "curse", "value": 2}, {"kind": "buff", "value": 3}],
	]},
	"boss_lich": {"name": "The Lich", "hp": 1300, "gold": 0, "xp": 0, "phases": [
		[{"kind": "attack", "value": 22}, {"kind": "curse", "value": 1}, {"kind": "block", "value": 30}],
		[{"kind": "attack", "value": 26}, {"kind": "chaos", "value": 1}, {"kind": "attack", "value": 22}, {"kind": "curse", "value": 1}],
	]},
}

## Mini-bosses: one per act, spawned on a `miniboss` tile after lap 1 (optional fight).
## Scaled like regular enemies (act/lap), single phase, not "boss" (no phases, not unscaled).
## Reward: gold + XP + a choice of 1 of 3 boss-tier passives.
const MINIBOSSES := {
	"mini_bone_champion": {"name": "Bone Champion", "hp": 110, "gold": 25, "xp": 12, "mode": "cycle",
		"pattern": [{"kind": "attack", "value": 9}, {"kind": "block", "value": 10}, {"kind": "attack", "value": 12}]},
	"mini_pumpkin_knight": {"name": "Pumpkin Knight", "hp": 105, "gold": 30, "xp": 15, "mode": "cycle",
		"pattern": [{"kind": "curse", "value": 1}, {"kind": "attack", "value": 9}, {"kind": "attack", "value": 11}, {"kind": "buff", "value": 2}]},
	"mini_grave_mage": {"name": "Grave Mage", "hp": 100, "gold": 35, "xp": 18, "mode": "cycle",
		"pattern": [{"kind": "summon", "value": 1}, {"kind": "attack", "value": 10}, {"kind": "chaos", "value": 1}, {"kind": "attack", "value": 12}]},
}

const ACT_MINIBOSS := ["mini_bone_champion", "mini_pumpkin_knight", "mini_grave_mage"]
## Act bosses (content kept; the run flow now only fights FINAL_BOSS after the last lap).
const ACT_BOSS := ["boss_bone_warden", "boss_hollow_king", "boss_lich"]
const FINAL_BOSS := "boss_lich"
const ACT_BIOME := ["crypt", "hollow", "throne"]
const SUMMON_ID := "skeleton_minion"

## Enemy pools per difficulty band (band = (lap - 1) / 3, 0..4 over laps 1..15).
const POOLS := [
	["skeleton_minion", "skeleton_minion", "skeleton_archer"],
	["skeleton_minion", "skeleton_archer", "skeleton_warrior", "cultist"],
	["skeleton_archer", "skeleton_warrior", "cultist", "bandit"],
	["skeleton_warrior", "cultist", "bandit", "brute"],
	["skeleton_warrior", "bandit", "brute", "cultist"],
]
## [min, max] enemies per tile for each band.
const COUNTS := [[2, 2], [2, 2], [2, 3], [2, 3], [2, 3]]

static func band(lap: int) -> int:
	return clampi((lap - 1) / 3, 0, POOLS.size() - 1)

static func is_boss(id: String) -> bool:
	return BOSSES.has(id)

static func is_miniboss(id: String) -> bool:
	return MINIBOSSES.has(id)

static func def(id: String) -> Dictionary:
	if BOSSES.has(id):
		return BOSSES[id]
	if MINIBOSSES.has(id):
		return MINIBOSSES[id]
	return ENEMIES[id]

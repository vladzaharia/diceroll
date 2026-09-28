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
	"boss_hollow_king": {"name": "Hollow King", "hp": 450, "gold": 60, "xp": 30, "phases": [
		[{"kind": "attack", "value": 18}, {"kind": "curse", "value": 2}, {"kind": "buff", "value": 3}],
		[{"kind": "attack", "value": 18}, {"kind": "attack", "value": 20}, {"kind": "curse", "value": 2}, {"kind": "buff", "value": 3}],
	]},
	"boss_lich": {"name": "The Lich", "hp": 800, "gold": 0, "xp": 0, "phases": [
		[{"kind": "attack", "value": 22}, {"kind": "curse", "value": 1}, {"kind": "block", "value": 30}],
		[{"kind": "attack", "value": 26}, {"kind": "chaos", "value": 1}, {"kind": "attack", "value": 22}, {"kind": "curse", "value": 1}],
	]},
}

const ACT_BOSS := ["boss_bone_warden", "boss_hollow_king", "boss_lich"]
const ACT_BIOME := ["crypt", "hollow", "throne"]
const SUMMON_ID := "skeleton_minion"

## Enemy pools per difficulty band (band = act + lap - 2, 0..4).
const POOLS := [
	["skeleton_minion", "skeleton_minion", "skeleton_archer"],
	["skeleton_minion", "skeleton_archer", "skeleton_warrior", "cultist"],
	["skeleton_archer", "skeleton_warrior", "cultist", "bandit"],
	["skeleton_warrior", "cultist", "bandit", "brute"],
	["skeleton_warrior", "bandit", "brute", "cultist"],
]
## [min, max] enemies per tile for each band.
const COUNTS := [[1, 2], [2, 2], [2, 3], [2, 3], [2, 3]]

static func band(act: int, lap: int) -> int:
	return clampi(act + lap - 2, 0, POOLS.size() - 1)

static func is_boss(id: String) -> bool:
	return BOSSES.has(id)

static func def(id: String) -> Dictionary:
	if BOSSES.has(id):
		return BOSSES[id]
	return ENEMIES[id]

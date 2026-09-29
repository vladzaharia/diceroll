class_name EnemyDefs
extends RefCounted
## Enemies and bosses. Ids are stable strings used by the presentation layer.
## Intent kinds: attack, block, buff, curse, summon, chaos, aim (does nothing; archer reload),
## plus (biomes) heal (all living allies), drain (attack; heals self by the damage dealt),
## burn (adds Burn stacks to the hero), chill (attack + locks 1 die next turn) and scorch
## (turns one of the hero's faces to 0 for the fight).
## mode "random": each turn picks a random pattern entry. mode "cycle": walks the pattern
## from a random starting offset.
## traits (optional): "armor" (its Block never expires), "thorns" (reflects ENEMY_THORNS to
## the hero when hit by the main attack, never lethal), "ward" (takes half damage while any
## summoned ally lives), "pierce" (its attacks ignore Block), "frenzy" (+FRENZY_STEP attack for
## the fight after surviving a hit from the main attack, max +FRENZY_MAX), "ward_allies" (the
## Warded affix: half damage while any other non-warded enemy lives). Bosses set traits per phase.
## rally intent: every living enemy (the caster included) gains +value attack for the fight.
## transform: a regular/mini-boss with `phases: [p1, p2]` (and `forms` names) switches pattern once
## at <= 50% HP, dropping its Block (enemy_transformed {enemy_idx, form}).

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
	# --- biome variants
	"thorn_sprite": {"name": "Thorn Sprite", "hp": 10, "gold": 4, "xp": 3, "mode": "cycle",
		"pattern": [{"kind": "heal", "value": 4}, {"kind": "attack", "value": 4}]},
	"wolf_bandit": {"name": "Wolf Bandit", "hp": 15, "gold": 6, "xp": 4, "mode": "cycle",
		"pattern": [{"kind": "attack", "value": 3}, {"kind": "attack", "value": 4}, {"kind": "attack", "value": 9}]},
	"hollow_wisp": {"name": "Hollow Wisp", "hp": 12, "gold": 5, "xp": 4, "mode": "cycle",
		"pattern": [{"kind": "drain", "value": 5}, {"kind": "block", "value": 4}]},
	"frost_skeleton": {"name": "Frost Skeleton", "hp": 18, "gold": 6, "xp": 5, "mode": "cycle",
		"pattern": [{"kind": "curse", "value": 2}, {"kind": "attack", "value": 6}, {"kind": "block", "value": 5}]},
	"ice_archer": {"name": "Ice Archer", "hp": 13, "gold": 5, "xp": 4, "mode": "cycle",
		"pattern": [{"kind": "aim", "value": 0}, {"kind": "chill", "value": 7}]},
	"bone_knight": {"name": "Bone Knight", "hp": 34, "gold": 9, "xp": 7, "mode": "cycle", "traits": ["armor"],
		"pattern": [{"kind": "block", "value": 6}, {"kind": "attack", "value": 10}, {"kind": "buff", "value": 2}]},
	"ember_imp": {"name": "Ember Imp", "hp": 11, "gold": 5, "xp": 4, "mode": "random",
		"pattern": [{"kind": "burn", "value": 2}, {"kind": "attack", "value": 5}]},
	"magma_brute": {"name": "Magma Brute", "hp": 36, "gold": 12, "xp": 9, "mode": "cycle",
		"pattern": [{"kind": "burn", "value": 2}, {"kind": "block", "value": 8}, {"kind": "attack", "value": 12}]},
	# --- 2026-09-28 roster (docs/design/2026-09-28-classes-enemies-skins.md §3)
	"bone_cutthroat": {"name": "Bone Cutthroat", "hp": 13, "gold": 5, "xp": 4, "mode": "cycle", "traits": ["pierce"],
		"pattern": [{"kind": "attack", "value": 4}, {"kind": "attack", "value": 4}, {"kind": "block", "value": 3}]},
	"bone_golem": {"name": "Bone Golem", "hp": 44, "gold": 13, "xp": 10, "mode": "cycle",
		"pattern": [{"kind": "block", "value": 10}, {"kind": "aim", "value": 0}, {"kind": "attack", "value": 16}]},
	"orc_raider": {"name": "Orc Raider", "hp": 22, "gold": 7, "xp": 5, "mode": "cycle", "traits": ["frenzy"],
		"pattern": [{"kind": "attack", "value": 5}, {"kind": "attack", "value": 7}]},
	"orc_drummer": {"name": "Orc Drummer", "hp": 20, "gold": 7, "xp": 5, "mode": "cycle",
		"pattern": [{"kind": "rally", "value": 2}, {"kind": "block", "value": 5}, {"kind": "attack", "value": 4}]},
	# transform: phases [man, wolf]; the switch happens once at <= 50% HP (forms names the phases)
	"werewolf": {"name": "Werewolf", "hp": 26, "gold": 8, "xp": 6, "mode": "cycle", "forms": ["man", "wolf"],
		"pattern": [{"kind": "block", "value": 5}, {"kind": "attack", "value": 6}],
		"phases": [[{"kind": "block", "value": 5}, {"kind": "attack", "value": 6}],
			[{"kind": "attack", "value": 5}, {"kind": "drain", "value": 6}, {"kind": "attack", "value": 9}]]},
	"fallen_paladin": {"name": "Fallen Paladin", "hp": 40, "gold": 12, "xp": 9, "mode": "cycle",
		"pattern": [{"kind": "attack", "value": 9}, {"kind": "heal", "value": 6}, {"kind": "block", "value": 8}]},
}

## Bosses have two phases; phase 2 starts at or below half HP. Boss numbers are not scaled.
## traits: per-phase trait lists. summon: id of summoned allies (default SUMMON_ID; an explicit
## id is scaled to the fight's lap).
const BOSSES := {
	"boss_hollow_king": {"name": "Hollow King", "hp": 380, "gold": 60, "xp": 30, "phases": [
		[{"kind": "attack", "value": 18}, {"kind": "curse", "value": 2}, {"kind": "buff", "value": 3}],
		[{"kind": "attack", "value": 18}, {"kind": "attack", "value": 20}, {"kind": "curse", "value": 2}, {"kind": "buff", "value": 3}],
	]},
	"boss_lich": {"name": "The Lich", "hp": 1650, "gold": 0, "xp": 0, "phases": [
		[{"kind": "attack", "value": 22}, {"kind": "curse", "value": 1}, {"kind": "block", "value": 30}],
		[{"kind": "attack", "value": 26}, {"kind": "chaos", "value": 1}, {"kind": "attack", "value": 22}, {"kind": "curse", "value": 1}],
	]},
	# Final-boss rotation (lap 15). The Bone Warden doubles as the Bone Throne's alternate boss:
	# phase 2 raises a bone legion that wards it (half damage while any minion stands).
	"boss_bone_warden": {"name": "Bone Warden", "hp": 1150, "gold": 0, "xp": 0, "summon": "skeleton_warrior",
		"traits": [[], ["ward"]], "phases": [
		[{"kind": "attack", "value": 20}, {"kind": "block", "value": 28}, {"kind": "summon", "value": 1}],
		[{"kind": "summon", "value": 2}, {"kind": "attack", "value": 24}, {"kind": "attack", "value": 20}, {"kind": "block", "value": 24}],
	]},
	# Magma Depths: burns you; phase 2 scorches a face of your dice to 0 (blank) for the fight.
	"boss_cinder_king": {"name": "Cinder King", "hp": 1200, "gold": 0, "xp": 0, "phases": [
		[{"kind": "burn", "value": 4}, {"kind": "attack", "value": 20}, {"kind": "block", "value": 24}],
		[{"kind": "scorch", "value": 1}, {"kind": "attack", "value": 24}, {"kind": "burn", "value": 5}, {"kind": "attack", "value": 20}],
	]},
	# Magma Depths: a molten shell (Block never expires) in phase 1; in phase 2 the shell shatters
	# (its Block is lost when phase 2 starts) and its attacks pierce your Block.
	"boss_magma_golem": {"name": "Magma Golem", "hp": 800, "gold": 0, "xp": 0,
		"traits": [["armor"], ["pierce"]], "phases": [
		[{"kind": "block", "value": 32}, {"kind": "attack", "value": 22}, {"kind": "attack", "value": 26}],
		[{"kind": "attack", "value": 24}, {"kind": "attack", "value": 28}, {"kind": "buff", "value": 3}],
	]},
}

## Mini-bosses: one per run, drawn from the tier-2 biome's candidates (BiomeDefs) and spawned
## on a `miniboss` tile when lap 7 starts (optional fight).
## Scaled like regular enemies (act/lap), single phase, not "boss" (no phases, not unscaled).
## Reward: gold + XP + a choice of 1 of 3 boss-tier passives.
const MINIBOSSES := {
	"mini_bone_champion": {"name": "Bone Champion", "hp": 110, "gold": 25, "xp": 12, "mode": "cycle", "traits": ["armor"],
		"pattern": [{"kind": "attack", "value": 9}, {"kind": "block", "value": 10}, {"kind": "attack", "value": 12}]},
	"mini_pumpkin_knight": {"name": "Pumpkin Knight", "hp": 105, "gold": 30, "xp": 15, "mode": "cycle",
		"pattern": [{"kind": "curse", "value": 1}, {"kind": "attack", "value": 9}, {"kind": "attack", "value": 11}, {"kind": "buff", "value": 2}]},
	"mini_grave_mage": {"name": "Grave Mage", "hp": 100, "gold": 35, "xp": 18, "mode": "cycle",
		"pattern": [{"kind": "summon", "value": 1}, {"kind": "attack", "value": 10}, {"kind": "chaos", "value": 1}, {"kind": "attack", "value": 12}]},
	"mini_frost_warden": {"name": "Frost Warden", "hp": 105, "gold": 30, "xp": 15, "mode": "cycle",
		"pattern": [{"kind": "chill", "value": 8}, {"kind": "curse", "value": 2}, {"kind": "attack", "value": 11}, {"kind": "block", "value": 8}]},
	"mini_briar_beast": {"name": "Briar Beast", "hp": 110, "gold": 30, "xp": 15, "mode": "cycle", "traits": ["thorns"],
		"pattern": [{"kind": "attack", "value": 8}, {"kind": "heal", "value": 10}, {"kind": "attack", "value": 10}]},
	"mini_cinder_brute": {"name": "Cinder Brute", "hp": 110, "gold": 30, "xp": 15, "mode": "cycle",
		"pattern": [{"kind": "burn", "value": 3}, {"kind": "attack", "value": 11}, {"kind": "block", "value": 10}]},
	"mini_moonfang": {"name": "Moonfang", "hp": 105, "gold": 30, "xp": 15, "mode": "cycle", "forms": ["man", "wolf"],
		"pattern": [{"kind": "block", "value": 10}, {"kind": "attack", "value": 9}, {"kind": "curse", "value": 1}],
		"phases": [[{"kind": "block", "value": 10}, {"kind": "attack", "value": 9}, {"kind": "curse", "value": 1}],
			[{"kind": "attack", "value": 8}, {"kind": "drain", "value": 10}, {"kind": "attack", "value": 12}]]},
	"mini_orc_warchief": {"name": "Orc Warchief", "hp": 100, "gold": 30, "xp": 15, "mode": "cycle", "summon": "orc_raider",
		"pattern": [{"kind": "summon", "value": 1}, {"kind": "rally", "value": 3}, {"kind": "attack", "value": 11}, {"kind": "block", "value": 8}]},
}

## Legacy per-act defaults (old saves, scenarios). The run uses RunState.miniboss_id.
const ACT_MINIBOSS := ["mini_bone_champion", "mini_pumpkin_knight", "mini_grave_mage"]
## Legacy act bosses. boss_hollow_king is unused (content kept); the run's final boss is
## RunState.boss_id, drawn from the tier-3 biome's candidates.
const ACT_BOSS := ["boss_bone_warden", "boss_hollow_king", "boss_lich"]
## Legacy default final boss (old saves). The run uses RunState.boss_id.
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

## Frenzy trait: attack gained per main-attack hit survived, and its cap.
const FRENZY_STEP := 2
const FRENZY_MAX := 6

## Intent pattern of a non-boss enemy in `phase` (1-based): transforming enemies (a "phases"
## entry) switch to phases[1] once at <= 50% HP.
static func pattern(id: String, phase := 1) -> Array:
	var d := def(id)
	if d.has("phases") and not BOSSES.has(id):
		var ph: Array = d.phases
		return ph[clampi(phase - 1, 0, ph.size() - 1)]
	return d.pattern

## True for regular enemies and mini-bosses that transform (Werewolf, Moonfang).
static func transforms(id: String) -> bool:
	return not BOSSES.has(id) and def(id).has("phases")

## Form name for `phase` ("" when the enemy has no forms).
static func form(id: String, phase: int) -> String:
	var f: Array = def(id).get("forms", [])
	return String(f[phase - 1]) if phase - 1 < f.size() and phase >= 1 else ""

static func band(lap: int) -> int:
	return clampi((lap - 1) / 3, 0, POOLS.size() - 1)

## Traits of a regular enemy / mini-boss, or of a boss in `phase` (1-based).
static func traits(id: String, phase := 1) -> Array:
	var d := def(id)
	if BOSSES.has(id):
		var t: Array = d.get("traits", [])
		return t[phase - 1] if phase - 1 < t.size() else []
	return d.get("traits", [])

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

class_name Balance
extends RefCounted
## Tunable numbers. See docs/plans/balance.md for the sim results behind them.

## Default ring size: 28 = 8x8 perimeter (24 = 7x7 and 32 = 9x9 also supported).
## GameFlow.new_run takes a size override.
const BOARD_SIZE := 28

# Run structure: one continuous board, TOTAL_LAPS laps ("floors"). The biome ("act") changes
# when lap BIOME_LAPS[k] starts; completing the last lap stops on Start for the final boss.
const TOTAL_LAPS := 15
## First lap of each act/biome (act 1 starts at lap 1).
const BIOME_LAPS := [1, 6, 11]
## Laps per biome (presentation: lap pips per act).
const LAPS_PER_ACT := 5
const ACTS := 3
## The shop opens after completing these laps (2026-09-28 rebalance: shops are the main upgrade
## source now that kills give no drafts): after lap 1, then every 2 laps, plus every biome change.
const SHOP_LAPS := [1, 3, 5, 6, 8, 10, 12, 14]
## Short Road (10 laps, biome change at 6).
const SHOP_LAPS_SHORT := [1, 3, 5, 7, 9]
## The mini-boss appears when this lap starts and is gone when the next biome starts.
const MINIBOSS_LAP := 7
const BIOME_HEAL_PCT := 0.30
const MAX_DICE := 5
const START_DICE := 2

# Tiles
const LAP_HEAL_PCT := 0.10
const CAMPFIRE_HEAL_PCT := 0.30
const TRAP_DAMAGE_PCT := 0.12
const TRAP_DODGE_MIN := 4
const TREASURY_START := 10
const TREASURY_PAIR_MULT := 2
const CHEST_GOLD_MIN := 12
const CHEST_GOLD_MAX := 24
const CHEST_RUNE_CHANCE := 0.5

# Combat
const COMBAT_REROLLS := 2
const MAX_COMBAT_REROLLS := 4
const MAX_BANKED_REROLLS := 2
const BUFF_AMOUNT := 2
const MAX_SUMMONED_ALIVE := 3
## Burn intent stacks scale at this fraction of the attack scaling (stacks decay by 1 per tick).
const BURN_SCALE := 0.5
## Damage a Thorns enemy (Briar Beast) reflects when hit by your attack (never lethal).
const ENEMY_THORNS := 3
## Anti-stacking (2026-09-28 balance pass): each rune's effect applies to at most
## RUNE_STACK_MAX dice per attack (the first ones in pool order whose trigger fires; for combo
## runes, dice in the scoring group). Extra copies do nothing, so offers skip a rune the pool
## already holds RUNE_STACK_MAX times. Wild is capped at WILD_MAX_DICE, and Heavy doubles pips
## only for dice in the scoring group (HEAVY_MAX == RUNE_STACK_MAX).
const RUNE_STACK_MAX := 2
const WILD_MAX_DICE := 1
const HEAVY_MAX := 2

## Cap on copies of `rune` that act in one attack.
static func rune_cap(rune: String) -> int:
	return WILD_MAX_DICE if rune == "wild" else RUNE_STACK_MAX

# Biome twists (core/content/biomes.gd)
const GLADE_CAMPFIRE_HEAL_PCT := 0.45
const CRYPT_DODGE_GOLD := 6
const HOLLOW_EVENT_HEAL_PCT := 0.08
## Frostpeak ice tile: fail the dodge roll and this many dice lock on turn 1 of the next fight.
const ICE_CHILL := 1
const ICE_CHILL_MAX := 2
const THRONE_ELITE_BOSS_PASSIVE_CHANCE := 0.30
## Magma Depths lava tile: % max HP when passed over / landed on. Lava never kills (min 1 HP).
const LAVA_PASS_PCT := 0.02
const LAVA_LAND_PCT := 0.06

# Enemy scaling by lap (1..15): HP x (ENEMY_BASE_SCALE + ENEMY_LAP_STEP*(lap-1)), attack x
# (ENEMY_BASE_SCALE + ENEMY_ATK_LAP_STEP*(lap-1)). 2026-09-28 rebalance: a gentle start (no
# drafts, 2 dice), HP growing faster than attack late (long fights, fewer one-shots).
const ENEMY_BASE_SCALE := 1.0
const ENEMY_LAP_STEP := 0.35
const ENEMY_ATK_LAP_STEP := 0.125
const ELITE_HP_MULT := 1.3
const ELITE_ATK_MULT := 1.15
const ELITE_REWARD_MULT := 1.5
## Regular enemy and chest gold: x(1 + GOLD_LAP_STEP*(lap-1)).
const GOLD_LAP_STEP := 0.05
## Chance an elite's passive reward is a boss-tier choice instead of a regular one.
const ELITE_BOSS_PASSIVE_CHANCE := 0.15

# Progression. Levels are automatic and slow (about 5-7 per full run): each gives
# LEVEL_MAX_HP max HP and heals LEVEL_MAX_HP + LEVEL_HEAL_PCT of max HP. No drafts from kills:
# upgrades come from shops, events, chests, minigames, elites and the mini-boss.
const LEVEL_MAX_HP := 4
const LEVEL_HEAL_PCT := 0.10
## Legacy level-up draft option (debug scenarios only).
const DRAFT_MAX_HP := 8
const XP_THRESHOLDS := [25, 55, 90, 130, 175, 225]
const XP_STEP_AFTER := 60

# Shop
## Dice prices live in DiceKinds.DEFS[kind].price.
const SHOP_MAX_DICE_ITEMS := 2
const SHOP_POTION_PRICE := 20
const SHOP_POTION_PCT := 0.35
const SHOP_FACE_RAISE_PRICE := 25
const SHOP_REROLL_ITEM_PRICE := 90
const SHOP_RESTOCK_PRICE := 10
const SHOP_MIN_ITEMS := 3
const SHOP_MAX_ITEMS := 4
const RUNE_PRICE := {"common": 35, "rare": 50, "epic": 70}

# Passives (see core/content/passives.gd)
const PASSIVE_PRICE := {"common": 60, "uncommon": 80, "rare": 110}
const PASSIVE_PAIR_BONUS := 0.5
const PASSIVE_SET_BONUS := 1.0
const PASSIVE_FULL_HOUSE_HEAL := 8
const PASSIVE_STRAIGHT_DAMAGE := 8
const PASSIVE_SNAKE_EYES := 5
const PASSIVE_BOXCARS := 3
const PASSIVE_RUNE_ECHO_CHANCE := 0.25
const PASSIVE_COLLECTOR_HP := 5
const PASSIVE_TREASURE_MULT := 1.5
const PASSIVE_PIGGY_PCT := 0.10
const PASSIVE_PIGGY_MAX := 15
const PASSIVE_HAGGLE := 0.8
const PASSIVE_SCHOLAR := 1.25
const PASSIVE_THORNS := 3
const PASSIVE_IRON_SKIN := 3
const PASSIVE_BLOODTHIRST := 3
const PASSIVE_DAMAGE_MULT := 1.5
## Glass Cannon's damage factor (2026-09-28 nerf from x1.5).
const PASSIVE_GLASS_MULT := 1.3
## Runes that Resonance / Rune Echo never trigger twice (Heavy and Echo stacking nerf).
const NO_DOUBLE_TRIGGER := ["heavy", "echo"]
const PASSIVE_GLASS_HP_PCT := 0.2
const PASSIVE_MIDAS_GOLD := 8
const PASSIVE_MIDAS_MAX := 15

# Events
const IDOL_DAMAGE := 15
const MERCHANT_HP_PCT := 0.10
const SHRINE_ATK := 1
const SHRINE_MAX_HP := 10
const SHRINE_GOLD := 15

## Total XP needed to reach level (level+1) from `level` (level starts at 1).
static func xp_for_level(level: int) -> int:
	if level - 1 < XP_THRESHOLDS.size():
		return XP_THRESHOLDS[level - 1]
	return XP_THRESHOLDS.back() + XP_STEP_AFTER * (level - XP_THRESHOLDS.size())

## Act (biome, 1..3) that lap `lap` (1..TOTAL_LAPS) belongs to.
static func act_for_lap(lap: int) -> int:
	var a := 1
	for k in BIOME_LAPS.size():
		if lap >= int(BIOME_LAPS[k]):
			a = k + 1
	return a

static func is_shop_lap(completed_lap: int) -> bool:
	if tune_shop != "":
		return Array(tune_shop.split(",")).has(str(completed_lap))
	return SHOP_LAPS.has(completed_lap)

## TEMP tuning dials (sim sweeps)
static var tune_hp := 1.0
static var tune_atk := 1.0
static var tune_boss := 1.0
static var tune_base := ENEMY_BASE_SCALE
static var tune_step := ENEMY_LAP_STEP
static var tune_gold := 1.0
static var tune_shop := "" # "" = default cadence; else comma list of completed laps

static var tune_atk_step := ENEMY_ATK_LAP_STEP

## Enemy HP multiplier at `lap`.
static func enemy_scale(lap: int) -> float:
	return tune_base + tune_step * (lap - 1)

## Enemy attack multiplier at `lap` (grows slower than HP late: long fights, fewer one-shots).
static func enemy_atk_scale(lap: int) -> float:
	return tune_base + tune_atk_step * (lap - 1)

static func gold_scale(lap: int) -> float:
	return 1.0 + GOLD_LAP_STEP * (lap - 1)

# Meta layer (§16 + design review). See also core/content/{economy,pets,gear,potions,unlocks,minigames}.gd.
## Potion belt: base size, Camp upgrade maximum, potions at run start, heal per potion.
const POTION_CAP := 2
const POTION_MAX_CAP := 3
const POTION_START := 1
const POTION_HEAL_PCT := 0.30
## Chance a chest also holds a Healing Draught (only in runs with a potion belt).
const CHEST_POTION_CHANCE := 0.2
## One minigame tile per equipped minigame (at most this many), respawned on lap mutation.
const MINIGAME_TILES_MAX := 3

# Short Road mode (opts.mode = "short"): 10 laps, 2 biomes. Laps 1-5 walk the route's tier-1
# biome, laps 6-10 its tier-3 biome. The mini-boss (from the tier-3 biome's list) appears when
# lap 6 starts; the final boss (tier-3 candidates) comes at lap 10. Enemies, pools and gold use
# the "effective lap" SHORT_EFF_LAPS[lap - 1] (the standard-run lap of equal difficulty).
const SHORT_LAPS := 10
const SHORT_BIOME_LAPS := [1, 6]
const SHORT_MINIBOSS_LAP := 6
const SHORT_EFF_LAPS := [1, 2, 3, 4, 5, 8, 9, 10, 11, 12]

## Balance targets for the greedy sim bot (A0, standard mode), used by tools/sim.gd reports.
const TARGET_FRESH := [0.22, 0.30]
const TARGET_MID := 0.33
const TARGET_MAX := [0.45, 0.50]

class_name Balance
extends RefCounted
## Tunable numbers. See docs/plans/balance.md for the sim results behind them.

## Default ring size (24 = 7x7 perimeter, 32 = 9x9). GameFlow.new_run takes a size override.
const BOARD_SIZE := 24
## Laps per act on the default board. Use laps_per_act(size) for other ring sizes.
const LAPS_PER_ACT := 3
const LAPS_BY_SIZE := {24: 3, 32: 3}
const ACTS := 3
const MAX_DICE := 5
const START_DICE := 2

# Tiles
const LAP_HEAL_PCT := 0.15
const CAMPFIRE_HEAL_PCT := 0.30
const TRAP_DAMAGE_PCT := 0.12
const TRAP_DODGE_MIN := 4
const TREASURY_START := 10
const TREASURY_PAIR_MULT := 2
const CHEST_GOLD_MIN := 12
const CHEST_GOLD_MAX := 24
const CHEST_RUNE_CHANCE := 0.5
const ACT_START_HEAL_PCT := 0.5

# Combat
const COMBAT_REROLLS := 2
const MAX_COMBAT_REROLLS := 4
const MAX_BANKED_REROLLS := 2
const BUFF_AMOUNT := 2
const MAX_SUMMONED_ALIVE := 3

# Enemy scaling: mult = 1 + ACT_STEP*(act-1) + LAP_STEP*(lap-1)
const ENEMY_ACT_STEP := 0.8
const ENEMY_LAP_STEP := 0.2
const ELITE_HP_MULT := 1.3
const ELITE_ATK_MULT := 1.15
const ELITE_REWARD_MULT := 1.5
const GOLD_ACT_STEP := 0.25

# Progression
const DRAFT_MAX_HP := 8
const XP_THRESHOLDS := [10, 25, 45, 70, 100]
const XP_STEP_AFTER := 30

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

static func laps_per_act(ring_size: int) -> int:
	return int(LAPS_BY_SIZE.get(ring_size, LAPS_PER_ACT))

static func enemy_scale(act: int, lap: int) -> float:
	return 1.0 + ENEMY_ACT_STEP * (act - 1) + ENEMY_LAP_STEP * (lap - 1)

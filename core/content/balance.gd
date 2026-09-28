class_name Balance
extends RefCounted
## Tunable numbers. See docs/plans/balance.md for the sim results behind them.

const BOARD_SIZE := 24
const LAPS_PER_ACT := 3
const ACTS := 3
const MAX_DICE := 6
const START_DICE := 3

# Tiles
const LAP_HEAL_PCT := 0.15
const CAMPFIRE_HEAL_PCT := 0.30
const TRAP_DAMAGE_PCT := 0.12
const TRAP_DODGE_MIN := 4
const TREASURY_START := 10
const TREASURY_PAIR_MULT := 2
const PORTAL_RANGE := 8
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
const ENEMY_ACT_STEP := 1.0
const ENEMY_LAP_STEP := 0.25
const ELITE_HP_MULT := 1.3
const ELITE_ATK_MULT := 1.15
const ELITE_REWARD_MULT := 1.5
const GOLD_ACT_STEP := 0.25

# Progression
const DRAFT_MAX_HP := 8
const XP_THRESHOLDS := [10, 25, 45, 70, 100]
const XP_STEP_AFTER := 30

# Shop
const SHOP_DIE_PRICE := 40
const SHOP_POTION_PRICE := 20
const SHOP_POTION_PCT := 0.35
const SHOP_FACE_RAISE_PRICE := 25
const SHOP_REROLL_ITEM_PRICE := 90
const SHOP_RESTOCK_PRICE := 10
const SHOP_MIN_ITEMS := 3
const SHOP_MAX_ITEMS := 4
const RUNE_PRICE := {"common": 35, "rare": 50, "epic": 70}

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

static func enemy_scale(act: int, lap: int) -> float:
	return 1.0 + ENEMY_ACT_STEP * (act - 1) + ENEMY_LAP_STEP * (lap - 1)

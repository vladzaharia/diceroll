class_name PetDefs
extends RefCounted
## Pet Den familiars (review §5.3). One pet per run. Each pet has a CHARGE METER of `size` pips,
## filled by one kind of dice event (`charge_on`). The charge persists across fights and board
## turns (RunState.pet_state.charge). Pets fire automatically (no tap):
##   * at the start of the next attack resolution (before damage), when the meter is full;
##   * Crystal Wisp instead fires at the start of the player's turn (its rerolls must come
##     before the attack).
## Firing empties the meter. Charge gained while full is lost.
##
## charge_on:
##   pair_plus      +1 per attack whose combo is a Pair or better
##   low_die        +1 per die showing 2 or less when you attack (L10: a 0 gives +2)
##   six            +1 per die showing 6 when you attack
##   kept           +1 per die you never rerolled that turn, when you attack
##   attack_intent  +1 per enemy intent rolled that is an attack
##   board_double   +1 per board move made with doubles
##
## Levels: 1..5 from pet XP (fights won while it is equipped, XP_LEVELS), 6..10 bought with
## Crowns (LEVEL_COSTS) once level 5 is reached. L5 and L10 add a behaviour (see `l5`, `l10`).
## Values below use level L (1..10). `model` is a presentation hint (KayKit prop).

const MAX_LEVEL := 10
const XP_LEVEL_MAX := 5
## Cumulative fights won with the pet equipped to reach level 2, 3, 4 and 5.
const XP_LEVELS := [15, 45, 90, 150]
## Crowns to buy levels 6, 7, 8, 9 and 10.
const LEVEL_COSTS := [40, 60, 80, 100, 120]

const DEFS := {
	"pumpkin_sprite": {"name": "Pumpkin Sprite", "role": "heal", "charge_on": "pair_plus", "size": 6, "model": "pumpkin",
		"fires": "Heal 3% of max HP (+0.2% per level).",
		"perk": "Campfires heal +5%.",
		"l5": "Also removes Burn.", "l10": "Overheal becomes Block."},
	"skull_buddy": {"name": "Skull Buddy", "role": "attack", "charge_on": "low_die", "size": 4, "model": "skull",
		"fires": "Before your attack, bite the target for 40% (+2% per level) of the hand's combo damage.",
		"perk": "Traps: +1 to the dodge roll.",
		"l5": "Bites every enemy at half damage.", "l10": "Blanks count as 1 for its bite and charge x2."},
	"lantern_ghost": {"name": "Lantern Ghost", "role": "burn", "charge_on": "six", "size": 5, "model": "lantern",
		"fires": "Poison 2 (+2 per 3 levels) on every enemy.",
		"perk": "Lava damage -50%.",
		"l5": "Poison doesn't decay on bosses.", "l10": "Poisoned enemies take +1 from Thunder and Ember."},
	"crystal_wisp": {"name": "Crystal Wisp", "role": "tempo", "charge_on": "kept", "size": 8, "model": "crystal",
		"fires": "At turn start: +1 combat reroll, and this turn's combo multiplier +0.3.",
		"perk": "+1 board reroll on the first board turn of each lap.",
		"l5": "Also +1 banked reroll and frees a cursed die.", "l10": "Its first reroll each fight doesn't count as rerolled."},
	"guard_die": {"name": "Guard Die", "role": "defense", "charge_on": "attack_intent", "size": 6, "model": "die",
		"fires": "Roll a d6: gain pips Block (+1 per 3 levels).",
		"perk": "Each new biome: +1 Healing Draught if the belt is empty.",
		"l5": "Half its Block lands again next turn.", "l10": "On a 6, also freezes the target."},
	"coin_mimic": {"name": "Coin Mimic", "role": "economy", "charge_on": "board_double", "size": 3, "model": "chest",
		"fires": "+12 gold (+2 per level) and bite the target for gold/20 (max 10).",
		"perk": "Treasury banks +2 per double.",
		"l5": "One free shop restock per shop.", "l10": "Chest gold rolls twice and keeps the better."},
}

const IDS := ["pumpkin_sprite", "skull_buddy", "lantern_ghost", "crystal_wisp", "guard_die", "coin_mimic"]

static func has(id: String) -> bool:
	return DEFS.has(id)

static func name_of(id: String) -> String:
	return String(DEFS[id].name) if DEFS.has(id) else ""

static func size(id: String) -> int:
	return int(DEFS[id].size)

static func charge_on(id: String) -> String:
	return String(DEFS[id].charge_on)

## Level reached from XP alone (1..5).
static func xp_level(xp: int) -> int:
	var l := 1
	for t in XP_LEVELS:
		if xp >= int(t):
			l += 1
	return l

## Crowns to go from `level` to level+1 (only 5..9 are bought); {} otherwise.
static func level_cost(level: int) -> Dictionary:
	if level < XP_LEVEL_MAX or level >= MAX_LEVEL:
		return {}
	return {"crowns": int(LEVEL_COSTS[level - XP_LEVEL_MAX])}

# ------------------------------------------------------------------ effect numbers

## Pet numbers (2026-09-28 pass: every pet worth about +3-6 pp at L10 in the realistic sim).
static func heal_pct(level: int) -> float:
	return 0.03 + 0.002 * (clampi(level, 1, MAX_LEVEL) - 1)

## Skull Buddy bite: bite_pct(level) x the hand's combo damage (pips x combo multiplier), at
## least BITE_MIN.
static func bite_pct(level: int) -> float:
	return 0.40 + 0.02 * (clampi(level, 1, MAX_LEVEL) - 1)

const BITE_MIN := 8
## Low-die charge threshold (dice showing this or less charge Skull Buddy).
const LOW_DIE_MAX := 2
## Crystal Wisp: rerolls per firing, and the combo multiplier bonus for that turn's attack.
const WISP_REROLLS := 1
const WISP_MULT := 0.3

static func poison(level: int) -> int:
	return 2 + (2 * (clampi(level, 1, MAX_LEVEL) - 1)) / 3

## Guard Die Block = d6 + block_bonus.
static func block_bonus(level: int) -> int:
	return (clampi(level, 1, MAX_LEVEL) - 1) / 3

static func mimic_gold(level: int) -> int:
	return 12 + 2 * (clampi(level, 1, MAX_LEVEL) - 1)

## Presentation card for the Pet Den.
static func card(id: String, level: int) -> Dictionary:
	var d: Dictionary = DEFS[id]
	return {"id": id, "name": String(d.name), "role": String(d.role), "charge_on": String(d.charge_on),
		"size": int(d.size), "fires": String(d.fires), "perk": String(d.perk), "l5": String(d.l5),
		"l10": String(d.l10), "level": level, "model": String(d.model)}

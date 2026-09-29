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
##   block          +1 per BLOCK_PER_CHARGE Block you hold when you attack (its own Block excluded)
##   one            +1 per die showing 1 when you attack
##   set3           +1 per attack whose combo is Three of a Kind, Full House or better (L5: Two Pair too)
##   reroll         +1 per combat reroll
##   rune           +1 per attack in which at least one rune triggers
##   win            +1 per fight won (fires right after the fight, not at an attack)
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
		"fires": "Heal 2% of max HP (+0.5% per level).",
		"perk": "Campfires heal +5%.",
		"l5": "Also removes Burn.", "l10": "Overheal becomes Block."},
	"skull_buddy": {"name": "Skull Buddy", "role": "attack", "charge_on": "low_die", "size": 4, "model": "skull",
		"fires": "Before your attack, bite the target for 30% (+5% per level) of the hand's combo damage.",
		"perk": "Traps: +1 to the dodge roll.",
		"l5": "Bites every enemy at half damage.", "l10": "Blanks count as 1 for its bite and charge x2."},
	"lantern_ghost": {"name": "Lantern Ghost", "role": "burn", "charge_on": "six", "size": 5, "model": "lantern",
		"fires": "Poison 1 (+0.7 per level, rounded down) on every enemy.",
		"perk": "Lava damage -50%.",
		"l5": "Poison doesn't decay on bosses.", "l10": "Poisoned enemies take +1 from Thunder and Ember."},
	"crystal_wisp": {"name": "Crystal Wisp", "role": "tempo", "charge_on": "kept", "size": 9, "model": "crystal",
		"fires": "At turn start: +1 combat reroll, and this turn's combo multiplier +0.05 (+0.01 per level).",
		"perk": "+1 board reroll on the first board turn of each lap.",
		"l5": "Also +1 banked reroll and frees a cursed die.", "l10": "Its first reroll each fight doesn't count as rerolled."},
	"guard_die": {"name": "Guard Die", "role": "defense", "charge_on": "attack_intent", "size": 6, "model": "die",
		"fires": "Roll a d6: gain pips Block (+1 per 3 levels above 1).",
		"perk": "Each new biome: +1 Healing Draught if the belt is empty.",
		"l5": "Half its Block lands again next turn.", "l10": "On a 6, also freezes the target."},
	"coin_mimic": {"name": "Coin Mimic", "role": "economy", "charge_on": "board_double", "size": 3, "model": "chest",
		"fires": "+8 gold (+2 per level) and bite the target for gold/20 (max 10).",
		"perk": "Treasury banks +2 per double.",
		"l5": "One free shop restock per shop.", "l10": "Chest gold rolls twice and keeps the better."},
	# --- 2026-09-29: six more familiars
	"pebble_golem": {"name": "Pebble", "role": "armor", "charge_on": "block", "size": 4, "model": "pebble",
		"fires": "Block 3 (+1 per 2 levels) and Thorns 3 (+1 per 2 levels) this turn: attackers that hurt you take it.",
		"perk": "Traps deal half damage.",
		"l5": "Thorns hit every attacker, even when your Block stops the hit.", "l10": "Its Block is doubled."},
	"frost_mote": {"name": "Frost Mote", "role": "control", "charge_on": "one", "size": 3, "model": "frost",
		"fires": "Freeze the target (it skips its next action) and chill it for 3 (+3 per level) damage.",
		"perk": "Ice tiles never freeze your dice.",
		"l5": "Also freezes the enemy with the biggest attack.", "l10": "Frozen enemies lose their Block."},
	"wick": {"name": "Wick", "role": "burst", "charge_on": "set3", "size": 3, "model": "candle",
		"fires": "Burn every enemy for 3 (+1.5 per level, rounded down) damage.",
		"perk": "Burn on you ticks 1 lower.",
		"l5": "Two Pair charges it too.", "l10": "Its fire ignores Block."},
	"tinker_gear": {"name": "Tinker", "role": "fixing", "charge_on": "reroll", "size": 6, "model": "gear",
		"fires": "Before your attack, set your lowest die to its highest face.",
		"perk": "Shop restocks cost 3 less.",
		"l5": "Fixes your two lowest dice.", "l10": "Also banks 1 reroll."},
	"grimoire": {"name": "Grimoire", "role": "runes", "charge_on": "rune", "size": 5, "model": "book",
		"fires": "Before your attack, re-fire the last rune that triggered (+5% per level above 1).",
		"perk": "Chests offer 4 runes instead of 3.",
		"l5": "Re-fires the last two different runes.", "l10": "Re-fires at +25% more."},
	"cauldron": {"name": "Bubbles", "role": "sustain", "charge_on": "win", "size": 4, "model": "cauldron",
		"fires": "After a fight, brew a Healing Draught into the belt (heals 15% when the belt is full) and heal 1.5% of max HP per level.",
		"perk": "Shop potions cost 5 less.",
		"l5": "Brews any unlocked potion type.", "l10": "Brews two potions."},
}

const IDS := ["pumpkin_sprite", "skull_buddy", "lantern_ghost", "crystal_wisp", "guard_die", "coin_mimic",
	"pebble_golem", "frost_mote", "wick", "tinker_gear", "grimoire", "cauldron"]

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

## Pet numbers (2026-09-28 pass: every pet worth about +4-8 pp at L10 in the realistic sim, and
## most of that power comes from levels, so a pet grows with the profile).
static func heal_pct(level: int) -> float:
	return 0.02 + 0.005 * (clampi(level, 1, MAX_LEVEL) - 1)

## Skull Buddy bite: bite_pct(level) x the hand's combo damage (pips x combo multiplier), at
## least BITE_MIN.
static func bite_pct(level: int) -> float:
	return 0.30 + 0.05 * (clampi(level, 1, MAX_LEVEL) - 1)

const BITE_MIN := 8
## Low-die charge threshold (dice showing this or less charge Skull Buddy).
const LOW_DIE_MAX := 2
## Crystal Wisp: rerolls per firing, and the combo multiplier bonus for that turn's attack.
const WISP_REROLLS := 1
const WISP_MULT := 0.05
const WISP_MULT_PER_LEVEL := 0.01

static func wisp_mult(level: int) -> float:
	return WISP_MULT + WISP_MULT_PER_LEVEL * (clampi(level, 1, MAX_LEVEL) - 1)

static func poison(level: int) -> int:
	return 1 + (7 * (clampi(level, 1, MAX_LEVEL) - 1)) / 10

## Guard Die Block = d6 + block_bonus.
static func block_bonus(level: int) -> int:
	return (clampi(level, 1, MAX_LEVEL) - 1) / 3

static func mimic_gold(level: int) -> int:
	return 8 + 2 * (clampi(level, 1, MAX_LEVEL) - 1)

## Pebble: Block per pip of charge, and its firing numbers.
const BLOCK_PER_CHARGE := 3

static func pebble_block(level: int) -> int:
	var b := 3 + (clampi(level, 1, MAX_LEVEL) - 1) / 2
	return b * 2 if level >= 10 else b

static func pebble_thorns(level: int) -> int:
	return 3 + (clampi(level, 1, MAX_LEVEL) - 1) / 2

static func frost_damage(level: int) -> int:
	return 3 + 3 * (clampi(level, 1, MAX_LEVEL) - 1)

static func wick_damage(level: int) -> int:
	return 3 + (3 * (clampi(level, 1, MAX_LEVEL) - 1)) / 2

static func grimoire_mult(level: int) -> float:
	var m := 1.0 + 0.05 * (clampi(level, 1, MAX_LEVEL) - 1)
	return m * 1.25 if level >= 10 else m

## Bubbles: heal % of max HP when brewing, and the heal when the belt is full.
static func cauldron_heal_pct(level: int) -> float:
	return 0.015 * clampi(level, 1, MAX_LEVEL)

const CAULDRON_FULL_HEAL := 0.15
## Pet perks: trap damage (Pebble), restock discount (Tinker), potion discount (Bubbles).
const PEBBLE_TRAP_MULT := 0.5
const TINKER_RESTOCK_OFF := 3
const CAULDRON_POTION_OFF := 5

## Presentation card for the Pet Den.
static func card(id: String, level: int) -> Dictionary:
	var d: Dictionary = DEFS[id]
	return {"id": id, "name": String(d.name), "role": String(d.role), "charge_on": String(d.charge_on),
		"size": int(d.size), "fires": String(d.fires), "perk": String(d.perk), "l5": String(d.l5),
		"l10": String(d.l10), "level": level, "model": String(d.model)}

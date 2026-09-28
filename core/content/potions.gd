class_name PotionDefs
extends RefCounted
## Potion types (review §5.5). Deterministic, unlocked by milestone or Sigils, bought in the
## shop by name, carried on the belt (2 slots, 3 with the Camp upgrade). Using one is a free
## action, at most one per combat turn. `combat_only` potions can't be drunk on the board.
##   healing       heal POTION_HEAL_PCT (30%) of max HP (A5: 25%)
##   stoneskin     gain STONESKIN_BLOCK Block now and again at the start of your next turn
##   reroll_tonic  +TONIC_REROLLS combat rerolls this turn
##   cleanse       remove Burn, Curse (locked + pending dice) and Chill; heal CLEANSE_HEAL_PCT

const DEFS := {
	"healing": {"name": "Healing Draught", "combat_only": false, "icon": "heart",
		"desc": "Heal 30% of max HP."},
	"stoneskin": {"name": "Stoneskin", "combat_only": true, "icon": "shield",
		"desc": "Gain 15 Block this turn and next."},
	"reroll_tonic": {"name": "Reroll Tonic", "combat_only": true, "icon": "dice",
		"desc": "+2 combat rerolls this turn."},
	"cleanse": {"name": "Cleanse", "combat_only": false, "icon": "drop",
		"desc": "Remove Burn, Curse and Chill, and heal 10% of max HP."},
}

const IDS := ["healing", "stoneskin", "reroll_tonic", "cleanse"]

const STONESKIN_BLOCK := 15
const TONIC_REROLLS := 2
const CLEANSE_HEAL_PCT := 0.10

static func has(id: String) -> bool:
	return DEFS.has(id)

static func name_of(id: String) -> String:
	return String(DEFS[id].name) if DEFS.has(id) else ""

static func combat_only(id: String) -> bool:
	return bool(DEFS[id].combat_only)

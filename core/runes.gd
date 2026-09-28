class_name Runes
extends RefCounted
## Rune definitions (bound to one die). Colours are hex strings for the presentation layer.
## Triggers: COMBO (die in scoring group), ALWAYS, SIX (die shows 6), ONE (die shows 1),
## KEPT (never rerolled this turn), REROLLED (rerolled at least once this turn), MOVE (board).

const DEFS := {
	"blade": {"name": "Blade", "color": "#e04848", "trigger": "COMBO", "rarity": "common", "desc": "In combo: +pips bonus damage."},
	"guard": {"name": "Guard", "color": "#4a8be0", "trigger": "ALWAYS", "rarity": "common", "desc": "Gain Block equal to pips."},
	"venom": {"name": "Venom", "color": "#58c060", "trigger": "COMBO", "rarity": "common", "desc": "In combo: apply Poison equal to pips."},
	"gilded": {"name": "Gilded", "color": "#e0a030", "trigger": "MOVE", "rarity": "common", "desc": "Move: +pips gold. In combo: +2 gold."},
	"heavy": {"name": "Heavy", "color": "#8a8a90", "trigger": "ALWAYS", "rarity": "common", "desc": "Pips count double in the damage sum."},
	"ember": {"name": "Ember", "color": "#f08030", "trigger": "SIX", "rarity": "rare", "desc": "Shows 6: 6 damage to ALL enemies."},
	"vampire": {"name": "Vampire", "color": "#a01830", "trigger": "COMBO", "rarity": "rare", "desc": "In combo, when the attack kills an enemy: heal equal to pips."},
	"lucky": {"name": "Lucky", "color": "#f0d040", "trigger": "KEPT", "rarity": "rare", "desc": "Never rerolled this turn: +1 reroll next turn (max 2 banked)."},
	"frost": {"name": "Frost", "color": "#9ad8f0", "trigger": "ONE", "rarity": "rare", "desc": "Shows 1: target skips its next action."},
	"thunder": {"name": "Thunder", "color": "#f0e040", "trigger": "REROLLED", "rarity": "rare", "desc": "Rerolled this turn: pips damage to a random enemy."},
	"echo": {"name": "Echo", "color": "#9a60e0", "trigger": "COMBO", "rarity": "epic", "desc": "In combo: combo multiplier +0.5."},
	"wild": {"name": "Wild", "color": "#ffffff", "trigger": "ALWAYS", "rarity": "epic", "desc": "Counts as the best value for combos."},
}

const IDS := ["blade", "guard", "venom", "gilded", "heavy", "ember", "vampire", "lucky", "frost", "thunder", "echo", "wild"]

## Rarity weights used when rolling a random rune.
const RARITY_WEIGHTS := {"common": 60, "rare": 30, "epic": 10}

static func rarity(id: String) -> String:
	return DEFS[id].rarity

static func of_rarity(r: String) -> Array[String]:
	var out: Array[String] = []
	for id in IDS:
		if DEFS[id].rarity == r:
			out.append(id)
	return out

static func random_rune(rng: Rng, rarity_filter: String = "") -> String:
	var r := rarity_filter
	if r == "":
		r = rng.weighted(RARITY_WEIGHTS)
	return rng.pick(of_rarity(r))

## n distinct random runes.
static func random_runes(rng: Rng, n: int) -> Array[String]:
	var out: Array[String] = []
	var guard := 0
	while out.size() < n and guard < 100:
		guard += 1
		var id := random_rune(rng)
		if not out.has(id):
			out.append(id)
	return out

static func option(id: String) -> Dictionary:
	var d: Dictionary = DEFS[id]
	return {"id": "rune", "label": "%s Rune" % d.name, "desc": d.desc, "rune": id}

## random_rune() restricted to `allowed` ids (empty = all runes, identical to random_rune).
## The rarity is rolled among rarities that still have an allowed rune (a filter with no allowed
## rune of that rarity falls back to any allowed rune).
static func random_rune_in(rng: Rng, allowed: Array, rarity_filter: String = "") -> String:
	if allowed.is_empty():
		return random_rune(rng, rarity_filter)
	# Each allowed id keeps its unrestricted odds (rarity weight / ids of that rarity), then the
	# weights are renormalised, so locking content never makes a rarer item more common.
	var w := {}
	for id in IDS:
		if allowed.has(id) and (rarity_filter == "" or String(DEFS[id].rarity) == rarity_filter):
			var r: String = DEFS[id].rarity
			w[id] = float(RARITY_WEIGHTS[r]) / float(of_rarity(r).size())
	if w.is_empty():
		for id in IDS:
			if allowed.has(id):
				w[id] = float(RARITY_WEIGHTS[String(DEFS[id].rarity)]) / float(of_rarity(String(DEFS[id].rarity)).size())
	if w.is_empty():
		return random_rune(rng, rarity_filter)
	return String(rng.weighted(w))

## n distinct runes from `allowed` (empty = all).
static func random_runes_in(rng: Rng, n: int, allowed: Array) -> Array[String]:
	if allowed.is_empty():
		return random_runes(rng, n)
	var out: Array[String] = []
	var guard := 0
	while out.size() < mini(n, allowed.size()) and guard < 100:
		guard += 1
		var id := random_rune_in(rng, allowed)
		if not out.has(id):
			out.append(id)
	return out

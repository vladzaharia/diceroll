class_name MinigameDefs
extends RefCounted
## Arcade minigames (review §5.4). Rules live in core/minigames/<id>.gd; each game reports a
## `score`. Performance ratio r = score / MEDIAN[id] (MEDIAN = median play, calibrated with the
## sim bot, see balance.md). r picks the reward TIER (bronze < TIER_SILVER <= silver <
## TIER_GOLD <= gold) and scales gold rewards by clamp(r, 1 - SKILL_BAND, 1 + SKILL_BAND).
## AUTO (minigame_auto) skips the game and takes r = PAR.
## After a game the player picks ONE reward from the tier's options (offer kind "reward").
## Crowns: Economy.CROWNS_MINIGAME[tier] per game, banked at run end.
## Mastery (1..5) comes from playing a minigame (MASTERY_PLAYS) and adds MASTERY_BONUS per level
## above 1 to gold rewards (max +10%).

const PAR := 0.85
## Skill band: rewards move at most this much around median (user decision: 15%).
const SKILL_BAND := 0.15
## Luck games move rewards even less (Fossil Hunter is a luck dig: no hints).
const SKILL_BAND_BY_ID := {"fossil_hunter": 0.05}
const TIER_SILVER := 0.8
const TIER_GOLD := 1.2

const MAX_MASTERY := 5
const MASTERY_PLAYS := [3, 8, 15, 25]
const MASTERY_BONUS := 0.025

const DEFS := {
	"fossil_hunter": {"name": "Fossil Hunter", "skill": "20:80", "signature": "new_die",
		"desc": "Dig a 7x7 site for three buried fossils (4, 3 and 2 long) and a few treasures. 10 digs, no hints: follow the bones you hit.",
		"signature_desc": "Gold: a new die of an unlocked kind."},
	"bubble_breaker": {"name": "Bubble Breaker", "skill": "80:20", "signature": "reroll_boost",
		"desc": "Pop clusters of 3+ same-coloured bubbles on a 6x6 board. 5 taps. Bigger clusters score more.",
		"signature_desc": "Gold: +1 combat reroll for the next 3 fights."},
	"scratch_off": {"name": "Scratch-off", "skill": "0:100", "signature": "gold_60",
		"desc": "Scratch 3 of 9 die faces. A pair pays, three of a kind pays well, three 6s is the jackpot.",
		"signature_desc": "Gold: 60 gold."},
	"claw_machine": {"name": "Claw Machine", "skill": "70:30", "signature": "passive_common",
		"desc": "Two grabs at a row of visible prizes. Hit a prize's hitbox to win it; the best prize is the narrowest.",
		"signature_desc": "Gold: pick a common passive."},
}

const IDS := ["fossil_hunter", "bubble_breaker", "scratch_off", "claw_machine"]

## Median score per game (calibrated: see balance.md "Minigame calibration").
const MEDIAN := {"fossil_hunter": 8.0, "bubble_breaker": 17.0, "scratch_off": 10.0, "claw_machine": 10.0}

## Reward options by tier (the player picks one). Gold amounts are x gold_scale(lap) x skill
## mult x mastery bonus.
const BRONZE_GOLD := 12
const SILVER_GOLD := 25
const GOLD_POTION_GOLD := 20
const SIGNATURE_GOLD := 60
## Bubble Breaker signature: +1 combat reroll for this many fights.
const REROLL_BOOST_FIGHTS := 3

static func has(id: String) -> bool:
	return DEFS.has(id)

static func name_of(id: String) -> String:
	return String(DEFS[id].name) if DEFS.has(id) else ""

static func signature(id: String) -> String:
	return String(DEFS[id].signature)

static func tier_for(ratio: float) -> String:
	if ratio >= TIER_GOLD:
		return "gold"
	if ratio >= TIER_SILVER:
		return "silver"
	return "bronze"

static func skill_mult(ratio: float, id := "") -> float:
	var band := float(SKILL_BAND_BY_ID.get(id, SKILL_BAND))
	return clampf(ratio, 1.0 - band, 1.0 + band)

static func mastery_level(plays: int) -> int:
	var l := 1
	for t in MASTERY_PLAYS:
		if plays >= int(t):
			l += 1
	return l

static func mastery_mult(level: int) -> float:
	return 1.0 + MASTERY_BONUS * (clampi(level, 1, MAX_MASTERY) - 1)

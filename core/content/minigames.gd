class_name MinigameDefs
extends RefCounted
## Arcade minigames (review §5.4). Rules live in core/minigames/<id>.gd; each game reports a
## `score`. Performance ratio r = score / MEDIAN[id] (MEDIAN = median play, calibrated with the
## sim bot, see balance.md). r picks the reward TIER (bronze < TIER_SILVER <= silver <
## TIER_GOLD <= gold) and scales gold rewards by clamp(r, 1 - SKILL_BAND, 1 + SKILL_BAND).
## The player plays every minigame (user decision 2026-09-29: the in-game AUTO pauses at
## minigames, Bot.decide). minigame_auto is the sims' / headless bots' stand-in for an average
## player: it draws the tier from the game's calibrated split (CALIBRATION[id].tiers, the
## human-like MgHuman player of tools/mg_calibrate.gd) with the minigame's own Rng, at that
## tier's typical ratio (SIM_RATIO). sim_ratio() does the draw.
## After a game the player picks ONE reward from the tier's options (offer kind "reward").
## Crowns: Economy.CROWNS_MINIGAME[tier] per game, banked at run end.
## Mastery (1..5) comes from playing a minigame (MASTERY_PLAYS) and adds MASTERY_BONUS per level
## above 1 to gold rewards (max +10%).

## A median player's ratio (silver at 1.0x): the stand-in for a game without calibration.
const PAR := 1.0
## The typical ratio of each tier for the sims' drawn results (gold rewards scale with it).
const SIM_RATIO := {"bronze": 0.65, "silver": 1.0, "gold": 1.35}
## Skill band: rewards move at most this much around median (user decision: 15%).
const SKILL_BAND := 0.15
## Luck games move rewards even less (Fossil Hunter is a luck dig: no hints; Plinko and the
## Lucky Wheel are mostly luck; Fishing and High-Low are half luck).
const SKILL_BAND_BY_ID := {"fossil_hunter": 0.05, "plinko": 0.05, "lucky_wheel": 0.05, "fishing": 0.10, "high_low": 0.10}
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
		"desc": "Pop clusters of 3+ same-coloured bubbles on a 6x6 board. 3 taps: make them count. Groups of 5+ and chains of big pops score extra.",
		"signature_desc": "Gold: +1 combat reroll for the next 3 fights."},
	"scratch_off": {"name": "Scratch-off", "skill": "0:100", "signature": "gold_60",
		"desc": "Scratch 3 of 9 die faces and win their pips. A pair adds 4, three alike adds 10, three 6s is the jackpot.",
		"signature_desc": "Gold: 60 gold."},
	"claw_machine": {"name": "Claw Machine", "skill": "70:30", "signature": "passive_common",
		"desc": "Three grabs into a pile of prize capsules. The colour hints the tier; the deep rare ones need a centred drop. One grab can scoop up to 3 capsules, but a full claw may drop some.",
		"signature_desc": "Gold: pick a common passive."},
	"bubble_shooter": {"name": "Bubble Shooter", "skill": "75:25", "signature": "sharpshooter",
		"desc": "Aim and launch bubbles into the hanging cluster. Match 3+ to pop; whatever hangs from them falls for double. 10 shots.",
		"signature_desc": "Gold: Sharpshooter, +1 ATK for the rest of the run."},
	"plinko": {"name": "Plinko", "skill": "25:75", "signature": "rare_rune",
		"desc": "Drop a die-ball from any slot and watch it bounce down the pegs into a prize bucket. Hit the golden peg for double. 3 drops.",
		"signature_desc": "Gold: a rare rune for one of your dice."},
	"shell_game": {"name": "Shell Game", "skill": "80:20", "signature": "heart_gem",
		"desc": "Watch the gem go under a cup, follow the shuffle, pick the cup. 3 rounds, each faster than the last.",
		"signature_desc": "Gold: Heart Gem, +10 max HP."},
	"memory_match": {"name": "Memory Match", "skill": "70:30", "signature": "mirror_forge",
		"desc": "Flip two cards a turn on a 4x4 grid of die faces and runes. Pairs stay up; 6 misses and you're done.",
		"signature_desc": "Gold: a Mirror Forge, two edits: raise a face or copy one face onto another."},
	"fishing": {"name": "Fishing", "skill": "50:50", "signature": "potion_pair",
		"desc": "Pick a spot, cast, and strike when the bobber plunges (not on a nibble). Deeper water, bigger fish, quicker bites. 3 casts.",
		"signature_desc": "Gold: The Catch, a Healing Draught plus another potion."},
	"lucky_wheel": {"name": "Lucky Wheel", "skill": "25:75", "signature": "passive_uncommon",
		"desc": "Spin the prize wheel three times. As it slows, one tap on the brake can stop it a segment or two early.",
		"signature_desc": "Gold: pick an uncommon passive."},
	"high_low": {"name": "High-Low Ladder", "skill": "40:60", "signature": "high_roller",
		"desc": "Higher or lower than the die? Every right call climbs the prize ladder. Cash out any time; a wrong call drops you to the last safe rung.",
		"signature_desc": "Gold: High Roller, raise the lowest face of every die by 1."},
}

const IDS := ["fossil_hunter", "bubble_breaker", "scratch_off", "claw_machine", "bubble_shooter", "plinko", "shell_game",
	"memory_match", "fishing", "lucky_wheel", "high_low"]

## Median score per game (calibrated: see balance.md "Minigame calibration").
const MEDIAN := {"fossil_hunter": 8.0, "bubble_breaker": 17.0, "scratch_off": 13.0, "claw_machine": 16.0,
	"bubble_shooter": 43.0, "plinko": 16.0, "shell_game": 11.0, "memory_match": 9.0, "fishing": 11.0, "lucky_wheel": 20.0,
	"high_low": 6.0}

## Calibration of all 11 games (2026-09-29 balance pass; tools/mg_calibrate.gd, the human-like
## MgHuman player, 2,000 games each; balance.md "Minigame calibration"): the median score, the
## tier split [bronze, silver, gold] at MEDIAN, the expected reward value in gold equivalents
## (bronze 12, silver 25, gold 45 x skill band), actions per game and the estimated seconds of
## play at 1x (actions x think + animation time). Rules for every game: EV within ±10% of the
## mean, gold <= 40%, bronze <= 45%, 15-35 s (SHORT_BY_DESIGN excepted). The sims'
## minigame_auto draws its tier from `tiers` (sim_ratio).
const CALIBRATION := {
	"fossil_hunter": {"median": 8.0, "tiers": [0.326, 0.359, 0.315], "ev": 27.8, "actions": 10.0, "secs": 20.0},
	"bubble_breaker": {"median": 17.0, "tiers": [0.332, 0.360, 0.308], "ev": 28.9, "actions": 2.9, "secs": 13.0},
	"scratch_off": {"median": 13.0, "tiers": [0.253, 0.471, 0.276], "ev": 29.1, "actions": 3.0, "secs": 9.0},
	"claw_machine": {"median": 16.0, "tiers": [0.343, 0.336, 0.321], "ev": 29.1, "actions": 3.0, "secs": 18.0},
	"bubble_shooter": {"median": 43.0, "tiers": [0.335, 0.351, 0.314], "ev": 29.0, "actions": 9.6, "secs": 25.0},
	"plinko": {"median": 15.0, "tiers": [0.334, 0.364, 0.302], "ev": 27.4, "actions": 3.0, "secs": 15.0},
	"shell_game": {"median": 11.0, "tiers": [0.314, 0.340, 0.346], "ev": 30.2, "actions": 3.0, "secs": 20.0},
	"memory_match": {"median": 8.0, "tiers": [0.342, 0.304, 0.354], "ev": 30.0, "actions": 20.8, "secs": 27.0},
	"fishing": {"median": 10.0, "tiers": [0.346, 0.388, 0.266], "ev": 27.0, "actions": 6.0, "secs": 18.0},
	"lucky_wheel": {"median": 20.0, "tiers": [0.220, 0.501, 0.279], "ev": 28.3, "actions": 6.0, "secs": 20.0},
	"high_low": {"median": 5.0, "tiers": [0.212, 0.552, 0.236], "ev": 28.0, "actions": 3.7, "secs": 10.0},
}
## Shorter than 15 s on purpose: Scratch-off is the breather (reveal 3 of 9), Bubble Breaker
## has 3 taps (user feedback 2026-09-29), High-Low ends when the player cashes out.
const SHORT_BY_DESIGN := ["scratch_off", "bubble_breaker", "high_low"]

## Reward options by tier (the player picks one). Gold amounts are x gold_scale(lap) x skill
## mult x mastery bonus.
const BRONZE_GOLD := 12
const SILVER_GOLD := 25
const GOLD_POTION_GOLD := 20
const SIGNATURE_GOLD := 60
## Bubble Breaker signature: +1 combat reroll for this many fights.
const REROLL_BOOST_FIGHTS := 3

## The sims' stand-in result for game `id`: u (0..1, from the minigame Rng) picks the tier by
## the calibrated split; returns that tier's SIM_RATIO (PAR without calibration).
static func sim_ratio(id: String, u: float) -> float:
	var c: Dictionary = CALIBRATION.get(id, {})
	if c.is_empty():
		return PAR
	var t: Array = c.tiers
	if u < float(t[0]):
		return float(SIM_RATIO.bronze)
	if u < float(t[0]) + float(t[1]):
		return float(SIM_RATIO.silver)
	return float(SIM_RATIO.gold)

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

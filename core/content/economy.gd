class_name Economy
extends RefCounted
## Meta currency model (user decision, 2026-09-28: model "A").
##   crowns  soft currency, paid by every run (laps, biomes, bosses, minigames), spent on levels
##   sigils  milestone currency: first-time achievements only (~57 exist), spent on unlocks
##   pet XP  per pet, fights won while equipped; levels pets 1..5 on its own
## Every price in the meta tables is a {crowns, sigils} dictionary, so a different model only
## has to change this file and the cost tables in unlocks.gd / gear.gd / pets.gd.

const MODEL := "A"
const CURRENCIES := ["crowns", "sigils"]

# ------------------------------------------------------------------ Crowns payout (review §3.4)

const CROWNS_PER_LAP := 2
const CROWNS_LAP_CAP := 30
## Per biome reached beyond the first (tier 2 and tier 3).
const CROWNS_PER_BIOME := 5
const CROWNS_MINIBOSS := 12
const CROWNS_WIN := 30
## Per minigame played, by reward tier.
const CROWNS_MINIGAME := {"bronze": 2, "silver": 3, "gold": 4}
## Leftover gold: 1 Crown per GOLD_PER_CROWN gold, at most GOLD_CROWN_CAP (so spending in-run
## is never punished).
const GOLD_PER_CROWN := 25
const GOLD_CROWN_CAP := 5
## +8% of the whole payout per ascension level.
const ASC_CROWN_BONUS := 0.08
## Catch-up: after CATCHUP_AFTER losses in a row the next run pays +CATCHUP_STEP per extra
## loss (first step at CATCHUP_AFTER), capped at CATCHUP_MAX. A win resets the streak.
const CATCHUP_AFTER := 3
const CATCHUP_STEP := 0.25
const CATCHUP_MAX := 0.5
## Short Road runs pay this share of the standard payout.
const SHORT_CROWN_MULT := 0.6

## Catch-up bonus for a loss streak.
static func catchup(loss_streak: int) -> float:
	if loss_streak < CATCHUP_AFTER:
		return 0.0
	return minf(CATCHUP_MAX, CATCHUP_STEP * (loss_streak - CATCHUP_AFTER + 1))

# ------------------------------------------------------------------ Sigils (first-time bonuses)

## Sigils paid the first time each thing happens (tracked in Profile.records.firsts).
##   biome      first time you reach each biome (6)
##   miniboss   first kill of each mini-boss (6)
##   boss       first kill of each final boss (4)
##   class_win  first win with each class (4)
##   route_win  first win on each route (8)
##   asc_clear  first win at each ascension level 1..10
##   short_win  first Short Road win
const SIGIL_FIRST := {"biome": 1, "miniboss": 1, "boss": 2, "class_win": 2, "route_win": 1, "asc_clear": 2, "short_win": 1}

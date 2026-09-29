class_name HighLow
extends Minigame
## High-Low Ladder (push your luck): a d6 shows a value; guess whether the next roll is higher
## or lower. A right guess climbs one rung of the prize ladder (PRIZES[rung]); an equal roll is
## a push (no change, guess again on the same value); a wrong guess ends the game on the last
## safety rung at or below the current one (SAFE). Cash out any time to bank the current rung;
## the top rung cashes out by itself.
## Action args: ["higher"] | ["lower"] | ["cash"]. Rolls come from the minigame Rng one at a
## time (the next one is never known before the guess).
## Score = PRIZES[rung] (a wrong guess: PRIZES[safety rung]). actions_left = rungs to the top.
## Public: {die, rung, prizes, safe, history [{guess, from, roll, result "up" | "push" |
##          "bust"}], cashed, bust}.
## Info per action: {guess, from, roll, result, rung} or {cash: true, rung}.

const PRIZES := [2, 5, 6, 7, 9, 11, 14, 18, 24]
const SAFE := [0, 1, 3, 5]

var die := 1
var rung := 0
var history: Array[Dictionary] = []
var cashed := false
var bust := false

func _init() -> void:
	id = "high_low"

func _setup() -> void:
	actions_left = PRIZES.size() - 1
	die = rng.randi_range(1, 6)
	rung = 0
	history.clear()
	cashed = false
	bust = false

static func safety(r: int) -> int:
	var s := 0
	for k in SAFE:
		if int(k) <= r:
			s = int(k)
	return s

func _action(args: Array) -> Dictionary:
	if args.is_empty():
		return {"error": "needs [\"higher\"], [\"lower\"] or [\"cash\"]"}
	var g := String(args[0])
	if g == "cash":
		cashed = true
		done = true
		return {"info": {"cash": true, "rung": rung}}
	if g != "higher" and g != "lower":
		return {"error": "unknown guess"}
	var from := die
	var roll := rng.randi_range(1, 6)
	var result := "push"
	if roll != from:
		result = "up" if (roll > from) == (g == "higher") else "bust"
	die = roll
	if result == "up":
		rung += 1
		actions_left -= 1
		if actions_left <= 0:
			cashed = true
	elif result == "bust":
		bust = true
		rung = safety(rung)
		done = true
	var h := {"guess": g, "from": from, "roll": roll, "result": result}
	history.append(h)
	var info := h.duplicate()
	info["rung"] = rung
	return {"info": info}

func score() -> float:
	return float(PRIZES[rung])

## Chance that a guess from `value` climbs (ignoring pushes: they re-roll).
static func win_odds(value: int, guess: String) -> float:
	var w := (6 - value) if guess == "higher" else (value - 1)
	var l := (value - 1) if guess == "higher" else (6 - value)
	return float(w) / float(maxi(1, w + l))

static func best_guess(value: int) -> String:
	return "higher" if value <= 3 else "lower"

func _public() -> Dictionary:
	return {"die": die, "rung": rung, "prizes": PRIZES.duplicate(), "safe": SAFE.duplicate(), "history": history.duplicate(true),
		"cashed": cashed, "bust": bust}

func _save() -> Dictionary:
	return {"die": die, "rung": rung, "history": history.duplicate(true), "cashed": cashed, "bust": bust}

func _load(d: Dictionary) -> void:
	die = int(d.get("die", 1))
	rung = int(d.get("rung", 0))
	history.clear()
	for h in d.get("history", []):
		history.append({"guess": String(h.guess), "from": int(h.from), "roll": int(h.roll), "result": String(h.result)})
	cashed = bool(d.get("cashed", false))
	bust = bool(d.get("bust", false))

class_name ScratchOff
extends Minigame
## Scratch-off: 9 hidden die faces, three copies each of 3 distinct faces (1..6), shuffled.
## Scratch 3; action args [idx] (0..8). Low variance by construction: P(three alike) ~ 4%,
## P(a pair) ~ 64%, P(nothing) ~ 32%, and nothing still pays a bronze prize.
## Score (MinigameDefs.MEDIAN.scratch_off = 10): nothing 7 (bronze), pair 10 (silver),
## three of a kind 13 (gold), three 6s 15 (gold, the jackpot). Unscratched cells stay "?".

const CELLS := 9
const SCRATCHES := 3
const SCORE := {"none": 7.0, "pair": 10.0, "three": 13.0, "jackpot": 15.0}

var faces: Array[int] = []
var revealed: Array[int] = []

func _init() -> void:
	id = "scratch_off"

func _setup() -> void:
	actions_left = SCRATCHES
	var pool: Array = [1, 2, 3, 4, 5, 6]
	rng.shuffle(pool)
	var cards: Array = []
	for k in 3:
		for c in 3:
			cards.append(int(pool[k]))
	rng.shuffle(cards)
	faces.clear()
	for v in cards:
		faces.append(int(v))
	revealed.resize(CELLS)
	revealed.fill(0)

func _action(args: Array) -> Dictionary:
	if args.is_empty():
		return {"error": "scratch needs [idx]"}
	var i := int(args[0])
	if i < 0 or i >= CELLS:
		return {"error": "cell out of range"}
	if revealed[i] == 1:
		return {"error": "already scratched"}
	revealed[i] = 1
	actions_left -= 1
	return {"info": {"idx": i, "face": faces[i]}}

## "none" | "pair" | "three" | "jackpot" for the scratched cells.
func outcome() -> String:
	var counts := {}
	var best := 0
	var best_face := 0
	for i in CELLS:
		if revealed[i] == 1:
			counts[faces[i]] = int(counts.get(faces[i], 0)) + 1
			if int(counts[faces[i]]) > best or (int(counts[faces[i]]) == best and faces[i] > best_face):
				best = int(counts[faces[i]])
				best_face = faces[i]
	if best >= 3:
		return "jackpot" if best_face == 6 else "three"
	if best == 2:
		return "pair"
	return "none"

func score() -> float:
	return float(SCORE[outcome()])

func _public() -> Dictionary:
	var view: Array = []
	for i in CELLS:
		view.append(faces[i] if revealed[i] == 1 else 0)
	return {"cells": view, "outcome": outcome()}

func _save() -> Dictionary:
	return {"faces": Array(faces), "revealed": Array(revealed)}

func _load(d: Dictionary) -> void:
	faces = Minigame.ints(d.get("faces", []))
	revealed = Minigame.ints(d.get("revealed", []))

class_name FossilHunter
extends Minigame
## Fossil Hunter (Minesweeper-lite): a 5x5 plot hides two fossils, 3 and 2 cells long (straight,
## never overlapping). DIGS digs; action args [x, y] (0..4). Every dug empty cell shows a
## distance hint: the Manhattan distance to the nearest fossil cell.
## Public: cells[i] = "?" not dug · "." empty (see hints[i]) · "hit" part of an unfinished
## fossil · "bone" part of a fully uncovered fossil; hints[i] = distance or -1.
## Score: 1 per fossil cell dug + 2 per complete fossil (max 9). Fossil positions stay hidden.

const W := 5
const H := 5
const SIZES := [3, 2]
const DIGS := 7

## Hidden: fossil index per cell (-1 = empty). dug: 0/1 per cell.
var cells: Array[int] = []
var dug: Array[int] = []

func _init() -> void:
	id = "fossil_hunter"

func _setup() -> void:
	actions_left = DIGS
	cells.resize(W * H)
	cells.fill(-1)
	dug.resize(W * H)
	dug.fill(0)
	for f in SIZES.size():
		var size := int(SIZES[f])
		for attempt in 200:
			var horiz := rng.randi_range(0, 1) == 0
			var x := rng.randi_range(0, W - (size if horiz else 1))
			var y := rng.randi_range(0, H - (1 if horiz else size))
			var spots: Array[int] = []
			for k in size:
				spots.append((y + (0 if horiz else k)) * W + x + (k if horiz else 0))
			var free := true
			for s in spots:
				if cells[s] != -1:
					free = false
			if free:
				for s in spots:
					cells[s] = f
				break

func _action(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"error": "dig needs [x, y]"}
	var x := int(args[0])
	var y := int(args[1])
	if x < 0 or x >= W or y < 0 or y >= H:
		return {"error": "cell out of range"}
	var i := y * W + x
	if dug[i] == 1:
		return {"error": "already dug"}
	dug[i] = 1
	actions_left -= 1
	var f := cells[i]
	var info := {"x": x, "y": y, "hit": f >= 0, "complete": 0, "hint": -1 if f >= 0 else hint(i)}
	if f >= 0 and is_complete(f):
		info.complete = int(SIZES[f])
		if found() == SIZES.size():
			done = true
	return {"info": info}

## Manhattan distance from cell i to the nearest fossil cell.
func hint(i: int) -> int:
	var best := 99
	for j in cells.size():
		if cells[j] >= 0:
			best = mini(best, absi(j % W - i % W) + absi(j / W - i / W))
	return best

func is_complete(f: int) -> bool:
	for i in cells.size():
		if cells[i] == f and dug[i] == 0:
			return false
	return true

func found() -> int:
	var n := 0
	for f in SIZES.size():
		if is_complete(f):
			n += 1
	return n

func hits() -> int:
	var n := 0
	for i in cells.size():
		if cells[i] >= 0 and dug[i] == 1:
			n += 1
	return n

func score() -> float:
	return float(hits() + 2 * found())

func _public() -> Dictionary:
	var view: Array = []
	var hints: Array = []
	for i in cells.size():
		if dug[i] == 0:
			view.append("?")
			hints.append(-1)
		elif cells[i] < 0:
			view.append(".")
			hints.append(hint(i))
		else:
			view.append("bone" if is_complete(cells[i]) else "hit")
			hints.append(-1)
	var fossils: Array = []
	for f in SIZES.size():
		fossils.append({"size": int(SIZES[f]), "found": is_complete(f)})
	return {"w": W, "h": H, "cells": view, "hints": hints, "fossils": fossils, "found": found()}

func _save() -> Dictionary:
	return {"cells": Array(cells), "dug": Array(dug)}

func _load(d: Dictionary) -> void:
	cells = Minigame.ints(d.get("cells", []))
	dug = Minigame.ints(d.get("dug", []))

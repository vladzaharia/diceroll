class_name FossilHunter
extends Minigame
## Fossil Hunter (luck dig, no hints): a 7x7 dig site hides three fossils, 4, 3 and 2 cells
## long (straight, never overlapping), and a few single treasures (a gem, two coin pouches).
## DIGS digs; action args [x, y] (0..6). A dig only reveals what is in that cell: nothing,
## a piece of a fossil, or a treasure. Nothing else is ever told (no distances, no counts
## per area), so finding things is luck; following a bone you uncovered is the only read.
## Public: cells[i] = "?" not dug · "." empty · "hit" part of an unfinished fossil · "bone" part
## of a fully uncovered fossil · "gem" / "coin" a treasure; fossils [{size, found}];
## treasures [{kind, found}] (kinds are known up front, where they are is not).
## Score: 1 per fossil cell dug + the fossil's size again when it is complete (4 / 3 / 2) +
## TREASURE points (gem 3, coin 2). Hidden: fossil and treasure positions.

const W := 7
const H := 7
const SIZES := [4, 3, 2]
const TREASURES := ["gem", "coin", "coin"]
const TREASURE_POINTS := {"gem": 3, "coin": 2}
const DIGS := 10

## Hidden: per cell, fossil index (0..), or TREASURE_BASE + treasure index, or -1 (empty).
const TREASURE_BASE := 100
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
		for attempt in 400:
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
	for t in TREASURES.size():
		for attempt in 400:
			var i := rng.randi_range(0, W * H - 1)
			if cells[i] == -1:
				cells[i] = TREASURE_BASE + t
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
	var c := cells[i]
	var info := {"x": x, "y": y, "hit": c >= 0 and c < TREASURE_BASE, "complete": 0, "treasure": ""}
	if c >= TREASURE_BASE:
		info.treasure = String(TREASURES[c - TREASURE_BASE])
	elif c >= 0 and is_complete(c):
		info.complete = int(SIZES[c])
	if found() == SIZES.size() and treasures_found() == TREASURES.size():
		done = true
	return {"info": info}

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

func treasures_found() -> int:
	var n := 0
	for i in cells.size():
		if cells[i] >= TREASURE_BASE and dug[i] == 1:
			n += 1
	return n

func score() -> float:
	var s := 0
	for i in cells.size():
		if dug[i] == 0 or cells[i] < 0:
			continue
		if cells[i] >= TREASURE_BASE:
			s += int(TREASURE_POINTS[TREASURES[cells[i] - TREASURE_BASE]])
		else:
			s += 1
	for f in SIZES.size():
		if is_complete(f):
			s += int(SIZES[f])
	return float(s)

func _public() -> Dictionary:
	var view: Array = []
	for i in cells.size():
		var c := cells[i]
		if dug[i] == 0:
			view.append("?")
		elif c < 0:
			view.append(".")
		elif c >= TREASURE_BASE:
			view.append(String(TREASURES[c - TREASURE_BASE]))
		else:
			view.append("bone" if is_complete(c) else "hit")
	var fossils: Array = []
	for f in SIZES.size():
		fossils.append({"size": int(SIZES[f]), "found": is_complete(f)})
	var treasures: Array = []
	for t in TREASURES.size():
		var got := false
		for i in cells.size():
			if cells[i] == TREASURE_BASE + t and dug[i] == 1:
				got = true
		treasures.append({"kind": String(TREASURES[t]), "found": got})
	return {"w": W, "h": H, "cells": view, "fossils": fossils, "treasures": treasures, "found": found()}

func _save() -> Dictionary:
	return {"cells": cells.duplicate(), "dug": dug.duplicate()}

func _load(d: Dictionary) -> void:
	cells = Minigame.ints(d.get("cells", []))
	dug = Minigame.ints(d.get("dug", []))

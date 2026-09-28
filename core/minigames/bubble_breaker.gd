class_name BubbleBreaker
extends Minigame
## Bubble Breaker: a 6x6 grid of 4 colours (nothing hidden). Tapping a cluster of MIN_CLUSTER+
## orthogonally connected bubbles of one colour pops it; bubbles fall, empty columns close up to
## the left. TAPS taps; action args [x, y], y = 0 is the bottom row. The game ends early when no
## cluster of MIN_CLUSTER is left.
## Chain meter: every pop of CHAIN_SIZE+ bubbles right after another one adds +CHAIN_BONUS.
## Score: bubbles popped + (size - BIG_FROM + 1) extra per bubble cluster of BIG_FROM+ + chain.
## Public: {w, h, colors, grid (column-major: grid[x * H + y], -1 = empty), popped, chain, best}.

const W := 6
const H := 6
const COLORS := 4
const TAPS := 5
const MIN_CLUSTER := 3
const BIG_FROM := 6
const CHAIN_SIZE := 4
const CHAIN_BONUS := 1

var grid: Array[int] = []
var popped: int = 0
var bonus: int = 0
var chain: int = 0
var best: int = 0

func _init() -> void:
	id = "bubble_breaker"

func _setup() -> void:
	actions_left = TAPS
	grid.resize(W * H)
	for i in grid.size():
		grid[i] = rng.randi_range(0, COLORS - 1)
	if not has_move():
		done = true

func at(x: int, y: int) -> int:
	if x < 0 or x >= W or y < 0 or y >= H:
		return -1
	return grid[x * H + y]

## Cells (x * H + y) of the cluster containing (x, y); empty for an empty cell.
func cluster(x: int, y: int) -> Array[int]:
	var out: Array[int] = []
	var c := at(x, y)
	if c < 0:
		return out
	var seen := {x * H + y: true}
	var stack: Array[int] = [x * H + y]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		out.append(i)
		var cx := i / H
		var cy := i % H
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = cx + int(d[0])
			var ny: int = cy + int(d[1])
			if at(nx, ny) == c and not seen.has(nx * H + ny):
				seen[nx * H + ny] = true
				stack.append(nx * H + ny)
	out.sort()
	return out

## Every poppable cluster as [cells...], largest first (ties: lowest first cell).
func clusters() -> Array:
	var seen := {}
	var out: Array = []
	for x in W:
		for y in H:
			if at(x, y) < 0 or seen.has(x * H + y):
				continue
			var cl := cluster(x, y)
			for i in cl:
				seen[i] = true
			if cl.size() >= MIN_CLUSTER:
				out.append(cl)
	out.sort_custom(func(a, b): return a.size() > b.size() or (a.size() == b.size() and a[0] < b[0]))
	return out

func has_move() -> bool:
	return not clusters().is_empty()

func _action(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"error": "tap needs [x, y]"}
	var x := int(args[0])
	var y := int(args[1])
	var cl := cluster(x, y)
	if cl.size() < MIN_CLUSTER:
		return {"error": "tap a cluster of %d or more" % MIN_CLUSTER}
	var color := at(x, y)
	actions_left -= 1
	for i in cl:
		grid[i] = -1
	var n := cl.size()
	popped += n
	best = maxi(best, n)
	if n >= BIG_FROM:
		bonus += n - BIG_FROM + 1
	if n >= CHAIN_SIZE:
		if chain > 0:
			bonus += CHAIN_BONUS * chain
		chain += 1
	else:
		chain = 0
	_collapse()
	if not has_move():
		done = true
	return {"info": {"x": x, "y": y, "popped": n, "cells": Array(cl), "color": color, "chain": chain}}

func _collapse() -> void:
	var cols: Array = []
	for x in W:
		var col: Array[int] = []
		for y in H:
			if grid[x * H + y] >= 0:
				col.append(grid[x * H + y])
		if not col.is_empty():
			cols.append(col)
	grid.fill(-1)
	for x in cols.size():
		var col: Array[int] = cols[x]
		for y in col.size():
			grid[x * H + y] = col[y]

func score() -> float:
	return float(popped + bonus)

func _public() -> Dictionary:
	return {"w": W, "h": H, "colors": COLORS, "min_cluster": MIN_CLUSTER, "grid": Array(grid), "popped": popped,
		"chain": chain, "best": best}

func _save() -> Dictionary:
	return {"grid": Array(grid), "popped": popped, "bonus": bonus, "chain": chain, "best": best}

func _load(d: Dictionary) -> void:
	grid = Minigame.ints(d.get("grid", []))
	popped = int(d.get("popped", 0))
	bonus = int(d.get("bonus", 0))
	chain = int(d.get("chain", 0))
	best = int(d.get("best", 0))

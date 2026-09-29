class_name MgLogic
extends RefCounted
## Pure helpers for the minigame screens. They only ever read the PUBLIC state the core
## hands out (offer.state / minigame_update.state); nothing here can see hidden cells, the
## fossils or the scratch card. Results (hits, grabs, faces) always come from core events.

## Claw sweep: constant speed between CLAW_MIN and CLAW_MAX, CLAW_SWEEP seconds one way,
## starting at the left edge every grab (a triangle wave; no randomness).
const CLAW_MIN := 0.03
const CLAW_MAX := 0.97
const CLAW_SWEEP := 1.45

## Bubble colours (4) and the claw prize looks by kind.
const BUBBLE_COLORS := [Color("ff5a6e"), Color("3fa9ff"), Color("5fdc6a"), Color("ffc93d")]
const PRIZE_COLORS := {"coins": Color("ffd34a"), "potion": Color("7dff9a"), "nugget": Color("ffc24a"), "gem": Color("7fe8ff"), "figure": Color("ff9a5a"), "robot": Color("c8d4e8"), "chest": Color("ffcf4a")}
const TIER_TINTS := {"common": Color("8fd0ff"), "rare": Color("6fe07a"), "epic": Color("c070ff"), "legendary": Color("ffc93d")}
const PRIZE_NAMES := {"coins": "Coins", "potion": "Potion", "nugget": "Gold Nugget", "gem": "Gem", "figure": "Action Figure", "robot": "Robot", "chest": "Gem Chest"}

const TIER_COLORS := {"bronze": Color("d98b4f"), "silver": Color("cfd9ea"), "gold": Color("ffcf4a")}
const GAME_COLORS := {"fossil_hunter": Color("e0a15a"), "bubble_breaker": Color("5ab8ff"),
	"scratch_off": Color("c98cff"), "claw_machine": Color("ff6f9a"), "bubble_shooter": Color("7f8cff"), "plinko": Color("4fd8b4"),
	"shell_game": Color("e89a52"), "memory_match": Color("b08cff"), "fishing": Color("3fb8e8"), "lucky_wheel": Color("ff6a5a"),
	"high_low": Color("8fd85a")}
const HINTS := {
	"fossil_hunter": "Dig for 3 fossils and hidden treasure. Hit a bone? Dig beside it!",
	"bubble_breaker": "Tap a group of 3+ to pop it. Big pops and chains score more.",
	"scratch_off": "Scratch 3 faces. A pair pays, three alike pays big, three 6s: JACKPOT!",
	"claw_machine": "Tap to drop. Every capsule hides a prize: gold ones are rare and deep!",
	"bubble_shooter": "Drag to aim, release to shoot. Match 3+ to pop; what hangs below falls for double!",
	"plinko": "Pick a slot and drop. Aim above the rich buckets; the golden peg doubles a drop!",
	"shell_game": "Watch the gem, follow the cups, tap its cup. Pick fast for a Sharp Eye bonus!",
	"memory_match": "Flip two cards a turn. Pairs stay up. Remember what you saw: 6 misses and it's over!",
	"fishing": "Pick a spot and cast. Strike when the bobber plunges, not on a nibble!",
	"lucky_wheel": "Spin! As it slows, tap BRAKE once to stop on a better prize.",
	"high_low": "Higher or lower? Each right call climbs the ladder. Cash out before you bust!",
}
const UNITS := {"fossil_hunter": "DIGS", "bubble_breaker": "TAPS", "scratch_off": "SCRATCHES", "claw_machine": "GRABS",
	"bubble_shooter": "SHOTS", "plinko": "DROPS", "shell_game": "ROUNDS", "memory_match": "MISSES", "fishing": "CASTS",
	"lucky_wheel": "SPINS", "high_low": "RUNGS"}
const ICONS := {"fossil_hunter": "shovel", "bubble_breaker": "bubble", "scratch_off": "ticket", "claw_machine": "claw",
	"bubble_shooter": "bubble", "plinko": "peg", "shell_game": "cup", "memory_match": "card", "fishing": "rod", "lucky_wheel": "wheel",
	"high_low": "ladder"}


static func claw_x(t: float) -> float:
	var u := fposmod(t / CLAW_SWEEP, 2.0)
	var k := u if u <= 1.0 else 2.0 - u
	return lerpf(CLAW_MIN, CLAW_MAX, k)


## The capsules a drop at x would scoop (public positions and depths; the same rule as the
## core). Aim highlight only: what is won comes from the minigame_update event.
static func claw_scoop(balls: Array, x: float) -> Array:
	return ClawMachine.scoop(balls, x)


static func bubble_at(grid: Array, x: int, y: int, w: int, h: int) -> int:
	if x < 0 or x >= w or y < 0 or y >= h:
		return -1
	return int(grid[x * h + y])


## Cells (x * h + y, sorted) of the same-colour group containing (x, y) in a public grid.
static func bubble_cluster(grid: Array, x: int, y: int, w: int, h: int) -> Array:
	var out: Array = []
	var c := bubble_at(grid, x, y, w, h)
	if c < 0:
		return out
	var seen := {x * h + y: true}
	var stack: Array = [x * h + y]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		out.append(i)
		var cx := i / h
		var cy := i % h
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := cx + d.x
			var ny := cy + d.y
			if bubble_at(grid, nx, ny, w, h) == c and not seen.has(nx * h + ny):
				seen[nx * h + ny] = true
				stack.append(nx * h + ny)
	out.sort()
	return out


## Gravity after a pop: {old cell: new cell} for every surviving bubble. Bubbles fall
## straight down in their column; empty columns close up to the left (the core's rule,
## derived from the public grid and the popped cells only).
static func bubble_moves(grid: Array, popped: Array, w: int, h: int) -> Dictionary:
	var gone := {}
	for c in popped:
		gone[int(c)] = true
	var moves := {}
	var nx := 0
	for x in w:
		var ny := 0
		for y in h:
			var i := x * h + y
			if int(grid[i]) >= 0 and not gone.has(i):
				moves[i] = nx * h + ny
				ny += 1
		if ny > 0:
			nx += 1
	return moves


## Scratch-off: the best set of equal revealed faces {face, count, cells} (ties: higher face).
static func scratch_best(cells: Array) -> Dictionary:
	var groups := {}
	for i in cells.size():
		var v := int(cells[i])
		if v > 0:
			if not groups.has(v):
				groups[v] = []
			groups[v].append(i)
	var best := {"face": 0, "count": 0, "cells": []}
	for v in groups:
		var n: int = groups[v].size()
		if n > int(best.count) or (n == int(best.count) and int(v) > int(best.face)):
			best = {"face": int(v), "count": n, "cells": groups[v]}
	return best


## Fossil bones: which orthogonal neighbours [left, up, right, down] of cell i are also
## bone (fully uncovered fossil) cells, so the drawn bones join into skeletons.
static func bone_links(cells: Array, i: int, w: int) -> Array:
	var kind := String(cells[i])
	var h := cells.size() / w
	var x := i % w
	var y := i / w
	var out := [false, false, false, false]
	if kind != "bone":
		return out
	out[0] = x > 0 and String(cells[i - 1]) == "bone"
	out[1] = y > 0 and String(cells[i - w]) == "bone"
	out[2] = x < w - 1 and String(cells[i + 1]) == "bone"
	out[3] = y < h - 1 and String(cells[i + w]) == "bone"
	return out


## Tier from a ratio (display only; the core's minigame_result carries the real tier).
static func tier_label(tier: String) -> String:
	match tier:
		"gold": return "GOLD!"
		"silver": return "SILVER"
	return "BRONZE"

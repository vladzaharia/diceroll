class_name BubbleShooter
extends Minigame
## Bubble Shooter: a hanging cluster of coloured bubbles on a hex grid (COLS wide, odd rows
## shifted half a cell right and one cell shorter) and a launcher at the bottom centre. Each
## shot is aimed with a quantised angle: action args [angle_idx] (0 .. ANGLES - 1, the middle
## one straight up; see angle_of). The core traces the flight (straight lines, bouncing off the
## side walls), sticks the bubble into the nearest free cell, pops its same-colour group when
## it has MIN_POP+ bubbles and drops every bubble no longer hanging from the ceiling.
## Score: POP_POINTS per popped bubble + DROP_POINTS per dropped one (+ CLEAR_BONUS for an
## empty board). SHOTS shots; the loaded and the next bubble are public (the preview), later
## colours come from the minigame Rng (only colours still on the board).
## Nothing else is hidden: the whole grid is public. trace() is a pure static so the screen's
## aim guide uses the exact rule on public data.
## Public: {cols, rows, grid (row-major, row * COLS + col, -1 empty), current, next,
##          popped, dropped, cleared}.
## Info per shot: {angle, path [[x, y], ...] (launcher, wall bounces, stop point, cell centre),
##          cell, color, popped [cells], dropped [cells], points, cleared}.

const COLS := 8
const ROWS := 11
const START_ROWS := 5
const COLORS := 4
const SHOTS := 10
const ANGLES := 121
const MAX_DEG := 75.0
const MIN_POP := 3
const POP_POINTS := 1
const DROP_POINTS := 2
const CLEAR_BONUS := 10
## Geometry in cell units: bubble radius, row pitch, launcher position.
const R := 0.5
const ROW_H := 0.866
const WIDTH := 8.0
const LAUNCH := Vector2(4.0, 10.75)
## Contact distance between centres (a little under 2R, so near misses slip through gaps).
const HIT := 0.88

var grid: Array[int] = []
var current := 0
var next_color := 0
var popped := 0
var dropped := 0
var cleared := false

func _init() -> void:
	id = "bubble_shooter"

func _setup() -> void:
	actions_left = SHOTS
	grid.resize(ROWS * COLS)
	grid.fill(-1)
	for r in START_ROWS:
		for c in COLS:
			if not valid(r, c):
				continue
			var col := rng.randi_range(0, COLORS - 1)
			# clumps: often copy the left or the upper-left neighbour
			if rng.chance(0.45):
				var left := at(r, c - 1)
				var up := at(r - 1, c if r % 2 == 1 else c - 1)
				if left >= 0 and (up < 0 or rng.chance(0.5)):
					col = left
				elif up >= 0:
					col = up
			grid[r * COLS + c] = col
	current = _draw_color()
	next_color = _draw_color()

static func valid(r: int, c: int) -> bool:
	return r >= 0 and r < ROWS and c >= 0 and c < (COLS if r % 2 == 0 else COLS - 1)

func at(r: int, c: int) -> int:
	return grid[r * COLS + c] if valid(r, c) else -1

static func center(r: int, c: int) -> Vector2:
	return Vector2(c + 0.5 + (0.5 if r % 2 == 1 else 0.0), r * ROW_H + 0.5)

static func angle_of(idx: int) -> float:
	return deg_to_rad(-MAX_DEG + 2.0 * MAX_DEG * clampi(idx, 0, ANGLES - 1) / float(ANGLES - 1))

## Hex neighbours of (r, c) as cell indices (valid cells only).
static func neighbours(r: int, c: int) -> Array[int]:
	var out: Array[int] = []
	var sh := 0 if r % 2 == 0 else 1
	for d: Array in [[0, -1], [0, 1], [-1, sh - 1], [-1, sh], [1, sh - 1], [1, sh]]:
		var rr: int = r + int(d[0])
		var cc: int = c + int(d[1])
		if valid(rr, cc):
			out.append(rr * COLS + cc)
	return out

## The flight of a shot at angle_idx over a public grid: {path: [[x, y], ...], cell} (cell -1:
## no free cell to stick to). Pure: the same rule for the core, the bot and the aim guide.
static func trace(g: Array, angle_idx: int) -> Dictionary:
	var a := angle_of(angle_idx)
	var dx := snappedf(sin(a), 0.000001)
	var dy := -snappedf(cos(a), 0.000001)
	var x := LAUNCH.x
	var y := LAUNCH.y
	var path: Array = [[x, y]]
	# straight segments between wall bounces; each ends at a wall, the ceiling or the first
	# bubble the flight comes within HIT of (ray-circle intersection)
	for seg in 24:
		var t_wall := INF
		if dx > 0.0:
			t_wall = (WIDTH - R - x) / dx
		elif dx < 0.0:
			t_wall = (R - x) / dx
		var t_ceil := (R - y) / dy
		var t_hit := INF
		for i in g.size():
			if int(g[i]) < 0:
				continue
			var ctr := center(i / COLS, i % COLS)
			var ox := x - ctr.x
			var oy := y - ctr.y
			var b := ox * dx + oy * dy
			var c := ox * ox + oy * oy - HIT * HIT
			if c <= 0.0:
				t_hit = 0.0
				continue
			var disc := b * b - c
			if disc < 0.0:
				continue
			var t := -b - sqrt(disc)
			if t >= 0.0 and t < t_hit:
				t_hit = t
		var t_end := minf(t_wall, minf(t_ceil, t_hit))
		x = snappedf(x + dx * t_end, 0.0001)
		y = snappedf(y + dy * t_end, 0.0001)
		if t_end == t_wall and t_wall < t_ceil and t_wall < t_hit:
			dx = -dx
			path.append([snappedf(x, 0.001), snappedf(y, 0.001)])
			continue
		break
	path.append([snappedf(x, 0.001), snappedf(y, 0.001)])
	var cell := _snap(g, x, y)
	if cell >= 0:
		var ctr := center(cell / COLS, cell % COLS)
		path.append([snappedf(ctr.x, 0.001), snappedf(ctr.y, 0.001)])
	return {"path": path, "cell": cell}

## The free cell the bubble sticks in: the nearest free cell touching the ceiling or a bubble.
static func _snap(g: Array, x: float, y: float) -> int:
	var best := -1
	var best_d := INF
	var r0 := int(round((y - 0.5) / ROW_H))
	for rr in range(r0 - 2, r0 + 3):
		for cc in range(int(x) - 2, int(x) + 3):
			if not valid(rr, cc) or int(g[rr * COLS + cc]) >= 0:
				continue
			var attached := rr == 0
			if not attached:
				for n in neighbours(rr, cc):
					if int(g[n]) >= 0:
						attached = true
						break
			if not attached:
				continue
			var ctr := center(rr, cc)
			var d := Vector2(x - ctr.x, y - ctr.y).length()
			if d < best_d - 0.000001:
				best_d = d
				best = rr * COLS + cc
	return best

## Same-colour group (cell indices, sorted) containing cell i.
static func group(g: Array, i: int) -> Array[int]:
	var out: Array[int] = []
	var col := int(g[i])
	if col < 0:
		return out
	var seen := {i: true}
	var stack: Array[int] = [i]
	while not stack.is_empty():
		var k: int = stack.pop_back()
		out.append(k)
		for n in neighbours(k / COLS, k % COLS):
			if not seen.has(n) and int(g[n]) == col:
				seen[n] = true
				stack.append(n)
	out.sort()
	return out

## Occupied cells not connected to the ceiling (sorted).
static func floating(g: Array) -> Array[int]:
	var seen := {}
	var stack: Array[int] = []
	for c in COLS:
		if int(g[c]) >= 0:
			seen[c] = true
			stack.append(c)
	while not stack.is_empty():
		var k: int = stack.pop_back()
		for n in neighbours(k / COLS, k % COLS):
			if not seen.has(n) and int(g[n]) >= 0:
				seen[n] = true
				stack.append(n)
	var out: Array[int] = []
	for i in g.size():
		if int(g[i]) >= 0 and not seen.has(i):
			out.append(i)
	return out

## What a shot would do on a public grid (bot / aim preview): {cell, popped, dropped, points}.
static func simulate(g: Array, color: int, angle_idx: int) -> Dictionary:
	var t := trace(g, angle_idx)
	var cell := int(t.cell)
	var res := {"cell": cell, "popped": [], "dropped": [], "points": 0, "path": t.path}
	if cell < 0:
		return res
	var gg := g.duplicate()
	gg[cell] = color
	var grp := group(gg, cell)
	if grp.size() >= MIN_POP:
		for k in grp:
			gg[k] = -1
		var fl := floating(gg)
		res.popped = Array(grp)
		res.dropped = Array(fl)
		res.points = POP_POINTS * grp.size() + DROP_POINTS * fl.size()
	return res

func _action(args: Array) -> Dictionary:
	if args.is_empty():
		return {"error": "shoot needs [angle_idx]"}
	var ai := clampi(int(args[0]), 0, ANGLES - 1)
	var sim := simulate(grid, current, ai)
	var cell := int(sim.cell)
	var color := current
	actions_left -= 1
	if cell >= 0:
		grid[cell] = color
		for k in sim.popped:
			grid[int(k)] = -1
		for k in sim.dropped:
			grid[int(k)] = -1
	popped += (sim.popped as Array).size()
	dropped += (sim.dropped as Array).size()
	var points := int(sim.points)
	if not cleared and grid.max() < 0:
		cleared = true
		points += CLEAR_BONUS
		actions_left = 0
	current = next_color
	next_color = _draw_color()
	return {"info": {"angle": ai, "path": sim.path, "cell": cell, "color": color, "popped": sim.popped,
		"dropped": sim.dropped, "points": points, "cleared": cleared}}

## A colour still on the board (any colour on an empty board).
func _draw_color() -> int:
	var have: Array = []
	for c in COLORS:
		if grid.has(c):
			have.append(c)
	if have.is_empty():
		return rng.randi_range(0, COLORS - 1)
	return int(rng.pick(have))

func score() -> float:
	return float(POP_POINTS * popped + DROP_POINTS * dropped + (CLEAR_BONUS if cleared else 0))

## Best angle for a colour on a public grid (points, then the most same-colour neighbours at the
## landing cell, then the most central angle). Bot / AUTO play.
static func best_angle(g: Array, color: int) -> int:
	var best := ANGLES / 2
	var best_v := -INF
	for ai in ANGLES:
		var s := simulate(g, color, ai)
		var cell := int(s.cell)
		if cell < 0:
			continue
		var v := float(s.points) * 10.0
		for n in neighbours(cell / COLS, cell % COLS):
			if int(g[n]) == color:
				v += 1.5
		v -= absf(ai - ANGLES / 2) * 0.001
		if v > best_v:
			best_v = v
			best = ai
	return best

func _public() -> Dictionary:
	return {"cols": COLS, "rows": ROWS, "grid": Array(grid).duplicate(), "current": current, "next": next_color,
		"popped": popped, "dropped": dropped, "cleared": cleared}

func _save() -> Dictionary:
	return {"grid": Array(grid), "current": current, "next": next_color, "popped": popped, "dropped": dropped, "cleared": cleared}

func _load(d: Dictionary) -> void:
	grid = Minigame.ints(d.get("grid", []))
	current = int(d.get("current", 0))
	next_color = int(d.get("next", 0))
	popped = int(d.get("popped", 0))
	dropped = int(d.get("dropped", 0))
	cleared = bool(d.get("cleared", false))

class_name ShooterBoard
extends MgBoard
## Bubble Shooter: a hanging cluster of glossy bubbles on a hex grid over a hidden gem chest,
## and a cute bubble cannon at the bottom. Aim by dragging (touch: press anywhere, the cannon
## points at the finger, release shoots, drag back below the cannon to cancel) or by hovering
## (desktop: the cannon follows the pointer, click shoots). The aim is quantised to the core's
## angle steps ([angle_idx]) and a dotted guide (BubbleShooter.trace on the public grid) shows
## the flight up to the first wall bounce plus a short stub: the rest is the skill.
## Every shot plays from the minigame_update info: the flight along info.path (bounces), the
## snap with a wobble ripple, the pops one by one, the dropped bubbles falling for double.
##
## Geometry is in the core's cell units (radius 0.5, row pitch 0.866, field 8 wide, launcher
## at (4, 10.75)); P() maps them to the screen.

const COLS := BubbleShooter.COLS
const TOP := -0.72          # ceiling bar top (cell units)
const BOT := 12.3           # frame bottom
const SIDE := 0.3           # wall thickness
const DECK := 11.12         # launch deck top
const DANGER := 9.8         # decorative danger line
const FLY_SPEED := 18.0     # cells per second at 1x
const STUB := 1.5           # guide length after the first bounce
const NEXT_POS := Vector2(1.75, 11.45)
const CHEST_POS := Vector2(4.0, 2.7)

var _u := 40.0
var _o := Vector2.ZERO
## Visual grid: cell -> {col, off (units), vel, pop (time or -1), shake (time or -1)}.
var _vis := {}
var _animating := false
var _disp_cur := -1
var _disp_next := -1
var _next_born := -10.0
var _swap_k := -1.0          # 0..1: the next bubble rolling into the cannon
var _swap_col := 0
## Aim: target step and the displayed (smoothed) angle.
var _aim_idx := BubbleShooter.ANGLES / 2
var _aim := 0.0
var _drag := false
var _cancel := false
var _hover := false
var _touched := false
var _guide_key := ""
var _guide: Array = []       # the traced path (units)
## The bubble in flight: {pts, lens, total, d, col, bounces {idx: true}, next_b}.
var _fly := {}
var _trail: Array = []
var _squash_t := -10.0
var _recoil_t := -10.0
var _falling: Array = []     # {p, v, col, hits, fade, spin}
var _drop_pts := 0
var _clear_t := -1000.0
var _chest_bump := -10.0
var _cancel_t := -10.0


# --- state -----------------------------------------------------------------------------

func set_state(st: Dictionary, instant := true) -> void:
	super.set_state(st, instant)
	if not _animating:
		_rebuild()
		_disp_cur = int(state.get("current", 0))
		_disp_next = int(state.get("next", 0))
		if bool(state.get("cleared", false)):
			_clear_t = time
	unlock()


func _rebuild() -> void:
	var old := _vis
	_vis = {}
	var grid: Array = state.get("grid", [])
	for i in grid.size():
		if int(grid[i]) >= 0:
			var v: Dictionary = {"col": int(grid[i]), "off": Vector2.ZERO, "vel": Vector2.ZERO, "pop": -1.0, "shake": -1.0}
			if old.has(i) and int(old[i].col) == int(grid[i]):
				v.off = old[i].off
				v.vel = old[i].vel
			_vis[i] = v


func is_settled() -> bool:
	return not _animating and _fly.is_empty() and _falling.is_empty()


func status_text() -> String:
	var p := int(state.get("popped", 0))
	var d := int(state.get("dropped", 0))
	if bool(state.get("cleared", false)):
		return "Board cleared!"
	if p + d == 0:
		return ""
	return "Popped %d   Dropped %d" % [p, d]


func _can_shoot() -> bool:
	return not locked and not _animating and int(state.get("actions_left", 0)) > 0 and not bool(state.get("done", false))


# --- layout ----------------------------------------------------------------------------

func _layout() -> void:
	var w := COLS + SIDE * 2.0
	var h := BOT - TOP
	_u = maxf(4.0, minf((size.x - 12.0) / w, (size.y - 12.0) / h))
	_o = Vector2((size.x - COLS * _u) * 0.5, (size.y - h * _u) * 0.5 - TOP * _u)


## Screen position of a point in cell units.
func P(v: Vector2) -> Vector2:
	return _o + v * _u


func U(p: Vector2) -> Vector2:
	return (p - _o) / _u


func cell_pos(i: int) -> Vector2:
	return BubbleShooter.center(i / COLS, i % COLS)


## The angle step pointing from the launcher at screen point p (-1: at/below the launcher).
func idx_toward(p: Vector2) -> int:
	var d := U(p) - BubbleShooter.LAUNCH
	if d.y > -0.35:
		return -1
	var deg := rad_to_deg(atan2(d.x, -d.y))
	var k := (deg + BubbleShooter.MAX_DEG) / (2.0 * BubbleShooter.MAX_DEG) * (BubbleShooter.ANGLES - 1)
	return clampi(roundi(k), 0, BubbleShooter.ANGLES - 1)


## The dotted guide: the traced flight up to the first wall bounce plus STUB after it (a
## straight shot shows up to its contact point). Pure; units.
static func guide_points(path: Array) -> Array:
	var out: Array = []
	if path.size() < 2:
		return out
	var a := Vector2(float(path[0][0]), float(path[0][1]))
	out.append(a)
	var n := path.size()
	# path = launcher, bounces..., stop[, cell centre]; a bounce is any point before the stop
	var b := Vector2(float(path[1][0]), float(path[1][1]))
	out.append(b)
	var at_wall := absf(b.x - BubbleShooter.R) < 0.01 or absf(b.x - (BubbleShooter.WIDTH - BubbleShooter.R)) < 0.01
	if at_wall and n >= 3:
		var c := Vector2(float(path[2][0]), float(path[2][1]))
		var seg := c - b
		if seg.length() > 0.001:
			out.append(b + seg.normalized() * minf(STUB, seg.length()))
	return out


# --- input -----------------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and not _drag:
		_hover = false


func _gui_input(e: InputEvent) -> void:
	_layout()
	var mb := e as InputEventMouseButton
	var mm := e as InputEventMouseMotion
	if mm:
		var k := idx_toward(mm.position)
		if k >= 0:
			_aim_idx = k
			_hover = true
			if _drag and _cancel:
				_cancel = false
				MgBoard.sfx("tick", 0.05, -8.0)
		elif _drag and not _cancel:
			_cancel = true
			_cancel_t = time
			MgBoard.sfx("click", 0.05, -6.0)
		return
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		if not _can_shoot():
			return
		_drag = true
		_touched = true
		var k := idx_toward(mb.position)
		_cancel = k < 0
		if k >= 0:
			_aim_idx = k
			_hover = true
		return
	if not _drag:
		return
	_drag = false
	var k := idx_toward(mb.position)
	if k >= 0 and not _cancel:
		_aim_idx = k
	if _cancel or k < 0:
		_cancel = false
		return
	if _can_shoot():
		send([_aim_idx])


func scripted_input(args: Array, drv: Node) -> bool:
	if args.is_empty():
		return false
	# the drag runs as its own coroutine: the harness polls the core for the action (awaiting a
	# coroutine through the MgBoard-typed call loses the caller's frame state in the harness)
	_scripted_drag(clampi(int(args[0]), 0, BubbleShooter.ANGLES - 1), drv)
	return true


## Press above the cannon, drag to the aim point for angle step idx, hold a beat, release.
func _scripted_drag(idx: int, drv: Node) -> void:
	var guard := 0
	while (_animating or locked or not _falling.is_empty()) and guard < 400:
		guard += 1
		await get_tree().process_frame
	_layout()
	var a := BubbleShooter.angle_of(idx)
	var dir := Vector2(sin(a), -cos(a))
	var o := get_global_rect().position
	var start := P(BubbleShooter.LAUNCH + Vector2(0.0, -2.4))
	var target := P(BubbleShooter.LAUNCH + dir * 3.6)
	drv.call("press", o + start)
	await get_tree().process_frame
	for k in 8:
		drv.call("move", o + start.lerp(target, (k + 1) / 8.0))
		await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	drv.call("release", o + target)


# --- update animation --------------------------------------------------------------------

func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	_layout()
	_animating = true
	_drag = false
	_cancel = false
	var info: Dictionary = ev.get("info", {})
	var nst: Dictionary = ev.get("state", {})
	var col := int(info.get("color", _disp_cur))
	var cell := int(info.get("cell", -1))
	var popped: Array = info.get("popped", [])
	var dropped: Array = info.get("dropped", [])
	var path: Array = info.get("path", [])
	# turn the cannon to the shot (AUTO / a restored aim), then fire
	var ai := int(info.get("angle", _aim_idx))
	if ai != _aim_idx:
		_aim_idx = ai
		await wait(0.2)
	_recoil_t = time
	MgBoard.sfx("swoosh", 0.08, -2.0)
	MgBoard.sfx("pop", 0.1, -8.0)
	burst(P(BubbleShooter.LAUNCH + Vector2(sin(_aim), -cos(_aim)) * 0.9), _bc(col).lightened(0.5), 6, "puff", 90.0, 20.0, 6.0)
	_disp_cur = -1
	_swap_in(int(nst.get("current", 0)), int(nst.get("next", 0)))
	# the flight
	_start_flight(path, col, cell >= 0)
	while not _fly.is_empty():
		await get_tree().process_frame
	if cell < 0:
		burst(P(Vector2(float(path[-1][0]), float(path[-1][1]))), _bc(col), 10, "puff", 120.0, 0.0, 8.0)
		MgBoard.sfx("fwump")
	else:
		_vis[cell] = {"col": col, "off": Vector2.ZERO, "vel": Vector2.ZERO, "pop": -1.0, "shake": -1.0, "born": time}
		_ripple(cell, 1.0)
		MgBoard.sfx("clink", 0.08, -3.0)
		shake(2.0)
	# pops: one after another, outward from the landing cell, rising pitch
	if not popped.is_empty():
		await wait(0.08)
		var order := _pop_order(cell, popped)
		var centre := Vector2.ZERO
		for c in popped:
			centre += cell_pos(int(c))
		centre /= float(popped.size())
		var step := 0.075 if popped.size() < 7 else 0.05
		for k in order.size():
			var c := int(order[k])
			if not _vis.has(c):
				continue
			var v: Dictionary = _vis[c]
			v.pop = time
			var p := P(cell_pos(c) + v.off)
			var bc := _bc(int(v.col))
			burst(p, bc, 8, "spark", 5.5 * _u, 0.8 * _u, 0.16 * _u)
			burst(p, bc.lightened(0.45), 4, "flake", 4.0 * _u, 2.0 * _u, 0.14 * _u)
			ring(p, Color(1, 1, 1, 0.8), _u * 0.6, 0.3, 0.09 * _u)
			float_text(p + Vector2(0, -_u * 0.2), "+1", bc.lightened(0.5), maxi(16, int(_u * 0.42)), 0.6)
			_pitched("glass" if k % 3 == 2 else "pop", 0.9 + 0.07 * k, -3.0 + minf(k, 6) * 0.4)
			_ripple(c, 0.45)
			await wait(step)
		await wait(0.1)
		var n := popped.size()
		float_text(P(centre), "POP x%d  +%d" % [n, n] if n >= 5 else "+%d" % n, _bc(col).lightened(0.4), maxi(22, int(_u * (0.75 if n >= 5 else 0.6))), 1.0)
		shake(3.0 + minf(n, 10) * 0.6)
		kick.emit(0.2 + minf(n, 10) * 0.03, Color(_bc(col), 0.25))
	elif cell >= 0:
		# no pop: a tiny settle bounce and a neighbour count nudge
		var same := 0
		for nb in BubbleShooter.neighbours(cell / COLS, cell % COLS):
			if _vis.has(nb) and int(_vis[nb].col) == col:
				same += 1
		if same >= 1:
			float_text(P(cell_pos(cell)) + Vector2(0, -_u * 0.5), "%d/3" % (same + 1), UiPalette.TEXT_DIM, maxi(16, int(_u * 0.4)), 0.7)
	# drops: shaken loose, then they fall for double
	if not dropped.is_empty():
		for c in dropped:
			if _vis.has(int(c)):
				_vis[int(c)].shake = time
		MgBoard.sfx("wood", 0.1, -4.0)
		await wait(0.22)
		_drop_pts = 0
		var ctr := Vector2.ZERO
		for c in dropped:
			var i := int(c)
			ctr += cell_pos(i)
			if not _vis.has(i):
				continue
			var v: Dictionary = _vis[i]
			_falling.append({"p": cell_pos(i) + v.off, "v": Vector2(randf_range(-1.6, 1.6), randf_range(-3.2, -0.6)),
				"col": int(v.col), "hits": 0, "fade": -1.0, "spin": randf_range(-4.0, 4.0), "rot": 0.0})
			_vis.erase(i)
		ctr /= float(dropped.size())
		MgBoard.sfx("swoosh", 0.1, 0.0)
		var nd := dropped.size()
		float_text(P(ctr), "DROP x%d!" % nd if nd >= 2 else "DROP!", Color("ffd84a"), maxi(24, int(_u * 0.8)), 1.2)
		var guard := 0
		while guard < 240 and _drop_pts < nd:
			guard += 1
			await get_tree().process_frame
		await wait(0.1)
		float_text(P(Vector2(4.0, 8.6)), "+%d  (+2 each)" % (nd * BubbleShooter.DROP_POINTS), Color("ffe07a"), maxi(24, int(_u * 0.72)), 1.3)
		MgBoard.sfx("coin")
		if nd >= 4:
			MgBoard.sfx("buff")
		shake(4.0 + minf(nd, 12) * 0.5)
		kick.emit(0.35 + minf(nd, 12) * 0.05, Color(1.0, 0.85, 0.3, 0.3))
	if bool(info.get("cleared", false)):
		await _celebrate()
	state = nst.duplicate(true)
	_rebuild()
	_disp_cur = int(state.get("current", 0))
	_disp_next = int(state.get("next", 0))
	_swap_k = -1.0
	_animating = false
	unlock()


## Bubbles popped in rings outward from the landing cell.
func _pop_order(from: int, popped: Array) -> Array:
	var left := {}
	for c in popped:
		left[int(c)] = true
	var out: Array = []
	var frontier: Array = [from] if left.has(from) else [int(popped[0])]
	for c in frontier:
		left.erase(c)
	while not frontier.is_empty():
		out.append_array(frontier)
		var nxt: Array = []
		for c in frontier:
			for nb in BubbleShooter.neighbours(int(c) / COLS, int(c) % COLS):
				if left.has(nb):
					left.erase(nb)
					nxt.append(nb)
		frontier = nxt
	out.append_array(left.keys())
	return out


func _celebrate() -> void:
	_clear_t = time
	_chest_bump = time
	var c := P(CHEST_POS)
	MgBoard.sfx("fanfare")
	MgBoard.sfx("chest", 0.0, -2.0)
	for k in 4:
		burst(c, [Color("ffd84a"), Color("ff7ab0"), Color("7fe8ff"), Color("9dff8a")][k], 14, "star", 7.0 * _u, 1.0 * _u, 0.26 * _u)
	burst(P(Vector2(4.0, 0.2)), Color("fff3c0"), 30, "flake", 6.0 * _u, 3.0 * _u, 0.2 * _u)
	ring(c, Color("ffe07a"), _u * 3.0, 0.7, 0.2 * _u)
	float_text(c + Vector2(0, _u * 1.2), "BOARD CLEAR!", Color("ffe07a"), maxi(30, int(_u * 1.0)), 1.8)
	float_text(c + Vector2(0, _u * 2.6), "+%d" % BubbleShooter.CLEAR_BONUS, Color.WHITE, maxi(26, int(_u * 0.8)), 1.8)
	shake(9.0)
	kick.emit(1.0, Color(1.0, 0.85, 0.3, 0.45))
	await wait(1.1)


func _swap_in(cur: int, nxt: int) -> void:
	_swap_col = _disp_next
	_swap_k = 0.0
	var t := create_tween()
	t.tween_property(self, "_swap_k", 1.0, dur(0.32)).set_delay(dur(0.12)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_disp_next = -1
	await t.finished
	_swap_k = -1.0
	_disp_cur = cur
	_disp_next = nxt
	_next_born = time
	MgBoard.sfx("plink", 0.1, -8.0)


func _start_flight(path: Array, col: int, snaps: bool) -> void:
	var pts := PackedVector2Array()
	for q in path:
		pts.append(Vector2(float(q[0]), float(q[1])))
	if pts.size() < 2:
		pts.append(BubbleShooter.LAUNCH + Vector2(0, -1))
	var lens: Array = [0.0]
	for k in range(1, pts.size()):
		lens.append(float(lens[-1]) + pts[k].distance_to(pts[k - 1]))
	var bounces := {}
	var last_b := pts.size() - (2 if snaps else 1)
	for k in range(1, last_b):
		bounces[k] = true
	_trail.clear()
	_fly = {"pts": pts, "lens": lens, "total": float(lens[-1]), "d": 0.0, "col": col, "bounces": bounces, "next_b": 1}


## The fly position at distance d along the path (units) and the segment index.
func _fly_at(d: float) -> Array:
	var pts: PackedVector2Array = _fly.pts
	var lens: Array = _fly.lens
	for k in range(1, pts.size()):
		if d <= float(lens[k]) or k == pts.size() - 1:
			var seg := float(lens[k]) - float(lens[k - 1])
			var t := clampf((d - float(lens[k - 1])) / maxf(seg, 0.0001), 0.0, 1.0)
			return [pts[k - 1].lerp(pts[k], t), k]
	return [pts[-1], pts.size() - 1]


## Neighbours within reach wobble away from cell c.
func _ripple(c: int, strength: float) -> void:
	var at := cell_pos(c)
	for i in _vis:
		if int(i) == c:
			continue
		var d := cell_pos(int(i)) - at
		var l := d.length()
		if l < 2.6 and l > 0.01:
			var v: Dictionary = _vis[i]
			v.vel += d / l * strength * 2.6 * (1.0 - l / 2.8)


# --- per-frame -----------------------------------------------------------------------------

func _tick(dt: float) -> void:
	var sdt := dt * clampf(speed, 0.25, 4.0)
	# aim smoothing (real time)
	var target := BubbleShooter.angle_of(_aim_idx)
	if _cancel and _drag:
		target = 0.0
	_aim = lerpf(_aim, target, 1.0 - exp(-dt * 22.0))
	# wobble springs
	for i in _vis:
		var v: Dictionary = _vis[i]
		var off: Vector2 = v.off
		var vel: Vector2 = v.vel
		if off == Vector2.ZERO and vel == Vector2.ZERO:
			continue
		vel += (-off * 160.0 - vel * 11.0) * sdt
		off += vel * sdt
		if off.length() < 0.002 and vel.length() < 0.02:
			off = Vector2.ZERO
			vel = Vector2.ZERO
		v.off = off
		v.vel = vel
	# the flight
	if not _fly.is_empty():
		var d := float(_fly.d) + FLY_SPEED * sdt
		var total := float(_fly.total)
		var res := _fly_at(minf(d, total))
		var seg := int(res[1])
		while int(_fly.next_b) < seg:
			var b := int(_fly.next_b)
			_fly.next_b = b + 1
			if (_fly.bounces as Dictionary).has(b):
				_squash_t = time
				var bp: Vector2 = (_fly.pts as PackedVector2Array)[b]
				burst(P(bp), _bc(int(_fly.col)).lightened(0.4), 6, "spark", 3.5 * _u, 0.0, 0.12 * _u)
				ring(P(bp), Color(1, 1, 1, 0.6), _u * 0.5, 0.25, 0.07 * _u)
				MgBoard.sfx("plink", 0.12, -3.0)
		_fly.d = d
		_trail.push_front(res[0])
		if _trail.size() > 9:
			_trail.pop_back()
		if d >= total:
			_fly = {}
			_trail.clear()
	# falling bubbles: gravity, a bounce on the deck, then fade
	for i in range(_falling.size() - 1, -1, -1):
		var f: Dictionary = _falling[i]
		var v: Vector2 = f.v
		var p: Vector2 = f.p
		v.y += 34.0 * sdt
		p += v * sdt
		if p.x < 0.5 or p.x > COLS - 0.5:
			v.x = -v.x * 0.7
			p.x = clampf(p.x, 0.5, COLS - 0.5)
		var floor_y := DECK - 0.44
		if p.y > floor_y and v.y > 0.0:
			p.y = floor_y
			v.y = -v.y * 0.42
			v.x *= 0.8
			f.hits = int(f.hits) + 1
			if int(f.hits) == 1:
				f.fade = time
				_drop_pts += 1
				var bc := _bc(int(f.col))
				burst(P(p + Vector2(0, 0.4)), bc, 6, "chunk", 3.0 * _u, 2.0 * _u, 0.12 * _u)
				float_text(P(p), "+2", Color("ffe07a"), maxi(18, int(_u * 0.5)), 0.8)
				_pitched("plink", 0.85 + 0.05 * (_drop_pts % 8), -4.0)
				if _drop_pts % 3 == 1:
					MgBoard.sfx("chip_tick", 0.1, -6.0)
		f.v = v
		f.p = p
		f.rot = float(f.rot) + float(f.spin) * sdt
		if float(f.fade) >= 0.0 and time - float(f.fade) > dur(0.5):
			burst(P(p), _bc(int(f.col)).lightened(0.5), 4, "puff", 60.0, 10.0, 0.15 * _u)
			_falling.remove_at(i)
		elif p.y > BOT + 2.0:
			_falling.remove_at(i)


# --- drawing -----------------------------------------------------------------------------

func _bc(c: int) -> Color:
	return MgLogic.BUBBLE_COLORS[clampi(c, 0, 3)]


func _draw_board() -> void:
	_layout()
	var gc: Color = MgLogic.GAME_COLORS.get("bubble_shooter", Color("7f8cff"))
	var frame := Rect2(P(Vector2(-SIDE, TOP)), Vector2(COLS + SIDE * 2.0, BOT - TOP) * _u)
	var field := Rect2(P(Vector2(0, 0)), Vector2(COLS, BOT - SIDE * 0.5) * _u)
	var rad := _u * 0.55
	# cabinet
	rrect(Rect2(frame.position + Vector2(0, _u * 0.18), frame.size), Color(0, 0, 0, 0.45), rad)
	rrect(frame.grow(4.0), UiPalette.OUTLINE, rad + 4)
	rrect(frame, gc.darkened(0.45), rad)
	rrect(Rect2(frame.position, frame.size - Vector2(0, _u * 0.12)), gc.darkened(0.2), rad)
	# the deep water-glass backdrop
	var bands := 10
	for k in bands:
		var t := float(k) / (bands - 1)
		var r := Rect2(field.position.x, field.position.y + field.size.y * k / bands, field.size.x, field.size.y / bands + 1.0)
		draw_rect(r, Color("1d2466").lerp(Color("0b0d2a"), t))
	# light rays from above
	for k in 3:
		var x0 := field.position.x + field.size.x * (0.18 + 0.3 * k)
		var sway := sin(time * 0.35 + k * 1.7) * _u * 0.4
		var ray := PackedVector2Array([Vector2(x0 - _u * 0.4, field.position.y), Vector2(x0 + _u * 0.4, field.position.y),
			Vector2(x0 + _u * 1.4 + sway, field.end.y - _u * 2.0), Vector2(x0 - _u * 0.2 + sway, field.end.y - _u * 2.0)])
		draw_colored_polygon(ray, Color(0.6, 0.7, 1.0, 0.035))
	# drifting background bubbles (depth)
	for k in 16:
		var hx := float(hash(k * 131 + 7) % 1000) / 1000.0
		var sp := 0.05 + 0.05 * float(hash(k * 17) % 10) / 10.0
		var yy := fposmod(-time * sp + hx * 3.0, 1.0)
		var p := Vector2(field.position.x + _u * 0.4 + hx * (field.size.x - _u * 0.8) + sin(time * 0.8 + k) * _u * 0.12,
			field.position.y + _u * 0.4 + yy * (field.size.y - _u * 2.2))
		var br := _u * (0.06 + 0.14 * hx)
		draw_arc(p, br, 0.0, TAU, 14, Color(0.65, 0.8, 1.0, 0.16), maxf(1.0, _u * 0.035), true)
		draw_circle(p + Vector2(-br * 0.35, -br * 0.35), br * 0.25, Color(1, 1, 1, 0.12))
	_draw_chest()
	# the danger line (decorative)
	var dy := P(Vector2(0, DANGER)).y
	var pulse := 0.35 + 0.15 * sin(time * 2.2)
	var x := field.position.x + _u * 0.1
	while x < field.end.x - _u * 0.1:
		draw_line(Vector2(x, dy), Vector2(minf(x + _u * 0.3, field.end.x - _u * 0.1), dy), Color(1.0, 0.35, 0.4, pulse), maxf(2.0, _u * 0.06))
		x += _u * 0.5
	# launch deck
	var deck := Rect2(Vector2(field.position.x, P(Vector2(0, DECK)).y), Vector2(field.size.x, frame.end.y - P(Vector2(0, DECK)).y - _u * 0.12))
	draw_rect(deck, Color("141848"))
	draw_rect(Rect2(deck.position, Vector2(deck.size.x, maxf(2.0, _u * 0.07))), gc.lightened(0.1))
	draw_rect(Rect2(deck.position + Vector2(0, _u * 0.07), Vector2(deck.size.x, _u * 0.12)), Color(0, 0, 0, 0.25))
	# the aim guide
	if _can_shoot() and _disp_cur >= 0 and not (_drag and _cancel):
		_draw_guide()
	# the cluster
	for i in _vis:
		_draw_cell(int(i), _vis[i])
	# the bubble in flight
	if not _fly.is_empty():
		_draw_flight()
	_draw_launcher(gc)
	# falling (dropped) bubbles
	for f: Dictionary in _falling:
		var a := 1.0
		if float(f.fade) >= 0.0:
			a = clampf(1.0 - (time - float(f.fade)) / dur(0.5), 0.0, 1.0)
		_bubble(P(f.p), _u * 0.46, int(f.col), a, Vector2.ONE, float(f.rot) * 0.1)
	# walls + ceiling over the edges
	draw_rect(Rect2(frame.position.x, field.position.y, _u * SIDE, field.size.y), gc.darkened(0.2))
	draw_rect(Rect2(field.end.x, field.position.y, _u * SIDE, field.size.y), gc.darkened(0.2))
	draw_rect(Rect2(field.position.x - 2.0, field.position.y, 3.0, field.size.y), Color(UiPalette.OUTLINE, 0.9))
	draw_rect(Rect2(field.end.x - 1.0, field.position.y, 3.0, field.size.y), Color(UiPalette.OUTLINE, 0.9))
	var ceil_r := Rect2(frame.position + Vector2(_u * 0.12, _u * 0.12), Vector2(frame.size.x - _u * 0.24, -TOP * _u - _u * 0.12))
	rrect(ceil_r, Color("3a2a18"), _u * 0.2, 3, UiPalette.OUTLINE)
	rrect(Rect2(ceil_r.position + Vector2(3, 3), Vector2(ceil_r.size.x - 6, ceil_r.size.y * 0.45)), Color("c98a3a"), _u * 0.16)
	rrect(Rect2(ceil_r.position + Vector2(3, ceil_r.size.y * 0.45), Vector2(ceil_r.size.x - 6, ceil_r.size.y * 0.5 - 3)), Color("8a5a24"), _u * 0.12)
	for k in 9:
		if k == 4:
			continue
		var rp := Vector2(ceil_r.position.x + _u * 0.35 + (ceil_r.size.x - _u * 0.7) * k / 8.0, ceil_r.get_center().y)
		draw_circle(rp, _u * 0.09 + 1.5, UiPalette.OUTLINE)
		draw_circle(rp, _u * 0.09, Color("ffd27a"))
	# a gem plaque in the middle of the rail
	var gp := ceil_r.get_center()
	var gr := ceil_r.size.y * 0.62
	var gem := PackedVector2Array([gp + Vector2(0, -gr), gp + Vector2(gr * 0.9, 0), gp + Vector2(0, gr), gp + Vector2(-gr * 0.9, 0)])
	draw_colored_polygon(gem, UiPalette.OUTLINE)
	var gem_in := PackedVector2Array()
	for q in gem:
		gem_in.append(gp + (q - gp) * 0.72)
	draw_colored_polygon(gem_in, Color("7fe8ff"))
	draw_colored_polygon(PackedVector2Array([gem_in[0], gem_in[1], gp]), Color("c9f6ff"))
	_star4(gp + Vector2(gr * 0.5, -gr * 0.5), gr * (0.25 + 0.15 * sin(time * 3.0)), Color(1, 1, 1, 0.8))
	if _drag and _cancel:
		var cp := P(BubbleShooter.LAUNCH + Vector2(0, -1.6))
		text_c(cp, "RELEASE TO CANCEL", maxi(13, int(_u * 0.36)), UiPalette.TEXT_DIM, maxi(4, int(_u * 0.12)))
	elif not _touched and _can_shoot() and int(state.get("actions_left", 0)) == BubbleShooter.SHOTS:
		var cp := P(Vector2(4.0, 8.2))
		var a := 0.55 + 0.35 * sin(time * 3.0)
		text_c(cp, "DRAG TO AIM  -  RELEASE TO SHOOT", maxi(12, int(_u * 0.32)), Color(1, 1, 1, a), maxi(4, int(_u * 0.1)))


func _draw_chest() -> void:
	var c := P(CHEST_POS)
	var s := _u * 3.3
	var bump := clampf(1.0 - (time - _chest_bump) / 0.8, 0.0, 1.0)
	var cleared := bool(state.get("cleared", false)) or _clear_t > -500.0
	s *= 1.0 + 0.25 * sin(bump * PI) + (0.12 if cleared else 0.0)
	c.y += sin(time * 1.1) * _u * 0.06
	glow(c, s * (0.62 + 0.04 * sin(time * 2.0)), Color(1.0, 0.8, 0.35, 0.9 if cleared else 0.55), 8)
	var tex: Texture2D = ModelIcons.get_icon(ModelIcons.GEM_CHEST, 28.0)
	if tex:
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	else:
		var bw := s * 0.62
		var body := Rect2(c + Vector2(-bw * 0.5, -s * 0.05), Vector2(bw, s * 0.34))
		rrect(body.grow(3.0), UiPalette.OUTLINE, s * 0.06)
		rrect(body, Color("8a4f24"), s * 0.05)
		var lid := Rect2(c + Vector2(-bw * 0.5, -s * 0.24), Vector2(bw, s * 0.2))
		rrect(lid.grow(3.0), UiPalette.OUTLINE, s * 0.08)
		rrect(lid, Color("a8622c"), s * 0.08)
		draw_rect(Rect2(c + Vector2(-bw * 0.5, -s * 0.06), Vector2(bw, s * 0.05)), Color("ffcf4a"))
		draw_circle(c + Vector2(0, -s * 0.2), s * 0.07, Color("7fe8ff"))
		draw_circle(c + Vector2(-s * 0.14, -s * 0.18), s * 0.05, Color("ff6fae"))
	for k in 6:
		var a := time * 0.6 + k * TAU / 6.0
		var tw := 0.5 + 0.5 * sin(time * 3.0 + k * 1.9)
		_star4(c + Vector2(cos(a) * s * 0.5, sin(a) * s * 0.34), _u * (0.08 + 0.1 * tw), Color(1, 0.95, 0.7, 0.5 * tw))


func _draw_guide() -> void:
	var grid: Array = state.get("grid", [])
	var key := "%d|%s" % [_aim_idx, str(grid.hash())]
	if key != _guide_key:
		_guide_key = key
		_guide = guide_points(BubbleShooter.trace(grid, _aim_idx).path)
	if _guide.size() < 2:
		return
	var active := _drag or _hover
	var base := _bc(_disp_cur).lightened(0.35)
	var total := 0.0
	for k in range(1, _guide.size()):
		total += (_guide[k] as Vector2).distance_to(_guide[k - 1])
	var gap := 0.42
	var d := 0.95 + fposmod(time * 1.4, gap)
	while d < total:
		var p := _along(_guide, d)
		var fade := 1.0 - clampf((d - (total - 1.2)) / 1.2, 0.0, 1.0) if _guide.size() > 2 else 1.0
		var a := (0.95 if active else 0.5) * fade
		var r := _u * (0.11 if active else 0.085) * (1.0 - 0.3 * d / maxf(total, 1.0))
		draw_circle(P(p), r + 1.5, Color(UiPalette.OUTLINE, a * 0.7))
		draw_circle(P(p), r, Color(base, a))
		d += gap
	if _guide.size() > 2:
		var bp := P(_guide[1])
		draw_arc(bp, _u * 0.22, 0.0, TAU, 18, Color(1, 1, 1, 0.55 if active else 0.3), maxf(2.0, _u * 0.05), true)


static func _along(pts: Array, d: float) -> Vector2:
	var left := d
	for k in range(1, pts.size()):
		var a: Vector2 = pts[k - 1]
		var b: Vector2 = pts[k]
		var l := a.distance_to(b)
		if left <= l:
			return a.lerp(b, left / maxf(l, 0.0001))
		left -= l
	return pts[-1]


func _draw_cell(i: int, v: Dictionary) -> void:
	var ctr := cell_pos(i)
	var ph := float(i) * 0.83
	var idle := Vector2(sin(time * 1.3 + ph) * 0.018, sin(time * 1.7 + ph * 1.3) * 0.024)
	var p := P(ctr + (v.off as Vector2) + idle)
	var sc := Vector2(1.0 + 0.02 * sin(time * 2.2 + ph), 1.0 + 0.02 * sin(time * 2.2 + ph + 1.5))
	var a := 1.0
	if float(v.shake) >= 0.0:
		p.x += sin((time - float(v.shake)) * 70.0) * _u * 0.06
	if v.has("born"):
		var bk := clampf((time - float(v.born)) / dur(0.25), 0.0, 1.0)
		var sq := sin(bk * PI) * 0.18 * (1.0 - bk)
		sc *= Vector2(1.0 + sq, 1.0 - sq)
	if float(v.pop) >= 0.0:
		var pk := (time - float(v.pop)) / dur(0.11)
		if pk >= 1.0:
			return
		sc *= 1.0 + 0.4 * pk
		a = 1.0 - pk
	_bubble(p, _u * 0.47, int(v.col), a, sc)


func _draw_flight() -> void:
	var col := int(_fly.col)
	var bc := _bc(col)
	for k in range(_trail.size() - 1, 0, -1):
		var t := 1.0 - float(k) / _trail.size()
		draw_circle(P(_trail[k]), _u * 0.4 * t, Color(bc.lightened(0.3), 0.28 * t))
	var res := _fly_at(float(_fly.d))
	var p: Vector2 = res[0]
	var pts: PackedVector2Array = _fly.pts
	var seg := int(res[1])
	var dir := (pts[seg] - pts[seg - 1]).normalized() if seg > 0 else Vector2.UP
	var sq := clampf(1.0 - (time - _squash_t) / dur(0.12), 0.0, 1.0)
	var rot := dir.angle()
	var sc := Vector2(1.14 - 0.34 * sq, 0.9 + 0.3 * sq)
	glow(P(p), _u * 0.9, Color(bc, 0.5), 5)
	_bubble(P(p), _u * 0.47, col, 1.0, sc, rot)


func _draw_launcher(gc: Color) -> void:
	var lp := P(BubbleShooter.LAUNCH)
	var u := _u
	var rk := clampf(1.0 - (time - _recoil_t) / dur(0.25), 0.0, 1.0)
	var recoil := sin(rk * PI) * 0.22 * rk
	# body: a round critter sitting on the deck
	var body_c := lp + Vector2(0, u * 0.55)
	var squash := 1.0 + recoil * 0.6
	draw_set_transform(body_c, 0.0, Vector2(squash, 1.0 / squash))
	draw_circle(Vector2(0, u * 0.1), u * 0.84, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, u * 0.82 + 3.0, UiPalette.OUTLINE)
	draw_circle(Vector2.ZERO, u * 0.82, gc.darkened(0.3))
	draw_circle(Vector2(0, -u * 0.06), u * 0.75, gc)
	draw_circle(Vector2(-u * 0.3, -u * 0.35), u * 0.16, Color(1, 1, 1, 0.35))
	draw_set_transform(Vector2.ZERO)
	# the nozzle (rotates with the aim)
	draw_set_transform(lp, _aim)
	var nz := Rect2(Vector2(-u * 0.3, -u * (1.18 - recoil)), Vector2(u * 0.6, u * 0.62))
	rrect(nz.grow(3.0), UiPalette.OUTLINE, u * 0.16)
	rrect(nz, Color("d9def5"), u * 0.14)
	rrect(Rect2(nz.position, Vector2(nz.size.x, u * 0.16)), Color("ffd84a"), u * 0.08)
	draw_rect(Rect2(nz.position + Vector2(u * 0.08, u * 0.2), Vector2(u * 0.08, nz.size.y * 0.55)), Color(1, 1, 1, 0.6))
	draw_set_transform(Vector2.ZERO)
	# the ring holding the loaded bubble
	draw_circle(lp, u * 0.6 + 3.0, UiPalette.OUTLINE)
	draw_circle(lp, u * 0.6, Color("2a2f6e"))
	draw_arc(lp, u * 0.55, PI * 1.1, PI * 1.9, 16, Color(1, 1, 1, 0.25), maxf(2.0, u * 0.06), true)
	var out_of_shots := not _animating and int(state.get("actions_left", 0)) <= 0
	if _disp_cur >= 0 and not out_of_shots:
		_bubble(lp, u * 0.47, _disp_cur, 1.0, Vector2.ONE * (1.0 + 0.03 * sin(time * 3.0)))
	# eyes on the body, looking where it aims
	var look := Vector2(sin(_aim), -cos(_aim)) * u * 0.05
	var blink := 1.0 if fposmod(time, 3.7) > 0.12 else 0.15
	for s in [-1.0, 1.0]:
		var e := body_c + Vector2(s * u * 0.3, u * 0.38)
		draw_set_transform(e, 0.0, Vector2(1.0, blink))
		draw_circle(Vector2.ZERO, u * 0.13 + 2.0, UiPalette.OUTLINE)
		draw_circle(Vector2.ZERO, u * 0.13, Color.WHITE)
		draw_circle(look, u * 0.07, UiPalette.OUTLINE)
		draw_circle(look + Vector2(-u * 0.025, -u * 0.03), u * 0.025, Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		draw_circle(body_c + Vector2(s * u * 0.55, u * 0.55), u * 0.09, Color(1.0, 0.5, 0.65, 0.5))
	# the next bubble in its cup, rolling in after each shot
	var np := P(NEXT_POS)
	var cup := Rect2(np + Vector2(-u * 0.52, -u * 0.1), Vector2(u * 1.04, u * 0.62))
	rrect(cup.grow(3.0), UiPalette.OUTLINE, u * 0.26)
	rrect(cup, gc.darkened(0.35), u * 0.24)
	text_c(np + Vector2(0, u * 0.66), "NEXT", maxi(11, int(u * 0.26)), UiPalette.TEXT_DIM, maxi(3, int(u * 0.08)))
	if _swap_k >= 0.0 and _swap_col >= 0:
		var to := lp
		var q := np.lerp(to, _swap_k) + Vector2(0, -sin(_swap_k * PI) * u * 0.9)
		_bubble(q, u * lerpf(0.36, 0.47, _swap_k), _swap_col, 1.0, Vector2.ONE)
	if _disp_next >= 0 and not out_of_shots:
		var bk := clampf((time - _next_born) / dur(0.3), 0.0, 1.0)
		var s := ease(bk, 0.4) * (1.0 + 0.2 * sin(bk * PI))
		_bubble(np, u * 0.36 * s, _disp_next, 1.0, Vector2.ONE)
	# shots left: a rack of mini bubbles
	var left := int(state.get("actions_left", 0))
	if _animating and _disp_cur < 0:
		left = maxi(0, left - 1)
	var rack := P(Vector2(5.7, 11.3))
	for k in BubbleShooter.SHOTS:
		var rp := rack + Vector2((k % 5) * u * 0.36, (k / 5) * u * 0.36)
		draw_circle(rp, u * 0.13 + 1.5, UiPalette.OUTLINE)
		draw_circle(rp, u * 0.13, Color("ffd84a") if k < left else Color(1, 1, 1, 0.12))
		if k < left:
			draw_circle(rp + Vector2(-u * 0.04, -u * 0.04), u * 0.04, Color(1, 1, 1, 0.8))
	text_c(rack + Vector2(u * 0.72, u * 0.8), "SHOTS", maxi(11, int(u * 0.26)), UiPalette.TEXT_DIM, maxi(3, int(u * 0.08)))


## A glossy bubble with its colour-blind glyph.
func _bubble(p: Vector2, r: float, col: int, a: float, sc := Vector2.ONE, rot := 0.0) -> void:
	var base := _bc(col)
	draw_set_transform(p, rot, sc)
	draw_circle(Vector2(0, r * 0.1), r * 1.04, Color(0, 0, 0, 0.3 * a))
	draw_circle(Vector2.ZERO, r * 1.03, Color(UiPalette.OUTLINE, a))
	draw_circle(Vector2.ZERO, r * 0.95, Color(base.darkened(0.35), a))
	draw_circle(Vector2(0, -r * 0.06), r * 0.86, Color(base, a))
	draw_circle(Vector2(-r * 0.12, -r * 0.2), r * 0.6, Color(base.lightened(0.18), a))
	draw_set_transform(p, 0.0, sc)
	draw_circle(Vector2(-r * 0.36, -r * 0.4), r * 0.2, Color(1, 1, 1, 0.85 * a))
	draw_circle(Vector2(-r * 0.12, -r * 0.54), r * 0.08, Color(1, 1, 1, 0.7 * a))
	draw_arc(Vector2.ZERO, r * 0.74, 0.3, 1.3, 10, Color(1, 1, 1, 0.25 * a), r * 0.08, true)
	_glyph(col, Vector2(r * 0.1, r * 0.12), r * 0.3, Color(1, 1, 1, 0.5 * a))
	draw_set_transform(Vector2.ZERO)


## A small symbol per colour (heart, drop, diamond, star), the same as Bubble Breaker's.
func _glyph(kind: int, at: Vector2, s: float, col: Color) -> void:
	match kind:
		0:
			draw_circle(at + Vector2(-s * 0.42, -s * 0.2), s * 0.48, col)
			draw_circle(at + Vector2(s * 0.42, -s * 0.2), s * 0.48, col)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.88, 0.0), at + Vector2(s * 0.88, 0.0), at + Vector2(0, s * 0.95)]), col)
		1:
			draw_circle(at + Vector2(0, s * 0.25), s * 0.6, col)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.55, s * 0.05), at + Vector2(0, -s * 0.95), at + Vector2(s * 0.55, s * 0.05)]), col)
		2:
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s), at + Vector2(s * 0.75, 0), at + Vector2(0, s), at + Vector2(-s * 0.75, 0)]), col)
		_:
			_star4(at, s * 1.05, col)


## Plays an sfx at a given pitch (rising pop chains). Audio has no pitch argument, so this
## sets the pitch on the pool player it just used (local workaround; see the WP-E5 report).
static func _pitched(id: String, pitch: float, volume_db := 0.0) -> void:
	var loop := Engine.get_main_loop() as SceneTree
	var a: Node = loop.root.get_node_or_null("Audio") if loop else null
	if a == null or not a.has_method("play_sfx"):
		return
	a.call("play_sfx", id, 0.0, volume_db)
	var pool: Variant = a.get("_pool")
	var nx: Variant = a.get("_next")
	if pool is Array and nx is int and (pool as Array).size() > 0:
		var pl := (pool as Array)[(int(nx) - 1 + (pool as Array).size()) % (pool as Array).size()] as AudioStreamPlayer
		if pl and pl.stream:
			pl.pitch_scale = clampf(pitch, 0.5, 2.0)

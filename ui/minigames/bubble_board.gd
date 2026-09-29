class_name BubbleBoard
extends MgBoard
## Bubble Breaker: a 6x6 tank of glossy bubbles in 4 colours (y = 0 is the bottom row).
## Press a bubble to light up its group, release to pop a group of 3+ ([x, y]). The core
## answers with the popped cells; they burst from the tapped bubble outward, then the rest
## fall and empty columns slide left (MgLogic.bubble_moves, checked against the core grid).
## The chain meter fills while pops of 4+ follow each other.

const W := 6
const H := 6

var _grid := Rect2()
var _cell := 60.0
## Visual bubbles: {cell, col, pos (grid coords, float), scale, alive, pop}.
var _bubbles: Array = []
var _hover: Array = []
var _press := -1
var _animating := false
var _chain_pulse := -10.0
var _bad := {}   # cell -> time (a group too small: jiggle)


func set_state(st: Dictionary, instant := true) -> void:
	super.set_state(st, instant)
	if instant or not _animating:
		_rebuild()
	unlock()


func _rebuild() -> void:
	_bubbles.clear()
	var grid: Array = state.get("grid", [])
	for i in grid.size():
		if int(grid[i]) >= 0:
			_bubbles.append({"cell": i, "col": int(grid[i]), "pos": Vector2(i / H, i % H), "scale": 1.0, "alive": true, "pop": -1.0})


func is_settled() -> bool:
	return not _animating


func status_text() -> String:
	var ch := int(state.get("chain", 0))
	return "Chain x%d" % ch if ch >= 2 else ""


func _layout() -> void:
	var header := 86.0
	var avail := Vector2(size.x, size.y - header)
	var s := minf(avail.x, avail.y)
	_cell = (s - 40.0) / float(W)
	var gs := _cell * W
	_grid = Rect2(Vector2((size.x - gs) * 0.5, header + (avail.y - gs) * 0.5), Vector2(gs, gs))


## Screen centre of grid coords (x, y) with y = 0 at the bottom.
func to_screen(g: Vector2) -> Vector2:
	return _grid.position + Vector2(g.x + 0.5, H - g.y - 0.5) * _cell


func cell_at(p: Vector2) -> int:
	if not _grid.has_point(p):
		return -1
	var q := ((p - _grid.position) / _cell).floor()
	var x := int(q.x)
	var y := H - 1 - int(q.y)
	return x * H + y


func _gui_input(e: InputEvent) -> void:
	_layout()
	var mb := e as InputEventMouseButton
	var mm := e as InputEventMouseMotion
	var grid: Array = state.get("grid", [])
	if mm and _press >= 0:
		var i := cell_at(mm.position)
		if i != _press and i >= 0:
			_press = i
			_hover = MgLogic.bubble_cluster(grid, i / H, i % H, W, H)
		return
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var i := cell_at(mb.position)
	if mb.pressed:
		if locked or _animating or i < 0:
			return
		_press = i
		_hover = MgLogic.bubble_cluster(grid, i / H, i % H, W, H)
		if _hover.size() >= int(state.get("min_cluster", 3)):
			MgBoard.sfx("tick")
		return
	var cl := _hover
	_press = -1
	_hover = []
	if i < 0 or locked or _animating or not cl.has(i):
		return
	if cl.size() < int(state.get("min_cluster", 3)):
		for c in cl:
			_bad[c] = time
		MgBoard.sfx("error")
		float_text(to_screen(Vector2(i / H, i % H)), "Need 3+", UiPalette.TEXT_DIM, 24, 0.7)
		return
	send([i / H, i % H])


func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	_layout()
	_animating = true
	_hover = []
	var info: Dictionary = ev.get("info", {})
	var popped: Array = info.get("cells", [])
	var old_grid: Array = state.get("grid", [])
	var tap := int(info.get("x", 0)) * H + int(info.get("y", 0))
	var col: Color = MgLogic.BUBBLE_COLORS[clampi(int(info.get("color", 0)), 0, 3)]
	# pop order: rings outward from the tapped bubble
	var dist := {tap: 0}
	var frontier: Array = [tap]
	var gone := {}
	for c in popped:
		gone[int(c)] = true
	while not frontier.is_empty():
		var nxt: Array = []
		for c in frontier:
			for d: int in [H, -H, 1, -1]:
				var n := int(c) + d
				if gone.has(n) and not dist.has(n) and not (absi(d) == 1 and int(c) / H != n / H):
					dist[n] = int(dist[c]) + 1
					nxt.append(n)
		frontier = nxt
	var n := popped.size()
	var step := dur(0.055)
	for b: Dictionary in _bubbles:
		if gone.has(int(b.cell)):
			b.pop = time + float(dist.get(int(b.cell), 0)) * step
	var last := 0
	for c in dist:
		last = maxi(last, int(dist[c]))
	var centre := Vector2.ZERO
	for c in popped:
		centre += to_screen(Vector2(int(c) / H, int(c) % H))
	centre /= maxf(1.0, n)
	# bursts as each ring pops
	for ringi in last + 1:
		var any := false
		for c in popped:
			if int(dist.get(int(c), 0)) == ringi:
				any = true
				var p := to_screen(Vector2(int(c) / H, int(c) % H))
				burst(p, col, 7, "spark", 320.0, 40.0, 8.0)
				burst(p, col.lightened(0.4), 3, "flake", 220.0, 120.0, 7.0)
				ring(p, col.lightened(0.3), _cell * 0.55, 0.35, 5.0)
		if any:
			MgBoard.sfx("pop", 0.12, -2.0 + ringi * 0.5)
		await get_tree().create_timer(step, false).timeout
	await wait(0.12)
	var chain := int(info.get("chain", 0))
	var big := n >= 6
	var txt := "+%d" % n
	if big:
		txt = "BIG POP! +%d" % (n + (n - 5))
	float_text(centre, txt, col.lightened(0.45), 40 if big else 34, 1.1)
	if chain >= 2:
		_chain_pulse = time
		float_text(centre + Vector2(0, 56), "CHAIN x%d!" % chain, Color("ffb13d"), 34, 1.2)
		MgBoard.sfx("buff")
	shake(4.0 + minf(n, 10) * 0.8)
	kick.emit(0.25 + minf(n, 12) * 0.04, Color(col.r, col.g, col.b, 0.3))
	# gravity: every survivor slides to its new cell
	var moves := MgLogic.bubble_moves(old_grid, popped, W, H)
	for b: Dictionary in _bubbles:
		if gone.has(int(b.cell)):
			b.alive = false
	var tw := create_tween().set_parallel(true)
	var moved := false
	for b: Dictionary in _bubbles:
		if not b.alive or not moves.has(int(b.cell)):
			continue
		var to := int(moves[int(b.cell)])
		var from_v: Vector2 = b.pos
		var to_v := Vector2(to / H, to % H)
		if from_v != to_v:
			moved = true
			var delay := dur(0.02 * from_v.x + 0.015 * from_v.y)
			var d := dur(0.18 + 0.07 * (from_v - to_v).length())
			tw.tween_method(func(v: Vector2) -> void: b.pos = v, from_v, to_v, d).set_delay(delay) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if moved:
		await tw.finished
	else:
		tw.kill()
	state = (ev.get("state", {}) as Dictionary).duplicate(true)
	_rebuild()
	_animating = false
	if bool(state.get("done", false)) and int(state.get("actions_left", 0)) > 0:
		float_text(_grid.get_center(), "No more groups!", UiPalette.TEXT, 34, 1.3)
	unlock()


func _draw_board() -> void:
	_layout()
	_draw_header()
	# the tank
	var tank := _grid.grow(16.0)
	rrect(tank.grow(4.0), UiPalette.OUTLINE, 32)
	rrect(tank, Color("12305a"), 30)
	rrect(tank.grow(-6.0), Color("0b1d3a"), 26)
	rrect(Rect2(tank.position + Vector2(6, 6), Vector2(tank.size.x - 12, tank.size.y * 0.35)), Color(0.3, 0.6, 1.0, 0.07), 26)
	# rising background fizz
	for k in 14:
		var hx := float(hash(k * 131) % 1000) / 1000.0
		var sp := 0.08 + 0.05 * float(hash(k * 17) % 10) / 10.0
		var yy := fposmod(-time * sp + hx * 3.0, 1.0)
		var p := Vector2(tank.position.x + 20 + hx * (tank.size.x - 40), tank.position.y + 12 + yy * (tank.size.y - 24))
		draw_arc(p, 3.0 + 4.0 * hx, 0.0, TAU, 12, Color(0.6, 0.85, 1.0, 0.18), 1.5, true)
	draw_rect(Rect2(tank.position + Vector2(18, 10), Vector2(10, tank.size.y - 20)), Color(1, 1, 1, 0.04))
	var hov := {}
	for c in _hover:
		hov[int(c)] = true
	var can := _hover.size() >= int(state.get("min_cluster", 3)) and not locked
	for b: Dictionary in _bubbles:
		_draw_bubble(b, hov.has(int(b.cell)), can)
	if can and not _hover.is_empty():
		var p := to_screen(Vector2(_press / H, _press % H))
		var n := _hover.size()
		text_c(p + Vector2(0, -_cell * 0.72), "+%d" % n, 30, Color.WHITE, 8)


func _draw_bubble(b: Dictionary, hovered: bool, can: bool) -> void:
	var t := time
	var alive: bool = b.alive
	var pk := -1.0
	if float(b.pop) >= 0.0:
		pk = (t - float(b.pop)) / dur(0.12)
		if pk >= 1.0:
			return
	elif not alive:
		return
	var c := to_screen(b.pos)
	var ci := int(b.cell)
	var base: Color = MgLogic.BUBBLE_COLORS[clampi(int(b.col), 0, 3)]
	var r := _cell * 0.44
	# idle breathing, hover lift, pop inflate
	var ph := float(ci) * 0.7
	var sx := 1.0 + 0.025 * sin(t * 2.4 + ph)
	var sy := 1.0 + 0.025 * sin(t * 2.4 + ph + 1.6)
	if hovered and can:
		var k := 1.08 + 0.04 * sin(t * 12.0)
		sx *= k
		sy *= k
	if _bad.has(ci) and t - float(_bad[ci]) < 0.35:
		c.x += sin((t - float(_bad[ci])) * 60.0) * 4.0
	if pk >= 0.0:
		var k := 1.0 + 0.45 * pk
		sx *= k
		sy *= k
	draw_set_transform(c, 0.0, Vector2(sx, sy))
	var a := 1.0 - maxf(pk, 0.0)
	draw_circle(Vector2(0, r * 0.1), r * 1.04, Color(0, 0, 0, 0.35 * a))
	draw_circle(Vector2.ZERO, r * 1.02, Color(UiPalette.OUTLINE, a))
	draw_circle(Vector2.ZERO, r * 0.95, Color(base.darkened(0.35), a))
	draw_circle(Vector2(0, -r * 0.06), r * 0.86, Color(base, a))
	draw_circle(Vector2(-r * 0.12, -r * 0.2), r * 0.6, Color(base.lightened(0.18), a))
	draw_circle(Vector2(-r * 0.36, -r * 0.4), r * 0.2, Color(1, 1, 1, 0.85 * a))
	draw_circle(Vector2(-r * 0.12, -r * 0.52), r * 0.08, Color(1, 1, 1, 0.7 * a))
	draw_arc(Vector2.ZERO, r * 0.74, 0.3, 1.3, 10, Color(1, 1, 1, 0.25 * a), r * 0.08, true)
	_glyph(int(b.col), Vector2(r * 0.12, r * 0.14), r * 0.3, Color(1, 1, 1, 0.42 * a))
	if hovered:
		var hc := Color.WHITE if can else Color(1, 1, 1, 0.35)
		draw_arc(Vector2.ZERO, r * 1.02, 0.0, TAU, 32, hc, 4.0, true)
	draw_set_transform(Vector2.ZERO)


## A small symbol per colour (heart, drop, leaf, star) so groups read without colour.
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


func _draw_header() -> void:
	# chain meter: 5 flame segments, lit by the current chain
	var ch := int(state.get("chain", 0))
	var w := minf(size.x - 40.0, 420.0)
	var r := Rect2((size.x - w) * 0.5, 16, w, 52)
	rrect(r, Color(0.04, 0.05, 0.13, 0.85), 26, 2, UiPalette.GOLD_FAINT)
	text_c(Vector2(r.position.x + 62, r.get_center().y), "CHAIN", 24, UiPalette.GOLD, 5)
	var seg_w := (w - 140.0) / 5.0
	var pulse := clampf(1.0 - (time - _chain_pulse) / 0.6, 0.0, 1.0)
	for k in 5:
		var sr := Rect2(r.position.x + 120 + k * seg_w, r.position.y + 12, seg_w - 6, 28)
		var lit := k < ch
		var col := Color("ff7a2e").lerp(Color("ffd84a"), float(k) / 4.0)
		rrect(sr, col if lit else Color(1, 1, 1, 0.08), 10)
		if lit:
			rrect(Rect2(sr.position + Vector2(3, 3), Vector2(sr.size.x - 6, 8)), Color(1, 1, 1, 0.35), 4)
			if pulse > 0.0:
				glow(sr.get_center(), 30.0 * (1.0 + pulse), Color(col.r, col.g, col.b, pulse))

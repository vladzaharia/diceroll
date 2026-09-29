class_name FossilBoard
extends MgBoard
## Fossil Hunter: a 5x5 dig site of dirt mounds. Tap a mound to dig ([x, y]). The core
## answers with the dug cell: an empty hole shows the distance to the nearest bone (hot red
## 1 ... cool blue 4+), a hit shows a bone piece, and a finished fossil turns its bones gold
## and links them into a skeleton. Hidden fossils are never drawn: only public cells.

const DIRT := Color("8a5a36")
const DIRT_TOP := Color("b07a4a")
const SOIL := Color("3a2618")
const HINT_COLORS := [Color("ff4d4d"), Color("ff4d4d"), Color("ff9a3a"), Color("ffd24a"), Color("7fd0ff"), Color("8fa4ff")]

var _grid := Rect2()
var _cell := 60.0
## Per-cell reveal start time (-1 = none), and the press squash.
var _reveal := {}
var _press := -1
var _dig := {}   # cell -> start time of the shovel strike
var _glow_until := 0.0


func set_state(st: Dictionary, instant := true) -> void:
	super.set_state(st, instant)
	if instant:
		_reveal.clear()
	unlock()


func is_settled() -> bool:
	for k in _reveal:
		if time - float(_reveal[k]) < 0.5:
			return false
	return _dig.is_empty()


func status_text() -> String:
	var fs: Array = state.get("fossils", [])
	var found := 0
	for f: Dictionary in fs:
		if bool(f.found):
			found += 1
	return "Fossils %d / %d" % [found, fs.size()]


func _layout() -> void:
	var header := 86.0
	var avail := Vector2(size.x, size.y - header)
	var s := minf(avail.x, avail.y)
	_cell = (s - 36.0) / 5.0
	var gs := _cell * 5.0
	_grid = Rect2(Vector2((size.x - gs) * 0.5, header + (avail.y - gs) * 0.5), Vector2(gs, gs))


func cell_rect(i: int) -> Rect2:
	var x := i % 5
	var y := i / 5
	return Rect2(_grid.position + Vector2(x, y) * _cell, Vector2(_cell, _cell)).grow(-4.0)


func cell_at(p: Vector2) -> int:
	if not _grid.has_point(p):
		return -1
	var q := ((p - _grid.position) / _cell).floor()
	return int(q.y) * 5 + int(q.x)


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_layout()
	var i := cell_at(mb.position)
	if mb.pressed:
		_press = i
		return
	var was := _press
	_press = -1
	if i < 0 or i != was or locked:
		return
	var cells: Array = state.get("cells", [])
	if i >= cells.size() or String(cells[i]) != "?":
		MgBoard.sfx("error")
		return
	_dig[i] = time
	MgBoard.sfx("dig")
	send([i % 5, i / 5])


func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	_layout()
	var info: Dictionary = ev.get("info", {})
	var x := int(info.get("x", 0))
	var y := int(info.get("y", 0))
	var i := y * 5 + x
	var r := cell_rect(i)
	var c := r.get_center()
	# the shovel strikes (if the tap didn't start it, e.g. AUTO / a scripted action)
	if not _dig.has(i):
		_dig[i] = time
		MgBoard.sfx("dig")
	await wait(0.16)
	burst(c, DIRT_TOP, 16, "chunk", 380.0, 260.0, 9.0)
	burst(c, DIRT.darkened(0.2), 10, "chunk", 300.0, 200.0, 6.0)
	burst(c + Vector2(0, _cell * 0.2), Color(0.85, 0.72, 0.55, 0.9), 6, "puff", 90.0, 30.0, 16.0)
	shake(5.0)
	_dig.erase(i)
	var prev: Array = state.get("cells", []).duplicate()
	state = (ev.get("state", {}) as Dictionary).duplicate(true)
	_reveal[i] = time
	if bool(info.get("hit", false)):
		MgBoard.sfx("clink")
		burst(c, Color("fff2c8"), 14, "star", 240.0, 60.0, 9.0)
		ring(c, Color("ffe08a"), _cell * 0.7)
		kick.emit(0.35, Color(1.0, 0.9, 0.6, 0.35))
		var done := int(info.get("complete", 0))
		if done > 0:
			await wait(0.3)
			var cells: Array = state.get("cells", [])
			for k in cells.size():
				if String(cells[k]) == "bone" and String(prev[k]) != "bone":
					_reveal[k] = time
					burst(cell_rect(k).get_center(), Color("ffd96a"), 10, "star", 200.0, 40.0, 10.0)
			_glow_until = time + 2.0
			MgBoard.sfx("win")
			shake(9.0)
			kick.emit(0.8, Color(1.0, 0.85, 0.4, 0.45))
			float_text(c + Vector2(0, -_cell * 0.3), "FOSSIL! +%d" % (done + 2), Color("ffe07a"), 44, 1.3)
			await wait(0.7)
		else:
			float_text(c + Vector2(0, -_cell * 0.3), "BONE! +1", Color("fff0c0"), 36)
			await wait(0.45)
	else:
		var hint := int(info.get("hint", -1))
		MgBoard.sfx("tick")
		float_text(c + Vector2(0, -_cell * 0.25), ["", "HOT!", "Warm", "Cool", "Cold"][clampi(hint, 0, 4)] if hint <= 4 else "Cold",
			HINT_COLORS[clampi(hint, 0, 5)], 26, 0.8)
		await wait(0.35)
	unlock()


func _draw_board() -> void:
	_layout()
	var cells: Array = state.get("cells", [])
	var hints: Array = state.get("hints", [])
	_draw_header()
	# dig site: wooden frame and soil bed
	var frame := _grid.grow(18.0)
	rrect(frame.grow(4.0), UiPalette.OUTLINE, 30)
	rrect(frame, Color("6b4526"), 28)
	rrect(Rect2(frame.position, Vector2(frame.size.x, frame.size.y - 8)), Color("8d5d34"), 28)
	for k in 5:
		var yy := frame.position.y + 6 + k * (frame.size.y - 12) / 5.0
		draw_line(Vector2(frame.position.x + 16, yy), Vector2(frame.end.x - 16, yy), Color(0, 0, 0, 0.12), 2.0)
	rrect(_grid.grow(6.0), SOIL, 18)
	for i in cells.size():
		_draw_cell(i, String(cells[i]), int(hints[i]) if i < hints.size() else -1)
	# shovel strikes
	for i in _dig:
		var k := clampf((time - float(_dig[i])) / dur(0.18), 0.0, 1.0)
		_draw_shovel(cell_rect(int(i)).get_center() + Vector2(_cell * 0.28, -_cell * (0.75 - 0.45 * k)), -0.6 + 0.5 * k)


func _draw_header() -> void:
	var fs: Array = state.get("fossils", [])
	var total := 0.0
	for f: Dictionary in fs:
		total += int(f.size) * 34.0 + 50.0
	var x := (size.x - total) * 0.5
	for f: Dictionary in fs:
		var n := int(f.size)
		var w := n * 34.0 + 24.0
		var r := Rect2(x, 14, w, 56)
		var found := bool(f.found)
		rrect(r, Color("2a1d14") if not found else Color("5a3d12"), 24, 3, UiPalette.GOLD_FAINT if not found else UiPalette.GOLD_BRIGHT)
		if found:
			glow(r.get_center(), w * 0.7, Color(1.0, 0.8, 0.3, 0.6 + 0.2 * sin(time * 4.0)))
		var y := r.get_center().y
		_bone(Vector2(r.position.x + 22, y), Vector2(r.end.x - 22, y), 11.0,
			Color("fff1d0") if found else Color(1, 1, 1, 0.16), found)
		x += w + 26.0


func _draw_cell(i: int, kind: String, hint: int) -> void:
	var r := cell_rect(i)
	var c := r.get_center()
	var rev := float(_reveal.get(i, -10.0))
	var k := clampf((time - rev) / dur(0.35), 0.0, 1.0)
	var pop := 1.0 + 0.25 * sin(k * PI) if k < 1.0 else 1.0
	var h := hash(i * 7919 + 13)
	if kind == "?":
		var sq := 0.92 if _press == i and not locked else 1.0
		var digk := 0.0
		if _dig.has(i):
			digk = clampf((time - float(_dig[i])) / dur(0.18), 0.0, 1.0)
			sq *= 1.0 - 0.1 * digk
		var rr := Rect2(c - r.size * 0.5 * sq, r.size * sq)
		var shade := 0.9 + 0.1 * float(h % 7) / 6.0
		rrect(rr.grow(2), Color(0, 0, 0, 0.35), _cell * 0.24)
		rrect(rr, DIRT * shade, _cell * 0.22)
		rrect(Rect2(rr.position, Vector2(rr.size.x, rr.size.y * 0.8)), DIRT_TOP * shade, _cell * 0.22)
		rrect(Rect2(rr.position + rr.size * Vector2(0.14, 0.08), rr.size * Vector2(0.72, 0.22)), Color(1, 1, 1, 0.12), _cell * 0.12)
		# pebbles and a tuft
		for p in 3:
			var ph := hash(h + p * 31)
			var pp := rr.position + rr.size * Vector2(0.2 + 0.6 * float(ph % 97) / 97.0, 0.35 + 0.35 * float((ph / 97) % 89) / 89.0)
			draw_circle(pp, _cell * (0.035 + 0.02 * (ph % 3)), Color("5e3a22"))
			draw_circle(pp - Vector2(1, 1), _cell * 0.02, Color("d9a674"))
		if h % 3 == 0:
			var g := rr.position + Vector2(rr.size.x * 0.72, rr.size.y * 0.2)
			for b in 3:
				draw_line(g, g + Vector2((b - 1) * 6.0, -_cell * 0.14), Color("7fbf4a"), 3.0, true)
		if _press == i and not locked:
			rrect(rr, Color(1, 0.9, 0.6, 0.18), _cell * 0.22, 3, Color(1.0, 0.85, 0.5, 0.8))
		return
	# a dug hole
	var hr := Rect2(c - r.size * 0.5 * pop, r.size * pop)
	rrect(hr, Color("2b1a10"), _cell * 0.22)
	rrect(hr.grow(-_cell * 0.07), Color("1a0f09"), _cell * 0.18)
	rrect(Rect2(hr.position + Vector2(_cell * 0.07, hr.size.y * 0.62), Vector2(hr.size.x - _cell * 0.14, hr.size.y * 0.3)), Color("3b2415"), _cell * 0.14)
	match kind:
		".":
			var col: Color = HINT_COLORS[clampi(hint, 0, 5)]
			var gk := 0.5 + 0.2 * sin(time * 3.0 + i)
			glow(c, _cell * 0.5, Color(col.r, col.g, col.b, gk if hint <= 1 else gk * 0.6))
			text_c(c, str(hint), int(_cell * 0.5 * pop), col, 8)
		"hit":
			glow(c, _cell * 0.55, Color(1.0, 0.85, 0.5, 0.55))
			_bone(c + Vector2(-_cell * 0.26, _cell * 0.08), c + Vector2(_cell * 0.26, -_cell * 0.08), _cell * 0.1 * pop, Color("f4e6c6"), false)
			_crack(c + Vector2(_cell * 0.24, _cell * 0.2))
		"bone":
			var links := MgLogic.bone_links(state.get("cells", []), i, 5)
			var shine := time < _glow_until
			glow(c, _cell * 0.62, Color(1.0, 0.78, 0.25, 0.75 if shine else 0.45))
			var col := Color("fff4d6")
			var half := _cell * 0.5 + 4.0
			var t := _cell * 0.12 * pop
			var any := false
			for d in 4:
				if links[d]:
					any = true
					var dir: Vector2 = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN][d]
					_bone_bar(c, c + dir * half, t, col)
			if not any:
				_bone(c + Vector2(-_cell * 0.28, 0), c + Vector2(_cell * 0.28, 0), t, col, true)
			draw_circle(c, t * 1.45, UiPalette.OUTLINE)
			draw_circle(c, t * 1.2, col)
			draw_circle(c - Vector2(t * 0.3, t * 0.3), t * 0.4, Color(1, 1, 1, 0.8))


## A cartoon bone from a to b (thickness t); gold = finished-fossil trim.
func _bone(a: Vector2, b: Vector2, t: float, col: Color, gold: bool) -> void:
	var o := UiPalette.OUTLINE
	o.a = col.a
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	for end: Vector2 in [a, b]:
		draw_circle(end + n * t * 0.8, t * 1.1, o)
		draw_circle(end - n * t * 0.8, t * 1.1, o)
	draw_line(a, b, o, t * 2.0 + 5.0, true)
	for end: Vector2 in [a, b]:
		draw_circle(end + n * t * 0.8, t * 0.9, col)
		draw_circle(end - n * t * 0.8, t * 0.9, col)
	draw_line(a, b, col, t * 2.0, true)
	draw_line(a + n * t * 0.4, b + n * t * 0.4, Color(1, 1, 1, 0.45 * col.a), t * 0.5, true)
	if gold:
		draw_line(a - n * t * 0.6, b - n * t * 0.6, Color(1.0, 0.75, 0.2, 0.7), t * 0.35, true)


func _bone_bar(a: Vector2, b: Vector2, t: float, col: Color) -> void:
	draw_line(a, b, UiPalette.OUTLINE, t * 2.0 + 5.0, true)
	draw_line(a, b, col, t * 2.0, true)
	var dir := (b - a).normalized()
	var n := Vector2(-dir.y, dir.x)
	draw_line(a + n * t * 0.4, b + n * t * 0.4, Color(1, 1, 1, 0.5), t * 0.5, true)


func _crack(at: Vector2) -> void:
	var s := _cell * 0.1
	var col := Color(1.0, 0.9, 0.5)
	text_c(at, "?", int(_cell * 0.26), col, 5)
	glow(at, s * 2.0, Color(1.0, 0.8, 0.3, 0.5))


func _draw_shovel(tip: Vector2, ang: float) -> void:
	draw_set_transform(tip, ang)
	var s := _cell / 60.0
	draw_line(Vector2(0, -8 * s), Vector2(0, -58 * s), UiPalette.OUTLINE, 10 * s, true)
	draw_line(Vector2(0, -8 * s), Vector2(0, -58 * s), Color("a0683a"), 6 * s, true)
	draw_rect(Rect2(Vector2(-10, -66) * s, Vector2(20, 8) * s), Color("a0683a"))
	var blade := PackedVector2Array([Vector2(-13, -10) * s, Vector2(13, -10) * s, Vector2(10, 10) * s, Vector2(0, 18) * s, Vector2(-10, 10) * s])
	draw_colored_polygon(blade, UiPalette.OUTLINE)
	var inner := PackedVector2Array([Vector2(-10, -8) * s, Vector2(10, -8) * s, Vector2(8, 8) * s, Vector2(0, 14) * s, Vector2(-8, 8) * s])
	draw_colored_polygon(inner, Color("c8d2de"))
	draw_line(Vector2(-6, -6) * s, Vector2(-4, 8) * s, Color(1, 1, 1, 0.7), 3 * s, true)
	draw_set_transform(Vector2.ZERO)

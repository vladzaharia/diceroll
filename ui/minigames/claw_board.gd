class_name ClawBoard
extends MgBoard
## Claw Machine: an arcade cabinet with the 5 visible prizes on its floor (each prize's
## hitbox shows as a floor spotlight: narrow = valuable, the legendary crown is the
## narrowest, half-buried at the bottom of the pile). The claw sweeps at a constant speed
## (MgLogic.claw_x, restarting from the left each grab); a tap anywhere drops it
## ([position 0..1]). The descent, grab or miss, and the prize dropping into the chute all
## play from the core's minigame_update: nothing is decided here.

var _cab := Rect2()
var _win := Rect2()
var _floor_y := 0.0
var _rail_y := 0.0
var _swing := 0.0
var _claw := MgLogic.CLAW_MIN
var _mode := "swing"          # swing | drop | idle
var _cable := 0.0             # extra cable length below the rest position (px)
var _open := 1.0              # prong opening 0 (closed) .. 1 (open)
var _carry := -1              # prize index hanging from the claw
var _carry_drop := -1.0       # 0..1 fall into the chute
var _won: Array = []          # kinds already won (the shelf)
var _flash_prize := -1
var _bulbs := 0.0


func set_state(st: Dictionary, instant := true) -> void:
	super.set_state(st, instant)
	if instant:
		_won.clear()
		for g: Dictionary in state.get("grabs", []):
			if bool(g.get("grabbed", false)):
				_won.append(String(g.get("kind", "small")))
		_mode = "swing" if int(state.get("actions_left", 0)) > 0 and not bool(state.get("done", false)) else "idle"
		_swing = 0.0
		_cable = 0.0
		_open = 1.0
		_carry = -1
	unlock()


func is_settled() -> bool:
	return _mode != "drop"


func _layout() -> void:
	var avail := size - Vector2(10, 10)
	var h := minf(avail.y, avail.x / 0.82)
	var w := h * 0.82
	_cab = Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))
	var top := _cab.position.y + h * 0.17
	_win = Rect2(Vector2(_cab.position.x + w * 0.07, top), Vector2(w * 0.86, h * 0.56))
	_rail_y = _win.position.y + 26.0
	_floor_y = _win.end.y - h * 0.07


func floor_x(pos: float) -> float:
	return _win.position.x + 28.0 + pos * (_win.size.x - 56.0)


func _unit() -> float:
	return _win.size.x / 520.0


func _tick(dt: float) -> void:
	_bulbs += dt
	if _mode == "swing":
		# real time on purpose: the sweep speed is the game's skill, never the game speed
		_swing += dt
		_claw = MgLogic.claw_x(_swing)


func drop() -> void:
	if locked or _mode != "swing" or int(state.get("actions_left", 0)) <= 0:
		return
	_mode = "drop"
	MgBoard.sfx("claw")
	send([snappedf(_claw, 0.001)])


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		drop()


func _prizes() -> Array:
	return state.get("prizes", [])


func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	_layout()
	var info: Dictionary = ev.get("info", {})
	_mode = "drop"
	_claw = float(info.get("x", _claw))
	var hit := int(info.get("prize", -1))
	var grabbed := bool(info.get("grabbed", false))
	var u := _unit()
	var rest := _rest_len()
	var depth := _floor_y - _rail_y - rest - 58.0 * u
	if grabbed and hit >= 0:
		depth -= _prize_h(String(info.get("kind", "small"))) * 0.55
	# descend
	MgBoard.sfx("whirr")
	var t := create_tween()
	t.tween_property(self, "_cable", depth, dur(0.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	t = create_tween()
	t.tween_property(self, "_open", 0.0, dur(0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await t.finished
	MgBoard.sfx("clink")
	var head := Vector2(floor_x(_claw), _rail_y + rest + _cable + 40.0 * u)
	if grabbed and hit >= 0:
		_carry = hit
		_flash_prize = hit
		burst(head + Vector2(0, 30 * u), Color("fff3c0"), 12, "star", 220.0, 60.0, 8.0)
		shake(4.0)
	else:
		burst(Vector2(head.x, _floor_y - 10), Color(0.8, 0.8, 0.9, 0.8), 8, "puff", 80.0, 20.0, 12.0)
	await wait(0.12)
	# rise (a miss wobbles on the way up)
	t = create_tween()
	t.tween_property(self, "_cable", 0.0, dur(0.55)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	if grabbed and hit >= 0:
		# carry it over the chute (left), release
		var from := _claw
		t = create_tween()
		t.tween_method(func(v: float) -> void: _claw = v, from, -0.02, dur(0.25 + 0.4 * from)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await t.finished
		t = create_tween()
		t.tween_property(self, "_open", 1.0, dur(0.15))
		await t.finished
		t = create_tween()
		t.tween_property(self, "_carry_drop", 1.0, dur(0.32)).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await t.finished
		var kind := String(info.get("kind", "small"))
		var pts := int(_prizes()[hit].get("points", 0)) if hit < _prizes().size() else 0
		_carry = -1
		_carry_drop = -1.0
		_won.append(kind)
		var chute := Vector2(floor_x(-0.02), _cab.end.y - _cab.size.y * 0.14)
		burst(chute, MgLogic.PRIZE_COLORS.get(kind, Color.WHITE), 26, "star", 360.0, 200.0, 10.0)
		ring(chute, Color("ffe07a"), 80.0, 0.5, 8.0)
		var big := kind in ["big", "legendary"]
		MgBoard.sfx("win" if big else "coin")
		shake(8.0 if big else 4.0)
		kick.emit(1.0 if kind == "legendary" else 0.5, Color(1.0, 0.85, 0.4, 0.45))
		float_text(Vector2(_cab.get_center().x, _win.position.y + _win.size.y * 0.45),
			"%s!  +%d" % [String(MgLogic.PRIZE_NAMES.get(kind, kind)).to_upper(), pts], MgLogic.PRIZE_COLORS.get(kind, Color.WHITE).lightened(0.2), 48, 1.4)
	else:
		MgBoard.sfx("error")
		float_text(Vector2(floor_x(_claw), _win.get_center().y), "MISS!", UiPalette.TEXT_DIM, 44, 1.0)
		await wait(0.2)
	state = (ev.get("state", {}) as Dictionary).duplicate(true)
	_flash_prize = -1
	# reset for the next grab: back to the left edge, the sweep restarts
	var back := _claw
	t = create_tween()
	t.tween_method(func(v: float) -> void: _claw = v, back, MgLogic.CLAW_MIN, dur(0.3))
	await t.finished
	_open = 1.0
	_swing = 0.0
	_mode = "swing" if int(state.get("actions_left", 0)) > 0 and not bool(state.get("done", false)) else "idle"
	unlock()


func _rest_len() -> float:
	return 30.0 * _unit()


func _prize_h(kind: String) -> float:
	var u := _unit()
	match kind:
		"small": return 58.0 * u
		"medium": return 62.0 * u
		"big": return 70.0 * u
	return 44.0 * u


# --- drawing -------------------------------------------------------------------------

func _draw_board() -> void:
	_layout()
	var c := _cab
	var u := _unit()
	var pink := Color("ff5d95")
	# body
	rrect(Rect2(c.position + Vector2(0, 12), c.size), Color(0, 0, 0, 0.45), 40)
	rrect(c.grow(4.0), UiPalette.OUTLINE, 44)
	rrect(c, pink.darkened(0.35), 40)
	rrect(Rect2(c.position, c.size - Vector2(0, 14)), pink, 40)
	rrect(Rect2(c.position + Vector2(c.size.x * 0.04, 8), Vector2(c.size.x * 0.92, 14)), Color(1, 1, 1, 0.25), 8)
	# marquee
	var mq := Rect2(c.position + Vector2(c.size.x * 0.1, c.size.y * 0.03), Vector2(c.size.x * 0.8, c.size.y * 0.11))
	rrect(mq, Color("3a1450"), 24, 4, UiPalette.OUTLINE)
	text_c(mq.get_center(), "CLAW  CRAZE", int(mq.size.y * 0.5), Color("ffe07a"), 9)
	var nb := 16
	for k in nb:
		var p := mq.position + Vector2(12 + k * (mq.size.x - 24) / (nb - 1), -2)
		var on := (int(_bulbs * 8.0) + k) % 3 == 0
		draw_circle(p, 6 * u + 2, UiPalette.OUTLINE)
		draw_circle(p, 6 * u, Color("fff2a0") if on else Color("b86a3a"))
		var p2 := Vector2(p.x, mq.end.y + 2)
		draw_circle(p2, 6 * u + 2, UiPalette.OUTLINE)
		draw_circle(p2, 6 * u, Color("fff2a0") if not on else Color("b86a3a"))
	# window: back wall
	var w := _win
	rrect(w.grow(6.0), UiPalette.OUTLINE, 22)
	rrect(w, Color("2a1745"), 18)
	for k in 6:
		var band := Rect2(w.position + Vector2(0, k * w.size.y / 6.0), Vector2(w.size.x, w.size.y / 6.0))
		draw_rect(band.grow_individual(-8, 0, -8, 0), Color(0.5, 0.3, 0.9, 0.04 * (6 - k)))
	for k in 18:
		var hx := float(hash(k * 97) % 1000) / 1000.0
		var hy := float(hash(k * 53) % 1000) / 1000.0
		var tw := 0.5 + 0.5 * sin(_bulbs * 2.0 + k)
		_star4(w.position + Vector2(20 + hx * (w.size.x - 40), 20 + hy * w.size.y * 0.55), 3.0 + 3.0 * tw, Color(1, 1, 1, 0.25 * tw))
	# floor & the pile
	var fl := Rect2(Vector2(w.position.x + 6, _floor_y - 6), Vector2(w.size.x - 12, w.end.y - _floor_y))
	rrect(fl, Color("4a2a6a"), 12)
	for k in 11:
		var hx := float(hash(k * 211 + 5) % 1000) / 1000.0
		var col: Color = [Color("6fd6ff"), Color("ffd46b"), Color("ff8ad0"), Color("9dff8a")][k % 4]
		var p := Vector2(w.position.x + 24 + hx * (w.size.x - 48), _floor_y - 6 + (k % 3) * 5.0)
		draw_circle(p, (15.0 + 5.0 * (k % 3)) * u, col.darkened(0.45))
		draw_circle(p - Vector2(4, 4) * u, (6.0 + 2.0 * (k % 2)) * u, col.darkened(0.2))
	# prizes (with hitbox spotlights)
	var prizes := _prizes()
	var aim := MgLogic.claw_target(prizes, _claw) if _mode == "swing" else -1
	for i in prizes.size():
		var p: Dictionary = prizes[i]
		if bool(p.get("taken", false)) or i == _carry:
			continue
		var kind := String(p.kind)
		var x := floor_x(float(p.pos))
		var half := float(p.width) * 0.5 * (_win.size.x - 56.0)
		var col: Color = MgLogic.PRIZE_COLORS.get(kind, Color.WHITE)
		var hot := i == aim
		var sp := Rect2(Vector2(x - half, _floor_y - 4), Vector2(half * 2.0, 12))
		rrect(sp, Color(col.r, col.g, col.b, 0.55 if hot else 0.28), 6)
		if hot:
			glow(Vector2(x, _floor_y - 20 * u), 60 * u, Color(col.r, col.g, col.b, 0.8))
		var base := Vector2(x, _floor_y + (8.0 * u if kind == "legendary" else 0.0))
		_prize(kind, base, u * (1.08 if hot else 1.0), 1.0)
		var tag := Vector2(x, _floor_y + 26 * u)
		text_c(tag, str(int(p.points)), int(22 * u + 4), col.lightened(0.3), 6)
	# rail, trolley, cable, claw
	draw_rect(Rect2(Vector2(w.position.x + 8, _rail_y - 8), Vector2(w.size.x - 16, 12)), Color("9aa3b8"))
	draw_rect(Rect2(Vector2(w.position.x + 8, _rail_y - 8), Vector2(w.size.x - 16, 4)), Color("d9e0ee"))
	var cx := floor_x(_claw)
	if _mode == "swing" and not locked:
		var y0 := _rail_y + _rest_len() + 60 * u
		var yy := y0
		while yy < _floor_y - 20:
			draw_line(Vector2(cx, yy), Vector2(cx, minf(yy + 10, _floor_y - 20)), Color(1.0, 0.4, 0.5, 0.55), 3.0)
			yy += 20.0
	_draw_claw(Vector2(cx, _rail_y), u)
	# glass reflection
	var gl := PackedVector2Array([w.position + Vector2(w.size.x * 0.62, 0), w.position + Vector2(w.size.x * 0.72, 0),
		w.position + Vector2(w.size.x * 0.42, w.size.y), w.position + Vector2(w.size.x * 0.32, w.size.y)])
	draw_colored_polygon(gl, Color(1, 1, 1, 0.05))
	rrect(w, Color(0, 0, 0, 0), 18, 3, Color(1, 1, 1, 0.12))
	# front panel: chute + won shelf + a big button
	var fp := Rect2(Vector2(c.position.x + c.size.x * 0.07, w.end.y + 18), Vector2(c.size.x * 0.86, c.end.y - w.end.y - 44))
	rrect(fp, pink.darkened(0.2), 20, 3, UiPalette.OUTLINE)
	var chute := Rect2(fp.position + Vector2(14, 12), Vector2(fp.size.x * 0.26, fp.size.y - 24))
	rrect(chute, Color("22102e"), 14, 3, UiPalette.OUTLINE)
	text_c(chute.get_center() + Vector2(0, chute.size.y * 0.3), "PRIZE", int(16 * u + 4), Color(1, 1, 1, 0.5))
	var shelf := Rect2(Vector2(chute.end.x + 16, fp.position.y + 12), Vector2(fp.size.x * 0.44, fp.size.y - 24))
	rrect(shelf, Color(0.05, 0.03, 0.12, 0.7), 14)
	if _won.is_empty():
		text_c(shelf.get_center(), "WON: -", int(16 * u + 4), Color(1, 1, 1, 0.35))
	for k in _won.size():
		_prize(String(_won[k]), Vector2(shelf.position.x + 40 * u + k * 70 * u, shelf.end.y - 8), u * 0.72, 1.0)
	var bc := Vector2(fp.end.x - fp.size.x * 0.13, fp.get_center().y)
	var br := minf(fp.size.y * 0.36, 34.0 * u + 10)
	var pressed := _mode == "drop"
	draw_circle(bc + Vector2(0, 6), br, Color("8a1030"))
	draw_circle(bc + (Vector2(0, 4) if pressed else Vector2.ZERO), br, Color("ff3b5c"))
	draw_circle(bc + Vector2(-br * 0.3, -br * 0.35), br * 0.3, Color(1, 1, 1, 0.45))
	# the dropping prize falling into the chute
	if _carry_drop >= 0.0 and _carry >= 0 and _carry < prizes.size():
		var k := _carry_drop
		var from := Vector2(floor_x(-0.02), _rail_y + _rest_len() + 90 * u)
		var to := Vector2(from.x, chute.get_center().y)
		_prize(String(prizes[_carry].kind), from.lerp(to, k), u * (1.0 - 0.4 * k), 1.0 - k * 0.5)


func _draw_claw(top: Vector2, u: float) -> void:
	# trolley
	rrect(Rect2(top + Vector2(-26, -14) * u, Vector2(52, 24) * u), Color("5e6a86"), 6 * u)
	rrect(Rect2(top + Vector2(-26, -14) * u, Vector2(52, 8) * u), Color("aeb8cf"), 6 * u)
	var cl := _rest_len() + _cable
	var head := top + Vector2(0, cl)
	draw_line(top, head, UiPalette.OUTLINE, 6.0 * u, true)
	draw_line(top, head, Color("c8cfdd"), 3.0 * u, true)
	# hub
	draw_circle(head, 16 * u, UiPalette.OUTLINE)
	draw_circle(head, 13 * u, Color("ffc93d"))
	draw_circle(head + Vector2(-4, -4) * u, 5 * u, Color(1, 1, 1, 0.6))
	# carried prize hangs between the prongs
	var prizes := _prizes()
	if _carry >= 0 and _carry_drop < 0.0 and _carry < prizes.size():
		_prize(String(prizes[_carry].kind), head + Vector2(0, 60 * u), u, 1.0)
	# prongs: left, right (and a short centre one)
	var spread := lerpf(0.15, 0.75, _open)
	for s in [-1.0, 1.0]:
		var a := head + Vector2(s * 8 * u, 8 * u)
		var knee := a + Vector2(s * 26 * u * spread + s * 6 * u, 24 * u)
		var tip := knee + Vector2(-s * 16 * u * (1.2 - spread), 22 * u)
		for pass_i in 2:
			var col := UiPalette.OUTLINE if pass_i == 0 else Color("d6dcea")
			var wd := (9.0 if pass_i == 0 else 5.0) * u
			draw_line(a, knee, col, wd, true)
			draw_line(knee, tip, col, wd, true)
		draw_circle(knee, 4 * u, Color("8e98ae"))
	draw_line(head, head + Vector2(0, 30 * u), UiPalette.OUTLINE, 8 * u, true)
	draw_line(head, head + Vector2(0, 30 * u), Color("d6dcea"), 4 * u, true)


## A prize standing on point `b` (bottom centre).
func _prize(kind: String, b: Vector2, s: float, a: float) -> void:
	var col: Color = MgLogic.PRIZE_COLORS.get(kind, Color.WHITE)
	var o := Color(UiPalette.OUTLINE, a)
	match kind:
		"small":
			var cc := b + Vector2(0, -26 * s)
			draw_circle(cc, 27 * s, o)
			draw_circle(cc, 24 * s, Color(col, a))
			draw_circle(cc + Vector2(-8, -9) * s, 8 * s, Color(1, 1, 1, 0.35 * a))
			for e in [-1.0, 1.0]:
				draw_circle(cc + Vector2(e * 8, -2) * s, 4.5 * s, o)
				draw_circle(cc + Vector2(e * 8 - 1, -3) * s, 1.6 * s, Color(1, 1, 1, a))
				draw_circle(cc + Vector2(e * 20, -20) * s, 7 * s, o)
				draw_circle(cc + Vector2(e * 20, -20) * s, 5 * s, Color(col.darkened(0.2), a))
			draw_arc(cc + Vector2(0, 6) * s, 5 * s, 0.2, PI - 0.2, 8, o, 2.5 * s, true)
		"medium":
			var r := Rect2(b + Vector2(-27, -54) * s, Vector2(54, 54) * s)
			rrect(r.grow(3 * s), o, 8 * s)
			rrect(r, Color(col, a), 7 * s)
			draw_rect(Rect2(Vector2(b.x - 5 * s, r.position.y), Vector2(10 * s, r.size.y)), Color(1.0, 0.95, 0.6, a))
			draw_rect(Rect2(Vector2(r.position.x, r.position.y + 12 * s), Vector2(r.size.x, 9 * s)), Color(1.0, 0.95, 0.6, a))
			for e in [-1.0, 1.0]:
				draw_circle(Vector2(b.x + e * 9 * s, r.position.y - 4 * s), 9 * s, o)
				draw_circle(Vector2(b.x + e * 9 * s, r.position.y - 4 * s), 6.5 * s, Color(1.0, 0.95, 0.6, a))
		"big":
			var r := Rect2(b + Vector2(-34, -54) * s, Vector2(68, 54) * s)
			rrect(r.grow(3 * s), o, 10 * s)
			rrect(r, Color(Color("9b5a2a"), a), 9 * s)
			rrect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.42)), Color(Color("b8733a"), a), 9 * s)
			draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.38), Vector2(r.size.x, 6 * s)), Color(col, a))
			for e in [0.15, 0.85]:
				draw_rect(Rect2(Vector2(r.position.x + r.size.x * e - 3 * s, r.position.y), Vector2(6 * s, r.size.y)), Color(col, a))
			rrect(Rect2(Vector2(b.x - 7 * s, r.position.y + r.size.y * 0.3), Vector2(14, 16) * s), Color(Color("ffe07a"), a), 3 * s)
			for k in 3:
				draw_circle(b + Vector2(-14 + k * 14, -58 - (k % 2) * 4) * s, 6 * s, Color(Color("ffd24a"), a))
		"legendary":
			glow(b + Vector2(0, -24 * s), 56 * s, Color(1.0, 0.85, 0.3, 0.8 * a))
			var pts := PackedVector2Array([b + Vector2(-26, 0) * s, b + Vector2(-28, -34) * s, b + Vector2(-14, -20) * s,
				b + Vector2(0, -42) * s, b + Vector2(14, -20) * s, b + Vector2(28, -34) * s, b + Vector2(26, 0) * s])
			var big := PackedVector2Array()
			var ctr := b + Vector2(0, -20 * s)
			for p in pts:
				big.append(ctr + (p - ctr) * 1.14)
			draw_colored_polygon(big, o)
			draw_colored_polygon(pts, Color(col, a))
			draw_rect(Rect2(b + Vector2(-26, -10) * s, Vector2(52, 10) * s), Color(Color("e0a33a"), a))
			for k in 3:
				draw_circle(b + Vector2(-14 + k * 14, -5) * s, 3.5 * s, Color([Color("ff5a6e"), Color("5ab8ff"), Color("5fdc6a")][k], a))
			_star4(b + Vector2(18, -40) * s, (7.0 + 3.0 * sin(_bulbs * 6.0)) * s, Color(1, 1, 1, a))

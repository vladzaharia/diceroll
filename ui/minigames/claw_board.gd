class_name ClawBoard
extends MgBoard
## Claw Machine: an arcade cabinet full of prize capsules. Each capsule's colour is its tier
## (common blue, rare green, epic purple, legendary gold, deeper by tier); what is inside
## stays hidden (the core never tells) until it is won. The claw sweeps at a constant speed
## (MgLogic.claw_x, restarting from the left each grab); a tap drops it ([position 0..1]).
## The capsules it will scoop light up (public positions/depths only). The descent, the
## scoop (up to 3), the capsules slipping out on the lift, and the chute + one-by-one
## capsule reveal all play from the core's minigame_update: nothing is decided here.

const PRIZE_ICONS := {"coins": [ModelIcons.COINS, 25.0], "potion": [ModelIcons.POTION, 20.0], "nugget": [ModelIcons.NUGGET, 25.0],
	"gem": [ModelIcons.GEM_SMALL, 25.0], "figure": [ModelIcons.ACTION_FIGURE, 25.0], "robot": [ModelIcons.ROBOT, 20.0],
	"chest": [ModelIcons.GEM_CHEST, 25.0]}

var _cab := Rect2()
var _win := Rect2()
var _floor_y := 0.0
var _rail_y := 0.0
var _heap_h := 100.0
var _swing := 0.0
var _claw := MgLogic.CLAW_MIN
var _mode := "swing"          # swing | drop | idle
var _cable := 0.0
var _open := 1.0
var _held: Array = []         # ball indices hanging in the claw
var _drop_k := -1.0           # 0..1 held capsules falling into the chute
var _falling := {}            # ball -> {from: Vector2, t0}
var _jig := {}                # ball -> {off, vel}
var _reveal: Dictionary = {}  # the capsule opening on stage: {kind, points, tier, t0}
var _won_kinds: Array = []    # kinds in the tray
var _bulbs := 0.0


func set_state(st: Dictionary, instant := true) -> void:
	super.set_state(st, instant)
	if instant:
		_won_kinds.clear()
		for w: Dictionary in state.get("won", []):
			_won_kinds.append(String(w.kind))
		_mode = "swing" if int(state.get("actions_left", 0)) > 0 and not bool(state.get("done", false)) else "idle"
		_swing = 0.0
		_cable = 0.0
		_open = 1.0
		_held.clear()
		_reveal = {}
	unlock()


func is_settled() -> bool:
	return _mode != "drop"


func _layout() -> void:
	var avail := size - Vector2(10, 10)
	var h := minf(avail.y, avail.x / 0.82)
	var w := h * 0.82
	_cab = Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))
	var top := _cab.position.y + h * 0.17
	_win = Rect2(Vector2(_cab.position.x + w * 0.07, top), Vector2(w * 0.86, h * 0.58))
	_rail_y = _win.position.y + 26.0
	_floor_y = _win.end.y - 6.0
	_heap_h = _win.size.y * 0.34


func floor_x(pos: float) -> float:
	return _win.position.x + 28.0 + pos * (_win.size.x - 56.0)


func _unit() -> float:
	return _win.size.x / 520.0


func _r() -> float:
	return 34.0 * _unit()


## Resting centre of ball i in the pile (deeper = lower).
func ball_pos(b: Dictionary) -> Vector2:
	var d := float(b.get("depth", 0.0))
	return Vector2(floor_x(float(b.pos)), _floor_y - _r() - (1.0 - d) * _heap_h)


func _tick(dt: float) -> void:
	_bulbs += dt
	if _mode == "swing":
		# real time on purpose: the sweep speed is the game's skill, never the game speed
		_swing += dt
		_claw = MgLogic.claw_x(_swing)
	for k in _jig.keys():
		var j: Dictionary = _jig[k]
		j.vel += (-j.off * 70.0 - j.vel * 8.0) * dt
		j.off += j.vel * dt
		if j.off.length() < 0.2 and j.vel.length() < 2.0:
			_jig.erase(k)


## Capsules near screen x rock away from the claw.
func jostle(x: float, strength := 1.0) -> void:
	var balls: Array = state.get("balls", [])
	for i in balls.size():
		var p := ball_pos(balls[i])
		if absf(p.x - x) < 110.0 * _unit() and not bool(balls[i].taken):
			var j: Dictionary = _jig.get(i, {"off": Vector2.ZERO, "vel": Vector2.ZERO})
			j.vel += Vector2(signf(p.x - x) * randf_range(60.0, 180.0), randf_range(-160.0, -40.0)) * strength
			_jig[i] = j


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


func _head() -> Vector2:
	return Vector2(floor_x(_claw), _rail_y + 30.0 * _unit() + _cable)


func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	_layout()
	var info: Dictionary = ev.get("info", {})
	_mode = "drop"
	_claw = float(info.get("x", _claw))
	var held: Array = info.get("held", [])
	var won: Array = info.get("won", [])
	var slipped: Array = info.get("slipped", [])
	var balls: Array = state.get("balls", [])
	var u := _unit()
	var x := floor_x(_claw)
	# down into the pile: to the deepest capsule it scoops, else onto the pile top
	var target := _floor_y - _heap_h - _r()
	for i in held:
		target = maxf(target, ball_pos(balls[int(i)]).y - _r())
	if held.is_empty():
		var top_y := _floor_y
		for b: Dictionary in balls:
			if not bool(b.taken) and absf(ball_pos(b).x - x) < _r() * 1.5:
				top_y = minf(top_y, ball_pos(b).y - _r())
		target = top_y
	var t := create_tween()
	MgBoard.sfx("whirr")
	t.tween_property(self, "_cable", target - _rail_y - 30.0 * u - 34.0 * u, dur(0.65)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	MgBoard.sfx("fwump")
	jostle(x, 1.0)
	t = create_tween()
	t.tween_property(self, "_open", 0.0, dur(0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await t.finished
	MgBoard.sfx("clink")
	_held = held.duplicate()
	if not held.is_empty():
		burst(_head() + Vector2(0, 60 * u), Color("fff3c0"), 10 + 4 * held.size(), "star", 220.0, 60.0, 8.0)
		shake(3.0 + 1.5 * held.size())
		if held.size() >= 2:
			float_text(Vector2(x, _win.position.y + _win.size.y * 0.3), "x%d!" % held.size(), Color("ffe07a"), 44, 0.9)
	await wait(0.12)
	# the lift: slipping capsules fall back into the pile part way up
	t = create_tween()
	t.tween_property(self, "_cable", 0.0, dur(0.7)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not slipped.is_empty():
		await wait(0.3)
		for i in slipped:
			_falling[int(i)] = {"from": _held_pos(_held.find(int(i)), _held.size()), "t0": time}
			_held.erase(int(i))
		MgBoard.sfx("error")
		MgBoard.sfx("fwump")
		jostle(x, 0.7)
		float_text(Vector2(x, _win.position.y + _win.size.y * 0.42), "SLIPPED!" if slipped.size() == 1 else "%d SLIPPED!" % slipped.size(),
			Color("ffb0c0"), 40, 1.0)
	await t.finished
	if _held.is_empty():
		float_text(Vector2(_cab.get_center().x, _win.position.y + _win.size.y * 0.3), "EMPTY CLAW!" if slipped.is_empty() else "SO CLOSE!",
			UiPalette.TEXT_DIM, 44, 1.1)
		MgBoard.sfx("error")
		await wait(0.3)
	else:
		# over the chute, release, into the tray
		var from := _claw
		t = create_tween()
		t.tween_method(func(v: float) -> void: _claw = v, from, -0.02, dur(0.25 + 0.4 * from)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await t.finished
		t = create_tween()
		t.tween_property(self, "_open", 1.0, dur(0.15))
		await t.finished
		t = create_tween()
		t.tween_property(self, "_drop_k", 1.0, dur(0.32)).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await t.finished
		MgBoard.sfx("clink")
		_held.clear()
		_drop_k = -1.0
		# the reveal: each capsule pops open on stage, one by one
		for w: Dictionary in won:
			await _open_capsule(w)
	state = (ev.get("state", {}) as Dictionary).duplicate(true)
	_falling.clear()
	var back := _claw
	t = create_tween()
	t.tween_method(func(v: float) -> void: _claw = v, back, MgLogic.CLAW_MIN, dur(0.3))
	await t.finished
	_open = 1.0
	_swing = 0.0
	_mode = "swing" if int(state.get("actions_left", 0)) > 0 and not bool(state.get("done", false)) else "idle"
	unlock()


func _open_capsule(w: Dictionary) -> void:
	_reveal = {"kind": String(w.kind), "points": int(w.points), "tier": String(w.get("tier", "common")), "t0": time}
	MgBoard.sfx("tick")
	await wait(0.32)
	var c := _stage_center()
	var tier := String(_reveal.tier)
	var tc: Color = MgLogic.TIER_TINTS.get(tier, Color.WHITE)
	var big := tier in ["epic", "legendary"]
	MgBoard.sfx("win" if tier == "legendary" else ("reveal" if big else "coin"))
	burst(c, tc, 18 + (14 if big else 0), "star", 320.0, 80.0, 10.0)
	ring(c, tc.lightened(0.3), 110.0 * _unit(), 0.5, 8.0)
	shake(3.0 + (6.0 if tier == "legendary" else 0.0))
	kick.emit(0.9 if tier == "legendary" else (0.45 if big else 0.25), Color(tc.r, tc.g, tc.b, 0.4))
	float_text(c + Vector2(0, -90.0 * _unit()), "%s  +%d" % [String(MgLogic.PRIZE_NAMES.get(String(_reveal.kind), _reveal.kind)).to_upper(),
		int(_reveal.points)], tc.lightened(0.35), 42, 1.1)
	await wait(0.55)
	_won_kinds.append(String(_reveal.kind))
	_reveal = {}


func _stage_center() -> Vector2:
	return Vector2(_win.get_center().x, _win.position.y + _win.size.y * 0.42)


## Where held capsule k (of n) hangs under the claw.
func _held_pos(k: int, n: int) -> Vector2:
	var r := _r()
	var head := _head()
	var offs := [[Vector2(0, 1.6)], [Vector2(-0.55, 1.55), Vector2(0.55, 1.55)],
		[Vector2(-0.8, 1.45), Vector2(0.8, 1.45), Vector2(0, 2.1)]]
	var o: Vector2 = (offs[clampi(n, 1, 3) - 1] as Array)[clampi(k, 0, clampi(n, 1, 3) - 1)]
	return head + o * r


# --- drawing -------------------------------------------------------------------------

func _draw_board() -> void:
	_layout()
	var c := _cab
	var u := _unit()
	var pink := Color("ff5d95")
	rrect(Rect2(c.position + Vector2(0, 12), c.size), Color(0, 0, 0, 0.45), 40)
	rrect(c.grow(4.0), UiPalette.OUTLINE, 44)
	rrect(c, pink.darkened(0.35), 40)
	rrect(Rect2(c.position, c.size - Vector2(0, 14)), pink, 40)
	rrect(Rect2(c.position + Vector2(c.size.x * 0.04, 8), Vector2(c.size.x * 0.92, 14)), Color(1, 1, 1, 0.25), 8)
	var mq := Rect2(c.position + Vector2(c.size.x * 0.1, c.size.y * 0.03), Vector2(c.size.x * 0.8, c.size.y * 0.11))
	rrect(mq, Color("3a1450"), 24, 4, UiPalette.OUTLINE)
	text_c(mq.get_center(), "CAPSULE  CLAW", int(mq.size.y * 0.46), Color("ffe07a"), 9)
	var nb := 16
	for k in nb:
		var p := mq.position + Vector2(12 + k * (mq.size.x - 24) / (nb - 1), -2)
		var on := (int(_bulbs * 8.0) + k) % 3 == 0
		draw_circle(p, 6 * u + 2, UiPalette.OUTLINE)
		draw_circle(p, 6 * u, Color("fff2a0") if on else Color("b86a3a"))
		var p2 := Vector2(p.x, mq.end.y + 2)
		draw_circle(p2, 6 * u + 2, UiPalette.OUTLINE)
		draw_circle(p2, 6 * u, Color("fff2a0") if not on else Color("b86a3a"))
	var w := _win
	rrect(w.grow(6.0), UiPalette.OUTLINE, 22)
	rrect(w, Color("2a1745"), 18)
	for k in 6:
		var band := Rect2(w.position + Vector2(0, k * w.size.y / 6.0), Vector2(w.size.x, w.size.y / 6.0))
		draw_rect(band.grow_individual(-8, 0, -8, 0), Color(0.5, 0.3, 0.9, 0.04 * (6 - k)))
	for k in 14:
		var hx := float(hash(k * 97) % 1000) / 1000.0
		var hy := float(hash(k * 53) % 1000) / 1000.0
		var tw := 0.5 + 0.5 * sin(_bulbs * 2.0 + k)
		_star4(w.position + Vector2(20 + hx * (w.size.x - 40), 20 + hy * w.size.y * 0.35), 3.0 + 3.0 * tw, Color(1, 1, 1, 0.25 * tw))
	# shredded-paper bedding under the pile (filler, not prizes)
	var bed := PackedVector2Array([Vector2(w.position.x + 6, _floor_y + 6)])
	for k in 25:
		var bx := w.position.x + 6 + (w.size.x - 12) * k / 24.0
		var bh := _heap_h * (0.35 + 0.25 * sin(PI * k / 24.0)) + 6.0 * sin(k * 2.3)
		bed.append(Vector2(bx, _floor_y - bh))
	bed.append(Vector2(w.end.x - 6, _floor_y + 6))
	draw_colored_polygon(bed, Color("6a3d8f"))
	for k in 40:
		var hx := float(hash(k * 71 + 3) % 1000) / 1000.0
		var hy := float(hash(k * 29 + 5) % 1000) / 1000.0
		var bx := w.position.x + 16 + hx * (w.size.x - 32)
		var top := _floor_y - _heap_h * (0.35 + 0.25 * sin(PI * hx)) + 8.0
		var by := lerpf(top, _floor_y - 4.0, hy)
		var sc: Color = [Color("ff9ad0"), Color("9fd8ff"), Color("ffe38a"), Color("c9a8ff"), Color("a8f0c0")][k % 5]
		draw_line(Vector2(bx, by), Vector2(bx + 14.0 * _unit(), by + 5.0 * sin(k)), sc.darkened(0.2), 4.0 * _unit(), true)
	# the capsule pile, deepest first
	var balls: Array = state.get("balls", [])
	var scoop: Array = MgLogic.claw_scoop(balls, _claw) if _mode == "swing" and not locked else []
	var order: Array = range(balls.size())
	order.sort_custom(func(a: int, b: int) -> bool: return float(balls[a].depth) > float(balls[b].depth))
	for i: int in order:
		var b: Dictionary = balls[i]
		if bool(b.taken) or _held.has(i):
			continue
		var p := ball_pos(b)
		if _falling.has(i):
			var f: Dictionary = _falling[i]
			var k := clampf((time - float(f.t0)) / dur(0.45), 0.0, 1.0)
			var from: Vector2 = f.from
			p = from.lerp(p, ease(k, 0.4)) + Vector2(0, -sin(k * PI) * 30.0 * u)
		if _jig.has(i):
			p += (_jig[i] as Dictionary).off
		_capsule(p, _r(), String(b.tier), scoop.has(i), i)
	# the front lip of the bedding half-buries the deepest capsules
	var lip := PackedVector2Array([Vector2(w.position.x + 6, _floor_y + 6)])
	for k in 25:
		var bx := w.position.x + 6 + (w.size.x - 12) * k / 24.0
		lip.append(Vector2(bx, _floor_y - _heap_h * 0.12 - 5.0 * sin(k * 1.7)))
	lip.append(Vector2(w.end.x - 6, _floor_y + 6))
	draw_colored_polygon(lip, Color("5a3280"))
	for k in 18:
		var hx := float(hash(k * 53 + 11) % 1000) / 1000.0
		var bx := w.position.x + 16 + hx * (w.size.x - 32)
		var by := _floor_y - _heap_h * 0.1 * float(hash(k * 7) % 100) / 100.0
		var sc: Color = [Color("ff9ad0"), Color("9fd8ff"), Color("ffe38a"), Color("c9a8ff"), Color("a8f0c0")][k % 5]
		draw_line(Vector2(bx, by), Vector2(bx + 14.0 * u, by - 4.0 * cos(k)), sc, 4.0 * u, true)
	if scoop.size() >= 2:
		var sx := floor_x(_claw)
		text_c(Vector2(sx, _floor_y - _heap_h - _r() * 2.6), "x%d" % scoop.size(), 24, Color("ffe07a"), 6)
	# rail, drop line, claw
	draw_rect(Rect2(Vector2(w.position.x + 8, _rail_y - 8), Vector2(w.size.x - 16, 12)), Color("9aa3b8"))
	draw_rect(Rect2(Vector2(w.position.x + 8, _rail_y - 8), Vector2(w.size.x - 16, 4)), Color("d9e0ee"))
	var cx := floor_x(_claw)
	if _mode == "swing" and not locked:
		var yy := _rail_y + 90 * u
		var y_end := _floor_y - _heap_h - _r() * 1.5
		while yy < y_end:
			draw_line(Vector2(cx, yy), Vector2(cx, minf(yy + 10, y_end)), Color(1.0, 0.4, 0.5, 0.55), 3.0)
			yy += 20.0
	_draw_claw(Vector2(cx, _rail_y), u)
	# glass
	var gl := PackedVector2Array([w.position + Vector2(w.size.x * 0.62, 0), w.position + Vector2(w.size.x * 0.72, 0),
		w.position + Vector2(w.size.x * 0.42, w.size.y), w.position + Vector2(w.size.x * 0.32, w.size.y)])
	draw_colored_polygon(gl, Color(1, 1, 1, 0.05))
	rrect(w, Color(0, 0, 0, 0), 18, 3, Color(1, 1, 1, 0.12))
	# the reveal stage: a capsule wobbles, splits, the prize pops out
	if not _reveal.is_empty():
		_draw_reveal(u)
	# front panel: chute + won tray + button
	var fp := Rect2(Vector2(c.position.x + c.size.x * 0.07, w.end.y + 16), Vector2(c.size.x * 0.86, c.end.y - w.end.y - 40))
	rrect(fp, pink.darkened(0.2), 20, 3, UiPalette.OUTLINE)
	var chute := Rect2(fp.position + Vector2(14, 12), Vector2(fp.size.x * 0.22, fp.size.y - 24))
	rrect(chute, Color("22102e"), 14, 3, UiPalette.OUTLINE)
	text_c(chute.get_center() + Vector2(0, chute.size.y * 0.3), "PRIZE", int(16 * u + 4), Color(1, 1, 1, 0.5))
	var shelf := Rect2(Vector2(chute.end.x + 12, fp.position.y + 12), Vector2(fp.size.x * 0.52, fp.size.y - 24))
	rrect(shelf, Color(0.05, 0.03, 0.12, 0.7), 14)
	if _won_kinds.is_empty():
		text_c(shelf.get_center(), "WON: -", int(16 * u + 4), Color(1, 1, 1, 0.35))
	var slot := minf(shelf.size.y * 0.9, (shelf.size.x - 12.0) / maxf(4.0, _won_kinds.size()))
	for k in _won_kinds.size():
		var at := Vector2(shelf.position.x + 8.0 + slot * (k + 0.5), shelf.get_center().y)
		_prize(String(_won_kinds[k]), at, slot, 1.0)
	var bc := Vector2(fp.end.x - fp.size.x * 0.11, fp.get_center().y)
	var br := minf(fp.size.y * 0.34, 30.0 * u + 10)
	var pressed := _mode == "drop"
	draw_circle(bc + Vector2(0, 6), br, Color("8a1030"))
	draw_circle(bc + (Vector2(0, 4) if pressed else Vector2.ZERO), br, Color("ff3b5c"))
	draw_circle(bc + Vector2(-br * 0.3, -br * 0.35), br * 0.3, Color(1, 1, 1, 0.45))
	# capsules falling into the chute
	if _drop_k >= 0.0:
		var from := Vector2(floor_x(-0.02), _rail_y + 80 * u)
		var to := Vector2(from.x, chute.get_center().y)
		for k in _held.size():
			var i := int(_held[k])
			if i < balls.size():
				_capsule(from.lerp(to, _drop_k) + Vector2((k - (_held.size() - 1) * 0.5) * _r() * 1.1, -k * 8.0), _r() * (1.0 - 0.3 * _drop_k),
					String(balls[i].tier), false, i)


func _draw_reveal(u: float) -> void:
	var c := _stage_center()
	var k := time - float(_reveal.t0)
	var tier := String(_reveal.tier)
	var tc: Color = MgLogic.TIER_TINTS.get(tier, Color.WHITE)
	var r := 58.0 * u
	draw_circle(c, r * 2.2, Color(0, 0, 0, 0.35))
	glow(c, r * 2.4, Color(tc.r, tc.g, tc.b, 0.7))
	var split := clampf((k - dur(0.3)) / dur(0.25), 0.0, 1.0)
	if split <= 0.0:
		# wobble before it pops
		var wob := sin(k * 38.0) * 0.18 * clampf(k / dur(0.3), 0.0, 1.0)
		draw_set_transform(c, wob, Vector2.ONE)
		_capsule(Vector2.ZERO, r, tier, false, 0)
		draw_set_transform(Vector2.ZERO)
		return
	# the halves fly apart, the prize rises between them
	var top := c + Vector2(-split * r * 1.2, -split * r * 1.4)
	var bot := c + Vector2(split * r * 1.1, split * r * 0.6)
	var a := 1.0 - split * 0.8
	draw_set_transform(top, -split * 1.2, Vector2.ONE)
	_half(r, tc, true, a)
	draw_set_transform(bot, split * 0.9, Vector2.ONE)
	_half(r, Color("f4f2ff"), false, a)
	draw_set_transform(Vector2.ZERO)
	var s := r * (1.4 + 0.5 * split) * (1.0 + 0.15 * sin(clampf(split, 0.0, 1.0) * PI))
	_prize(String(_reveal.kind), c - Vector2(0, split * r * 0.3), s * 1.6, 1.0)


func _half(r: float, col: Color, top: bool, a: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0 if top else PI * i / 16.0
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, Color(col, a))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(UiPalette.OUTLINE, a), 4.0, true)


## A prize capsule: tier-coloured top, pearly bottom, a seam, a shine; `hot` = in the claw's
## reach now; the legendary one shimmers.
func _capsule(p: Vector2, r: float, tier: String, hot: bool, seed_i: int) -> void:
	var tc: Color = MgLogic.TIER_TINTS.get(tier, Color("8fd0ff"))
	if tier == "legendary":
		glow(p, r * 1.9, Color(1.0, 0.8, 0.3, 0.55 + 0.25 * sin(_bulbs * 4.0 + seed_i)))
	elif tier == "epic":
		glow(p, r * 1.5, Color(0.75, 0.45, 1.0, 0.35))
	draw_circle(p + Vector2(0, r * 0.1), r * 1.04, Color(0, 0, 0, 0.3))
	draw_circle(p, r + 2.5, UiPalette.OUTLINE)
	draw_circle(p, r, Color("e9e6f5"))
	# the tier-coloured top half
	var pts := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		pts.append(p + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, tc)
	draw_line(p + Vector2(-r, 0), p + Vector2(r, 0), UiPalette.OUTLINE, 3.0, true)
	draw_line(p + Vector2(-r * 0.9, r * 0.14), p + Vector2(r * 0.9, r * 0.14), Color(1, 1, 1, 0.5), 2.0, true)
	draw_circle(p + Vector2(-r * 0.38, -r * 0.45), r * 0.24, Color(1, 1, 1, 0.65))
	draw_circle(p + Vector2(r * 0.3, r * 0.5), r * 0.14, Color(1, 1, 1, 0.3))
	if tier == "legendary":
		_star4(p + Vector2(r * 0.55, -r * 0.6), r * (0.3 + 0.1 * sin(_bulbs * 6.0)), Color.WHITE)
	if hot:
		draw_arc(p, r + 6.0, 0.0, TAU, 32, Color(1, 1, 1, 0.75 + 0.25 * sin(_bulbs * 10.0)), 4.0, true)


func _draw_claw(top: Vector2, u: float) -> void:
	rrect(Rect2(top + Vector2(-26, -14) * u, Vector2(52, 24) * u), Color("5e6a86"), 6 * u)
	rrect(Rect2(top + Vector2(-26, -14) * u, Vector2(52, 8) * u), Color("aeb8cf"), 6 * u)
	var head := _head()
	draw_line(top, head, UiPalette.OUTLINE, 6.0 * u, true)
	draw_line(top, head, Color("c8cfdd"), 3.0 * u, true)
	draw_circle(head, 16 * u, UiPalette.OUTLINE)
	draw_circle(head, 13 * u, Color("ffc93d"))
	draw_circle(head + Vector2(-4, -4) * u, 5 * u, Color(1, 1, 1, 0.6))
	var balls: Array = state.get("balls", [])
	if _drop_k < 0.0:
		for k in _held.size():
			var i := int(_held[k])
			if i < balls.size():
				_capsule(_held_pos(k, _held.size()), _r(), String(balls[i].tier), false, i)
	var spread := lerpf(0.15, 0.8, _open)
	for s in [-1.0, 0.0, 1.0]:
		var a := head + Vector2(s * 10 * u, 8 * u)
		var knee := a + Vector2(s * 40 * u * spread + s * 10 * u, 26 * u)
		var tip := knee + Vector2(-s * 22 * u * (1.2 - spread), 30 * u)
		for pass_i in 2:
			var col := UiPalette.OUTLINE if pass_i == 0 else Color("d6dcea")
			var wd := (11.0 if pass_i == 0 else 6.0) * u
			draw_line(a, knee, col, wd, true)
			draw_line(knee, tip, col, wd, true)
		draw_circle(knee, 5 * u, Color("8e98ae"))


## A prize icon centred at c, size s (the KayKit model, or a vector stand-in).
func _prize(kind: String, c: Vector2, s: float, a: float) -> void:
	var spec: Array = PRIZE_ICONS.get(kind, [])
	var tex: Texture2D = ModelIcons.get_icon(String(spec[0]), float(spec[1])) if not spec.is_empty() else null
	if tex:
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, a))
		return
	var col: Color = MgLogic.PRIZE_COLORS.get(kind, Color.WHITE)
	draw_circle(c, s * 0.3 + 3.0, Color(UiPalette.OUTLINE, a))
	draw_circle(c, s * 0.3, Color(col, a))

class_name PlinkoBoard
extends MgBoard
## Plinko: an upright arcade cabinet. A dropper rides the slot rail on top holding the die-ball;
## it follows the pointer / finger (press anywhere on the board, slide to aim, release to drop;
## a plain tap drops at the tapped slot). 8 rows of glowing pegs (one golden: x2) over 9 prize
## buckets whose values (and 3D prize icons) are public from the start. The bounces are the
## core's (info.path, drawn at the drop): the ball hops peg to peg along that path, the pegs
## flash and plink, the golden peg bursts "x2!", the bucket lights up and pays out.
## Position unit (core): x2 = 2 x bucket index; the ball sits on peg (row k, path[k]).

const ROWS := 8
const BUCKETS := 9
const X2_MAX := 16

## Bucket look per prize value: [colour, icon model, icon yaw].
const LOOKS := {
	1: [Color("5ab8ff"), ModelIcons.K + "resources/Money_Coins_Stack_Small.gltf", 30.0],
	2: [Color("4fd8b4"), ModelIcons.K + "resources/Money_Pile_Small.gltf", 25.0],
	3: [Color("8fd85a"), ModelIcons.K + "resources/Money_Pile_Medium.gltf", 25.0],
	5: [Color("c98cff"), ModelIcons.K + "resources/Gem_Medium.gltf", 25.0],
	6: [Color("ff6fb0"), ModelIcons.K + "resources/Gem_Large.gltf", 25.0],
	10: [Color("ffc93d"), ModelIcons.K + "resources/Gems_Chest.gltf", 25.0],
}
const GOLD := Color("ffd23d")
const PEG := Color("bff8ea")
const FIELD := Color("0f1d33")

var _cab := Rect2()
var _field := Rect2()
var _bw := 40.0
var _dy := 40.0
var _hdr := Rect2()
var _rail_y := 0.0
var _drop_y := 0.0
var _row0 := 0.0
var _bucket_top := 0.0
var _bucket_h := 60.0

var _aim := 4                 # the slot the dropper is over
var _drop_x := 4.0            # dropper position (slot units, eased)
var _hovering := false        # a mouse is over the board (desktop hover hint)
var _held := false            # press in progress (aiming)
var _animating := false
var _in_flight := false       # a ball has left the rack (sent or falling)
var _claw_open := 0.0

var _ball_on := false
var _ball := Vector2.ZERO
var _ball_rot := 0.0
var _ball_face := 6
var _ball_sq := 0.0
var _ball_gold := false
var _ball_scale := 1.0
var _trail: Array = []

var _peg_flash := {}          # Vector2i(row, x2) -> time
var _bucket_flash := {}       # bucket -> time
var _queued: Dictionary = {}


func set_state(st: Dictionary, instant := true) -> void:
	if _animating:
		_queued = st.duplicate(true)
		return
	super.set_state(st, instant)
	unlock()


func unlock() -> void:
	super.unlock()
	if not _animating:
		_in_flight = false


func is_settled() -> bool:
	return not _animating


func status_text() -> String:
	for d: Dictionary in state.get("drops", []):
		if bool(d.get("golden", false)):
			return "Golden peg x2!"
	return ""


# --- layout ------------------------------------------------------------------------------

## Cabinet: header (rack + tally), slot rail with the dropper, 8 peg rows, the buckets.
## Everything scales with the bucket width _bw; rows stretch (to 1.45 bw) on tall boards.
func _layout() -> void:
	var avail := size - Vector2(12, 12)
	var fixed := 5.4
	var bw := minf(avail.x / 10.2, avail.y / (fixed + 7.9 * 0.85))
	bw = maxf(bw, 8.0)
	var dy := clampf((avail.y - fixed * bw) / 7.9, 0.85 * bw, 1.45 * bw)
	# a tall board: the leftover height goes to deeper buckets (bigger prizes)
	var extra := clampf(avail.y - fixed * bw - 7.9 * dy, 0.0, bw * 0.7)
	_bw = bw
	_dy = dy
	var w := bw * 10.2
	var h := fixed * bw + 7.9 * dy + extra
	_cab = Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))
	var fx := _cab.position.x + bw * 0.6
	_hdr = Rect2(Vector2(fx, _cab.position.y + bw * 0.28), Vector2(bw * 9.0, bw * 0.9))
	_rail_y = _hdr.end.y + bw * 0.28
	_drop_y = _rail_y + bw * 0.62
	_row0 = _rail_y + bw * 1.9
	_bucket_top = _row0 + 7.0 * dy + dy * 0.85
	_bucket_h = bw * 1.75 + extra
	_field = Rect2(Vector2(fx, _hdr.end.y + bw * 0.14), Vector2(bw * 9.0, _bucket_top + _bucket_h - _hdr.end.y - bw * 0.14))


func slot_x(slot: float) -> float:
	return _field.position.x + _bw * (slot + 0.5)


func peg_pos(row: int, x2: int) -> Vector2:
	return Vector2(_field.position.x + _bw * (x2 * 0.5 + 0.5), _row0 + row * _dy)


## Where the ball rests on peg (row, x2).
func rest_pos(row: int, x2: int) -> Vector2:
	return peg_pos(row, x2) - Vector2(0, _peg_r() + _ball_r() * 0.95)


func bucket_rect(b: int) -> Rect2:
	return Rect2(Vector2(_field.position.x + b * _bw, _bucket_top), Vector2(_bw, _bucket_h))


func _peg_r() -> float:
	return maxf(3.0, _bw * 0.1 + _dy * 0.02)


func _ball_r() -> float:
	return _bw * 0.33


## The slot under board x (clamped).
func slot_at(x: float) -> int:
	return clampi(int(floor((x - _field.position.x) / _bw)), 0, BUCKETS - 1)


func _can_aim() -> bool:
	return not locked and not _animating and int(state.get("actions_left", 0)) > 0 and not bool(state.get("done", false))


# --- input ---------------------------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	_layout()
	var mb := e as InputEventMouseButton
	var mm := e as InputEventMouseMotion
	if mm:
		_hovering = true
		if _can_aim() and (_held or mm.button_mask == 0):
			_set_aim(slot_at(mm.position.x))
		return
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		if not _can_aim():
			return
		_held = true
		_set_aim(slot_at(mb.position.x))
		MgBoard.sfx("click", 0.1, -8.0)
	elif _held:
		_held = false
		# release far below the cabinet = cancel (slide off to think again)
		if mb.position.y > _cab.end.y + _bw or not _can_aim():
			return
		_set_aim(slot_at(mb.position.x))
		drop(_aim)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hovering = false


func _set_aim(s: int) -> void:
	if s != _aim:
		_aim = s
		MgBoard.sfx("tick", 0.08, -14.0)


func drop(slot: int) -> void:
	if not _can_aim():
		return
	_in_flight = true
	_claw_open = 1.0
	MgBoard.sfx("pop")
	send([slot])


## Harness: slide the dropper from where it is to the slot and let go (a player's drag).
func scripted_input(args: Array, drv: Node) -> bool:
	var guard := 0
	while (_animating or locked) and guard < 400:
		guard += 1
		await get_tree().process_frame
	_layout()
	var o := get_global_rect().position
	var slot := clampi(int(args[0]) if not args.is_empty() else 4, 0, BUCKETS - 1)
	# press on the dropper, slide it over the slot, let go
	var pts: Array = []
	var from := _drop_x
	for k in 8:
		pts.append(o + Vector2(slot_x(lerpf(from, float(slot), k / 7.0)), _drop_y + k))
	await drv.drag(pts)
	return true


# --- animation -------------------------------------------------------------------------------

func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	_layout()
	var info: Dictionary = ev.get("info", {})
	var path: Array = info.get("path", [])
	if path.size() < ROWS + 1:
		_adopt(ev.get("state", {}))
		unlock()
		return
	_animating = true
	_in_flight = true
	_held = false
	var slot := int(info.get("slot", _aim))
	_aim = slot
	# the dropper slides over (a tap far away) and lets go
	if absf(_drop_x - slot) > 0.05:
		var t := create_tween()
		t.tween_property(self, "_drop_x", float(slot), dur(0.12)).set_trans(Tween.TRANS_SINE)
		await t.finished
	_claw_open = 1.0
	_ball_on = true
	_ball_gold = false
	_ball_scale = 1.0
	_ball = _dropper_ball()
	_trail.clear()
	var gold: Array = state.get("golden", [])
	# fall onto the first peg
	await _hop(_ball, rest_pos(0, int(path[0])), -_bw * 0.1, dur(0.26), 0.0)
	_hit(0, int(path[0]), gold)
	for k in range(1, ROWS):
		var a := rest_pos(k - 1, int(path[k - 1]))
		var b := rest_pos(k, int(path[k]))
		var dir := signf(b.x - a.x)
		await _hop(a, b, _dy * randf_range(0.28, 0.5), dur(0.2 - k * 0.006), dir)
		_hit(k, int(path[k]), gold)
	# the last hop drops into the bucket
	var bucket := int(info.get("bucket", int(path[ROWS]) / 2))
	var a2 := rest_pos(ROWS - 1, int(path[ROWS - 1]))
	var land := Vector2(slot_x(bucket), _bucket_top + _bw * 0.35)
	await _hop(a2, land, _dy * 0.35, dur(0.26), signf(land.x - a2.x))
	_land(info)
	_adopt(ev.get("state", {}))
	# the ball sinks into the bucket
	var t2 := create_tween()
	t2.tween_property(self, "_ball_scale", 0.0, dur(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await t2.finished
	_ball_on = false
	_trail.clear()
	await wait(0.35)
	_claw_open = 0.0
	_animating = false
	_in_flight = false
	unlock()


func _adopt(st: Dictionary) -> void:
	if not _queued.is_empty() and st.is_empty():
		st = _queued
	_queued = {}
	state = st.duplicate(true)
	_in_flight = false


func _dropper_ball() -> Vector2:
	return Vector2(slot_x(_drop_x), _drop_y + _bw * 0.12)


## One bounce: a short parabola from a to b (apex `hop` above the straight line), with a
## little sideways wobble that still lands exactly; the die tumbles a quarter turn.
func _hop(a: Vector2, b: Vector2, hop: float, t: float, dir: float) -> void:
	var jit := randf_range(-0.12, 0.12) * _bw
	var r0 := _ball_rot
	var turn := dir * PI * 0.5 if dir != 0.0 else randf_range(-0.6, 0.6)
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		var p := a.lerp(b, k)
		p.x += jit * sin(PI * k)
		p.y = lerpf(a.y, b.y, k * k * 0.6 + k * 0.4) - hop * 4.0 * k * (1.0 - k)
		_ball = p
		_ball_rot = r0 + turn * ease(k, 0.6), 0.0, 1.0, maxf(t, 0.03))
	await tw.finished


func _hit(row: int, x2: int, gold: Array) -> void:
	var p := peg_pos(row, x2)
	_peg_flash[Vector2i(row, x2)] = time
	_ball_sq = 1.0
	_ball_face = randi_range(1, 6)
	MgBoard.sfx("plink", 0.2, -3.0)
	burst(p, PEG, 4, "spark", 120.0, 30.0, 4.0)
	if gold.size() == 2 and row == int(gold[0]) and x2 == int(gold[1]):
		_ball_gold = true
		MgBoard.sfx("bell")
		burst(p, GOLD, 26, "star", 300.0, 60.0, 9.0)
		ring(p, GOLD, _bw * 1.6, 0.55, 7.0)
		ring(p, Color.WHITE, _bw * 0.9, 0.35, 4.0)
		float_text(p + Vector2(0, -_bw * 0.6), "x2!", GOLD, int(clampf(_bw * 0.95, 28, 56)), 1.1)
		shake(6.0)
		kick.emit(0.35, Color(1.0, 0.85, 0.3, 0.35))


func _land(info: Dictionary) -> void:
	var b := int(info.get("bucket", 0))
	var v := int(info.get("value", 0))
	var pts := int(info.get("points", v))
	var gold := bool(info.get("golden", false))
	var r := bucket_rect(b)
	var c := r.get_center()
	var col := _bucket_col(v)
	_bucket_flash[b] = time
	var big := v >= 5 or gold
	burst(c, col, 18 + (16 if big else 0), "star", 280.0 + (120.0 if big else 0.0), 160.0, 8.0)
	burst(c, col.lightened(0.4), 10, "spark", 220.0, 200.0, 5.0)
	if v >= 10:
		burst(c, GOLD, 30, "flake", 360.0, 320.0, 8.0)
	ring(c, col.lightened(0.3), _bw * 1.4, 0.5, 6.0)
	var txt := ("+%d x2!" % pts) if gold else "+%d" % pts
	float_text(Vector2(clampf(c.x, _field.position.x + _bw * 1.2, _field.end.x - _bw * 1.2), r.position.y - _bw * 0.3), txt, GOLD if gold else col.lightened(0.6), int(clampf(_bw * (1.0 if big else 0.85), 26, 60)), 1.2)
	shake(3.0 + (5.0 if big else 0.0))
	if v >= 10 or gold:
		MgBoard.sfx("win")
		kick.emit(0.7 if v >= 10 else 0.4, Color(col.r, col.g, col.b, 0.4))
	elif v >= 5:
		MgBoard.sfx("reveal")
		kick.emit(0.3, Color(col.r, col.g, col.b, 0.3))
	else:
		MgBoard.sfx("coin")
	MgBoard.sfx("chip_tick", 0.1, -6.0)


func _tick(dt: float) -> void:
	var target := float(_aim)
	_drop_x = lerpf(_drop_x, target, 1.0 - exp(-dt * 16.0))
	_ball_sq = maxf(0.0, _ball_sq - dt * 7.0)
	if _claw_open > 0.0 and not _animating:
		_claw_open = maxf(0.0, _claw_open - dt * 3.0)
	if _ball_on:
		_trail.push_front(_ball)
		if _trail.size() > 7:
			_trail.pop_back()


# --- drawing ---------------------------------------------------------------------------------

func _bucket_col(v: int) -> Color:
	var l: Array = LOOKS.get(v, [Color("8fd0ff")])
	return l[0]


func _draw_board() -> void:
	_layout()
	var c := _cab
	var bw := _bw
	var teal: Color = MgLogic.GAME_COLORS.get("plinko", Color("4fd8b4"))
	var rad := bw * 0.7
	# cabinet body
	rrect(Rect2(c.position + Vector2(0, bw * 0.25), c.size), Color(0, 0, 0, 0.45), rad)
	rrect(c.grow(4.0), UiPalette.OUTLINE, rad + 4.0)
	rrect(c, teal.darkened(0.45), rad)
	rrect(Rect2(c.position, c.size - Vector2(0, bw * 0.22)), teal.darkened(0.12), rad)
	rrect(Rect2(c.position + Vector2(c.size.x * 0.05, bw * 0.08), Vector2(c.size.x * 0.9, bw * 0.16)), Color(1, 1, 1, 0.22), bw * 0.08)
	# side bulbs chase
	var nb := int(clampf(c.size.y / (bw * 0.9), 6, 30))
	for side in [0, 1]:
		var x := c.position.x + bw * 0.3 if int(side) == 0 else c.end.x - bw * 0.3
		for k in nb:
			var y := c.position.y + rad + k * (c.size.y - rad * 2.0) / float(nb - 1)
			var on := (int(time * 7.0) + k + int(side)) % 3 == 0
			draw_circle(Vector2(x, y), bw * 0.07 + 1.5, UiPalette.OUTLINE)
			draw_circle(Vector2(x, y), bw * 0.07, Color("fff2a0") if on else Color("2a8f7c"))
	_draw_header()
	# the play field
	var f := _field
	rrect(f.grow(4.0), UiPalette.OUTLINE, bw * 0.34)
	rrect(f, FIELD, bw * 0.3)
	for k in 8:
		var band := Rect2(f.position + Vector2(0, k * f.size.y / 8.0), Vector2(f.size.x, f.size.y / 8.0))
		draw_rect(band.grow_individual(-bw * 0.2, 0, -bw * 0.2, 0), Color(0.3, 0.9, 0.75, 0.012 * (8 - k)))
	for k in 12:
		var hx := float(hash(k * 97 + 1) % 1000) / 1000.0
		var hy := float(hash(k * 53 + 7) % 1000) / 1000.0
		var tw := 0.5 + 0.5 * sin(time * 1.7 + k * 1.3)
		_star4(f.position + Vector2(bw * 0.3 + hx * (f.size.x - bw * 0.6), bw * 0.3 + hy * (f.size.y * 0.8)), 1.5 + 2.5 * tw, Color(1, 1, 1, 0.14 * tw))
	_draw_aim_hint()
	_draw_rail()
	_draw_pegs()
	_draw_buckets()
	# glass sheen over the field
	var gl := PackedVector2Array([f.position + Vector2(f.size.x * 0.6, 0), f.position + Vector2(f.size.x * 0.7, 0),
		f.position + Vector2(f.size.x * 0.38, f.size.y), f.position + Vector2(f.size.x * 0.28, f.size.y)])
	draw_colored_polygon(gl, Color(1, 1, 1, 0.035))
	rrect(f, Color(0, 0, 0, 0), bw * 0.3, 2, Color(1, 1, 1, 0.1))
	_draw_ball()


func _draw_header() -> void:
	var h := _hdr
	var bw := _bw
	rrect(h, Color(0.03, 0.08, 0.12, 0.75), h.size.y * 0.4, 2, UiPalette.OUTLINE)
	# the rack: balls still to drop
	var left := int(state.get("actions_left", 0)) - (1 if _in_flight else 0)
	var total := int(state.get("actions_left", 0)) + (state.get("drops", []) as Array).size()
	total = maxi(total, 3)
	var ds := h.size.y * 0.62
	for k in total:
		var p := Vector2(h.position.x + h.size.y * 0.5 + k * ds * 1.15, h.get_center().y)
		var r := Rect2(p - Vector2(ds, ds) * 0.5, Vector2(ds, ds))
		if k < left:
			var bob := sin(time * 3.0 + k) * 1.5
			die_face(Rect2(r.position + Vector2(0, bob), r.size), 6 - k)
		else:
			rrect(r, Color(1, 1, 1, 0.06), ds * 0.2, 2, Color(1, 1, 1, 0.14))
	# title
	var rack_w := h.size.y * 0.5 + total * ds * 1.15
	var drops: Array = state.get("drops", [])
	var chip_w := h.size.y * 1.25
	var tally_w := 3.0 * (chip_w + 4.0)
	var mid := Rect2(Vector2(h.position.x + rack_w, h.position.y), Vector2(h.size.x - rack_w - tally_w, h.size.y))
	if mid.size.x > bw * 1.8:
		text_c(mid.get_center(), "PLINKO", int(clampf(h.size.y * 0.55, 12, 40)), Color("ffe07a"), maxi(4, int(h.size.y * 0.14)))
	# the tally: one chip per drop made
	for k in 3:
		var r := Rect2(Vector2(h.end.x - (3 - k) * (chip_w + 4.0) - 2.0, h.position.y + h.size.y * 0.16), Vector2(chip_w, h.size.y * 0.68))
		if k < drops.size():
			var d: Dictionary = drops[k]
			var g := bool(d.get("golden", false))
			var col := _bucket_col(int(d.get("value", 1)))
			rrect(r, col.darkened(0.35), r.size.y * 0.4, 2, GOLD if g else UiPalette.OUTLINE)
			text_c(r.get_center(), "+%d" % int(d.get("points", 0)), int(r.size.y * 0.62), Color.WHITE, maxi(3, int(r.size.y * 0.12)))
		else:
			rrect(r, Color(1, 1, 1, 0.05), r.size.y * 0.4, 2, Color(1, 1, 1, 0.12))
			text_c(r.get_center(), "-", int(r.size.y * 0.55), Color(1, 1, 1, 0.2))


## A faint glow over the buckets the ball tends to reach from the aimed slot (Plinko.odds).
func _draw_aim_hint() -> void:
	if not _can_aim() or not (_hovering or _held):
		return
	var o := Plinko.odds(_aim, state.get("golden", []))
	var probs: Array = o.probs
	var mx := 0.0001
	for p in probs:
		mx = maxf(mx, float(p))
	for b in BUCKETS:
		var k := float(probs[b]) / mx
		if k < 0.02:
			continue
		var r := bucket_rect(b)
		var cc := Color(0.75, 1.0, 0.95, 0.16 * k)
		draw_rect(Rect2(r.position + Vector2(2, -_dy * 0.9), Vector2(r.size.x - 4, _dy * 0.9)), Color(cc.r, cc.g, cc.b, cc.a * 0.5))
		glow(Vector2(r.get_center().x, r.position.y), _bw * 0.8, Color(0.7, 1.0, 0.9, 0.5 * k), 4)
	# the drop line
	var x := slot_x(_drop_x)
	var yy := _drop_y + _bw * 0.5
	while yy < _row0 - _peg_r() - _ball_r():
		draw_line(Vector2(x, yy), Vector2(x, minf(yy + 5.0, _row0)), Color(0.8, 1.0, 0.95, 0.4), 2.0)
		yy += 10.0


func _draw_rail() -> void:
	var bw := _bw
	var f := _field
	# slot notches: chevrons under the rail, the aimed one lit
	for s in BUCKETS:
		var x := slot_x(s)
		var y := _rail_y + bw * 1.28
		var lit := s == _aim and _can_aim()
		var col := Color("ffe07a") if lit else Color(0.75, 1.0, 0.92, 0.22)
		var ww := bw * (0.2 if lit else 0.14)
		var bob := sin(time * 6.0) * bw * 0.05 if lit else 0.0
		var tri := PackedVector2Array([Vector2(x - ww, y - ww * 0.6 + bob), Vector2(x + ww, y - ww * 0.6 + bob), Vector2(x, y + ww * 0.6 + bob)])
		draw_colored_polygon(tri, col)
	# the rail bar
	var rr := Rect2(Vector2(f.position.x + bw * 0.1, _rail_y - bw * 0.07), Vector2(f.size.x - bw * 0.2, bw * 0.18))
	rrect(rr.grow(2.0), UiPalette.OUTLINE, bw * 0.1)
	rrect(rr, Color("9aa3b8"), bw * 0.08)
	draw_rect(Rect2(rr.position, Vector2(rr.size.x, rr.size.y * 0.35)), Color("dfe6f2"))
	# the dropper carriage
	var x0 := slot_x(_drop_x)
	var body := Rect2(Vector2(x0 - bw * 0.36, _rail_y - bw * 0.2), Vector2(bw * 0.72, bw * 0.34))
	rrect(body.grow(2.0), UiPalette.OUTLINE, bw * 0.12)
	rrect(body, Color("ff6f9a"), bw * 0.1)
	draw_rect(Rect2(body.position + Vector2(bw * 0.06, bw * 0.04), Vector2(body.size.x - bw * 0.12, bw * 0.07)), Color(1, 1, 1, 0.35))
	var open := _claw_open
	var holding := _can_aim() or (locked and not _ball_on and _in_flight)
	if holding and not _ball_on:
		var bob := sin(time * 4.0) * bw * 0.03
		_die(Vector2(x0, _drop_y + bob), sin(time * 2.0) * 0.12, 6, 0.0, false, 1.0)
	for sd in [-1.0, 1.0]:
		var a := Vector2(x0 + sd * bw * 0.22, body.end.y - 2.0)
		var knee := a + Vector2(sd * bw * (0.14 + 0.18 * open), bw * 0.3)
		var tip := knee + Vector2(-sd * bw * (0.12 - 0.12 * open), bw * 0.28)
		for pass_i in 2:
			var col := UiPalette.OUTLINE if pass_i == 0 else Color("d6dcea")
			var wd := bw * (0.13 if pass_i == 0 else 0.07)
			draw_line(a, knee, col, wd, true)
			draw_line(knee, tip, col, wd, true)


func _draw_pegs() -> void:
	var pr := _peg_r()
	var gold: Array = state.get("golden", [])
	for k in ROWS:
		var x2 := k % 2
		while x2 <= X2_MAX:
			var p := peg_pos(k, x2)
			var key := Vector2i(k, x2)
			var fl := 0.0
			if _peg_flash.has(key):
				fl = clampf(1.0 - (time - float(_peg_flash[key])) / 0.45, 0.0, 1.0)
				if fl <= 0.0:
					_peg_flash.erase(key)
			var is_gold := gold.size() == 2 and k == int(gold[0]) and x2 == int(gold[1])
			if is_gold:
				_gold_peg(p, pr, fl)
			else:
				var tw := float(hash(key) % 1000) / 1000.0
				var glint := maxf(0.0, sin(time * 1.3 + tw * 40.0)) ** 12
				glow(p, pr * (2.6 + 3.0 * fl), Color(0.5, 1.0, 0.85, 0.35 + 0.2 * glint + 0.6 * fl), 4)
				var r := pr * (1.0 + 0.45 * fl)
				draw_circle(p + Vector2(0, pr * 0.3), r + 1.5, Color(0, 0, 0, 0.35))
				draw_circle(p, r + 1.5, UiPalette.OUTLINE)
				draw_circle(p, r, PEG.lerp(Color.WHITE, fl))
				draw_circle(p + Vector2(-r * 0.3, -r * 0.35), r * 0.38, Color(1, 1, 1, 0.8))
			x2 += 2


func _gold_peg(p: Vector2, pr: float, fl: float) -> void:
	var pulse := 0.5 + 0.5 * sin(time * 4.0)
	glow(p, pr * (4.5 + 1.5 * pulse + 3.0 * fl), Color(1.0, 0.8, 0.25, 0.7 + 0.3 * fl), 6)
	var r := pr * (1.45 + 0.4 * fl)
	draw_circle(p + Vector2(0, pr * 0.3), r + 2.0, Color(0, 0, 0, 0.35))
	draw_circle(p, r + 2.0, UiPalette.OUTLINE)
	draw_circle(p, r, GOLD.lerp(Color.WHITE, fl * 0.6))
	draw_circle(p + Vector2(0, r * 0.25), r * 0.7, GOLD.darkened(0.15))
	draw_circle(p + Vector2(-r * 0.3, -r * 0.35), r * 0.36, Color(1, 1, 1, 0.85))
	# orbiting sparkles
	for i in 3:
		var a := time * 1.8 + i * TAU / 3.0
		var sp := p + Vector2(cos(a), sin(a)) * r * 2.1
		_star4(sp, r * (0.45 + 0.25 * sin(time * 6.0 + i)), Color(1.0, 0.95, 0.7, 0.9))
	if _bw > 26.0:
		text_c(p + Vector2(0, -r * 2.2), "x2", int(clampf(_bw * 0.34, 10, 22)), GOLD, 4)


func _draw_buckets() -> void:
	var bw := _bw
	var vals: Array = state.get("buckets", [])
	var f := _field
	# tray floor
	var tray := Rect2(Vector2(f.position.x, _bucket_top), Vector2(f.size.x, _bucket_h))
	draw_rect(tray, Color(0.02, 0.05, 0.1, 0.6))
	for b in BUCKETS:
		var r := bucket_rect(b).grow_individual(-bw * 0.05, 0, -bw * 0.05, -bw * 0.05)
		var v := int(vals[b]) if b < vals.size() else 0
		var col := _bucket_col(v)
		var fl := 0.0
		if _bucket_flash.has(b):
			fl = clampf(1.0 - (time - float(_bucket_flash[b])) / 0.9, 0.0, 1.0)
		var jack := v >= 10
		if jack:
			glow(r.get_center(), bw * 1.1, Color(1.0, 0.8, 0.3, 0.35 + 0.15 * sin(time * 3.0)), 5)
		if fl > 0.0:
			glow(r.get_center(), bw * (1.0 + fl), Color(col.r, col.g, col.b, fl), 5)
			# a beam of light rising from the winning bucket
			var bh := _dy * 3.2 * (0.6 + 0.4 * fl)
			for i in 6:
				var k := float(i) / 6.0
				draw_rect(Rect2(Vector2(r.position.x + bw * 0.08, r.position.y - bh * (1.0 - k)), Vector2(r.size.x - bw * 0.16, bh / 6.0)),
					Color(col.r, col.g, col.b, 0.07 * fl * (1.0 + 4.0 * k)))
		rrect(r, col.darkened(0.55).lerp(col, fl * 0.6), bw * 0.14, 2, UiPalette.OUTLINE)
		var top := Rect2(r.position, Vector2(r.size.x, bw * 0.16))
		rrect(top, col.lerp(Color.WHITE, fl), bw * 0.08)
		# prize icon + value
		var pop := 1.0 + 0.35 * sin(clampf(1.0 - fl, 0.0, 1.0) * PI) * fl
		var isz := minf(r.size.x * 1.05, bw * 1.1) * pop * (1.08 if jack else 1.0)
		var ic := Vector2(r.get_center().x, r.position.y + r.size.y * 0.42 + sin(time * 2.2 + b) * bw * 0.03)
		_prize(v, ic, isz)
		text_c(Vector2(r.get_center().x, r.end.y - r.size.y * 0.17), str(v), int(clampf(bw * (0.5 if v < 10 else 0.46), 11, 34)),
			GOLD if jack else col.lightened(0.45), maxi(3, int(bw * 0.12)))
	# the balls that landed: little dice resting in their buckets
	var landed := {}
	for d: Dictionary in state.get("drops", []):
		var b := int(d.get("bucket", 0))
		var n := int(landed.get(b, 0))
		landed[b] = n + 1
		var ds := bw * 0.34
		var r := bucket_rect(b)
		var p := Vector2(r.get_center().x + (n - 0.5 * minf(n, 1.0)) * ds * 0.55 * (1.0 if n % 2 == 0 else -1.0), r.position.y + bw * 0.3 - n * ds * 0.2)
		draw_set_transform(p, 0.25 * (1.0 if (b + n) % 2 == 0 else -1.0), Vector2.ONE)
		die_face(Rect2(-ds * 0.5, -ds * 0.5, ds, ds), 6 - n % 6, Color("ffe27a") if bool(d.get("golden", false)) else UiPalette.DIE_BODY)
		draw_set_transform(Vector2.ZERO)
	# dividers: posts between buckets rising a little into the field
	for b in BUCKETS + 1:
		var x := f.position.x + b * bw
		var y0 := _bucket_top - _dy * 0.3
		if b == 0 or b == BUCKETS:
			continue
		draw_line(Vector2(x, y0), Vector2(x, _bucket_top + _bucket_h), UiPalette.OUTLINE, bw * 0.12 + 2.0, true)
		draw_line(Vector2(x, y0), Vector2(x, _bucket_top + _bucket_h), Color("7fe8cf"), bw * 0.07, true)
		draw_circle(Vector2(x, y0), bw * 0.07 + 1.5, UiPalette.OUTLINE)
		draw_circle(Vector2(x, y0), bw * 0.07, Color("dffcf4"))


## A prize icon for a bucket value (the KayKit model, or a vector stand-in).
func _prize(v: int, c: Vector2, s: float) -> void:
	var l: Array = LOOKS.get(v, [])
	var tex: Texture2D = ModelIcons.get_icon(String(l[1]), float(l[2])) if not l.is_empty() else null
	if tex:
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		return
	var col := _bucket_col(v)
	if v >= 5:
		var pts := PackedVector2Array([c + Vector2(0, -s * 0.3), c + Vector2(s * 0.26, -s * 0.05), c + Vector2(0, s * 0.3), c + Vector2(-s * 0.26, -s * 0.05)])
		draw_colored_polygon(pts, UiPalette.OUTLINE)
		draw_colored_polygon(PackedVector2Array([pts[0] * 0.85 + c * 0.15, pts[1] * 0.85 + c * 0.15, pts[2] * 0.85 + c * 0.15, pts[3] * 0.85 + c * 0.15]), col)
	else:
		for i in mini(v, 3):
			var q := c + Vector2((i - (mini(v, 3) - 1) * 0.5) * s * 0.18, s * 0.08 - i * s * 0.08)
			draw_circle(q, s * 0.17 + 2.0, UiPalette.OUTLINE)
			draw_circle(q, s * 0.17, UiPalette.GOLD)


func _draw_ball() -> void:
	if not _ball_on:
		return
	# motion trail
	for i in range(_trail.size() - 1, 0, -1):
		var k := 1.0 - float(i) / _trail.size()
		var col := Color(1.0, 0.85, 0.35, 0.35 * k) if _ball_gold else Color(0.75, 1.0, 0.95, 0.25 * k)
		draw_circle(_trail[i], _ball_r() * (0.5 + 0.5 * k) * _ball_scale, col)
	if _ball_gold:
		glow(_ball, _ball_r() * 3.0, Color(1.0, 0.8, 0.3, 0.8), 5)
	_die(_ball, _ball_rot, _ball_face, _ball_sq, _ball_gold, _ball_scale)


## The die-ball: a little d6 (golden after the golden peg), squashing on each hit.
func _die(p: Vector2, rot: float, face: int, sq: float, gold: bool, sc: float) -> void:
	if sc <= 0.01:
		return
	var s := _ball_r() * 2.0 * sc
	draw_set_transform(p + Vector2(0, s * 0.1), 0.0, Vector2.ONE)
	draw_circle(Vector2(0, s * 0.35), s * 0.45, Color(0, 0, 0, 0.18))
	draw_set_transform(p, rot, Vector2(1.0 + 0.22 * sq, 1.0 - 0.22 * sq))
	var body := Color("ffe27a") if gold else UiPalette.DIE_BODY
	die_face(Rect2(-s * 0.5, -s * 0.5, s, s), clampi(face, 1, 6), body)
	draw_set_transform(Vector2.ZERO)

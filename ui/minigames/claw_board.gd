class_name ClawBoard
extends MgBoard
## Claw Machine: an arcade cabinet whose floor is a heap of plush fluff (dozens of soft
## puffballs) with 5 prizes nestled in it at the core's depths: coins and potions sit on top,
## the gem and the figure sink in, the legendary gem chest is buried deepest. More fluff
## covers a prize the deeper it is. The claw sweeps at a constant speed (MgLogic.claw_x,
## restarting from the left each grab); a tap drops it ([position 0..1]). The descent into
## the fluff, the puffballs jostling, and the result (grab / slip / miss, plus the puffball
## consolation) all play from the core's minigame_update: nothing is decided here. The aim
## highlight shows the prize's hitbox and, inside it, its narrower grip zone.

const PUFF_COLORS := [Color("ffb3d1"), Color("b3e5ff"), Color("fff0a8"), Color("c9b8ff"), Color("b8f5c8"), Color("ffd0b0"),
	Color("ffffff")]
const PRIZE_ICONS := {"coins": [ModelIcons.COINS, 25.0, 70.0], "potion": [ModelIcons.POTION, 20.0, 72.0],
	"nugget": [ModelIcons.NUGGET, 25.0, 60.0], "gem": [ModelIcons.GEM_SMALL, 25.0, 64.0],
	"figure": [ModelIcons.ACTION_FIGURE, 25.0, 92.0], "legendary": [ModelIcons.GEM_CHEST, 25.0, 88.0], "fluff": ["", 0.0, 44.0]}
const CLAW_COLORS := {"wide": Color("7fb8ff"), "narrow": Color("ffd24a")}

var _cab := Rect2()
var _win := Rect2()
var _floor_y := 0.0
var _rail_y := 0.0
var _heap_h := 100.0
var _swing := 0.0
var _claw := MgLogic.CLAW_MIN
var _mode := "swing"          # swing | drop | idle
var _cable := 0.0             # cable length below the rest position (px)
var _open := 1.0              # prong opening 0 (closed) .. 1 (open)
var _carry := ""              # "" | "prize" | "fluff": what hangs from the claw
var _carry_prize := -1
var _carry_col := Color.WHITE
var _carry_drop := -1.0       # 0..1 fall into the chute
var _slip := 0.0              # a slipping prize's lift (px, tweened up and back)
var _slip_prize := -1
var _won: Array = []          # kinds already won (the shelf), "fluff" included
var _bulbs := 0.0
var _swap_t := -10.0
## Heap puffballs: {n (normalised rest pos: x across the window, y 1 = floor .. 0 = heap top),
## r (fraction of the window width), col, off (px), vel}
var _balls: Array = []


func _init() -> void:
	super._init()
	# a deterministic heap (a look, not a rule): rows of puffballs under a mound surface
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for row in 5:
		var n := 14 - row
		for k in n + 1:
			var nx := (k + rng.randf_range(-0.3, 0.3)) / float(n)
			var ny := 1.0 - (row + rng.randf_range(0.0, 0.5)) / 4.6
			if ny < 1.0 - _mound(nx) * 1.02:
				continue
			_balls.append({"n": Vector2(clampf(nx, 0.02, 0.98), ny), "r": rng.randf_range(0.03, 0.042),
				"col": PUFF_COLORS[rng.randi() % PUFF_COLORS.size()], "off": Vector2.ZERO, "vel": Vector2.ZERO})
	_balls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.n.y < b.n.y)


## Heap height profile (0..1 of the heap height) at normalised x.
static func _mound(nx: float) -> float:
	return 0.55 + 0.4 * sin(clampf(nx, 0.0, 1.0) * PI) + 0.05 * sin(nx * 17.0)


func set_state(st: Dictionary, instant := true) -> void:
	super.set_state(st, instant)
	if instant:
		_won.clear()
		for g: Dictionary in state.get("grabs", []):
			if bool(g.get("grabbed", false)):
				_won.append(String(g.get("kind", "coins")))
			elif bool(g.get("fluff", false)):
				_won.append("fluff")
		_mode = "swing" if int(state.get("actions_left", 0)) > 0 and not bool(state.get("done", false)) else "idle"
		_swing = 0.0
		_cable = 0.0
		_open = 1.0
		_carry = ""
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
	_floor_y = _win.end.y - 8.0
	_heap_h = _win.size.y * 0.3


func floor_x(pos: float) -> float:
	return _win.position.x + 28.0 + pos * (_win.size.x - 56.0)


## Heap surface y at screen x.
func surface_y(x: float) -> float:
	return _floor_y - _heap_h * _mound((x - _win.position.x) / _win.size.x)


func _unit() -> float:
	return _win.size.x / 520.0


func _prize_h(kind: String) -> float:
	return float((PRIZE_ICONS.get(kind, ["", 0.0, 80.0]) as Array)[2]) * _unit() * 0.9


## Bottom-centre point of prize p: sunk into the heap by its depth.
func prize_base(p: Dictionary) -> Vector2:
	var x := floor_x(float(p.pos))
	var d := float(p.get("depth", 0.0))
	return Vector2(x, surface_y(x) + _prize_h(String(p.kind)) * 0.1 + d * _heap_h * 0.6)


func _tick(dt: float) -> void:
	_bulbs += dt
	if _mode == "swing":
		# real time on purpose: the sweep speed is the game's skill, never the game speed
		_swing += dt
		_claw = MgLogic.claw_x(_swing)
	for b: Dictionary in _balls:
		if b.off != Vector2.ZERO or b.vel != Vector2.ZERO:
			b.vel += (-b.off * 60.0 - b.vel * 7.0) * dt
			b.off += b.vel * dt
			if b.off.length() < 0.2 and b.vel.length() < 2.0:
				b.off = Vector2.ZERO
				b.vel = Vector2.ZERO


## Puffballs near screen x bounce away (the claw sinking into the fluff).
func jostle(x: float, strength := 1.0) -> void:
	for b: Dictionary in _balls:
		var p := _ball_pos(b)
		var d := p.x - x
		if absf(d) < 90.0 * _unit():
			b.vel += Vector2(signf(d) * randf_range(80.0, 220.0), randf_range(-260.0, -80.0)) * strength


func _ball_pos(b: Dictionary) -> Vector2:
	var n: Vector2 = b.n
	return Vector2(_win.position.x + n.x * _win.size.x, _floor_y - (1.0 - n.y) * _heap_h * 1.05)


func drop() -> void:
	if locked or _mode != "swing" or int(state.get("actions_left", 0)) <= 0:
		return
	_mode = "drop"
	MgBoard.sfx("claw")
	send([snappedf(_claw, 0.001)])


func claw_kind() -> String:
	return String(state.get("claw", "wide"))


## The two claw selector buttons on the cabinet's front panel: [wide, narrow].
func selector_rects() -> Array:
	_layout()
	var fp := _front_panel()
	var w := fp.size.x * 0.2
	var h := fp.size.y - 24.0
	var x0 := fp.end.x - 12.0 - w * 2.0 - 8.0
	return [Rect2(x0, fp.position.y + 12.0, w, h), Rect2(x0 + w + 8.0, fp.position.y + 12.0, w, h)]


func _front_panel() -> Rect2:
	return Rect2(Vector2(_cab.position.x + _cab.size.x * 0.07, _win.end.y + 16), Vector2(_cab.size.x * 0.86, _cab.end.y - _win.end.y - 40))


## Picks a claw (free, before a grab).
func choose(kind: String) -> void:
	if locked or _mode != "swing" or kind == claw_kind():
		return
	MgBoard.sfx("claw")
	send(["claw", kind])


func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var rs := selector_rects()
		for k in 2:
			if (rs[k] as Rect2).has_point(mb.position):
				choose(String(ClawMachine.CLAWS[k]))
				return
		drop()


func _prizes() -> Array:
	return state.get("prizes", [])


func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	_layout()
	var info: Dictionary = ev.get("info", {})
	if not info.has("x"):
		# a claw swap: the new claw drops onto the trolley
		state = (ev.get("state", {}) as Dictionary).duplicate(true)
		_swap_t = time
		burst(Vector2(floor_x(_claw), _rail_y + 40.0 * _unit()), CLAW_COLORS.get(claw_kind(), Color.WHITE), 12, "star", 200.0, 40.0, 8.0)
		MgBoard.sfx("clink")
		unlock()
		return
	_mode = "drop"
	_claw = float(info.get("x", _claw))
	var hit := int(info.get("prize", -1))
	var grabbed := bool(info.get("grabbed", false))
	var slipped := bool(info.get("slipped", false))
	var u := _unit()
	var x := floor_x(_claw)
	var prizes := _prizes()
	# down into the fluff: to the prize's top (grab / slip) or into the heap surface
	var target := surface_y(x) + 8.0 * u
	if hit >= 0 and hit < prizes.size():
		var pb := prize_base(prizes[hit])
		target = pb.y - _prize_h(String(prizes[hit].kind)) * 0.55
	var cable := target - _rail_y - _rest_len() - 40.0 * u
	MgBoard.sfx("whirr")
	var t := create_tween()
	t.tween_property(self, "_cable", cable, dur(0.65)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	MgBoard.sfx("fwump")
	jostle(x, 1.0)
	burst(Vector2(x, target + 20.0 * u), Color(1, 0.92, 0.97, 0.9), 8, "puff", 120.0, 60.0, 14.0)
	t = create_tween()
	t.tween_property(self, "_open", 0.0, dur(0.22)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await t.finished
	MgBoard.sfx("clink")
	if grabbed and hit >= 0:
		_carry = "prize"
		_carry_prize = hit
		burst(Vector2(x, target + 30 * u), Color("fff3c0"), 16, "star", 240.0, 70.0, 9.0)
		shake(4.0)
	else:
		# the consolation: a puffball comes up in the prongs
		_carry = "fluff"
		_carry_col = PUFF_COLORS[(int(_claw * 1000.0) + int(state.get("fluff", 0))) % PUFF_COLORS.size()]
		if slipped and hit >= 0:
			_slip_prize = hit
			var st := create_tween()
			st.tween_property(self, "_slip", 46.0 * u, dur(0.3)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			st.tween_property(self, "_slip", 0.0, dur(0.35)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await wait(0.12)
	t = create_tween()
	t.tween_property(self, "_cable", 0.0, dur(0.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if slipped:
		await wait(0.3)
		MgBoard.sfx("error")
		jostle(x, 0.6)
		float_text(Vector2(x, _win.position.y + _win.size.y * 0.35), "SLIPPED!", Color("ffb0c0"), 44, 1.0)
	await t.finished
	_slip_prize = -1
	# carry it over the chute (left), release it into the prize tray
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
	var chute := Vector2(floor_x(-0.02), _cab.end.y - _cab.size.y * 0.14)
	if _carry == "prize":
		var kind := String(info.get("kind", "coins"))
		var pts := int(prizes[hit].get("points", 0)) if hit < prizes.size() else 0
		_won.append(kind)
		burst(chute, MgLogic.PRIZE_COLORS.get(kind, Color.WHITE), 26, "star", 360.0, 200.0, 10.0)
		ring(chute, Color("ffe07a"), 80.0, 0.5, 8.0)
		var big := kind in ["figure", "legendary"]
		MgBoard.sfx("win" if big else "coin")
		shake(8.0 if big else 4.0)
		kick.emit(1.0 if kind == "legendary" else 0.5, Color(1.0, 0.85, 0.4, 0.45))
		float_text(Vector2(_cab.get_center().x, _win.position.y + _win.size.y * 0.3),
			"%s!  +%d" % [String(MgLogic.PRIZE_NAMES.get(kind, kind)).to_upper(), pts], MgLogic.PRIZE_COLORS.get(kind, Color.WHITE).lightened(0.2), 48, 1.4)
	else:
		_won.append("fluff")
		burst(chute, _carry_col, 14, "puff", 120.0, 80.0, 12.0)
		MgBoard.sfx("fwump")
		var msg := ("SO CLOSE!  +%d" if slipped else "PUFFBALL  +%d") % ClawMachine.FLUFF_POINTS
		float_text(Vector2(_cab.get_center().x, _win.position.y + _win.size.y * 0.3), msg, _carry_col.lightened(0.2), 40, 1.2)
	_carry = ""
	_carry_drop = -1.0
	state = (ev.get("state", {}) as Dictionary).duplicate(true)
	# back to the left edge, the sweep restarts
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
	for k in 14:
		var hx := float(hash(k * 97) % 1000) / 1000.0
		var hy := float(hash(k * 53) % 1000) / 1000.0
		var tw := 0.5 + 0.5 * sin(_bulbs * 2.0 + k)
		_star4(w.position + Vector2(20 + hx * (w.size.x - 40), 20 + hy * w.size.y * 0.4), 3.0 + 3.0 * tw, Color(1, 1, 1, 0.25 * tw))
	# the fluff heap (back to front)
	for b: Dictionary in _balls:
		_puff(_ball_pos(b) + b.off, float(b.r) * w.size.x, b.col)
	# prizes nestled in it, deepest first; the fluff in front of each covers it by its depth
	var prizes := _prizes()
	var ck := claw_kind()
	var aim := MgLogic.claw_target(prizes, _claw, ck) if _mode == "swing" else -1
	var order: Array = range(prizes.size())
	order.sort_custom(func(a: int, b: int) -> bool: return float(prizes[a].get("depth", 0.0)) > float(prizes[b].get("depth", 0.0)))
	for i: int in order:
		var p: Dictionary = prizes[i]
		if bool(p.get("taken", false)) or (_carry == "prize" and i == _carry_prize):
			continue
		var kind := String(p.kind)
		var base := prize_base(p)
		if i == _slip_prize:
			base.y -= _slip
		var hot := i == aim
		var col: Color = MgLogic.PRIZE_COLORS.get(kind, Color.WHITE)
		if hot:
			glow(base + Vector2(0, -_prize_h(kind) * 0.5), 70 * u, Color(col.r, col.g, col.b, 0.75))
		_prize(kind, base, u * (1.06 if hot else 1.0), 1.0)
		_cover(i, p, base)
		var tag := Vector2(base.x, base.y - _prize_h(kind) - 12.0 * u)
		text_c(tag, str(int(p.points)), int(22 * u + 4), col.lightened(0.35), 6)
	# the aim: the hitbox on the fluff and its (narrower, by depth) grip zone
	if aim >= 0:
		var p: Dictionary = prizes[aim]
		var px := floor_x(float(p.pos))
		var span := _win.size.x - 56.0
		var y := surface_y(px) - 6.0
		var hw := (float(p.width) * 0.5 + float(ClawMachine.REACH.get(ck, 0.0))) * span
		var gw := ClawMachine.grip_half(p, ck) * span
		draw_line(Vector2(px - hw, y), Vector2(px + hw, y), Color(1, 1, 1, 0.35), 8.0 * u, true)
		draw_line(Vector2(px - gw, y), Vector2(px + gw, y), Color("7dffb0"), 8.0 * u, true)
	# rail, trolley, cable, claw
	draw_rect(Rect2(Vector2(w.position.x + 8, _rail_y - 8), Vector2(w.size.x - 16, 12)), Color("9aa3b8"))
	draw_rect(Rect2(Vector2(w.position.x + 8, _rail_y - 8), Vector2(w.size.x - 16, 4)), Color("d9e0ee"))
	var cx := floor_x(_claw)
	if _mode == "swing" and not locked:
		var yy := _rail_y + _rest_len() + 60 * u
		var y_end := surface_y(cx) - 10.0
		while yy < y_end:
			draw_line(Vector2(cx, yy), Vector2(cx, minf(yy + 10, y_end)), Color(1.0, 0.4, 0.5, 0.55), 3.0)
			yy += 20.0
	_draw_claw(Vector2(cx, _rail_y), u)
	# glass reflection
	var gl := PackedVector2Array([w.position + Vector2(w.size.x * 0.62, 0), w.position + Vector2(w.size.x * 0.72, 0),
		w.position + Vector2(w.size.x * 0.42, w.size.y), w.position + Vector2(w.size.x * 0.32, w.size.y)])
	draw_colored_polygon(gl, Color(1, 1, 1, 0.05))
	rrect(w, Color(0, 0, 0, 0), 18, 3, Color(1, 1, 1, 0.12))
	# front panel: chute + won tray + a big button
	var fp := _front_panel()
	rrect(fp, pink.darkened(0.2), 20, 3, UiPalette.OUTLINE)
	var chute := Rect2(fp.position + Vector2(14, 12), Vector2(fp.size.x * 0.26, fp.size.y - 24))
	rrect(chute, Color("22102e"), 14, 3, UiPalette.OUTLINE)
	text_c(chute.get_center() + Vector2(0, chute.size.y * 0.3), "PRIZE", int(16 * u + 4), Color(1, 1, 1, 0.5))
	var shelf := Rect2(Vector2(chute.end.x + 12, fp.position.y + 12), Vector2(fp.size.x * 0.24, fp.size.y - 24))
	rrect(shelf, Color(0.05, 0.03, 0.12, 0.7), 14)
	if _won.is_empty():
		text_c(shelf.get_center(), "WON: -", int(16 * u + 4), Color(1, 1, 1, 0.35))
	for k in _won.size():
		var kind := String(_won[k])
		var at := Vector2(shelf.position.x + 30 * u + k * 56 * u, shelf.end.y - 6)
		if kind == "fluff":
			_puff(at + Vector2(0, -18 * u), 16 * u, PUFF_COLORS[k % PUFF_COLORS.size()])
		else:
			_prize(kind, at, u * 0.55, 1.0)
	# claw selector: WIDE / NARROW, the chosen one lit
	var rs := selector_rects()
	for k in 2:
		var kind := String(ClawMachine.CLAWS[k])
		var r: Rect2 = rs[k]
		var on := kind == ck
		var kc: Color = CLAW_COLORS[kind]
		if on:
			glow(r.get_center(), r.size.x * 0.8, Color(kc.r, kc.g, kc.b, 0.55 + 0.15 * sin(_bulbs * 5.0)))
		rrect(r, Color("2a1238") if not on else kc.darkened(0.55), 14, 4 if on else 2, kc if on else Color(1, 1, 1, 0.2))
		_claw_icon(kind, r.get_center() + Vector2(0, -r.size.y * 0.16), minf(r.size.x, r.size.y) / 110.0, 1.0 if on else 0.5)
		text_c(Vector2(r.get_center().x, r.end.y - 16.0 * u), kind.to_upper(), int(15 * u + 4), kc if on else Color(1, 1, 1, 0.5), 5)
	# what the claw dropped, falling into the chute
	if _carry_drop >= 0.0 and _carry != "":
		var k := _carry_drop
		var from := Vector2(floor_x(-0.02), _rail_y + _rest_len() + 90 * u)
		var to := Vector2(from.x, chute.get_center().y)
		if _carry == "prize" and _carry_prize < prizes.size():
			_prize(String(prizes[_carry_prize].kind), from.lerp(to, k), u * (1.0 - 0.4 * k), 1.0 - k * 0.5)
		else:
			_puff(from.lerp(to, k) - Vector2(0, 20 * u), 22 * u * (1.0 - 0.3 * k), _carry_col)


## Fluff in front of a prize: more (and higher) the deeper it is buried.
func _cover(i: int, p: Dictionary, base: Vector2) -> void:
	var d := float(p.get("depth", 0.0))
	var ph := _prize_h(String(p.kind))
	var n := 2 + int(d * 4.0)
	var w := ph * 0.9
	for k in n:
		var hh := hash(i * 131 + k * 17)
		var fx := (float(hh % 1000) / 1000.0 - 0.5) * w
		var fy := -float((hh / 1000) % 1000) / 1000.0 * d * ph * 0.55
		var col: Color = PUFF_COLORS[(hh / 7) % PUFF_COLORS.size()]
		_puff(base + Vector2(fx, fy + 6.0 * _unit()), (15.0 + float(hh % 7)) * _unit(), col)


## One soft puffball: a shaded disc with a fuzzy rim and a highlight.
func _puff(c: Vector2, r: float, col: Color) -> void:
	draw_circle(c + Vector2(0, r * 0.12), r * 1.02, col.darkened(0.45))
	draw_circle(c, r, col.darkened(0.12))
	draw_circle(c - Vector2(r * 0.12, r * 0.14), r * 0.78, col)
	draw_circle(c - Vector2(r * 0.35, r * 0.38), r * 0.26, Color(1, 1, 1, 0.55))


## A small claw picture for the selector (wide: three big prongs; narrow: slim tweezers).
func _claw_icon(kind: String, c: Vector2, s: float, a: float) -> void:
	var col: Color = CLAW_COLORS[kind]
	col.a = a
	var o := Color(UiPalette.OUTLINE, a)
	draw_line(c + Vector2(0, -34) * s, c, o, 7 * s, true)
	draw_circle(c, 10 * s, o)
	draw_circle(c, 8 * s, col)
	if kind == "wide":
		for sg in [-1.0, 0.0, 1.0]:
			var knee := c + Vector2(sg * 26, 14) * s
			var tip := knee + Vector2(-sg * 10, 20) * s
			draw_polyline(PackedVector2Array([c, knee, tip]), o, 8 * s, true)
			draw_polyline(PackedVector2Array([c, knee, tip]), col, 4 * s, true)
	else:
		for sg in [-1.0, 1.0]:
			var tip := c + Vector2(sg * 6, 44) * s
			draw_polyline(PackedVector2Array([c, c + Vector2(sg * 9, 16) * s, tip]), o, 6 * s, true)
			draw_polyline(PackedVector2Array([c, c + Vector2(sg * 9, 16) * s, tip]), col, 3 * s, true)


func _draw_claw(top: Vector2, u: float) -> void:
	# trolley
	rrect(Rect2(top + Vector2(-26, -14) * u, Vector2(52, 24) * u), Color("5e6a86"), 6 * u)
	rrect(Rect2(top + Vector2(-26, -14) * u, Vector2(52, 8) * u), Color("aeb8cf"), 6 * u)
	var cl := _rest_len() + _cable
	var head := top + Vector2(0, cl)
	draw_line(top, head, UiPalette.OUTLINE, 6.0 * u, true)
	draw_line(top, head, Color("c8cfdd"), 3.0 * u, true)
	var kind := claw_kind()
	var kc: Color = CLAW_COLORS[kind]
	var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - (time - _swap_t) / 0.3)
	u *= pop
	draw_circle(head, 16 * u, UiPalette.OUTLINE)
	draw_circle(head, 13 * u, kc)
	draw_circle(head + Vector2(-4, -4) * u, 5 * u, Color(1, 1, 1, 0.6))
	# the other claw, parked at the right end of the rail
	var park := Vector2(_win.end.x - 34.0 * u / pop, _rail_y + 14.0)
	_claw_icon("narrow" if kind == "wide" else "wide", park + Vector2(0, 30 * u / pop), 0.55 * u / pop, 0.7)
	# what hangs between the prongs
	var prizes := _prizes()
	if _carry_drop < 0.0:
		if _carry == "prize" and _carry_prize < prizes.size():
			var pk := String(prizes[_carry_prize].kind)
			_prize(pk, head + Vector2(0, 30 * u + _prize_h(pk) * 0.75), u, 1.0)
		elif _carry == "fluff":
			_puff(head + Vector2(0, 50 * u), 22 * u, _carry_col)
	var spread := lerpf(0.15, 0.75, _open)
	var metal := kc.lerp(Color("d6dcea"), 0.45)
	if kind == "wide":
		# three big prongs, a wide reach
		for s in [-1.0, 1.0]:
			var a := head + Vector2(s * 10 * u, 8 * u)
			var knee := a + Vector2(s * 38 * u * spread + s * 10 * u, 26 * u)
			var tip := knee + Vector2(-s * 20 * u * (1.2 - spread), 24 * u)
			for pass_i in 2:
				var col := UiPalette.OUTLINE if pass_i == 0 else metal
				var wd := (11.0 if pass_i == 0 else 6.0) * u
				draw_line(a, knee, col, wd, true)
				draw_line(knee, tip, col, wd, true)
			draw_circle(knee, 5 * u, kc.darkened(0.3))
		draw_line(head, head + Vector2(0, 36 * u), UiPalette.OUTLINE, 10 * u, true)
		draw_line(head, head + Vector2(0, 36 * u), metal, 5 * u, true)
	else:
		# slim gold tweezers: reach little, grip hard
		for s in [-1.0, 1.0]:
			var a := head + Vector2(s * 5 * u, 8 * u)
			var knee := a + Vector2(s * 14 * u * spread + s * 3 * u, 22 * u)
			var tip := knee + Vector2(-s * 9 * u * (1.2 - spread), 30 * u)
			for pass_i in 2:
				var col := UiPalette.OUTLINE if pass_i == 0 else metal
				var wd := (8.0 if pass_i == 0 else 4.0) * u
				draw_line(a, knee, col, wd, true)
				draw_line(knee, tip, col, wd, true)
			draw_circle(tip, 3 * u, kc)


## A prize standing on point `b` (bottom centre): the KayKit model icon, or a vector stand-in.
func _prize(kind: String, b: Vector2, s: float, a: float) -> void:
	var col: Color = MgLogic.PRIZE_COLORS.get(kind, Color.WHITE)
	var spec: Array = PRIZE_ICONS.get(kind, ["", 0.0, 80.0])
	var px := float(spec[2]) * s
	var tex: Texture2D = ModelIcons.get_icon(String(spec[0]), float(spec[1])) if String(spec[0]) != "" else null
	if kind == "legendary":
		glow(b + Vector2(0, -px * 0.45), px * 0.9, Color(1.0, 0.85, 0.4, 0.7 * a))
	if tex:
		draw_texture_rect(tex, Rect2(b - Vector2(px * 0.5, px * 0.96), Vector2(px, px)), false, Color(1, 1, 1, a))
	else:
		var r := px * 0.36
		draw_circle(b + Vector2(0, -r), r + 3.0, Color(UiPalette.OUTLINE, a))
		draw_circle(b + Vector2(0, -r), r, Color(col, a))
		draw_circle(b + Vector2(-r * 0.3, -r * 1.35), r * 0.3, Color(1, 1, 1, 0.5 * a))
	if kind == "legendary":
		_star4(b + Vector2(px * 0.3, -px * 0.8), (8.0 + 3.0 * sin(_bulbs * 6.0)) * s, Color(1, 1, 1, a))

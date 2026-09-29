class_name MemoryBoard
extends MgBoard
## Memory Match: a 4x4 spread of premium cards (ornate backs in the game colour), two of each
## of 8 faces: die faces 1..6, the Star rune and the Skull rune. Tap a card to flip it ([idx]);
## the second flip of a turn either locks a pair face up (glow, burst, a chime that climbs
## with the streak, then a golden border) or misses: both cards shake, a heart pip cracks, and
## after a short look (input locked) they flip back face down.
## Only the public state is drawn: found pairs and the turn's open card. A flipped-back card's
## face is known here only from that flip's update info and is forgotten when it turns over
## (remembering it is the player's job).

const N := 16
const COLS := 4
const GOLD := Color("ffd24a")
const STAR_COL := Color("ffd84a")
const SKULL_COL := Color("8dffc4")
const HEART := Color("ff5c7c")
const CREAM := Color("fff6e3")
const RUNE_BG := Color("2a1a4e")
const STAR_ICON := ModelIcons.K + "platformer/yellow/star_yellow.gltf"
const SKULL_ICON := ModelIcons.K + "halloween/skull.gltf"
## Mismatch: how long both faces stay up (game-speed scaled) before they flip back.
const HOLD := 0.8

var _grid := Rect2()
var _head := Rect2()
var _cw := 80.0
var _ch := 104.0
var _gap := 10.0

## Face known for the card while it is face up / turning (0 = unknown).
var _face: Array[int] = []
## Flip progress: 0 = back up, 1 = face up.
var _flip: Array[float] = []
var _matched: Array[bool] = []
var _match_t: Array[float] = []
var _shake_t: Array[float] = []
var _tap_t: Array[float] = []
var _hk: Array[float] = []
var _hover := -1
## Hearts still intact on screen (cracks before the state catches up).
var _hearts := 6
var _crack_t: Array[float] = []
## Something is animating that input must wait for (flip / mismatch hold / deal / finale).
var _busy := false
var _dealt := false
var _deal_t0 := -1.0
var _finale_t := -10.0
var _finale := ""
var _settle_at := 0.0
var _gems: Array = []
var _twinkle := 0.0
var _so := Vector2.ZERO
var _queued := -1


func _init() -> void:
	super._init()
	for i in N:
		_face.append(0)
		_flip.append(0.0)
		_matched.append(false)
		_match_t.append(-10.0)
		_shake_t.append(-10.0)
		_tap_t.append(-10.0)
		_hk.append(0.0)
	for i in 12:
		_crack_t.append(-10.0)


func set_state(st: Dictionary, instant := true) -> void:
	super.set_state(st, instant)
	var cards: Array = state.get("cards", [])
	var open := int(state.get("open", -1))
	for i in N:
		var v := int(cards[i]) if i < cards.size() else 0
		_matched[i] = v > 0
		if v > 0:
			_face[i] = v
			_flip[i] = 1.0
		elif i == open:
			_face[i] = int(state.get("open_symbol", 0))
			_flip[i] = 1.0
		else:
			_face[i] = 0
			_flip[i] = 0.0
	_hearts = int(state.get("actions_left", 0))
	if bool(state.get("done", false)) and _pairs() >= 8:
		_finale = "win"
		_finale_t = time - 10.0
	elif _hearts <= 0 and not state.is_empty():
		_finale = "lose"
		_finale_t = time - 10.0
	if not _dealt and not state.is_empty():
		_dealt = true
		_deal_t0 = time + 0.3
		_busy = true
		_deal_sounds()
	unlock()


func _deal_sounds() -> void:
	await wait(0.3)
	MgBoard.sfx("card_shuffle")
	for k in 8:
		await wait(0.09)
		MgBoard.sfx("card_slide", 0.12, -5.0)


func _pairs() -> int:
	return int(state.get("pairs", 0))


func is_settled() -> bool:
	return not _busy and time >= _settle_at


func status_text() -> String:
	var s := int(state.get("streak", 0))
	if s >= 2:
		return "Streak x%d!" % s
	if _pairs() > 0:
		return "%d / 8 pairs" % _pairs()
	return ""


# --- layout ----------------------------------------------------------------------------

func _layout() -> void:
	var hh := clampf(size.y * 0.1, 40.0, 68.0)
	_head = Rect2(0, 0, size.x, hh)
	var av := Rect2(4.0, hh + 4.0, size.x - 8.0, size.y - hh - 8.0)
	# two passes: the felt margin around the spread scales with the card size
	for pass_i in 2:
		var m := _gap * 1.2 + 4.0 if pass_i == 1 else 0.0
		var inner := av.grow(-m)
		var a := clampf(inner.size.x / maxf(inner.size.y, 1.0), 0.68, 0.82)
		_cw = maxf(8.0, minf(inner.size.x / 4.36, inner.size.y / (4.0 / a + 0.36)))
		_ch = _cw / a
		_gap = _cw * 0.12
		var gs := Vector2(_cw * 4.0 + _gap * 3.0, _ch * 4.0 + _gap * 3.0)
		_grid = Rect2(inner.position + (inner.size - gs) * 0.5, gs)


func card_center(i: int) -> Vector2:
	var x := i % COLS
	var y := i / COLS
	return _grid.position + Vector2(x * (_cw + _gap) + _cw * 0.5, y * (_ch + _gap) + _ch * 0.5)


func card_rect(i: int) -> Rect2:
	return Rect2(card_center(i) - Vector2(_cw, _ch) * 0.5, Vector2(_cw, _ch))


func card_at(p: Vector2) -> int:
	for i in N:
		# a little slack between cards so a thumb between two still hits one
		if card_rect(i).grow(_gap * 0.5).has_point(p):
			return i
	return -1


func _deal_k(i: int) -> float:
	if _deal_t0 < 0.0:
		return 1.0
	return clampf((time - _deal_t0 - dur(0.05) * i) / dur(0.34), 0.0, 1.0)


func _deal_done() -> bool:
	return _deal_t0 < 0.0 or _deal_k(N - 1) >= 1.0


func _can_flip(i: int) -> bool:
	if i < 0 or locked or _busy or not _deal_done():
		return false
	if bool(state.get("done", false)) or int(state.get("actions_left", 0)) <= 0:
		return false
	return not _matched[i] and i != int(state.get("open", -1))


# --- input -----------------------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	_layout()
	var mm := e as InputEventMouseMotion
	if mm:
		_hover = card_at(mm.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _can_flip(_hover) else Control.CURSOR_ARROW
		return
	var mb := e as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var i := card_at(mb.position)
	if i < 0:
		return
	_tap_t[i] = time
	if _can_flip(i):
		send([i])
	elif not _deal_done() and not _matched[i] and not locked:
		# tapped while the cards are still being dealt: flip it once they are down
		_queued = i
	elif _matched[i] or i == int(state.get("open", -1)):
		# already up: a little wiggle, no action
		_shake_t[i] = time - 0.1
		MgBoard.sfx("click", 0.1, -8.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = -1


## Taps the card like a player. Synchronous on purpose: a tap during the deal is buffered by
## the board and plays as soon as the cards are down (awaiting in here trips a GDScript
## stack bug in the harness's match branch).
func scripted_input(args: Array, drv: Node) -> bool:
	if args.is_empty() or not is_inside_tree():
		return false
	_layout()
	var p := get_global_rect().position + card_center(int(args[0]))
	drv.call("move", p, false)
	drv.call("click", p)
	return true


# --- events ----------------------------------------------------------------------------

func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	_layout()
	var info: Dictionary = ev.get("info", {})
	var nst: Dictionary = (ev.get("state", {}) as Dictionary).duplicate(true)
	var i := int(info.get("idx", -1))
	if i < 0 or i >= N:
		state = nst
		unlock()
		return
	_busy = true
	_face[i] = int(info.get("symbol", 0))
	MgBoard.sfx("card_flip", 0.08)
	await _turn([i], 1.0, 0.26)
	if bool(info.get("first", true)):
		state = nst
		_busy = false
		unlock()
		return
	var o := int(info.get("other", -1))
	if o >= 0 and o < N:
		_face[o] = int(info.get("other_symbol", _face[o]))
		_flip[o] = 1.0
	var mid := (card_center(i) + card_center(o)) * 0.5 if o >= 0 else card_center(i)
	if bool(info.get("match", false)):
		await wait(0.06)
		var streak := int(nst.get("streak", 1))
		for c in [i, o]:
			if c < 0:
				continue
			_matched[c] = true
			_match_t[c] = time
			var cc := card_center(c)
			ring(cc, GOLD, _cw * 0.75, 0.5, 6.0)
			burst(cc, GOLD, 12, "star", 240.0, 40.0, 9.0)
			burst(cc, _sym_col(_face[c]), 8, "spark", 200.0, 20.0, 7.0)
		_chime(streak)
		var pts := int(info.get("points", 2))
		if bool(nst.get("done", false)):
			pts -= int(nst.get("actions_left", 0))
		float_text(mid + Vector2(0, -_ch * 0.1), "+%d" % pts, GOLD, int(_cw * 0.42), 1.0)
		if streak >= 2:
			float_text(mid + Vector2(0, _ch * 0.35), "STREAK x%d" % streak, Color("ffb3f0"), int(_cw * 0.3), 1.2)
		kick.emit(0.25 + 0.08 * mini(streak, 4), Color(1.0, 0.85, 0.4, 0.3))
		state = nst
		await wait(0.4)
		if bool(nst.get("done", false)):
			await _win_finale()
	else:
		await wait(0.12)
		MgBoard.sfx("error", 0.05, -7.0)
		MgBoard.sfx("card_slide", 0.05, -8.0)
		for c in [i, o]:
			if c >= 0:
				_shake_t[c] = time
		float_text(mid, "MISS", Color("ffb0c0"), int(_cw * 0.36), 0.9)
		_crack_heart()
		kick.emit(0.2, Color(1.0, 0.3, 0.4, 0.25))
		await wait(HOLD)
		MgBoard.sfx("card_flip", 0.08)
		var both: Array = [i]
		if o >= 0:
			both.append(o)
		await _turn(both, 0.0, 0.24)
		for c in both:
			_face[c] = 0
		state = nst
		if int(nst.get("actions_left", 0)) <= 0:
			await _lose_finale()
	_busy = false
	unlock()


## Animates the flip of cards idxs to `to` (0 back, 1 face).
func _turn(idxs: Array, to: float, d: float) -> void:
	if not is_inside_tree():
		for c in idxs:
			_flip[c] = to
		return
	var t := create_tween().set_parallel(true)
	for c in idxs:
		t.tween_method(_set_flip.bind(int(c)), _flip[c], to, dur(d)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _set_flip(v: float, i: int) -> void:
	_flip[i] = v


func _crack_heart() -> void:
	_hearts = maxi(0, _hearts - 1)
	var k := _hearts
	if k < _crack_t.size():
		_crack_t[k] = time
	var p := _heart_pos(k)
	burst(p, HEART, 8, "chunk", 180.0, 120.0, 6.0)
	burst(p, Color.WHITE, 5, "spark", 140.0, 20.0, 5.0)
	MgBoard.sfx("glass", 0.08, -4.0)


## A chime that climbs with the streak (Audio has no pitch argument: the pitch is set on the
## player that just started, when the autoload exposes its pool).
func _chime(streak: int) -> void:
	MgBoard.sfx("bell", 0.0, -2.0)
	var loop := Engine.get_main_loop() as SceneTree
	var a: Node = loop.root.get_node_or_null("Audio") if loop else null
	if a != null:
		var pool: Variant = a.get("_pool")
		var nx: Variant = a.get("_next")
		if pool is Array and nx is int and (pool as Array).size() > 0:
			var pl: Variant = pool[(int(nx) - 1 + pool.size()) % pool.size()]
			if pl is AudioStreamPlayer:
				(pl as AudioStreamPlayer).pitch_scale = minf(1.0 + 0.12 * (streak - 1), 1.7)
	if streak >= 3:
		MgBoard.sfx("coin", 0.05, -6.0)


func _win_finale() -> void:
	_finale = "win"
	_finale_t = time
	MgBoard.sfx("fanfare")
	MgBoard.sfx("win", 0.0, -3.0)
	var c := _grid.get_center()
	burst(c, GOLD, 40, "flake", 520.0, 260.0, 10.0)
	burst(c, Color.WHITE, 22, "star", 400.0, 100.0, 12.0)
	for g in 10:
		_gems.append({"p": c + Vector2(randf_range(-60, 60), randf_range(-30, 30)),
			"v": Vector2(randf_range(-340, 340), randf_range(-660, -320)), "t": 0.0, "rot": randf() * TAU})
	kick.emit(1.0, Color(1.0, 0.85, 0.35, 0.5))
	shake(8.0)
	await wait(0.7)
	# each heart left pays a bonus point
	for k in _hearts:
		var p := _heart_pos(k)
		float_text(p + Vector2(0, 10), "+1", GOLD, int(_head.size.y * 0.5), 0.9)
		burst(p, GOLD, 10, "star", 180.0, 40.0, 7.0)
		ring(p, GOLD, _head.size.y * 0.5, 0.35, 4.0)
		MgBoard.sfx("coin", 0.06, -4.0)
		await wait(0.14)
	_settle_at = time + dur(0.9)


func _lose_finale() -> void:
	_finale = "lose"
	_finale_t = time
	MgBoard.sfx("lose", 0.0, -4.0)
	kick.emit(0.4, Color(0.5, 0.2, 0.3, 0.35))
	_settle_at = time + dur(1.0)


func _tick(dt: float) -> void:
	for i in N:
		var target := 1.0 if i == _hover and _can_flip(i) else 0.0
		_hk[i] = lerpf(_hk[i], target, minf(1.0, dt * 14.0))
	if _deal_t0 >= 0.0 and _deal_done() and _busy and _flip_idle():
		_deal_t0 = -1.0
		_busy = false
	if _queued >= 0 and not _busy and _deal_done():
		var q := _queued
		_queued = -1
		if _can_flip(q):
			send([q])
	for g: Dictionary in _gems:
		g.t += dt
		g.v.y += 1100.0 * dt
		g.p += g.v * dt
		g.rot += dt * 4.0
	_gems = _gems.filter(func(g: Dictionary) -> bool: return float(g.t) < 1.7)
	# idle twinkles on the found pairs
	_twinkle -= dt
	if _twinkle <= 0.0:
		_twinkle = randf_range(0.35, 0.7)
		var found: Array = []
		for i in N:
			if _matched[i] and time - _match_t[i] > 0.6:
				found.append(i)
		if not found.is_empty():
			var r := card_rect(int(found[randi() % found.size()]))
			burst(r.position + r.size * Vector2(randf_range(0.15, 0.85), randf_range(0.1, 0.9)), Color("fff3c0"), 1, "star", 30.0, 10.0,
				_cw * 0.09)


## True when no card is mid-turn (the deal flag only clears then).
func _flip_idle() -> bool:
	for i in N:
		if _flip[i] > 0.0 and _flip[i] < 1.0:
			return false
	return true


# --- drawing ---------------------------------------------------------------------------

func _draw_board() -> void:
	_layout()
	_so = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake if _shake > 0.0 else Vector2.ZERO
	_draw_felt()
	_draw_hearts()
	# cards: settled ones first, the flying / deck ones on top
	var order: Array = []
	var flying: Array = []
	var deck: Array = []
	for i in N:
		var k := _deal_k(i)
		if k >= 1.0:
			order.append(i)
		elif k > 0.0:
			flying.append(i)
		else:
			deck.append(i)
	deck.reverse()
	# lifted cards (turning, open, just matched) over their neighbours
	order.sort_custom(func(x: int, y: int) -> bool: return _lift(x) < _lift(y))
	for i in order + deck + flying:
		_draw_card(i)
	for g: Dictionary in _gems:
		var a := clampf(2.0 - float(g.t) * 1.3, 0.0, 1.0)
		var gem := ModelIcons.get_icon(ModelIcons.GEM, 30.0)
		draw_set_transform(g.p + _so, g.rot, Vector2.ONE)
		if gem:
			draw_texture_rect(gem, Rect2(-30, -30, 60, 60), false, Color(1, 1, 1, a))
		else:
			_star4(Vector2.ZERO, 16.0, Color(0.5, 0.9, 1.0, a))
	draw_set_transform(_so)
	_draw_banner()


## A soft felt mat under the spread (in the game colour).
func _draw_felt() -> void:
	var col: Color = MgLogic.GAME_COLORS.get("memory_match", Color("b08cff"))
	var r := _grid.grow(_gap * 1.2)
	rrect(Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.3), _cw * 0.26)
	rrect(r, col.darkened(0.72), _cw * 0.24, 3, col.darkened(0.35))
	rrect(r.grow(-_gap * 0.45), Color(0, 0, 0, 0), _cw * 0.18, 2, Color(col.r, col.g, col.b, 0.22))


func _lift(i: int) -> float:
	var l := sin(PI * _flip[i])
	if i == int(state.get("open", -1)) and _flip[i] >= 1.0:
		l = 0.45
	var m := time - _match_t[i]
	if m < dur(0.5):
		l = maxf(l, sin(clampf(m / dur(0.5), 0.0, 1.0) * PI))
	return maxf(l, _hk[i] * 0.3)


func _draw_card(i: int) -> void:
	var c := card_center(i)
	var rot := 0.0
	var sc := 1.0
	var k := _deal_k(i)
	if k < 1.0:
		# dealt from a deck at the middle of the spread
		var from := _grid.get_center() + Vector2(0, -float(N - i) * 0.9)
		var e := 1.0 - pow(1.0 - k, 3.0)
		c = from.lerp(c, e)
		rot = lerpf(0.35 * (1.0 if i % 2 == 0 else -1.0) + (i - 7.5) * 0.03, 0.0, e) if k > 0.0 else (i % 3 - 1) * 0.03
		sc = lerpf(0.9, 1.0, e) * (1.0 + 0.12 * sin(k * PI))
	var f := _flip[i]
	var sx := absf(cos(PI * f))
	var lift := _lift(i)
	# match pop / tap squish / mismatch shake / the finale wave
	var m := time - _match_t[i]
	if m < dur(0.5):
		sc *= 1.0 + 0.14 * sin(clampf(m / dur(0.5), 0.0, 1.0) * PI)
	var tp := time - _tap_t[i]
	if tp < 0.16:
		sc *= 1.0 - 0.06 * sin(tp / 0.16 * PI)
	var sh := time - _shake_t[i]
	if sh < dur(0.45):
		var d := 1.0 - sh / dur(0.45)
		c.x += sin(sh * 55.0) * _cw * 0.08 * d
		rot += sin(sh * 40.0) * 0.05 * d
	if _finale == "win":
		var w := (time - _finale_t) / dur(1.0) * 6.0 - float(i % COLS + i / COLS) * 0.8
		if w > 0.0 and w < PI:
			c.y -= sin(w) * _ch * 0.14
			sc *= 1.0 + 0.06 * sin(w)
	sc *= 1.0 + 0.1 * lift + 0.04 * _hk[i]
	var up := Vector2(0, -_ch * 0.06 * lift)
	# shadow (stays on the table, grows with the lift)
	var sw := maxf(sx, 0.06)
	draw_set_transform(c + _so + Vector2(_cw * 0.04, _ch * (0.05 + 0.05 * lift)), rot, Vector2(sc * sw * (1.0 + 0.05 * lift), sc))
	rrect(Rect2(-_cw * 0.5, -_ch * 0.5, _cw, _ch), Color(0, 0, 0, 0.32 - 0.1 * lift), _cw * 0.14)
	draw_set_transform(c + _so + up, rot, Vector2(sc * maxf(sx, 0.02), sc))
	var sheen := 1.0 - sx if f > 0.0 and f < 1.0 else 0.0
	if f >= 0.5:
		_draw_face(i, _face[i], sheen)
	else:
		_draw_back(i, sheen)
	# the card's edge while it is side-on
	if sx < 0.2:
		draw_set_transform(c + _so + up, rot, Vector2(sc, sc))
		var ew := maxf(_cw * sx, _cw * 0.035)
		rrect(Rect2(-ew * 0.5 - 1.5, -_ch * 0.5, ew + 3.0, _ch), UiPalette.OUTLINE, 3)
		rrect(Rect2(-ew * 0.5, -_ch * 0.5 + 2.0, ew, _ch - 4.0), Color("e8dcc0") if f >= 0.5 else Color("6d52b8"), 2)
	draw_set_transform(_so)


func _draw_back(i: int, sheen: float) -> void:
	var w := _cw
	var h := _ch
	var col: Color = MgLogic.GAME_COLORS.get("memory_match", Color("b08cff"))
	var r := w * 0.14
	var rect := Rect2(-w * 0.5, -h * 0.5, w, h)
	var thick := h * 0.045
	var top := Rect2(rect.position, rect.size - Vector2(0, thick))
	var hover := _hk[i]
	rrect(rect.grow(3.0), UiPalette.OUTLINE, r + 3.0)
	rrect(rect, col.darkened(0.62), r)
	rrect(top, col.darkened(0.3).lerp(col, hover * 0.25), r)
	var inner := top.grow(-w * 0.075)
	rrect(inner, col.darkened(0.08).lerp(col.lightened(0.15), hover * 0.4), r * 0.6)
	# diamond lattice
	var dcol := Color(col.darkened(0.35).r, col.darkened(0.35).g, col.darkened(0.35).b, 0.55)
	var ds := w * 0.055
	for gy in 5:
		for gx in 4:
			var p := inner.position + Vector2((gx + 0.5 + (0.5 if gy % 2 == 1 else 0.0)) * inner.size.x / 4.5, (gy + 0.5) * inner.size.y / 5.0)
			if Rect2(Vector2.ZERO - Vector2(w, w) * 0.27, Vector2(w, w) * 0.54).has_point(p):
				continue
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -ds), p + Vector2(ds * 0.7, 0), p + Vector2(0, ds),
				p + Vector2(-ds * 0.7, 0)]), dcol)
	rrect(inner, Color(0, 0, 0, 0), r * 0.6, 2, Color(1.0, 0.86, 0.5, 0.85))
	rrect(inner.grow(-w * 0.045), Color(0, 0, 0, 0), r * 0.4, 1, Color(1.0, 0.86, 0.5, 0.35))
	for cx in [-1.0, 1.0]:
		for cy in [-1.0, 1.0]:
			var p := inner.get_center() + Vector2(cx * (inner.size.x * 0.5 - w * 0.1), cy * (inner.size.y * 0.5 - w * 0.1))
			_star4(p, w * 0.075, GOLD)
	# medallion: a gold ring with a die-pip rosette
	var mc := top.get_center()
	var mr := w * 0.24
	draw_circle(mc, mr + 3.0, UiPalette.OUTLINE)
	draw_circle(mc, mr, GOLD.darkened(0.15))
	draw_circle(mc, mr * 0.84, col.darkened(0.55))
	draw_arc(mc, mr * 0.84, PI * 1.1, PI * 1.6, 12, Color(1, 1, 1, 0.25), 2.0, true)
	var tw := 1.0 + 0.08 * sin(time * 2.2 + i * 0.7)
	_star4(mc, mr * 0.62 * tw, GOLD)
	_star4(mc, mr * 0.3, Color("fff6d0"))
	for q in 4:
		var a := PI * 0.25 + q * PI * 0.5
		draw_circle(mc + Vector2(cos(a), sin(a)) * mr * 0.55, mr * 0.09, Color("fff0b0"))
	# gloss + a sweeping sheen
	rrect(Rect2(top.position + Vector2(w * 0.08, h * 0.03), Vector2(w * 0.84, h * 0.12)), Color(1, 1, 1, 0.12), r * 0.6)
	var sk := fposmod(time * 0.32 + i * 0.137, 2.4) - 0.3
	if sk > -0.2 and sk < 1.2:
		var x0 := rect.position.x + sk * w * 1.4
		var band := PackedVector2Array([Vector2(x0, rect.position.y), Vector2(x0 + w * 0.2, rect.position.y),
			Vector2(x0 - w * 0.25, rect.end.y), Vector2(x0 - w * 0.45, rect.end.y)])
		clipped(band, rect_poly(top.grow(-2.0)), Color(1, 1, 1, 0.16))
	if sheen > 0.0:
		rrect(rect, Color(1, 1, 1, 0.45 * sheen), r)
	if _finale == "lose":
		rrect(rect.grow(2.0), Color(0.05, 0.03, 0.1, 0.45 * clampf((time - _finale_t) / dur(0.5), 0.0, 1.0)), r + 2.0)


func _draw_face(i: int, sym: int, sheen: float) -> void:
	var w := _cw
	var h := _ch
	var r := w * 0.14
	var rect := Rect2(-w * 0.5, -h * 0.5, w, h)
	var thick := h * 0.045
	var top := Rect2(rect.position, rect.size - Vector2(0, thick))
	var rune := sym >= 7
	var matched := _matched[i]
	var m := time - _match_t[i]
	if not matched and i == int(state.get("open", -1)) and _flip[i] >= 1.0:
		var oc: Color = MgLogic.GAME_COLORS.get("memory_match", Color("b08cff")).lightened(0.3)
		oc.a = 0.7 + 0.2 * sin(time * 5.0)
		glow(Vector2.ZERO, w * 0.85, oc)
	if matched:
		var gk := clampf(1.0 - m / dur(0.9), 0.0, 1.0)
		var gc := GOLD
		gc.a = 0.35 + 0.6 * gk + 0.08 * sin(time * 3.0 + i)
		glow(Vector2.ZERO, w * (0.8 + 0.25 * gk), gc)
	rrect(rect.grow(3.0), UiPalette.OUTLINE, r + 3.0)
	rrect(rect, (RUNE_BG if rune else CREAM).darkened(0.35), r)
	rrect(top, RUNE_BG if rune else CREAM, r)
	var inner := top.grow(-w * 0.07)
	var col: Color = MgLogic.GAME_COLORS.get("memory_match", Color("b08cff"))
	rrect(inner, Color(0, 0, 0, 0), r * 0.6, 2, Color(1.0, 0.82, 0.4, 0.8) if rune else Color(col.r, col.g, col.b, 0.55))
	var cc := top.get_center()
	if sym >= 1 and sym <= 6:
		var s := w * 0.6
		die_face(Rect2(cc - Vector2(s, s) * 0.5, Vector2(s, s)), sym)
		var ic := col.darkened(0.35)
		text_c(inner.position + Vector2(w * 0.1, w * 0.1), str(sym), int(w * 0.17), ic)
		text_c(inner.end - Vector2(w * 0.1, w * 0.1), str(sym), int(w * 0.17), ic)
	elif rune:
		var rc := STAR_COL if sym == 7 else SKULL_COL
		glow(cc, w * 0.5, Color(rc.r, rc.g, rc.b, 0.8 + 0.15 * sin(time * 3.0)))
		# the rune circle: a slowly turning ring of arcs and tick glyphs
		var rr := w * 0.36
		var spin := time * 0.5 * (1.0 if sym == 7 else -1.0)
		for q in 6:
			var a0 := spin + q * TAU / 6.0
			draw_arc(cc, rr, a0 + 0.12, a0 + TAU / 6.0 - 0.12, 8, Color(rc.r, rc.g, rc.b, 0.8), 2.0, true)
			var tp := cc + Vector2(cos(a0), sin(a0)) * rr
			draw_line(tp - Vector2(cos(a0), sin(a0)) * w * 0.035, tp + Vector2(cos(a0), sin(a0)) * w * 0.035, rc, 2.0, true)
		draw_arc(cc, rr * 0.8, 0.0, TAU, 32, Color(rc.r, rc.g, rc.b, 0.3), 1.5, true)
		var tex := ModelIcons.get_icon(STAR_ICON if sym == 7 else SKULL_ICON, 20.0 if sym == 7 else 25.0, -12.0)
		var bob := sin(time * 2.4 + i) * w * 0.02
		var s := w * (0.6 if sym == 7 else 0.54)
		if tex:
			draw_texture_rect(tex, Rect2(cc - Vector2(s, s) * 0.5 + Vector2(0, bob), Vector2(s, s)), false)
		elif sym == 7:
			_star5(cc + Vector2(0, bob), s * 0.45, STAR_COL)
		else:
			_skull(cc + Vector2(0, bob), s * 0.4)
		for q in 2:
			var cp := inner.position + Vector2(w * 0.1, w * 0.1) if q == 0 else inner.end - Vector2(w * 0.1, w * 0.1)
			_star4(cp, w * 0.06, rc)
	if matched:
		var gk := clampf(m / dur(0.35), 0.0, 1.0)
		rrect(rect.grow(1.0), Color(0, 0, 0, 0), r + 1.0, int(maxf(3.0, w * 0.045)), Color(GOLD.r, GOLD.g, GOLD.b, gk))
		if m < dur(0.3):
			rrect(rect, Color(1, 1, 1, 0.6 * (1.0 - m / dur(0.3))), r)
	elif i == int(state.get("open", -1)) and _flip[i] >= 1.0:
		# the turn's first card: a pulsing rim in the game colour ("find my twin")
		var pk := 0.6 + 0.4 * sin(time * 5.0)
		var rc := col.lightened(0.45)
		rrect(rect.grow(3.0), Color(0, 0, 0, 0), r + 3.0, int(maxf(3.0, w * 0.05)), Color(rc.r, rc.g, rc.b, pk))
	var sh := time - _shake_t[i]
	if not matched and sh < dur(0.6) and sh >= 0.0:
		rrect(rect, Color(1.0, 0.25, 0.35, 0.3 * (1.0 - sh / dur(0.6))), r)
	if sheen > 0.0:
		rrect(rect, Color(1, 1, 1, 0.45 * sheen), r)


func _star5(at: Vector2, rad: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var big := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + k * PI / 5.0
		var rr := rad if k % 2 == 0 else rad * 0.45
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
		big.append(at + Vector2(cos(a), sin(a)) * (rr + 3.0))
	draw_colored_polygon(big, UiPalette.OUTLINE)
	draw_colored_polygon(pts, col)
	draw_circle(at + Vector2(-rad * 0.15, -rad * 0.15), rad * 0.15, Color(1, 1, 1, 0.6))


func _skull(at: Vector2, s: float) -> void:
	var bone := Color("f2eee0")
	draw_circle(at + Vector2(0, -s * 0.15), s * 0.78, UiPalette.OUTLINE)
	rrect(Rect2(at + Vector2(-s * 0.48, s * 0.1), Vector2(s * 0.96, s * 0.6)), UiPalette.OUTLINE, s * 0.2)
	draw_circle(at + Vector2(0, -s * 0.15), s * 0.7, bone)
	rrect(Rect2(at + Vector2(-s * 0.4, s * 0.12), Vector2(s * 0.8, s * 0.5)), bone, s * 0.16)
	for sx in [-1.0, 1.0]:
		draw_circle(at + Vector2(sx * s * 0.28, -s * 0.08), s * 0.2, Color("1b1530"))
		draw_circle(at + Vector2(sx * s * 0.28, -s * 0.08), s * 0.07, SKULL_COL)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, s * 0.12), at + Vector2(-s * 0.08, s * 0.28), at + Vector2(s * 0.08, s * 0.28)]),
		Color("1b1530"))
	for t in 3:
		draw_line(at + Vector2((t - 1) * s * 0.18, s * 0.42), at + Vector2((t - 1) * s * 0.18, s * 0.6), Color("1b1530"), 2.0)


# --- hearts (misses) -------------------------------------------------------------------

func _heart_pos(k: int) -> Vector2:
	var n := int(state.get("misses", 6))
	var hs := _heart_size()
	var step := hs * 1.35
	var x0 := size.x * 0.5 - step * (n - 1) * 0.5
	return Vector2(x0 + k * step, _head.get_center().y)


func _heart_size() -> float:
	var n := int(state.get("misses", 6))
	return minf(_head.size.y * 0.62, size.x / (n * 1.35 + 1.0))


func _heart_poly(at: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for q in 28:
		var t := q * TAU / 28.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(at + Vector2(x, y + 2.5) * s / 34.0)
	return pts


func _draw_hearts() -> void:
	var n := int(state.get("misses", 6))
	var hs := _heart_size()
	# a little plaque behind the pips
	var w := hs * 1.35 * n + hs * 0.4
	var plq := Rect2(Vector2(size.x * 0.5 - w * 0.5, _head.get_center().y - hs * 0.72), Vector2(w, hs * 1.44))
	rrect(plq, Color(0.05, 0.03, 0.12, 0.55), hs * 0.5, 2, Color(1, 1, 1, 0.08))
	for k in n:
		var p := _heart_pos(k) + _so
		var alive := k < _hearts
		var ct := time - (_crack_t[k] if k < _crack_t.size() else -10.0)
		var s := hs
		if alive:
			var beat := 0.0
			if _hearts == 1:
				beat = 0.12 * maxf(0.0, sin(time * 7.0))
			else:
				beat = 0.04 * sin(time * 2.5 + k * 0.6)
			s *= 1.0 + beat
			draw_colored_polygon(_heart_poly(p + Vector2(0, 3), s * 1.2), Color(0, 0, 0, 0.3))
			draw_colored_polygon(_heart_poly(p, s * 1.22), UiPalette.OUTLINE)
			draw_colored_polygon(_heart_poly(p, s), HEART.darkened(0.25))
			draw_colored_polygon(_heart_poly(p + Vector2(0, -s * 0.06), s * 0.84), HEART)
			draw_circle(p + Vector2(-s * 0.2, -s * 0.18), s * 0.12, Color(1, 1, 1, 0.75))
			if _finale == "win" and time - _finale_t < dur(2.0):
				glow(p, s, Color(GOLD.r, GOLD.g, GOLD.b, 0.6))
		else:
			var fresh := ct < 0.45
			if fresh:
				p.x += sin(ct * 70.0) * s * 0.08 * (1.0 - ct / 0.45)
				s *= 1.0 + 0.25 * (1.0 - ct / 0.45)
			draw_colored_polygon(_heart_poly(p, s * 1.2), UiPalette.OUTLINE)
			draw_colored_polygon(_heart_poly(p, s), Color("4a4260"))
			draw_colored_polygon(_heart_poly(p + Vector2(0, -s * 0.06), s * 0.84), Color("5d5478"))
			# the crack
			var crack := PackedVector2Array([p + Vector2(-s * 0.02, -s * 0.34), p + Vector2(s * 0.1, -s * 0.12), p + Vector2(-s * 0.08, s * 0.04),
				p + Vector2(s * 0.08, s * 0.2), p + Vector2(0, s * 0.42)])
			draw_polyline(crack, UiPalette.OUTLINE, maxf(2.0, s * 0.09), true)
			if fresh:
				draw_colored_polygon(_heart_poly(p, s), Color(1, 1, 1, 0.6 * (1.0 - ct / 0.45)))


func _draw_banner() -> void:
	if _finale == "":
		return
	var t := time - _finale_t
	var k := clampf(t / dur(0.35), 0.0, 1.0)
	var pop := 1.0 + 0.3 * sin(k * PI) * (1.0 - k) + (1.0 - k) * 0.5
	var a := k
	var c := _grid.get_center() + _so
	var win := _finale == "win"
	var txt := "ALL PAIRS!" if win else "OUT OF MISSES"
	var fs := int(minf(_cw * (0.62 if win else 0.44), size.x * 0.1) * pop)
	var font := UiTheme.display_font()
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bh := fs * 1.6
	var br := Rect2(c - Vector2(tw * 0.5 + fs * 0.8, bh * 0.5), Vector2(tw + fs * 1.6, bh))
	var bcol := Color("7a2fbf") if win else Color("4a2a4a")
	if win:
		glow(c, br.size.x * 0.6, Color(1.0, 0.8, 0.3, 0.7 * a))
	rrect(Rect2(br.position + Vector2(0, 6), br.size), Color(0, 0, 0, 0.35 * a), bh * 0.4)
	rrect(br.grow(3.0), Color(UiPalette.OUTLINE.r, UiPalette.OUTLINE.g, UiPalette.OUTLINE.b, a), bh * 0.4 + 3.0)
	rrect(br, Color(bcol.r, bcol.g, bcol.b, a), bh * 0.4, 3, Color(GOLD.r, GOLD.g, GOLD.b, a) if win else Color(0.7, 0.5, 0.6, a))
	rrect(Rect2(br.position + Vector2(8, 5), Vector2(br.size.x - 16, bh * 0.3)), Color(1, 1, 1, 0.16 * a), bh * 0.2)
	var tc := Color("ffe07a") if win else Color("ffc0cc")
	tc.a = a
	var oc := UiPalette.OUTLINE
	oc.a = a
	text_c(c, txt, fs, tc, maxi(6, fs / 5), true, oc)
	if win:
		for sx in [-1.0, 1.0]:
			_star4(Vector2(c.x + sx * (br.size.x * 0.5 - fs * 0.4), c.y), fs * 0.3 * (1.0 + 0.15 * sin(time * 5.0)), Color(1, 0.95, 0.7, a))
		if t > dur(0.35):
			# a shimmer band across the banner
			var sk := fposmod((t - dur(0.35)) * 0.7, 1.5) - 0.2
			var x0 := br.position.x + sk * br.size.x * 1.3
			var band := PackedVector2Array([Vector2(x0, br.position.y), Vector2(x0 + fs * 0.6, br.position.y), Vector2(x0 - fs * 0.2, br.end.y),
				Vector2(x0 - fs * 0.8, br.end.y)])
			clipped(band, rect_poly(br.grow(-3.0)), Color(1, 1, 1, 0.25))


func _sym_col(sym: int) -> Color:
	match sym:
		7: return STAR_COL
		8: return SKULL_COL
	return Color("fff3c0")

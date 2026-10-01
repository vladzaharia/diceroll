class_name ShellBoard
extends MgBoard
## Shell Game: a street-hustler's stall (striped awning, a round-tracker sign, a green felt
## table) with three identical copper cups. Each round: a banner ("ROUND 2 / FASTER!"), the
## cups lift to show the gem under the start cup, thunk down, then shuffle: every swap from the
## public state plays at exactly its swap_time in REAL time (never game speed), the two cups
## trading places on arcs, one passing in front (bigger, lower) and one behind (smaller,
## higher), with shadows and a faint ghost trail so the eye can follow. Then the pick: cups
## glow under the finger / mouse and the Sharp Eye bar drains over ShellGame.QUICK seconds;
## a tap sends [cup, delay] (delay = real seconds since the last swap ended).
## The board never knows where the gem is after the shuffle: it only animates start + swaps.
## The result (the picked cup lifts; gem + "+N" or empty + the real cup lifting) plays from
## the minigame_update info.

const GAME := Color("e89a52")
const COPPER := Color("d27a3c")
const BAND := Color("ffd36a")
const FELT := Color("1f7a5a")
const FELT_DARK := Color("12503b")
const WOOD := Color("8a5a36")
const WOOD_DARK := Color("5a3620")
const CREAM := Color("fff1d6")
const GOOD := Color("6fe07a")
const BAD := Color("ff6a6a")
const GEM_TINT := Color("ff7ad0")

## Stall geometry (board-local, from _layout).
var _stage := Rect2()
var _u := 1.0
var _awn := Rect2()
var _sign := Rect2()
var _felt := Rect2()          # bounding box of the felt trapezoid
var _apron := Rect2()
var _pill := Rect2()
var _gy := 0.0                # cups' ground line
var _dy := 0.0                # front/back offset of a passing cup
var _cw := 80.0               # cup width (bottom)
var _lift_px := 50.0          # how high a lifted cup rises
var _ch := 90.0               # cup height
var _xs: Array[float] = [0.0, 0.0, 0.0]

## Round flow: intro | reveal | shuffle | pick | result | idle
var _phase := "idle"
var _gen := 0
var _busy := false
var _tweens: Array[Tween] = []
## Per cup (identity 0..2, all look alike): slot, x in slot units, depth (-1 back .. 1 front),
## lift 0..1, squash (decaying), hover glow 0..1.
var _slot := [0, 1, 2]
var _cx := [0.0, 1.0, 2.0]
var _depth := [0.0, 0.0, 0.0]
var _hop := [0.0, 0.0, 0.0]
var _lift := [0.0, 0.0, 0.0]
var _sq := [0.0, 0.0, 0.0]
var _hov := [0.0, 0.0, 0.0]
var _ghost := [-1.0, -1.0, -1.0]   # previous-frame-ish x for the trail (slot units), -1 = none
var _ghost_d := [0.0, 0.0, 0.0]
## Shuffle clock (real seconds).
var _swap_i := 0
var _swap_t := 0.0
var _pick_ms := 0
var _hover := -1
var _picked := -1
## Gem on the felt: slot (-1 hidden) and the time it popped.
var _gem_slot := -1
var _gem_t0 := 0.0
var _gem_win := false
## Banner: {title, sub, t0}.
var _banner := {}
## Results shown on the sign (grows as each pick is revealed).
var _shown: Array = []
var _last_quick := false
## A tap queued by the screenshot harness: {slot, drv}.
var _script_tap := {}


func _init() -> void:
	super._init()
	mouse_exited.connect(func() -> void: _hover = -1)


# --- state ---------------------------------------------------------------------------------

func set_state(st: Dictionary, instant := true) -> void:
	super.set_state(st, instant)
	_gen += 1
	_kill_tweens()
	_busy = false
	_banner = {}
	_gem_slot = -1
	_picked = -1
	_shown = (state.get("results", []) as Array).duplicate(true)
	_reset_cups()
	unlock()
	if _open_round():
		_run_round(_gen)
	else:
		_phase = "idle"


func _open_round() -> bool:
	return not bool(state.get("done", false)) and int(state.get("actions_left", 0)) > 0 and int(state.get("start", -1)) >= 0


func is_settled() -> bool:
	return not _busy


func status_text() -> String:
	var rounds := int(state.get("rounds", ShellGame.ROUNDS))
	var r := mini(int(state.get("round", 0)) + 1, rounds)
	if _phase == "pick":
		return "Pick a cup!"
	return "Round %d/%d" % [r, rounds]


func _reset_cups() -> void:
	for i in 3:
		_slot[i] = i
		_cx[i] = float(i)
		_depth[i] = 0.0
		_hop[i] = 0.0
		_lift[i] = 0.0
		_ghost[i] = -1.0


func _kill_tweens() -> void:
	for t in _tweens:
		if t and t.is_valid():
			t.kill()
	_tweens.clear()


func _tw() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	if _tweens.size() > 24:
		_tweens = _tweens.filter(func(x: Tween) -> bool: return x.is_valid())
	return t


func _cup_in(slot: int) -> int:
	for i in 3:
		if int(_slot[i]) == slot:
			return i
	return slot


## Tweens cup i's lift to `to` (awaitable through the returned tween).
func _lift_to(i: int, to: float, t: float, trans := Tween.TRANS_BACK, ease_ := Tween.EASE_OUT) -> Tween:
	var tw := _tw()
	tw.tween_method(func(v: float) -> void: _lift[i] = v, float(_lift[i]), to, dur(t)).set_trans(trans).set_ease(ease_)
	return tw


# --- a round ---------------------------------------------------------------------------------

func _run_round(g: int) -> void:
	_phase = "intro"
	await wait(0.45)
	if g != _gen or not is_inside_tree():
		return
	var r := int(state.get("round", 0))
	var n := (state.get("swaps", []) as Array).size()
	var subs := ["WATCH THE GEM!", "FASTER!", "FASTEST!"]
	_banner = {"title": "ROUND %d" % (r + 1), "sub": "%s  %d SWAPS" % [subs[clampi(r, 0, 2)], n], "t0": time}
	MgBoard.sfx("bell", 0.05, -4.0)
	await wait(0.9)
	if g != _gen:
		return
	_banner = {}
	# the reveal: all three cups lift, the gem sparkles under the start cup
	_phase = "reveal"
	MgBoard.sfx("swoosh")
	var last: Tween
	for i in 3:
		last = _lift_to(i, 1.0, 0.32)
	await wait(0.1)
	if g != _gen:
		return
	_show_gem(int(state.get("start", 0)), false)
	await last.finished
	if g != _gen:
		return
	await wait(0.8)
	if g != _gen:
		return
	for i in 3:
		last = _lift_to(i, 0.0, 0.2, Tween.TRANS_QUAD, Tween.EASE_IN)
	await last.finished
	if g != _gen:
		return
	_thunk_all()
	_gem_slot = -1
	await wait(0.45)
	if g != _gen:
		return
	# the shuffle runs in _tick on the real clock
	_swap_i = 0
	_swap_t = 0.0
	_phase = "shuffle"
	if n == 0:
		_begin_pick(Time.get_ticks_msec())
	else:
		_swap_sfx()


func _show_gem(slot: int, win: bool) -> void:
	_gem_slot = slot
	_gem_t0 = time
	_gem_win = win
	var p := _gem_pos(slot)
	MgBoard.sfx("glass", 0.08)
	burst(p, Color("ffe2f6"), 14, "star", 200.0, 60.0, 8.0 * _u)
	ring(p, GEM_TINT.lightened(0.3), 70.0 * _u, 0.45, 6.0)


func _thunk_all() -> void:
	MgBoard.sfx("cup_knock")
	shake(2.5)
	for i in 3:
		_sq[i] = 1.0
		for sx: float in [-1.0, 1.0]:
			burst(Vector2(_x_of(float(_cx[i])) + sx * _cw * 0.55, _gy), Color(0.8, 0.95, 0.85, 0.5), 2, "puff", 70.0, 0.0, 6.0 * _u)


func _swap_sfx() -> void:
	MgBoard.sfx("swoosh", 0.15, -7.0)


func _begin_pick(end_ms: int) -> void:
	_phase = "pick"
	_pick_ms = end_ms
	for i in 3:
		_cx[i] = float(_slot[i])
		_depth[i] = 0.0
		_hop[i] = 0.0
		_ghost[i] = -1.0
	MgBoard.sfx("tick")
	for i in 3:
		ring(Vector2(_x_of(float(_cx[i])), _gy - _ch * 0.5), GAME.lightened(0.3), _cw * 0.7, 0.35, 5.0)


## Pose of the two cups of swap [a, b] at progress t (0..1): [x of the cup leaving a, its depth,
## x of the cup leaving b, its depth, hop]. x in slot units; the a-cup passes in front when
## a_front. Eased so the cups start and land softly; the far swap (0 <-> 2) hops a little.
static func swap_pose(a: int, b: int, t: float, a_front: bool) -> Array:
	var k := clampf(t, 0.0, 1.0)
	var e := 0.5 - 0.5 * cos(PI * k)
	var arc := sin(PI * k)
	var s := 1.0 if a_front else -1.0
	var hop := arc * (0.35 if absi(a - b) >= 2 else 0.12)
	return [lerpf(a, b, e), arc * s, lerpf(b, a, e), -arc * s, hop]


## Which slot a board-local x belongs to (nearest centre within `half`), -1 = none.
static func nearest_slot(x: float, xs: Array, half: float) -> int:
	var best := -1
	var bd := half
	for i in xs.size():
		var d := absf(x - float(xs[i]))
		if d <= bd:
			bd = d
			best = i
	return best


func _front_for(k: int) -> bool:
	return ((k * 5 + int(state.get("round", 0))) % 3) != 1


func _tick(dt: float) -> void:
	for i in 3:
		_sq[i] = move_toward(float(_sq[i]), 0.0, dt * 3.2)
		var want := 1.0 if (_phase == "pick" and not locked and _hover == int(_slot[i])) else 0.0
		_hov[i] = move_toward(float(_hov[i]), want, dt * 7.0)
	_scripted_tick()
	if _phase == "pick":
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover >= 0 and not locked else Control.CURSOR_ARROW
	if _phase != "shuffle":
		return
	# real time on purpose: the swap pace is the game's skill, never the game speed
	var swaps: Array = state.get("swaps", [])
	var tt := maxf(0.05, float(state.get("swap_time", 0.4)))
	_swap_t += dt
	while _swap_t >= tt and _swap_i < swaps.size():
		var s: Array = swaps[_swap_i]
		var ca := _cup_in(int(s[0]))
		var cb := _cup_in(int(s[1]))
		_slot[ca] = int(s[1])
		_slot[cb] = int(s[0])
		_swap_t -= tt
		_swap_i += 1
		MgBoard.sfx("cup_knock", 0.25, -12.0)
		if _swap_i < swaps.size():
			_swap_sfx()
	if _swap_i >= swaps.size():
		_begin_pick(Time.get_ticks_msec() - int(_swap_t * 1000.0))
		return
	var cur: Array = swaps[_swap_i]
	var a := int(cur[0])
	var b := int(cur[1])
	var ca2 := _cup_in(a)
	var cb2 := _cup_in(b)
	var k := _swap_t / tt
	var pose := swap_pose(a, b, k, _front_for(_swap_i))
	var back := swap_pose(a, b, maxf(0.0, k - 0.22), _front_for(_swap_i))
	for i in 3:
		_ghost[i] = -1.0
		if i != ca2 and i != cb2:
			_cx[i] = float(_slot[i])
			_depth[i] = 0.0
			_hop[i] = 0.0
	_cx[ca2] = float(pose[0])
	_depth[ca2] = float(pose[1])
	_cx[cb2] = float(pose[2])
	_depth[cb2] = float(pose[3])
	_hop[ca2] = float(pose[4])
	_hop[cb2] = float(pose[4])
	if k > 0.12 and k < 0.9:
		_ghost[ca2] = float(back[0])
		_ghost_d[ca2] = float(back[1])
		_ghost[cb2] = float(back[2])
		_ghost_d[cb2] = float(back[3])


# --- input --------------------------------------------------------------------------------

func slot_at(p: Vector2) -> int:
	if p.y < _gy - _ch * 1.45 or p.y > _gy + _ch * 0.45:
		return -1
	return nearest_slot(p.x, _xs, (_xs[1] - _xs[0]) * 0.5 if _xs[1] > _xs[0] else _cw)


func _gui_input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm:
		_hover = slot_at(mm.position)
		return
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_hover = slot_at(mb.position)
		pick(_hover)


## A tap on the cup at slot `slot` during the pick phase.
func pick(slot: int) -> void:
	if slot < 0 or locked or _phase != "pick":
		return
	var delay := (Time.get_ticks_msec() - _pick_ms) / 1000.0
	_picked = slot
	MgBoard.sfx("click")
	var i := _cup_in(slot)
	_sq[i] = 0.6
	send([slot, snappedf(delay, 0.001)])


## Harness: queue a tap on the cup at args[0]; the board performs it (injected mouse input, like
## a player) once the shuffle is over + ~0.5 s. Returns at once on purpose: awaiting in here trips
## a GDScript VM bug in the harness's `if not await b.scripted_input(...)` (the command check
## after it never passes); its 8 s command wait covers intro + reveal + shuffle (<= 6.7 s).
func scripted_input(args: Array, drv: Node) -> bool:
	if args.is_empty() or drv == null:
		return false
	_script_tap = {"slot": clampi(int(args[0]), 0, 2), "drv": drv}
	return true


## Keyboard: 1 / 2 / 3 pick the left / middle / right cup (a click on it, like the scripted
## pick but without the harness's settle delay).
func key_input(event: InputEvent, drv: Node) -> bool:
	var n := InputActions.pressed_index(event, InputActions.MG_PICK)
	if n < 0:
		return false
	if _phase == "pick" and not locked:
		var p := get_global_rect().position + Vector2(_xs[n], _gy - _ch * 0.5)
		drv.call("move", p, false)
		drv.call("click", p)
	return true


func _scripted_tick() -> void:
	if _script_tap.is_empty() or _phase != "pick" or locked:
		return
	if Time.get_ticks_msec() - _pick_ms < 500:
		return
	var drv: Node = _script_tap.get("drv")
	var slot := int(_script_tap.slot)
	_script_tap = {}
	if not is_instance_valid(drv):
		return
	var p := get_global_rect().position + Vector2(_xs[slot], _gy - _ch * 0.5)
	drv.call("move", p, false)
	drv.call("click", p)


# --- result -------------------------------------------------------------------------------

func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	_gen += 1
	_kill_tweens()
	_layout()
	_busy = true
	_banner = {}
	var info: Dictionary = ev.get("info", {})
	var pick_s := clampi(int(info.get("pick", 0)), 0, 2)
	var gem_s := clampi(int(info.get("gem", 0)), 0, 2)
	var ok := bool(info.get("correct", false))
	var quick := bool(info.get("quick", false))
	var pts := int(info.get("points", 0))
	if _phase != "pick":
		# AUTO (or a resync) picked mid-shuffle: settle the cups where the core says they are
		for i in 3:
			_cx[i] = float(_slot[i])
			_depth[i] = 0.0
			_hop[i] = 0.0
			_ghost[i] = -1.0
			_lift[i] = 0.0
	_phase = "result"
	_picked = pick_s
	_hover = -1
	var ci := _cup_in(pick_s)
	# anticipation: a little wobble, then the lift
	_sq[ci] = 0.8
	await wait(0.16)
	MgBoard.sfx("swoosh")
	var t := _lift_to(ci, 1.0, 0.3)
	await t.finished
	var at := _gem_pos(pick_s)
	_last_quick = quick
	if ok:
		_show_gem(pick_s, true)
		MgBoard.sfx("win" if quick else "coin")
		burst(at, GOOD.lightened(0.3), 16, "spark", 300.0, 80.0, 8.0 * _u)
		burst(at, Color("ffe07a"), 12, "star", 260.0, 120.0, 10.0 * _u)
		ring(at, GOOD, 110.0 * _u, 0.5, 8.0)
		shake(4.0)
		kick.emit(0.35, Color(0.4, 1.0, 0.5, 0.3))
		float_text(at + Vector2(0, -_ch * 0.9), "+%d" % pts, Color("ffe07a"), int(52 * _u + 8), 1.2)
		if quick:
			await wait(0.28)
			MgBoard.sfx("fanfare", 0.0, -4.0)
			var sp := Vector2(_stage.get_center().x, _felt.position.y + _felt.size.y * 0.97)
			float_text(sp, "SHARP EYE x2!", Color("7fe8ff"), int(44 * _u + 8), 1.4)
			burst(sp + Vector2(0, -30.0 * _u), Color("bff4ff"), 22, "star", 360.0, 40.0, 10.0 * _u)
			ring(_pill.position + Vector2(_pill.size.y * 0.2, _pill.size.y * 0.5), Color("7fe8ff"), 80.0 * _u, 0.5, 7.0)
			kick.emit(0.6, Color(0.5, 0.9, 1.0, 0.35))
			shake(6.0)
	else:
		MgBoard.sfx("error")
		MgBoard.sfx("tin", 0.1, -6.0)
		float_text(at + Vector2(0, -_ch * 0.9), "EMPTY!", Color("ffb0b0"), int(44 * _u + 8), 1.1)
		burst(at, Color(0.8, 0.8, 0.9, 0.6), 6, "puff", 80.0, 0.0, 10.0 * _u)
		shake(3.0)
		await wait(0.5)
		var cg := _cup_in(gem_s)
		MgBoard.sfx("swoosh")
		t = _lift_to(cg, 1.0, 0.3)
		await t.finished
		_show_gem(gem_s, false)
		float_text(_gem_pos(gem_s) + Vector2(0, -_ch * 0.9), "HERE!", GEM_TINT.lightened(0.35), int(34 * _u + 8), 1.0)
	_shown.append(info.duplicate(true))
	await wait(0.85)
	var last: Tween = null
	for i in 3:
		if float(_lift[i]) > 0.01:
			last = _lift_to(i, 0.0, 0.2, Tween.TRANS_QUAD, Tween.EASE_IN)
	if last:
		await last.finished
		_thunk_all()
	_gem_slot = -1
	_picked = -1
	await wait(0.25)
	state = (ev.get("state", {}) as Dictionary).duplicate(true)
	_shown = (state.get("results", []) as Array).duplicate(true)
	_busy = false
	unlock()
	_reset_cups()
	if _open_round():
		_gen += 1
		_run_round(_gen)
	else:
		_phase = "idle"


# --- layout ---------------------------------------------------------------------------------

func _layout() -> void:
	var sw := minf(size.x - 8.0, size.y * 1.02)
	var sh := minf(size.y - 8.0, sw * 1.3)
	_stage = Rect2((size - Vector2(sw, sh)) * 0.5, Vector2(sw, sh))
	_u = sw / 520.0
	var x0 := _stage.position.x
	var y0 := _stage.position.y
	_awn = Rect2(Vector2(x0, y0), Vector2(sw, sh * 0.1))
	_sign = Rect2(Vector2(x0 + sw * 0.14, y0 + sh * 0.115), Vector2(sw * 0.72, sh * 0.13))
	_felt = Rect2(Vector2(x0 + sw * 0.02, y0 + sh * 0.27), Vector2(sw * 0.96, sh * 0.52))
	_apron = Rect2(Vector2(x0, _felt.end.y), Vector2(sw, sh - (_felt.end.y - y0)))
	var pw := minf(sw * 0.62, 340.0 * _u + 40.0)
	_pill = Rect2(Vector2(_stage.get_center().x - pw * 0.5, _apron.position.y + _apron.size.y * 0.3), Vector2(pw, _apron.size.y * 0.5))
	var fh := _felt.size.y
	_gy = _felt.position.y + fh * 0.7
	_dy = fh * 0.12
	var spacing := _felt.size.x * 0.31
	_cw = _felt.size.x * 0.225
	_ch = _cw * 1.08
	for i in 3:
		_xs[i] = _stage.get_center().x + (i - 1) * spacing
	# lifted cups rise high enough to show the gem, but stay under the round sign if they can
	var room := (_gy - _ch * 1.12) - (_sign.end.y + 4.0)
	_lift_px = clampf(room, _ch * 0.5, _ch * 0.64)


func _x_of(slot_x: float) -> float:
	var sp := _xs[1] - _xs[0]
	return _xs[0] + slot_x * sp


func _gem_pos(slot: int) -> Vector2:
	return Vector2(_xs[clampi(slot, 0, 2)], _gy - _gem_size() * 0.3)


## The gem's size on the felt: as big as fits under a lifted cup.
func _gem_size() -> float:
	return clampf(_lift_px * 1.3, _cw * 0.66, _cw * 0.86)


# --- drawing --------------------------------------------------------------------------------

func _draw_board() -> void:
	_layout()
	_draw_stall()
	_draw_felt()
	_draw_apron()
	# cups: shadows first, then the gem, then cups back to front
	var order := [0, 1, 2]
	order.sort_custom(func(a: int, b: int) -> bool: return float(_depth[a]) < float(_depth[b]))
	for i: int in order:
		_cup_shadow(i)
	if _gem_slot >= 0:
		_draw_gem_on_felt()
	for i: int in order:
		if float(_ghost[i]) >= 0.0:
			_draw_cup_at(float(_ghost[i]), float(_ghost_d[i]), float(_hop[i]), 0.0, 0.0, 0.0, 0.22)
	for i: int in order:
		var glow_k := float(_hov[i])
		if _phase == "pick" and not locked:
			glow_k = maxf(glow_k, 0.3 + 0.15 * sin(time * 5.0 + i))
		if _phase == "result" and _picked == int(_slot[i]):
			glow_k = 0.8
		_draw_cup_at(float(_cx[i]), float(_depth[i]), float(_hop[i]), float(_lift[i]), float(_sq[i]), glow_k, 1.0)
	if _phase == "pick" and not locked:
		var a := clampf((time - 0.0) * 3.0, 0.0, 1.0)
		var py := _felt.position.y + _felt.size.y * 0.1
		text_c(Vector2(_stage.get_center().x, py + sin(time * 4.0) * 3.0), "WHERE'S THE GEM?", int(30 * _u + 6), Color(CREAM, a),
			int(8 * _u + 3))
	if not _banner.is_empty():
		_draw_banner()


func _draw_stall() -> void:
	var s := _stage
	var u := _u
	# back wall: dark planks behind the table
	var wall := Rect2(Vector2(s.position.x + s.size.x * 0.03, _awn.get_center().y), Vector2(s.size.x * 0.94, _felt.position.y + _felt.size.y * 0.4 - _awn.get_center().y))
	rrect(wall.grow(3.0), UiPalette.OUTLINE, 18 * u + 3)
	rrect(wall, Color("3b2233"), 18 * u)
	for k in 7:
		var x := wall.position.x + wall.size.x * (k + 1) / 8.0
		draw_line(Vector2(x, wall.position.y + 6), Vector2(x, wall.end.y - 6), Color(0, 0, 0, 0.25), 3.0 * u)
		draw_line(Vector2(x + 2.0 * u, wall.position.y + 6), Vector2(x + 2.0 * u, wall.end.y - 6), Color(1, 1, 1, 0.04), 2.0 * u)
	# a lantern glow on the wall
	glow(Vector2(s.get_center().x, _sign.end.y + 10.0 * u), s.size.x * 0.5, Color(1.0, 0.75, 0.4, 0.5 + 0.06 * sin(time * 3.1)))
	# posts
	for sx: float in [-1.0, 1.0]:
		var px := s.get_center().x + sx * s.size.x * 0.47
		var pr := Rect2(Vector2(px - 9.0 * u, _awn.get_center().y), Vector2(18.0 * u, _felt.position.y + _felt.size.y * 0.3 - _awn.get_center().y))
		rrect(pr.grow(2.5), UiPalette.OUTLINE, 6)
		rrect(pr, WOOD, 5)
		draw_rect(Rect2(pr.position, Vector2(pr.size.x * 0.35, pr.size.y)), Color(1, 1, 1, 0.12))
	# striped awning with a scalloped hem that sways a touch
	var a := _awn
	var n := 8
	var sway := sin(time * 1.3) * 2.0 * u
	var hem: Array = []
	for k in n * 6 + 1:
		var f := float(k) / (n * 6)
		var x := a.position.x + a.size.x * f
		var sc := absf(sin(PI * f * n))
		hem.append(Vector2(x, a.end.y + sc * a.size.y * 0.32 + sway * sin(f * 9.0)))
	var ord := PackedVector2Array([a.position + Vector2(-4, -4), Vector2(a.end.x + 4, a.position.y - 4)])
	for k in range(hem.size() - 1, -1, -1):
		ord.append((hem[k] as Vector2) + Vector2(0, 4))
	draw_colored_polygon(ord, UiPalette.OUTLINE)
	for k in n:
		var col := GAME if k % 2 == 0 else CREAM
		var pts := PackedVector2Array([a.position + Vector2(a.size.x * k / n, 0), a.position + Vector2(a.size.x * (k + 1) / n, 0)])
		for j in range(6, -1, -1):
			pts.append(hem[k * 6 + j])
		draw_colored_polygon(pts, col)
		var shade := PackedVector2Array([a.position + Vector2(a.size.x * k / n, a.size.y * 0.7), a.position + Vector2(a.size.x * (k + 1) / n, a.size.y * 0.7)])
		for j in range(6, -1, -1):
			shade.append(hem[k * 6 + j])
		draw_colored_polygon(shade, Color(0, 0, 0, 0.14))
	draw_rect(Rect2(a.position, Vector2(a.size.x, a.size.y * 0.22)), Color(1, 1, 1, 0.16))
	rrect(Rect2(a.position + Vector2(-6, -8) * u, Vector2(a.size.x + 12 * u, 12 * u)), UiPalette.OUTLINE, 6)
	rrect(Rect2(a.position + Vector2(-4, -6) * u, Vector2(a.size.x + 8 * u, 8 * u)), GAME.darkened(0.3), 4)
	_draw_sign()


## The round tracker: three pips (result tick / cross, current round pulsing) + points.
func _draw_sign() -> void:
	var r := _sign
	var u := _u
	# ropes
	for sx: float in [0.2, 0.8]:
		draw_line(Vector2(r.position.x + r.size.x * sx, _awn.end.y), Vector2(r.position.x + r.size.x * sx, r.position.y + 6), UiPalette.OUTLINE, 4.0 * u)
	rrect(r.grow(3.0), UiPalette.OUTLINE, 16 * u + 3)
	rrect(r, WOOD_DARK, 16 * u)
	rrect(Rect2(r.position, r.size - Vector2(0, 5.0 * u)), WOOD, 16 * u)
	draw_rect(Rect2(r.position + Vector2(10 * u, 5 * u), Vector2(r.size.x - 20 * u, 4 * u)), Color(1, 1, 1, 0.15))
	for k in 3:
		draw_line(Vector2(r.position.x + 12 * u, r.position.y + r.size.y * (0.35 + 0.22 * k)), Vector2(r.end.x - 12 * u, r.position.y + r.size.y * (0.35 + 0.22 * k)),
			Color(0, 0, 0, 0.1), 2.0)
	var rounds := int(state.get("rounds", ShellGame.ROUNDS))
	var cur := int(state.get("round", 0))
	var pr := minf(r.size.y * 0.3, 26.0 * u + 4.0)
	var gap := minf(r.size.x * 0.2, pr * 3.4)
	var cx0 := r.position.x + r.size.x * 0.4 - gap
	var cy := r.position.y + r.size.y * 0.4
	var total := 0
	for res: Dictionary in _shown:
		total += int(res.get("points", 0))
	draw_line(Vector2(cx0, cy), Vector2(cx0 + gap * (rounds - 1), cy), UiPalette.OUTLINE, 6.0 * u)
	for k in rounds:
		var c := Vector2(cx0 + gap * k, cy)
		var res: Dictionary = _shown[k] if k < _shown.size() else {}
		draw_circle(c, pr + 3.0, UiPalette.OUTLINE)
		if res.is_empty():
			var live := k == cur and _phase != "idle"
			var col := GAME if live else Color("4a3048")
			if live:
				var pulse := 0.5 + 0.5 * sin(time * 5.0)
				draw_circle(c, pr + 3.0 + 5.0 * pulse * u, Color(GAME, 0.35 * (1.0 - pulse)))
			draw_circle(c, pr, col)
			text_c(c, str(k + 1), int(pr * 1.1), CREAM if live else Color(1, 1, 1, 0.45), int(4 * u + 2))
		else:
			var ok := bool(res.get("correct", false))
			var q := bool(res.get("quick", false))
			var col := (Color("7fe8ff") if q else GOOD) if ok else BAD
			draw_circle(c, pr, col.darkened(0.25))
			draw_circle(c + Vector2(0, -2.0 * u), pr - 2.0 * u, col)
			if ok:
				var pts := PackedVector2Array([c + Vector2(-0.45, 0.02) * pr, c + Vector2(-0.12, 0.35) * pr, c + Vector2(0.5, -0.35) * pr])
				draw_polyline(pts, UiPalette.OUTLINE, pr * 0.34, true)
				draw_polyline(pts, Color.WHITE, pr * 0.18, true)
			else:
				for sgn: float in [-1.0, 1.0]:
					draw_line(c + Vector2(-0.38, -0.38 * sgn) * pr, c + Vector2(0.38, 0.38 * sgn) * pr, UiPalette.OUTLINE, pr * 0.34, true)
					draw_line(c + Vector2(-0.38, -0.38 * sgn) * pr, c + Vector2(0.38, 0.38 * sgn) * pr, Color.WHITE, pr * 0.16, true)
			var lab := ("+%d" % int(res.points)) if ok else "0"
			text_c(c + Vector2(0, pr + 9.0 * u), lab, int(17 * u + 5), CREAM if ok else Color("ffb0b0"), int(4 * u + 2))
	# points total
	var tx := r.position.x + r.size.x * 0.84
	text_c(Vector2(tx, cy - pr * 0.15), str(total), int(30 * u + 6), Color("ffe07a"), int(6 * u + 3))
	text_c(Vector2(tx, cy + pr * 0.95), "PTS", int(13 * u + 5), CREAM, int(4 * u + 2))


func _felt_poly() -> PackedVector2Array:
	var f := _felt
	var inset := f.size.x * 0.09
	return PackedVector2Array([f.position + Vector2(inset, 0), Vector2(f.end.x - inset, f.position.y), f.end, Vector2(f.position.x, f.end.y)])


func _draw_felt() -> void:
	var u := _u
	var poly := _felt_poly()
	# wooden rim (a slightly bigger trapezoid) then the felt
	var rim := PackedVector2Array()
	var c := _felt.get_center()
	for p in poly:
		rim.append(p + (p - c).normalized() * 14.0 * u)
	var rim_o := PackedVector2Array()
	for p in poly:
		rim_o.append(p + (p - c).normalized() * 18.0 * u)
	draw_colored_polygon(rim_o, UiPalette.OUTLINE)
	draw_colored_polygon(rim, WOOD)
	draw_colored_polygon(poly, FELT_DARK)
	# felt with a lamp-lit centre: concentric insets
	for k in 5:
		var kk := float(k + 1) / 6.0
		var inner := PackedVector2Array()
		for p in poly:
			inner.append(c + (p - c) * (1.0 - kk * 0.55) + Vector2(0, kk * 6.0 * u))
		draw_colored_polygon(inner, FELT_DARK.lerp(FELT.lightened(0.12), kk))
	# a stitched border line
	var st := PackedVector2Array()
	for p in poly:
		st.append(c + (p - c) * 0.93)
	st.append(st[0])
	for k in st.size() - 1:
		var a := st[k]
		var b := st[k + 1]
		var n := int(a.distance_to(b) / (14.0 * u))
		for j in n:
			if j % 2 == 0:
				draw_line(a.lerp(b, float(j) / n), a.lerp(b, float(j + 1) / n), Color(1.0, 0.9, 0.6, 0.35), 2.0 * u)
	# felt specks
	for k in 30:
		var hx := float(hash(k * 97 + 5) % 1000) / 1000.0
		var hy := float(hash(k * 53 + 9) % 1000) / 1000.0
		var p := Vector2(_felt.position.x + _felt.size.x * (0.12 + hx * 0.76), _felt.position.y + _felt.size.y * (0.08 + hy * 0.86))
		draw_circle(p, 1.5 * u + 0.5, Color(1, 1, 1, 0.05))
	# twinkles
	for k in 5:
		var hx := float(hash(k * 31 + 1) % 1000) / 1000.0
		var hy := float(hash(k * 17 + 3) % 1000) / 1000.0
		var tw := maxf(0.0, sin(time * 1.7 + k * 2.3))
		_star4(Vector2(_felt.position.x + _felt.size.x * (0.1 + hx * 0.8), _felt.position.y + _felt.size.y * (0.08 + hy * 0.2)), (3.0 + 4.0 * tw) * u,
			Color(1, 1, 0.8, 0.35 * tw))


func _draw_apron() -> void:
	var u := _u
	var a := Rect2(_apron.position + Vector2(_stage.size.x * 0.0, 0), Vector2(_apron.size.x, _apron.size.y * 0.86))
	rrect(a.grow(3.0), UiPalette.OUTLINE, 14 * u + 3)
	rrect(a, WOOD_DARK, 14 * u)
	rrect(Rect2(a.position, a.size - Vector2(0, 6.0 * u)), WOOD, 14 * u)
	draw_rect(Rect2(a.position + Vector2(12 * u, 4 * u), Vector2(a.size.x - 24 * u, 5 * u)), Color(1, 1, 1, 0.14))
	for sx: float in [0.04, 0.96]:
		var p := Vector2(a.position.x + a.size.x * sx, a.get_center().y)
		draw_circle(p, 7.0 * u + 2, UiPalette.OUTLINE)
		draw_circle(p, 7.0 * u, Color("ffc93d"))
		draw_circle(p + Vector2(-2, -2) * u, 2.5 * u, Color(1, 1, 1, 0.6))
	_draw_sharp_eye()


## The Sharp Eye bar: full during the shuffle, drains over ShellGame.QUICK real seconds in the
## pick phase, then greys out ("no rush").
func _draw_sharp_eye() -> void:
	var r := _pill
	var u := _u
	var left := 1.0
	var live := false
	if _phase == "pick" and not locked:
		left = 1.0 - clampf((Time.get_ticks_msec() - _pick_ms) / 1000.0 / ShellGame.QUICK, 0.0, 1.0)
		live = true
	elif _phase == "pick" or _phase == "result":
		left = 0.0 if not _last_quick or _phase == "pick" else 1.0
	var expired := live and left <= 0.0
	var col := Color("7fe8ff")
	var rad := r.size.y * 0.5
	rrect(r.grow(3.0), UiPalette.OUTLINE, rad + 3)
	rrect(r, Color("1d2447"), rad)
	var fill_w := (r.size.x - 8.0) * left
	if fill_w > rad * 0.5:
		var fr := Rect2(r.position + Vector2(4, 4), Vector2(fill_w, r.size.y - 8))
		var fc := col if left > 0.35 else Color("ffd36a").lerp(Color("ff7a5a"), 1.0 - left / 0.35)
		if not live and _phase != "result":
			fc = fc.darkened(0.45)
		rrect(fr, fc.darkened(0.2), rad - 4)
		rrect(Rect2(fr.position, Vector2(fr.size.x, fr.size.y * 0.55)), fc, rad - 4)
	# eye badge with a draining ring
	var ec := Vector2(r.position.x + rad * 0.4, r.get_center().y)
	var er := rad * 1.25
	draw_circle(ec, er + 3.0, UiPalette.OUTLINE)
	draw_circle(ec, er, Color("2a3466"))
	if live and left > 0.0:
		draw_arc(ec, er - 3.0 * u, -PI * 0.5, -PI * 0.5 + TAU * left, 32, col, 5.0 * u, true)
	var eye_s := er * 0.62
	var eye := PackedVector2Array()
	for k in 17:
		var t := PI * k / 16.0
		eye.append(ec + Vector2(-cos(t) * eye_s, -sin(t) * eye_s * 0.55))
	for k in range(15, 0, -1):
		var t := PI * k / 16.0
		eye.append(ec + Vector2(-cos(t) * eye_s, sin(t) * eye_s * 0.55))
	var ecol := Color(1, 1, 1, 0.35) if expired or (not live and _phase != "result") else Color.WHITE
	draw_colored_polygon(eye, ecol)
	draw_circle(ec, eye_s * 0.42, Color("1d2447"))
	draw_circle(ec + Vector2(-eye_s * 0.12, -eye_s * 0.12), eye_s * 0.13, Color(1, 1, 1, 0.9))
	var txt := "SHARP EYE x2"
	if expired:
		txt = "NO RUSH..."
	elif _phase == "result" and _last_quick:
		txt = "SHARP EYE!"
	var tcol := CREAM if (live and not expired) or (_phase == "result" and _last_quick) else Color(1, 1, 1, 0.5)
	text_c(Vector2(r.position.x + rad + (r.size.x - rad) * 0.5, r.get_center().y), txt, int(r.size.y * 0.46), tcol, int(5 * u + 2))


func _draw_banner() -> void:
	var k := (time - float(_banner.t0)) / dur(0.9)
	var inn := clampf(k / 0.18, 0.0, 1.0)
	var out := clampf((k - 0.82) / 0.18, 0.0, 1.0)
	var sc := (0.4 + 0.6 * ease(inn, 0.3) + 0.12 * sin(inn * PI)) * (1.0 - 0.3 * out)
	var a := 1.0 - out
	var c := Vector2(_stage.get_center().x, _felt.position.y + _felt.size.y * 0.32)
	draw_set_transform(c, sin(time * 3.0) * 0.02, Vector2(sc, sc))
	var w := minf(_stage.size.x * 0.82, 400.0 * _u + 40.0)
	var h := 118.0 * _u + 20.0
	rrect(Rect2(Vector2(-w * 0.5, -h * 0.5) + Vector2(0, 8 * _u), Vector2(w, h)), Color(0, 0, 0, 0.35 * a), 22 * _u)
	rrect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)).grow(3.0), Color(UiPalette.OUTLINE, a), 22 * _u + 3)
	rrect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), Color(GAME.darkened(0.25), a), 22 * _u)
	rrect(Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h * 0.5)), Color(1, 1, 1, 0.12 * a), 22 * _u)
	text_c(Vector2(0, -h * 0.14), String(_banner.title), int(52 * _u + 8), Color(CREAM, a), int(9 * _u + 3))
	text_c(Vector2(0, h * 0.27), String(_banner.sub), int(22 * _u + 5), Color(Color("ffe07a"), a), int(5 * _u + 2))
	draw_set_transform(Vector2.ZERO)


# --- cups & gem -----------------------------------------------------------------------------

func _pose(slot_x: float, depth: float, hop: float) -> Array:
	var x := _x_of(slot_x)
	var y := _gy + depth * _dy * (1.0 + 0.0) - hop * _ch
	var s := 1.0 + depth * 0.12
	return [Vector2(x, y), s]


func _cup_shadow(i: int) -> void:
	var p := _pose(float(_cx[i]), float(_depth[i]), 0.0)
	var base: Vector2 = p[0]
	var s: float = p[1]
	var lift := float(_lift[i]) + float(_hop[i]) * 1.4
	var k := 1.0 - clampf(lift, 0.0, 1.0) * 0.45
	_ellipse(base + Vector2(4.0 * _u, 2.0 * _u), _cw * 0.6 * s * k, _cw * 0.16 * s * k, Color(0, 0, 0, 0.38 * k))


func _draw_cup_at(slot_x: float, depth: float, hop: float, lift: float, sq: float, glow_k: float, alpha: float) -> void:
	var p := _pose(slot_x, depth, hop)
	var base: Vector2 = p[0]
	var s: float = p[1]
	base.y -= lift * _lift_px
	var q := sq * cos((1.0 - sq) * 14.0)
	var w := _cw * s * (1.0 + 0.1 * q)
	var h := _ch * s * (1.0 - 0.1 * q)
	_cup(base, w, h, glow_k, alpha, lift)


## One cup: bottom-centre `b` (on the felt), bottom width w, height h. glow_k: hover / pick glow.
## alpha < 1: a translucent ghost silhouette only (the motion trail).
func _cup(b: Vector2, w: float, h: float, glow_k: float, alpha: float, lift: float) -> void:
	var wb := w * 0.5
	var wt := w * 0.33
	var ryb := w * 0.13
	var ryt := wt * 0.34
	var top := b.y - h
	var cx := b.x
	# silhouette: top ellipse's back half, sides, bottom ellipse's front half
	var sil := PackedVector2Array()
	for k in 13:
		var t := PI + PI * k / 12.0
		sil.append(Vector2(cx + cos(t) * wt, top + sin(t) * ryt))
	for k in 13:
		var t := PI * k / 12.0
		sil.append(Vector2(cx + cos(t) * wb * 1.04, b.y + sin(t) * ryb))
	var ctr := Vector2(cx, (top + b.y) * 0.5)
	if alpha < 1.0:
		draw_colored_polygon(sil, Color(COPPER.lightened(0.2), alpha))
		return
	if glow_k > 0.01:
		var g := PackedVector2Array()
		var gw := (7.0 + 5.0 * glow_k) * _u + 3.0
		for pt in sil:
			g.append(pt + (pt - ctr).normalized() * gw)
		draw_colored_polygon(g, Color(1.0, 0.85, 0.45, 0.55 * glow_k))
	var o := PackedVector2Array()
	for pt in sil:
		o.append(pt + (pt - ctr).normalized() * (3.5 * _u + 1.0))
	draw_colored_polygon(o, UiPalette.OUTLINE)
	# the dark mouth when lifted (seen at the rim)
	if lift > 0.05:
		_ellipse(b + Vector2(0, -ryb * 0.1), wb * 0.98, ryb * 0.9, Color("2a140a"))
	# body in strips: cylindrical shading (lit from upper left)
	var dark := COPPER.darkened(0.45)
	var light := COPPER.lightened(0.28)
	var n := 12
	for k in n:
		var t0 := PI - PI * k / n
		var t1 := PI - PI * (k + 1) / n
		var c0 := _shade(k, n, dark, light)
		var c1 := _shade(k + 1, n, dark, light)
		var pts := PackedVector2Array([Vector2(cx + cos(t0) * wb, b.y + sin(t0) * ryb), Vector2(cx + cos(t1) * wb, b.y + sin(t1) * ryb),
			Vector2(cx + cos(t1) * wt, top + sin(t1) * ryt), Vector2(cx + cos(t0) * wt, top + sin(t0) * ryt)])
		draw_polygon(pts, PackedColorArray([c0, c1, c1, c0]))
	# decorative band (gold) and the chunky bottom rim
	_band(cx, b.y, top, wb, wt, ryb, ryt, 0.5, 0.62, BAND.darkened(0.1), BAND.lightened(0.3))
	_band(cx, b.y, top, wb, wt, ryb, ryt, 0.0, 0.14, COPPER.darkened(0.3), COPPER.lightened(0.05))
	# gold studs on the band
	for k in 5:
		var t := PI - PI * (k + 0.5) / 5.0
		var f := 0.56
		var rr := lerpf(wb, wt, f)
		var ry := lerpf(ryb, ryt, f)
		var sp := Vector2(cx + cos(t) * rr, lerpf(b.y, top, f) + sin(t) * ry)
		var sa := sin(t)
		draw_circle(sp, (2.2 + 1.6 * sa) * _u + 0.5, Color("8a3f12", 0.5 + 0.5 * sa))
	# top cap + knob
	_ellipse(Vector2(cx, top), wt + 1.5, ryt + 1.5, UiPalette.OUTLINE)
	_ellipse(Vector2(cx, top), wt, ryt, COPPER.lightened(0.18))
	_ellipse(Vector2(cx - wt * 0.15, top - ryt * 0.15), wt * 0.6, ryt * 0.5, COPPER.lightened(0.35))
	var kr := wt * 0.34
	var kc := Vector2(cx, top - kr * 0.55)
	draw_circle(kc, kr + 3.0 * _u, UiPalette.OUTLINE)
	draw_circle(kc, kr, BAND.darkened(0.05))
	draw_circle(kc + Vector2(-kr * 0.3, -kr * 0.3), kr * 0.38, Color(1, 1, 1, 0.7))
	# specular stripe
	var sx0 := -0.62
	var spec := PackedVector2Array([Vector2(cx + wb * sx0, b.y - h * 0.18), Vector2(cx + wb * (sx0 + 0.13), b.y - h * 0.18),
		Vector2(cx + wt * (sx0 + 0.2), top + ryt * 0.9), Vector2(cx + wt * (sx0 + 0.02), top + ryt * 0.9)])
	draw_colored_polygon(spec, Color(1, 1, 1, 0.32))
	if glow_k > 0.5:
		_star4(Vector2(cx + wt * 0.8, top + h * 0.12), (6.0 + 5.0 * sin(time * 8.0)) * _u + 2.0, Color(1, 1, 0.85, glow_k))


func _shade(k: int, n: int, dark: Color, light: Color) -> Color:
	var u := float(k) / n
	var lit := clampf(1.0 - absf(u - 0.3) / 0.7, 0.0, 1.0)
	return dark.lerp(light, pow(lit, 1.2))


## A band around the cup between height fractions f0..f1 (front half, following the curve).
func _band(cx: float, by: float, top: float, wb: float, wt: float, ryb: float, ryt: float, f0: float, f1: float, dark: Color, light: Color) -> void:
	var r0 := lerpf(wb, wt, f0) * 1.02
	var r1 := lerpf(wb, wt, f1) * 1.02
	var y0 := lerpf(by, top, f0)
	var y1 := lerpf(by, top, f1)
	var e0 := lerpf(ryb, ryt, f0)
	var e1 := lerpf(ryb, ryt, f1)
	var n := 12
	for k in n:
		var t0 := PI - PI * k / n
		var t1 := PI - PI * (k + 1) / n
		var c0 := _shade(k, n, dark, light)
		var c1 := _shade(k + 1, n, dark, light)
		var pts := PackedVector2Array([Vector2(cx + cos(t0) * r0, y0 + sin(t0) * e0), Vector2(cx + cos(t1) * r0, y0 + sin(t1) * e0),
			Vector2(cx + cos(t1) * r1, y1 + sin(t1) * e1), Vector2(cx + cos(t0) * r1, y1 + sin(t0) * e1)])
		draw_polygon(pts, PackedColorArray([c0, c1, c1, c0]))
	var line := PackedVector2Array()
	for k in n + 1:
		var t := PI - PI * k / n
		line.append(Vector2(cx + cos(t) * r1, y1 + sin(t) * e1))
	draw_polyline(line, Color(UiPalette.OUTLINE, 0.7), 2.0 * _u, true)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 28:
		var t := TAU * k / 28.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	draw_colored_polygon(pts, col)


func _draw_gem_on_felt() -> void:
	var p := _gem_pos(_gem_slot)
	var k := clampf((time - _gem_t0) / 0.35, 0.0, 1.0)
	var pop := ease(k, 0.4) * (1.0 + 0.25 * sin(k * PI))
	var s := _gem_size() * pop * (1.12 if _gem_win else 1.0)
	var bob := sin(time * 3.0) * 3.0 * _u
	glow(p + Vector2(0, -s * 0.05), s * 1.1, Color(1.0, 0.55, 0.85, 0.75))
	_ellipse(Vector2(p.x, _gy), s * 0.4, s * 0.1, Color(0, 0, 0, 0.3))
	_gem(p + Vector2(0, -s * 0.12 + bob), s)
	for j in 3:
		var a := time * 2.2 + j * TAU / 3.0
		var tw := 0.5 + 0.5 * sin(time * 7.0 + j * 2.0)
		_star4(p + Vector2(cos(a) * s * 0.55, sin(a) * s * 0.3 - s * 0.2), (4.0 + 5.0 * tw) * _u + 1.0, Color(1, 1, 1, 0.8 * tw))


## The gem (KayKit Gem_Large rendered to an icon; a vector gem until it is ready).
func _gem(c: Vector2, s: float) -> void:
	var tex := ModelIcons.get_icon(ModelIcons.GEM, fmod(0.0, 360.0))
	if tex:
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		return
	var r := s * 0.34
	var pts := PackedVector2Array([c + Vector2(-r, -r * 0.3), c + Vector2(-r * 0.5, -r * 0.8), c + Vector2(r * 0.5, -r * 0.8),
		c + Vector2(r, -r * 0.3), c + Vector2(0, r)])
	var o := PackedVector2Array()
	for pt in pts:
		o.append(pt + (pt - c).normalized() * 3.0)
	draw_colored_polygon(o, UiPalette.OUTLINE)
	draw_colored_polygon(pts, GEM_TINT)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.8), c + Vector2(r * 0.5, -r * 0.8), c + Vector2(r * 0.2, -r * 0.3),
		c + Vector2(-r * 0.2, -r * 0.3)]), GEM_TINT.lightened(0.4))
	draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.2, -r * 0.3), c + Vector2(r, -r * 0.3), c + Vector2(0, r)]), GEM_TINT.darkened(0.25))

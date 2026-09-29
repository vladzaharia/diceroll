class_name WheelBoard
extends MgBoard
## Lucky Wheel: a carnival prize wheel of 12 segments (the public shuffled layout) under a
## flapper at the top. SPIN (the big button, or a tap anywhere on the board) sends ["spin"];
## the core answers with the spin curve (from, total, dur, window) and the wheel follows
## LuckyWheel.angle_at() on a REAL-time clock (never game speed: the brake is the skill).
## The brake window (the last `window` seconds) is telegraphed by a glowing arc painted on the
## wheel over the segments the pointer will pass in it, the bulbs turning red and the BRAKE
## button lighting up and pulsing. A tap before it only flashes TOO FAST!; a tap inside it
## sends ["stop", t] and the flapper catches the wheel right there; no tap = ["stop", -1] at
## the natural stop. The result (segment, value) always comes from the core's update: the
## winning wedge pops out, the prize flies into its spin slot.
##
## Drawing space: segment i spans wheel-local degrees [30i, 30i+30); a wheel-local angle phi
## sits at screen angle -90 - phi + A (degrees, y down) for the wheel angle A, so the local
## angle A is under the pointer and the wheel turns clockwise as A grows.

const SEG_COLS := [Color("ff4b5c"), Color("3aa0ff"), Color("ffc83a"), Color("a468ff"), Color("ff8a3d"), Color("34c77b")]
const JACKPOT := 12
const JACKPOT_COL := Color("2a1145")
const ICONS := {2: ["resources/Money_Coins_Stack_Small.gltf", 30.0], 3: ["resources/Money_Coins_Stack_Medium.gltf", 30.0],
	4: ["resources/Money_Coins_Stack_Large.gltf", 30.0], 5: ["resources/Gold_Bar.gltf", 35.0], 6: ["resources/Gold_Nugget_Large.gltf", 25.0],
	7: ["resources/Gold_Bars_Stack_Small.gltf", 30.0], 9: ["resources/Gem_Large.gltf", 25.0], 12: ["resources/Gems_Chest.gltf", 25.0]}
const WIND := 0.22            # anticipation pull-back before the curve starts (real seconds)
const BULBS := 28

var _mode := "idle"           # idle | spinning | braking | wait | result | over
var _spin: Dictionary = {}
var _t0_us := 0               # the spin clock's zero (Time.get_ticks_usec)
var _angle := 0.0             # the drawn wheel angle (degrees, unwrapped)
var _prev_angle := 0.0
var _speed := 0.0             # degrees / s (smoothed)
var _last_cnt := 0            # segment boundary counter (flapper ticks)
var _tick_cd := 0.0
var _flap := 0.0              # flapper deflection (radians)
var _flap_v := 0.0
var _brake_t := -1.0
var _brake_at := 0.0
var _brake_angle := 0.0
var _brake_amp := 0.0
var _window_on := false
var _win_seg := -1
var _win_t0 := 0.0
var _won: Array = []          # [{value, segment, nudged}]
var _fly: Dictionary = {}     # {value, from, to, t0, d, slot}
var _press := 0.0
var _hover := false
var _early_t := -9.0
var _slot_pop := [0.0, 0.0]

var _c := Vector2.ZERO        # wheel centre
var _R := 100.0               # wheel face radius
var _btn := Rect2()
var _slots: Array[Rect2] = [Rect2(), Rect2()]
var _off := Vector2.ZERO


func _init() -> void:
	super._init()
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


# --- pure helpers (tests) --------------------------------------------------------------

## Screen angle (radians, y down) of wheel-local degrees `local` at wheel angle `wheel`.
static func screen_angle(local: float, wheel: float) -> float:
	return deg_to_rad(-90.0 - local + wheel)


## What a tap t seconds into spin `sp` does: "early" (slips: TOO FAST), "brake", or "late".
static func tap_kind(t: float, sp: Dictionary) -> String:
	var d := float(sp.get("dur", 0.0))
	if t < d - float(sp.get("window", 0.0)):
		return "early"
	return "brake" if t <= d else "late"


## The KayKit model for a prize value (coins for small, gold mid, a gem, the gem chest).
static func icon_path(value: int) -> String:
	var best := 2
	for v: int in ICONS.keys():
		if v <= value and v > best:
			best = v
	return ModelIcons.K + String(ICONS[best][0])


static func seg_color(i: int, value: int) -> Color:
	return JACKPOT_COL if value >= JACKPOT else SEG_COLS[i % SEG_COLS.size()]


## Brake settle overshoot (degrees) that stays inside the caught segment.
static func settle_amp(angle: float, speed: float) -> float:
	var fwd := LuckyWheel.SEG_DEG - fposmod(angle, LuckyWheel.SEG_DEG)
	var back := fposmod(angle, LuckyWheel.SEG_DEG)
	return maxf(0.0, minf(clampf(speed * 0.03, 2.0, 7.0), minf(fwd - 0.8, (back - 0.8) / 0.45)))


# --- state -----------------------------------------------------------------------------

func set_state(st: Dictionary, instant := true) -> void:
	var sp_new: Dictionary = st.get("spin", {})
	if instant and _mode in ["spinning", "braking", "wait"] and not sp_new.is_empty() and _same_spin(sp_new):
		# a resync of the spin already running here: keep its clock
		state = st.duplicate(true)
		unlock()
		return
	super.set_state(st, instant)
	if instant:
		_won.clear()
		for r: Dictionary in state.get("results", []):
			_won.append({"value": int(r.value), "segment": int(r.segment), "nudged": bool(r.nudged)})
		_angle = float(state.get("angle", 0.0))
		_win_seg = -1
		_fly = {}
		var sp: Dictionary = state.get("spin", {})
		if String(state.get("phase", "spin")) == "spinning" and not sp.is_empty():
			# resumed mid-spin: the spin replays from its start (same curve, fresh clock)
			_begin_spin(sp)
		else:
			_mode = "idle" if _can_act() else "over"
		_last_cnt = floori(_angle / LuckyWheel.SEG_DEG)
	unlock()


func _same_spin(sp: Dictionary) -> bool:
	return not _spin.is_empty() and is_equal_approx(float(sp.get("from", -1)), float(_spin.from)) \
		and is_equal_approx(float(sp.get("total", -1)), float(_spin.total)) and is_equal_approx(float(sp.get("dur", -1)), float(_spin.dur))


func _can_act() -> bool:
	return int(state.get("actions_left", 0)) > 0 and not bool(state.get("done", false))


func is_settled() -> bool:
	return _mode in ["idle", "over"] and _fly.is_empty()


func status_text() -> String:
	var n := mini(_won.size() + (1 if _mode in ["spinning", "braking", "wait"] else 0), LuckyWheel.SPINS)
	if _mode == "spinning" and _window_on:
		return "BRAKE NOW!"
	return "Spin %d of %d" % [maxi(n, 1), LuckyWheel.SPINS]


## Seconds since the spin's curve started (real time; negative during the wind-up).
func spin_clock() -> float:
	return (Time.get_ticks_usec() - _t0_us) / 1000000.0


func _begin_spin(sp: Dictionary) -> void:
	_spin = {"from": float(sp.from), "total": float(sp.total), "dur": float(sp.dur), "window": float(sp.window)}
	_t0_us = Time.get_ticks_usec() + int(WIND * 1000000.0)
	_mode = "spinning"
	_brake_t = -1.0
	_window_on = false
	_angle = float(sp.from)
	_last_cnt = floori(_angle / LuckyWheel.SEG_DEG)


func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	_layout()
	var info: Dictionary = ev.get("info", {})
	var st: Dictionary = (ev.get("state", {}) as Dictionary).duplicate(true)
	if info.has("spin"):
		state = st
		_begin_spin(info)
		MgBoard.sfx("whirr")
		MgBoard.sfx("swoosh", 0.05, -3.0)
		burst(_c + Vector2(0, -_R), Color("fff3c0"), 14, "spark", 300.0, 40.0, 6.0)
		shake(3.0)
		unlock()
		return
	if not info.has("stop"):
		set_state(st, true)
		return
	var t := float(info.get("t", -1.0))
	var nudged := bool(info.get("nudged", false))
	# the stop came in while the wheel still runs here (not our tap): play on to the stop point
	if _mode == "spinning" and not _spin.is_empty():
		var until := t if nudged else float(_spin.dur)
		while is_inside_tree() and _mode == "spinning" and spin_clock() < until:
			await get_tree().process_frame
		if _mode == "spinning":
			if nudged:
				_do_brake(t)
			else:
				_angle = LuckyWheel.angle_at(_spin, float(_spin.dur))
				_mode = "wait"
	if _mode == "braking":
		while is_inside_tree() and time - _brake_at < 0.5:
			await get_tree().process_frame
	# settle exactly on the core's rest angle (no visible jump: same angle mod 360)
	var rest := float(info.get("angle", _angle))
	_angle = rest + 360.0 * roundf((_angle - rest) / 360.0)
	_mode = "result"
	await _reveal(int(info.get("segment", 0)), int(info.get("value", 0)), nudged, int(info.get("natural", -1)))
	state = st
	_spin = {}
	_mode = "idle" if _can_act() else "over"
	unlock()


## The result beat: the winning wedge pops, the prize flies into its spin slot.
func _reveal(seg: int, value: int, nudged: bool, natural: int) -> void:
	_win_seg = seg
	_win_t0 = time
	var top := _c + Vector2(0, -_R * 0.6)
	var col := seg_color(seg, value)
	var big := value >= 9
	MgBoard.sfx("reveal" if big else "coin")
	if value >= JACKPOT:
		MgBoard.sfx("fanfare")
		kick.emit(0.9, Color(1.0, 0.85, 0.3, 0.45))
		shake(9.0)
		for k in 5:
			burst(Vector2(size.x * (0.1 + 0.2 * k), -10.0), SEG_COLS[k % SEG_COLS.size()], 16, "flake", 260.0, -60.0, 11.0)
		burst(top, Color("ffe07a"), 30, "star", 380.0, 90.0, 12.0)
	elif big:
		MgBoard.sfx("win")
		kick.emit(0.5, Color(0.5, 0.9, 1.0, 0.35))
		shake(5.0)
		burst(top, Color("bff4ff"), 22, "star", 320.0, 70.0, 10.0)
	else:
		shake(2.5)
		burst(top, Color("ffe8a0"), 12, "star", 240.0, 60.0, 8.0)
	burst(top, col.lightened(0.3), 10, "chunk", 260.0, 180.0, 7.0)
	ring(top, Color(1, 1, 1, 0.9), _R * 0.5, 0.5, 7.0)
	float_text(top + Vector2(0, -_R * 0.15), "+%d" % value, Color("ffe07a") if value < 9 else Color("aef4ff"), int(_R * 0.3) + 10, 1.1)
	var segs: Array = state.get("segments", [])
	if nudged and natural >= 0 and natural < segs.size() and int(segs[natural]) < value:
		float_text(_c + Vector2(0, _R * 0.35), "NICE BRAKE!", Color("9dffb0"), int(_R * 0.14) + 10, 1.2)
	await wait(0.75)
	var slot := mini(_won.size(), 1)
	_fly = {"value": value, "from": top, "to": _slots[slot].get_center(), "t0": time, "d": dur(0.42), "slot": slot}
	MgBoard.sfx("swoosh", 0.05, -6.0)
	await wait(0.42)
	_fly = {}
	_won.append({"value": value, "segment": seg, "nudged": nudged})
	_slot_pop[slot] = 1.0
	MgBoard.sfx("clink")
	burst(_slots[slot].get_center(), Color("ffe07a"), 12, "star", 200.0, 40.0, 7.0)
	ring(_slots[slot].get_center(), Color("ffe07a"), _slots[slot].size.x * 0.5, 0.4, 5.0)
	await wait(0.3)
	_win_seg = -1


# --- input -------------------------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm:
		_hover = _btn.grow(8.0).has_point(mm.position)
		return
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		main_tap()


## The one button (anywhere on the board works too): SPIN when idle, BRAKE while spinning.
func main_tap() -> void:
	match _mode:
		"idle":
			if locked or not _can_act() or String(state.get("phase", "spin")) != "spin":
				return
			_press = 1.0
			MgBoard.sfx("click")
			send(["spin"])
		"spinning":
			var t := spin_clock()
			match tap_kind(t, _spin):
				"early":
					if time - _early_t > 0.25:
						_early_t = time
						_press = 0.6
						MgBoard.sfx("error", 0.05, -4.0)
						float_text(_btn.get_center() + Vector2(0, -_btn.size.y * 0.9), "TOO FAST!", Color("ffb0c0"), int(_R * 0.15) + 12, 0.7)
				"brake":
					if locked:
						return
					_press = 1.0
					send(["stop", snappedf(t, 0.001)])
					_do_brake(t)


## The flapper catches the wheel at t: a short settle around angle_at(t), inside the segment.
func _do_brake(t: float) -> void:
	var d := float(_spin.dur)
	var k := clampf(t / d, 0.0, 1.0)
	var spd := float(_spin.total) * 2.0 * (1.0 - k) / d
	_brake_t = t
	_brake_at = time
	_brake_angle = LuckyWheel.angle_at(_spin, t)
	_brake_amp = settle_amp(_brake_angle, spd)
	_mode = "braking"
	_flap_v -= 9.0
	MgBoard.sfx("block")
	MgBoard.sfx("wood", 0.05, -2.0)
	shake(5.0)
	ring(_pointer_tip(), Color("ff6a5a"), _R * 0.25, 0.35, 6.0)
	burst(_pointer_tip(), Color("ffd0a0"), 10, "spark", 220.0, 0.0, 6.0)
	kick.emit(0.3, Color(1.0, 0.4, 0.3, 0.3))


# --- per frame -----------------------------------------------------------------------------

func _tick(dt: float) -> void:
	_press = maxf(0.0, _press - dt * 5.0)
	for k in 2:
		_slot_pop[k] = maxf(0.0, _slot_pop[k] - dt * 3.0)
	_tick_cd -= dt
	match _mode:
		"spinning":
			var t := spin_clock()
			if t < 0.0:
				# wind-up: pull back, then let go
				_angle = float(_spin.from) - 7.0 * sin(PI * (t + WIND) / WIND)
			else:
				_angle = LuckyWheel.angle_at(_spin, t)
			var d := float(_spin.dur)
			if not _window_on and t >= d - float(_spin.window):
				_window_on = true
				MgBoard.sfx("bell", 0.02, -2.0)
				ring(_btn.get_center(), Color("ff5a5a"), _btn.size.x * 0.6, 0.5, 6.0)
			if t >= d and not locked:
				# no tap: the wheel coasted to its natural stop
				_angle = LuckyWheel.angle_at(_spin, d)
				_mode = "wait"
				_brake_at = time
				send(["stop", -1])
		"braking":
			var tau := time - _brake_at
			_angle = _brake_angle + _brake_amp * exp(-tau * 8.0) * sin(tau * 26.0)
			if tau > 2.0 and not locked:
				_brake_at = time
				send(["stop", snappedf(_brake_t, 0.001)])
		"wait":
			if time - _brake_at > 2.0 and not locked:
				_brake_at = time
				send(["stop", -1])
	# flapper ticks on every peg that passes
	var cnt := floori(_angle / LuckyWheel.SEG_DEG)
	if cnt != _last_cnt:
		var dir := signf(cnt - _last_cnt)
		_last_cnt = cnt
		_flap_v -= dir * clampf(3.0 + _speed * 0.004, 3.0, 7.0)
		if _tick_cd <= 0.0:
			_tick_cd = 0.035
			MgBoard.sfx("chip_tick", 0.08, -8.0 if _speed > 500.0 else -3.0)
	_flap_v += (-_flap * 420.0 - _flap_v * 16.0) * dt
	_flap = clampf(_flap + _flap_v * dt, -0.75, 0.75)
	if dt > 0.0:
		_speed = lerpf(_speed, absf(_angle - _prev_angle) / dt, clampf(dt * 12.0, 0.0, 1.0))
	_prev_angle = _angle


# --- harness -------------------------------------------------------------------------------

func scripted_input(args: Array, drv: Node) -> bool:
	if args.is_empty() or not is_inside_tree() or not String(args[0]) in ["spin", "stop"]:
		return false
	# fire and forget: the timed tap runs on its own (the harness polls for the command), so
	# this call never suspends the caller
	_scripted(args, drv)
	return true


func _scripted(args: Array, drv: Node) -> void:
	var o := get_global_rect().position
	if String(args[0]) == "spin":
		for i in 400:
			if _mode == "idle" and not locked:
				break
			await get_tree().process_frame
		_layout()
		drv.click(o + _btn.get_center())
		return
	var t := float(args[1]) if args.size() > 1 else -1.0
	if t < 0.0:
		return  # no tap: the board sends ["stop", -1] at the natural stop
	for i in 1200:
		if _mode != "spinning" or spin_clock() >= t:
			break
		await get_tree().process_frame
	_layout()
	drv.click(o + _btn.get_center())


# --- layout ----------------------------------------------------------------------------------

func _layout() -> void:
	var w := size.x
	var h := size.y
	var bw := clampf(w * 0.42, 130.0, 250.0)
	var bh := clampf(h * 0.13, 64.0, 92.0)
	var sw := clampf((w - bw) * 0.5 - 22.0, 60.0, 150.0)
	var sh := clampf(minf(sw, bh * 1.35), 60.0, 120.0)
	var strip := maxf(bh, sh) + 16.0
	var area := Vector2(w, h - strip)
	_R = maxf(40.0, minf(area.x / 2.34, area.y / 2.42))
	_c = Vector2(w * 0.5, area.y * 0.5 + _R * 0.06)
	var sy := h - strip * 0.5
	_btn = Rect2(Vector2(w * 0.5 - bw * 0.5, sy - bh * 0.5), Vector2(bw, bh))
	var gap := (w * 0.5 - bw * 0.5 - sw) * 0.5
	_slots[0] = Rect2(Vector2(gap, sy - sh * 0.5), Vector2(sw, sh))
	_slots[1] = Rect2(Vector2(w - gap - sw, sy - sh * 0.5), Vector2(sw, sh))


func _pointer_tip() -> Vector2:
	return _c + Vector2(0, -_R * 0.9)


# --- drawing ---------------------------------------------------------------------------------

func _draw_board() -> void:
	_layout()
	_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake if _shake > 0.0 else Vector2.ZERO
	var c := _c + _off
	var R := _R
	var game_col: Color = MgLogic.GAME_COLORS.get("lucky_wheel", Color("ff6a5a"))
	var spinning := _mode == "spinning"
	var in_window := spinning and _window_on
	# sunburst behind the wheel
	var rays := 16
	var rl := minf(R * 1.55, minf(size.x, size.y) * 0.5)
	for k in rays:
		var a0 := time * 0.15 + TAU * k / rays
		var pts := PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * rl,
			c + Vector2(cos(a0 + TAU / rays * 0.5), sin(a0 + TAU / rays * 0.5)) * rl])
		draw_colored_polygon(pts, Color(game_col.r, game_col.g, game_col.b, 0.08))
	# the stand: a post and a foot behind the wheel
	var foot_y := minf(_btn.position.y - 4.0, c.y + R * 1.5)
	if foot_y > c.y + R * 1.3:
		var post := PackedVector2Array([c + Vector2(-R * 0.1, 0), c + Vector2(R * 0.1, 0), Vector2(c.x + R * 0.2, foot_y), Vector2(c.x - R * 0.2, foot_y)])
		draw_colored_polygon(post, UiPalette.OUTLINE)
		draw_colored_polygon(PackedVector2Array([post[0] + Vector2(4, 0), post[1] - Vector2(4, 0), post[2] - Vector2(5, 3), post[3] + Vector2(5, -3)]), Color("8a2a3a"))
		rrect(Rect2(Vector2(c.x - R * 0.42, foot_y - R * 0.08), Vector2(R * 0.84, R * 0.14)), Color("6a1e30"), R * 0.06, 3, UiPalette.OUTLINE)
	# outer frame with the chasing bulbs
	draw_circle(c + Vector2(0, R * 0.06), R * 1.2, Color(0, 0, 0, 0.4))
	draw_circle(c, R * 1.17, UiPalette.OUTLINE)
	draw_circle(c, R * 1.14, Color("8a2a3a"))
	draw_arc(c, R * 1.1, PI * 1.1, PI * 1.9, 32, Color(1, 1, 1, 0.14), R * 0.05, true)
	draw_circle(c, R * 1.035, UiPalette.OUTLINE)
	draw_circle(c, R * 1.02, Color("ffc93d"))
	var br := maxf(3.0, R * 0.035)
	var chase := time * (16.0 if spinning else 7.0)
	for k in BULBS:
		var a := TAU * k / BULBS - PI * 0.5
		var p := c + Vector2(cos(a), sin(a)) * R * 1.09
		var on: bool
		var lit := Color("fff2a0")
		if in_window:
			on = int(time * 8.0) % 2 == k % 2
			lit = Color("ff6a5a")
		elif _win_seg >= 0:
			on = int(time * 10.0) % 2 == 0
		else:
			on = (int(chase) + k) % 4 < 2 if not spinning else (int(chase) + k) % 3 == 0
		draw_circle(p, br + 2.0, UiPalette.OUTLINE)
		draw_circle(p, br, lit if on else Color("b8704a"))
		if on:
			draw_circle(p, br * 2.2, Color(lit.r, lit.g, lit.b, 0.18))
			draw_circle(p - Vector2(br, br) * 0.3, br * 0.35, Color(1, 1, 1, 0.8))
	_draw_wheel(c, R)
	_draw_pointer(c, R)
	_draw_controls()
	if not _fly.is_empty():
		var k := clampf((time - float(_fly.t0)) / maxf(0.01, float(_fly.d)), 0.0, 1.0)
		var e := ease(k, -1.8)
		var from: Vector2 = _fly.from
		var to: Vector2 = _fly.to
		var p := from.lerp(to, e) + Vector2(0, -sin(k * PI) * R * 0.35)
		var s := lerpf(R * 0.5, _slots[int(_fly.slot)].size.y * 0.55, e)
		_icon(int(_fly.value), p, s, 1.0)
	draw_set_transform(Vector2.ZERO)


func _wedge(c: Vector2, r0: float, r1: float, a0: float, a1: float, steps := 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for s in steps + 1:
		var a := lerpf(a0, a1, float(s) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r1)
	if r0 <= 0.0:
		pts.append(c)
	else:
		for s in range(steps, -1, -1):
			var a := lerpf(a0, a1, float(s) / steps)
			pts.append(c + Vector2(cos(a), sin(a)) * r0)
	return pts


func _draw_wheel(c: Vector2, R: float) -> void:
	var segs: Array = state.get("segments", [])
	if segs.is_empty():
		return
	var n := segs.size()
	var sd := 360.0 / n
	var rot := deg_to_rad(_angle - 90.0)
	var xf := Transform2D(rot, c)
	draw_set_transform_matrix(xf)
	# wedges (drawing angle psi = -phi)
	for i in n:
		var v := int(segs[i])
		var col := seg_color(i, v)
		var a0 := deg_to_rad(-(i + 1) * sd)
		var a1 := deg_to_rad(-i * sd)
		draw_colored_polygon(_wedge(Vector2.ZERO, 0.0, R, a0, a1), col)
		draw_colored_polygon(_wedge(Vector2.ZERO, R * 0.84, R, a0, a1), col.lightened(0.18))
		draw_colored_polygon(_wedge(Vector2.ZERO, 0.0, R * 0.36, a0, a1, 4), col.darkened(0.22))
		if v >= JACKPOT:
			# the jackpot wedge: gold trims and a shimmer sweeping across
			draw_arc(Vector2.ZERO, R * 0.84, a0, a1, 12, Color("ffd24a"), R * 0.03, true)
			draw_arc(Vector2.ZERO, R * 0.96, a0, a1, 12, Color("ffd24a"), R * 0.02, true)
			var sh := fposmod(time * 0.6, 1.6) - 0.3
			if sh >= 0.0 and sh <= 1.0:
				var sa := lerpf(a0, a1, sh)
				draw_colored_polygon(_wedge(Vector2.ZERO, R * 0.4, R * 0.98, sa - 0.04, sa + 0.04, 2), Color(1, 0.95, 0.7, 0.35))
	# the brake window: the arc of wheel the pointer will cover in the last `window` seconds
	if _mode in ["spinning", "braking"] and not _spin.is_empty():
		var d := float(_spin.dur)
		var w0 := LuckyWheel.angle_at(_spin, d - float(_spin.window))
		var w1 := LuckyWheel.angle_at(_spin, d)
		var t := spin_clock()
		var near := clampf(1.0 - (d - float(_spin.window) - t) / 2.0, 0.25, 1.0) if _mode == "spinning" else 0.5
		var pulse := 0.5 + 0.5 * sin(time * (14.0 if _window_on else 6.0))
		var b0 := deg_to_rad(-w1)
		var b1 := deg_to_rad(-w0)
		var steps := maxi(6, int((w1 - w0) / 4.0))
		draw_colored_polygon(_wedge(Vector2.ZERO, R * 0.38, R * 0.98, b0, b1, steps), Color(1.0, 0.95, 0.75, (0.1 + 0.12 * pulse) * near))
		draw_arc(Vector2.ZERO, R * 0.995, b0, b1, steps * 2, Color(UiPalette.OUTLINE, near), R * 0.075, true)
		draw_arc(Vector2.ZERO, R * 0.995, b0, b1, steps * 2, Color(1.0, 0.35 + 0.4 * pulse, 0.3, near), R * 0.05, true)
	# dividers and pegs
	for i in n:
		var a := deg_to_rad(-i * sd)
		var dv := Vector2(cos(a), sin(a))
		draw_line(dv * R * 0.3, dv * R, UiPalette.OUTLINE, maxf(2.0, R * 0.022), true)
		draw_line(dv * R * 0.3, dv * R * 0.99, Color("ffe7a0"), maxf(1.0, R * 0.008), true)
	draw_arc(Vector2.ZERO, R, 0.0, TAU, 72, UiPalette.OUTLINE, maxf(3.0, R * 0.025), true)
	for i in n:
		var a := deg_to_rad(-i * sd)
		var pp := Vector2(cos(a), sin(a)) * R * 0.955
		draw_circle(pp, R * 0.032 + 1.5, UiPalette.OUTLINE)
		draw_circle(pp, R * 0.032, Color("e8ecf5"))
		draw_circle(pp - Vector2(1, 1) * R * 0.01, R * 0.012, Color.WHITE)
	# labels + prize icons (+ trailing ghosts at speed: motion blur)
	var ghosts := 0
	if _speed > 160.0:
		ghosts = 2
	var ghost_step := clampf(_speed * 0.006, 0.0, 9.0)
	for g in range(ghosts, -1, -1):
		var ga := deg_to_rad(-ghost_step * g)
		var alpha := 1.0 if g == 0 else 0.28 / g
		if g == 0 and _speed > 160.0:
			alpha = clampf(1.0 - (_speed - 160.0) / 900.0, 0.45, 1.0)
		for i in n:
			var v := int(segs[i])
			var mid := deg_to_rad(-(i + 0.5) * sd) + ga
			var dvec := Vector2(cos(mid), sin(mid))
			var lrot := mid + PI * 0.5
			draw_set_transform_matrix(xf * Transform2D(lrot, dvec * R * 0.76))
			var fs := int(R * 0.2)
			var tc := Color("ffd24a") if v >= JACKPOT else Color.WHITE
			text_c(Vector2.ZERO, str(v), fs, Color(tc, alpha), maxi(4, int(fs * 0.22)), true, Color(UiPalette.OUTLINE, alpha))
			draw_set_transform_matrix(xf * Transform2D(lrot, dvec * R * 0.5))
			_icon(v, Vector2.ZERO, R * (0.34 if v >= 9 else 0.3), alpha)
	draw_set_transform_matrix(xf)
	# the winning wedge pops out
	if _win_seg >= 0 and _win_seg < n:
		var k := time - _win_t0
		var pop := clampf(k / 0.18, 0.0, 1.0)
		var s := 1.0 + 0.1 * ease(pop, -2.0) + 0.02 * sin(time * 8.0)
		var mid := deg_to_rad(-(_win_seg + 0.5) * sd)
		var out := Vector2(cos(mid), sin(mid)) * R * 0.06 * pop
		var a0 := deg_to_rad(-(_win_seg + 1) * sd)
		var a1 := deg_to_rad(-_win_seg * sd)
		var v := int(segs[_win_seg])
		var col := seg_color(_win_seg, v)
		var wpts := _wedge(out, 0.0, R * s, a0, a1)
		draw_colored_polygon(_wedge(out, 0.0, R * s + 6.0, a0 - 0.02, a1 + 0.02), Color(1, 1, 1, 0.6 + 0.3 * sin(time * 12.0)))
		draw_colored_polygon(wpts, col.lightened(0.12))
		draw_polyline(wpts + PackedVector2Array([wpts[0]]), UiPalette.OUTLINE, 3.0, true)
		var dvec := Vector2(cos(mid), sin(mid))
		draw_set_transform_matrix(xf * Transform2D(mid + PI * 0.5, out + dvec * R * 0.76 * s))
		var fs := int(R * 0.24)
		text_c(Vector2.ZERO, str(v), fs, Color("ffd24a") if v >= JACKPOT else Color.WHITE, maxi(5, int(fs * 0.22)))
		draw_set_transform_matrix(xf * Transform2D(mid + PI * 0.5, out + dvec * R * 0.5 * s))
		_icon(v, Vector2.ZERO, R * 0.42, 1.0)
		draw_set_transform_matrix(xf)
	# speed lines
	if _speed > 180.0:
		var la := clampf((_speed - 180.0) / 800.0, 0.0, 0.4)
		for k in 9:
			var rr := R * (0.42 + 0.06 * k)
			var st := float(hash(k * 131) % 628) / 100.0
			var ln := clampf(_speed * 0.0012, 0.2, 1.1)
			draw_arc(Vector2.ZERO, rr, st - ln, st, 10, Color(1, 1, 1, la), 2.0 + (k % 3), true)
	# hub
	draw_circle(Vector2.ZERO, R * 0.2, UiPalette.OUTLINE)
	draw_circle(Vector2.ZERO, R * 0.18, Color("c9851f"))
	draw_circle(Vector2.ZERO, R * 0.155, Color("ffc93d"))
	for k in 8:
		var a := TAU * k / 8.0
		draw_circle(Vector2(cos(a), sin(a)) * R * 0.125, R * 0.016, Color("a8641a"))
	draw_circle(Vector2.ZERO, R * 0.085, Color("ff4b5c"))
	_star5(Vector2.ZERO, R * 0.07, Color("ffe9a0"))
	draw_set_transform(Vector2.ZERO)
	draw_circle(c + Vector2(-R * 0.06, -R * 0.07), R * 0.04, Color(1, 1, 1, 0.55))


func _star5(at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


## The flapper: hangs from a bolt above the rim, its tip between the pegs.
func _draw_pointer(c: Vector2, R: float) -> void:
	var piv := c + Vector2(0, -R * 1.16)
	var idle := 0.04 * sin(time * 2.2) if _mode == "idle" else 0.0
	draw_set_transform(piv, _flap + idle)
	var L := R * 0.3
	var W := R * 0.13
	var body := PackedVector2Array([Vector2(-W, 0), Vector2(W, 0), Vector2(W * 0.55, L * 0.55), Vector2(0, L), Vector2(-W * 0.55, L * 0.55)])
	draw_colored_polygon(PackedVector2Array([Vector2(-W - 3, -3), Vector2(W + 3, -3), Vector2(W * 0.55 + 3, L * 0.55 + 2),
		Vector2(0, L + 5), Vector2(-W * 0.55 - 3, L * 0.55 + 2)]), UiPalette.OUTLINE)
	draw_colored_polygon(body, Color("e8384f"))
	draw_colored_polygon(PackedVector2Array([Vector2(-W * 0.8, 2), Vector2(-W * 0.1, 2), Vector2(-W * 0.05, L * 0.8), Vector2(-W * 0.45, L * 0.5)]),
		Color(1, 1, 1, 0.25))
	draw_circle(Vector2.ZERO, W * 0.62, UiPalette.OUTLINE)
	draw_circle(Vector2.ZERO, W * 0.5, Color("ffc93d"))
	draw_circle(Vector2(-W * 0.15, -W * 0.15), W * 0.18, Color(1, 1, 1, 0.7))
	draw_set_transform(Vector2.ZERO)


func _draw_controls() -> void:
	var b := _btn
	var spinning := _mode == "spinning"
	var in_window := spinning and _window_on
	var idle_ready := _mode == "idle" and not locked and _can_act()
	var label := "SPIN!"
	var col := Color("4cc96a")
	var sub := ""
	if spinning:
		label = "BRAKE!" if in_window else "WAIT..."
		col = Color("ff3b4f") if in_window else Color("5a5872")
	elif _mode in ["braking", "wait", "result"]:
		label = "STOP!" if _mode != "result" else "WIN!"
		col = Color("ff8a3d") if _mode != "result" else Color("ffb000")
	elif _mode == "over":
		label = "DONE"
		col = UiPalette.DISABLED
	elif not idle_ready:
		col = UiPalette.DISABLED
	if _mode == "idle" and _won.size() == 1:
		sub = "LAST SPIN"
	var pulse := 0.0
	if in_window:
		pulse = 0.5 + 0.5 * sin(time * 16.0)
	elif idle_ready:
		pulse = 0.5 + 0.5 * sin(time * 4.0)
	var grow := 3.0 * pulse + (2.0 if _hover and (idle_ready or in_window) else 0.0)
	var r := b.grow(grow)
	var press := _press * 6.0
	if in_window:
		glow(r.get_center(), r.size.x * 0.75, Color(1.0, 0.3, 0.3, 0.5 + 0.4 * pulse))
	elif idle_ready:
		glow(r.get_center(), r.size.x * 0.7, Color(0.4, 1.0, 0.5, 0.25 + 0.2 * pulse))
	var rad := r.size.y * 0.3
	rrect(Rect2(r.position + Vector2(0, 8), r.size), Color(0, 0, 0, 0.4), rad)
	rrect(r.grow(3.0), UiPalette.OUTLINE, rad + 3)
	rrect(Rect2(r.position + Vector2(0, 7), r.size - Vector2(0, 7)), col.darkened(0.4), rad)
	var face := Rect2(r.position + Vector2(0, press), r.size - Vector2(0, 7))
	rrect(face, col.lightened(0.12 if _hover else 0.0), rad)
	rrect(Rect2(face.position + Vector2(face.size.x * 0.06, 4), Vector2(face.size.x * 0.88, face.size.y * 0.34)), Color(1, 1, 1, 0.22), rad * 0.7)
	# the timer bar: fills up to the window, then drains through it
	if spinning and not _spin.is_empty():
		var t := spin_clock()
		var d := float(_spin.dur)
		var wdw := float(_spin.window)
		var k := clampf(t / maxf(0.01, d - wdw), 0.0, 1.0) if not in_window else clampf((d - t) / wdw, 0.0, 1.0)
		var bar := Rect2(face.position + Vector2(face.size.x * 0.1, face.size.y - 14.0), Vector2(face.size.x * 0.8, 7.0))
		rrect(bar, Color(0, 0, 0, 0.35), 4)
		rrect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Color("ffe07a") if in_window else Color("c9c4e0"), 4)
	var fs := int(clampf(face.size.y * 0.42, 22.0, 40.0))
	text_c(face.get_center() + Vector2(0, -3 if sub == "" else -8), label, fs, Color.WHITE, maxi(5, fs / 5))
	if sub != "":
		text_c(face.get_center() + Vector2(0, fs * 0.55), sub, int(fs * 0.42), Color(1, 1, 1, 0.85), 4)
	# the two spin slots
	for k in 2:
		var s := _slots[k].grow(_slot_pop[k] * 6.0)
		var has := k < _won.size()
		var cur := k == _won.size() and _mode != "over"
		rrect(Rect2(s.position + Vector2(0, 5), s.size), Color(0, 0, 0, 0.35), 16)
		rrect(s, Color("2a1745") if not has else Color("3a1c55"), 16, 3, Color("ffc93d") if cur and _mode != "idle" else UiPalette.OUTLINE)
		var hs := int(clampf(s.size.y * 0.15, 12.0, 18.0))
		text_c(Vector2(s.get_center().x, s.position.y + hs * 0.9), "SPIN %d" % (k + 1), hs, Color(1, 1, 1, 0.6), 0, false)
		if has:
			var wv := int(_won[k].value)
			_icon(wv, s.get_center() + Vector2(-s.size.x * 0.17, s.size.y * 0.08), s.size.y * 0.52, 1.0)
			var vs := int(clampf(s.size.y * 0.3, 18.0, 36.0))
			text_c(s.get_center() + Vector2(s.size.x * 0.2, s.size.y * 0.08), "+%d" % wv, vs, Color("ffe07a") if wv < 9 else Color("aef4ff"), 5)
			if bool(_won[k].nudged):
				var tag := Rect2(Vector2(s.get_center().x - s.size.x * 0.3, s.end.y - hs * 0.9), Vector2(s.size.x * 0.6, hs * 1.3))
				rrect(tag, Color("ff3b4f"), hs * 0.6, 2, UiPalette.OUTLINE)
				text_c(tag.get_center(), "BRAKE", int(hs * 0.8), Color.WHITE, 0)
		else:
			text_c(s.get_center() + Vector2(0, s.size.y * 0.1), "?", int(s.size.y * 0.4), Color(1, 1, 1, 0.25 if not cur else 0.5 + 0.2 * sin(time * 4.0)), 0)


## A prize icon centred at c, size s (the 3D KayKit model, else a vector stand-in).
func _icon(value: int, c: Vector2, s: float, a: float) -> void:
	var best := 2
	for v: int in ICONS.keys():
		if v <= value and v > best:
			best = v
	var tex: Texture2D = ModelIcons.get_icon(icon_path(value), float(ICONS[best][1]))
	if tex:
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, a))
		return
	var o := Color(UiPalette.OUTLINE, a)
	if value >= JACKPOT:
		rrect(Rect2(c - Vector2(s * 0.34, s * 0.2), Vector2(s * 0.68, s * 0.44)), Color(Color("8a4a1c"), a), s * 0.06, 2, o)
		draw_rect(Rect2(c - Vector2(s * 0.34, s * 0.04), Vector2(s * 0.68, s * 0.06)), Color(Color("ffc93d"), a))
		draw_circle(c + Vector2(0, -s * 0.24), s * 0.1, Color(Color("6ff0ff"), a))
	elif value >= 9:
		var pts := PackedVector2Array([c + Vector2(0, -s * 0.34), c + Vector2(s * 0.3, -s * 0.06), c + Vector2(0, s * 0.34), c + Vector2(-s * 0.3, -s * 0.06)])
		draw_colored_polygon(pts, Color(Color("5fe3ff"), a))
		draw_polyline(pts + PackedVector2Array([pts[0]]), o, 2.0, true)
	elif value >= 5:
		rrect(Rect2(c - Vector2(s * 0.32, s * 0.14), Vector2(s * 0.64, s * 0.28)), Color(Color("ffc93d"), a), s * 0.05, 2, o)
	else:
		draw_circle(c, s * 0.28 + 2.0, o)
		draw_circle(c, s * 0.28, Color(Color("ffc93d"), a))
		draw_circle(c, s * 0.16, Color(Color("e0a020"), a))

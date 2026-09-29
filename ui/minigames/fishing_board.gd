class_name FishingBoard
extends MgBoard
## Fishing: a sunny pond seen from the end of a little pier. Three spots bubble on the water
## (SHALLOWS near the beach, REEDS by the cattails, DEEP out in the dark middle: bigger fish,
## a quicker bite). Tap one: the rod swings, the line arcs out, the bobber splashes down and
## settles; from that moment a REAL-time clock runs (never scaled by game speed). The core's
## public nibbles twitch the bobber; at bite_at it plunges under ("!", the rod bends) and
## stays under for the strike window: tap anywhere to strike (["hook", t], t = real seconds
## since the bobber settled). No tap: ["hook", -1] shortly after the window closes. What was
## on the line (hidden by the core until it is landed) comes only from the hook update: the
## fish flies out of the water into the catch tray, or the shadow darts off (TOO EARLY!) or
## swims away (GOT AWAY!).

const SPOT_AT := [Vector2(0.25, 0.64), Vector2(0.76, 0.43), Vector2(0.45, 0.26)]
const SPOT_NAMES := ["SHALLOWS", "REEDS", "DEEP"]
const SPOT_HINTS := ["small fry · up to 3", "up to 5", "big fish · up to 10!"]
const SPOT_COLS := [Color("8ff5d8"), Color("d8f070"), Color("ffd25a")]
## Water under each spot (the bobber's underwater silhouette / meniscus tint).
const SPOT_WATER := [Color("5ccbe0"), Color("46a9c4"), Color("1f5fa6")]
## Fish looks: length (of the tray-slot size), height ratio, colours.
const KINDS := {
	"minnow": {"name": "Minnow", "len": 0.58, "h": 0.34, "body": Color("a9d8cc"), "belly": Color("f0fbf4"), "fin": Color("70b2a6"), "mark": Color("4f8fb0")},
	"perch": {"name": "Perch", "len": 0.72, "h": 0.42, "body": Color("c9d450"), "belly": Color("fff2b4"), "fin": Color("ff8a3a"), "mark": Color("4c6a26")},
	"bass": {"name": "Bass", "len": 0.84, "h": 0.42, "body": Color("6fae4c"), "belly": Color("e9f2c2"), "fin": Color("4d7d3a"), "mark": Color("2f5a2a")},
	"pike": {"name": "Pike", "len": 1.0, "h": 0.26, "body": Color("7aa85a"), "belly": Color("f2f2c8"), "fin": Color("c9763a"), "mark": Color("e9f4a8")},
	"carp": {"name": "Carp", "len": 0.9, "h": 0.44, "body": Color("dc9c3c"), "belly": Color("ffe2a2"), "fin": Color("b86e2a"), "mark": Color("a8641f")},
	"catfish": {"name": "Catfish", "len": 0.98, "h": 0.32, "body": Color("7c8594"), "belly": Color("dcd6c8"), "fin": Color("596170"), "mark": Color("3e4450")},
	"koi": {"name": "Golden Koi", "len": 0.94, "h": 0.4, "body": Color("ffd23e"), "belly": Color("fff4b8"), "fin": Color("fff0c0"), "mark": Color("ff5a24")},
	"boot": {"name": "Old Boot", "len": 0.62, "h": 0.6, "body": Color("8a5a36"), "belly": Color("5e3a20"), "fin": Color("3a2414"), "mark": Color("d8c090")},
	"weed": {"name": "Pondweed", "len": 0.7, "h": 0.5, "body": Color("4fae4a"), "belly": Color("86d86a"), "fin": Color("2f7a34"), "mark": Color("c8f08a")},
}
const BARREL := ModelIcons.K + "resources/Food_Barrel_Fish.gltf"
const TACKLE := ModelIcons.K + "tools_x/fishing_tacklebox.gltf"
## Seconds after the window closes before an untouched bite counts as got-away.
const MISS_GRACE := 0.3

var _s := Rect2()               # the scene (pond) rect
var _u := 1.0
var _geo_key := Vector2.ZERO
var _pond := PackedVector2Array()
var _sand := PackedVector2Array()
var _wet := PackedVector2Array()
var _ripple_pts: Array = []     # [Vector2, phase]
var _caustic_pts: Array = []

var _mode := "aim"              # aim | cast | wait | reel | idle
var _hover := -1
var _spot := -1
var _bite_at := 0.0
var _window := 0.0
var _nibbles: Array = []
var _t0_us := 0
var _nib_done := 0
var _nib_t := -9.0              # real time (board clock) of the last nibble
var _bitten := false
var _bite_t := -9.0             # board time of the plunge
var _struck := false
var _strike_t := -9.0
var _surfaced := false          # the window ran out: the bobber popped back up

# rod / line / bobber
var _aim := 0.0                 # smoothed rod angle offset toward the target
var _swing := 0.0               # cast swing (radians, + = back)
var _bend := 0.0                # 0..1 the rod bows toward the bobber
var _bob := "hang"              # hang | fly | float | back
var _fly_k := 0.0
var _fly_from := Vector2.ZERO
var _fly_to := Vector2.ZERO
var _settle := 0.0              # 1 right at splash-down, 0 settled (bounce)
var _slack := 1.0
var _ripples: Array = []        # {p, t0, life, r, col, w}

# the fish shadow and the catch
var _shadow_a := 0.0            # 0..1 visibility
var _shadow_ang := 0.0
var _shadow_dart := {}          # {t0, dir, far, life}
var _flying := {}               # {kind, from, to, t0, d, points, perfect}
var _tray: Array = []           # catches shown in the tray
var _pop_slot := -1
var _pop_t := -9.0


# --- state -----------------------------------------------------------------------------

func set_state(st: Dictionary, instant := true) -> void:
	super.set_state(st, instant)
	if instant:
		_tray = (state.get("catches", []) as Array).duplicate(true)
		_flying = {}
		_shadow_dart = {}
		_swing = 0.0
		_bend = 0.0
		if String(state.get("phase", "cast")) == "bite" and not _over():
			# a restored bite: the bobber is back on the water and the clock starts again
			_begin_wait(int(state.get("spot", 0)), float(state.get("bite_at", 1.5)), float(state.get("window", 0.6)),
				state.get("nibbles", []))
			_fly_to = _spot_pos(_spot)
			_bob = "float"
			_settle = 0.0
		else:
			_mode = "idle" if _over() else "aim"
			_bob = "hang"
			_spot = -1
	unlock()


func _over() -> bool:
	return bool(state.get("done", false)) or int(state.get("actions_left", 0)) <= 0


func is_settled() -> bool:
	return _mode in ["aim", "idle"] and _flying.is_empty()


func status_text() -> String:
	if _mode == "wait":
		return "STRIKE ON THE PLUNGE!" if _bitten and not _surfaced else "WATCH THE BOBBER..."
	var n := (state.get("catches", []) as Array).size()
	if _over() or n >= Fishing.CASTS:
		return ""
	return "CAST %d OF %d" % [n + 1, Fishing.CASTS]


## Real seconds since the bobber settled (the skill clock; never game-speed scaled).
func clock() -> float:
	return float(Time.get_ticks_usec() - _t0_us) / 1000000.0


func _begin_wait(s: int, bite_at: float, window: float, nibbles: Array) -> void:
	_spot = s
	_bite_at = bite_at
	_window = window
	_nibbles = nibbles.duplicate()
	_nib_done = 0
	_nib_t = -9.0
	_bitten = false
	_bite_t = -9.0
	_struck = false
	_surfaced = false
	_slack = 1.0
	_shadow_a = 0.0
	_shadow_dart = {}
	_t0_us = Time.get_ticks_usec()
	_mode = "wait"


# --- layout ----------------------------------------------------------------------------

func _layout() -> void:
	var avail := size - Vector2(8, 8)
	var w := maxf(avail.x, 60.0)
	var h := maxf(avail.y, 60.0)
	var asp := clampf(w / h, 0.78, 1.32)
	if w / h > asp:
		w = h * asp
	else:
		h = w / asp
	_s = Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))
	_u = minf(w, h) / 520.0
	if _geo_key != _s.size:
		_geo_key = _s.size
		_build_geo()


func P(fx: float, fy: float) -> Vector2:
	return _s.position + _s.size * Vector2(fx, fy)


func _spot_pos(i: int) -> Vector2:
	var f: Vector2 = SPOT_AT[clampi(i, 0, 2)]
	return P(f.x, f.y)


func _ell(c: Vector2, rx: float, ry: float, n := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _build_geo() -> void:
	_pond = PackedVector2Array()
	_sand = PackedVector2Array()
	_wet = PackedVector2Array()
	var c := P(0.5, 0.49)
	var rx := _s.size.x * 0.47
	var ry := _s.size.y * 0.385
	for i in 56:
		var a := TAU * i / 56.0
		var wob := 1.0 + 0.045 * sin(a * 3.0 + 0.6) + 0.03 * sin(a * 5.0 + 2.1) + 0.02 * sin(a * 9.0)
		var d := Vector2(cos(a) * rx, sin(a) * ry) * wob
		_pond.append(c + d)
		_wet.append(c + d * 1.025 + Vector2(0, 3))
		_sand.append(c + d * 1.075 + Vector2(0, 5))
	_ripple_pts.clear()
	for k in 46:
		var p := P(0.08 + 0.84 * float(hash(k * 131 + 7) % 1000) / 1000.0, 0.14 + 0.72 * float(hash(k * 71 + 3) % 1000) / 1000.0)
		if Geometry2D.is_point_in_polygon(p, _pond):
			_ripple_pts.append([p, float(hash(k * 13) % 628) / 100.0])
	_caustic_pts.clear()
	for k in 26:
		var p := P(0.08 + 0.4 * float(hash(k * 37 + 1) % 1000) / 1000.0, 0.56 + 0.3 * float(hash(k * 53 + 9) % 1000) / 1000.0)
		if Geometry2D.is_point_in_polygon(p, _pond):
			_caustic_pts.append([p, float(hash(k * 17) % 628) / 100.0])


# --- rod -------------------------------------------------------------------------------

func _butt() -> Vector2:
	return P(0.815, 0.985)


func _rod_len() -> float:
	return minf(_s.size.x, _s.size.y) * 0.44


## The rod's points butt -> tip (bent toward the bobber by _bend).
func _rod_pts() -> PackedVector2Array:
	var b := _butt()
	var base := (P(0.62, 0.62) - b).angle()
	var ang := base + _aim + _swing
	var dir := Vector2.from_angle(ang)
	var L := _rod_len() * (1.0 - 0.1 * absf(_swing))
	var pull := Vector2.ZERO
	if _bend > 0.0 and _bob == "float":
		pull = (_fly_to - (b + dir * L)).normalized() * _bend * L * 0.2
	var pts := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		pts.append(b + dir * L * k + pull * k * k)
	return pts


func _tip() -> Vector2:
	var p := _rod_pts()
	return p[p.size() - 1]


func _aim_target() -> float:
	var target := -1
	if _mode == "aim" and _hover >= 0:
		target = _hover
	elif _mode in ["cast", "wait", "reel"] and _spot >= 0:
		target = _spot
	if target < 0:
		return 0.0
	var b := _butt()
	var base := (P(0.62, 0.62) - b).angle()
	return clampf(wrapf((_spot_pos(target) - b).angle() - base, -PI, PI) * 0.55, -0.5, 0.5)


# --- input -----------------------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm:
		_hover = _spot_at(mm.position) if _mode == "aim" else -1
		return
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _mode == "aim":
		var s := _spot_at(mb.position)
		if s >= 0:
			cast_to(s)
	elif _mode == "wait":
		strike()


## The spot under p (generous, thumb-sized), or -1.
func _spot_at(p: Vector2) -> int:
	_layout()
	var best := -1
	var bd := maxf(minf(_s.size.x, _s.size.y) * 0.17, 48.0)
	for i in 3:
		var d := p.distance_to(_spot_pos(i) + Vector2(0, 10.0 * _u))
		if d < bd:
			bd = d
			best = i
	return best


func cast_to(s: int) -> void:
	if locked or _mode != "aim" or _over():
		return
	_hover = s
	MgBoard.sfx("click")
	send(["cast", s])


func strike() -> void:
	if locked or _mode != "wait" or _struck:
		return
	_struck = true
	_strike_t = time
	var t := snappedf(clock(), 0.001)
	MgBoard.sfx("reel")
	var tw := create_tween()
	tw.tween_property(self, "_swing", 0.32, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	send(["hook", t])


## Harness input (scenarios): tap the spot, or strike ~0.15 s after the real plunge. The waiting
## runs in a detached coroutine and this returns at once: awaiting a suspended coroutine from the
## harness's match branch corrupts its command-count check (a GDScript VM quirk), and the harness
## polls for the command anyway.
func scripted_input(args: Array, drv: Node) -> bool:
	if args.size() < 2 or not (String(args[0]) in ["cast", "hook"]):
		return false
	_script_tap(String(args[0]), int(args[1]) if String(args[0]) == "cast" else -1, drv)
	return true


func _script_tap(kind: String, s: int, drv: Node) -> void:
	var t_end := Time.get_ticks_msec() + 7000
	if kind == "cast":
		while (_mode != "aim" or locked) and Time.get_ticks_msec() < t_end:
			await get_tree().process_frame
		_layout()
		drv.call("click", get_global_rect().position + _spot_pos(s) + Vector2(0, 10.0 * _u))
		return
	while _mode != "wait" and Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
	while clock() < _bite_at + 0.15 and Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
	drv.call("click", get_global_rect().position + size * Vector2(0.5, 0.55))


# --- per frame -------------------------------------------------------------------------

func _tick(dt: float) -> void:
	_layout()
	_aim = lerpf(_aim, _aim_target(), 1.0 - exp(-dt * 6.0))
	for i in range(_ripples.size() - 1, -1, -1):
		if time - float(_ripples[i].t0) > float(_ripples[i].life):
			_ripples.remove_at(i)
	if _mode != "wait":
		return
	var t := clock()
	var bp := _spot_pos(_spot)
	_shadow_a = minf(1.0, _shadow_a + dt * 0.8)
	_shadow_ang += dt * (0.9 + (1.5 if t > _bite_at - 0.8 else 0.0))
	while _nib_done < _nibbles.size() and t >= float(_nibbles[_nib_done]):
		_nib_done += 1
		if not _struck:
			_nibble(bp)
	if not _bitten and t >= _bite_at and not _struck:
		_plunge(bp)
	if _bitten and not _struck and not _surfaced and t > _bite_at + _window:
		_surfaced = true
		MgBoard.sfx("plink", 0.05, -6.0)
		_ripple(bp, 34.0, Color(1, 1, 1, 0.6), 0.6)
	if _bitten and not _struck and t > _bite_at + _window + MISS_GRACE and not locked:
		_struck = true
		send(["hook", -1])


func _nibble(bp: Vector2) -> void:
	_nib_t = time
	MgBoard.sfx("question" if _nib_done % 2 == 1 else "tin", 0.1, -4.0)
	_ripple(bp, 26.0, Color(1, 1, 1, 0.55), 0.55)
	burst(bp, Color("d8f6ff"), 4, "spark", 60.0, 30.0, 4.0 * _u + 1.0)


func _plunge(bp: Vector2) -> void:
	_bitten = true
	_bite_t = time
	_slack = 0.0
	MgBoard.sfx("splash", 0.05, 2.0)
	MgBoard.sfx("pop", 0.05, -2.0)
	_ripple(bp, 60.0, Color(1, 1, 1, 0.85), 0.7, 5.0)
	_ripple(bp, 36.0, Color(1, 1, 1, 0.6), 0.5)
	burst(bp, Color("e6fbff"), 16, "chunk", 260.0, 220.0, 7.0 * _u + 2.0)
	shake(4.0)
	var tw := create_tween()
	tw.tween_property(self, "_bend", 1.0, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ripple(p: Vector2, r: float, col: Color, life: float, w := 3.0) -> void:
	_ripples.append({"p": p, "t0": time, "life": life, "r": r * _u + 6.0, "col": col, "w": w})


# --- updates ---------------------------------------------------------------------------

func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	_layout()
	var info: Dictionary = ev.get("info", {})
	var st: Dictionary = ev.get("state", {})
	if info.has("cast"):
		await _play_cast(info, st)
	elif info.has("hook"):
		await _play_hook(info, st)
	else:
		set_state(st, true)
		return
	unlock()


func _play_cast(info: Dictionary, st: Dictionary) -> void:
	state = st.duplicate(true)
	_spot = int(info.get("spot", 0))
	_mode = "cast"
	_hover = -1
	var target := _spot_pos(_spot)
	# wind up, whip forward
	MgBoard.sfx("swing", 0.08)
	var tw := create_tween()
	tw.tween_property(self, "_swing", 0.75, dur(0.22)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	MgBoard.sfx("swoosh", 0.08)
	tw = create_tween()
	tw.tween_property(self, "_swing", -0.18, dur(0.14)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	_fly_from = _tip() + Vector2(0, 20.0 * _u)
	_fly_to = target
	_bob = "fly"
	_fly_k = 0.0
	tw = create_tween().set_parallel(true)
	tw.tween_property(self, "_fly_k", 1.0, dur(0.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(self, "_swing", 0.0, dur(0.45)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	# splash-down, a little bounce, settle: the clock starts
	_bob = "float"
	MgBoard.sfx("plink", 0.08)
	MgBoard.sfx("splash", 0.1, -8.0)
	_ripple(target, 40.0, Color(1, 1, 1, 0.8), 0.6, 4.0)
	burst(target, Color("e6fbff"), 9, "chunk", 150.0, 150.0, 5.0 * _u + 2.0)
	_settle = 1.0
	tw = create_tween()
	tw.tween_property(self, "_settle", 0.0, dur(0.42)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	_begin_wait(_spot, float(info.get("bite_at", 1.5)), float(info.get("window", 0.6)), info.get("nibbles", []))


func _play_hook(info: Dictionary, st: Dictionary) -> void:
	_mode = "reel"
	_struck = true
	var result := String(info.get("result", "missed"))
	var bp := _spot_pos(_spot)
	var slot := (state.get("catches", []) as Array).size()
	match result:
		"caught":
			var kind := String(info.get("kind", ""))
			var pts := int(info.get("points", 0))
			var perfect := bool(info.get("perfect", false))
			MgBoard.sfx("splash", 0.05, 3.0)
			_ripple(bp, 70.0, Color(1, 1, 1, 0.9), 0.7, 6.0)
			burst(bp, Color("e6fbff"), 22, "chunk", 320.0, 300.0, 7.0 * _u + 2.0)
			shake(5.0)
			_shadow_a = 0.0
			_bob = "hang"
			_bend = 0.0
			_slack = 1.0
			var junk := kind in ["boot", "weed"]
			var d := 0.85
			_flying = {"kind": kind, "from": bp, "to": _slot_pos(slot), "t0": time, "d": dur(d)}
			await wait(d * 0.45)
			var kc: Color = (KINDS.get(kind, KINDS.minnow) as Dictionary).body
			var nm := String((KINDS.get(kind, {}) as Dictionary).get("name", kind)).to_upper()
			float_text(P(0.5, 0.22), (nm + "..." if junk else nm + "!"), kc.lightened(0.3) if not junk else Color("d8c8a8"), int(34 * _u + 14), 1.1)
			if perfect:
				await wait(0.12)
				float_text(bp + Vector2(0, -30.0 * _u), "PERFECT!", Color("ffe07a"), int(30 * _u + 12), 1.0)
				MgBoard.sfx("crit", 0.05, -4.0)
				burst(bp, Color("ffe07a"), 14, "star", 260.0, 60.0, 9.0 * _u + 2.0)
			await wait(maxf(0.0, d * 0.55 - (0.12 if perfect else 0.0)))
			# lands in the tray
			var sp := _slot_pos(slot)
			_flying = {}
			var c2 := state.get("catches", []) as Array
			_tray = c2.duplicate(true)
			_tray.append({"spot": _spot, "result": "caught", "kind": kind, "points": pts, "perfect": perfect})
			_pop_slot = slot
			_pop_t = time
			if kind == "boot":
				MgBoard.sfx("bong", 0.05)
			elif kind == "weed":
				MgBoard.sfx("pluck", 0.1)
				MgBoard.sfx("question", 0.1, -4.0)
			elif kind == "koi":
				MgBoard.sfx("fanfare")
			elif pts >= 6:
				MgBoard.sfx("reveal")
			else:
				MgBoard.sfx("coin")
			var gold := kind == "koi"
			burst(sp, kc.lightened(0.2) if not junk else Color("a08060"), 10 + (18 if gold else 0), "star" if not junk else "chunk", 220.0, 80.0, 8.0 * _u + 2.0)
			ring(sp, kc.lightened(0.4), 50.0 * _u + 10.0, 0.45, 5.0)
			float_text(sp + Vector2(0, -24.0 * _u), "+%d" % pts, Color("ffe07a") if not junk else UiPalette.TEXT_DIM, int(30 * _u + 12), 1.0)
			kick.emit(0.9 if gold else (0.45 if pts >= 6 else 0.2), Color(kc.r, kc.g, kc.b, 0.4))
			await wait(0.45)
		"spooked":
			MgBoard.sfx("error")
			MgBoard.sfx("swoosh", 0.1, -3.0)
			_shadow_dart = {"t0": time, "dir": Vector2.from_angle(_shadow_ang + PI * 0.5).normalized()}
			_ripple(bp, 44.0, Color(1, 1, 1, 0.7), 0.5)
			burst(bp, Color("e6fbff"), 8, "chunk", 160.0, 120.0, 5.0 * _u + 2.0)
			float_text(bp + Vector2(0, -34.0 * _u), "TOO EARLY!", Color("ffab5a"), int(30 * _u + 12), 1.1)
			await wait(0.75)
			_tray = (st.get("catches", []) as Array).duplicate(true)
			_pop_slot = slot
			_pop_t = time
		_:
			MgBoard.sfx("swoosh", 0.1)
			MgBoard.sfx("error", 0.05, -4.0)
			_shadow_dart = {"t0": time, "dir": (P(0.5, 0.05) - bp).normalized().rotated(0.7), "slow": true}
			_ripple(bp, 34.0, Color(1, 1, 1, 0.6), 0.6)
			float_text(bp + Vector2(0, -34.0 * _u), "GOT AWAY!", Color("ff8a9a"), int(30 * _u + 12), 1.1)
			await wait(0.75)
			_tray = (st.get("catches", []) as Array).duplicate(true)
			_pop_slot = slot
			_pop_t = time
	# reel the bobber home
	if _bob == "float":
		_fly_from = bp
		_bob = "back"
		_fly_k = 0.0
		_bend = 0.0
		MgBoard.sfx("reel", 0.05, -6.0)
		var tw := create_tween()
		tw.tween_property(self, "_fly_k", 1.0, dur(0.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tw.finished
	_bob = "hang"
	var tw2 := create_tween()
	tw2.tween_property(self, "_swing", 0.0, dur(0.2))
	await tw2.finished
	state = st.duplicate(true)
	_tray = (state.get("catches", []) as Array).duplicate(true)
	_shadow_dart = {}
	_shadow_a = 0.0
	_spot = -1
	_mode = "idle" if _over() else "aim"


# --- drawing ---------------------------------------------------------------------------

func _draw_board() -> void:
	_layout()
	var s := _s
	var u := _u
	var rad := 30.0 * u + 6.0
	# frame + grass
	rrect(Rect2(s.position + Vector2(0, 10), s.size), Color(0, 0, 0, 0.4), rad + 4)
	rrect(s.grow(4.0), UiPalette.OUTLINE, rad + 4)
	rrect(s, Color("5fb548"), rad)
	# grass texture: soft lighter tufts
	for k in 34:
		var gp := P(0.04 + 0.92 * float(hash(k * 19 + 2) % 1000) / 1000.0, 0.03 + 0.94 * float(hash(k * 43 + 5) % 1000) / 1000.0)
		if Geometry2D.is_point_in_polygon(gp, _sand):
			continue
		for j in 3:
			var a := -PI * 0.5 + (j - 1) * 0.45
			draw_line(gp, gp + Vector2.from_angle(a) * (7.0 * u + 2.0), Color("7fd05a"), 2.5 * u + 0.5, true)
	_draw_far_bank()
	_draw_pond()
	_draw_reeds(false)
	_draw_lilies()
	_draw_spots()
	_draw_shadow()
	_draw_line_and_bobber()
	_draw_reeds(true)
	_draw_pier()
	_draw_tray()
	_draw_rod()
	_draw_flying()
	_draw_dragonfly()
	_draw_prompt()
	# frame rim on top (tidies the edges)
	rrect(s, Color(0, 0, 0, 0), rad, int(3.0 * u + 2.0), Color("2c6a2a"))


func _draw_far_bank() -> void:
	var u := _u
	# a row of round trees and bushes along the top
	for k in 9:
		var x := 0.1 + 0.8 * k / 8.0 + 0.03 * sin(k * 2.7)
		var r := (26.0 + 10.0 * float(hash(k * 7) % 100) / 100.0) * u + 6.0
		var c := P(x, 0.05) + Vector2(0, 4.0 * u * sin(k * 1.3))
		draw_circle(c + Vector2(0, 5.0 * u), r + 3.0, UiPalette.OUTLINE)
		draw_circle(c, r, Color("2f7d3a"))
		draw_circle(c + Vector2(-r * 0.25, -r * 0.3), r * 0.55, Color("3f9a44"))
		draw_circle(c + Vector2(-r * 0.35, -r * 0.42), r * 0.22, Color(1, 1, 1, 0.12))
	for k in 12:
		var x := 0.06 + 0.88 * k / 11.0
		var c := P(x, 0.1 + 0.012 * sin(k * 3.1))
		var r := 14.0 * u + 4.0
		draw_circle(c, r + 2.5, UiPalette.OUTLINE)
		draw_circle(c, r, Color("4fae46"))
		draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.4, Color("72c95a"))
	# flowers on the bank
	for k in 10:
		var fp := P(0.08 + 0.84 * float(hash(k * 29 + 11) % 1000) / 1000.0, 0.115 + 0.02 * float(hash(k * 3) % 100) / 100.0)
		var fc: Color = [Color("ffffff"), Color("ffd84a"), Color("ff8ab0")][k % 3]
		var fr := 3.5 * u + 1.5
		for j in 5:
			draw_circle(fp + Vector2.from_angle(TAU * j / 5.0 + k) * fr, fr * 0.8, fc)
		draw_circle(fp, fr * 0.7, Color("ffb020"))


func _draw_pond() -> void:
	var u := _u
	draw_colored_polygon(_sand, Color("ead8a0"))
	draw_polyline(_sand + PackedVector2Array([_sand[0]]), Color("c8b278"), 2.0 * u + 1.0, true)
	draw_colored_polygon(_wet, Color("c7b07a"))
	draw_colored_polygon(_pond, Color("3aa3d8"))
	# depth: light shallows by the beach, a green-tinted reed bay, a dark deep hole
	# depth: light shallows by the beach, a green-tinted reed bay, a dark deep hole (soft steps)
	var base := Color("3aa3d8")
	var layers := [[Vector2(0.24, 0.73), Vector2(0.3, 0.2), Color("74dbe6"), 4], [Vector2(0.8, 0.45), Vector2(0.19, 0.2), Color("3f9fb0"), 3],
		[Vector2(0.46, 0.27), Vector2(0.34, 0.21), Color("1a4f96"), 5]]
	for l: Array in layers:
		var f: Vector2 = l[0]
		var r: Vector2 = l[1]
		var n: int = l[3]
		for j in n:
			var k := float(j + 1) / n
			var sc := 1.0 - 0.8 * float(j) / n
			clipped(_ell(P(f.x, f.y), r.x * _s.size.x * sc, r.y * _s.size.y * sc, 32), _pond, base.lerp(l[2], k))
	# caustics in the shallows: shimmering light cells
	for cp: Array in _caustic_pts:
		var p: Vector2 = cp[0]
		var ph: float = cp[1]
		var a := 0.1 + 0.1 * sin(time * 1.6 + ph)
		var r := (9.0 + 3.0 * sin(time * 1.1 + ph * 2.0)) * u + 3.0
		var pts := PackedVector2Array()
		for i in 7:
			var ang := TAU * i / 6.0 + ph + time * 0.2
			pts.append(p + Vector2(cos(ang) * r, sin(ang) * r * 0.6))
		draw_polyline(pts, Color(1, 1, 1, a), 2.0 * u + 0.5, true)
	# sky glints + drifting ripple ticks
	for rp: Array in _ripple_pts:
		var p: Vector2 = rp[0]
		var ph: float = rp[1]
		var drift := Vector2(fmod(time * 6.0 + ph * 10.0, 24.0) - 12.0, 0) * u
		var a := 0.28 * (0.5 + 0.5 * sin(time * 1.3 + ph))
		var w := (13.0 + 4.0 * sin(ph)) * u + 3.0
		draw_arc(p + drift, w, PI * 0.2, PI * 0.8, 8, Color(1, 1, 1, a), 2.0 * u + 0.5, true)
	# long reflections of the sky
	for k in 3:
		var y := 0.34 + 0.16 * k
		var x0 := 0.2 + 0.12 * sin(time * 0.3 + k * 2.0) + 0.08 * k
		clipped(PackedVector2Array([P(x0, y), P(x0 + 0.22, y - 0.004), P(x0 + 0.22, y + 0.006), P(x0, y + 0.01)]), _pond, Color(1, 1, 1, 0.1))
	# shore foam
	var foam := PackedVector2Array(_pond)
	foam.append(_pond[0])
	draw_polyline(foam, Color(1, 1, 1, 0.35 + 0.1 * sin(time * 2.0)), 3.0 * u + 1.0, true)
	# a few shore stones
	for k in 7:
		var i := (k * 8 + 3) % _pond.size()
		var p := _pond[i].lerp(_sand[i], 0.5)
		var r := (7.0 + 3.0 * (k % 3)) * u + 2.0
		draw_circle(p, r + 2.0, UiPalette.OUTLINE)
		draw_circle(p, r, Color("a8a4a0"))
		draw_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.4, Color("d0ccc4"))
	# live ripples
	for r: Dictionary in _ripples:
		var k := clampf((time - float(r.t0)) / float(r.life), 0.0, 1.0)
		var col: Color = r.col
		col.a *= 1.0 - k
		var rr: float = float(r.r) * (0.3 + 0.9 * ease(k, 0.5))
		draw_set_transform(r.p, 0.0, Vector2(1.0, 0.42))
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 32, col, float(r.w) * (1.0 - 0.5 * k) * _u + 1.0, true)
		draw_set_transform(Vector2.ZERO)


func _draw_reeds(front: bool) -> void:
	var u := _u
	# [x, y, height, lean] in scene fractions; the front ones overlap the water edge
	var clumps := [[0.9, 0.36, 1.0], [0.94, 0.47, 0.9], [0.87, 0.54, 0.8], [0.66, 0.36, 0.7], [0.07, 0.34, 0.9], [0.1, 0.44, 0.75],
		[0.95, 0.6, 0.7]]
	for ci in clumps.size():
		var cl: Array = clumps[ci]
		var base := P(cl[0], cl[1])
		var is_front := float(cl[1]) > 0.5 or ci == 2
		if is_front != front:
			continue
		for j in 5:
			var x := base.x + (j - 2) * 7.0 * u
			var h := (60.0 + 16.0 * sin(j * 2.3 + ci)) * u * float(cl[2]) + 10.0
			var sway := sin(time * 1.4 + j * 0.8 + ci) * 5.0 * u
			var b := Vector2(x, base.y + j % 2 * 4.0 * u)
			var t := b + Vector2(sway + (j - 2) * 3.0 * u, -h)
			draw_line(b, t, UiPalette.OUTLINE, 5.0 * u + 1.5, true)
			draw_line(b, t, Color("5aa83e"), 3.0 * u + 0.5, true)
			if j % 2 == 0:
				var tail := t.lerp(b, 0.22)
				var dir := (t - b).normalized()
				draw_line(t.lerp(b, 0.08), tail, UiPalette.OUTLINE, 9.0 * u + 3.0, true)
				draw_line(t.lerp(b, 0.08) + dir, tail - dir, Color("8a5430"), 7.0 * u + 1.0, true)
			else:
				# a leaf blade
				var mid := b.lerp(t, 0.5)
				draw_line(mid, mid + Vector2(10.0 * u + sway, -14.0 * u), Color("4a9432"), 3.0 * u, true)
		# the base in the water: a little ring
		draw_set_transform(base + Vector2(0, 6.0 * u), 0.0, Vector2(1.0, 0.35))
		draw_arc(Vector2.ZERO, 24.0 * u, 0.0, TAU, 20, Color(1, 1, 1, 0.25), 2.0 * u + 0.5, true)
		draw_set_transform(Vector2.ZERO)


func _draw_lilies() -> void:
	var u := _u
	var pads := [[0.62, 0.62, 1.0], [0.68, 0.69, 0.7], [0.3, 0.44, 0.8], [0.14, 0.52, 0.65], [0.58, 0.2, 0.6]]
	for k in pads.size():
		var pd: Array = pads[k]
		var c := P(pd[0], pd[1]) + Vector2(0, sin(time * 1.2 + k) * 1.5 * u)
		var r := 20.0 * u * float(pd[2]) + 4.0
		var pts := PackedVector2Array([c])
		for i in 21:
			var a := 0.35 + (TAU - 0.7) * i / 20.0 + k
			pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.55))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.18))
		var outline := PackedVector2Array(pts)
		outline.append(c)
		draw_set_transform(Vector2(0, -2.0 * u))
		draw_colored_polygon(pts, Color("3f9a3c"))
		draw_polyline(outline, Color("2a6a2a"), 2.0 * u + 0.5, true)
		draw_line(c, c + Vector2(cos(k + 2.0) * r * 0.7, sin(k + 2.0) * r * 0.38), Color("62b84e"), 1.5 * u + 0.5, true)
		draw_set_transform(Vector2.ZERO)
		if k == 0 or k == 3:
			var fc := c + Vector2(r * 0.15, -4.0 * u)
			for j in 6:
				var a := TAU * j / 6.0 + time * 0.1
				draw_circle(fc + Vector2(cos(a) * 6.0 * u, sin(a) * 3.5 * u - 2.0 * u), 5.0 * u + 1.0, Color("ff9cc2"))
			draw_circle(fc + Vector2(0, -3.0 * u), 4.0 * u + 1.0, Color("fff0f6"))
			draw_circle(fc + Vector2(0, -3.0 * u), 2.0 * u + 0.5, Color("ffd24a"))


func _draw_spots() -> void:
	var u := _u
	var aiming := _mode == "aim" and not locked
	for i in 3:
		var c := _spot_pos(i)
		var col: Color = SPOT_COLS[i]
		var a := 1.0 if aiming else (0.0 if i == _spot or _mode == "idle" else 0.25)
		if a <= 0.0:
			continue
		var hot := aiming and i == _hover
		var R := (34.0 + 4.0 * i) * u + 8.0
		# bubbling rings (perspective ellipses)
		for j in 3:
			var k := fmod(time * 0.55 + j / 3.0 + i * 0.21, 1.0)
			var rc := col
			rc.a = (1.0 - k) * 0.7 * a
			draw_set_transform(c, 0.0, Vector2(1.0, 0.42))
			draw_arc(Vector2.ZERO, R * (0.35 + 0.8 * k), 0.0, TAU, 32, rc, (3.5 - 2.0 * k) * u + 1.0, true)
			draw_set_transform(Vector2.ZERO)
		draw_set_transform(c, 0.0, Vector2(1.0, 0.42))
		draw_arc(Vector2.ZERO, R, 0.0, TAU, 40, Color(col, (0.95 if hot else 0.6) * a), (5.0 if hot else 3.0) * u + 1.0, true)
		if hot:
			draw_circle(Vector2.ZERO, R, Color(col, 0.18))
		draw_set_transform(Vector2.ZERO)
		# bubbles popping up
		for j in 4:
			var k := fmod(time * (0.8 + 0.1 * j) + j * 0.37 + i * 0.5, 1.0)
			var bp := c + Vector2(sin(j * 2.4 + i) * R * 0.45, -k * 16.0 * u + 2.0)
			draw_circle(bp, (2.5 + 1.5 * (j % 2)) * u + 1.0, Color(1, 1, 1, (1.0 - k) * 0.8 * a))
		# the label pill
		var fs := int(clampf(17.0 * u + 4.0, 13.0, 26.0))
		var hs := int(clampf(12.0 * u + 3.0, 11.0, 19.0))
		var font := UiTheme.display_font()
		var tw := maxf(font.get_string_size(SPOT_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
			UiTheme.body_font(700).get_string_size(SPOT_HINTS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x) + 22.0
		var lc := c + Vector2(0, R * 0.42 + fs * 1.2 + 4.0)
		var pr := Rect2(lc - Vector2(tw * 0.5, fs * 0.85), Vector2(tw, fs * 1.0 + hs * 1.25 + 8.0))
		var bob := sin(time * 2.0 + i) * 1.5 * u - (3.0 * u if hot else 0.0)
		pr.position.y += bob
		rrect(Rect2(pr.position + Vector2(0, 3), pr.size), Color(0, 0, 0, 0.3 * a), pr.size.y * 0.3)
		rrect(pr, Color(0.06, 0.1, 0.2, 0.82 * a), pr.size.y * 0.3, 2 if not hot else 3, Color(col, a))
		text_c(Vector2(lc.x, pr.position.y + fs * 0.62 + 3.0), SPOT_NAMES[i], fs, Color(col, a), 0)
		text_c(Vector2(lc.x, pr.position.y + fs * 1.05 + hs * 0.72 + 5.0), SPOT_HINTS[i], hs, Color(1, 1, 1, 0.85 * a), 0, false)


func _draw_shadow() -> void:
	if _spot < 0 or not (_mode in ["wait", "reel"]):
		return
	var bp := _spot_pos(_spot)
	var u := _u
	var a := _shadow_a
	var p: Vector2
	var ang: float
	if not _shadow_dart.is_empty():
		var k := (time - float(_shadow_dart.t0)) / (1.1 if _shadow_dart.has("slow") else 0.45)
		if k >= 1.0:
			return
		var dir: Vector2 = _shadow_dart.dir
		p = bp + dir * ease(clampf(k, 0.0, 1.0), 0.5) * 140.0 * u
		ang = dir.angle()
		a *= 1.0 - k
	else:
		var R := 46.0 * u
		if _mode == "wait":
			var t := clock()
			var nk := clampf((time - _nib_t) / 0.35, 0.0, 1.0)
			R *= 0.55 + 0.45 * nk
			if _bitten:
				R *= maxf(0.0, 1.0 - (time - _bite_t) * 6.0)
			elif t > _bite_at - 0.6:
				R *= 0.8
		p = bp + Vector2(cos(_shadow_ang) * R, sin(_shadow_ang) * R * 0.45 + 10.0 * u)
		ang = _shadow_ang + PI * 0.5
	if a <= 0.0:
		return
	var L := (58.0 + 8.0 * _spot) * u
	var col := Color(0.02, 0.1, 0.2, 0.32 * a)
	draw_set_transform(p, ang, Vector2(1.0, 0.55))
	draw_colored_polygon(_ell(Vector2.ZERO, L * 0.42, L * 0.2, 20), col)
	var wag := sin(time * 9.0) * L * 0.08
	draw_colored_polygon(PackedVector2Array([Vector2(-L * 0.36, 0), Vector2(-L * 0.62, -L * 0.18 + wag), Vector2(-L * 0.58, L * 0.18 + wag)]), col)
	draw_set_transform(Vector2.ZERO)


func _bobber_pos() -> Vector2:
	var u := _u
	match _bob:
		"fly":
			var k := _fly_k
			return _fly_from.lerp(_fly_to, k) + Vector2(0, -sin(k * PI) * _s.size.y * 0.22)
		"back":
			var k := _fly_k
			return _fly_from.lerp(_tip() + Vector2(0, 22.0 * u), k) + Vector2(0, -sin(k * PI) * 40.0 * u)
		"float":
			return _fly_to
	return _tip() + Vector2(sin(time * 2.2) * 4.0 * u, 22.0 * u)


func _draw_line_and_bobber() -> void:
	var u := _u
	var tip := _tip()
	var bp := _bobber_pos()
	var rb := 11.0 * u + 3.0
	var sub := 0.0         # how deep the bobber sits (px); only when floating
	var under := 0.0
	if _bob == "float":
		sub = rb * 0.25 + sin(time * 2.4) * 1.5 * u - _settle * rb * 0.9
		var nk := clampf((time - _nib_t) / 0.3, 0.0, 1.0)
		if nk < 1.0:
			sub += sin(nk * PI) * rb * 0.75
		if _bitten and not _surfaced and not (_mode == "reel"):
			under = clampf((time - _bite_t) / 0.1, 0.0, 1.0)
			sub += under * rb * 3.2
	# the line
	var end := bp + Vector2(0, -rb * 1.6 + sub) if _bob == "float" else bp + Vector2(0, -rb * 1.4)
	var mid := tip.lerp(end, 0.5) + Vector2(0, (26.0 * u) * _slack if _bob in ["float"] else 6.0 * u)
	var line := PackedVector2Array()
	for i in 17:
		var k := i / 16.0
		line.append(tip.lerp(mid, k).lerp(mid.lerp(end, k), k))
	draw_polyline(line, Color(1, 1, 1, 0.75), 1.6 * u + 0.6, true)
	if _bob == "float":
		_draw_floating(bp, rb, sub, under)
	else:
		_bobber(bp, rb, 1e9)


## The bobber at the surface point sp, `sub` px down (clipped at the waterline).
func _draw_floating(sp: Vector2, rb: float, sub: float, under: float) -> void:
	var u := _u
	var c := sp + Vector2(0, -rb * 0.75 + sub)
	var wc: Color = SPOT_WATER[clampi(_spot, 0, 2)]
	# the underwater part, seen dimly through the water
	draw_circle(c, rb, wc.darkened(0.25).lerp(Color("ff6a6a"), 0.25))
	_bobber(c, rb, sp.y)
	# meniscus ring
	draw_set_transform(sp, 0.0, Vector2(1.0, 0.38))
	draw_arc(Vector2.ZERO, rb * (1.25 + 0.4 * under), 0.0, TAU, 24, Color(1, 1, 1, 0.55 + 0.3 * under), 2.5 * u + 0.5, true)
	draw_set_transform(Vector2.ZERO)
	if under > 0.0:
		# swirl + the strike window countdown + "!"
		var k := clampf(clock() - _bite_at, 0.0, _window) / maxf(_window, 0.01)
		var left := 1.0 - k
		var R := 30.0 * u + 10.0
		draw_arc(sp, R, 0.0, TAU, 40, Color(UiPalette.OUTLINE, 0.6), 9.0 * u + 2.0, true)
		var wcol := Color("7dff9a").lerp(Color("ff5a4a"), k)
		if left > 0.0 and not _struck:
			draw_arc(sp, R, -PI * 0.5, -PI * 0.5 + TAU * left, 40, wcol, 6.0 * u + 1.5, true)
		for j in 3:
			var bk := fmod(time * 2.5 + j * 0.33, 1.0)
			draw_circle(sp + Vector2(sin(j * 2.1 + time * 3.0) * rb, -bk * 14.0 * u), 3.0 * u + 1.0, Color(1, 1, 1, 1.0 - bk))
		var pk := clampf((time - _bite_t) / 0.18, 0.0, 1.0)
		var sc := (1.0 + 0.5 * sin(pk * PI)) * (1.0 + 0.06 * sin(time * 18.0))
		var bc := sp + Vector2(0, -R - 22.0 * u - 6.0)
		var br := (19.0 * u + 7.0) * sc
		draw_circle(bc, br + 3.0, UiPalette.OUTLINE)
		draw_circle(bc, br, Color("fff4c8"))
		draw_colored_polygon(PackedVector2Array([bc + Vector2(-br * 0.35, br * 0.8), bc + Vector2(br * 0.1, br * 0.8), bc + Vector2(-br * 0.3, br * 1.35)]), Color("fff4c8"))
		text_c(bc + Vector2(0, -1), "!", int(br * 1.4), Color("ff3b4a"), 0)


## A red-and-white bobber centred at c; only what is above water_y is drawn.
func _bobber(c: Vector2, rb: float, water_y: float) -> void:
	var u := _u
	var above := Rect2(c - Vector2(rb * 3.0, rb * 4.0), Vector2(rb * 6.0, water_y - (c.y - rb * 4.0)))
	if above.size.y <= 0.0:
		return
	var clip := rect_poly(above)
	# the antenna
	var st := c + Vector2(0, -rb)
	var sp := c + Vector2(0, -rb * 1.9)
	var top := maxf(sp.y, above.position.y)
	if st.y > top and sp.y < water_y:
		var sb := Vector2(st.x, minf(st.y, water_y))
		draw_line(sb, Vector2(sp.x, sp.y), UiPalette.OUTLINE, 4.5 * u + 1.0, true)
		draw_line(sb, Vector2(sp.x, sp.y), Color("fff4d0"), 2.2 * u + 0.5, true)
		draw_circle(sp, 3.5 * u + 1.5, UiPalette.OUTLINE)
		draw_circle(sp, 2.5 * u + 1.0, Color("ffd24a"))
	clipped(_ell(c, rb + 2.5, rb + 2.5, 24), clip, UiPalette.OUTLINE)
	clipped(_ell(c, rb, rb, 24), clip, Color("fbf6ec"))
	var top_r := above.intersection(Rect2(c - Vector2(rb * 2.0, rb * 2.0), Vector2(rb * 4.0, rb * 2.0)))
	if top_r.size.y > 0.5:
		clipped(_ell(c, rb, rb, 24), rect_poly(top_r), Color("ff3b4a"))
	var band := above.intersection(Rect2(c + Vector2(-rb * 2.0, -rb * 0.08), Vector2(rb * 4.0, rb * 0.22)))
	if band.size.y > 0.5:
		clipped(_ell(c, rb, rb, 24), rect_poly(band), Color("2a1a30"))
	if c.y - rb * 0.4 < water_y:
		draw_circle(c + Vector2(-rb * 0.38, -rb * 0.45), rb * 0.24, Color(1, 1, 1, 0.75))


func _draw_rod() -> void:
	var u := _u
	var pts := _rod_pts()
	var n := pts.size()
	for pass_i in 2:
		for i in n - 1:
			var k := float(i) / (n - 1)
			var w := lerpf(11.0, 4.0, k) * u + 2.0
			if pass_i == 0:
				draw_line(pts[i], pts[i + 1], UiPalette.OUTLINE, w + 4.0, true)
			else:
				var col := Color("8a5a36") if k < 0.24 else Color("2f5f9a").lerp(Color("5a8fd0"), k)
				draw_line(pts[i], pts[i + 1], col, w, true)
				if k >= 0.24:
					draw_line(pts[i] + Vector2(-1, -1), pts[i + 1] + Vector2(-1, -1), Color(1, 1, 1, 0.3), maxf(1.0, w * 0.3), true)
	# cork grip bands + the reel
	for i in 3:
		var p := pts[0].lerp(pts[3], 0.2 + i * 0.3)
		draw_circle(p, 5.5 * u + 1.5, Color("c89a62"))
	var rp := pts[3]
	var dir := (pts[4] - pts[2]).normalized()
	var side := dir.orthogonal()
	var rc := rp + side * 14.0 * u
	draw_line(rp, rc, UiPalette.OUTLINE, 5.0 * u + 2.0, true)
	draw_circle(rc, 12.0 * u + 3.0, UiPalette.OUTLINE)
	draw_circle(rc, 12.0 * u + 0.5, Color("c8ced8"))
	draw_circle(rc, 6.0 * u, Color("8a92a4"))
	var spin := time * (14.0 if _mode == "reel" or _bob == "back" else 0.5)
	var hk := rc + Vector2.from_angle(spin) * 10.0 * u
	draw_line(rc, hk, UiPalette.OUTLINE, 4.0 * u + 1.0, true)
	draw_circle(hk, 3.5 * u + 1.0, Color("ff3b4a"))
	# line guides
	for i in [6, 9, 11]:
		draw_circle(pts[i], 3.0 * u + 1.0, Color("dfe6f0"))
	draw_circle(pts[n - 1], 3.0 * u + 1.0, Color("ffd24a"))


func _draw_pier() -> void:
	var u := _u
	var x0 := 0.66
	var x1 := 0.92
	var top := P(x0, 0.8)
	var r := Rect2(top, P(x1, 1.0) - top + Vector2(0, 1))
	# posts in the water, then the planks
	for px in [x0 + 0.015, x1 - 0.015]:
		var pc := P(px, 0.815)
		draw_set_transform(pc + Vector2(0, 8.0 * u), 0.0, Vector2(1, 0.4))
		draw_arc(Vector2.ZERO, 14.0 * u + 3.0, 0.0, TAU, 20, Color(1, 1, 1, 0.35 + 0.15 * sin(time * 2.0)), 2.0 * u + 0.5, true)
		draw_set_transform(Vector2.ZERO)
		rrect(Rect2(pc + Vector2(-8.0 * u - 2.0, -10.0 * u), Vector2(16.0 * u + 4.0, 26.0 * u)), UiPalette.OUTLINE, 5.0 * u)
		rrect(Rect2(pc + Vector2(-6.0 * u - 1.0, -8.0 * u), Vector2(12.0 * u + 2.0, 22.0 * u)), Color("6a4226"), 4.0 * u)
	rrect(Rect2(r.position + Vector2(0, 8.0 * u), r.size), Color(0, 0, 0, 0.25), 8.0 * u)
	rrect(r.grow(3.0), UiPalette.OUTLINE, 9.0 * u + 3.0)
	var n := 5
	for i in n:
		var pr := Rect2(r.position + Vector2(0, r.size.y * i / n), Vector2(r.size.x, r.size.y / n - 2.0))
		var col := Color("b07a48") if i % 2 == 0 else Color("a06c3e")
		rrect(pr, col, 4.0 * u)
		draw_line(pr.position + Vector2(4, 3), Vector2(pr.end.x - 4, pr.position.y + 3), Color(1, 1, 1, 0.18), 2.0, true)
		draw_circle(pr.position + Vector2(8.0 * u, pr.size.y * 0.5), 2.0 * u + 0.5, Color("5a3a22"))
		draw_circle(Vector2(pr.end.x - 8.0 * u, pr.position.y + pr.size.y * 0.5), 2.0 * u + 0.5, Color("5a3a22"))
	# the tackle box on the planks (3D icon when available)
	var tb := ModelIcons.get_icon(TACKLE, 30.0)
	var ts := 56.0 * u + 10.0
	var tc := P(x0 + 0.06, 0.9)
	if tb:
		draw_texture_rect(tb, Rect2(tc - Vector2(ts, ts) * 0.5, Vector2(ts, ts)), false)
	else:
		rrect(Rect2(tc - Vector2(ts * 0.35, ts * 0.2), Vector2(ts * 0.7, ts * 0.42)), UiPalette.OUTLINE, 6.0 * u)
		rrect(Rect2(tc - Vector2(ts * 0.32, ts * 0.17), Vector2(ts * 0.64, ts * 0.36)), Color("3a8a4a"), 5.0 * u)


func _slot_rect(i: int) -> Rect2:
	var tr := _tray_rect()
	var pad := 6.0 * _u + 2.0
	var lab := 0.0
	var w := (tr.size.x - pad * 4.0 - lab) / 3.0
	return Rect2(tr.position + Vector2(pad + lab + i * (w + pad), pad), Vector2(w, tr.size.y - pad * 2.0))


func _slot_pos(i: int) -> Vector2:
	return _slot_rect(clampi(i, 0, 2)).get_center()


func _tray_rect() -> Rect2:
	var a := P(0.035, 0.855)
	return Rect2(a, P(0.6, 0.985) - a)


func _draw_tray() -> void:
	var u := _u
	var tr := _tray_rect()
	# the fish barrel beside the tray
	var bar := ModelIcons.get_icon(BARREL, 30.0)
	var bs := 70.0 * u + 12.0
	var bc := Vector2(tr.end.x + bs * 0.18, tr.position.y - bs * 0.18)
	if bar:
		draw_texture_rect(bar, Rect2(bc - Vector2(bs, bs) * 0.5, Vector2(bs, bs)), false)
	rrect(Rect2(tr.position + Vector2(0, 5), tr.size), Color(0, 0, 0, 0.3), 12.0 * u + 4.0)
	rrect(tr.grow(3.0), UiPalette.OUTLINE, 12.0 * u + 6.0)
	rrect(tr, Color("9a6a3e"), 12.0 * u + 4.0)
	rrect(Rect2(tr.position + Vector2(6, 3), Vector2(tr.size.x - 12, 4.0 * u + 2.0)), Color(1, 1, 1, 0.18), 3)
	var cur := (state.get("catches", []) as Array).size()
	for i in 3:
		var sr := _slot_rect(i)
		var pulse := i == cur and _mode in ["aim", "wait", "cast"] and not _over()
		rrect(sr, Color("3a2414"), 9.0 * u + 3.0, 2 if not pulse else 3,
			Color(1, 0.9, 0.5, 0.5 + 0.4 * sin(time * 5.0)) if pulse else Color("5a3a22"))
		var c := sr.get_center()
		var pop := 1.0
		if i == _pop_slot:
			var pk := clampf((time - _pop_t) / 0.3, 0.0, 1.0)
			pop = 1.0 + 0.35 * sin(pk * PI)
		if i < _tray.size():
			var ct: Dictionary = _tray[i]
			var res := String(ct.get("result", ""))
			if res == "caught":
				var kind := String(ct.get("kind", ""))
				var L := minf(sr.size.x * 0.8, sr.size.y * 1.55) * float((KINDS.get(kind, KINDS.minnow) as Dictionary).len) * pop
				_fish(kind, c + Vector2(-sr.size.x * 0.06, 2.0 * u), L, -0.18 + sin(time * 2.0 + i) * 0.05)
				var fs := int(clampf(15.0 * u + 4.0, 12.0, 24.0))
				text_c(Vector2(sr.end.x - fs * 0.9, sr.end.y - fs * 0.55), "+%d" % int(ct.get("points", 0)), fs, Color("ffe07a"), maxi(4, fs / 4))
				if bool(ct.get("perfect", false)):
					_star4(sr.position + Vector2(fs * 0.7, fs * 0.7), fs * 0.5 * (1.0 + 0.15 * sin(time * 6.0)), Color("ffe07a"))
			else:
				var fs := int(clampf(13.0 * u + 3.0, 10.0, 20.0))
				text_c(c + Vector2(0, -fs * 0.35), "X", int(fs * 1.6 * pop), Color(1, 0.55, 0.55, 0.8), 4)
				text_c(c + Vector2(0, fs * 0.95), "EARLY" if res == "spooked" else "AWAY", fs, Color(1, 1, 1, 0.55), 0, false)
		else:
			var fs := int(clampf(18.0 * u + 4.0, 13.0, 28.0))
			text_c(c, str(i + 1), fs, Color(1, 1, 1, 0.22), 0)


func _draw_flying() -> void:
	if _flying.is_empty():
		return
	var k := clampf((time - float(_flying.t0)) / float(_flying.d), 0.0, 1.0)
	var from: Vector2 = _flying.from
	var to: Vector2 = _flying.to
	var e := ease(k, -1.6)
	var p := from.lerp(to, e) + Vector2(0, -sin(k * PI) * _s.size.y * 0.3)
	var kind := String(_flying.kind)
	var sr := _slot_rect(0)
	var L0 := 120.0 * _u + 20.0
	var L1 := minf(sr.size.x * 0.8, sr.size.y * 1.55) * float((KINDS.get(kind, KINDS.minnow) as Dictionary).len)
	var L := lerpf(L0 * (0.6 + 0.5 * float((KINDS.get(kind, KINDS.minnow) as Dictionary).len)), L1, e)
	if kind == "koi":
		glow(p, L * 0.9, Color(1.0, 0.85, 0.3, 0.8))
	# droplets trail
	if k < 0.6 and randf() < 0.5:
		burst(p, Color("dff6ff"), 1, "spark", 40.0, 0.0, 4.0 * _u + 1.0)
	_fish(kind, p, L, k * TAU * 1.25 - 0.4)


func _draw_dragonfly() -> void:
	var u := _u
	var t := time * 0.35
	var p := P(0.5 + 0.32 * sin(t * 1.3) * cos(t * 0.7), 0.4 + 0.18 * sin(t * 1.9 + 1.0))
	var v := Vector2(0.32 * 1.3 * cos(t * 1.3), 0.18 * 1.9 * cos(t * 1.9 + 1.0))
	var ang := v.angle()
	draw_set_transform(p, ang, Vector2.ONE)
	var fl := 0.6 + 0.4 * absf(sin(time * 40.0))
	for sgn in [-1.0, 1.0]:
		for off in [-2.0, 3.0]:
			draw_colored_polygon(_ell(Vector2(off * u, sgn * 7.0 * u * fl), 3.0 * u + 1.0, 7.0 * u * fl + 1.0, 10), Color(0.85, 0.95, 1.0, 0.55))
	draw_line(Vector2(-11.0 * u, 0), Vector2(7.0 * u, 0), UiPalette.OUTLINE, 4.0 * u + 1.0, true)
	draw_line(Vector2(-11.0 * u, 0), Vector2(7.0 * u, 0), Color("3ad0c0"), 2.5 * u + 0.5, true)
	draw_circle(Vector2(8.0 * u, 0), 2.5 * u + 1.0, Color("1a6a8a"))
	draw_set_transform(Vector2.ZERO)


func _draw_prompt() -> void:
	var u := _u
	var txt := ""
	var col := Color.WHITE
	var hot := false
	if _mode == "aim" and not locked:
		txt = "TAP A SPOT TO CAST"
		col = Color("dff6ff")
	elif _mode == "wait":
		if _bitten and not _surfaced and not _struck:
			txt = "STRIKE! TAP!"
			col = Color("ffe07a")
			hot = true
		elif not _struck:
			txt = "WAIT FOR THE PLUNGE..."
			col = Color(1, 1, 1, 0.85)
	if txt == "":
		return
	var fs := int(clampf((26.0 if hot else 18.0) * u + 5.0, 14.0, 34.0))
	var font := UiTheme.display_font()
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30.0
	var c := P(0.5, 0.075)
	var sc := 1.0 + (0.08 * sin(time * 16.0) if hot else 0.0)
	var r := Rect2(c - Vector2(w, fs * 1.5) * 0.5 * sc, Vector2(w, fs * 1.5) * sc)
	rrect(r.grow(2.0), UiPalette.OUTLINE, r.size.y * 0.5)
	rrect(r, Color("d8263a") if hot else Color(0.06, 0.1, 0.2, 0.85), r.size.y * 0.5)
	text_c(c, txt, int(fs * sc), col, maxi(4, fs / 5))


# --- fish ------------------------------------------------------------------------------

## A procedural catch centred at c: length L, rotated by ang (facing right at 0).
func _fish(kind: String, c: Vector2, L: float, ang: float, a := 1.0) -> void:
	var d: Dictionary = KINDS.get(kind, KINDS.minnow)
	draw_set_transform(c, ang, Vector2.ONE)
	match kind:
		"boot":
			_boot(L, d, a)
		"weed":
			_weed(L, d, a)
		_:
			_fish_body(kind, L, d, a)
	draw_set_transform(Vector2.ZERO)


func _fish_body(kind: String, L: float, d: Dictionary, a: float) -> void:
	var h := L * float(d.h)
	var ow := maxf(2.0, L * 0.04)
	var body: Color = d.body
	var belly: Color = d.belly
	var fin: Color = d.fin
	var mark: Color = d.mark
	var o := Color(UiPalette.OUTLINE, a)
	# body outline: an egg shape, pointier at the tail
	var pts := PackedVector2Array()
	for i in 28:
		var t := TAU * i / 28.0
		var x := cos(t)
		var y := sin(t)
		var rx := L * (0.38 if x > 0.0 else 0.34)
		var ry := h * 0.5 * (1.0 - 0.28 * maxf(0.0, -x))
		pts.append(Vector2(x * rx + L * 0.04, y * ry))
	var tail := PackedVector2Array([Vector2(-L * 0.26, 0), Vector2(-L * 0.5, -h * 0.46), Vector2(-L * 0.44, 0), Vector2(-L * 0.5, h * 0.46)])
	var dorsal := PackedVector2Array([Vector2(-L * 0.12, -h * 0.4), Vector2(L * 0.02, -h * 0.72), Vector2(L * 0.14, -h * 0.44)])
	if kind == "pike":
		dorsal = PackedVector2Array([Vector2(-L * 0.26, -h * 0.3), Vector2(-L * 0.2, -h * 0.72), Vector2(-L * 0.1, -h * 0.4)])
	var tw := sin(time * 10.0) * 0.12
	var tail_t := Transform2D(tw, Vector2(-L * 0.26, 0)) * Transform2D(0.0, Vector2(L * 0.26, 0))
	tail = tail_t * tail
	for poly: PackedVector2Array in [tail, dorsal]:
		var cl := PackedVector2Array(poly)
		cl.append(poly[0])
		draw_polyline(cl, o, ow * 2.0, true)
	var bl := PackedVector2Array(pts)
	bl.append(pts[0])
	draw_polyline(bl, o, ow * 2.0, true)
	draw_colored_polygon(tail, Color(fin, a))
	draw_colored_polygon(dorsal, Color(fin, a))
	draw_colored_polygon(pts, Color(body, a))
	# belly
	var bpts := PackedVector2Array()
	for i in 15:
		var t := PI * i / 14.0
		bpts.append(Vector2(cos(t) * L * 0.3 + L * 0.04, h * 0.1 + sin(t) * h * 0.34))
	clipped(bpts, pts, Color(belly, a))
	# markings per kind
	match kind:
		"minnow":
			draw_line(Vector2(-L * 0.28, 0), Vector2(L * 0.3, -h * 0.05), Color(mark, a), maxf(2.0, h * 0.12), true)
		"perch":
			for k in 4:
				var x := -L * 0.16 + k * L * 0.11
				clipped(PackedVector2Array([Vector2(x, -h), Vector2(x + L * 0.05, -h), Vector2(x + L * 0.02, h * 0.2), Vector2(x - L * 0.03, h * 0.2)]), pts, Color(mark, a * 0.8))
		"bass":
			var zig := PackedVector2Array()
			for k in 8:
				zig.append(Vector2(-L * 0.28 + k * L * 0.075, (k % 2) * h * 0.08 - h * 0.02))
			draw_polyline(zig, Color(mark, a), maxf(2.0, h * 0.09), true)
			draw_line(Vector2(L * 0.3, h * 0.12), Vector2(L * 0.42, h * 0.08), o, ow, true)
		"pike":
			for k in 7:
				draw_colored_polygon(_ell(Vector2(-L * 0.24 + k * L * 0.075, (k % 2 - 0.5) * h * 0.3), L * 0.025, h * 0.08, 8), Color(mark, a * 0.9))
		"carp":
			for k in 3:
				for j in 2:
					draw_arc(Vector2(-L * 0.12 + k * L * 0.1, (j - 0.5) * h * 0.36), h * 0.14, -PI * 0.5, PI * 0.5, 6, Color(mark, a * 0.7), maxf(1.5, ow * 0.7), true)
			draw_line(Vector2(L * 0.4, h * 0.06), Vector2(L * 0.48, h * 0.28), Color(mark, a), maxf(1.5, ow * 0.7), true)
		"catfish":
			for sgn in [-1.0, 1.0]:
				var wp := PackedVector2Array()
				for k in 6:
					wp.append(Vector2(L * 0.4 + k * L * 0.05, h * 0.1 + sgn * (k * h * 0.12) + sin(time * 6.0 + k) * h * 0.04))
				draw_polyline(wp, o, maxf(1.5, ow * 0.8), true)
		"koi":
			clipped(_ell(Vector2(-L * 0.02, -h * 0.12), L * 0.13, h * 0.24, 12), pts, Color(mark, a))
			clipped(_ell(Vector2(L * 0.22, -h * 0.2), L * 0.08, h * 0.16, 10), pts, Color(mark, a))
			clipped(_ell(Vector2(-L * 0.2, h * 0.08), L * 0.07, h * 0.14, 10), pts, Color("ff8a3a", a))
			var sh := fmod(time * 0.9, 1.6) - 0.3
			clipped(PackedVector2Array([Vector2(L * (sh - 0.08), -h), Vector2(L * (sh + 0.02), -h), Vector2(L * (sh - 0.1), h), Vector2(L * (sh - 0.2), h)]), pts, Color(1, 1, 1, 0.55 * a))
			_star4(Vector2(L * 0.28, -h * 0.5), h * (0.28 + 0.1 * sin(time * 7.0)), Color(1, 1, 1, a))
	# gill + eye + shine
	draw_arc(Vector2(L * 0.22, 0), h * 0.3, -PI * 0.35, PI * 0.35, 8, Color(o, a * 0.6), maxf(1.5, ow * 0.6), true)
	var ec := Vector2(L * 0.3, -h * 0.1)
	draw_circle(ec, h * 0.13 + 1.0, o)
	draw_circle(ec, h * 0.11, Color(1, 1, 1, a))
	draw_circle(ec + Vector2(h * 0.02, 0), h * 0.06, Color(o, a))
	draw_line(Vector2(-L * 0.1, -h * 0.28), Vector2(L * 0.14, -h * 0.3), Color(1, 1, 1, 0.35 * a), maxf(2.0, h * 0.08), true)


func _boot(L: float, d: Dictionary, a: float) -> void:
	var o := Color(UiPalette.OUTLINE, a)
	var ow := maxf(2.0, L * 0.05)
	# a laced ankle boot, toe to the right
	var shaft := Rect2(Vector2(-L * 0.36, -L * 0.42), Vector2(L * 0.34, L * 0.62))
	var foot := PackedVector2Array([Vector2(-L * 0.36, L * 0.02), Vector2(L * 0.3, L * 0.04), Vector2(L * 0.44, L * 0.14), Vector2(L * 0.42, L * 0.26),
		Vector2(-L * 0.36, L * 0.26)])
	rrect(shaft.grow(ow), o, L * 0.08)
	var fo := PackedVector2Array(foot)
	fo.append(foot[0])
	draw_polyline(fo, o, ow * 2.0, true)
	rrect(shaft, Color(d.body as Color, a), L * 0.06)
	draw_colored_polygon(foot, Color(d.body as Color, a))
	draw_rect(Rect2(Vector2(-L * 0.36, L * 0.2), Vector2(L * 0.78, L * 0.08)), Color(d.fin as Color, a))
	for k in 3:
		var y := -L * 0.3 + k * L * 0.14
		draw_line(Vector2(-L * 0.12, y), Vector2(-L * 0.04, y + L * 0.06), Color(d.mark as Color, a), maxf(1.5, ow * 0.6), true)
		draw_line(Vector2(-L * 0.04, y), Vector2(-L * 0.12, y + L * 0.06), Color(d.mark as Color, a), maxf(1.5, ow * 0.6), true)
	draw_circle(Vector2(L * 0.1, L * 0.1), L * 0.03, Color(1, 1, 1, 0.3 * a))
	# a hole in the toe, a drip
	draw_circle(Vector2(L * 0.3, L * 0.12), L * 0.035, Color(d.belly as Color, a))
	var dk := fmod(time * 1.5, 1.0)
	draw_circle(Vector2(-L * 0.2, L * 0.34 + dk * L * 0.2), L * 0.03 * (1.0 - dk) + 1.0, Color(0.7, 0.9, 1.0, a * (1.0 - dk)))


func _weed(L: float, d: Dictionary, a: float) -> void:
	var o := Color(UiPalette.OUTLINE, a)
	for k in 5:
		var pts := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			pts.append(Vector2(-L * 0.4 + t * L * 0.8, (k - 2) * L * 0.07 + sin(t * 7.0 + k * 1.3 + time * 3.0) * L * 0.06))
		draw_polyline(pts, o, maxf(4.0, L * 0.09), true)
		draw_polyline(pts, Color((d.body as Color).lerp(d.belly, k * 0.2), a), maxf(2.0, L * 0.05), true)
	draw_circle(Vector2(L * 0.12, -L * 0.04), L * 0.08 + 2.0, o)
	draw_circle(Vector2(L * 0.12, -L * 0.04), L * 0.08, Color("f0c8a0", a))
	draw_arc(Vector2(L * 0.12, -L * 0.04), L * 0.045, 0.0, TAU * 0.8, 10, Color("a07050", a), maxf(1.0, L * 0.02), true)

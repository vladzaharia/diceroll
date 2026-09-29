class_name LadderBoard
extends MgBoard
## High-Low Ladder: a big die centre stage and a prize ladder beside it. Guess HIGHER or LOWER
## than the die (each button shows its odds, "4 in 5"); a right call climbs one rung (coins ->
## gold bars -> gems -> the gem chest at the top), an equal roll is a PUSH, a wrong one BUSTS
## the ladder down to the last SAFE rung (shields). CASH OUT banks the current rung any time.
## The next roll always comes from the core's minigame_update (never known here): the die
## shakes, tumbles and lands on it, then the hero token climbs, wobbles or falls.

const ICONS := [["resources/Money_Coins_Stack_Small.gltf", 25.0], ["resources/Money_Coins_Stack_Medium.gltf", 25.0],
	["resources/Money_Pile_Small.gltf", 25.0], ["resources/Money_Pile_Medium.gltf", 25.0], ["resources/Gold_Bar.gltf", 35.0],
	["resources/Gold_Bars_Stack_Small.gltf", 30.0], ["resources/Gem_Medium.gltf", 25.0], ["resources/Gems_Pile_Small.gltf", 25.0],
	["resources/Gems_Chest.gltf", 25.0]]
const ICON_COLS := [Color("ffd34a"), Color("ffd34a"), Color("ffc24a"), Color("ffc24a"), Color("ffb02e"), Color("ffb02e"),
	Color("7fe8ff"), Color("c98cff"), Color("ffcf4a")]
const TOKEN := "boardgame/pawn_A_yellow.gltf"
const GREEN := Color("8fd85a")
const HIGH_COL := Color("5fd068")
const LOW_COL := Color("5aa7ff")
const CASH_COL := Color("ffc93d")
const BUST_COL := Color("ff4d5e")
const BTN := ["higher", "lower", "cash"]

var _die_val := 1
var _die_off := Vector2.ZERO
var _die_rot := 0.0
var _die_sq := Vector2.ONE
var _die_flash := Color(0, 0, 0, 0)
var _die_spin := false
var _marker := 0.0
var _hop := 0.0
var _lit := 0            # rung glowing as "current"
var _broken := {}        # rung -> time it cracked
var _ladder_off := Vector2.ZERO
var _busy := false
var _hover := -1
var _press := {}         # button -> time pressed
var _stamp := ""         # "", "cash", "top", "bust"
var _stamp_t := -10.0
var _stamp_amt := 0
var _hist_t := -10.0
var _coins: Array = []   # flying cash coins {p, v, t, rot}

# layout
var _u := 1.0
var _ladder := Rect2()
var _stage := Rect2()
var _die_c := Vector2.ZERO
var _die_s := 100.0
var _step := 30.0
var _btns: Array[Rect2] = [Rect2(), Rect2(), Rect2()]


func set_state(st: Dictionary, instant := true) -> void:
	if _busy:
		state = st.duplicate(true)
		return
	super.set_state(st, instant)
	_die_val = int(state.get("die", 1))
	_marker = float(state.get("rung", 0))
	_lit = int(state.get("rung", 0))
	_broken.clear()
	_stamp = ""
	var hist: Array = state.get("history", [])
	if bool(state.get("bust", false)):
		var ups := 0
		for h: Dictionary in hist:
			if String(h.result) == "up":
				ups += 1
		for r in range(int(state.get("rung", 0)) + 1, ups + 1):
			_broken[r] = -10.0
		_stamp = "bust"
	elif bool(state.get("cashed", false)):
		_stamp = "top" if int(state.get("rung", 0)) >= _prizes().size() - 1 else "cash"
	_stamp_amt = _prize(int(state.get("rung", 0)))
	_stamp_t = -10.0
	unlock()


func is_settled() -> bool:
	return not _busy and _coins.is_empty()


func status_text() -> String:
	var r := int(state.get("rung", 0))
	if bool(state.get("bust", false)):
		return "Bust! Kept +%d" % _prize(r)
	if bool(state.get("cashed", false)):
		return "Banked +%d" % _prize(r)
	return "Bank +%d  ·  Safe +%d" % [_prize(r), _prize(HighLow.safety(r))]


func _prizes() -> Array:
	return state.get("prizes", HighLow.PRIZES)


func _prize(r: int) -> int:
	var p := _prizes()
	return int(p[clampi(r, 0, p.size() - 1)]) if not p.is_empty() else 0


func _is_safe(r: int) -> bool:
	for s in state.get("safe", HighLow.SAFE):
		if int(s) == r:
			return true
	return false


func _over() -> bool:
	return bool(state.get("done", false)) or bool(state.get("cashed", false)) or bool(state.get("bust", false))


## Can the player press button b now (HIGHER on a 6 / LOWER on a 1 never can).
func can_press(b: int) -> bool:
	if locked or _busy or _over() or state.is_empty():
		return false
	if b == 0:
		return _die_val < 6
	if b == 1:
		return _die_val > 1
	return true


## Odds label for a guess from `value`: "4 in 5" (pushes re-roll, so it is always out of 5).
static func odds_text(value: int, guess: String) -> String:
	var w := (6 - value) if guess == "higher" else (value - 1)
	if w >= 5:
		return "SURE THING"
	if w <= 0:
		return "NO CHANCE"
	return "%d in 5" % w


static func odds_color(value: int, guess: String) -> Color:
	var o := HighLow.win_odds(value, guess)
	if o >= 0.6:
		return Color("9dff8a")
	if o >= 0.4:
		return Color("ffe07a")
	return Color("ff9a8a")


# --- layout ----------------------------------------------------------------------------

func _layout() -> void:
	var w := size.x
	var h := size.y
	_u = clampf(minf(w, h) / 500.0, 0.6, 2.2)
	var pad := 8.0 * _u
	var bh := clampf(h * 0.16, 60.0, 110.0 * _u)
	var by := h - bh - pad * 0.5
	var gap := 10.0 * _u
	var bw := w - pad * 2.0 - gap * 2.0
	var ws := [0.31, 0.31, 0.38]
	var x := pad
	for i in 3:
		_btns[i] = Rect2(Vector2(x, by), Vector2(bw * ws[i], bh))
		x += bw * ws[i] + gap
	var top := pad
	var area_h := by - gap - top
	var lw := clampf(w * 0.42, 150.0, area_h * 0.72)
	_ladder = Rect2(Vector2(pad, top), Vector2(lw, area_h))
	_stage = Rect2(Vector2(pad + lw + gap, top), Vector2(w - pad * 2.0 - lw - gap, area_h))
	_step = (_ladder.size.y - 40.0 * _u) / float(maxi(1, _prizes().size()))
	_die_s = minf(_stage.size.x * 0.52, _stage.size.y * 0.36)
	_die_c = _stage.position + Vector2(_stage.size.x * 0.5, _stage.size.y * 0.47)


func rung_y(r: float) -> float:
	return _ladder.end.y - 14.0 * _u - (r + 0.5) * _step


func button_rect(guess: String) -> Rect2:
	_layout()
	return _btns[maxi(0, BTN.find(guess))]


# --- input -----------------------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm:
		_hover = _btn_at(mm.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hover >= 0 and can_press(_hover) else Control.CURSOR_ARROW
		return
	var mb := e as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var b := _btn_at(mb.position)
		if b < 0:
			return
		if not can_press(b):
			if not locked and not _busy and not _over():
				MgBoard.sfx("error")
				_press[b] = time
			return
		_press[b] = time
		MgBoard.sfx("dice_select" if b < 2 else "chips")
		send([BTN[b]])


func _btn_at(p: Vector2) -> int:
	_layout()
	for i in 3:
		if _btns[i].grow(4.0).has_point(p):
			return i
	return -1


func scripted_input(args: Array, drv: Node) -> bool:
	var guard := 0
	while (_busy or locked) and guard < 400:
		guard += 1
		await get_tree().process_frame
	var g := String(args[0]) if not args.is_empty() else "cash"
	var i := BTN.find(g)
	if i < 0:
		return false
	var p := get_global_rect().position + button_rect(g).get_center()
	drv.call("move", p, false)
	await get_tree().create_timer(0.25).timeout
	drv.call("click", p)
	return true


# --- updates ---------------------------------------------------------------------------

func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	_busy = true
	locked = true
	_layout()
	var info: Dictionary = ev.get("info", {})
	var new_state: Dictionary = (ev.get("state", {}) as Dictionary).duplicate(true)
	if bool(info.get("cash", false)):
		await _play_cash(int(info.get("rung", 0)), false)
	else:
		await _play_guess(info)
	state = new_state
	_die_val = int(state.get("die", _die_val))
	_marker = float(state.get("rung", 0))
	_lit = int(state.get("rung", 0))
	_busy = false
	unlock()


func _play_guess(info: Dictionary) -> void:
	var guess := String(info.get("guess", "higher"))
	var roll := int(info.get("roll", 1))
	var result := String(info.get("result", "push"))
	var from_rung := int(round(_marker))
	var new_rung := int(info.get("rung", from_rung))
	# anticipation: the die rattles
	MgBoard.sfx("dice_shake")
	var t0 := time
	while time - t0 < dur(0.4):
		var k := (time - t0) / dur(0.4)
		_die_off = Vector2(sin(time * 70.0) * 5.0, cos(time * 53.0) * 3.0) * _u * (0.4 + k)
		_die_rot = sin(time * 45.0) * 0.08 * (0.5 + k)
		await get_tree().process_frame
	# the tumble: up, spinning, faces flickering
	MgBoard.sfx("dice_roll")
	_die_spin = true
	var t := create_tween()
	t.tween_method(_tumble, 0.0, 1.0, dur(0.62))
	await t.finished
	_die_spin = false
	_die_val = roll
	_die_off = Vector2.ZERO
	_die_rot = 0.0
	MgBoard.sfx("dice_land")
	_die_sq = Vector2(1.28, 0.74)
	var sq := create_tween()
	sq.tween_property(self, "_die_sq", Vector2.ONE, dur(0.45)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	burst(_die_c + Vector2(0, _die_s * 0.55), Color("e8f0ff"), 10, "puff", 160.0, 0.0, 9.0 * _u)
	shake(3.0)
	_hist_t = time
	var col := HIGH_COL if result == "up" else (BUST_COL if result == "bust" else Color("cfd6e6"))
	ring(_die_c, col, _die_s * 0.9, 0.5, 8.0 * _u)
	await wait(0.18)
	match result:
		"up":
			await _play_up(from_rung, new_rung, guess)
		"push":
			await _play_push()
		_:
			await _play_bust(from_rung, new_rung)


func _tumble(k: float) -> void:
	_die_off = Vector2(sin(k * PI * 2.0) * 10.0 * _u, -sin(k * PI) * _die_s * 0.75)
	_die_rot = k * TAU * 2.0
	_die_sq = Vector2.ONE * (1.0 + 0.12 * sin(k * PI))
	# cosmetic face flicker while airborne (the real roll is only shown on landing)
	var f := int(k * 11.0)
	_die_val = (f * 5 + 3) % 6 + 1


func _play_up(from_rung: int, to_rung: int, guess: String) -> void:
	_die_flash = Color(HIGH_COL, 0.55)
	create_tween().tween_property(self, "_die_flash:a", 0.0, dur(0.5))
	float_text(_die_c + Vector2(0, -_die_s * 0.75), ("HIGHER!" if guess == "higher" else "LOWER!"), HIGH_COL.lightened(0.3), int(34 * _u), 0.9)
	# the climb: a hop up to the next rung
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		_marker = v
		_hop = sin((v - from_rung) * PI), float(from_rung), float(to_rung), dur(0.42)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	MgBoard.sfx("step")
	await t.finished
	_hop = 0.0
	_lit = to_rung
	_chime(1.0 + 0.09 * to_rung)
	var p := _rung_icon_center(to_rung)
	var tc: Color = ICON_COLS[clampi(to_rung, 0, ICON_COLS.size() - 1)]
	burst(p, tc, 12 + to_rung * 2, "star", 240.0, 40.0, 8.0 * _u)
	ring(p, tc.lightened(0.3), 46.0 * _u, 0.45, 6.0 * _u)
	float_text(p + Vector2(0, -10 * _u), "+%d" % _prize(to_rung), tc.lightened(0.35), int(30 * _u), 0.9)
	kick.emit(0.15 + 0.04 * to_rung, Color(tc.r, tc.g, tc.b, 0.3))
	if _is_safe(to_rung):
		await wait(0.15)
		MgBoard.sfx("block")
		float_text(Vector2(_ladder.get_center().x, rung_y(to_rung)), "SAFE!", Color("9fd8ff"), int(26 * _u), 0.9)
		ring(Vector2(_ladder.position.x + 16 * _u, rung_y(to_rung)), Color("9fd8ff"), 30 * _u, 0.5, 5.0 * _u)
	await wait(0.3)
	if to_rung >= _prizes().size() - 1:
		await _play_cash(to_rung, true)


func _play_push() -> void:
	MgBoard.sfx("tin")
	float_text(_die_c + Vector2(0, -_die_s * 0.75), "PUSH!", Color("e6ecff"), int(40 * _u), 1.0)
	var t := create_tween()
	for k in 5:
		t.tween_property(self, "_die_rot", 0.22 * (1.0 if k % 2 == 0 else -1.0) * (1.0 - k * 0.18), dur(0.07))
	t.tween_property(self, "_die_rot", 0.0, dur(0.07))
	await t.finished
	float_text(_die_c + Vector2(0, _die_s * 0.2), "same value - go again", UiPalette.TEXT_DIM, int(18 * _u), 1.0)
	await wait(0.35)


func _play_bust(from_rung: int, to_rung: int) -> void:
	MgBoard.sfx("crit")
	_die_flash = Color(BUST_COL, 0.7)
	create_tween().tween_property(self, "_die_flash:a", 0.25, dur(0.6))
	kick.emit(0.75, Color(1.0, 0.15, 0.2, 0.45))
	float_text(_die_c + Vector2(0, -_die_s * 0.8), "BUST!", BUST_COL.lightened(0.25), int(48 * _u), 1.2)
	shake(10.0)
	# the ladder cracks from the top of the climb down to the safety rung
	for r in range(from_rung, to_rung, -1):
		_broken[r] = time
		MgBoard.sfx("wood", 0.1)
		var p := Vector2(_ladder.position.x + _ladder.size.x * 0.4, rung_y(r))
		burst(p, Color("9a6a3a"), 8, "chunk", 200.0, 60.0, 7.0 * _u)
		_ladder_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * _u
		await wait(0.09)
	_ladder_off = Vector2.ZERO
	# the fall
	if from_rung != to_rung:
		MgBoard.sfx("swoosh")
		var t := create_tween()
		t.tween_property(self, "_marker", float(to_rung), dur(0.18 + 0.06 * (from_rung - to_rung))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await t.finished
	_lit = to_rung
	MgBoard.sfx("hit")
	MgBoard.sfx("fwump")
	shake(12.0)
	var mp := Vector2(_marker_x(), rung_y(to_rung))
	burst(mp, Color("d8c8b0"), 14, "puff", 180.0, 10.0, 10.0 * _u)
	ring(mp, BUST_COL, 40.0 * _u, 0.45, 6.0 * _u)
	await wait(0.3)
	MgBoard.sfx("lose")
	_stamp = "bust"
	_stamp_amt = _prize(to_rung)
	_stamp_t = time
	if _is_safe(to_rung) and to_rung > 0:
		float_text(Vector2(_ladder.get_center().x, rung_y(to_rung) - 10 * _u), "SAFE: +%d" % _prize(to_rung), Color("9fd8ff"), int(26 * _u), 1.2)
	await wait(0.7)


func _play_cash(r: int, top: bool) -> void:
	_lit = r
	var from := _rung_icon_center(r)
	MgBoard.sfx("chips")
	MgBoard.sfx("coin")
	if top:
		MgBoard.sfx("fanfare")
		shake(8.0)
		kick.emit(0.8, Color(1.0, 0.85, 0.3, 0.45))
		burst(from, Color("fff3a0"), 40, "star", 420.0, 80.0, 11.0 * _u)
		ring(from, Color("ffe07a"), 90.0 * _u, 0.6, 10.0 * _u)
	else:
		MgBoard.sfx("win")
		kick.emit(0.35 + 0.05 * r, Color(1.0, 0.85, 0.3, 0.35))
	# coins pour from the rung into the stage
	var n := 10 + r * 3
	for k in n:
		_coins.append({"p": from + Vector2(randf_range(-10, 10), randf_range(-8, 8)) * _u,
			"v": Vector2(randf_range(80.0, 420.0), randf_range(-520.0, -160.0)) * _u, "t": time + k * dur(0.025), "rot": randf() * TAU,
			"spin": randf_range(-10.0, 10.0)})
	_stamp = "top" if top else "cash"
	_stamp_amt = _prize(r)
	_stamp_t = time
	for k in 5:
		MgBoard.sfx("chip_tick", 0.15)
		await wait(0.1)
	await wait(0.6)


## Plays an sfx at a chosen pitch (a chime climbing with the rung): the bus has no pitch
## parameter, so this loads the same stream into a one-shot player here.
func _chime(pitch: float) -> void:
	var loop := Engine.get_main_loop() as SceneTree
	var a: Node = loop.root.get_node_or_null("Audio") if loop else null
	if a == null or a.get_script() == null:
		return
	var defs: Dictionary = (a.get_script() as Script).get_script_constant_map().get("SFX", {})
	for id in ["bell", "plink"]:
		if not defs.has(id):
			continue
		var files: Array = defs[id][0]
		var path := String(files[randi() % files.size()])
		if not ResourceLoader.exists(path):
			continue
		var p := AudioStreamPlayer.new()
		p.stream = load(path)
		p.bus = "SFX"
		p.volume_db = float(defs[id][1]) + (-2.0 if id == "bell" else 2.0)
		p.pitch_scale = pitch * (1.0 if id == "bell" else 1.5)
		add_child(p)
		p.finished.connect(p.queue_free)
		p.play()


func _tick(dt: float) -> void:
	var sdt := dt * clampf(speed, 1.0, 3.0)
	var floor_y := size.y + 40.0
	for i in range(_coins.size() - 1, -1, -1):
		var c: Dictionary = _coins[i]
		if time < float(c.t):
			continue
		c.v.y += 1400.0 * _u * sdt
		c.p += c.v * sdt
		c.rot += c.spin * sdt
		if c.p.y > floor_y:
			_coins.remove_at(i)


# --- drawing ---------------------------------------------------------------------------

func _draw_board() -> void:
	_layout()
	var u := _u
	var r := Rect2(Vector2.ZERO, size)
	# the table: a felt panel in the game colour
	rrect(Rect2(r.position + Vector2(0, 8 * u), r.size), Color(0, 0, 0, 0.4), 28 * u)
	rrect(r, UiPalette.OUTLINE, 28 * u)
	rrect(r.grow(-4 * u), Color("173024"), 24 * u)
	rrect(Rect2(r.position + Vector2(4, 4) * u, Vector2(r.size.x - 8 * u, 10 * u)), Color(1, 1, 1, 0.06), 8 * u)
	_draw_stage()
	_draw_ladder()
	_draw_buttons()
	_draw_coins()


func _draw_stage() -> void:
	var u := _u
	var s := _stage
	rrect(s, Color("0f2219"), 20 * u, int(3 * u), Color(GREEN, 0.25))
	# felt pattern
	for k in 7:
		var y := s.position.y + (k + 0.5) * s.size.y / 7.0
		draw_line(Vector2(s.position.x + 16 * u, y), Vector2(s.end.x - 16 * u, y), Color(1, 1, 1, 0.025), 2.0 * u)
	# info plates: bank now / a bust keeps
	var rung := int(round(_marker)) if _busy else int(state.get("rung", 0))
	var ph := 34.0 * u
	var pw := (s.size.x - 30.0 * u) * 0.5
	var bank := Rect2(s.position + Vector2(10 * u, 10 * u), Vector2(pw, ph))
	var keep := Rect2(Vector2(bank.end.x + 10 * u, bank.position.y), Vector2(pw, ph))
	rrect(bank, Color(0, 0, 0, 0.35), 12 * u)
	rrect(keep, Color(0, 0, 0, 0.35), 12 * u)
	var fs := int(clampf(15.0 * u, 11.0, 30.0))
	text_c(bank.position + Vector2(bank.size.x * 0.5, ph * 0.3), "BANK", int(fs * 0.75), UiPalette.TEXT_DIM, 0, false)
	text_c(bank.position + Vector2(bank.size.x * 0.5, ph * 0.68), "+%d" % _prize(_lit), fs, CASH_COL, int(4 * u))
	text_c(keep.position + Vector2(keep.size.x * 0.5, ph * 0.3), "BUST KEEPS", int(fs * 0.75), UiPalette.TEXT_DIM, 0, false)
	_shield(keep.position + Vector2(keep.size.x * 0.5 - 22 * u, ph * 0.68), 9.0 * u)
	text_c(keep.position + Vector2(keep.size.x * 0.5 + 6 * u, ph * 0.68), "+%d" % _prize(HighLow.safety(rung)), fs, Color("9fd8ff"), int(4 * u))
	# the die
	var c := _die_c
	var ds := _die_s
	var idle := not _busy and not _over()
	var bob := sin(time * 2.2) * 4.0 * u if idle else 0.0
	var hgt := clampf(-_die_off.y / (ds * 0.75), 0.0, 1.0)
	draw_set_transform(c + Vector2(0, ds * 0.62), 0.0, Vector2(1.0 - 0.35 * hgt, 0.3 * (1.0 - 0.35 * hgt)))
	draw_circle(Vector2.ZERO, ds * 0.52, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	var pulse := 0.5 + 0.5 * sin(time * 3.0)
	if idle:
		glow(c, ds * 1.05, Color(GREEN, 0.35 + 0.2 * pulse))
	if _die_flash.a > 0.01:
		glow(c + _die_off, ds * 1.2, _die_flash)
	_die3d(c + _die_off + Vector2(0, bob), ds, _die_val, _die_rot + (sin(time * 1.3) * 0.04 if idle else 0.0), _die_sq)
	# the die's value, big, under it (readable at a glance)
	if not _die_spin:
		var nf := int(clampf(ds * 0.24, 16.0, 60.0))
		text_c(c + Vector2(0, ds * 0.86), "ROLLED %d" % _die_val if not _over() else "LAST ROLL %d" % _die_val, int(nf * 0.62), UiPalette.TEXT_DIM, int(3 * u))
	# history strip
	var hist: Array = state.get("history", [])
	var n := mini(hist.size(), 6)
	var hs := minf(26.0 * u, (s.size.x - 30 * u) / 6.0 - 6 * u)
	var hy := s.end.y - hs * 0.5 - 16.0 * u
	if n == 0:
		text_c(Vector2(s.get_center().x, hy), "higher or lower?", int(clampf(15 * u, 11, 30)), Color(1, 1, 1, 0.3), 0, false)
	for k in n:
		var h: Dictionary = hist[hist.size() - n + k]
		var x := s.get_center().x + (k - (n - 1) * 0.5) * (hs + 8.0 * u)
		var newest := k == n - 1
		var pop := 1.0 + (0.4 * maxf(0.0, 1.0 - (time - _hist_t) / 0.3) if newest and not _busy else 0.0)
		var rs := hs * pop
		var res := String(h.result)
		var rc := HIGH_COL if res == "up" else (BUST_COL if res == "bust" else Color("aab4c8"))
		die_face(Rect2(Vector2(x, hy) - Vector2(rs, rs) * 0.5, Vector2(rs, rs)), int(h.roll))
		draw_rect(Rect2(Vector2(x - rs * 0.4, hy + rs * 0.58), Vector2(rs * 0.8, 4 * u)), rc)
		# the guess arrow above
		var up := String(h.guess) == "higher"
		_arrow(Vector2(x, hy - rs * 0.78), 6.0 * u, up, rc)
	# the end stamp
	if _stamp != "":
		_draw_stamp()


func _draw_stamp() -> void:
	var u := _u
	var k := clampf((time - _stamp_t) / 0.25, 0.0, 1.0)
	var sc := 1.0 + 1.2 * (1.0 - ease(k, 0.3))
	var c := _stage.get_center() + Vector2(0, -_stage.size.y * 0.06)
	var bust := _stamp == "bust"
	var col := BUST_COL if bust else CASH_COL
	var title := "BUST!" if bust else ("TOP RUNG!" if _stamp == "top" else "CASHED OUT")
	var sub := ("KEPT +%d" if bust else "+%d") % _stamp_amt
	var w := _stage.size.x * 0.9
	var h := 84.0 * u
	draw_set_transform(c, -0.12, Vector2(sc, sc))
	var br := Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h))
	rrect(br.grow(4 * u), UiPalette.OUTLINE, 16 * u)
	rrect(br, col.darkened(0.55), 14 * u, int(4 * u), col)
	var tf := int(clampf(w * 0.13, 16.0, 56.0))
	text_c(Vector2(0, -h * 0.17), title, tf, col.lightened(0.3), int(5 * u))
	text_c(Vector2(0, h * 0.24), sub, int(tf * 0.8), Color.WHITE, int(5 * u))
	draw_set_transform(Vector2.ZERO)


## A chunky 3D die: a thick body (the side faces) under the top face with its pips.
func _die3d(c: Vector2, s: float, v: int, rot: float, sq: Vector2) -> void:
	draw_set_transform(c + Vector2(0, s * 0.5 * (1.0 - sq.y)), rot, sq)
	var face := Rect2(Vector2(-s * 0.5, -s * 0.5), Vector2(s, s))
	var depth := Vector2(s * 0.09, s * 0.13)
	rrect(face.grow(s * 0.04), UiPalette.OUTLINE, s * 0.24)
	rrect(Rect2(face.position + depth, face.size).grow(s * 0.04), UiPalette.OUTLINE, s * 0.24)
	rrect(Rect2(face.position + depth, face.size), UiPalette.DIE_EDGE.darkened(0.25), s * 0.2)
	rrect(Rect2(face.position + depth * 0.5, face.size), UiPalette.DIE_EDGE, s * 0.2)
	die_face(face, v)
	# glossy corner
	draw_circle(face.position + Vector2(s * 0.2, s * 0.17), s * 0.06, Color(1, 1, 1, 0.55))
	draw_set_transform(Vector2.ZERO)


func _draw_ladder() -> void:
	var u := _u
	var L := _ladder
	var off := _ladder_off
	rrect(L, Color("0c1a14"), 20 * u)
	var prizes := _prizes()
	var n := prizes.size()
	var rail_l := L.position.x + L.size.x * 0.17 + off.x
	var rail_r := L.position.x + L.size.x * 0.66 + off.x
	var top_y := rung_y(n - 1) - _step * 0.55
	var bot_y := L.end.y - 6.0 * u
	# the top rung's glow (the chest)
	var cp := _rung_icon_center(n - 1)
	glow(cp, _step * 1.6, Color(1.0, 0.8, 0.35, 0.45 + 0.2 * sin(time * 2.5)))
	# rungs (planks) first, rails over them
	for r in n:
		var y := rung_y(r) + off.y
		var broken := _broken.has(r)
		var safe := _is_safe(r)
		var cur := r == _lit and not broken
		var passed := r < _lit
		var ph := _step * 0.5
		var pr := Rect2(Vector2(rail_l - 4 * u, y - ph * 0.5), Vector2(rail_r - rail_l + 8 * u, ph))
		var wood := Color("b9824a")
		if safe:
			wood = Color("5f8fc8")
		if r == n - 1:
			wood = Color("e0a93a")
		if not passed and not cur and not safe and r != n - 1:
			wood = wood.darkened(0.3)
		if broken:
			var cut := pr.size.x * (0.42 + 0.1 * sin(r * 3.1))
			var drop := clampf((time - float(_broken[r])) / 0.35, 0.0, 1.0) * 8.0 * u
			var a := Rect2(pr.position, Vector2(cut - 5 * u, ph))
			var b := Rect2(pr.position + Vector2(cut + 5 * u, drop), Vector2(pr.size.x - cut - 5 * u, ph))
			for q in [a, b]:
				rrect(q.grow(2 * u), UiPalette.OUTLINE, 5 * u)
				rrect(q, Color("5a4030"), 4 * u)
			var jag := PackedVector2Array([Vector2(a.end.x, a.position.y), Vector2(a.end.x + 4 * u, y - ph * 0.1),
				Vector2(a.end.x - 2 * u, y + ph * 0.15), Vector2(a.end.x, a.end.y)])
			draw_polyline(jag, UiPalette.OUTLINE, 2.0 * u, true)
		else:
			if cur:
				glow(Vector2(pr.get_center().x, y), pr.size.x * 0.75, Color(GREEN, 0.5 + 0.25 * sin(time * 5.0)))
			rrect(pr.grow(2.5 * u), UiPalette.OUTLINE, 6 * u)
			rrect(pr, wood.darkened(0.25), 5 * u)
			rrect(Rect2(pr.position, Vector2(pr.size.x, pr.size.y * 0.72)), wood, 5 * u)
			rrect(Rect2(pr.position + Vector2(3 * u, 2 * u), Vector2(pr.size.x - 6 * u, pr.size.y * 0.2)), Color(1, 1, 1, 0.2), 3 * u)
			if cur:
				rrect(pr.grow(3.5 * u), Color(0, 0, 0, 0), 7 * u, int(3 * u), Color(GREEN.lightened(0.4), 0.8 + 0.2 * sin(time * 6.0)))
		# the prize on the plank
		var fs := int(clampf(ph * 0.82, 10.0, 34.0))
		var tc := Color.WHITE if (passed or cur) else Color(1, 1, 1, 0.6)
		if broken:
			tc = Color(1, 1, 1, 0.3)
		text_c(Vector2(pr.position.x + pr.size.x * 0.62, y + (0.0 if not broken else 2 * u)), "+%d" % int(prizes[r]), fs, tc, int(maxf(3.0, 3.5 * u)))
		# safety shield at the left end
		if safe:
			_shield(Vector2(L.position.x + L.size.x * 0.085 + off.x, y), minf(_step * 0.36, 13.0 * u), cur)
		# the prize icon to the right
		var ic := _rung_icon_center(r) + off
		var isz := _step * (1.05 if r < n - 1 else 1.5)
		var alpha := 1.0 if (passed or cur or r == n - 1) else 0.55
		if broken:
			alpha = 0.3
		if cur:
			isz *= 1.0 + 0.08 * sin(time * 5.0)
		_icon(r, ic, isz, alpha)
	# rails
	for x in [rail_l, rail_r]:
		var rr := Rect2(Vector2(x - 5 * u, top_y), Vector2(10 * u, bot_y - top_y))
		rrect(rr.grow(2.5 * u), UiPalette.OUTLINE, 6 * u)
		rrect(rr, Color("8a5a30"), 5 * u)
		draw_rect(Rect2(rr.position + Vector2(2 * u, 4 * u), Vector2(3 * u, rr.size.y - 8 * u)), Color(1, 1, 1, 0.18))
	# twinkles around the chest
	for k in 3:
		var a := time * 1.2 + k * TAU / 3.0
		var tw := 0.5 + 0.5 * sin(time * 4.0 + k * 2.0)
		_star4(cp + Vector2(cos(a), sin(a) * 0.6) * _step * 0.9, (3.0 + 4.0 * tw) * u, Color(1, 1, 0.8, 0.8 * tw))
	# the hero token on its rung
	_draw_token()


func _marker_x() -> float:
	return _ladder.position.x + _ladder.size.x * 0.3 + _ladder_off.x


func _rung_icon_center(r: int) -> Vector2:
	return Vector2(_ladder.position.x + _ladder.size.x * 0.84, rung_y(r))


func _draw_token() -> void:
	var u := _u
	var y := rung_y(_marker) + _ladder_off.y - _hop * _step * 0.5
	var idle := not _busy and not _over()
	var bob := absf(sin(time * 3.0)) * 3.0 * u if idle else 0.0
	var ts := _step * 1.25
	var base := Vector2(_marker_x(), y - _step * 0.2 - bob)
	var tex := ModelIcons.get_icon(ModelIcons.K + TOKEN, 20.0)
	draw_set_transform(base + Vector2(0, 3 * u), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, ts * 0.28, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if tex:
		draw_texture_rect(tex, Rect2(base - Vector2(ts * 0.5, ts * 0.92), Vector2(ts, ts)), false)
	else:
		var head := base + Vector2(0, -ts * 0.66)
		var body := PackedVector2Array([base + Vector2(-ts * 0.22, 0), base + Vector2(ts * 0.22, 0), head + Vector2(ts * 0.1, ts * 0.12),
			head + Vector2(-ts * 0.1, ts * 0.12)])
		draw_colored_polygon(body, Color("ffd24a"))
		draw_polyline(body + PackedVector2Array([body[0]]), UiPalette.OUTLINE, 2.5 * u, true)
		draw_circle(head, ts * 0.15 + 2.5 * u, UiPalette.OUTLINE)
		draw_circle(head, ts * 0.15, Color("ffe07a"))


func _icon(r: int, c: Vector2, s: float, a: float) -> void:
	var spec: Array = ICONS[clampi(r, 0, ICONS.size() - 1)]
	var tex := ModelIcons.get_icon(ModelIcons.K + String(spec[0]), float(spec[1]))
	if tex:
		draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, a))
		return
	var col: Color = ICON_COLS[clampi(r, 0, ICON_COLS.size() - 1)]
	draw_circle(c, s * 0.3 + 2.0, Color(UiPalette.OUTLINE, a))
	draw_circle(c, s * 0.3, Color(col, a))
	draw_circle(c + Vector2(-s * 0.1, -s * 0.1), s * 0.09, Color(1, 1, 1, 0.5 * a))


## A little heater shield with a keyhole (the safety rungs).
func _shield(c: Vector2, r: float, hot := false) -> void:
	var pts := PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(r, r * 0.1), c + Vector2(0, r * 1.2),
		c + Vector2(-r, r * 0.1)])
	if hot:
		glow(c, r * 2.6, Color(0.6, 0.85, 1.0, 0.6))
	draw_colored_polygon(pts, Color("5aa7ff"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), UiPalette.OUTLINE, maxf(2.0, r * 0.25), true)
	draw_circle(c + Vector2(0, -r * 0.2), r * 0.26, UiPalette.OUTLINE)
	draw_rect(Rect2(c + Vector2(-r * 0.1, -r * 0.2), Vector2(r * 0.2, r * 0.6)), UiPalette.OUTLINE)


func _arrow(c: Vector2, r: float, up: bool, col: Color) -> void:
	var d := -1.0 if up else 1.0
	var pts := PackedVector2Array([c + Vector2(0, d * r), c + Vector2(r, -d * r * 0.6), c + Vector2(-r, -d * r * 0.6)])
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), UiPalette.OUTLINE, maxf(1.5, r * 0.3), true)


func _draw_buttons() -> void:
	var u := _u
	var v := _die_val
	for i in 3:
		var r := _btns[i]
		var ok := can_press(i)
		var col: Color = [HIGH_COL, LOW_COL, CASH_COL][i]
		var dead := (i == 0 and v >= 6) or (i == 1 and v <= 1) or _over()
		if dead:
			col = UiPalette.DISABLED
		var pk := clampf((time - float(_press.get(i, -10.0))) / 0.18, 0.0, 1.0)
		var down := (1.0 - pk) * 5.0 * u
		var hov := _hover == i and ok
		var scale := 1.0
		if i == 2 and ok:
			# the cash button pulses harder the more is at stake
			var stake := float(int(state.get("rung", 0))) / 8.0
			scale = 1.0 + (0.015 + 0.04 * stake) * (0.5 + 0.5 * sin(time * (3.0 + 4.0 * stake)))
		var c := r.get_center()
		draw_set_transform(c, 0.0, Vector2(scale, scale))
		var lr := Rect2(-r.size * 0.5, r.size)
		var lip := 7.0 * u
		rrect(Rect2(lr.position + Vector2(0, lip), lr.size).grow(3 * u), UiPalette.OUTLINE, 16 * u)
		rrect(Rect2(lr.position + Vector2(0, lip), lr.size), col.darkened(0.45), 14 * u)
		var face := Rect2(lr.position + Vector2(0, down + (2.0 * u if hov else 0.0) * 0.0), lr.size)
		if hov:
			face.position.y -= 2.0 * u
		rrect(face.grow(3 * u), UiPalette.OUTLINE, 16 * u)
		rrect(face, col.lightened(0.12) if hov else col, 14 * u)
		rrect(Rect2(face.position + Vector2(6 * u, 4 * u), Vector2(face.size.x - 12 * u, face.size.y * 0.26)), Color(1, 1, 1, 0.25), 9 * u)
		var fs := int(clampf(face.size.y * 0.3, 14.0, 40.0))
		var sub_fs := int(clampf(face.size.y * 0.2, 11.0, 28.0))
		var tcol := Color.WHITE if not dead else Color(1, 1, 1, 0.45)
		var fc := face.get_center()
		if i < 2:
			var guess := String(BTN[i])
			var ar := fs * 0.42
			var label := "HIGHER" if i == 0 else "LOWER"
			var font := UiTheme.display_font()
			var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var total := lw + ar * 2.0 + 6.0 * u
			var lx := fc.x - total * 0.5
			_arrow(Vector2(lx + ar, fc.y - face.size.y * 0.14), ar, i == 0, Color.WHITE if not dead else Color(1, 1, 1, 0.4))
			text_c(Vector2(lx + ar * 2.0 + 6.0 * u + lw * 0.5, fc.y - face.size.y * 0.14), label, fs, tcol, int(maxf(3.0, 4.0 * u)))
			var od := odds_text(v, guess) if not _over() else "-"
			var oc := odds_color(v, guess) if not dead else Color(1, 1, 1, 0.4)
			var pill := Rect2(Vector2(fc.x - face.size.x * 0.4, fc.y + face.size.y * 0.06), Vector2(face.size.x * 0.8, face.size.y * 0.3))
			rrect(pill, Color(0, 0, 0, 0.35), pill.size.y * 0.5)
			text_c(pill.get_center(), od, sub_fs, oc, 0, false)
		else:
			var amt := _prize(_lit)
			text_c(Vector2(fc.x, fc.y - face.size.y * 0.14), "CASH OUT", fs, tcol if not dead else tcol, int(maxf(3.0, 4.0 * u)))
			var pill := Rect2(Vector2(fc.x - face.size.x * 0.36, fc.y + face.size.y * 0.06), Vector2(face.size.x * 0.72, face.size.y * 0.3))
			rrect(pill, Color(0, 0, 0, 0.35), pill.size.y * 0.5)
			_coin(Vector2(pill.position.x + pill.size.y * 0.7, pill.get_center().y), pill.size.y * 0.34)
			text_c(pill.get_center() + Vector2(pill.size.y * 0.3, 0), "+%d" % amt, sub_fs, Color("fff0b0") if not dead else Color(1, 1, 1, 0.4), 0, false)
			if ok:
				# a sheen sweeping the gold
				var sk := fposmod(time * 0.7, 2.2) - 0.6
				var sx := face.position.x + sk * face.size.x
				var band := PackedVector2Array([Vector2(sx, face.position.y), Vector2(sx + 18 * u, face.position.y),
					Vector2(sx - 6 * u, face.end.y), Vector2(sx - 24 * u, face.end.y)])
				clipped(band, rect_poly(face.grow(-4 * u)), Color(1, 1, 1, 0.3))
		draw_set_transform(Vector2.ZERO)


func _coin(c: Vector2, r: float, rot := 0.0) -> void:
	var sx := absf(cos(rot)) * 0.8 + 0.2
	_ellipse(c, Vector2(r + 2.0, r + 2.0) * Vector2(sx, 1.0) + Vector2(2.0 * (1.0 - sx), 0), UiPalette.OUTLINE)
	_ellipse(c, Vector2(r * sx, r), Color("e8a21c"))
	_ellipse(c + Vector2(0, -r * 0.08), Vector2(r * sx, r) * 0.78, Color("ffd24a"))
	draw_circle(c + Vector2(-r * 0.25 * sx, -r * 0.3), r * 0.2 * sx, Color(1, 1, 1, 0.6))


func _ellipse(c: Vector2, rad: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y))
	draw_colored_polygon(pts, col)


func _draw_coins() -> void:
	for c: Dictionary in _coins:
		if time < float(c.t):
			continue
		_coin(c.p, 9.0 * _u, float(c.rot))

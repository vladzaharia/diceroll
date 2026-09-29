class_name MgBoard
extends Control
## Base for the four minigame boards (Fossil Hunter, Bubble Breaker, Scratch-off, Claw
## Machine). A board draws the core's PUBLIC state only, turns taps into minigame_action
## args (signal act) and animates each minigame_update. It never decides an outcome: every
## reveal, pop and grab comes from the update event.
##
## Shared juice: a cheap 2D particle system (chunks, sparks, flakes, rings), floating texts,
## screen-shake, and cached StyleBoxes for rounded shapes.

## The player acted: args for GameFlow.minigame_action.
signal act(args: Array)
## Something worth a screen-level kick happened (strength 0..1): the screen flashes/shakes.
signal kick(strength: float, color: Color)

var state: Dictionary = {}
## Presentation speed (the controller's game speed). Swings/aim timing never scale.
var speed := 1.0
## True while an action is in flight (sent, update not played yet) or the game is over.
var locked := false
## Seconds since the board was built (idle wobble, sheens).
var time := 0.0

var _parts: Array = []
var _texts: Array = []
var _rings: Array = []
var _shake := 0.0
var _pending := -1.0
var _boxes := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


## Shows a public state. instant: no animation (open / restore / resync).
func set_state(st: Dictionary, _instant := true) -> void:
	state = st.duplicate(true)
	queue_redraw()


## Animates one minigame_update event (state + info), then adopts its state.
func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	set_state(ev.get("state", {}), true)


## True when no local animation is still running (the screen waits for this before it
## cashes the game in).
func is_settled() -> bool:
	return true


## Board-specific text for the header subline (e.g. "Chain x2"). Empty = none.
func status_text() -> String:
	return ""


## Sends an action once (locks until the update arrives or a short timeout on refusal).
func send(args: Array) -> void:
	if locked:
		return
	locked = true
	_pending = 1.2
	act.emit(args)


func unlock() -> void:
	_pending = -1.0
	locked = bool(state.get("done", false)) or int(state.get("actions_left", 0)) <= 0


## Plays an Audio sfx if the autoload exists (UI scripts stay loadable without it).
static func sfx(id: String, pitch_var := 0.05, volume_db := 0.0) -> void:
	var loop := Engine.get_main_loop() as SceneTree
	var a: Node = loop.root.get_node_or_null("Audio") if loop else null
	if a != null and a.has_method("play_sfx"):
		a.call("play_sfx", id, pitch_var, volume_db)


func dur(t: float) -> float:
	return t / maxf(speed, 0.25)


func wait(t: float) -> void:
	if not is_inside_tree() or t <= 0.0:
		return
	await get_tree().create_timer(dur(t), false).timeout


# --- juice -----------------------------------------------------------------------------

## Particles: kind "chunk" (gravity squares), "spark" (glowing dots), "flake" (spinning
## rects), "puff" (soft growing circles), "star" (4-point twinkles).
func burst(at: Vector2, color: Color, n: int, kind := "spark", spd := 260.0, up := 0.0, size := 7.0) -> void:
	for i in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(0.35, 1.0) * spd + Vector2(0, -up)
		var life := randf_range(0.45, 0.9) * (1.6 if kind == "puff" else 1.0)
		_parts.append({"p": at, "v": v, "life": life, "max": life, "col": color.lerp(Color.WHITE, randf() * 0.25),
			"size": size * randf_range(0.6, 1.3), "kind": kind, "rot": randf() * TAU, "spin": randf_range(-9.0, 9.0),
			"g": 900.0 if kind in ["chunk", "flake"] else (-40.0 if kind == "puff" else 120.0)})


func ring(at: Vector2, color: Color, radius := 60.0, life := 0.45, width := 6.0) -> void:
	_rings.append({"p": at, "col": color, "r": radius, "life": life, "max": life, "w": width})


func float_text(at: Vector2, text: String, color: Color, size := 34, life := 1.0) -> void:
	_texts.append({"p": at, "text": text, "col": color, "size": size, "life": life, "max": life})


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(dt: float) -> void:
	time += dt
	if _pending > 0.0:
		_pending -= dt
		if _pending <= 0.0:
			unlock()
	var sdt := dt * clampf(speed, 1.0, 3.0)
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		p.life -= sdt
		if p.life <= 0.0:
			_parts.remove_at(i)
			continue
		p.v.y += p.g * sdt
		p.v *= 1.0 - (2.5 if p.kind == "puff" else 0.6) * sdt
		p.p += p.v * sdt
		p.rot += p.spin * sdt
	for i in range(_texts.size() - 1, -1, -1):
		_texts[i].life -= sdt
		if _texts[i].life <= 0.0:
			_texts.remove_at(i)
	for i in range(_rings.size() - 1, -1, -1):
		_rings[i].life -= sdt
		if _rings[i].life <= 0.0:
			_rings.remove_at(i)
	_shake = maxf(0.0, _shake - dt * 40.0)
	_tick(dt)
	queue_redraw()


## Per-frame hook for subclasses (animations that are not tweens).
func _tick(_dt: float) -> void:
	pass


func _draw() -> void:
	var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake if _shake > 0.0 else Vector2.ZERO
	draw_set_transform(off)
	_draw_board()
	_draw_fx()
	draw_set_transform(Vector2.ZERO)


## Override: the game itself.
func _draw_board() -> void:
	pass


func _draw_fx() -> void:
	for r: Dictionary in _rings:
		var k: float = 1.0 - r.life / r.max
		var col: Color = r.col
		col.a *= 1.0 - k
		draw_arc(r.p, r.r * (0.3 + 0.9 * k), 0.0, TAU, 40, col, r.w * (1.0 - k * 0.6), true)
	for p: Dictionary in _parts:
		var k: float = p.life / p.max
		var col: Color = p.col
		match String(p.kind):
			"chunk":
				col.a = minf(1.0, k * 2.5)
				var s: float = p.size
				draw_set_transform(p.p, p.rot)
				draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s * 0.8), col)
				draw_set_transform(Vector2.ZERO)
			"flake":
				col.a = minf(1.0, k * 2.0)
				var s: float = p.size
				draw_set_transform(p.p, p.rot, Vector2(1.0, absf(sin(p.rot * 1.7)) * 0.8 + 0.2))
				draw_rect(Rect2(-s * 0.5, -s * 0.35, s, s * 0.7), col)
				draw_set_transform(Vector2.ZERO)
			"puff":
				col.a *= k * 0.45
				draw_circle(p.p, p.size * (2.4 - k * 1.2), col)
			"star":
				col.a = minf(1.0, k * 2.0)
				_star4(p.p, p.size * (0.6 + 0.6 * k), col)
			_:
				col.a = minf(1.0, k * 1.8)
				draw_circle(p.p, p.size * (0.4 + 0.6 * k), col)
				draw_circle(p.p, p.size * (0.2 + 0.3 * k), Color(1, 1, 1, col.a * 0.8))
	var font := UiTheme.display_font()
	for t: Dictionary in _texts:
		var k: float = 1.0 - t.life / t.max
		var a := clampf((1.0 - k) * 3.0, 0.0, 1.0)
		var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - k * 6.0)
		var fs := int(t.size * pop)
		var pos: Vector2 = t.p + Vector2(0, -70.0 * ease(k, 0.4))
		var w := font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var col: Color = t.col
		col.a = a
		var o := UiPalette.OUTLINE
		o.a = a
		draw_string_outline(font, pos - Vector2(w * 0.5, 0), t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(6, fs / 5), o)
		draw_string(font, pos - Vector2(w * 0.5, 0), t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# --- drawing helpers ---------------------------------------------------------------------

func box(col: Color, radius: float, border := 0, border_col := Color.TRANSPARENT) -> StyleBoxFlat:
	var key := "%s|%d|%d|%s" % [col.to_html(), int(radius), border, border_col.to_html()]
	if _boxes.has(key):
		return _boxes[key]
	var s := StyleBoxFlat.new()
	s.bg_color = col
	s.set_corner_radius_all(int(radius))
	s.corner_detail = 8
	s.anti_aliasing = true
	s.anti_aliasing_size = 1.0
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_col
	if _boxes.size() > 600:
		_boxes.clear()
	_boxes[key] = s
	return s


func rrect(r: Rect2, col: Color, radius: float, border := 0, border_col := Color.TRANSPARENT) -> void:
	draw_style_box(box(col, radius, border, border_col), r)


func text_c(at: Vector2, s: String, size: int, col: Color, outline := 0, display := true, out_col := UiPalette.OUTLINE) -> void:
	var font := UiTheme.display_font() if display else UiTheme.body_font(700)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at + Vector2(-w * 0.5, size * 0.36)
	if outline > 0:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, out_col)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## Soft glow: stacked translucent circles.
func glow(at: Vector2, radius: float, col: Color, steps := 6) -> void:
	for i in steps:
		var k := 1.0 - float(i) / steps
		var c := col
		c.a = col.a * 0.18 * (1.0 - k * 0.5)
		draw_circle(at, radius * k, c)


## Draws `band` clipped to `clip` (both convex), skipping degenerate slivers.
func clipped(band: PackedVector2Array, clip: PackedVector2Array, col: Color) -> void:
	for poly in Geometry2D.intersect_polygons(band, clip):
		if poly.size() < 3:
			continue
		var area := 0.0
		for i in poly.size():
			area += poly[i].cross(poly[(i + 1) % poly.size()])
		if absf(area) > 8.0:
			draw_colored_polygon(poly, col)


static func rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func _star4(at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4.0
		var rr := r if i % 2 == 0 else r * 0.28
		pts.append(at + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, col)


## A die face (pips) in rect r.
func die_face(r: Rect2, v: int, body := UiPalette.DIE_BODY, pip := UiPalette.DIE_PIP) -> void:
	var s := minf(r.size.x, r.size.y)
	var rad := s * 0.2
	rrect(r.grow(s * 0.035), UiPalette.OUTLINE, rad + 2)
	rrect(r, body.darkened(0.25), rad)
	rrect(Rect2(r.position, r.size - Vector2(0, s * 0.07)), body, rad)
	rrect(Rect2(r.position + Vector2(s * 0.1, s * 0.06), Vector2(s * 0.8, s * 0.26)), Color(1, 1, 1, 0.25), rad * 0.8)
	var pips: Array = DieFace.PIPS.get(v, [])
	var inner := Rect2(r.position, r.size - Vector2(0, s * 0.07))
	for p: Vector2 in pips:
		var c := inner.position + inner.size * p
		draw_circle(c, s * 0.085, pip)
		draw_circle(c + Vector2(-s * 0.02, -s * 0.02), s * 0.03, pip.lightened(0.35))

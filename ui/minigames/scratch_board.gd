class_name ScratchBoard
extends MgBoard
## Scratch-off: a lottery card of 9 foil cells over die faces. Touch a cell to spend a
## scratch ([idx]); the core reveals that face (minigame_update) and the finger keeps
## scratching the foil off it; the rest of the foil flakes away once enough is cleared (or
## after a short pause, so a plain tap works too). Unscratched cells keep their foil: the
## faces under them are never known here. Two alike glow; three alike (or three 6s, the
## JACKPOT) sweep the card with a gold shimmer.

const CELLS := 9
const MASK := 56
const BRUSH := 0.17
const AUTO_CLEAR := 0.5

var _card := Rect2()
var _cell := 100.0
var _foil: Array[Image] = []
var _tex: Array[ImageTexture] = []
var _cov: Array[int] = []
var _committed: Array[bool] = []
var _stroke: Array[float] = []
var _revealed_at: Array[float] = []
var _dissolve: Array[float] = []
var _gone: Array[bool] = []
var _dragging := false
var _last_sfx := 0.0
var _last_pt := Vector2.INF
var _match_t := -10.0
var _match_n := 0
static var _base: Image


func _init() -> void:
	super._init()
	for i in CELLS:
		_foil.append(null)
		_tex.append(null)
		_cov.append(0)
		_committed.append(false)
		_stroke.append(-10.0)
		_revealed_at.append(-10.0)
		_dissolve.append(-1.0)
		_gone.append(false)


func set_state(st: Dictionary, instant := true) -> void:
	super.set_state(st, instant)
	var cells: Array = state.get("cells", [])
	for i in CELLS:
		if _foil[i] == null:
			_new_foil(i)
		if i < cells.size() and int(cells[i]) > 0 and instant and not _committed[i]:
			# restored / resynced: already scratched cells show their face
			_gone[i] = true
			_dissolve[i] = -1.0
	if instant:
		_eval_match(true)
	unlock()


func is_settled() -> bool:
	var cells: Array = state.get("cells", [])
	for i in CELLS:
		if i < cells.size() and int(cells[i]) > 0 and not _gone[i]:
			return false
	return time - _match_t > dur(1.2)


func status_text() -> String:
	match String(state.get("outcome", "none")):
		"jackpot": return "JACKPOT!"
		"three": return "Three alike!"
		"pair": return "A pair"
	return ""


func _layout() -> void:
	var header := 70.0
	var footer := 64.0
	var avail := Vector2(size.x - 20.0, size.y - header - footer)
	var cw := minf(avail.x, avail.y * 0.92)
	_cell = (cw - 64.0) / 3.0
	var ch := _cell * 3.0 + 64.0 + 88.0
	_card = Rect2(Vector2((size.x - cw) * 0.5, header + (size.y - header - footer - ch) * 0.5 + 10.0), Vector2(cw, ch))


func cell_rect(i: int) -> Rect2:
	var x := i % 3
	var y := i / 3
	var o := _card.position + Vector2(32, 104)
	return Rect2(o + Vector2(x, y) * _cell, Vector2(_cell, _cell)).grow(-7.0)


func cell_at(p: Vector2) -> int:
	for i in CELLS:
		if cell_rect(i).has_point(p):
			return i
	return -1


# --- foil ------------------------------------------------------------------------------

static func _foil_base() -> Image:
	if _base:
		return _base
	var img := Image.create(MASK, MASK, false, Image.FORMAT_RGBA8)
	for y in MASK:
		for x in MASK:
			var u := float(x) / MASK
			var v := float(y) / MASK
			var g := 0.72 + 0.16 * (1.0 - v) + 0.06 * sin((u + v) * 22.0)
			# embossed 4-point star in the middle
			var d := Vector2(u - 0.5, v - 0.5)
			var star := absf(d.x) * absf(d.y) * 40.0 + d.length() * 1.6
			var emb := 0.0
			if star < 0.42:
				emb = 0.1 if d.x + d.y < 0.0 else -0.08
			var c := Color(g + emb, g + emb + 0.01, g + emb + 0.04)
			# rounded corners (transparent) so the foil sits inside the cell
			var cx := minf(x, MASK - 1 - x)
			var cy := minf(y, MASK - 1 - y)
			var a := 1.0
			if cx < 7 and cy < 7:
				var dd := Vector2(7 - cx, 7 - cy).length()
				a = clampf(7.5 - dd, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	_base = img
	return img


func _new_foil(i: int) -> void:
	_foil[i] = _foil_base().duplicate()
	_tex[i] = ImageTexture.create_from_image(_foil[i])
	_cov[i] = 0


## Clears foil around local point p (cell coords 0..1). Returns true if anything changed.
func _scratch(i: int, p: Vector2) -> bool:
	var img := _foil[i]
	var c := p * MASK
	var r := BRUSH * MASK
	var changed := false
	for y in range(maxi(0, int(c.y - r)), mini(MASK, int(c.y + r) + 1)):
		for x in range(maxi(0, int(c.x - r)), mini(MASK, int(c.x + r) + 1)):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > r:
				continue
			var px := img.get_pixel(x, y)
			if px.a > 0.05:
				var na := px.a * clampf((d / r - 0.55) * 2.2, 0.0, 1.0)
				if na < 0.05:
					na = 0.0
					_cov[i] += 1
				img.set_pixel(x, y, Color(px.r, px.g, px.b, na))
				changed = true
	if changed:
		_tex[i].update(img)
	return changed


func coverage(i: int) -> float:
	return float(_cov[i]) / float(MASK * MASK * 0.9)


# --- input -----------------------------------------------------------------------------

func _gui_input(e: InputEvent) -> void:
	_layout()
	var mb := e as InputEventMouseButton
	var mm := e as InputEventMouseMotion
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		_dragging = mb.pressed
		_last_pt = Vector2.INF
		if mb.pressed:
			_touch(mb.position, true)
		return
	if mm and _dragging:
		# fill the gap between motion events so fast strokes stay continuous
		var from := _last_pt if _last_pt != Vector2.INF else mm.position
		var n := maxi(1, int(from.distance_to(mm.position) / (_cell * 0.06)))
		for k in n:
			_touch(from.lerp(mm.position, float(k + 1) / n), false)


func _touch(p: Vector2, first: bool) -> void:
	_last_pt = p
	var i := cell_at(p)
	if i < 0:
		return
	var cells: Array = state.get("cells", [])
	var face := int(cells[i]) if i < cells.size() else 0
	if not _committed[i] and face == 0:
		if locked or int(state.get("actions_left", 0)) <= 0:
			if first:
				MgBoard.sfx("error")
				float_text(cell_rect(i).get_center(), "No scratches left", UiPalette.TEXT_DIM, 24, 0.8)
			return
		_committed[i] = true
		MgBoard.sfx("scratch")
		send([i])
	if _gone[i] or _dissolve[i] >= 0.0:
		return
	var r := cell_rect(i)
	if _scratch(i, (p - r.position) / r.size):
		_stroke[i] = time
		if time - _last_sfx > 0.09:
			_last_sfx = time
			MgBoard.sfx("scratch", 0.15, -6.0)
			burst(p, Color(0.85, 0.87, 0.92), 3, "flake", 160.0, 60.0, 6.0)


# --- events ----------------------------------------------------------------------------

func play_update(ev: Dictionary) -> void:
	_pending = -1.0
	var info: Dictionary = ev.get("info", {})
	var i := int(info.get("idx", -1))
	state = (ev.get("state", {}) as Dictionary).duplicate(true)
	if i >= 0 and i < CELLS:
		_revealed_at[i] = time
		if not _committed[i]:
			# played without a finger (AUTO, scripted): quick automatic scratch
			_committed[i] = true
			_stroke[i] = time - 0.7
			var r := cell_rect(i)
			for k in 5:
				_scratch(i, Vector2(0.2 + 0.15 * k, 0.3 + 0.1 * (k % 2)))
			burst(r.get_center(), Color(0.85, 0.87, 0.92), 10, "flake", 220.0, 80.0, 7.0)
			MgBoard.sfx("scratch")
	await wait(0.05)
	unlock()


func _tick(_dt: float) -> void:
	var cells: Array = state.get("cells", [])
	for i in CELLS:
		var face := int(cells[i]) if i < cells.size() else 0
		if face <= 0 or _gone[i]:
			continue
		if _dissolve[i] < 0.0:
			var idle := time - _stroke[i]
			if coverage(i) >= AUTO_CLEAR or (idle > dur(0.75) and time - _revealed_at[i] > dur(0.25)):
				_dissolve[i] = time
				var r := cell_rect(i)
				burst(r.get_center(), Color(0.86, 0.88, 0.94), 16, "flake", 300.0, 140.0, 9.0)
				burst(r.get_center(), Color("fff3c0"), 8, "star", 200.0, 40.0, 9.0)
				MgBoard.sfx("reveal")
		elif time - _dissolve[i] > dur(0.3):
			_gone[i] = true
			_eval_match(false)


func _eval_match(instant: bool) -> void:
	var shown: Array = []
	var cells: Array = state.get("cells", [])
	for i in CELLS:
		shown.append(int(cells[i]) if i < cells.size() and _gone[i] else 0)
	var best := MgLogic.scratch_best(shown)
	var n := int(best.count)
	if n >= 2 and n > _match_n:
		_match_n = n
		if instant:
			_match_t = time - 5.0
			return
		_match_t = time
		var mid := Vector2.ZERO
		for c in best.cells:
			mid += cell_rect(int(c)).get_center()
		mid /= float(best.cells.size())
		if n >= 3:
			var jack := int(best.face) == 6
			float_text(mid, "JACKPOT!!" if jack else "THREE ALIKE!", Color("ffe07a"), 54 if jack else 46, 1.6)
			MgBoard.sfx("win")
			burst(mid, Color("ffd24a"), 40, "flake", 520.0, 260.0, 10.0)
			burst(mid, Color.WHITE, 20, "star", 380.0, 100.0, 12.0)
			shake(10.0)
			kick.emit(1.0, Color(1.0, 0.85, 0.35, 0.5))
		else:
			float_text(mid, "PAIR!", Color("bfe3ff"), 44, 1.2)
			MgBoard.sfx("coin")
			burst(mid, Color("bfe3ff"), 16, "star", 260.0, 40.0, 9.0)
			kick.emit(0.35, Color(0.7, 0.85, 1.0, 0.3))


# --- drawing ---------------------------------------------------------------------------

func _draw_board() -> void:
	_layout()
	var cells: Array = state.get("cells", [])
	var left := int(state.get("actions_left", 0))
	var shown: Array = []
	for i in CELLS:
		shown.append(int(cells[i]) if i < cells.size() and _gone[i] else 0)
	var best := MgLogic.scratch_best(shown)
	var jackpot := int(best.count) >= 3
	# scratch coins
	var cx := size.x * 0.5 - 60.0
	for k in 3:
		var p := Vector2(cx + k * 60.0, 36)
		var used := k >= left
		draw_circle(p + Vector2(0, 3), 22, Color(0, 0, 0, 0.35))
		draw_circle(p, 22, UiPalette.OUTLINE)
		draw_circle(p, 19, Color("7a7a8a") if used else Color("f2b84b"))
		draw_circle(p, 13, Color("5c5c6a") if used else Color("ffdc7a"))
		if not used:
			_star4(p, 9.0, Color("b8761f"))
	# the card
	var c := _card
	var glow_k := 0.0
	if jackpot:
		glow_k = 0.6 + 0.3 * sin(time * 5.0)
		glow(c.get_center(), c.size.x * 0.75, Color(1.0, 0.8, 0.3, glow_k))
	rrect(Rect2(c.position + Vector2(0, 10), c.size), Color(0, 0, 0, 0.4), 30)
	rrect(c.grow(4.0), UiPalette.OUTLINE, 32)
	rrect(c, Color("fff4dc"), 28, 6, Color("e0a33a") if not jackpot else Color("ffe07a"))
	rrect(c.grow(-14.0), Color(0, 0, 0, 0), 20, 2, Color(0.88, 0.62, 0.22, 0.6))
	# guilloche stripes
	for k in 12:
		var yy := c.position.y + 18 + k * (c.size.y - 36) / 12.0
		draw_line(Vector2(c.position.x + 20, yy), Vector2(c.end.x - 20, yy + 6), Color(0.9, 0.7, 0.45, 0.12), 2.0, true)
	# title banner
	var tb := Rect2(c.position + Vector2(40, 22), Vector2(c.size.x - 80, 64))
	rrect(tb, Color("7a2fbf"), 20, 3, UiPalette.OUTLINE)
	rrect(Rect2(tb.position + Vector2(6, 5), Vector2(tb.size.x - 12, 20)), Color(1, 1, 1, 0.18), 12)
	text_c(tb.get_center() + Vector2(0, -2), "LUCKY  SIX", 40, Color("ffe07a"), 8)
	for s in 2:
		_star_deco(Vector2(tb.position.x + 30 + s * (tb.size.x - 60), tb.get_center().y))
	# cells
	for i in CELLS:
		_draw_cell(i, int(cells[i]) if i < cells.size() else 0, best)
	# legend
	var ly := c.end.y + 36.0
	var lx := size.x * 0.5
	var fs := 20
	text_c(Vector2(lx - 150, ly), "PAIR", fs, Color("bfe3ff"), 5)
	text_c(Vector2(lx - 40, ly), "3 ALIKE", fs, Color("ffd24a"), 5)
	for k in 3:
		die_face(Rect2(Vector2(lx + 58 + k * 30, ly - 13), Vector2(26, 26)), 6)
	text_c(Vector2(lx + 190, ly), "JACKPOT", fs, Color("ff9ae0"), 5)
	# jackpot shimmer band sweeping across the card
	if jackpot:
		var k := fposmod((time - _match_t) * 0.8, 1.6) - 0.3
		var x0 := c.position.x + k * c.size.x * 1.4
		var band := PackedVector2Array([Vector2(x0, c.position.y - 40), Vector2(x0 + 90, c.position.y - 40),
			Vector2(x0 - 110, c.end.y + 40), Vector2(x0 - 200, c.end.y + 40)])
		clipped(band, rect_poly(c), Color(1.0, 0.95, 0.7, 0.28))


func _draw_cell(i: int, face: int, best: Dictionary) -> void:
	var r := cell_rect(i)
	var in_match := int(best.count) >= 2 and (best.cells as Array).has(i)
	# paper under the foil
	rrect(r.grow(3.0), Color(0.55, 0.38, 0.2, 0.5), 16)
	rrect(r, Color("fffaf0"), 14)
	for k in 4:
		draw_line(r.position + Vector2(8, 12 + k * r.size.y / 4.0), r.position + Vector2(r.size.x - 8, 12 + k * r.size.y / 4.0),
			Color(0.9, 0.8, 0.65, 0.35), 1.5)
	if face > 0:
		var k := 1.0
		if _dissolve[i] >= 0.0:
			var t := clampf((time - _dissolve[i]) / dur(0.3), 0.0, 1.0)
			k = 1.0 + 0.2 * sin(t * PI)
		if in_match:
			var mk := clampf((time - _match_t) / 0.4, 0.0, 1.0)
			var gc := Color("ffd24a") if int(best.count) >= 3 else Color("8fd0ff")
			glow(r.get_center(), r.size.x * (0.6 + 0.08 * sin(time * 6.0)), Color(gc.r, gc.g, gc.b, 0.9 * mk))
			rrect(r.grow(2.0), Color(0, 0, 0, 0), 16, 5, Color(gc.r, gc.g, gc.b, mk))
			k *= 1.0 + 0.05 * sin(time * 8.0) * mk
		var ds := r.size.x * 0.64 * k
		var body := UiPalette.DIE_BODY
		if face == 6 and in_match and int(best.count) >= 3:
			body = Color("ffe9a8")
		die_face(Rect2(r.get_center() - Vector2(ds, ds) * 0.5, Vector2(ds, ds)), face, body)
	else:
		# unknown (never revealed locally): a faint stamp
		text_c(r.get_center(), "?", int(r.size.x * 0.4), Color(0.85, 0.75, 0.6, 0.35))
	# foil
	if not _gone[i] and _tex[i] != null:
		var a := 1.0
		var grow := 0.0
		if _dissolve[i] >= 0.0:
			var t := clampf((time - _dissolve[i]) / dur(0.3), 0.0, 1.0)
			a = 1.0 - t
			grow = 10.0 * t
		draw_texture_rect(_tex[i], r.grow(grow), false, Color(1, 1, 1, a))
		if _dissolve[i] < 0.0:
			# moving foil sheen
			var sk := fposmod(time * 0.45 + i * 0.13, 1.4) - 0.2
			var sx := r.position.x + sk * r.size.x
			var band := PackedVector2Array([Vector2(sx, r.position.y), Vector2(sx + 16, r.position.y),
				Vector2(sx - 14, r.end.y), Vector2(sx - 30, r.end.y)])
			clipped(band, rect_poly(r), Color(1, 1, 1, 0.22 * a))
			if not _committed[i] and not locked and int(state.get("actions_left", 0)) > 0:
				text_c(r.get_center() + Vector2(0, r.size.y * 0.33), "SCRATCH", 16, Color(0.4, 0.42, 0.5, 0.75))


func _star_deco(at: Vector2) -> void:
	_star4(at, 14.0 + 2.0 * sin(time * 4.0), Color("ffe07a"))
	_star4(at, 7.0, Color.WHITE)

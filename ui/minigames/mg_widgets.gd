class_name MgWidgets
extends RefCounted
## Small widgets for the minigame screens: the par meter (a pack Regular bar), the tier
## trophies (pack icons trophy_gold / silver / bronze; they replace the drawn Medal), the
## per-game title plaque with the game's icon, and the result-beat flavour face.


## Horizontal performance meter: score / median on a 0 .. MAX scale with the bronze,
## silver and gold zones (MinigameDefs.TIER_SILVER / TIER_GOLD). `value` animates. (No PAR
## tick: players play every minigame; AUTO's par result is a sim-only approximation.)
class ParMeter:
	extends Control
	const MAX := 1.6
	var value := 0.0:
		set(v):
			value = v
			queue_redraw()
	var show_labels := true
	var thick := 22.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(240, 58)

	func set_value(v: float, animate := true, time := 0.5) -> void:
		v = clampf(v, 0.0, MAX)
		if not animate or not is_inside_tree():
			value = v
			return
		var t := create_tween()
		t.tween_property(self, "value", v, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func _x(r: float) -> float:
		return 12.0 + (size.x - 24.0) * clampf(r / MAX, 0.0, 1.0)

	func _draw() -> void:
		var y := 10.0
		var h := thick
		var bar := Rect2(Vector2(12, y), Vector2(size.x - 24, h))
		var fx := _x(value)
		var fill := Rect2(Vector2(12, y), Vector2(fx - 12.0, h))
		var boxes := UiTheme.bar_boxes("par")
		if bool(boxes.skinned):
			# pack Regular bar: grey-darker track, yellow fill inset in the rim
			draw_style_box(boxes.bg, bar.grow(4.0))
			if fill.size.x > h * 0.6:
				draw_style_box(boxes.fill, Rect2(bar.position - Vector2(4, 4), Vector2(fill.size.x + 8.0, h + 8.0)))
		else:
			draw_style_box(UiTheme.box(UiPalette.OUTLINE, int(h * 0.5) + 3), bar.grow(3.0))
			var zones := [[0.0, MinigameDefs.TIER_SILVER, MgLogic.TIER_COLORS.bronze], [MinigameDefs.TIER_SILVER, MinigameDefs.TIER_GOLD, MgLogic.TIER_COLORS.silver],
				[MinigameDefs.TIER_GOLD, MAX, MgLogic.TIER_COLORS.gold]]
			for z in zones:
				var zr := Rect2(Vector2(_x(float(z[0])), y), Vector2(_x(float(z[1])) - _x(float(z[0])), h))
				var c: Color = z[2]
				draw_rect(zr, c.darkened(0.62))
			if fill.size.x > 1.0:
				var tier := MinigameDefs.tier_for(value)
				var fc: Color = MgLogic.TIER_COLORS[tier]
				draw_style_box(UiTheme.box(fc, int(h * 0.5)), fill)
				draw_style_box(UiTheme.box(Color(1, 1, 1, 0.3), int(h * 0.3)), Rect2(fill.position + Vector2(4, 3), Vector2(maxf(fill.size.x - 8, 1), h * 0.3)))
		# zone dividers
		for r: float in [MinigameDefs.TIER_SILVER, MinigameDefs.TIER_GOLD]:
			draw_line(Vector2(_x(r), y - 2), Vector2(_x(r), y + h + 2), UiPalette.OUTLINE, 3.0)
		# needle
		draw_circle(Vector2(fx, y + h * 0.5), h * 0.62, UiPalette.OUTLINE)
		draw_circle(Vector2(fx, y + h * 0.5), h * 0.46, Color.WHITE)
		if show_labels:
			# tier labels: a small trophy + the word, centred in each zone
			var f := UiTheme.body_font(700)
			var fs := 17
			var ip := 22.0
			var ly := y + h + 22.0
			for item in [["BRONZE", 0.4, MgLogic.TIER_COLORS.bronze, "trophy_bronze"], ["SILVER", 1.0, MgLogic.TIER_COLORS.silver, "trophy_silver"],
					["GOLD", 1.4, MgLogic.TIER_COLORS.gold, "trophy_gold"]]:
				var s := String(item[0])
				var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var tex: Texture2D = Icons.texture(String(item[3]), int(ip)) if Icons.is_mapped(String(item[3])) else null
				var tw := w + (ip + 4.0 if tex != null else 0.0)
				var x0 := clampf(_x(float(item[1])) - tw * 0.5, 0.0, size.x - tw)
				if tex != null:
					draw_texture_rect(tex, Rect2(Vector2(x0, ly - ip + 4.0), Vector2(ip, ip)), false)
					x0 += ip + 4.0
				draw_string(f, Vector2(x0, ly), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, item[2])


## The tier trophy (pack icon trophy_gold / trophy_silver / trophy_bronze) as a TextureRect
## `px` tall: the result beat (150 px) and the reward modal (96 px). Without the pack it is
## the legacy trophy glyph in the tier colour.
static func trophy(tier: String, px := 150) -> TextureRect:
	var id := "trophy_" + (tier if tier in ["gold", "silver", "bronze"] else "silver")
	var r := Icons.rect(id, px) if Icons.is_mapped(id) else Icons.rect("trophy", px, MgLogic.TIER_COLORS.get(tier, UiPalette.GOLD))
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return r


## Result-beat flavour face (spec 5 rule 8: the one emoji use in minigames), or null when the
## icon map has no face for it. `jackpot` = a scratch-off / plinko jackpot; `bust` = scored 0.
static func face(tier: String, bust := false, jackpot := false, px := 64) -> TextureRect:
	var id := "mg_face_" + ("jackpot" if jackpot else ("bust" if bust else tier))
	if not Icons.is_mapped(id):
		return null
	return Icons.rect(id, px)


## Pack plaque family per game (native faces only, never modulate): the nearest of the pack's
## colours to MgLogic.GAME_COLORS.
const PLAQUE_FAMILY := {"fossil_hunter": "yellow", "bubble_breaker": "blue", "scratch_off": "purple",
	"claw_machine": "pink", "bubble_shooter": "blue", "plinko": "forestgreen", "shell_game": "yellow",
	"memory_match": "purple", "fishing": "blue", "lucky_wheel": "red", "high_low": "green"}


## The minigame's title plaque: the pack 3D face in the game's family with its mg_* icon and
## the name in ink Lilita. Without the pack: the pre-reskin Ribbon look (with the icon).
class Plaque:
	extends Control
	const H := 84.0
	const ICON := 52.0
	const PAD := 28.0
	var text := "":
		set(v):
			text = v
			update_minimum_size()
			queue_redraw()
	var icon := "":
		set(v):
			icon = v
			update_minimum_size()
			queue_redraw()
	var family := "yellow":
		set(v):
			family = v
			queue_redraw()
	var color: Color = UiPalette.GOLD
	var font_size := 40
	var max_width := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func skinned() -> bool:
		return UiSkin.has("plaque_" + family)

	func fitted_font() -> int:
		var fs := font_size
		if max_width <= 0.0:
			return fs
		var avail := max_width - PAD * 2.0 - ICON - 10.0
		var f := UiTheme.display_font()
		while fs > 26 and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
			fs -= 1
		return fs

	func _get_minimum_size() -> Vector2:
		var w := UiTheme.display_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_font()).x
		w += PAD * 2.0 + (ICON + 10.0 if icon != "" else 0.0)
		if max_width > 0.0:
			w = minf(w, max_width)
		return Vector2(w, H)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var face_mid := size.y * (4.0 + 46.0 * 0.5) / 64.0
		if skinned():
			draw_style_box(UiTheme.plaque_box(family), r)
		else:
			face_mid = size.y * 0.46
			draw_style_box(UiTheme.box(color.darkened(0.15), 22, 4, UiPalette.OUTLINE), Rect2(0, 0, size.x, size.y * 0.92))
		var f := UiTheme.display_font()
		var fs := fitted_font()
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var iw := ICON + 10.0 if icon != "" else 0.0
		var x := (size.x - tw - iw) * 0.5
		if icon != "":
			var tex := Icons.texture(icon, int(ICON))
			if tex != null:
				var ts := tex.get_size()
				var k := ICON / maxf(ts.x, ts.y)
				draw_texture_rect(tex, Rect2(Vector2(x + (ICON - ts.x * k) * 0.5, face_mid - ts.y * k * 0.5), ts * k), false)
			x += iw
		var base := face_mid + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		var ink := UiPalette.INK_LABEL if skinned() else UiPalette.TEXT
		if not skinned():
			draw_string_outline(f, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, UiPalette.OUTLINE)
		draw_string(f, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


## DEPRECATED: the drawn tier medal. The reskin uses MgWidgets.trophy(); kept only until the
## minigame reward modal (slice c) switches over.
class Medal:
	extends Control
	var tier := "silver":
		set(v):
			tier = v
			queue_redraw()
	var shine := 0.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(150, 170)

	func _process(dt: float) -> void:
		_t += dt
		queue_redraw()

	func _draw() -> void:
		var col: Color = MgLogic.TIER_COLORS.get(tier, MgLogic.TIER_COLORS.silver)
		var s := minf(size.x, size.y / 1.12)
		var c := Vector2(size.x * 0.5, s * 0.46)
		var r := s * 0.4
		# ribbon tails
		for sgn in [-1.0, 1.0]:
			var base := c + Vector2(sgn * r * 0.35, r * 0.6)
			var tail := PackedVector2Array([base + Vector2(-r * 0.22, 0), base + Vector2(r * 0.22, 0),
				base + Vector2(r * 0.22 + sgn * r * 0.15, r * 0.95), base + Vector2(sgn * r * 0.15, r * 0.78),
				base + Vector2(-r * 0.22 + sgn * r * 0.15, r * 0.95)])
			draw_colored_polygon(tail, Color("c0304a") if sgn < 0 else Color("3a6fd8"))
			draw_polyline(tail + PackedVector2Array([tail[0]]), UiPalette.OUTLINE, 3.0, true)
		# glow and disc
		for k in 6:
			var gc := col
			gc.a = 0.08 * (6 - k) * (0.7 + 0.3 * sin(_t * 3.0))
			draw_circle(c, r * (1.25 + k * 0.06), gc)
		draw_circle(c, r * 1.06, UiPalette.OUTLINE)
		draw_circle(c, r, col.darkened(0.35))
		draw_circle(c + Vector2(0, -r * 0.04), r * 0.92, col)
		draw_arc(c, r * 0.76, 0.0, TAU, 40, col.darkened(0.25), r * 0.06, true)
		# star emboss
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI * 0.5 + i * PI / 5.0
			var rr := r * (0.55 if i % 2 == 0 else 0.24)
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, col.darkened(0.3))
		var pts2 := PackedVector2Array()
		for p in pts:
			pts2.append(p + (c - p) * 0.12 + Vector2(0, -2))
		draw_colored_polygon(pts2, col.lightened(0.35))
		# gloss + moving shine
		draw_arc(c, r * 0.84, PI * 1.1, PI * 1.6, 16, Color(1, 1, 1, 0.55), r * 0.08, true)
		var sk := fposmod(_t * 0.6, 1.8) - 0.4
		var sx := c.x - r + sk * r * 2.0
		var band := PackedVector2Array([Vector2(sx, c.y - r), Vector2(sx + r * 0.25, c.y - r), Vector2(sx - r * 0.25, c.y + r), Vector2(sx - r * 0.5, c.y + r)])
		var disc := PackedVector2Array()
		for i in 28:
			disc.append(c + Vector2(cos(TAU * i / 28.0), sin(TAU * i / 28.0)) * r * 0.92)
		for poly in Geometry2D.intersect_polygons(band, disc):
			var area := 0.0
			for i in poly.size():
				area += poly[i].cross(poly[(i + 1) % poly.size()])
			if poly.size() >= 3 and absf(area) > 8.0:
				draw_colored_polygon(poly, Color(1, 1, 1, 0.35))

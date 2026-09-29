class_name MgWidgets
extends RefCounted
## Small drawn widgets for the minigame screens: the par meter and the tier medal.


## Horizontal performance meter: score / median on a 0 .. MAX scale with the bronze,
## silver and gold zones (MinigameDefs.TIER_SILVER / TIER_GOLD) and a PAR tick (AUTO's
## result). `value` animates; `target` is where it is heading.
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
		draw_style_box(UiTheme.box(UiPalette.OUTLINE, int(h * 0.5) + 3), bar.grow(3.0))
		var zones := [[0.0, MinigameDefs.TIER_SILVER, MgLogic.TIER_COLORS.bronze], [MinigameDefs.TIER_SILVER, MinigameDefs.TIER_GOLD, MgLogic.TIER_COLORS.silver],
			[MinigameDefs.TIER_GOLD, MAX, MgLogic.TIER_COLORS.gold]]
		for z in zones:
			var zr := Rect2(Vector2(_x(float(z[0])), y), Vector2(_x(float(z[1])) - _x(float(z[0])), h))
			var c: Color = z[2]
			draw_rect(zr, c.darkened(0.62))
		# fill
		var fx := _x(value)
		var fill := Rect2(Vector2(12, y), Vector2(fx - 12.0, h))
		if fill.size.x > 1.0:
			var tier := MinigameDefs.tier_for(value)
			var fc: Color = MgLogic.TIER_COLORS[tier]
			draw_style_box(UiTheme.box(fc, int(h * 0.5)), fill)
			draw_style_box(UiTheme.box(Color(1, 1, 1, 0.3), int(h * 0.3)), Rect2(fill.position + Vector2(4, 3), Vector2(maxf(fill.size.x - 8, 1), h * 0.3)))
		# zone dividers and the par tick
		for r: float in [MinigameDefs.TIER_SILVER, MinigameDefs.TIER_GOLD]:
			draw_line(Vector2(_x(r), y - 2), Vector2(_x(r), y + h + 2), UiPalette.OUTLINE, 3.0)
		var px := _x(MinigameDefs.PAR)
		draw_line(Vector2(px, y - 6), Vector2(px, y + h + 6), Color.WHITE, 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(px - 7, y - 10), Vector2(px + 7, y - 10), Vector2(px, y - 2)]), Color.WHITE)
		# needle
		draw_circle(Vector2(fx, y + h * 0.5), h * 0.62, UiPalette.OUTLINE)
		draw_circle(Vector2(fx, y + h * 0.5), h * 0.46, Color.WHITE)
		if show_labels:
			var f := UiTheme.body_font(700)
			var fs := 17
			var ly := y + h + 22.0
			for item in [["BRONZE", 0.4, MgLogic.TIER_COLORS.bronze], ["SILVER", 1.0, MgLogic.TIER_COLORS.silver], ["GOLD", 1.4, MgLogic.TIER_COLORS.gold]]:
				var s := String(item[0])
				var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(f, Vector2(_x(float(item[1])) - w * 0.5, ly), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, item[2])
			var pw := f.get_string_size("PAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(f, Vector2(px - pw * 0.5, y - 12), "PAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.85))


## Tier medal: a ribboned disc (bronze / silver / gold) with an embossed star and a sweeping
## shine. `pop` scales it (stamp animation).
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
			draw_colored_polygon(poly, Color(1, 1, 1, 0.35))

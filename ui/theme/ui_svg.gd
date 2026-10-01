class_name UiSvg
extends RefCounted
## Shared SVG plumbing for the RhosGFX reskin (Icons registry + UiSkin theme loader).
##
## Paths: manifests (ui/icons/icon_map.json, ui/theme/ui_pack.json) name source files relative
## to third_party/ ("rhosgfx/vector-icon-pack-pro/Currency/Coin/Coin.svg"). tools/import_assets.sh
## copies each referenced file to a runtime folder under a sanitised name:
##
##   runtime_path("icons", "rhosgfx/vector-icon-pack-pro/Currency/Star Gem/Star Gem.svg")
##     -> "res://assets/ui/icons/vector-icon-pack-pro/currency/star_gem/star_gem.svg"
##   runtime_path("pack", "rhosgfx/cartoony-ui-pack-full/Buttons/3D/Square/3. Yellow/x_hover.svg")
##     -> "res://assets/ui/pack/cartoony-ui-pack-full/buttons/3d/square/3_yellow/x_hover.svg"
##
## (the same rule lives in tools/import_assets.sh; tests/test_ui_skin.gd pins both.)
##
## Textures: SVGs become DPITexture (Godot 4.5+), which re-rasterises the vector at the
## viewport's oversampling (stretch scale x --ui-scale x display density), so one texture is
## crisp on a 1366x768 laptop, a 1080p desktop, an @2x phone and a 150% zoom alike, and works
## as a StyleBoxTexture 9-slice. See docs/design/2026-09-30-svg-ui-pipeline.md for the
## measurements behind that choice. MODE_RASTER (fixed ImageTexture at RASTER_OVERSAMPLE x,
## mipmapped) is kept for comparison / as an escape hatch.

enum Mode { DPI, RASTER }

## Texture flavour for every UiSkin / Icons texture (see header).
static var mode: Mode = Mode.DPI
## MODE_RASTER only: raster density relative to the logical size.
const RASTER_OVERSAMPLE := 2.0

const ROOTS := {"icons": "res://assets/ui/icons/", "pack": "res://assets/ui/pack/"}
## Runtime roots in use (tests point these at user:// fixtures).
static var roots: Dictionary = ROOTS.duplicate()

static var _src: Dictionary = {}
static var _size: Dictionary = {}
static var _palette: Dictionary = {}
static var _re_seg: RegEx
static var _re_hex: RegEx
static var _re_vb: RegEx
static var _re_wh: RegEx


# ---------------------------------------------------------------- paths

## Sanitised runtime path of a manifest `svg` entry. kind: "icons" | "pack".
static func runtime_path(kind: String, tp_path: String) -> String:
	return String(roots.get(kind, roots["icons"])) + sanitize(tp_path)


## "rhosgfx/Foo Pack/3. Yellow/Star Gem 2.5.svg" -> "foo_pack/3_yellow/star_gem_2_5.svg":
## drops a leading "rhosgfx/", lowercases, and turns every run of characters outside
## [a-z0-9-] into "_" (per path segment, extension kept, "_" trimmed at both ends).
static func sanitize(tp_path: String) -> String:
	if _re_seg == null:
		_re_seg = RegEx.create_from_string("[^a-z0-9-]+")
	var p := tp_path.strip_edges().replace("\\", "/")
	if p.begins_with("rhosgfx/"):
		p = p.substr(8)
	var out := PackedStringArray()
	var segs := p.split("/", false)
	for i in segs.size():
		var s := segs[i].to_lower()
		var ext := ""
		if i == segs.size() - 1 and s.get_extension() != "":
			ext = "." + s.get_extension()
			s = s.get_basename()
		s = _re_seg.sub(s, "_", true).lstrip("_").rstrip("_")
		out.append(s + ext)
	return "/".join(out)


## Raw SVG text of a runtime file ("" when missing). Cached.
static func source(path: String) -> String:
	if _src.has(path):
		return _src[path]
	var s := ""
	if FileAccess.file_exists(path):
		s = fix_rgba(FileAccess.get_file_as_string(path))
	_src[path] = s
	return s


## ThorVG ignores the alpha of CSS rgba() colours, so a transparent helper rect such as
## `fill: rgba(26, 26, 26, 0)` renders as an opaque black square behind the icon. Rewrites
## `fill` / `stroke: rgba(r,g,b,0)` to `none` and other alphas to `#rrggbb` plus a matching
## `fill-opacity` / `stroke-opacity`, in <style> CSS, style="" and presentation attributes;
## any other rgba() (stop-color, ...) becomes its opaque hex.
static func fix_rgba(svg: String) -> String:
	if not svg.contains("rgba("):
		return svg
	var num := "\\s*([0-9.]+)\\s*"
	var rgba := "rgba\\(%s,%s,%s,%s\\)" % [num, num, num, num]
	# CSS declarations (in <style> and style="")
	var css := RegEx.create_from_string("(fill|stroke)\\s*:\\s*" + rgba)
	svg = _sub_each(svg, css, func(m: RegExMatch) -> String:
		var prop := m.get_string(1)
		var a := float(m.get_string(5))
		if a <= 0.001:
			return prop + ": none"
		return "%s: %s; %s-opacity: %s" % [prop, _rgba_hex(m), prop, _trim_num(a)])
	# presentation attributes: fill="rgba(...)"
	var attr := RegEx.create_from_string("(fill|stroke)=\"" + rgba + "\"")
	svg = _sub_each(svg, attr, func(m: RegExMatch) -> String:
		var prop := m.get_string(1)
		var a := float(m.get_string(5))
		if a <= 0.001:
			return prop + "=\"none\""
		return "%s=\"%s\" %s-opacity=\"%s\"" % [prop, _rgba_hex(m), prop, _trim_num(a)])
	var rest := RegEx.create_from_string(rgba)
	return _sub_each(svg, rest, func(m: RegExMatch) -> String: return _rgba_hex(m))


static func _rgba_hex(m: RegExMatch) -> String:
	var n := m.get_group_count()
	var r := clampi(int(float(m.get_string(n - 3))), 0, 255)
	var g := clampi(int(float(m.get_string(n - 2))), 0, 255)
	var b := clampi(int(float(m.get_string(n - 1))), 0, 255)
	return "#%02x%02x%02x" % [r, g, b]


static func _trim_num(x: float) -> String:
	return String.num(x, 3)


## Replaces every match of `re` in `text` with `f.call(match)`.
static func _sub_each(text: String, re: RegEx, f: Callable) -> String:
	var out := ""
	var at := 0
	for m in re.search_all(text):
		out += text.substr(at, m.get_start() - at) + String(f.call(m))
		at = m.get_end()
	return out + text.substr(at)


static func exists(path: String) -> bool:
	return source(path) != ""


## Intrinsic size (SVG user units) from the root viewBox, else width/height, else 24x24.
static func svg_size(svg: String) -> Vector2:
	if _size.has(svg.hash()):
		return _size[svg.hash()]
	if _re_vb == null:
		_re_vb = RegEx.create_from_string("<svg[^>]*?viewBox\\s*=\\s*[\"']\\s*([-0-9.eE]+)[ ,]+([-0-9.eE]+)[ ,]+([0-9.eE]+)[ ,]+([0-9.eE]+)")
		_re_wh = RegEx.create_from_string("<svg[^>]*?\\swidth\\s*=\\s*[\"']([0-9.]+)[^\"']*[\"'][^>]*?\\sheight\\s*=\\s*[\"']([0-9.]+)")
	var v := Vector2(24, 24)
	var m := _re_vb.search(svg)
	if m:
		v = Vector2(float(m.get_string(3)), float(m.get_string(4)))
	else:
		m = _re_wh.search(svg)
		if m:
			v = Vector2(float(m.get_string(1)), float(m.get_string(2)))
	_size[svg.hash()] = v
	return v


# ---------------------------------------------------------------- colour

## Manifest colour: null / "" -> null, "#rrggbb[aa]" -> Color, "palette:NAME" -> a UiPalette
## constant (case-insensitive; "palette:RARITY.rare" indexes a dictionary constant).
## Unknown names warn once and resolve to null (= no tint).
static func color(v: Variant) -> Variant:
	if v is Color:
		return v
	if v == null or not v is String or String(v).strip_edges() == "":
		return null
	var s := String(v).strip_edges()
	if s.begins_with("palette:"):
		return palette(s.substr(8))
	if Color.html_is_valid(s):
		return Color.html(s)
	push_warning("UiSvg: bad colour '%s'" % s)
	return null


static func palette(name: String) -> Variant:
	if _palette.is_empty():
		var sc: Script = load("res://ui/theme/palette.gd")
		_palette = sc.get_script_constant_map()
	var parts := name.split(".", false, 1)
	var v: Variant = _palette.get(parts[0].to_upper(), null)
	if parts.size() > 1 and v is Dictionary:
		v = (v as Dictionary).get(parts[1], (v as Dictionary).get(parts[1].to_lower(), null))
		if v is Array and not (v as Array).is_empty():
			for e in v:
				if e is Color:
					v = e
					break
	if v is Color:
		return v
	push_warning("UiSvg: unknown palette colour '%s'" % name)
	return null


## Bakes a multiply tint (and optional desaturation) into the SVG text: every #rgb / #rrggbb
## fill / stroke / stop colour, in attributes and in <style> CSS alike (RhosGFX files use CSS
## classes, which DPITexture.color_map does not reach). White source art becomes exactly
## `tint`; coloured art is multiplied, like CanvasItem.modulate. Alpha in `tint` is ignored
## here (use modulate for fades).
static func recolor(svg: String, tint: Variant = null, saturation: float = 1.0) -> String:
	if not tint is Color and saturation >= 1.0:
		return svg
	if _re_hex == null:
		_re_hex = RegEx.create_from_string("(?<=[:\"'\\s=,])#([0-9a-fA-F]{6}|[0-9a-fA-F]{3})(?![0-9a-zA-Z_-])")
	var out := ""
	var at := 0
	for m in _re_hex.search_all(svg):
		var c := Color.html(m.get_string(1))
		if saturation < 1.0:
			var g := c.get_luminance()
			c = Color(g, g, g).lerp(c, clampf(saturation, 0.0, 1.0))
		if tint is Color:
			var t: Color = tint
			c = Color(c.r * t.r, c.g * t.g, c.b * t.b)
		out += svg.substr(at, m.get_start() - at) + "#" + c.to_html(false)
		at = m.get_end()
	return out + svg.substr(at)


## Removes <text> elements. ThorVG (Godot's SVG rasteriser) drops them anyway, so a keycap
## from vector-keyboard-controls renders as a blank cap: strip it explicitly and draw the
## label with a Label on top. tools/import_ui_svgs.py does the same at import for entries with
## "strip_text": true, and reports every other imported file that contains <text>.
static func strip_text(svg: String) -> String:
	if not svg.contains("<text"):
		return svg
	return RegEx.create_from_string("<text\\b[^>]*/>|<text\\b[\\s\\S]*?</text\\s*>").sub(svg, "", true)


## The SVG turned `deg` clockwise (multiples of 90): vertical scroll tracks from horizontal
## bar art. The viewBox swaps for 90 / 270.
static func rotate(svg: String, deg: int) -> String:
	var d := posmod(deg, 360)
	if d == 0 or d % 90 != 0:
		return svg
	var sz := svg_size(svg)
	var o := _viewbox_origin(svg)
	var out := sz if d == 180 else Vector2(sz.y, sz.x)
	# rotate about the origin, then shift the rotated box back into positive space
	var shift := {90: Vector2(sz.y, 0), 180: sz, 270: Vector2(0, sz.x)}[d] as Vector2
	var g := "<g transform=\"translate(%s %s) rotate(%d) translate(%s %s)\">%s</g>" \
		% [shift.x, shift.y, d, -o.x, -o.y, _inner(svg)]
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%s\" height=\"%s\" viewBox=\"0 0 %s %s\">%s</svg>" \
		% [out.x, out.y, out.x, out.y, g]


# ---------------------------------------------------------------- composition

## One SVG from several (bottom first), each [svg_text, offset Vector2 in SVG units] or
## [svg_text, offset, scale]; the result's viewBox is the union of the parts (shifted to start
## at 0,0). Class names and ids are prefixed per part, so the pack's shared ".cls-1" CSS
## classes don't collide. (Toggle = container + handle, icon + corner badge, ...)
static func compose(parts: Array) -> String:
	if parts.is_empty():
		return ""
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in parts:
		var o: Vector2 = p[1]
		var k: float = float(p[2]) if (p as Array).size() > 2 else 1.0
		lo = lo.min(o)
		hi = hi.max(o + svg_size(String(p[0])) * k)
	# ThorVG honours only the first <style> element: hoist every part's (prefixed) CSS into one.
	var css := ""
	var body := ""
	var re_style := RegEx.create_from_string("<style[^>]*>([\\s\\S]*?)</style>")
	for i in parts.size():
		var src := _prefix(String(parts[i][0]), "p%d-" % i)
		for m in re_style.search_all(src):
			css += m.get_string(1)
		src = re_style.sub(src, "", true)
		var o: Vector2 = parts[i][1] - lo
		var k: float = float(parts[i][2]) if (parts[i] as Array).size() > 2 else 1.0
		var vb := _viewbox_origin(src)
		body += "<g transform=\"translate(%s %s) scale(%s) translate(%s %s)\">%s</g>" \
			% [o.x, o.y, k, -vb.x, -vb.y, _inner(src)]
	var sz := hi - lo
	var defs := "<defs><style>%s</style></defs>" % css if css != "" else ""
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%s\" height=\"%s\" viewBox=\"0 0 %s %s\">%s%s</svg>" \
		% [sz.x, sz.y, sz.x, sz.y, defs, body]


## `base` with `badge` composited in a corner ("br", "bl", "tr", "tl"), the badge's longer side
## = `scale` x the base's longer side (icon_map "badge": {"svg", "corner", "scale"}).
static func with_badge(base: String, badge: String, corner: String = "br", scale: float = 0.45) -> String:
	var bs := svg_size(base)
	var gs := svg_size(badge)
	var k := scale * maxf(bs.x, bs.y) / maxf(gs.x, gs.y)
	var g := gs * k
	var off := Vector2(bs.x - g.x if corner.ends_with("r") else 0.0, bs.y - g.y if corner.begins_with("b") else 0.0)
	return compose([[base, Vector2.ZERO], [badge, off, k]])


## Contents of the root <svg> element (XML prolog, root tag and <title> dropped).
static func _inner(svg: String) -> String:
	var a := svg.find("<svg")
	a = svg.find(">", a) + 1 if a >= 0 else 0
	var b := svg.rfind("</svg>")
	return svg.substr(a, (b if b > a else svg.length()) - a)


static func _viewbox_origin(svg: String) -> Vector2:
	svg_size(svg)
	var m := _re_vb.search(svg)
	return Vector2(float(m.get_string(1)), float(m.get_string(2))) if m else Vector2.ZERO


## Prefixes CSS class selectors, class attributes, ids and #id references with `pre`.
static func _prefix(svg: String, pre: String) -> String:
	var out := svg
	for m in RegEx.create_from_string("(<style[^>]*>)([\\s\\S]*?)(</style>)").search_all(svg):
		var css := RegEx.create_from_string("\\.([A-Za-z_][A-Za-z0-9_-]*)").sub(m.get_string(2), "." + pre + "$1", true)
		out = out.replace(m.get_string(0), m.get_string(1) + css + m.get_string(3))
	for m in RegEx.create_from_string("class=\"([^\"]*)\"").search_all(out):
		var toks := PackedStringArray()
		for t in m.get_string(1).split(" ", false):
			toks.append(pre + t)
		out = out.replace(m.get_string(0), "class=\"" + " ".join(toks) + "\"")
	out = RegEx.create_from_string("\\bid=\"([^\"]*)\"").sub(out, "id=\"" + pre + "$1\"", true)
	out = RegEx.create_from_string("url\\(#([^)]*)\\)").sub(out, "url(#" + pre + "$1)", true)
	return RegEx.create_from_string("href=\"#([^\"]*)\"").sub(out, "href=\"#" + pre + "$1\"", true)


# ---------------------------------------------------------------- textures

## Texture of an SVG string at `scale` logical px per SVG unit (size = viewBox x scale).
static func make_texture(svg: String, scale: float) -> Texture2D:
	if svg == "":
		return null
	scale = maxf(scale, 0.01)
	if mode == Mode.DPI:
		return DPITexture.create_from_string(svg, scale)
	var img := Image.new()
	if img.load_svg_from_string(svg, scale * RASTER_OVERSAMPLE) != OK:
		return null
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	t.set_size_override(Vector2i((svg_size(svg) * scale).round()))
	return t


## Fixed-size raster (ImageTexture, px along the longer side) for places that sample the
## texture themselves (shader uniforms, legacy draw code): same contract as UiIcons.tex.
static func raster(svg: String, px: int) -> Texture2D:
	if svg == "":
		return null
	var sz := svg_size(svg)
	var img := Image.new()
	if img.load_svg_from_string(svg, float(px) / maxf(sz.x, sz.y)) != OK:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Test / hot-reload hook.
static func clear_cache() -> void:
	_src.clear()
	_size.clear()

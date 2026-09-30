class_name Icons
extends RefCounted
## Icon registry for the RhosGFX reskin: a drop-in superset of UiIcons.
##
## Ids are the game's existing icon ids ("heart", "coin", "rune_frost", "class_ninja",
## "3d:coins", ...); the map may override "3d:" ids too (else they stay RenderedIcons PNGs). ui/icons/icon_map.json (owned by the UI designer) maps an id to a RhosGFX
## SVG; every id that is not mapped, or whose SVG was not imported (fresh clone, paid pack
## absent), falls back to the current drawn glyph (UiIcons), so call sites migrate one by one
## and nothing ever renders empty or crashes.
##
##   Icons.texture("coin", 40)              # crisp resolution-independent texture (DPITexture)
##   Icons.rect("heart", 48)                # ready-made TextureRect (was UiIcons.rect)
##   Icons.rect("skull", 32, UiPalette.HP)  # explicit tint (see "Tint" below)
##   Icons.tex("rune_frost", 64)            # fixed raster at 64 px (was UiIcons.tex: shader
##                                          # uniforms, custom _draw code)
##   Icons.rect("chest", 48, {"saturation": 0.0})   # greyed-out / locked (opts: tint, saturation)
##   Icons.is_mapped("coin")                # true once the designer's map covers it
##
## Migrating a call site is a rename: UiIcons.rect / .tex / .exists / .class_icon /
## .biome_icon / .mechanic_icon / .rune_icon / .intent_icon / .default_color all exist here
## with the same signatures.
##
## Tint (icon_map "tint"): null = keep the SVG's own colours (full-colour art; caller tints
## are ignored, since legacy call sites pass glyph colours); "#hex" / "palette:NAME" = a
## default multiply tint baked into the vector (use the pack's "Flat White" variants), which
## an explicit caller tint overrides; "palette:auto" = the legacy per-id colour
## (UiIcons.default_color: rune / class / biome / intent colours).
##
## Map format (paths relative to third_party/):
##   {"version": 1, "icons": {"coin": {"svg": "rhosgfx/vector-icon-pack-pro/Currency/Coin/Coin.svg",
##                                     "tint": null, "note": "HUD gold counter"}},
##    "input_glyphs": {"key_space": {"svg": "rhosgfx/vector-keyboard-controls/...", "strip_text": true}}}
## "input_glyphs" ids share the id space ("icons" win a clash). Optional entry keys:
##   "strip_text": true    drop the SVG's <text> (Godot renders none; UiSvg.strip_text), so a
##                         keycap is a blank background for a Label
##   "saturation": 0..1    default saturation (callers' opts override)
##   "badge": {"svg", "corner": "br", "scale": 0.45}   second icon composited in a corner
##   "compact_svg": "..."  alternate art used at <= COMPACT_PX logical px
## ("schema", "missing", "group", "note", "label", ... are documentation / for other code.)

const MAP_PATH := "res://ui/icons/icon_map.json"
## Demo / sample map (tools/import_assets.sh imports it too); only read after use_demo_map().
const DEMO_MAP_PATH := "res://ui/icons/icon_map.demo.json"
## Entries with a "compact_svg" use it at or below this logical size.
const COMPACT_PX := 22

static var _map: Dictionary = {}
static var _loaded := false
static var _cache: Dictionary = {}


# ---------------------------------------------------------------- map

## The merged id -> entry map (lazy-loaded from MAP_PATH).
static func entries() -> Dictionary:
	if not _loaded:
		_loaded = true
		_map = load_map_file(MAP_PATH)
	return _map


## Parses an icon map file; {} (with a warning) when unreadable, {} silently when absent.
static func load_map_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not j.data is Dictionary:
		push_warning("Icons: unreadable %s: %s" % [path, j.get_error_message()])
		return {}
	var out := {}
	# "input_glyphs" (keyboard / mouse glyphs) share the id space; "icons" win on a clash
	for section in ["input_glyphs", "icons"]:
		var sec: Variant = (j.data as Dictionary).get(section, {})
		if sec is Dictionary:
			out.merge(sec, true)
	return out


## Layers another map over the loaded one (its ids win). Used by the ui_skin_demo scenario;
## engineers can use it to preview a map before it lands in icon_map.json.
static func merge_map(extra: Dictionary) -> void:
	var m := entries()
	for id in extra:
		m[id] = extra[id]
	_cache.clear()


static func use_demo_map() -> void:
	merge_map(load_map_file(DEMO_MAP_PATH))


## Test hook: replace the map entirely (null = reload from MAP_PATH on next use).
static func set_map(m: Variant) -> void:
	_loaded = m != null
	_map = m if m is Dictionary else {}
	_cache.clear()


## Runtime path of an id's mapped SVG ("" when unmapped).
static func svg_path(id: String) -> String:
	var e: Variant = entries().get(id, null)
	if not e is Dictionary or String(e.get("svg", "")) == "":
		return ""
	return UiSvg.runtime_path("icons", String(e["svg"]))


## True when the id is mapped AND its SVG is present (i.e. it renders RhosGFX art).
static func is_mapped(id: String) -> bool:
	var p := svg_path(id)
	return p != "" and UiSvg.exists(p)


# ---------------------------------------------------------------- textures

## Resolution-independent texture of logical size `size_px` (longer side). Mapped ids give a
## DPITexture (re-rasterised at the viewport's oversampling: always crisp); unmapped ids give
## the legacy glyph through the same path. "3d:" ids use the map when it has them, else the
## rendered prop PNG (RenderedIcons, at 2x). Cached per id / size / options.
## `opts`: a Color (= tint, the UiIcons signature) or {"tint": Color, "saturation": 0..1}
## (saturation 0 = greyed-out "locked" look).
static func texture(id: String, size_px: int = 48, opts: Variant = null) -> Texture2D:
	var o := _opts(opts)
	if id.begins_with("3d:") and not is_mapped(id):
		return UiIcons.tex(id, size_px * 2, o.tint)
	var key := "t|%s|%d|%s" % [id, size_px, _opts_key(o)]
	if _cache.has(key):
		return _cache[key]
	var svg := _svg(id, o, size_px)
	if svg == "" and not id.begins_with("3d:"):
		svg = _legacy_svg(id, o)
	var t: Texture2D = null
	if svg != "":
		var sz := UiSvg.svg_size(svg)
		t = UiSvg.make_texture(svg, float(size_px) / maxf(sz.x, sz.y))
	_cache[key] = t
	return t


## Fixed raster, `px` pixels on the longer side (ImageTexture with mipmaps): the UiIcons.tex
## contract, for shader uniforms and custom _draw code that scales the texture itself.
## Unmapped ids return exactly UiIcons.tex (unless a saturation is asked for).
static func tex(id: String, px: int = 48, opts: Variant = null) -> Texture2D:
	var o := _opts(opts)
	if id.begins_with("3d:") and not is_mapped(id):
		return UiIcons.tex(id, px, o.tint)
	var key := "r|%s|%d|%s" % [id, px, _opts_key(o)]
	if _cache.has(key):
		return _cache[key]
	var svg := _svg(id, o, px)
	if svg == "" and float(o.saturation) < 1.0 and not id.begins_with("3d:"):
		svg = _legacy_svg(id, o)
	var t: Texture2D = UiSvg.raster(svg, px) if svg != "" else UiIcons.tex(id, px, o.tint)
	_cache[key] = t
	return t


## TextureRect showing an icon at `px` logical px, centred and aspect-kept. `opts` as texture().
static func rect(id: String, px: int = 48, opts: Variant = null) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture(id, px, opts)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Normalised options: {"tint": Color or null, "saturation": float}.
static func _opts(opts: Variant) -> Dictionary:
	var o := {"tint": null, "saturation": 1.0, "has_sat": false}
	if opts is Color:
		o.tint = opts
	elif opts is Dictionary:
		var t: Variant = UiSvg.color((opts as Dictionary).get("tint", null))
		o.tint = t
		o.has_sat = (opts as Dictionary).has("saturation")
		o.saturation = float((opts as Dictionary).get("saturation", 1.0))
	return o


static func _opts_key(o: Dictionary) -> String:
	return "%s|%s" % [(o.tint as Color).to_html() if o.tint is Color else "-", o.saturation if o.has_sat else "-"]


## Final SVG text for a mapped id ("" when unmapped / missing -> legacy fallback): the entry's
## svg (or compact_svg at <= COMPACT_PX), text stripped, tinted / desaturated, with its
## "badge" composited in the corner.
static func _svg(id: String, o: Dictionary, size_px: int = 0) -> String:
	var p := svg_path(id)
	if p == "":
		return ""
	var e: Dictionary = entries()[id]
	var c := String(e.get("compact_svg", ""))
	if c != "" and size_px > 0 and size_px <= COMPACT_PX and UiSvg.exists(UiSvg.runtime_path("icons", c)):
		p = UiSvg.runtime_path("icons", c)
	var src := UiSvg.source(p)
	if src == "":
		return ""
	if bool(e.get("strip_text", false)):
		src = UiSvg.strip_text(src)
	var sat: float = float(o.saturation) if o.has_sat else float(e.get("saturation", 1.0))
	src = UiSvg.recolor(src, effective_tint(id, o.tint), sat)
	var b: Variant = e.get("badge", null)
	if b is Dictionary and String(b.get("svg", "")) != "":
		var bsrc := UiSvg.source(UiSvg.runtime_path("icons", String(b["svg"])))
		if bsrc != "":
			src = UiSvg.with_badge(src, UiSvg.recolor(bsrc, null, sat), String(b.get("corner", "br")),
				float(b.get("scale", 0.45)))
	return src


## The current drawn glyph (ui/icons/<id>.svg) with its tint slot filled, like UiIcons.tex.
static func _legacy_svg(id: String, o: Dictionary) -> String:
	var src := UiSvg.source(UiIcons.DIR + id + ".svg")
	if src == "":
		push_error("Icons: no icon '%s' (not in icon_map.json, no ui/icons/%s.svg)" % [id, id])
		return ""
	var c: Color = o.tint if o.tint is Color else UiIcons.default_color(id)
	return UiSvg.recolor(src.replace(UiIcons.TINT_SLOT, "#" + c.to_html(false)), null, float(o.saturation))


## Tint actually applied to a mapped id (null = the SVG's own colours). See the header.
static func effective_tint(id: String, caller: Variant = null) -> Variant:
	var e: Dictionary = entries().get(id, {})
	var raw: Variant = e.get("tint", null)
	if raw == null or (raw is String and String(raw) == ""):
		return null
	if caller is Color:
		return caller
	if String(raw) == "palette:auto":
		return UiIcons.default_color(id)
	return UiSvg.color(raw)


static func clear_cache() -> void:
	_cache.clear()


# ---------------------------------------------------------------- UiIcons drop-ins

## True when the id renders anything (mapped RhosGFX art or a legacy glyph).
static func exists(id: String) -> bool:
	return is_mapped(id) or UiIcons.exists(id)


static func default_color(id: String) -> Color:
	return UiIcons.default_color(id)


static func rune_icon(rune: String) -> String:
	return UiIcons.rune_icon(rune)


static func intent_icon(kind: String) -> String:
	return UiIcons.intent_icon(kind)


static func biome_icon(id: String) -> String:
	return "biome_" + id if exists("biome_" + id) else "flag"


static func class_icon(class_id: String) -> String:
	if exists("class_" + class_id):
		return "class_" + class_id
	return UiIcons.class_icon(class_id)


static func mechanic_icon(mechanic: String) -> String:
	return "mech_" + mechanic if exists("mech_" + mechanic) else "star"

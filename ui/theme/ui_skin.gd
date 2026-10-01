class_name UiSkin
extends RefCounted
## RhosGFX Cartoony UI pack -> Godot StyleBoxes / Theme entries, driven by ui/theme/ui_pack.json.
## Every lookup falls back to the current StyleBoxFlat look when the manifest has no such
## piece or its SVGs were not imported (fresh clone, paid pack absent), so switching a
## control over is safe before the art lands.
##
##   btn.add_theme_stylebox_override("normal", UiSkin.stylebox("button_primary", "normal"))
##   UiSkin.apply_button(btn, "button_primary")           # normal/hover/pressed/disabled/focus
##   UiSkin.apply_panel(panel_container, "panel_main")     # "panel" stylebox
##   UiSkin.apply_progress(progress_bar, "bar_hp")         # "background" + "fill"
##   UiSkin.apply_toggle(check_button, "toggle")           # checked / unchecked icons
##   UiSkin.set_theme_type(theme, "Button", "button_secondary")   # whole Theme type at once
##   draw_style_box(UiSkin.stylebox("chip", "normal"), rect)       # custom-drawn widgets
##   UiSkin.texture("checkbox", "checked", 32)             # a piece as a plain texture/icon
##   UiSkin.has("button_primary")                          # art present?
##   UiSkin.stylebox("plaque", "normal", {"tint": UiPalette.class_color("mage")})  # per-use tint
##   UiSkin.stylebox("chip", "normal", {"saturation": 0.0, "fallback": my_flat_box})
##
## Manifest (ui/theme/ui_pack.json; `svg` paths relative to third_party/):
##   {"version": 1, "pieces": {"<piece>": {
##       "note": "...", "fallback": "button" | "panel:<kind>" | "theme:<Type>" | "empty",
##       "slice":   [l, t, r, b],   9-slice margins in SVG units (viewBox px) of the source art
##       "scale":   1.0,            logical canvas px per SVG unit (the art's on-screen size)
##       "content": [l, t, r, b],   content margins, logical px (default slice x scale)
##       "expand":  [l, t, r, b],   expand margins, logical px (negative = inset)
##       "tint":     null | "#hex" | "palette:NAME",  multiply baked into the vector (crisp;
##                                   use the "0. White" colour variants)
##       "modulate": null | "#hex[aa]" | "palette:NAME", StyleBoxTexture.modulate_color (alpha ok)
##       "saturation": 1.0,          < 1 desaturates (disabled states)
##       "axis": "stretch" | "tile" | "tile_fit" | [h, v],   "draw_center": true,
##       "rotate": 0 | 90 | 180 | 270   (clockwise; e.g. horizontal bar art as a vertical scroll
##                                       track: slice / scale then refer to the rotated art),
##       "fit": false                  (true = shrink the whole box uniformly when the draw rect
##                                       is smaller than its slices: UiFitStyleBox),
##       "runtime_tint": true           (false = per-use opts tints skip this layer),
##       "states": {"normal": {...}, "hover": {...}, "pressed": {...}, "disabled": {...},
##                  "focus": {...}, "background": {...}, "fill": {...}, "checked": {...}, ...}
##   }}}
## Every key may sit on the piece (default for all states) or on a state (override). A state
## may instead give "layers": [{...}, {...}] (bottom first, each a full key set that inherits
## from the state) for container + frame combos (and "offset": [x, y] in SVG units, used when
## texture() composes the layers into one image). A missing state falls back to "normal".

const PACK_PATH := "res://ui/theme/ui_pack.json"
const BUTTON_STATES := ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]

static var _pieces: Dictionary = {}
static var _loaded := false
static var _cache: Dictionary = {}
static var _warned: Dictionary = {}
static var _has_cache: Dictionary = {}


# ---------------------------------------------------------------- manifest

static func pieces() -> Dictionary:
	if not _loaded:
		_loaded = true
		_pieces = load_manifest(PACK_PATH)
	return _pieces


static func load_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not j.data is Dictionary:
		push_warning("UiSkin: unreadable %s: %s" % [path, j.get_error_message()])
		return {}
	var p: Variant = (j.data as Dictionary).get("pieces", {})
	return p if p is Dictionary else {}


## Test / preview hook: replace the manifest (null = reload from PACK_PATH on next use).
static func set_manifest(m: Variant) -> void:
	_loaded = m != null
	_pieces = m if m is Dictionary else {}
	_cache.clear()
	_warned.clear()
	_has_cache.clear()


static func clear_cache() -> void:
	_cache.clear()
	_has_cache.clear()


## The resolved layers of piece/state: an array of merged key dictionaries (bottom first),
## [] when the piece is unknown. `state` falls back to "normal".
static func layers(piece: String, state: String = "normal", opts: Dictionary = {}) -> Array:
	var p: Variant = pieces().get(piece, null)
	if not p is Dictionary:
		return []
	var states: Dictionary = (p as Dictionary).get("states", {})
	var st: Dictionary = states.get(state, states.get("normal", {}))
	var base := {}
	for k in p:
		if k != "states":
			base[k] = p[k]
	for k in st:
		if k != "layers":
			base[k] = st[k]
	var out := []
	var ls: Variant = st.get("layers", p.get("layers", null))
	if ls is Array and not (ls as Array).is_empty():
		for l in ls:
			var m := base.duplicate()
			m.erase("layers")
			for k in l:
				m[k] = l[k]
			out.append(m)
	elif String(base.get("svg", "")) != "":
		out.append(base)
	if not opts.is_empty():
		for l in out:
			if l.get("runtime_tint", true) == false:
				continue
			for k in ["tint", "modulate", "saturation"]:
				if opts.has(k) and opts[k] != null:
					l[k] = opts[k]
	return out


## True when piece/state is in the manifest and every one of its SVGs is imported.
static func has(piece: String, state: String = "normal") -> bool:
	var key := piece + "|" + state
	if _has_cache.has(key):
		return _has_cache[key]
	var ok := true
	var ls := layers(piece, state)
	if ls.is_empty():
		ok = false
	for l in ls:
		if not UiSvg.exists(UiSvg.runtime_path("pack", String(l.get("svg", "")))):
			ok = false
	_has_cache[key] = ok
	return ok


# ---------------------------------------------------------------- style boxes

## StyleBox for piece/state: a StyleBoxTexture (9-slice DPITexture), a UiLayeredStyleBox for
## layered states, or - when the art is missing - the fallback: opts.fallback, else the
## manifest's "fallback" (the current flat look), else StyleBoxEmpty. Returns a fresh copy.
## `opts` (optional): a StyleBox (= fallback) or a Dictionary:
##   {"fallback": StyleBox, "tint": Color, "modulate": Color, "saturation": float}
## tint / modulate / saturation are per-use overrides applied to every layer that doesn't set
## "runtime_tint": false in the manifest (e.g. tint a white plaque to a ribbon colour, an
## accent per pet / class, without a piece per colour).
static func stylebox(piece: String, state: String = "normal", opts: Variant = null) -> StyleBox:
	var o := _opts(opts)
	var key := "%s|%s|%s" % [piece, state, _opts_key(o)]
	if not _cache.has(key):
		_cache[key] = _build(piece, state, o)
	var sb: StyleBox = _cache[key]
	if sb == null:
		return _fallback(piece, state, o.get("fallback", null))
	return sb.duplicate()


static func _opts(opts: Variant) -> Dictionary:
	if opts is StyleBox:
		return {"fallback": opts}
	if opts is Dictionary:
		var o := (opts as Dictionary).duplicate()
		for k in ["tint", "modulate"]:
			if o.has(k) and not o[k] is Color:
				o[k] = UiSvg.color(o[k])
		return o
	return {}


static func _opts_key(o: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in ["tint", "modulate", "saturation"]:
		var v: Variant = o.get(k, null)
		parts.append((v as Color).to_html() if v is Color else str(v))
	return ",".join(parts)


static func _build(piece: String, state: String, o: Dictionary = {}) -> StyleBox:
	if not has(piece, state):
		return null
	var run := o.duplicate()
	run.erase("fallback")
	var ls := layers(piece, state, run)
	var boxes: Array[StyleBox] = []
	for l in ls:
		var b := _layer_box(l)
		if b == null:
			return null
		boxes.append(b)
	var first: Dictionary = ls[0]
	var sb: StyleBox = boxes[0]
	if boxes.size() > 1:
		var lay := UiLayeredStyleBox.new()
		lay.layers = boxes
		sb = lay
	var cm := _rect4(first.get("content", null))
	if cm.is_empty():
		var s := _scale(first)
		var sl := _rect4(first.get("slice", null))
		cm = [0.0, 0.0, 0.0, 0.0] if sl.is_empty() else [sl[0] * s, sl[1] * s, sl[2] * s, sl[3] * s]
	if bool(first.get("fit", false)):
		sb = _fit(sb, boxes)
	sb.content_margin_left = cm[0]
	sb.content_margin_top = cm[1]
	sb.content_margin_right = cm[2]
	sb.content_margin_bottom = cm[3]
	return sb


## "fit": true pieces: one art scale serves every size. The box shrinks uniformly when the
## draw rect is smaller than its borders (UiFitStyleBox), instead of overlapping them.
static func _fit(sb: StyleBox, boxes: Array[StyleBox]) -> StyleBox:
	var m := Vector2.ZERO
	for b in boxes:
		if b is StyleBoxTexture:
			var t := b as StyleBoxTexture
			m.x = maxf(m.x, t.texture_margin_left + t.texture_margin_right + 1.0 - t.expand_margin_left - t.expand_margin_right)
			m.y = maxf(m.y, t.texture_margin_top + t.texture_margin_bottom + 1.0 - t.expand_margin_top - t.expand_margin_bottom)
	var f := UiFitStyleBox.new()
	f.inner = sb
	f.min_rect = m
	return f


static func _layer_box(l: Dictionary) -> StyleBoxTexture:
	var t := _layer_texture(l, 1.0)
	if t == null:
		return null
	var s := _scale(l)
	var sb := StyleBoxTexture.new()
	sb.texture = t
	var sl := _rect4(l.get("slice", null))
	if not sl.is_empty():
		sb.texture_margin_left = sl[0] * s
		sb.texture_margin_top = sl[1] * s
		sb.texture_margin_right = sl[2] * s
		sb.texture_margin_bottom = sl[3] * s
	var ex := _rect4(l.get("expand", null))
	if not ex.is_empty():
		sb.expand_margin_left = ex[0]
		sb.expand_margin_top = ex[1]
		sb.expand_margin_right = ex[2]
		sb.expand_margin_bottom = ex[3]
	var mod: Variant = UiSvg.color(l.get("modulate", null))
	if mod is Color:
		sb.modulate_color = mod
	sb.draw_center = bool(l.get("draw_center", true))
	var ax: Variant = l.get("axis", "stretch")
	var ah: String = ax[0] if ax is Array and (ax as Array).size() == 2 else String(ax)
	var av: String = ax[1] if ax is Array and (ax as Array).size() == 2 else String(ax)
	sb.axis_stretch_horizontal = _axis(ah)
	sb.axis_stretch_vertical = _axis(av)
	return sb


static func _axis(s: String) -> StyleBoxTexture.AxisStretchMode:
	match s:
		"tile":
			return StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		"tile_fit":
			return StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH


static func _fallback(piece: String, state: String, fallback: StyleBox) -> StyleBox:
	if fallback != null:
		return fallback
	var p: Variant = pieces().get(piece, null)
	var fb := String(p.get("fallback", "")) if p is Dictionary else ""
	if fb == "button":
		fb = "theme:Button"
	if fb.begins_with("panel:"):
		return UiTheme.flat_box(fb.substr(6))
	if fb.begins_with("theme:"):
		var th := UiTheme.get_theme()
		var type := fb.substr(6)
		var st := state
		if not th.has_stylebox(st, type):
			st = {"background": "panel", "fill": "panel"}.get(state, "normal")
		if th.has_stylebox(st, type):
			return th.get_stylebox(st, type).duplicate()
	if fb == "" and not _warned.has(piece):
		_warned[piece] = true
		if not p is Dictionary:
			push_warning("UiSkin: unknown piece '%s' (ui/theme/ui_pack.json)" % piece)
	return StyleBoxEmpty.new()


# ---------------------------------------------------------------- textures

## A piece's art as a plain texture, `size_px` logical px on the longer side (0 = the
## manifest scale), for CheckBox / CheckButton / slider icons and badges. Layered states are
## composed into one SVG, each layer placed at its "offset" [x, y] (SVG units), e.g. a toggle
## = container + handle. null when the art is missing.
static func texture(piece: String, state: String = "normal", size_px: float = 0.0, opts: Variant = null) -> Texture2D:
	var o := _opts(opts)
	o.erase("fallback")
	var key := "tex|%s|%s|%s|%s" % [piece, state, size_px, _opts_key(o)]
	if _cache.has(key):
		return _cache[key]
	var t: Texture2D = null
	if has(piece, state):
		var ls := layers(piece, state, o)
		var parts := []
		for l in ls:
			var src := _layer_svg(l)
			var off: Variant = l.get("offset", [0, 0])
			parts.append([src, Vector2(float(off[0]), float(off[1])) if off is Array and (off as Array).size() == 2 else Vector2.ZERO])
		var svg: String = parts[0][0] if parts.size() == 1 else UiSvg.compose(parts)
		var s := _scale(ls[0])
		if size_px > 0.0:
			var sz := UiSvg.svg_size(svg)
			s = size_px / maxf(sz.x, sz.y)
		t = UiSvg.make_texture(svg, s)
	_cache[key] = t
	return t


static func _layer_texture(l: Dictionary, mul: float) -> Texture2D:
	var src := _layer_svg(l)
	return UiSvg.make_texture(src, _scale(l) * mul) if src != "" else null


## A layer's SVG text with its tint / saturation baked in ("" when missing).
static func _layer_svg(l: Dictionary) -> String:
	var src := UiSvg.source(UiSvg.runtime_path("pack", String(l.get("svg", ""))))
	if src == "":
		return ""
	src = UiSvg.recolor(src, UiSvg.color(l.get("tint", null)), float(l.get("saturation", 1.0)))
	return UiSvg.rotate(src, int(l.get("rotate", 0))) if int(l.get("rotate", 0)) % 360 != 0 else src


static func _scale(l: Dictionary) -> float:
	return float(l.get("scale", 1.0))


static func _rect4(v: Variant) -> Array:
	if v is Array and (v as Array).size() == 4:
		return [float(v[0]), float(v[1]), float(v[2]), float(v[3])]
	if v is float or v is int:
		return [float(v), float(v), float(v), float(v)]
	return []


# ---------------------------------------------------------------- control helpers

## Button-like controls: normal / hover / pressed / disabled / focus / hover_pressed from the
## piece's states (hover_pressed defaults to pressed; missing states fall back to normal).
static func apply_button(c: Control, piece: String, opts: Variant = null) -> void:
	for st in BUTTON_STATES:
		var s: String = "pressed" if st == "hover_pressed" and not _has_state(piece, st) else st
		c.add_theme_stylebox_override(st, stylebox(piece, s, opts))


static func apply_panel(c: Control, piece: String, state: String = "normal", opts: Variant = null) -> void:
	c.add_theme_stylebox_override("panel", stylebox(piece, state, opts))


## ProgressBar (or anything with "background" / "fill" boxes).
static func apply_progress(c: Control, piece: String, fill_opts: Variant = null) -> void:
	c.add_theme_stylebox_override("background", stylebox(piece, "background"))
	c.add_theme_stylebox_override("fill", stylebox(piece, "fill", fill_opts))


## HSlider / VSlider: "track" -> slider, "fill" -> grabber_area(_highlight), "grabber" art
## -> grabber icons (only when present; the flat knob stays otherwise).
static func apply_slider(c: Control, piece: String, grabber_px: float = 44.0) -> void:
	c.add_theme_stylebox_override("slider", stylebox(piece, "track"))
	var fill := stylebox(piece, "fill")
	c.add_theme_stylebox_override("grabber_area", fill)
	c.add_theme_stylebox_override("grabber_area_highlight", fill)
	var g := texture(piece, "grabber", grabber_px)
	if g != null:
		c.add_theme_icon_override("grabber", g)
		c.add_theme_icon_override("grabber_highlight", texture(piece, "grabber_hover", grabber_px) if has(piece, "grabber_hover") else g)
		c.add_theme_icon_override("grabber_disabled", g)


## CheckBox / CheckButton: "checked" / "unchecked" (+ "_disabled") art as the icons.
static func apply_toggle(c: Control, piece: String, px: float = 0.0) -> void:
	for st in ["checked", "unchecked", "checked_disabled", "unchecked_disabled"]:
		var src: String = st if has(piece, st) else st.trim_suffix("_disabled")
		var t := texture(piece, src, px)
		if t != null:
			c.add_theme_icon_override(st, t)


## Fills a Theme type with every state of a piece: theme.set_stylebox(<state>, type, ...).
## `rename` maps piece states to theme names (e.g. {"track": "slider"}).
static func set_theme_type(theme: Theme, type_name: String, piece: String, rename: Dictionary = {}) -> void:
	var p: Variant = pieces().get(piece, null)
	var states: Array = (p as Dictionary).get("states", {"normal": {}}).keys() if p is Dictionary else ["normal"]
	for st in states:
		theme.set_stylebox(String(rename.get(st, st)), type_name, stylebox(piece, st))


static func _has_state(piece: String, state: String) -> bool:
	var p: Variant = pieces().get(piece, null)
	return p is Dictionary and (p as Dictionary).get("states", {}).has(state)

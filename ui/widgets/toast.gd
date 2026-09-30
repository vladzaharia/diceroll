class_name Toast
extends RefCounted
## The one toast helper (spec 2.6): a callout box (ink with a Thin rim in the toast's colour:
## gold reward, red danger, green heal, blue info) with an optional icon and a Lilita line,
## that pops in, holds, rises and fades. Replaces the overlay / board HUD / dev menu / dev
## gesture copies. Clamped to the safe area; long text wraps; stacks up to 3.
##
##   Toast.show(overlay, "Trap dodged!", "skull", UiPalette.HEAL)
##   Toast.show(layer, "Diagnostics copied", "", UiPalette.TEXT_DIM, {"at": "bottom", "font": 22})
##
## opts: "y" (top edge, logical px; default under the top HUD), "at" ("top" | "bottom"),
##       "step" (px between stacked toasts, default 70; negative stacks upward),
##       "hold" (s, 1.3), "rise" (px, 50), "font" (28), "rim" (Color / "reward" | "danger" |
##       "heal" | "info"; default = the text colour), "time_scale" (Callable(float) -> float).

const META := "toast"
const MAX_STACK := 3
## Default top edge: under the top HUD.
const TOP_Y := 150.0


## A toast box (not shown or animated): the callout panel with icon + label.
static func make(text: String, icon := "", color: Color = UiPalette.TEXT, font := 28, rim: Variant = null) -> PanelContainer:
	var p := PanelContainer.new()
	var r: Variant = rim if rim != null else _rim_for(color)
	p.add_theme_stylebox_override("panel", UiTheme.toast_box(r))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_meta(META, true)
	var row := UiTheme.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(row)
	if icon != "" and Icons.exists(icon):
		var ic := Icons.rect(icon, int(font * 1.5))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var l := UiTheme.label(text, font, color, true, 0, not UiTheme.skinned("toast"))
	l.name = "Text"
	row.add_child(l)
	return p


## Shows a toast on `host` (a Control, or any Node: a full-screen holder is added).
static func show(host: Node, text: String, icon := "", color: Color = UiPalette.TEXT, opts: Dictionary = {}) -> PanelContainer:
	if host == null or not host.is_inside_tree():
		return null
	var root := host as Control
	if root == null:
		root = Control.new()
		root.name = "ToastLayer"
		root.theme = UiTheme.get_theme()
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTheme.full_rect(root)
		host.add_child(root)
	var font := int(opts.get("font", 28))
	var p := make(text, icon, color, font, opts.get("rim", null))
	var slot := 0
	for c in root.get_children():
		if c is Control and (c as Control).has_meta(META) and not (c as Control).is_queued_for_deletion():
			slot += 1
	slot = slot % MAX_STACK
	root.add_child(p)
	var view := root.get_viewport().get_visible_rect().size if root.size.x <= 0.0 else root.size
	var safe := UiTheme.safe_margins(root)
	var maxw := view.x - safe.left - safe.right
	p.reset_size()
	if p.get_combined_minimum_size().x > maxw:
		var l := p.find_child("Text", true, false) as Label
		if l:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = maxw - 120.0
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.reset_size()
	var s := p.get_combined_minimum_size()
	p.size = s
	var step := float(opts.get("step", 70.0))
	var y: float
	if opts.has("y"):
		y = float(opts["y"])
	elif String(opts.get("at", "top")) == "bottom":
		y = view.y - safe.bottom - s.y - 96.0
		step = -absf(step)
	else:
		y = maxf(safe.top, TOP_Y)
	y += slot * step
	y = clampf(y, safe.top, view.y - safe.bottom - s.y)
	p.position = Vector2(clampf((view.x - s.x) * 0.5, safe.left, maxf(safe.left, view.x - safe.right - s.x)), y)
	p.pivot_offset = s * 0.5
	p.scale = Vector2(0.6, 0.6)
	p.modulate.a = 0.0
	var ts: Callable = opts.get("time_scale", Callable())
	var d := func(t: float) -> float: return float(ts.call(t)) if ts.is_valid() else t
	var rise := minf(float(opts.get("rise", 50.0)), maxf(0.0, y - safe.top))
	var t := p.create_tween()
	t.set_parallel(true)
	t.tween_property(p, "scale", Vector2.ONE, d.call(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(p, "modulate:a", 1.0, d.call(0.15))
	t.chain().tween_interval(d.call(float(opts.get("hold", 1.3))))
	# rise + fade together, only after the hold (chain() then parallel(): re-enabling
	# set_parallel here would run them alongside the hold and drop the toast after ~0.25 s)
	t.chain().tween_property(p, "position:y", y - rise, d.call(0.4))
	t.parallel().tween_property(p, "modulate:a", 0.0, d.call(0.4))
	t.chain().tween_callback(func() -> void:
		p.remove_meta(META)
		p.queue_free()
		if root != host and root.get_child_count() <= 1:
			root.queue_free())
	return p


## Rim for a text colour: the nearest of gold / red / green / blue (the rim is the meaning).
static func _rim_for(c: Color) -> Variant:
	if c.s < 0.2:
		return "info"
	match UiTheme.family_of(c):
		"red", "pink":
			return "danger"
		"green":
			return "heal"
		"yellow":
			return "reward"
	return c

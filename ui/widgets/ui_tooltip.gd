class_name UiTooltip
extends RefCounted
## One recipe for every tooltip and callout body (spec 2.6): an ink box with a Thin rim in the
## accent colour (rarity / affix / potion / status: the rim colour *is* the information; no
## accent = the darkbrown tooltip rim), an optional 48 px Outline icon on the left, then a title
## (Lilita, accent-lit), an optional tag, the body text (Fredoka, dim) and an optional status
## line (gold, the live value). Replaces the three hand-copied StyleBoxFlat builders
## (hud_top _text_tip, meta_hud _show_tip, affix_tips show_tip).
##
##   UiTooltip.fill(_tip, "Frost Rune", "RARE", "Shows 1: the target skips...", UiPalette.rarity_color("rare"))
##   UiTooltip.fill(_tip, "Healing", "POTION", "Heal 20 HP.", col, {"icon": "potion_healing", "status": "Tap to drink"})
##   UiTooltip.place(_tip, self, anchor.get_global_rect())   # below the anchor, flips above, clamped to the safe area
##
## `panel` keeps its node (callers own show / hide / fades); fill() replaces its children and
## box. Nothing here reads an autoload, so it is safe at parse time anywhere under ui/.

## Widest body text (logical px); callers on narrow hosts pass opts.max_w.
const MAX_W := 380.0
## Icon size on the left (spec 2.6: optional 48 px Outline icon).
const ICON_PX := 48
## Gap between the anchor and the tip, and the minimum margin to the safe area.
const GAP := 8.0
const EDGE := 12.0


## The tooltip box: callout art with a rim in `accent` (a Color), or the plain tooltip
## (darkbrown rim) when `accent` is null. Fresh StyleBox; never cast it.
static func box(accent: Variant = null) -> StyleBox:
	return UiTheme.callout_box(accent if accent is Color else null)


## Fills `panel` with the standard tooltip content and returns the text column (callers may
## append rows). opts: "icon" (icon id, drawn ICON_PX on the left), "icon_px", "status"
## (String: a gold line under the body), "status_color" (Color), "max_w" (float),
## "title_size" (int, default 26), "body_size" (int, default 21).
static func fill(panel: PanelContainer, title: String, tag := "", body := "", accent: Variant = null,
		opts: Dictionary = {}) -> VBoxContainer:
	UiTheme.clear(panel)
	panel.add_theme_stylebox_override("panel", box(accent))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var acc: Color = accent if accent is Color else UiPalette.GOLD
	var row := UiTheme.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var icon := String(opts.get("icon", ""))
	if icon != "":
		var ic := Icons.rect(icon, int(opts.get("icon_px", ICON_PX)))
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(ic)
	var col := UiTheme.vbox(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var head := UiTheme.hbox(8)
	col.add_child(head)
	var t := UiTheme.label(title, int(opts.get("title_size", 26)), acc.lightened(0.3), true, 5)
	t.name = "Title"
	head.add_child(t)
	if tag != "":
		var tg := UiTheme.label(tag, 16, acc.lightened(0.1), false, 0, false, 800)
		tg.name = "Tag"
		tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(tg)
	var mw := float(opts.get("max_w", MAX_W))
	if body != "":
		var d := UiTheme.para(body, int(opts.get("body_size", 21)), UiPalette.TEXT_DIM, 500)
		d.name = "Body"
		d.custom_minimum_size.x = mw
		col.add_child(d)
	var status := String(opts.get("status", ""))
	if status != "":
		var s := UiTheme.label(status, 21, opts.get("status_color", UiPalette.GOLD_BRIGHT), false, 0, false, 700)
		s.name = "Status"
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size.x = mw
		col.add_child(s)
	return col


## Sizes `panel` to its content and positions it (in `host`'s local coordinates) centred under
## `anchor` (a global rect), flipping above when it would cross the bottom of the safe area
## and clamping inside the safe area on every side (spec 3.1 rule 7). An empty anchor centres
## the tip in the host. Returns the final local rect.
static func place(panel: Control, host: Control, anchor: Rect2 = Rect2(), gap := GAP) -> Rect2:
	panel.reset_size()
	var s := panel.get_combined_minimum_size()
	panel.size = s
	var inv := host.get_global_transform().affine_inverse()
	var view := host.size
	var safe := UiTheme.safe_margins(host)
	var lo := Vector2(safe.left + EDGE, safe.top + EDGE)
	var hi := Vector2(view.x - safe.right - EDGE, view.y - safe.bottom - EDGE)
	var pos := (view - s) * 0.5
	if anchor.size != Vector2.ZERO or anchor.position != Vector2.ZERO:
		var a0 := inv * anchor.position
		var a1 := inv * anchor.end
		var cx := (a0.x + a1.x) * 0.5
		pos = Vector2(cx - s.x * 0.5, a1.y + gap)
		if pos.y + s.y > hi.y:
			pos.y = a0.y - gap - s.y
	pos.x = clampf(pos.x, lo.x, maxf(lo.x, hi.x - s.x))
	pos.y = clampf(pos.y, lo.y, maxf(lo.y, hi.y - s.y))
	panel.position = pos
	return Rect2(pos, s)

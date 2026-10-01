class_name UiAudit
extends RefCounted
## "No spillover" layout audit (the reskin acceptance gate). Walks the visible Controls under a
## node and reports, one line each:
##
##   AUDIT_OVERFLOW <px> <path> > <frame path>   a Control's rect pokes out of its nearest frame
##   AUDIT_SAFE <px> <path>                      content outside the device safe area
##   AUDIT_CLIP <px> "<text>" <path>             Label / RichTextLabel text wider / taller than
##                                               its rect (no autowrap, no ellipsis)
##
## Frame = the nearest ancestor that is a PanelContainer / Panel with a visible style box (modal
## panels, cards, tags, chips), a UiModal's `panel` (for everything inside that modal), or any
## Control with meta "contain" = true. A clipping ancestor (clip_contents, ScrollContainer) that
## is closer than the frame ends the check (its content is visually contained).
## Safe area = the viewport minus the device (or --safe= emulated) insets; only content counts
## (text, buttons, icons, ranges), not full-screen backgrounds.
## Opt out: meta "allow_overflow" = true on a Control exempts it and its subtree from the FRAME
## check only (safe area and text clipping still apply): the modal title plaque (UiModal sets
## it on its ribbon) and the round close button that straddle the frame edge, corner badges.
## Meta "audit_skip" = true skips a subtree entirely (drag previews, off-screen staging).
##
##   tools/shoot.sh <scenario> out.png 1920x1080 --audit          (prints AUDIT_* after the shot)
##   tools/shoot_matrix.sh <scenario> <dir> all --audit           (every device; grep AUDIT_)
##   UiAudit.run(node)  -> PackedStringArray                        (tests)

## Pixels a rect may poke out before it counts (anti-aliasing, fractional layout).
const TOLERANCE := 1.5
## Meta flags (see header).
const ALLOW := "allow_overflow"
const SKIP := "audit_skip"


static func run(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if root == null:
		return out
	_walk(root, out, _safe_rect(root) if root.is_inside_tree() else Rect2(), Rect2(-1e6, -1e6, 2e6, 2e6))
	return out


## `clip` = the visible region left by clipping ancestors (ScrollContainer, clip_contents):
## content scrolled out of view is neither drawn nor checked.
static func _walk(n: Node, out: PackedStringArray, safe: Rect2, clip: Rect2, free := false) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n.get_meta(SKIP, false):
		return
	free = free or bool(n.get_meta(ALLOW, false))
	if n is Control:
		var c := n as Control
		var r := grect(c)
		if not r.intersects(clip):
			return
		if r.size.x > 0.5 and r.size.y > 0.5 and c.modulate.a > 0.05:
			if not free:
				_check_frame(c, r, out)
			if _is_content(c) and safe.size.x > 0.0:
				var d := _outside(r.intersection(clip), safe)
				if d > TOLERANCE:
					out.append("AUDIT_SAFE %.0f %s" % [d, path(c)])
			_check_text(c, out)
		if c.clip_contents or c is ScrollContainer:
			clip = clip.intersection(r)
	for ch in n.get_children():
		_walk(ch, out, safe, clip, free)


## Distance (px) by which `r` pokes out of `frame` (0 = inside).
static func _outside(r: Rect2, frame: Rect2) -> float:
	return maxf(maxf(frame.position.x - r.position.x, r.end.x - frame.end.x),
		maxf(maxf(frame.position.y - r.position.y, r.end.y - frame.end.y), 0.0))


static func _check_frame(c: Control, r: Rect2, out: PackedStringArray) -> void:
	var f := frame_of(c)
	if f == null:
		return
	var d := _outside(r, grect(f))
	if d > TOLERANCE:
		out.append("AUDIT_OVERFLOW %.0f %s > %s" % [d, path(c), path(f)])


## Nearest frame of `c` (see header), or null (none / a clipping ancestor comes first).
static func frame_of(c: Control) -> Control:
	# a modal's own chrome (centring holder, frame column) holds its panel: not content
	var p := c.get_parent()
	var child: Node = c
	while p != null:
		if p is Control:
			var pc := p as Control
			var modal_panel: Variant = pc.get("panel") if "scrim" in pc else null
			if modal_panel is Control and modal_panel != child and child != pc.get("scrim"):
				if (child as Node).is_ancestor_of(modal_panel) or c.is_ancestor_of(modal_panel):
					return null
				return modal_panel
			if pc.clip_contents or pc is ScrollContainer:
				return null
			if bool(pc.get_meta("contain", false)) or _framed(pc):
				return pc
		child = p
		p = p.get_parent()
	return null


static func _framed(c: Control) -> bool:
	if not (c is PanelContainer or c is Panel):
		return false
	var sb := c.get_theme_stylebox("panel")
	return sb != null and not sb is StyleBoxEmpty


static func _is_content(c: Control) -> bool:
	return c is Label or c is RichTextLabel or c is BaseButton or c is Range or c is LineEdit \
		or (c is TextureRect and c.is_inside_tree() and c.get_global_rect().size.length() < c.get_viewport_rect().size.length() * 0.5)


static func _check_text(c: Control, out: PackedStringArray) -> void:
	if c is Label:
		var l := c as Label
		if l.text.strip_edges() == "" or l.autowrap_mode != TextServer.AUTOWRAP_OFF \
				or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
			return
		var font: Font = l.label_settings.font if l.label_settings and l.label_settings.font else l.get_theme_font("font")
		var fs: int = l.label_settings.font_size if l.label_settings else l.get_theme_font_size("font_size")
		if font == null:
			font = ThemeDB.fallback_font
		if fs <= 0:
			fs = ThemeDB.fallback_font_size
		var w := 0.0
		for line in l.text.split("\n"):
			w = maxf(w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		var d := w - l.size.x
		if d > TOLERANCE:
			out.append("AUDIT_CLIP %.0f \"%s\" %s" % [d, l.text.left(30).replace("\n", " "), path(l)])
	elif c is RichTextLabel:
		var rt := c as RichTextLabel
		if rt.fit_content or rt.scroll_active:
			return
		var d := rt.get_content_height() - rt.size.y
		if d > TOLERANCE:
			out.append("AUDIT_CLIP %.0f \"%s\" %s" % [d, rt.get_parsed_text().left(30).replace("\n", " "), path(rt)])


## Viewport rect minus the device / emulated safe-area insets (no EDGE padding).
static func _safe_rect(n: Node) -> Rect2:
	var vp := n.get_viewport()
	if vp == null:
		return Rect2()
	var v := vp.get_visible_rect()
	var m := UiTheme.safe_margins(n) if n.is_inside_tree() else null
	if m == null:
		return v
	# safe_margins floors every side at UiTheme.EDGE; only real insets count here
	var l := m.left if m.left > UiTheme.EDGE else 0.0
	var t := m.top if m.top > UiTheme.EDGE else 0.0
	var r := m.right if m.right > UiTheme.EDGE else 0.0
	var b := m.bottom if m.bottom > UiTheme.EDGE else 0.0
	return Rect2(v.position + Vector2(l, t), v.size - Vector2(l + r, t + b))


## Global rect; outside a tree (tests), positions summed up the Control parents.
static func grect(c: Control) -> Rect2:
	if c.is_inside_tree():
		return c.get_global_rect()
	var pos := c.position
	var p := c.get_parent()
	while p is Control:
		pos += (p as Control).position
		p = p.get_parent()
	return Rect2(pos, c.size)


static func path(n: Node) -> String:
	var parts := []
	var p := n
	for i in 4:
		if p == null:
			break
		parts.push_front(String(p.name) if not String(p.name).begins_with("@") else p.get_class())
		p = p.get_parent()
	return "/".join(parts)

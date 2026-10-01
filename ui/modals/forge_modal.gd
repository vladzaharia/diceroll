class_name ForgeModal
extends UiModal
## Forge (offer {kind:"forge", ops}). Choose die → choose face → Raise (+1) or Mirror (copy
## another face of the same die) with a before/after preview. Skip is always allowed: one
## exit (spec 3.2), the header close button (tooltip "Skip the forge"), Esc or the backdrop
## skip; there is no SKIP button. Enter = FORGE.
## Emits forge_apply(die_idx, face_idx, op, src_face); skip = forge_apply(-1, -1, "skip", -1).

signal forge_apply(die_idx: int, face_idx: int, op: String, src_face: int)

var _dice_row: HBoxContainer
var _faces_row: HBoxContainer
var _ops_row: HBoxContainer
var _src_box: VBoxContainer
var _src_row: HBoxContainer
var _preview: HBoxContainer
var _apply: GameButton
## The skip control (= the header close button; AUTO highlights it).
var _skip: GameButton
var _raise_btn: GameButton
var _mirror_btn: GameButton
var _flow: GameFlow
var _ops: Array = []
var _die := 0
var _face := -1
var _op := "raise"
var _src := -1
var _die_tabs: Array[_DieTab] = []
var _face_btns: Array[_FaceButton] = []
var _src_btns: Array[_FaceButton] = []


func _build() -> void:
	body.add_theme_constant_override("separation", 14)
	dismissible = true
	close_tooltip = "Skip the forge"
	_skip = close_button
	body.add_child(UiModal.section_label("1 · Choose a die"))
	_dice_row = UiTheme.hbox(10)
	_dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_dice_row)
	body.add_child(UiModal.section_label("2 · Choose a face"))
	# the die's faces sit in an inset well (spec 4.3)
	var fw := PanelContainer.new()
	fw.add_theme_stylebox_override("panel", UiTheme.inset_box())
	fw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(fw)
	_faces_row = UiTheme.hbox(10)
	_faces_row.alignment = BoxContainer.ALIGNMENT_CENTER
	fw.add_child(_faces_row)
	_ops_row = UiTheme.hbox(14)
	_ops_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(_ops_row)
	_raise_btn = GameButton.make("RAISE +1", "up", GameButton.Kind.SECONDARY, 28)
	_raise_btn.toggle_mode = true
	_raise_btn.toggle_primary = true
	_raise_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_raise_btn.pressed.connect(func() -> void: _set_op("raise"))
	_ops_row.add_child(_raise_btn)
	_mirror_btn = GameButton.make("MIRROR", "mirror", GameButton.Kind.SECONDARY, 28)
	_mirror_btn.toggle_mode = true
	_mirror_btn.toggle_primary = true
	_mirror_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mirror_btn.pressed.connect(func() -> void: _set_op("mirror"))
	_ops_row.add_child(_mirror_btn)
	_src_box = UiTheme.vbox(10)
	body.add_child(_src_box)
	_src_box.add_child(UiModal.section_label("Copy from face"))
	_src_row = UiTheme.hbox(10)
	_src_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_src_box.add_child(_src_row)
	var pv := PanelContainer.new()
	pv.add_theme_stylebox_override("panel", UiTheme.inset_box())
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(pv)
	_preview = UiTheme.hbox(20)
	_preview.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview.custom_minimum_size.y = 104
	pv.add_child(_preview)
	var foot := UiTheme.hbox(14)
	body.add_child(foot)
	_apply = GameButton.make("FORGE", "anvil", GameButton.Kind.PRIMARY, 36)
	_apply.icon_tint = UiPalette.TEXT_DARK
	_apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply.sfx_id = "block"
	_apply.pressed.connect(func() -> void:
		if _valid():
			forge_apply.emit(_die, _face, _op, _src if _op == "mirror" else -1))
	foot.add_child(_apply)
	primary_action = _apply


## Skipping is the forge's dismissal: the core closes it (UiRoot.sync).
func dismiss() -> void:
	forge_apply.emit(-1, -1, "skip", -1)


func refresh(flow: GameFlow) -> void:
	_flow = flow
	_ops = flow.offer.get("ops", ["raise", "mirror"])
	var draft := String(flow.offer.get("source", "tile")) == "draft"
	set_title("FACE RAISE" if draft or not _ops.has("mirror") else "FORGE", PLAQUE_DEFAULT)
	_mirror_btn.visible = _ops.has("mirror")
	UiTheme.clear(_dice_row)
	_die_tabs.clear()
	var n := flow.run.dice.size()
	var tab_w := minf(96.0, (max_width - 100.0 - (n - 1) * 10.0) / maxf(1, n))
	for i in n:
		var t := _DieTab.new()
		t.die = flow.run.dice[i]
		t.idx = i
		t.custom_minimum_size = Vector2(tab_w, tab_w + 30)
		t.pressed.connect(_set_die.bind(i))
		_dice_row.add_child(t)
		_die_tabs.append(t)
	_die = clampi(_die, 0, n - 1)
	_face = -1
	_src = -1
	_op = "raise"
	_set_die(_die)


## Scenario helper: jump to a die/face/op selection.
func preselect(die_idx: int, face_idx: int, op: String, src := -1) -> void:
	_set_die(die_idx)
	_set_face(face_idx)
	_set_op(op)
	if src >= 0:
		_set_src(src)


func _set_die(i: int) -> void:
	_die = i
	_face = -1
	_src = -1
	for t in _die_tabs:
		t.selected = t.idx == i
	var d: Die = _flow.run.dice[i]
	UiTheme.clear(_faces_row)
	_face_btns.clear()
	for f in 6:
		var b := _FaceButton.make(d, f, 84)
		b.pressed.connect(_set_face.bind(f))
		_faces_row.add_child(b)
		_face_btns.append(b)
	_update()


func _set_face(f: int) -> void:
	_face = f
	if _src == f:
		_src = -1
	for b in _face_btns:
		b.face.selected = b.face_idx == f
	_update()


func _set_op(op: String) -> void:
	if not _ops.has(op):
		op = "raise"
	_op = op
	_update()


func _set_src(s: int) -> void:
	_src = s
	for b in _src_btns:
		b.face.selected = b.face_idx == s
	_update()


func _valid() -> bool:
	if _face < 0:
		return false
	var d: Die = _flow.run.dice[_die]
	if _op == "raise":
		return d.can_raise(_face)
	return _src >= 0 and _src != _face and d.faces[_src] != d.faces[_face]


func _update() -> void:
	if _flow == null:
		return
	var d: Die = _flow.run.dice[_die]
	_raise_btn.set_pressed_no_signal(_op == "raise")
	_mirror_btn.set_pressed_no_signal(_op == "mirror")
	_raise_btn.queue_redraw()
	_mirror_btn.queue_redraw()
	_raise_btn.call("_refresh")
	_mirror_btn.call("_refresh")
	for b in _face_btns:
		var maxed := _op == "raise" and not d.can_raise(b.face_idx)
		b.face.dimmed = maxed
		b.disabled = maxed
	# mirror sources
	_src_box.visible = _op == "mirror" and _face >= 0
	UiTheme.clear(_src_row)
	_src_btns.clear()
	if _src_box.visible:
		for f in 6:
			var sb := _FaceButton.make(d, f, 64)
			var bad: bool = f == _face or d.faces[f] == d.faces[_face]
			sb.face.dimmed = bad
			sb.disabled = bad
			sb.face.selected = f == _src
			sb.pressed.connect(_set_src.bind(f))
			_src_row.add_child(sb)
			_src_btns.append(sb)
	# preview
	UiTheme.clear(_preview)
	if _face < 0:
		_preview.add_child(UiTheme.label("Pick a face to see the result", 24, UiPalette.TEXT_MUTED, false, 0, false, 600))
	else:
		var before := d.faces[_face]
		var after := before
		if _op == "raise":
			after = mini(d.raise_cap(), before + 1)
		elif _src >= 0:
			after = d.faces[_src]
		var bf := DieFace.make(before, d.rune, d.edited[_face] == 1, 72)
		bf.kind = d.kind
		_preview.add_child(_captioned(bf, "Before"))
		_preview.add_child(Icons.rect("arrow_right", 44, UiPalette.TEXT))
		var af := DieFace.make(after, d.rune, after != before or d.edited[_face] == 1, 72)
		af.kind = d.kind
		if _op == "mirror" and _src < 0:
			af.glyph = "?"
		_preview.add_child(_captioned(af, "After"))
	_apply.set_enabled(_valid())
	relayout()


static func _captioned(c: Control, text: String) -> VBoxContainer:
	var v := UiTheme.vbox(4)
	v.add_child(c)
	var l := UiTheme.label(text.to_upper(), 16, UiPalette.TEXT_MUTED, false, 0, false, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v


class _FaceButton:
	extends BaseButton
	var face: DieFace
	var face_idx := 0

	static func make(d: Die, f: int, px: float) -> _FaceButton:
		var b := _FaceButton.new()
		b.face_idx = f
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size = Vector2(px, px)
		b.face = DieFace.make(d.faces[f], d.rune, d.edited[f] == 1, px)
		b.face.kind = d.kind
		UiTheme.full_rect(b.face)
		b.add_child(b.face)
		b.pressed.connect(func() -> void:
			UiTheme.sfx("dice_select")
			b.pivot_offset = b.size * 0.5
			UiTheme.pop(b, 1.12, 0.2))
		return b


class _DieTab:
	extends BaseButton
	var die: Die
	var idx := 0
	var selected := false:
		set(v):
			selected = v
			queue_redraw()

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		pressed.connect(func() -> void: UiTheme.sfx("dice_select"))
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if OptionCard.skinned():
			draw_style_box(UiTheme.card_box("selected" if selected else ("hover" if is_hovered() else "normal")), r)
		else:
			if selected:
				draw_style_box(UiTheme.box(Color(0, 0, 0, 0), 18, 0, Color.TRANSPARENT, 14, Color(1, 0.75, 0.25, 0.45), Vector2.ZERO), r)
			draw_style_box(UiTheme.box(UiPalette.NAVY_3 if selected else UiPalette.NAVY_2, 18, 3 if selected else 2,
				UiPalette.GOLD_BRIGHT if selected else Color(1, 1, 1, 0.08)), r)
		# the card's 3D lip takes the bottom of the tab: the die and name sit above it
		var lip := 8.0 if OptionCard.skinned() else 0.0
		var s := minf(size.x - 20.0, size.y - 44.0 - lip)
		var br := Rect2(Vector2((size.x - s) * 0.5, 8), Vector2(s, s))
		# mini die body in rune tint with its best face
		var body := DieFace.body_color(die.rune)
		draw_style_box(UiTheme.box(UiPalette.OUTLINE, int(s * 0.22)), br.grow(2))
		draw_style_box(UiTheme.box(body, int(s * 0.2)), br)
		if die.rune != "":
			# die-face rune glyph: the tinted Flat White rune_face_* art (spec 5 rule 7)
			var tex := Icons.tex("rune_face_" + die.rune, int(s * 1.4))
			var gs := s * 0.62
			draw_texture_rect(tex, Rect2(br.get_center() - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false)
		else:
			draw_circle(br.get_center(), s * 0.09, UiPalette.DIE_PIP)
		if die.kind != "standard":
			DieFace.draw_kind_mark(self, UiPalette.kind_mark(die.kind), br.position + Vector2(s * 0.16, s * 0.16), s * 0.09,
				UiPalette.kind_color(die.kind))
		var f := UiTheme.display_font()
		var t := ("DIE %d" % (idx + 1)) if die.kind == "standard" else String(DiceKinds.def(die.kind).name).to_upper()
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(f, Vector2((size.x - w) * 0.5, size.y - 10 - lip), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			UiPalette.GOLD_BRIGHT if selected else UiPalette.TEXT_DIM)

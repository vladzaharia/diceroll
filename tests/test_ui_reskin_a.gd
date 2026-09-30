extends "res://tests/test_case.gd"
## UI reskin slice (a): the shared factories (pack art present or not), UiFitStyleBox, the
## one-exit UiModal (dismissible / Esc / backdrop / confirm cancel), InputMode and the
## GameButton hover-keycap visibility rules, ToggleSwitch and the plaque title fitting.


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	return k


# ---------------------------------------------------------------- factories

func test_factories_return_styleboxes_with_and_without_art() -> void:
	for pass_ in 2:
		if pass_ == 1:
			UiSkin.set_manifest({})  # the pack absent: every factory falls back to the flat look
		for k in ["main", "main_lg", "card", "card_hi", "inset", "hud", "pill", "tooltip", "tray", "well"]:
			assert_true(UiTheme.panel_box(k) is StyleBox, "panel_box " + k)
			assert_true(UiTheme.panel_box(k, UiPalette.RARE) is StyleBox, "panel_box accent " + k)
		for st in ["normal", "hover", "selected", "worn", "on", "craftable", "owned", "locked", "dim"]:
			assert_true(UiTheme.card_box(st) is StyleBox, "card_box " + st)
		assert_true(UiTheme.card_box("normal", UiPalette.EPIC) is StyleBox, "card accent")
		for f in UiTheme.FAMILIES:
			assert_true(UiTheme.chip_box(f) is StyleBox, "chip " + f)
		assert_true(UiTheme.chip_box(Color(0.2, 0.8, 0.3, 0.5)) is StyleBox, "chip colour")
		assert_true(UiTheme.callout_box(UiPalette.RARE) is StyleBox and UiTheme.callout_box() is StyleBox, "callout")
		assert_true(UiTheme.inset_box() is StyleBox and UiTheme.well_box() is StyleBox, "inset / well")
		assert_true(UiTheme.tag_box(UiPalette.GOLD) is StyleBox and UiTheme.danger_box(UiPalette.HP) is StyleBox, "tag / danger")
		for kind in UiTheme.BARS:
			var b := UiTheme.bar_boxes(kind)
			for key in ["bg", "fill", "ghost", "over"]:
				assert_true(b.get(key) is StyleBox, "bar %s %s" % [kind, key])
		for t in ["reward", "danger", "heal", "info", UiPalette.XP]:
			assert_true(UiTheme.toast_box(t) is StyleBox, "toast %s" % str(t))
		assert_true(UiTheme.plaque_box("purple") is StyleBox and UiTheme.plaque_box(UiPalette.HEAL) is StyleBox, "plaque")
		assert_true(UiTheme.tab_box(true) is StyleBox and UiTheme.tab_track_box() is StyleBox and UiTheme.focus_box() is StyleBox, "tabs / focus")
	# without the pack the accent still shows (the R10 border recolour, no cast needed)
	var pill := UiTheme.panel_box("pill", Color.RED)
	assert_true(pill is StyleBoxFlat and (pill as StyleBoxFlat).border_color.r > 0.9, "flat pill accent border")
	UiSkin.set_manifest(null)


func test_family_of_colours() -> void:
	assert_eq(UiTheme.family_of(UiPalette.GOLD), "yellow")
	assert_eq(UiTheme.family_of(UiPalette.XP), "purple")
	assert_eq(UiTheme.family_of(UiPalette.HP), "red")
	assert_eq(UiTheme.family_of(UiPalette.HEAL), "green")
	assert_eq(UiTheme.family_of(UiPalette.BLOCK), "blue")
	assert_eq(UiTheme.family_of("green"), "green")


func test_palette_pack_tokens() -> void:
	assert_eq(UiPalette.PRIMARY, Color("fdaf18"))
	assert_eq(UiPalette.DANGER, Color("f5535c"))
	assert_eq(UiPalette.INK_LABEL, UiPalette.TEXT_DARK)


func test_pack_manifest_is_complete() -> void:
	var p := UiSkin.load_manifest(UiSkin.PACK_PATH)
	for piece in ["button_primary", "button_secondary", "button_danger", "button_success", "button_ghost",
			"button_primary_sm", "button_ghost_sm", "round_red", "round_grey", "round_yellow", "round_purple", "round_white",
			"chip_red", "chip_grey", "chip_white", "panel_pill", "badge_count", "new_dot", "tab", "tab_track",
			"panel_main", "panel_main_lg", "plaque_yellow", "plaque_red", "plaque_purple", "plaque_green",
			"panel_card", "card_accent", "tooltip", "callout", "toast", "panel_inset", "panel_hud", "well",
			"bar_hp", "bar_block", "bar_xp", "bar_mastery", "bar_loading", "bar_enemy", "bar_par",
			"slider", "toggle", "toggle_track", "toggle_knob", "checkbox", "radio", "scrollbar", "focus_ring"]:
		assert_true(p.has(piece), "ui_pack.json piece " + piece)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		assert_true(p["button_primary"]["states"].has(st), "button state " + st)


func test_fit_stylebox_shrinks_only_small_rects() -> void:
	var f := UiFitStyleBox.new()
	f.min_rect = Vector2(64, 64)
	assert_near(f.fit_scale(Vector2(200, 100)), 1.0)
	assert_near(f.fit_scale(Vector2(200, 32)), 0.5)
	assert_near(f.fit_scale(Vector2(16, 64)), 0.25)


# ---------------------------------------------------------------- UiModal: one exit

func _modal() -> UiModal:
	var m := UiModal.new()
	m.set_title("TEST")
	m.size = Vector2(720, 1280)
	m.show_now()
	return m


func test_modal_default_is_forced() -> void:
	var m := _modal()
	var fired := [0]
	m.dismissed.connect(func() -> void: fired[0] += 1)
	assert_true(not m.dismissible, "forced by default")
	assert_true(not m.close_button.visible, "no close button")
	m._input(_key(KEY_ESCAPE))
	m._request_dismiss()
	assert_eq(fired[0], 0, "Esc / close ignored")
	assert_true(m.is_open(), "still open")
	m.free()


func test_modal_dismissible_close_esc_backdrop() -> void:
	var m := _modal()
	m.dismissible = true
	var fired := [0]
	m.dismissed.connect(func() -> void: fired[0] += 1)
	assert_true(m.close_button.visible, "close button shown")
	assert_true(m.close_button.get_meta(UiAudit.ALLOW, false), "close may straddle the frame")
	assert_eq(m.close_button.piece(), "round_red", "red round close")
	m.close_button.pressed.emit()
	assert_eq(fired[0], 1, "close button dismisses")
	assert_true(not m.is_open(), "closed")
	m.show_now()
	m._input(_key(KEY_ESCAPE))
	assert_eq(fired[0], 2, "Esc dismisses")
	m.show_now()
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.global_position = Vector2(2, 2)
	m._gui_input(mb)
	assert_eq(fired[0], 3, "backdrop dismisses")
	m.show_now()
	m.backdrop_dismiss = false
	m._gui_input(mb)
	assert_eq(fired[0], 3, "backdrop off")
	m.free()


func test_modal_confirm_cancel_and_enter() -> void:
	var m := _modal()
	var cancel := GameButton.make("CANCEL", "", GameButton.Kind.SECONDARY)
	var ok := GameButton.make("OK")
	m.body.add_child(cancel)
	m.body.add_child(ok)
	m.cancel_action = cancel
	m.primary_action = ok
	var hits := {"cancel": 0, "ok": 0}
	cancel.pressed.connect(func() -> void: hits.cancel += 1)
	ok.pressed.connect(func() -> void: hits.ok += 1)
	m._input(_key(KEY_ESCAPE))
	m._input(_key(KEY_ENTER))
	assert_eq(hits.cancel, 1, "Esc = cancel on a confirm dialog")
	assert_eq(hits.ok, 1, "Enter = primary")
	ok.set_enabled(false)
	m._input(_key(KEY_ENTER))
	assert_eq(hits.ok, 1, "disabled primary ignores Enter")
	m.free()


func test_modal_keys_go_to_top_only() -> void:
	var a := _modal()
	var b := _modal()
	a.dismissible = true
	b.dismissible = true
	assert_true(b.is_top() and not a.is_top(), "last opened is on top")
	a._input(_key(KEY_ESCAPE))
	assert_true(a.is_open(), "lower modal ignores Esc")
	b._input(_key(KEY_ESCAPE))
	assert_true(not b.is_open() and a.is_top(), "top closes, next becomes top")
	a.free()
	b.free()


func test_plaque_overlap_is_half_its_height() -> void:
	var m := _modal()
	if m.ribbon.skinned():
		assert_eq(m.header_overlap(), round(m.plaque_height() * 0.5))
		assert_eq(m._frame.get_theme_constant("separation"), -int(m.header_overlap()))
	m.free()


func test_plaque_title_shrinks_then_truncates() -> void:
	var r := Ribbon.make("A VERY LONG MODAL TITLE THAT DOES NOT FIT", 44)
	r.max_width = 360.0
	if r.skinned():
		assert_eq(r.fitted_font(), Ribbon.MIN_FONT, "shrinks to 30")
		assert_true(r.shown_text().ends_with("…"), "then truncates")
		assert_true(r.get_minimum_size().x <= 360.0, "never wider than allowed")
	r.free()


# ---------------------------------------------------------------- InputMode + hover keycap

func test_input_mode_switches() -> void:
	InputMode.reset(true)
	assert_true(InputMode.is_kbm(), "desktop default")
	var t := InputEventScreenTouch.new()
	t.pressed = true
	InputMode.note_event(t)
	assert_true(InputMode.is_touch(), "touch switches")
	var em := InputEventMouseButton.new()
	em.device = InputEvent.DEVICE_ID_EMULATION
	em.pressed = true
	InputMode.note_event(em)
	assert_true(InputMode.is_touch(), "touch-emulated mouse stays touch")
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(5, 0)
	InputMode.note_event(mm)
	assert_true(InputMode.is_kbm(), "real mouse motion -> kbm")
	InputMode.note_event(t)
	InputMode.note_event(_key(KEY_A))
	assert_true(InputMode.is_kbm(), "any key -> kbm")
	InputMode.set_override("never", false)
	assert_true(not InputMode.is_kbm(), "Never override")
	InputMode.set_override("always", false)
	InputMode.note_event(t)
	assert_true(InputMode.is_kbm(), "Always override")
	InputMode.reset()


func test_hover_keycap_rules() -> void:
	InputMode.reset(true)
	var b := GameButton.make("REROLL", "reroll", GameButton.Kind.SECONDARY)
	b.shortcut_hint = "key_r"
	b._ready()
	b.size = Vector2(320, 88)
	assert_true(b.keycap_allowed(), "text button, kbm")
	b._show_keycap(true)
	assert_true(b._keycap != null, "keycap made on hover")
	var kr := Rect2(b._keycap.position, b._keycap.size)
	assert_true(Rect2(Vector2.ZERO, b.size).encloses(kr), "keycap inside the button")
	assert_true(b._keycap.mouse_filter == Control.MOUSE_FILTER_IGNORE, "does not take input")
	assert_true(b.keycap_visible(), "shown at hover")
	assert_near(b._keycap.modulate.a, GameButton.KEYCAP_ALPHA, 0.001, "60% opacity")
	b._show_keycap(false)
	assert_true(not b.keycap_visible(), "gone on exit")
	var t := InputEventScreenTouch.new()
	t.pressed = true
	InputMode.note_event(t)
	assert_true(not b.keycap_allowed(), "never in touch mode")
	InputMode.reset(true)
	b.set_enabled(false)
	assert_true(not b.keycap_allowed(), "not on disabled buttons")
	var plain := GameButton.make("GO")
	assert_true(not plain.keycap_allowed(), "no shortcut, no keycap")
	var r := GameButton.round_icon("pause", 88)
	r.shortcut_hint = "key_esc"
	r.tooltip_text = "Pause"
	assert_true(not r.keycap_allowed(), "round buttons: no keycap")
	assert_eq(r._get_tooltip(Vector2.ZERO), "Pause (ESC)", "round: shortcut in the tooltip")
	b.free()
	plain.free()
	r.free()
	InputMode.reset()


func test_small_button_keeps_touch_hit_rect() -> void:
	var b := GameButton.make("BUY", "", GameButton.Kind.PRIMARY, 26)
	b.min_height = 72
	b._ready()
	if b.skinned():
		assert_true(b.piece().ends_with("_sm"), "1.0 scale art at 72 px")
		assert_true(b.get_combined_minimum_size().y >= UiTheme.TOUCH, "88 px hit rect")
		b.size = b.get_combined_minimum_size()
		assert_near(b.box_rect().size.y, 72.0, 0.5, "drawn at 72")
	b.free()


func test_toggle_switch_knob() -> void:
	var s := ToggleSwitch.make(false)
	assert_near(s.knob(), 0.0)
	s.set_pressed_no_signal(true)
	s._on_toggled(true)
	assert_near(s.knob(), 1.0, 0.001, "outside the tree it snaps")
	assert_true(s.get_combined_minimum_size().y >= UiTheme.TOUCH, "88 px hit row")
	s.free()


func test_toast_box() -> void:
	var p := Toast.make("Hello", "coin", UiPalette.GOLD)
	assert_true(p.get_theme_stylebox("panel") is StyleBox, "callout box")
	assert_true(p.find_child("Text", true, false) is Label, "label")
	assert_eq(Toast._rim_for(UiPalette.HP), "danger")
	assert_eq(Toast._rim_for(UiPalette.HEAL), "heal")
	assert_eq(Toast._rim_for(UiPalette.TEXT), "info")
	p.free()

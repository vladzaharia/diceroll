extends "res://tests/test_case.gd"
## Slice (c) one-exit rule (spec 3.2, modal inventory): which modals are dismissible (header
## close button + Esc + backdrop), which are forced, which keep an explicit cancel, that the
## removed DONE / CLOSE / LEAVE / SKIP buttons are gone, and the Enter / Esc key paths.

const REMOVED := ["DONE", "CLOSE", "LEAVE", "SKIP", "DEFAULTS"]


## Every GameButton label under `n` (upper-cased).
func _labels(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "GameButton", true, false):
		out.append(String((c as GameButton).text).to_upper())
	return out


func _key(m: UiModal, code: Key) -> void:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	m._input(k)


## Opens `m` without tweens at a phone canvas size (keys go to the top-most open modal).
func _open(m: UiModal) -> UiModal:
	m.size = Vector2(720, 1280)
	m.show_now()
	return m


func _done(m: UiModal) -> void:
	if is_instance_valid(m):
		m.free()


func _no_removed_buttons(m: UiModal, name: String) -> void:
	for l in _labels(m):
		assert_true(not REMOVED.has(l), "%s still has a %s button" % [name, l])


# ---------------------------------------------------------------- inventory

func test_dismissible_modals_have_no_bottom_dismiss_button() -> void:
	for m: UiModal in [SettingsPanel.new(), AutoSettingsPanel.new(), DevMenu.new(), DieInspector.new(),
			ShopModal.new(), ForgeModal.new()]:
		var name := str(m.get_script().get_global_name())
		assert_true(m.dismissible, "%s is dismissible (close button + Esc + backdrop)" % name)
		_no_removed_buttons(m, name)
		m.free()


func test_forced_modals_have_no_close() -> void:
	for m: UiModal in [DraftModal.new(), PassiveModal.new(), EventModal.new(), RuneAssignModal.new(),
			RouteCard.new(), MinigameRewardModal.new(), SummaryScreen.new(), PauseMenu.new()]:
		var name := str(m.get_script().get_global_name())
		assert_true(not m.dismissible, "%s is not dismissible" % name)
		m.free()


func test_close_tooltips_name_the_consequence() -> void:
	var s := ShopModal.new()
	assert_eq(s.close_tooltip, "Leave shop")
	s.free()
	var f := ForgeModal.new()
	assert_eq(f.close_tooltip, "Skip the forge")
	f.free()


func test_primary_actions() -> void:
	var d := DraftModal.new()
	assert_eq(d.primary_action, d._take, "draft: Enter = TAKE")
	assert_eq(d._take.kind, GameButton.Kind.SUCCESS, "TAKE is SUCCESS (spec 4.3)")
	d.free()
	var p := PassiveModal.new()
	assert_eq(p.primary_action, p._take, "passive: Enter = TAKE")
	p.free()
	var r := RuneAssignModal.new()
	assert_eq(r.primary_action, r._bind, "rune assign: Enter = BIND RUNE")
	r.free()
	var s := SummaryScreen.new()
	assert_eq(s.primary_action, s._camp_btn, "results: Enter = TO CAMP")
	s.free()
	var e := EventModal.new()
	assert_eq(e.primary_action, null, "events have no default choice")
	e.free()
	var sh := ShopModal.new()
	assert_eq(sh.primary_action, sh._buy, "shop: Enter = BUY")
	sh.free()
	var fo := ForgeModal.new()
	assert_eq(fo.primary_action, fo._apply, "forge: Enter = FORGE")
	fo.free()


func test_settings_sections() -> void:
	var s := SettingsPanel.new()
	var labels := _labels(s)
	assert_true(labels.has("AUTO SETTINGS"), "AUTO SETTINGS kept")
	assert_true(not labels.has("DONE"), "no DONE")
	assert_eq(s._speed_btns.size(), 3, "speed segments")
	assert_eq(s._size_btns.size(), 4, "UI size segments")
	assert_true(s._update_btn is ToggleSwitch, "auto-update is a ToggleSwitch")
	var credits := false
	for l in s.find_children("*", "Label", true, false):
		if String((l as Label).text).contains("RhosGFX"):
			credits = true
	assert_true(credits, "RhosGFX credit line")
	if InputMode.platform_default_kbm():
		assert_true(s._controls is ControlsList, "desktop: Controls list")
	s.free()


func test_controls_list_covers_every_action_row() -> void:
	var c := ControlsList.make()
	for r: Dictionary in InputActions.list():
		var row := c.find_child("Row_" + String(r["action"]), true, false)
		assert_true(row != null, "Controls row for %s" % r["action"])
		if row:
			assert_true(row.find_children("*", "KeyGlyph", true, false).size() >= 1, "%s shows its keycaps" % r["action"])
	c.free()


func test_auto_settings_reset_is_a_normal_width_ghost() -> void:
	var a := AutoSettingsPanel.new()
	var reset := a.find_child("Reset", true, false) as GameButton
	assert_true(reset != null, "Reset to defaults button")
	if reset:
		assert_eq(reset.kind, GameButton.Kind.GHOST)
		assert_true(reset.size_flags_horizontal != Control.SIZE_EXPAND_FILL, "normal width")
	a.free()


# ---------------------------------------------------------------- key paths

func test_shop_esc_leaves() -> void:
	var s := _open(ShopModal.new()) as ShopModal
	var left := []
	s.shop_leave_pressed.connect(func() -> void: left.append(1))
	_key(s, KEY_ESCAPE)
	assert_eq(left.size(), 1, "Esc = leave shop")
	s.close_button.pressed.emit()
	assert_eq(left.size(), 2, "close button = leave shop")
	_done(s)


func test_forge_esc_skips() -> void:
	var f := _open(ForgeModal.new()) as ForgeModal
	var got := []
	f.forge_apply.connect(func(d: int, fa: int, op: String, src: int) -> void: got.append([d, fa, op, src]))
	_key(f, KEY_ESCAPE)
	assert_eq(got, [[-1, -1, "skip", -1]], "Esc = skip the forge")
	_done(f)


func test_die_inspector_esc_closes() -> void:
	var d := _open(DieInspector.new()) as DieInspector
	var got := []
	d.closed_by_player.connect(func() -> void: got.append(1))
	_key(d, KEY_ESCAPE)
	assert_eq(got.size(), 1, "Esc closes the inspector")
	assert_true(not d.is_open(), "closing")
	_done(d)


func test_draft_ignores_esc_and_takes_on_enter() -> void:
	var d := _open(DraftModal.new()) as DraftModal
	var got := []
	d.draft_picked.connect(func(i: int) -> void: got.append(i))
	_key(d, KEY_ESCAPE)
	assert_true(d.is_open(), "forced: Esc does nothing")
	_key(d, KEY_ENTER)
	assert_eq(got, [], "Enter with no choice does nothing (TAKE disabled)")
	d._choice = 1
	d._take.set_enabled(true)
	_key(d, KEY_ENTER)
	assert_eq(got, [1], "Enter = TAKE")
	_done(d)


func test_pause_esc_resumes_and_confirm_cancels() -> void:
	var p := _open(PauseMenu.new()) as PauseMenu
	var resumed := []
	var abandoned := []
	p.resume_pressed.connect(func() -> void: resumed.append(1))
	p.abandon_confirmed.connect(func() -> void: abandoned.append(1))
	assert_true(not p.close_button.visible, "pause has no close button")
	_key(p, KEY_ESCAPE)
	assert_eq(resumed.size(), 1, "Esc = RESUME")
	_key(p, KEY_ENTER)
	assert_eq(resumed.size(), 2, "Enter = RESUME")
	p._ask()
	assert_true(p._confirm.visible, "abandon confirm up")
	assert_eq(p.ribbon.plaque_family(), "red", "red plaque")
	_key(p, KEY_ENTER)
	assert_eq(abandoned.size(), 0, "Enter never abandons")
	assert_true(not p._confirm.visible, "Enter = KEEP PLAYING (the safe option)")
	p._ask()
	_key(p, KEY_ESCAPE)
	assert_true(not p._confirm.visible, "Esc = KEEP PLAYING")
	assert_eq(resumed.size(), 2, "Esc in the confirm does not resume")
	assert_eq(abandoned.size(), 0)
	_done(p)


func test_pause_buttons_are_sized_by_importance() -> void:
	var p := PauseMenu.new()
	assert_eq(p._resume.size_flags_horizontal, Control.SIZE_FILL, "RESUME full width (VBox fill)")
	var labels := _labels(p)
	for l in ["RESUME", "SETTINGS", "ABANDON RUN", "KEEP PLAYING", "ABANDON"]:
		assert_true(labels.has(l), "pause has %s" % l)
	p.free()


func test_dev_menu_confirm_is_a_confirm_dialog() -> void:
	var m := _open(DevMenu.new()) as DevMenu
	assert_true(m.dismissible, "dev menu: close button + Esc")
	m._confirm.visible = true
	m._set_confirming(true)
	assert_true(not m.dismissible, "confirm: no close button")
	assert_eq(m.cancel_action, m._confirm_cancel, "Esc = CANCEL")
	_key(m, KEY_ESCAPE)
	assert_true(not m._confirm.visible, "Esc cancelled the switch")
	assert_true(m.dismissible, "back to the menu: dismissible again")
	assert_true(m.is_open(), "the menu stays open")
	_key(m, KEY_ESCAPE)
	assert_true(not m.is_open(), "Esc then closes the menu")
	_done(m)


func test_results_is_forced() -> void:
	var s := _open(SummaryScreen.new()) as SummaryScreen
	_key(s, KEY_ESCAPE)
	assert_true(s.is_open(), "results: Esc does nothing")
	assert_true(not s.close_button.visible, "no close button")
	_done(s)

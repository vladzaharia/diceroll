extends "res://tests/test_case.gd"
## Settings UI size x the landscape phone boost (UiTheme.landscape_ui_boost): applied by
## SettingsPanel.apply_ui_size on top of the window's base scale and re-applied on resize.


func _teardown_safe() -> void:
	UiTheme._safe_emu = []
	UiTheme._safe_emu_read = false


func _phone(on: bool) -> void:
	# emulate a phone (the harness --safe insets) or a desktop
	UiTheme._safe_emu = [0.0, 0.052, 0.071, 0.071] if on else []
	UiTheme._safe_emu_read = true


func test_effective_scale_desktop_and_portrait() -> void:
	_phone(false)
	assert_near(SettingsPanel.effective_ui_scale(1.15, Vector2(2622, 1206)), 1.15, 0.0001, "desktop: no boost")
	_phone(true)
	assert_near(SettingsPanel.effective_ui_scale(1.0, Vector2(1206, 2622)), 1.0, 0.0001, "phone portrait: no boost")
	assert_near(SettingsPanel.effective_ui_scale(1.15, Vector2(2622, 1206)), 1.15 * UiTheme.LANDSCAPE_BOOST, 0.0001,
		"phone landscape: UI size x boost")
	_teardown_safe()


func test_apply_ui_size_follows_rotation() -> void:
	_phone(true)
	var w := Window.new()
	w.content_scale_factor = 2.0
	w.size = Vector2i(1206, 2622)
	SettingsPanel.apply_ui_size(w, 1.0)
	assert_near(w.content_scale_factor, 2.0, 0.0001, "portrait: base x 1")
	assert_true(w.has_meta("ui_size_tracked"), "resize tracked")
	# rotate: the size_changed hook re-applies with the boost (saved UI size, 1.0 in tests)
	w.size = Vector2i(2622, 1206)
	w.size_changed.emit()
	assert_near(w.content_scale_factor, 2.0 * SettingsPanel.ui_size() * UiTheme.LANDSCAPE_BOOST, 0.0001, "landscape: boosted")
	w.size = Vector2i(1206, 2622)
	w.size_changed.emit()
	assert_near(w.content_scale_factor, 2.0 * SettingsPanel.ui_size(), 0.0001, "back to portrait")
	w.free()
	_teardown_safe()

extends "res://tests/test_case.gd"
## Desktop start-up window (game/boot/desktop_window.gd): landscape 1600x900 fitted to 85 % of
## the screen, never under 1280x720 unless the screen is smaller, centred; phones and explicit
## --resolution runs (the screenshot harness) untouched.


func _check(usable: Rect2i, scale: float, want: Vector2i, msg: String) -> void:
	var r := DesktopWindow.fit(usable, scale)
	assert_eq(r.size, want, msg)
	var c := Vector2(r.position) + Vector2(r.size) * 0.5
	var uc := Vector2(usable.position) + Vector2(usable.size) * 0.5
	assert_true(c.distance_to(uc) <= 1.0, msg + ": centred")
	assert_true(Rect2(usable).encloses(Rect2(r)), msg + ": on screen")
	assert_true(r.size.x > r.size.y, msg + ": landscape")


func test_fit_common_screens() -> void:
	_check(Rect2i(0, 0, 2560, 1400), 1.0, Vector2i(1600, 900), "1440p: full target")
	_check(Rect2i(0, 25, 1920, 1055), 1.0, Vector2i(1594, 897), "1080p with a taskbar: 85 % of the height")
	# MacBook Air 13" (1440x900 points, Retina): logical 1280x720 minimum, in pixels
	_check(Rect2i(0, 50, 2880, 1750), 2.0, Vector2i(2560, 1440), "Retina laptop: the minimum")
	_check(Rect2i(0, 0, 1366, 728), 1.0, Vector2i(1280, 720), "1366x768: the minimum still fits")


func test_fit_small_screen_shrinks_minimum() -> void:
	var u := Rect2i(0, 0, 1024, 600)
	var m := DesktopWindow.min_size(u, 1.0)
	assert_true(m.x <= 1024 * 0.85 + 0.5 and m.y <= 600 * 0.85 + 0.5, "minimum shrunk to the screen")
	assert_near(m.x / m.y, 16.0 / 9.0, 0.01, "16:9 kept")
	_check(u, 1.0, Vector2i(m.round()), "tiny screen")
	assert_eq(DesktopWindow.min_size(Rect2i(0, 0, 1920, 1080), 1.0), Vector2(1280, 720))


func test_explicit_resolution_wins() -> void:
	# headless (this test run) never resizes
	assert_true(not DesktopWindow.should_apply(PackedStringArray(), Vector2i(1600, 900)), "headless: skipped")
	assert_true(not DesktopWindow.should_apply(PackedStringArray(["--scenario=game_title"]), Vector2i(1600, 900)),
		"screenshot harness: skipped")
	if OS.has_feature("pc"):
		# Godot eats --resolution before scripts run: a non-project window size means it was given
		assert_true(DesktopWindow.is_project_size(Vector2i(1600, 900)), "the .pc override")
		assert_true(DesktopWindow.is_project_size(Vector2i(3200, 1800), 2.0), "the override on Retina")
		assert_true(not DesktopWindow.is_project_size(Vector2i(720, 1280), 2.0), "--resolution 720x1280")
		assert_true(not DesktopWindow.is_project_size(Vector2i(1280, 720)), "--resolution 1280x720")


func test_project_window_settings() -> void:
	# portrait-first base stays (phones); desktop opens landscape via the .pc override
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_width")), 720)
	assert_eq(int(ProjectSettings.get_setting("display/window/size/viewport_height")), 1280)
	assert_eq(int(ProjectSettings.get_setting("display/window/handheld/orientation")), 1, "portrait on phones")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load("res://project.godot"), OK)
	assert_eq(int(cfg.get_value("display", "window/size/window_width_override.pc", 0)), 1600)
	assert_eq(int(cfg.get_value("display", "window/size/window_height_override.pc", 0)), 900)
	assert_eq(int(cfg.get_value("display", "window/size/window_width_override", 0)), 540, "non-desktop default")
	if OS.has_feature("pc"):
		assert_eq(int(ProjectSettings.get_setting_with_override("display/window/size/window_width_override")), 1600,
			"the engine opens desktop windows at 1600 wide")

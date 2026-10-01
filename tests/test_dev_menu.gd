extends "res://tests/test_case.gd"
## Hidden Developer menu: corner-gesture counter, registration API, diagnostics text.

const VIEW := Vector2(1920, 1080)
const CORNER := Vector2(1900, 1060)


func test_five_quick_corner_taps_unlock() -> void:
	var g := DevGesture.new()
	var hits := 0
	for i in 5:
		if g.tap(CORNER, 1000 + i * 400, VIEW):
			hits += 1
			assert_eq(i, 4, "unlocks on the 5th tap")
	assert_eq(hits, 1)
	assert_eq(g.tap_count(), 0, "counter restarts after unlocking")
	g.free()


func test_corner_rect_and_safe_inset() -> void:
	assert_eq(DevGesture.corner_rect(VIEW), Rect2(1840, 1000, 80, 80))
	var r := DevGesture.corner_rect(Vector2(402, 874), Vector2(0, 34))
	assert_eq(r, Rect2(322, 760, 80, 80), "lifted above the home indicator")
	var g := DevGesture.new()
	for i in 5:
		assert_true(not g.tap(Vector2(400, 860), i * 100, Vector2(402, 874), Vector2(0, 34)),
			"taps on the home-indicator strip don't count")
	var won := false
	for i in 5:
		won = g.tap(Vector2(380, 800), i * 100, Vector2(402, 874), Vector2(0, 34))
	assert_true(won, "taps inside the lifted corner count")
	g.free()


func test_taps_outside_corner_do_not_count() -> void:
	var g := DevGesture.new()
	for i in 4:
		g.tap(CORNER, i * 100, VIEW)
	assert_eq(g.tap_count(), 4)
	assert_true(not g.tap(Vector2(1830, 1060), 450, VIEW), "just left of the corner")
	assert_eq(g.tap_count(), 0, "an outside tap resets the sequence")
	for p in [Vector2(10, 10), Vector2(960, 540), Vector2(1900, 990), Vector2(1839, 1079)]:
		assert_true(not g.tap(p, 500, VIEW))
	assert_eq(g.tap_count(), 0)
	g.free()


func test_slow_taps_do_not_count() -> void:
	var g := DevGesture.new()
	var won := false
	for i in 8:
		won = won or g.tap(CORNER, i * 1000, VIEW)
	assert_true(not won, "one tap per second never fits 5 taps into 3 s")
	# the window slides: after slow taps, a quick burst still unlocks
	var t := 20000
	for i in 5:
		won = g.tap(CORNER, t + i * 200, VIEW)
	assert_true(won)
	# exactly at the edge: 5 taps spanning 3000 ms count, 3001 ms don't
	assert_true(_burst(g, [0, 750, 1500, 2250, 3000]))
	assert_true(not _burst(g, [100000, 100750, 101500, 102250, 103001]))
	g.free()


func _burst(g: DevGesture, times: Array) -> bool:
	var won := false
	for tm: int in times:
		won = g.tap(CORNER, tm, VIEW)
	g.tap(Vector2.ZERO, 0, VIEW)  # reset
	return won


func test_registration_api() -> void:
	var ids := DevMenu.section_ids()
	assert_true("updates" in ids and "build" in ids, str(ids))
	assert_true(ids.find("updates") < ids.find("build"), "ordered")
	assert_eq(DevMenu.row_ids("updates"), PackedStringArray(["channel", "actions"]))
	DevMenu.register_section("zz_test", "TEST", 50)
	DevMenu.register_row("zz_test", "b", func(m: DevMenu) -> Control: return m.info_row("B", "2"), 20)
	DevMenu.register_row("zz_test", "a", func(m: DevMenu) -> Control: return m.info_row("A", "1"), 10)
	assert_eq(DevMenu.row_ids("zz_test"), PackedStringArray(["a", "b"]), "rows sorted by order")
	ids = DevMenu.section_ids()
	assert_true(ids.find("updates") < ids.find("zz_test") and ids.find("zz_test") < ids.find("build"))
	var menu := DevMenu.new()
	assert_true(menu.body.find_child("zz_test_a", true, false) != null, "registered row built into the menu")
	assert_true(menu.body.find_child("updates_channel", true, false) != null)
	assert_true(menu.body.find_child("build_info", true, false) != null)
	menu.free()
	DevMenu.unregister_row("zz_test", "a")
	DevMenu.unregister_row("zz_test", "b")
	assert_eq(DevMenu.row_ids("zz_test"), PackedStringArray())
	menu = DevMenu.new()
	assert_true(menu.body.find_child("zz_test_a", true, false) == null, "empty sections are skipped")
	menu.free()


func test_diagnostics_text() -> void:
	var info := {"version": "0.2.0", "commit": "abc1234", "channel": "stable", "distribution": "github",
		"godot": "4.7.2", "built": "2026-09-29T12:00:00Z"}
	var t := DevMenu.diagnostics_text(info, "beta", true, "macos", "0.2.1")
	for s in ["version: 0.2.0", "running: 0.2.1", "commit: abc1234", "channel: beta (override; build stable)",
			"distribution: github", "godot: 4.7.2", "built: 2026-09-29T12:00:00Z", "platform: macos"]:
		assert_true(t.contains(s), "missing '%s' in:\n%s" % [s, t])
	t = DevMenu.diagnostics_text(info, "stable", false, "ios", "0.2.0")
	assert_true(not t.contains("running:") and not t.contains("override"))

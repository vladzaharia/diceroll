extends "res://tests/test_case.gd"
## Lucky Wheel presentation: the board's pure helpers agree with the core's wheel geometry and
## brake rules, and the board adapts to the core's spin count.


## The wedge drawn under the pointer (screen angle -90 deg) is the segment the core reads.
func test_pointer_reads_the_core_segment() -> void:
	for a in [0.0, 14.9, 15.0, 29.99, 30.0, 181.3, 359.9, 725.0, -10.0]:
		var seg := LuckyWheel.segment_at(a)
		var local := fposmod(a, 360.0)
		var sa := WheelBoard.screen_angle(local, a)
		assert_true(is_equal_approx(fposmod(rad_to_deg(sa), 360.0), 270.0), "local angle %s is under the pointer" % a)
		assert_true(local >= seg * LuckyWheel.SEG_DEG and local < (seg + 1) * LuckyWheel.SEG_DEG, "segment span %s" % a)
	# growing wheel angle moves the next index under the pointer, turning clockwise on screen
	var s0 := WheelBoard.screen_angle(45.0, 30.0)
	var s1 := WheelBoard.screen_angle(45.0, 31.0)
	assert_true(s1 > s0, "clockwise")


## Taps before the window slip (TOO FAST, never sent), inside it they brake.
func test_tap_kinds_match_the_core_window() -> void:
	var sp := {"from": 10.0, "total": 1200.0, "dur": 4.5, "window": LuckyWheel.NUDGE_WINDOW}
	assert_eq(WheelBoard.tap_kind(0.5, sp), "early")
	assert_eq(WheelBoard.tap_kind(4.5 - LuckyWheel.NUDGE_WINDOW - 0.01, sp), "early")
	assert_eq(WheelBoard.tap_kind(4.5 - LuckyWheel.NUDGE_WINDOW + 0.01, sp), "brake")
	assert_eq(WheelBoard.tap_kind(4.49, sp), "brake")
	assert_eq(WheelBoard.tap_kind(4.6, sp), "late")


## The brake settle never swings the wheel into a neighbouring wedge.
func test_settle_stays_in_segment() -> void:
	for a in [0.2, 1.0, 14.0, 28.5, 29.9, 100.0, 359.5]:
		var amp := WheelBoard.settle_amp(a, 400.0)
		assert_true(amp >= 0.0, "amp >= 0")
		assert_eq(LuckyWheel.segment_at(a + amp), LuckyWheel.segment_at(a), "forward swing %s" % a)
		assert_eq(LuckyWheel.segment_at(a - amp * 0.45), LuckyWheel.segment_at(a), "back swing %s" % a)


## Icons: the top prize is the chest, everything below maps to coins / gold / a gem.
func test_icons_by_value() -> void:
	assert_eq(WheelBoard.icon_key(12, 12), 12)
	assert_eq(WheelBoard.icon_key(9, 12), 9)
	assert_eq(WheelBoard.icon_key(2, 12), 2)
	assert_eq(WheelBoard.icon_key(8, 12), 7)
	assert_eq(WheelBoard.icon_key(10, 10), 12)
	for v in LuckyWheel.SEGMENT_VALUES:
		assert_true(ResourceLoader.exists(WheelBoard.icon_path(int(v), 12)), "icon model for %d" % v)


## The spin slots follow the core's count (results + actions left), not a constant.
func test_slots_follow_spin_count() -> void:
	var m := Minigames.create("lucky_wheel", 5, 1)
	var b := WheelBoard.new()
	b.size = Vector2(400, 600)
	b.set_state(m.public_state(), true)
	assert_eq(b.spins_total(), LuckyWheel.SPINS)
	var st := m.public_state()
	st["actions_left"] = 3
	b.set_state(st, true)
	assert_eq(b.spins_total(), 3)
	b._layout()
	assert_eq(b._slots.size(), 3)
	for r in b._slots:
		assert_true(Rect2(Vector2.ZERO, b.size).encloses(r), "slot inside the board")
	b.free()

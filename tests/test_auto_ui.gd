extends "res://tests/test_case.gd"
## Speed pill (WP-D2). EventPlayer.condense and AutoScenarios need the autoloads (Audio),
## which the -s test runner doesn't load; they are covered by play_auto --ui-auto=1 --speed=4.


func test_speed_pill_cycles() -> void:
	assert_eq(SpeedPill.next_speed(1.0), 2.0)
	assert_eq(SpeedPill.next_speed(2.0), 4.0)
	assert_eq(SpeedPill.next_speed(4.0), 1.0)
	assert_eq(SpeedPill.next_speed(3.0), 4.0, "play_auto's 3x steps to 4x")

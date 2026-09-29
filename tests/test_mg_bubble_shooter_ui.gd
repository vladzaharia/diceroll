extends "res://tests/test_case.gd"
## Bubble Shooter board helpers: the pointer -> angle step quantisation round-trips exactly,
## and the aim guide stops at the first wall bounce plus a short stub (never the full flight).


func test_pointer_maps_back_to_every_angle_step() -> void:
	for sz in [Vector2(402, 540), Vector2(620, 620), Vector2(1000, 700)]:
		var b := ShooterBoard.new()
		b.size = sz
		b._layout()
		for idx in BubbleShooter.ANGLES:
			var a := BubbleShooter.angle_of(idx)
			var p := b.P(BubbleShooter.LAUNCH + Vector2(sin(a), -cos(a)) * 3.6)
			assert_eq(b.idx_toward(p), idx, "step %d at %s" % [idx, str(sz)])
		# at or below the launcher: no aim (the drag cancels)
		assert_eq(b.idx_toward(b.P(BubbleShooter.LAUNCH + Vector2(1.0, 0.5))), -1, "below the launcher")
		b.free()


func test_guide_stops_after_the_first_bounce() -> void:
	var g: Array = Minigames.create("bubble_shooter", 3, 1).public_state().grid
	var bounced := 0
	for idx in BubbleShooter.ANGLES:
		var path: Array = BubbleShooter.trace(g, idx).path
		var pts := ShooterBoard.guide_points(path)
		assert_true(pts.size() >= 2 and pts.size() <= 3, "guide size %d" % pts.size())
		var first := Vector2(float(path[1][0]), float(path[1][1]))
		assert_true((pts[1] as Vector2).distance_to(first) < 0.001, "guide follows the traced flight")
		if pts.size() == 3:
			bounced += 1
			assert_true((pts[2] as Vector2).distance_to(pts[1]) <= ShooterBoard.STUB + 0.001, "stub is short")
	assert_true(bounced > 20, "wide shots bounce (%d)" % bounced)

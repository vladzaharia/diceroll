extends "res://tests/test_case.gd"
## ShellBoard pure helpers: the swap arc, the tap -> slot mapping, and the shuffle bookkeeping
## (the cup that hid the gem ends where the core says, at the real-time pace).


func test_swap_pose_endpoints_and_depth() -> void:
	var p0 := ShellBoard.swap_pose(0, 2, 0.0, true)
	var p1 := ShellBoard.swap_pose(0, 2, 1.0, true)
	var mid := ShellBoard.swap_pose(0, 2, 0.5, true)
	assert_near(float(p0[0]), 0.0, 0.001, "a starts at a")
	assert_near(float(p0[2]), 2.0, 0.001, "b starts at b")
	assert_near(float(p1[0]), 2.0, 0.001, "a lands on b")
	assert_near(float(p1[2]), 0.0, 0.001, "b lands on a")
	assert_true(float(mid[1]) > 0.9 and float(mid[3]) < -0.9, "one cup in front, one behind")
	assert_true(float(mid[4]) > float(ShellBoard.swap_pose(0, 1, 0.5, true)[4]), "the far swap hops higher")
	var back := ShellBoard.swap_pose(1, 2, 0.5, false)
	assert_true(float(back[1]) < 0.0, "a_front=false sends the a-cup behind")


func test_nearest_slot() -> void:
	var xs := [100.0, 200.0, 300.0]
	assert_eq(ShellBoard.nearest_slot(110.0, xs, 50.0), 0)
	assert_eq(ShellBoard.nearest_slot(240.0, xs, 50.0), 1)
	assert_eq(ShellBoard.nearest_slot(349.0, xs, 50.0), 2)
	assert_eq(ShellBoard.nearest_slot(400.0, xs, 50.0), -1)


func test_shuffle_tracks_the_core() -> void:
	for seed in 12:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var start := rng.randi_range(0, 2)
		var swaps: Array = []
		for k in 6 + seed % 5:
			var a := rng.randi_range(0, 2)
			var b := (a + 1 + rng.randi_range(0, 1)) % 3
			swaps.append([mini(a, b), maxi(a, b)])
		var st := {"cups": 3, "round": 0, "rounds": 3, "start": start, "swaps": swaps, "swap_time": 0.3, "results": [],
			"actions_left": 3, "done": false}
		var b := ShellBoard.new()
		b.size = Vector2(400, 500)
		b.set_state(st, true)
		b._phase = "shuffle"
		b._swap_i = 0
		b._swap_t = 0.0
		var t := 0.0
		while b._phase == "shuffle" and t < 20.0:
			b._tick(0.05)
			t += 0.05
		assert_eq(b._phase, "pick", "shuffle ends in the pick phase")
		assert_near(t, swaps.size() * 0.3, 0.051, "real-time pace")
		assert_eq(int(b._slot[start]), ShellGame.follow(start, swaps), "seed %d: the gem cup lands where the core says" % seed)
		b.free()

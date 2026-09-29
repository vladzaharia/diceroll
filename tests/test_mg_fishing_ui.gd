extends "res://tests/test_case.gd"
## FishingBoard: every catch the core can land has a look, the spots line up with the core's,
## and a board restored mid-bite starts a fresh wait on the core's public bite data.


func test_every_core_kind_has_a_look() -> void:
	for d: Dictionary in Fishing.SPOTS:
		for f: Array in d.fish:
			assert_true(FishingBoard.KINDS.has(String(f[0])), "no look for %s" % f[0])


func test_spots_match_core() -> void:
	assert_eq(FishingBoard.SPOT_AT.size(), Fishing.SPOTS.size())
	assert_eq(FishingBoard.SPOT_NAMES.size(), Fishing.SPOTS.size())


func test_restore_mid_bite_waits() -> void:
	var b := FishingBoard.new()
	b.size = Vector2(400, 480)
	b.set_state({"phase": "bite", "casts": 3, "spot": 2, "bite_at": 2.0, "window": 0.48, "nibbles": [0.8],
		"catches": [], "actions_left": 3, "done": false}, true)
	assert_eq(b._mode, "wait")
	assert_eq(b._spot, 2)
	assert_near(b._bite_at, 2.0)
	assert_true(not b.is_settled(), "waiting on a bite is not settled")
	b.set_state({"phase": "cast", "casts": 3, "spot": -1, "catches": [{"spot": 0, "result": "caught", "kind": "perch", "points": 3,
		"perfect": false, "t": 1.5}], "actions_left": 2, "done": false}, true)
	assert_eq(b._mode, "aim")
	assert_eq(b._tray.size(), 1)
	assert_true(b.is_settled(), "aiming is settled")
	b.free()

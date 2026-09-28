extends "res://tests/test_case.gd"

func _count(b: Board, type: String) -> int:
	var n := 0
	for t in b.tiles:
		if t.type == type:
			n += 1
	return n

func test_generation_constraints_many_seeds() -> void:
	for s in 40:
		var b := Board.generate(Rng.new(s), 1)
		assert_eq(b.tiles.size(), 24, "24 tiles")
		assert_eq(b.tiles[0].type, "start")
		assert_eq(b.tiles[6].type, "forge")
		assert_eq(b.tiles[12].type, "treasury")
		assert_eq(b.tiles[18].type, "portal")
		assert_eq(_count(b, "enemy"), 6, "enemies seed %d" % s)
		assert_eq(_count(b, "chest"), 3)
		assert_eq(_count(b, "event"), 3)
		assert_eq(_count(b, "campfire"), 2)
		assert_eq(_count(b, "trap"), 2)
		assert_eq(_count(b, "empty"), 4)
		assert_eq(_count(b, "elite"), 0)
		for i in [1, 2]:
			assert_true(b.tiles[i].type != "enemy" and b.tiles[i].type != "elite", "no enemy right after start (seed %d)" % s)
		for t in b.tiles:
			if t.type == "enemy":
				assert_true(t.enemies.size() >= 1 and t.enemies.size() <= 3, "enemy count")
				for e in t.enemies:
					assert_true(EnemyDefs.ENEMIES.has(e), "known enemy id " + str(e))
			else:
				assert_eq(t.enemies.size(), 0, "no enemies on non-enemy tile")

func test_later_acts_have_an_elite() -> void:
	var b := Board.generate(Rng.new(4), 2)
	assert_eq(_count(b, "elite"), 1)
	assert_eq(_count(b, "enemy"), 5)
	for t in b.tiles:
		if t.type == "elite":
			assert_true(t.elite)
			assert_true(t.enemies.size() >= 1)

func test_generation_deterministic() -> void:
	var a := Board.generate(Rng.new(99), 1)
	var b := Board.generate(Rng.new(99), 1)
	assert_eq(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()))

func test_landing_and_path_wraparound() -> void:
	var b := Board.generate(Rng.new(1), 1)
	assert_eq(b.landing(22, 5), 3)
	assert_eq(b.landing(0, 4), 4)
	assert_eq(b.path(22, 5), [23, 0, 1, 2, 3])
	assert_true(b.crosses_start(22, 5))
	assert_true(b.crosses_start(20, 4), "landing exactly on start counts")
	assert_true(not b.crosses_start(0, 6), "leaving start does not")

func test_zero_move_stays() -> void:
	var b := Board.generate(Rng.new(1), 1)
	assert_eq(b.landing(5, 0), 5)
	assert_eq(b.path(5, 0), [])
	assert_true(not b.crosses_start(23, 0))

func test_portal_targets() -> void:
	var b := Board.generate(Rng.new(1), 1)
	assert_eq(b.portal_range(), 8)
	assert_eq(b.portal_targets(18), [19, 20, 21, 22, 23, 0, 1, 2])

# ---- board size parameter

func test_default_size_is_balance_board_size() -> void:
	var b := Board.generate(Rng.new(2), 1)
	assert_eq(Balance.BOARD_SIZE, 24)
	assert_eq(b.size(), 24)
	assert_eq(b.side(), 7)
	assert_eq(b.corners(), {0: "start", 6: "forge", 12: "treasury", 18: "portal"})

func test_size_32_geometry() -> void:
	var b := Board.generate(Rng.new(2), 1, 32)
	assert_eq(b.size(), 32)
	assert_eq(b.side(), 9)
	assert_eq(b.tiles.size(), 32)
	assert_eq(b.corners(), {0: "start", 8: "forge", 16: "treasury", 24: "portal"})
	assert_eq(b.tiles[8].type, "forge")
	assert_eq(b.tiles[16].type, "treasury")
	assert_eq(b.tiles[24].type, "portal")
	assert_true(b.is_corner(24) and not b.is_corner(18))
	assert_eq(b.landing(30, 5), 3)
	assert_eq(b.path(30, 4), [31, 0, 1, 2])
	assert_true(b.crosses_start(28, 4))
	assert_true(not b.crosses_start(20, 9))
	assert_eq(b.portal_range(), 10)
	assert_eq(b.portal_targets(24), [25, 26, 27, 28, 29, 30, 31, 0, 1, 2])

func test_size_32_distribution() -> void:
	for s in 30:
		var b := Board.generate(Rng.new(s), 1, 32)
		assert_eq(_count(b, "enemy"), 8, "enemies seed %d" % s)
		assert_eq(_count(b, "chest"), 4)
		assert_eq(_count(b, "event"), 4)
		assert_eq(_count(b, "campfire"), 3)
		assert_eq(_count(b, "trap"), 3)
		assert_eq(_count(b, "empty"), 6)
		for i in [1, 2]:
			assert_true(b.tiles[i].type != "enemy" and b.tiles[i].type != "elite", "no fight right after start")
	var b2 := Board.generate(Rng.new(4), 2, 32)
	assert_eq(_count(b2, "elite"), 1)
	assert_eq(_count(b2, "enemy"), 7)

func test_size_32_mutation_and_round_trip() -> void:
	var r := Rng.new(6)
	var b := Board.generate(r, 1, 32)
	var enemies := _count(b, "enemy")
	b.mutate(r, 1, 2)
	assert_eq(_count(b, "enemy"), enemies + 3, "32 ring spawns 3 enemies per lap")
	assert_eq(_count(b, "elite"), 1)
	assert_eq(_count(b, "event"), 4, "events refresh to 4")
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(b.to_dict()))
	var c := Board.from_dict(parsed)
	assert_eq(c.size(), 32)
	assert_eq(c.side(), 9)
	assert_eq(JSON.stringify(c.to_dict()), JSON.stringify(b.to_dict()))

func test_side_helpers() -> void:
	assert_eq(Board.side_for(24), 7)
	assert_eq(Board.side_for(32), 9)
	assert_eq(Board.corners_for(32).keys(), [0, 8, 16, 24])

func test_mutation() -> void:
	var r := Rng.new(5)
	var b := Board.generate(r, 1)
	# clear one enemy tile and consume an event
	var cleared := -1
	var consumed := -1
	for i in b.size():
		if b.tiles[i].type == "enemy" and cleared < 0:
			cleared = i
		if b.tiles[i].type == "event" and consumed < 0:
			consumed = i
	b.clear_enemies(cleared)
	b.tiles[consumed] = Board.make_tile("empty")
	var protect := -1
	for i in b.size():
		if b.tiles[i].type == "empty" and i != cleared and i != consumed:
			protect = i
			break
	var before_enemy := _count(b, "enemy")
	var changes := b.mutate(r, 1, 2, [protect])
	assert_eq(b.tiles[protect].type, "empty", "protected tile unchanged")
	assert_true(b.tiles[cleared].type != "enemy" or b.tiles[cleared].enemies.size() > 0, "cleared tile no longer a cleared enemy")
	# cleared one (-1) then +2 enemies
	assert_eq(_count(b, "enemy"), before_enemy - 1 + 2)
	assert_eq(_count(b, "elite"), 1)
	assert_eq(_count(b, "event"), 3, "events refresh")
	assert_true(changes.size() >= 4, "changes reported")
	for c in changes:
		assert_true(c.has("idx") and c.has("type") and c.has("enemies"))
		assert_eq(b.tiles[c.idx].type, c.type)
	assert_eq(b.tiles[0].type, "start")
	assert_eq(b.tiles[6].type, "forge")

func test_ahead_empty() -> void:
	var b := Board.generate(Rng.new(1), 1)
	var ahead := b.next_of_type(10, "empty", 3)
	assert_true(ahead.size() <= 3)
	for i in ahead:
		assert_eq(b.tiles[i].type, "empty")

func test_round_trip() -> void:
	var b := Board.generate(Rng.new(8), 3)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(b.to_dict()))
	var c := Board.from_dict(parsed)
	assert_eq(JSON.stringify(c.to_dict()), JSON.stringify(b.to_dict()))

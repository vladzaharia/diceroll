extends "res://tests/test_case.gd"
## PlinkoBoard layout helpers: the cabinet fits any board rect, slots map to their buckets,
## every peg and bucket lies inside the field, and the ball's resting spots follow a path.


func _board(sz: Vector2) -> PlinkoBoard:
	var b := PlinkoBoard.new()
	b.size = sz
	b._layout()
	return b


func test_cabinet_fits_every_board_size() -> void:
	for sz: Vector2 in [Vector2(386, 400), Vector2(386, 560), Vector2(530, 530), Vector2(300, 300), Vector2(900, 900), Vector2(600, 1100)]:
		var b := _board(sz)
		assert_true(Rect2(Vector2.ZERO, sz).grow(1.0).encloses(b._cab), "cabinet inside %s" % sz)
		assert_true(b._field.encloses(b.bucket_rect(0)) and b._field.encloses(b.bucket_rect(8)), "buckets inside the field %s" % sz)
		b.free()


func test_slots_map_to_their_bucket_centres() -> void:
	var b := _board(Vector2(530, 530))
	for s in 9:
		assert_eq(b.slot_at(b.slot_x(s)), s)
		assert_near(b.slot_x(s), b.bucket_rect(s).get_center().x, 0.01)
		assert_near(b.peg_pos(0, s * 2).x, b.slot_x(s), 0.01)
	assert_eq(b.slot_at(-50.0), 0)
	assert_eq(b.slot_at(5000.0), 8)
	b.free()


func test_pegs_and_path_stay_in_the_field() -> void:
	var b := _board(Vector2(402, 480))
	for k in 8:
		var x2 := k % 2
		while x2 <= 16:
			assert_true(b._field.has_point(b.peg_pos(k, x2)), "peg %d,%d" % [k, x2])
			assert_true(b._field.has_point(b.rest_pos(k, x2)), "rest %d,%d" % [k, x2])
			x2 += 2
	# a real walk (core rules): each resting spot sits one row lower, half a bucket aside
	var path := Plinko.walk(0, [false, true, true, true, true, true, true, true])
	for k in range(1, 8):
		var a := b.rest_pos(k - 1, path[k - 1])
		var c := b.rest_pos(k, path[k])
		assert_near(c.y - a.y, b._dy, 0.01)
		assert_near(absf(c.x - a.x), b._bw * 0.5, 0.01)
	b.free()

extends "res://tests/test_case.gd"

func test_default_die() -> void:
	var d := Die.new()
	assert_eq(d.faces, PackedInt32Array([1, 2, 3, 4, 5, 6]))
	assert_eq(d.rune, "")
	assert_eq(d.edited, PackedByteArray([0, 0, 0, 0, 0, 0]))

func test_roll_uses_faces() -> void:
	var d := Die.new()
	d.faces = PackedInt32Array([6, 6, 6, 6, 6, 6])
	var r := Rng.new(3)
	for i in 30:
		var f := d.roll(r)
		assert_true(f >= 0 and f < 6)
		assert_eq(d.faces[f], 6)

func test_roll_covers_all_faces() -> void:
	var d := Die.new()
	var r := Rng.new(11)
	var seen := {}
	for i in 300:
		seen[d.roll(r)] = true
	assert_eq(seen.size(), 6)

func test_raise_caps_at_six_and_marks_edited() -> void:
	var d := Die.new()
	assert_true(d.raise_face(0))
	assert_eq(d.faces[0], 2)
	assert_eq(d.edited[0], 1)
	assert_true(not d.raise_face(5), "cannot raise a 6")
	assert_eq(d.faces[5], 6)

func test_mirror() -> void:
	var d := Die.new()
	assert_true(d.mirror_face(0, 5))
	assert_eq(d.faces[0], 6)
	assert_eq(d.edited[0], 1)
	assert_true(not d.mirror_face(2, 2), "same face")
	assert_true(not d.mirror_face(1, 7), "bad index")

func test_lowest_face() -> void:
	var d := Die.new()
	d.faces = PackedInt32Array([3, 2, 5, 2, 6, 4])
	assert_eq(d.lowest_face(), 1)

func test_round_trip() -> void:
	var d := Die.new()
	d.rune = "blade"
	d.raise_face(2)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d.to_dict()))
	var e := Die.from_dict(parsed)
	assert_eq(e.faces, d.faces)
	assert_eq(e.rune, "blade")
	assert_eq(e.edited, d.edited)
	assert_eq(JSON.stringify(e.to_dict()), JSON.stringify(d.to_dict()))

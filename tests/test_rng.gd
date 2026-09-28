extends "res://tests/test_case.gd"

func test_same_seed_same_sequence() -> void:
	var a := Rng.new(42)
	var b := Rng.new(42)
	for i in 200:
		assert_eq(a.next_u32(), b.next_u32(), "step %d" % i)

func test_different_seeds_differ() -> void:
	var a := Rng.new(1)
	var b := Rng.new(2)
	var same := 0
	for i in 50:
		if a.next_u32() == b.next_u32():
			same += 1
	assert_true(same < 5, "sequences should differ")

func test_randi_range_bounds_and_coverage() -> void:
	var r := Rng.new(7)
	var seen := {}
	for i in 2000:
		var v := r.randi_range(1, 6)
		assert_true(v >= 1 and v <= 6, "out of range %d" % v)
		seen[v] = true
	assert_eq(seen.size(), 6, "all faces seen")
	assert_eq(r.randi_range(3, 3), 3)

func test_randf_unit_interval() -> void:
	var r := Rng.new(9)
	var total := 0.0
	for i in 2000:
		var f := r.randf()
		assert_true(f >= 0.0 and f < 1.0, "randf out of range")
		total += f
	assert_near(total / 2000.0, 0.5, 0.05, "mean")

func test_pick_and_shuffle_deterministic() -> void:
	var a := Rng.new(5)
	var b := Rng.new(5)
	var arr1 := [1, 2, 3, 4, 5, 6, 7, 8]
	var arr2 := [1, 2, 3, 4, 5, 6, 7, 8]
	a.shuffle(arr1)
	b.shuffle(arr2)
	assert_eq(arr1, arr2)
	var sorted := arr1.duplicate()
	sorted.sort()
	assert_eq(sorted, [1, 2, 3, 4, 5, 6, 7, 8], "shuffle is a permutation")
	assert_eq(a.pick(["x", "y", "z"]), b.pick(["x", "y", "z"]))

func test_serialisation_round_trip_through_json() -> void:
	var a := Rng.new(123456789)
	for i in 17:
		a.next_u32()
	var d := a.to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(d))
	var b := Rng.from_dict(parsed)
	for i in 100:
		assert_eq(a.next_u32(), b.next_u32(), "after restore step %d" % i)

func test_zero_seed_works() -> void:
	var r := Rng.new(0)
	var nonzero := false
	for i in 10:
		if r.next_u32() != 0:
			nonzero = true
	assert_true(nonzero)

extends "res://tests/test_case.gd"

func _ev(values: Array, wild: Array = []) -> Dictionary:
	var v: Array[int] = []
	v.assign(values)
	var w: Array[bool] = []
	w.assign(wild)
	return Combo.evaluate(v, w)

func _check(values: Array, id: String, mult: float, group: Array, wild: Array = []) -> void:
	var c := _ev(values, wild)
	assert_eq(c.id, id, "combo id for %s" % str(values))
	assert_near(c.mult, mult, 0.0001, "mult for %s" % str(values))
	var g: Array = c.group.duplicate()
	g.sort()
	var eg := group.duplicate()
	eg.sort()
	assert_eq(g, eg, "group for %s" % str(values))

func test_six_of_a_kind() -> void:
	_check([6, 6, 6, 6, 6, 6], "six_kind", 15.0, [0, 1, 2, 3, 4, 5])

func test_five_of_a_kind() -> void:
	_check([3, 3, 1, 3, 3, 3], "five_kind", 10.0, [0, 1, 3, 4, 5])

func test_four_of_a_kind() -> void:
	_check([2, 2, 5, 2, 2], "four_kind", 5.0, [0, 1, 3, 4])

func test_full_house() -> void:
	_check([4, 2, 4, 2, 4], "full_house", 3.5, [0, 1, 2, 3, 4])

func test_straight() -> void:
	_check([5, 1, 3, 2, 4], "straight", 3.0, [0, 1, 2, 3, 4])
	_check([2, 3, 4, 5, 6], "straight", 3.0, [0, 1, 2, 3, 4])

func test_small_straight() -> void:
	_check([1, 2, 3, 4, 6], "small_straight", 2.5, [0, 1, 2, 3])

func test_three_of_a_kind() -> void:
	_check([5, 1, 5, 2, 5], "three_kind", 2.5, [0, 2, 4])

func test_two_pair() -> void:
	_check([3, 5, 3, 5, 1], "two_pair", 2.0, [0, 1, 2, 3])

func test_pair() -> void:
	_check([6, 1, 6, 2, 4], "pair", 1.5, [0, 2])

func test_high_roller() -> void:
	_check([1, 3, 5], "high_roller", 1.0, [2])
	_check([4], "high_roller", 1.0, [0])

func test_names_present() -> void:
	var c := _ev([2, 2, 4])
	assert_eq(c.name, "Pair")
	assert_eq(c.sum, 4)

func test_tie_break_small_straight_vs_three_by_sum() -> void:
	# both x2.5: three 5s (15) beats 2-3-4-5 (14)
	_check([5, 5, 5, 2, 3, 4], "three_kind", 2.5, [0, 1, 2])
	# 3-4-5-6 (18) beats three 3s (9)
	_check([3, 3, 3, 4, 5, 6], "small_straight", 2.5, [0, 3, 4, 5])

func test_tie_break_higher_pair() -> void:
	_check([2, 2, 6, 6, 1, 1], "two_pair", 2.0, [0, 1, 2, 3])
	_check([1, 1, 4, 4, 6, 6], "two_pair", 2.0, [2, 3, 4, 5])

func test_six_dice_hands() -> void:
	_check([1, 2, 3, 4, 5, 6], "straight", 3.0, [1, 2, 3, 4, 5])
	_check([4, 4, 4, 4, 2, 2], "four_kind", 5.0, [0, 1, 2, 3])
	_check([2, 2, 2, 6, 6, 6], "full_house", 3.5, [3, 4, 5, 0, 1])
	_check([3, 3, 3, 3, 3, 3], "six_kind", 15.0, [0, 1, 2, 3, 4, 5])

func test_wild_completes_five_of_a_kind() -> void:
	_check([6, 6, 1, 6, 6], "five_kind", 10.0, [0, 1, 2, 3, 4], [false, false, true, false, false])
	var c := _ev([6, 6, 1, 6, 6], [false, false, true, false, false])
	assert_eq(c.values[2], 6, "wild takes value 6")

func test_wild_completes_straight() -> void:
	_check([1, 2, 3, 4, 1], "straight", 3.0, [0, 1, 2, 3, 4], [false, false, false, false, true])

func test_wild_makes_three() -> void:
	_check([2, 2, 1], "three_kind", 2.5, [0, 1, 2], [false, false, true])

func test_two_wilds() -> void:
	# best: three 5s (x2.5) over pair of wild sixes (x1.5)
	var c := _ev([5, 1, 1], [false, true, true])
	assert_eq(c.id, "three_kind")
	assert_eq(c.values, [5, 5, 5])

func test_lone_wild_is_six() -> void:
	var c := _ev([2], [true])
	assert_eq(c.id, "high_roller")
	assert_eq(c.values, [6])

func test_all_wild_six_dice() -> void:
	var c := _ev([1, 1, 1, 1, 1, 1], [true, true, true, true, true, true])
	assert_eq(c.id, "six_kind")
	assert_eq(c.sum, 36)

func test_free_wild_outside_group_is_six() -> void:
	var c := _ev([2, 3, 4, 5, 6, 1], [false, false, false, false, false, true])
	assert_eq(c.id, "straight")
	var g: Array = c.group.duplicate()
	g.sort()
	assert_eq(g, [0, 1, 2, 3, 4], "straight 2-6 from fixed dice")
	assert_eq(c.values, [2, 3, 4, 5, 6, 6], "free wild becomes 6")

func test_two_wilds_free_one_is_six() -> void:
	var c := _ev([2, 3, 4, 5, 1, 1], [false, false, false, false, true, true])
	assert_eq(c.id, "straight")
	assert_eq(c.sum, 20, "straight 2-6")
	for i in [4, 5]:
		if not c.group.has(i):
			assert_eq(c.values[i], 6, "free wild %d becomes 6" % i)
	var v: Array = c.values.duplicate()
	v.sort()
	assert_eq(v, [2, 3, 4, 5, 6, 6])

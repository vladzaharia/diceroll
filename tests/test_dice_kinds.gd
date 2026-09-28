extends "res://tests/test_case.gd"

func test_table_shape() -> void:
	for id in ["standard", "low", "high", "even", "odd", "loaded", "twin", "gambler", "giant"]:
		assert_true(DiceKinds.DEFS.has(id), "kind " + id)
	for id in DiceKinds.IDS:
		var d: Dictionary = DiceKinds.DEFS[id]
		for k in ["name", "desc", "rarity", "price", "faces"]:
			assert_true(d.has(k), "%s has %s" % [id, k])
		assert_eq((d.faces as Array).size(), 6, id + " six faces")
		for v in d.faces:
			assert_true(int(v) >= 0 and int(v) <= 9, "%s value in 0..9" % id)
		assert_true(["common", "rare", "epic"].has(String(d.rarity)))
	assert_eq(Array(DiceKinds.faces("odd")), [1, 1, 3, 3, 5, 5])
	assert_eq(Array(DiceKinds.faces("loaded")), [1, 2, 3, 4, 6, 6])
	assert_eq(DiceKinds.raise_cap("giant"), 9)
	assert_eq(DiceKinds.raise_cap("low"), 6)

func test_random_kind_deterministic_and_varied() -> void:
	var a := Rng.new(3)
	var b := Rng.new(3)
	var seen := {}
	for i in 400:
		var k := DiceKinds.random_kind(a)
		assert_eq(k, DiceKinds.random_kind(b))
		seen[k] = true
	assert_eq(seen.size(), DiceKinds.IDS.size(), "every kind can appear")

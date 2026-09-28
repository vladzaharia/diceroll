extends "res://tests/test_case.gd"
## AutoRules: defaults, persistence and validation.

func test_defaults() -> void:
	var r := AutoRules.new()
	assert_true(r.board and r.combat and r.drafts and r.forge and r.events and r.portal, "scopes on by default")
	assert_true(not r.shop, "shop scope off by default")
	assert_near(r.stop_hp_below, 0.0)
	assert_true(not r.stop_before_miniboss)
	assert_true(r.stop_before_boss)
	assert_true(r.stop_on_boss_passive)
	assert_true(r.stop_on_shop)
	assert_eq(r.focus, "balanced")
	assert_eq(r.fight_miniboss, "auto")

func test_round_trip() -> void:
	var r := AutoRules.new()
	r.board = false
	r.shop = true
	r.stop_hp_below = 0.3
	r.stop_before_miniboss = true
	r.stop_before_boss = false
	r.focus = "economy"
	r.fight_miniboss = "never"
	var d := r.to_dict()
	# survives a JSON round trip (settings persistence)
	var back := AutoRules.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_eq(back.to_dict(), d, "round trip")

func test_from_dict_partial_and_invalid() -> void:
	var r := AutoRules.from_dict({"focus": "nonsense", "fight_miniboss": "maybe", "stop_hp_below": 7, "combat": false})
	assert_eq(r.focus, "balanced", "bad focus falls back")
	assert_eq(r.fight_miniboss, "auto", "bad fight_miniboss falls back")
	assert_near(r.stop_hp_below, 1.0, 0.0001, "clamped to 0..1")
	assert_true(not r.combat, "explicit value kept")
	assert_true(r.board, "missing value keeps default")

func test_all_on_preset() -> void:
	var r := AutoRules.all_on()
	assert_true(r.shop and r.board and r.combat)
	assert_true(not r.stop_before_boss and not r.stop_on_boss_passive and not r.stop_on_shop)

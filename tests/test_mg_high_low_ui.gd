extends "res://tests/test_case.gd"
## LadderBoard (High-Low Ladder) pure helpers: odds labels, which buttons can be pressed, and
## the board state rebuilt from a public state (restore / resume).


func _state(die: int, rung: int, history: Array = [], cashed := false, bust := false) -> Dictionary:
	return {"die": die, "rung": rung, "prizes": HighLow.PRIZES.duplicate(), "safe": HighLow.SAFE.duplicate(),
		"history": history, "cashed": cashed, "bust": bust, "actions_left": HighLow.PRIZES.size() - 1 - rung,
		"done": cashed or bust}


func test_odds_text_is_out_of_five() -> void:
	assert_eq(LadderBoard.odds_text(1, "higher"), "SURE THING")
	assert_eq(LadderBoard.odds_text(1, "lower"), "NO CHANCE")
	assert_eq(LadderBoard.odds_text(2, "higher"), "4 in 5")
	assert_eq(LadderBoard.odds_text(2, "lower"), "1 in 5")
	assert_eq(LadderBoard.odds_text(4, "lower"), "3 in 5")
	assert_eq(LadderBoard.odds_text(6, "higher"), "NO CHANCE")
	assert_eq(LadderBoard.odds_text(6, "lower"), "SURE THING")


func test_impossible_guess_is_disabled() -> void:
	var b := LadderBoard.new()
	b.set_state(_state(6, 0))
	assert_true(not b.can_press(0), "HIGHER on a 6")
	assert_true(b.can_press(1), "LOWER on a 6")
	assert_true(b.can_press(2), "CASH")
	b.set_state(_state(1, 2))
	assert_true(b.can_press(0), "HIGHER on a 1")
	assert_true(not b.can_press(1), "LOWER on a 1")
	b.free()


func test_game_over_locks_every_button() -> void:
	var b := LadderBoard.new()
	b.set_state(_state(3, 4, [], true, false))
	for i in 3:
		assert_true(not b.can_press(i), "button %d after cashing" % i)
	assert_eq(b.status_text(), "Banked +9")
	b.free()


func test_bust_restores_broken_rungs() -> void:
	var b := LadderBoard.new()
	var hist := [{"guess": "higher", "from": 2, "roll": 5, "result": "up"}, {"guess": "lower", "from": 5, "roll": 1, "result": "up"},
		{"guess": "higher", "from": 1, "roll": 1, "result": "push"}, {"guess": "higher", "from": 1, "roll": 3, "result": "up"},
		{"guess": "lower", "from": 3, "roll": 2, "result": "up"}, {"guess": "higher", "from": 2, "roll": 1, "result": "bust"}]
	# four climbs (rung 4), then a bust down to the safety rung 3
	b.set_state(_state(1, 3, hist, false, true))
	assert_eq(b._broken.keys(), [4])
	assert_eq(b.status_text(), "Bust! Kept +7")
	b.free()


func test_status_shows_bank_and_safety() -> void:
	var b := LadderBoard.new()
	b.set_state(_state(4, 4))
	assert_eq(b.status_text(), "Bank +9  ·  Safe +7")
	b.free()

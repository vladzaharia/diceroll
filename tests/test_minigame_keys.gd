extends "res://tests/test_case.gd"
## Keyboard play in the minigames (desktop, spec 6): each natural board turns its keys into the
## click / drag a player would make (through scripted_input or the same synthetic clicks), grid
## games ignore keys, and the desktop copy names the keys in text.


## Records the driver calls a board makes (the MgBoard.Driver contract).
class FakeDriver:
	extends Node
	var calls: Array = []

	func click(p: Vector2) -> void:
		calls.append(["click", p])

	func press(p: Vector2) -> void:
		calls.append(["press", p])

	func release(p: Vector2) -> void:
		calls.append(["release", p])

	func move(p: Vector2, held := true) -> void:
		calls.append(["move", p, held])

	func drag(pts: Array) -> void:
		calls.append(["drag", pts])

	func kinds() -> Array:
		return calls.map(func(c: Array) -> String: return String(c[0]))


func _key(code: int) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	return k


func _board(id: String) -> MgBoard:
	var b: MgBoard
	match id:
		"claw_machine": b = ClawBoard.new()
		"lucky_wheel": b = WheelBoard.new()
		"fishing": b = FishingBoard.new()
		"shell_game": b = ShellBoard.new()
		"high_low": b = LadderBoard.new()
		"plinko": b = PlinkoBoard.new()
		"bubble_shooter": b = ShooterBoard.new()
		"fossil_hunter": b = FossilBoard.new()
		"bubble_breaker": b = BubbleBoard.new()
		"memory_match": b = MemoryBoard.new()
		_: b = ScratchBoard.new()
	b.size = Vector2(640, 820)
	# no scene tree in the headless runner: boards act at their own position
	b.set_state(Minigames.create(id, 4242, 1).public_state(), true)
	b.unlock()
	return b


func _done(b: MgBoard, d: Node) -> void:
	b.free()
	d.free()


func test_claw_space_drops() -> void:
	InputActions.ensure()
	var b := _board("claw_machine")
	var d := FakeDriver.new()
	assert_true(b.key_input(_key(KEY_SPACE), d), "space used")
	assert_eq(d.kinds(), ["click"], "one click on the cabinet")
	assert_true(not b.key_input(_key(KEY_R), d), "R ignored")
	_done(b, d)


func test_wheel_space_spins() -> void:
	var b := _board("lucky_wheel")
	var d := FakeDriver.new()
	assert_true(b.key_input(_key(KEY_SPACE), d), "space used")
	assert_eq(d.kinds(), ["click"], "spin = a click on the button")
	_done(b, d)


func test_fishing_number_casts() -> void:
	var b := _board("fishing")
	var d := FakeDriver.new()
	assert_true(b.key_input(_key(KEY_2), d), "2 used")
	assert_eq(d.kinds(), ["click"], "cast = a click on the reeds spot")
	assert_true(b.key_input(_key(KEY_SPACE), d), "space used (strike)")
	_done(b, d)


func test_shell_number_picks_cup() -> void:
	var b := _board("shell_game")
	var d := FakeDriver.new()
	b.set("_phase", "pick")
	assert_true(b.key_input(_key(KEY_3), d), "3 used")
	assert_eq(d.kinds(), ["move", "click"], "hover + click on the right cup")
	var xs: Array = b.get("_xs")
	assert_true(absf(float(d.calls[1][1].x) - (b.get_global_rect().position.x + float(xs[2]))) < 0.5, "at the third cup")
	_done(b, d)


func test_ladder_arrows_and_cash() -> void:
	var b := _board("high_low")
	var d := FakeDriver.new()
	assert_true(b.key_input(_key(KEY_UP), d), "up used")
	var p: Vector2 = d.calls[-1][1]
	var o := b.get_global_rect().position
	assert_true((b as LadderBoard).button_rect("higher").has_point(p - o), "up clicks HIGHER")
	b.set("_busy", false)
	b.locked = false
	d.calls.clear()
	assert_true(b.key_input(_key(KEY_C), d), "C used")
	assert_true((b as LadderBoard).button_rect("cash").has_point(Vector2(d.calls[-1][1]) - o), "C clicks CASH OUT")
	_done(b, d)


func test_plinko_arrows_aim_space_drops() -> void:
	var b := _board("plinko")
	var d := FakeDriver.new()
	var a0 := int(b.get("_aim"))
	assert_true(b.key_input(_key(KEY_RIGHT), d), "right used")
	assert_eq(int(b.get("_aim")), mini(a0 + 1, PlinkoBoard.BUCKETS - 1), "dropper moves one slot")
	assert_true(b.key_input(_key(KEY_SPACE), d), "space used")
	assert_eq(d.kinds(), ["drag"], "drop = press-slide-release")
	_done(b, d)


func test_shooter_arrows_aim_space_shoots() -> void:
	var b := _board("bubble_shooter")
	var d := FakeDriver.new()
	var a0 := int(b.get("_aim_idx"))
	assert_true(b.key_input(_key(KEY_LEFT), d), "left used")
	assert_eq(int(b.get("_aim_idx")), maxi(a0 - 1, 0), "aim steps left")
	assert_true(b.key_input(_key(KEY_SPACE), d), "space used (the drag itself needs a running tree)")
	_done(b, d)


func test_grid_games_ignore_keys() -> void:
	for id in ["fossil_hunter", "bubble_breaker", "memory_match", "scratch_off"]:
		var b := _board(id)
		var d := FakeDriver.new()
		for code in [KEY_SPACE, KEY_1, KEY_LEFT]:
			assert_true(not b.key_input(_key(code), d), "%s ignores keys" % id)
		assert_true(d.calls.is_empty(), "%s: no input" % id)
		_done(b, d)


func test_desktop_copy_names_keys_in_text() -> void:
	InputActions.ensure()
	assert_true(MinigameScreen.hint_text("claw_machine", true).begins_with("Space"), "claw: Space to drop")
	assert_true(MinigameScreen.hint_text("claw_machine", false).begins_with("Tap"), "touch keeps Tap")
	for id in MinigameDefs.IDS:
		var t := MinigameScreen.hint_text(id, true)
		assert_true(t != "" and not t.contains("{") and not t.contains("Tap"), "desktop copy for %s: %s" % [id, t])
		assert_true(MgLogic.KEY_HINTS.has(id), "KEY_HINTS has %s" % id)
	assert_true(not (load("res://game/minigames/mg_logic.gd") as GDScript).get_script_constant_map().has("ICONS"), "unused MgLogic.ICONS removed")

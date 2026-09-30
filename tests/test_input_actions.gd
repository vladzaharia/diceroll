extends "res://tests/test_case.gd"
## InputActions: registration, key routing, glyphs and the Settings -> Controls rows.


func _key(code: int, pressed := true, echo := false) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = pressed
	k.echo = echo
	return k


func test_every_action_registered_with_a_key() -> void:
	InputActions.ensure()
	for a in InputActions.actions():
		assert_true(InputMap.has_action(a), "action %s registered" % a)
		assert_true(not InputActions.keys_for(a).is_empty(), "action %s has a key" % a)


func test_ensure_is_idempotent() -> void:
	InputActions.ensure()
	InputActions.ensure()
	assert_eq(InputMap.action_get_events("reroll").size(), 1, "reroll bound once")


func test_run_keys_route_through_actions() -> void:
	assert_true(InputActions.pressed(_key(KEY_SPACE), "primary"), "space = primary")
	assert_true(InputActions.pressed(_key(KEY_ENTER), "primary"), "enter = primary")
	assert_true(InputActions.pressed(_key(KEY_R), "reroll"), "r = reroll")
	assert_true(InputActions.pressed(_key(KEY_ESCAPE), "pause"), "esc = pause")
	assert_true(InputActions.pressed(_key(KEY_P), "pause"), "p = pause")
	assert_true(not InputActions.pressed(_key(KEY_R), "primary"), "r is not primary")
	assert_eq(InputActions.pressed_index(_key(KEY_4), InputActions.DIE), 3, "4 = die 4")
	assert_eq(InputActions.pressed_index(_key(KEY_9), InputActions.DIE), -1, "9 = no die")


func test_echo_and_release_ignored() -> void:
	assert_true(not InputActions.pressed(_key(KEY_R, true, true), "reroll"), "echo ignored")
	assert_true(not InputActions.pressed(_key(KEY_R, false), "reroll"), "release ignored")
	assert_true(not InputActions.pressed(null, "reroll"), "null ignored")


func test_menu_and_minigame_keys() -> void:
	assert_true(InputActions.pressed(_key(KEY_ENTER), "menu_confirm"), "enter confirms")
	assert_true(InputActions.pressed(_key(KEY_ESCAPE), "menu_back"), "esc = back")
	assert_true(InputActions.pressed(_key(KEY_SPACE), "mg_action"), "space = mg action")
	assert_eq(InputActions.pressed_index(_key(KEY_2), InputActions.MG_PICK), 1, "2 = pick 2")
	assert_true(InputActions.pressed(_key(KEY_UP), "mg_up"), "up = higher")
	assert_true(InputActions.pressed(_key(KEY_C), "mg_cash_out"), "c = cash out")


func test_glyphs_follow_bindings() -> void:
	assert_eq(InputActions.glyph_for("primary"), "key_space", "primary glyph")
	assert_eq(InputActions.glyphs_for("primary"), ["key_space", "key_enter"] as Array[String],
		"keypad enter folds into enter")
	assert_eq(InputActions.glyphs_for("pause"), ["key_esc", "key_p"] as Array[String], "pause glyphs")
	# rebinding changes the glyph
	InputMap.action_erase_events("reroll")
	InputMap.action_add_event("reroll", _key(KEY_C))
	assert_eq(InputActions.glyph_for("reroll"), "key_c", "rebinding changes the glyph")
	InputMap.action_erase_events("reroll")
	InputMap.action_add_event("reroll", _key(KEY_R))
	assert_eq(InputActions.key_label("mg_action"), "Space", "key label")


func test_glyphs_exist_in_icon_map() -> void:
	var glyphs: Dictionary = Icons.load_map_file(Icons.MAP_PATH)
	for row in InputActions.list():
		for g in row["glyphs"]:
			assert_true(glyphs.has(g), "glyph %s of %s is in icon_map input_glyphs" % [g, row["action"]])


func test_list_shape() -> void:
	var rows := InputActions.list()
	assert_true(rows.size() >= 10, "rows listed")
	for row in rows:
		for k in ["action", "label", "glyphs", "group"]:
			assert_true(row.has(k), "row has %s" % k)
		assert_true(not (row["glyphs"] as Array).is_empty(), "%s has glyphs" % row["action"])
		assert_true(String(row["group"]) in ["Run", "Combat", "Menus", "Minigames"], "group")
	assert_eq(InputActions.groups(), ["Run", "Combat", "Menus", "Minigames"] as Array[String], "groups")
	var dice: Dictionary = rows.filter(func(r: Dictionary) -> bool: return r["action"] == "die_1")[0]
	assert_eq((dice["glyphs"] as Array).size(), 6, "1-6 row carries six glyphs")

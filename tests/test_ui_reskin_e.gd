extends "res://tests/test_case.gd"
## Slice (e) reskin: title buttons, class chips, the minigame header and trophies.


func test_title_hides_continue_without_a_save() -> void:
	var t := TitleScreen.new()
	t.refresh()
	assert_eq(t.continue_btn.visible, TitleScreen.has_save(), "CONTINUE only with a save")
	assert_eq(t.settings_btn.kind, GameButton.Kind.SECONDARY, "SETTINGS is a secondary button")
	assert_eq(t.new_btn.kind, GameButton.Kind.PRIMARY, "PLAY is primary")
	assert_eq(t.new_btn.shortcut_hint, "key_enter", "PLAY hover keycap = Enter")
	assert_true(t.get_node_or_null("DevGesture") != null, "dev gesture corner still hosted")
	t.free()


func test_class_chip_labels_fit_on_phones() -> void:
	# a 4-column grid on the 720 canvas leaves ~144 px per chip (~120 px for the label)
	for name in ["Necromancer", "Monster Kid", "Barbarian", "Engineer"]:
		var c := ClassSelect.ClassChip.make(name, "question", true)
		c.size = Vector2(144, ClassSelect.ClassChip.H)
		assert_eq(c.shown_label(c.text_width()), name, "%s is not truncated" % name)
		assert_true(c.fitted_font(c.text_width()) >= ClassSelect.ClassChip.MIN_FONT, "%s font" % name)
		c.free()


func test_locked_chip_is_marked() -> void:
	var c := ClassSelect.ClassChip.make("Ninja", "class_ninja", false)
	assert_true(not c.open, "locked chip")
	assert_true(c.toggle_mode, "chips toggle")
	c.free()


func test_class_select_keys_and_back() -> void:
	var cs := ClassSelect.new()
	assert_eq(cs.start_btn.shortcut_hint, "key_enter", "START RUN keycap = Enter")
	assert_true(cs.back_btn.is_round(), "back is a round button")
	assert_eq(cs.back_btn.shortcut_hint, "key_esc", "back names Esc in its tooltip")
	cs.free()


func test_minigame_plaque_family_per_game() -> void:
	for id in MinigameDefs.IDS:
		var fam := String(MgWidgets.PLAQUE_FAMILY.get(id, ""))
		assert_true(fam in UiTheme.FAMILIES and fam != "white" and fam != "grey", "%s has a native plaque family" % id)
		assert_true(Icons.exists("mg_" + id), "%s has an mg_ icon id" % id)


func test_trophies_replace_the_medal() -> void:
	for tier in ["gold", "silver", "bronze"]:
		var r := MgWidgets.trophy(tier, 96)
		assert_true(r.texture != null, "%s trophy has a texture" % tier)
		assert_eq(r.custom_minimum_size, Vector2(96, 96), "%s trophy size" % tier)
		r.free()
	var src := FileAccess.get_file_as_string("res://ui/minigames/minigame_screen.gd")
	assert_true(not src.contains("MgWidgets.Medal"), "the result beat uses trophies")

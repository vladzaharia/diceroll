extends "res://tests/test_case.gd"
## The missing-assets boot screen shows exactly when the packs are missing, so it must never
## depend on them: no Icons / UiSkin / UiSvg / res://assets/ui, tracked icons only, 80+ px
## buttons, and Enter / Esc wired to its two buttons.

const BOOT := "res://game/boot/"


func test_boot_sources_never_touch_the_pack() -> void:
	for f in DirAccess.get_files_at(BOOT):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string(BOOT + f)
		for bad in ["Icons.", "UiSkin.", "UiSvg.", "res://assets/ui", "rhosgfx", "KeyGlyph"]:
			assert_true(not src.contains(bad), "%s must not use %s" % [f, bad])


func test_tracked_icons_exist() -> void:
	for id in ["book", "door", "warning", "key_esc", "key_enter"]:
		var p: String = BOOT + "icons/" + String(id) + ".svg"
		assert_true(FileAccess.file_exists(p), "tracked icon " + p)
		var img := Image.new()
		assert_eq(img.load_svg_from_string(FileAccess.get_file_as_string(p), 1.0), OK, "renders: " + id)
		assert_true(not img.is_invisible(), "not blank: " + id)
	assert_true(FileAccess.file_exists(BOOT + "icons/LICENSE_keys_CC0.txt"), "CC0 licence next to the key glyphs")


## Builds with the pack absent (empty icon map and skin manifest).
func test_builds_without_the_pack() -> void:
	Icons.set_map({})
	UiSkin.set_manifest({})
	var s := MissingAssetsScreen.new()
	assert_true(s.readme_button != null and s.quit_button != null, "both buttons built")
	for b: Button in [s.readme_button, s.quit_button]:
		assert_true(b.custom_minimum_size.y >= 80.0, "%s is at least 80 px tall" % b.name)
		assert_true(b.icon != null, "%s has its tracked icon" % b.name)
		var cap := b.get_node_or_null("Keycap") as TextureRect
		assert_true(cap != null and cap.texture != null, "%s has a hover keycap" % b.name)
		assert_true(not cap.visible, "%s keycap hidden until hovered" % b.name)
	s.free()
	Icons.set_map(null)
	UiSkin.set_manifest(null)


func test_enter_and_esc_map_to_the_buttons() -> void:
	InputActions.ensure()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	assert_true(MissingAssetsScreen._is(enter, "menu_confirm", [KEY_ENTER]), "Enter = build guide")
	assert_true(MissingAssetsScreen._is(esc, "menu_back", [KEY_ESCAPE]), "Esc = quit")
	assert_true(not MissingAssetsScreen._is(esc, "menu_confirm", [KEY_ENTER]), "Esc is not confirm")
	# without the InputMap actions (raw keys)
	assert_true(MissingAssetsScreen._is(enter, "no_such_action", [KEY_ENTER]), "raw key fallback")

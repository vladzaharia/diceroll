class_name AssetCheck
extends RefCounted
## Boot-time check that the git-ignored third-party assets (KayKit FREE + EXTRA packs, Kenney
## SFX, mixkit music, fonts) were imported. Source of truth: the asset lock written by
## tools/ci/assets.py; every unit's `dest` folder must exist and hold at least one file
## (only files ending in one of the unit's `filter` suffixes count, when it has a filter).
## No hashing: this runs before the title screen.
##
## Skipped for exported builds (assets are baked into the PCK and the lock isn't exported),
## headless runs and when the lock file is absent. main.gd shows `screen()` instead of the
## game when units are missing; the screenshot harness (tools/shot.gd) fails loudly instead.

const LOCK_PATH := "res://tools/ci/assets.lock.json"
const README_URL := "https://github.com/vladzaharia/diceroll#build-from-source"
const SKIP_NAMES := [".DS_Store", "Thumbs.db"]


## Whether the boot check applies to this run (source checkout with a window and a lock file).
static func enabled() -> bool:
	return not OS.has_feature("template") and DisplayServer.get_name() != "headless" \
		and FileAccess.file_exists(LOCK_PATH)


## Parsed lock, or {} when the file is absent or unreadable.
static func load_lock(path: String = LOCK_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("AssetCheck: unreadable lock %s: %s" % [path, json.get_error_message()])
		return {}
	return json.data if json.data is Dictionary else {}


## Names of the lock's units whose `dest` (relative to `root`) is absent or has no files.
static func missing_units(root: String, lock: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var units: Variant = lock.get("units", {})
	if not units is Dictionary:
		return out
	var names: Array = units.keys()
	names.sort()
	for name: String in names:
		var unit: Dictionary = units[name]
		var suffixes := PackedStringArray(unit.get("filter", []))
		if not has_files(root.path_join(String(unit.get("dest", ""))), suffixes):
			out.append(name)
	return out


## True when `dir` (searched recursively) holds a file, optionally one ending in `suffixes`.
static func has_files(dir: String, suffixes: PackedStringArray = PackedStringArray()) -> bool:
	var da := DirAccess.open(dir)
	if da == null:
		return false
	da.include_hidden = true
	for f in da.get_files():
		if f in SKIP_NAMES:
			continue
		if suffixes.is_empty():
			return true
		for s in suffixes:
			if f.ends_with(s):
				return true
	for sub in da.get_directories():
		if has_files(dir.path_join(sub), suffixes):
			return true
	return false


## Runs the check against the project (res://) and logs every missing unit with its folder.
## Returns the missing unit names ([] when the check doesn't apply). The screenshot harness
## passes `headless_too` so CI catches missing assets there as well.
static func run(headless_too := false) -> PackedStringArray:
	if OS.has_feature("template") or not FileAccess.file_exists(LOCK_PATH):
		return PackedStringArray()
	if not headless_too and not enabled():
		return PackedStringArray()
	var lock := load_lock()
	var missing := missing_units("res://", lock)
	for name in missing:
		push_warning("AssetCheck: missing asset unit '%s' (%s)" % [name, lock["units"][name].get("dest", "?")])
	return missing


## Plain, theme-independent "assets missing" screen (engine fallback font only).
static func screen() -> Control:
	var font := ThemeDB.fallback_font
	var root := Control.new()
	root.name = "MissingAssets"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)

	var label := func(text: String, size: int, color: Color) -> Label:
		var l := Label.new()
		l.text = text
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", color)
		box.add_child(l)
		return l
	label.call("Required game assets are missing", 40, Color(1, 0.85, 0.5))
	label.call("The third-party KayKit packs (FREE and EXTRA), Kenney SFX, mixkit music and fonts "
		+ "are not in the repository; obtain them and run tools/import_assets.sh, then "
		+ "godot --headless --import. See the README.", 24, Color(0.9, 0.9, 0.9))

	var link := LinkButton.new()
	link.text = README_URL
	link.name = "Readme"
	link.add_theme_font_override("font", font)
	link.add_theme_font_size_override("font_size", 22)
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	link.pressed.connect(func() -> void: OS.shell_open(README_URL))
	box.add_child(link)

	var quit := Button.new()
	quit.text = "Quit"
	quit.name = "Quit"
	quit.custom_minimum_size = Vector2(220, 72)
	quit.add_theme_font_override("font", font)
	quit.add_theme_font_size_override("font_size", 28)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func() -> void: root.get_tree().quit())
	box.add_child(quit)
	return root

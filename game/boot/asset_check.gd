class_name AssetCheck
extends RefCounted
## Boot-time check that the git-ignored third-party assets (KayKit FREE + EXTRA packs, Kenney
## SFX, CC0 music, fonts) were imported. Source of truth: the asset lock written by
## tools/ci/assets.py; every unit's `dest` folder must exist and hold at least one file
## (only files ending in one of the unit's `filter` suffixes count, when it has a filter).
## No hashing: this runs before the title screen.
##
## Skipped for exported builds (assets are baked into the PCK and the lock isn't exported),
## headless runs and when the lock file is absent. main.gd shows `screen()` (MissingAssetsScreen) instead of the
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


## The "assets missing" screen (theme- and asset-independent, see MissingAssetsScreen).
static func screen() -> Control:
	return MissingAssetsScreen.new()

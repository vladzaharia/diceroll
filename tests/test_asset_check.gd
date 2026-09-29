extends "res://tests/test_case.gd"
## AssetCheck: lock parsing and missing-unit detection on temp fixtures under user://.

const ROOT := "user://asset_check_fixture"


func _lock() -> Dictionary:
	return {"schema": 1, "units": {
		"fonts": {"dest": "assets/fonts", "files": 1, "sha256": "x"},
		"kaykit-forest": {"dest": "assets/kaykit/forest", "files": 2, "sha256": "x"},
		"rendered-icons": {"dest": "ui/icons/rendered", "files": 1, "sha256": "x",
			"filter": [".png", ".png.import"]},
	}}


func _write(rel: String) -> void:
	var path := ROOT.path_join(rel)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("x")
	f.close()


func _wipe(dir: String = ROOT) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	da.include_hidden = true
	for f in da.get_files():
		da.remove(f)
	for d in da.get_directories():
		_wipe(dir.path_join(d))
	DirAccess.remove_absolute(dir)


func test_all_missing() -> void:
	_wipe()
	DirAccess.make_dir_recursive_absolute(ROOT)
	assert_eq(AssetCheck.missing_units(ROOT, _lock()),
		PackedStringArray(["fonts", "kaykit-forest", "rendered-icons"]), "empty root")
	_wipe()


func test_present_and_partial() -> void:
	_wipe()
	_write("assets/fonts/Fredoka.ttf")
	_write("assets/kaykit/forest/Color1/Tree_1_A_Color1.gltf")  # nested files count
	DirAccess.make_dir_recursive_absolute(ROOT.path_join("ui/icons/rendered"))
	_write("ui/icons/rendered/.DS_Store")  # ignored junk
	_write("ui/icons/rendered/readme.txt")  # doesn't match the unit's filter
	assert_eq(AssetCheck.missing_units(ROOT, _lock()), PackedStringArray(["rendered-icons"]), "filtered unit")
	_write("ui/icons/rendered/coin.png")
	assert_eq(AssetCheck.missing_units(ROOT, _lock()), PackedStringArray(), "all present")
	_wipe()


func test_empty_dir_counts_as_missing() -> void:
	_wipe()
	_write("assets/fonts/a.ttf")
	_write("assets/kaykit/forest/.DS_Store")
	DirAccess.make_dir_recursive_absolute(ROOT.path_join("assets/kaykit/forest/Color1"))
	_write("ui/icons/rendered/b.png.import")
	assert_eq(AssetCheck.missing_units(ROOT, _lock()), PackedStringArray(["kaykit-forest"]), "empty unit dir")
	_wipe()


func test_lock_parsing() -> void:
	_wipe()
	assert_eq(AssetCheck.load_lock(ROOT.path_join("nope.json")), {}, "absent lock")
	_write("bad.json")
	assert_eq(AssetCheck.load_lock(ROOT.path_join("bad.json")), {}, "garbage lock")
	var f := FileAccess.open(ROOT.path_join("lock.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_lock()))
	f.close()
	var lock := AssetCheck.load_lock(ROOT.path_join("lock.json"))
	assert_eq(lock.get("units", {}).size(), 3, "units parsed")
	assert_eq(AssetCheck.missing_units(ROOT, {}), PackedStringArray(), "no units -> nothing missing")
	_wipe()


func test_screen_builds_without_theme() -> void:
	var s := AssetCheck.screen()
	assert_true(s.find_child("Quit", true, false) is Button, "quit button")
	assert_true(s.find_child("Readme", true, false) is Button, "build guide button")
	var link := s.find_child("ReadmeLink", true, false) as LinkButton
	assert_true(link != null and link.uri == AssetCheck.README_URL, "readme link opens the README")
	assert_true(s.find_child("Logo", true, false) != null, "logo (or drawn fallback)")
	assert_true(ResourceLoader.exists(MissingAssetsScreen.LOGO_PATH), "tracked logo present")
	s.free()


func test_disabled_headless() -> void:
	# The test runner is headless: the boot check must never block it.
	assert_true(not AssetCheck.enabled(), "headless run skips the check")
	assert_eq(AssetCheck.run(), PackedStringArray(), "run() is a no-op headless")

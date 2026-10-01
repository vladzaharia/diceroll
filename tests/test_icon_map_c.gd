extends "res://tests/test_case.gd"
## Slice (c) icons (plan c 5, spec 4.3 / 5): every icon id the modals and run screens use is
## mapped in ui/icons/icon_map.json (or listed in its "missing" section, which keeps the
## legacy glyph on purpose), and when the RhosGFX pack is imported its SVG is there too.

const MAP := "res://ui/icons/icon_map.json"

## Ids used literally by the (c) screens (buttons, rows, headers, results lines).
const LITERAL := [
	# buttons and actions
	"check", "close", "arrow_left", "arrow_right", "home", "campfire", "flag", "reroll", "coin",
	"3d:coins", "anvil", "up", "gear", "auto", "copy",
	# settings rows
	"speaker", "music", "sfx", "speed", "ui_size",
	# currencies and results
	"crown", "sigil", "skull", "boss", "portal", "trophy", "star", "wardrobe", "heart",
	# potions (shop, rewards)
	"potion", "3d:potion_red", "potion_healing", "potion_stoneskin", "potion_reroll_tonic", "potion_cleanse",
	# events
	"ore", "curse", "sword", "chest", "rune_wild", "rune_lucky", "dice",
]


func _map() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP))
	return d if d is Dictionary else {}


func _missing_ids(m: Dictionary) -> Array:
	var out := []
	for e in m.get("missing", []):
		if e is Dictionary:
			out.append(String(e.get("id", "")))
	return out


## Every icon id the (c) files reference, with where it comes from.
func _used() -> Dictionary:
	var used := {}
	for id in LITERAL:
		used[id] = "literal"
	for id in DraftModal.ICONS.values():
		used[id] = "DraftModal.ICONS"
	for id in ShopModal.ICONS.values():
		used[id] = "ShopModal.ICONS"
	for k in EventModal.ART:
		used[EventModal.art_icon(String(k), String(EventModal.ART[k][0]))] = "EventModal.ART"
	for id in EventModal.CHOICE_ICONS.values():
		used[id] = "EventModal.CHOICE_ICONS"
	for id in MinigameRewardModal.ICONS.values():
		used[id] = "MinigameRewardModal.ICONS"
	for k in SummaryScreen.LINES:
		used[String(SummaryScreen.LINES[k][0])] = "SummaryScreen.LINES"
	for s in AutoSettingsPanel.SCOPES + AutoSettingsPanel.STOPS:
		used[String(s[2])] = "AutoSettingsPanel"
	for r in Runes.DEFS:
		used["rune_" + String(r)] = "Runes.DEFS"
		used["rune_face_" + String(r)] = "Runes.DEFS (die faces)"
	for p in Passives.DEFS:
		used["passive_" + String(p)] = "Passives.DEFS"
	for a in SkinRules.AFFIXES:
		used[String(SkinRules.AFFIXES[a].icon)] = "SkinRules.AFFIXES"
	used[RouteStrip.BOSS_ICON] = "RouteStrip boss stop"
	return used


func test_every_c_icon_is_mapped() -> void:
	var m := _map()
	assert_true(not m.is_empty(), "icon_map.json parses")
	var icons: Dictionary = m.get("icons", {})
	var missing := _missing_ids(m)
	var used := _used()
	assert_true(used.size() > 80, "collected the (c) ids (%d)" % used.size())
	for id: String in used:
		if missing.has(id):
			continue
		assert_true(icons.has(id), "icon '%s' (%s) is not in icon_map.json" % [id, used[id]])


func test_mirror_keeps_its_legacy_glyph() -> void:
	# the lead's call: the Forge MIRROR op has no pack icon; the legacy glyph stays
	assert_true(_missing_ids(_map()).has("mirror"), "mirror listed in icon_map missing")
	assert_true(UiIcons.exists("mirror"), "legacy mirror glyph present")


func test_sigils_have_their_own_icon() -> void:
	var icons: Dictionary = _map().get("icons", {})
	assert_true(icons.has("sigil"), "sigil mapped")
	assert_true(String(icons["sigil"].get("svg", "")) != String(icons["star"].get("svg", "")), "sigil is not the star")


func test_imported_svgs_exist_when_the_pack_is_present() -> void:
	if not DirAccess.dir_exists_absolute("res://assets/ui/icons"):
		return  # fresh clone without the paid pack: the legacy glyphs render (fallback parity)
	var m := _map()
	var icons: Dictionary = m.get("icons", {})
	for id: String in _used():
		if not icons.has(id):
			continue
		assert_true(Icons.is_mapped(id), "icon '%s' is mapped but its SVG was not imported" % id)

extends "res://tests/test_case.gd"
## UI reskin slice (b): every icon id the HUD / world HUD asks for is in the designer's map,
## the pack pieces it uses exist, the unified world badge (and its legacy fallback without the
## pack), status pips, the short-screen tray rule and the world HUD scale helper.


func _map() -> Dictionary:
	var f := FileAccess.open("res://ui/icons/icon_map.json", FileAccess.READ)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	return d.get("icons", {})


func test_hud_icon_ids_are_mapped() -> void:
	var m := _map()
	var ids: Array = ["heart", "shield", "burn", "sun", "oasis", "drum", "ore", "moon_crescent", "moon_half",
		"moon_full", "lap_pip", "boss", "pause", "gear", "speed", "auto", "info", "reroll", "sword", "dice",
		"die_locked", "die_wild_face", "crit", "level", "intent_unknown", "intent_cower", "trait_brave"]
	for k in UnitHud.INTENT_KINDS:
		ids.append("intent_" + String(k))
	for k in UnitHud.TRAIT_KINDS:
		ids.append("trait_" + String(k))
	for k in UnitHud.STATUSES:
		ids.append(String(UnitHud.STATUSES[k][0]))
	for a in SkinRules.AFFIXES:
		ids.append(String(SkinRules.AFFIXES[a].icon))
	for id in ids:
		assert_true(m.has(id), "icon_map has " + String(id))


func test_pack_pieces_used_by_the_hud() -> void:
	var p := UiSkin.load_manifest(UiSkin.PACK_PATH)
	for piece in ["panel_tray", "panel_tray_thin", "plaque_yellow", "plaque_purple", "chip_forestgreen",
			"chip_grey", "chip_red", "chip_yellow", "chip_white", "callout", "frame_pointed", "panel_hud", "panel_inset"]:
		assert_true(p.has(piece), "ui_pack.json piece " + piece)


func test_world_badge_and_legacy_fallback() -> void:
	var b := UnitHud.badge("intent_attack", UiPalette.HP, 0.46)
	var m := b.material_override as ShaderMaterial
	assert_eq(m.shader, UnitHud.BADGE_SHADER, "badge uses badge.gdshader")
	assert_near(float(m.get_shader_parameter("style")), 1.0, 0.001, "style C by default")
	assert_true(m.get_shader_parameter("icon") is Texture2D, "badge icon texture")
	var plain := UnitHud.badge("", UiPalette.PACK_BLUE, 0.36, 0.0)
	assert_true((plain.material_override as ShaderMaterial).get_shader_parameter("icon") is Texture2D, "plain disc")
	b.free()
	plain.free()
	# no pack mapping: affix badges keep the legacy shader + glyph
	Icons.set_map({})
	var legacy := UnitHud.affix_badge("affix_armored", Color.RED, 0.32)
	assert_eq((legacy.material_override as ShaderMaterial).shader, UnitHud.AFFIX_SHADER, "legacy affix shader")
	legacy.free()
	var hud := UnitHud.new()
	assert_true((hud.intent_badge.material_override as ShaderMaterial).shader != UnitHud.BADGE_SHADER, "SDF intent fallback")
	hud.free()
	Icons.set_map(null)


func test_status_pips() -> void:
	var hud := UnitHud.new()
	hud.set_data({"hp": 5, "max_hp": 10, "poison": 3, "frozen": true, "intent": {"kind": "attack", "value": 4}}, false)
	var pips := hud.status_row.get_children().filter(func(n: Node) -> bool: return n is MeshInstance3D)
	var counts := hud.status_row.get_children().filter(func(n: Node) -> bool: return n is Label3D)
	assert_eq(pips.size(), 2, "poison + frozen pips")
	assert_eq(counts.size(), 1, "poison carries a count")
	assert_eq((counts[0] as Label3D).text, "3")
	assert_true(not hud.status_label.visible, "the old status text stays hidden")
	hud.set_data({"hp": 5, "max_hp": 10, "intent": {"kind": "attack", "value": 4}}, false)
	for c in hud.status_row.get_children():
		assert_true(c.is_queued_for_deletion(), "cleared pips")
	hud.free()


func test_short_tray_and_world_scale() -> void:
	assert_true(DiceTray.is_short(Vector2(879, 1280)), "Duo outer (portrait under 1.6:1) is short")
	assert_true(not DiceTray.is_short(Vector2(720, 1565)), "iPhone portrait is not short")
	assert_true(DiceTray.is_short(Vector2(2783, 1280)), "phone landscape is short")
	assert_true(not DiceTray.is_short(Vector2(2276, 1280)), "16:9 desktop is not short")
	assert_near(UnitHud.world_ui_scale(null), 1.0, 0.0001, "no tree: scale 1")

extends "res://tests/test_case.gd"
## RhosGFX reskin plumbing: UiSvg path rule (pinned against tools/import_ui_svgs.py), tinting,
## composition, the Icons registry (map + legacy fallback) and UiSkin style boxes (art present
## and missing) on fixtures under user://, so it runs with or without the paid packs.

const FIX := "user://ui_skin_fixture/"
const BTN := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 64\"><defs><style>.cls-1{fill:#fff;}.cls-2{fill: #1778ff;}</style></defs><rect class=\"cls-2\" width=\"64\" height=\"64\" rx=\"9\"/><rect class=\"cls-1\" x=\"4\" y=\"4\" width=\"56\" height=\"46\"/></svg>"
const ICON := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 128 128\"><path fill=\"#ffffff\" d=\"M0 0h128v128z\"/><circle fill=\"#000\" cx=\"4\" cy=\"4\" r=\"2\"/></svg>"


func _setup() -> void:
	UiSvg.roots = {"icons": FIX + "icons/", "pack": FIX + "pack/"}
	UiSvg.clear_cache()
	_put("icons/" + UiSvg.sanitize("rhosgfx/pack/Coin 2/Coin Flat White.svg"), ICON)
	_put("pack/" + UiSvg.sanitize("rhosgfx/ui/Buttons/3. Yellow/btn_standard.svg"), BTN)


func _teardown() -> void:
	UiSvg.roots = UiSvg.ROOTS.duplicate()
	UiSvg.clear_cache()
	Icons.set_map(null)
	UiSkin.set_manifest(null)


func _put(rel: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute((FIX + rel).get_base_dir())
	var f := FileAccess.open(FIX + rel, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_sanitize_matches_import_script() -> void:
	# the same cases are asserted for tools/import_ui_svgs.py in tools/ci/selftest.sh
	assert_eq(UiSvg.sanitize("rhosgfx/vector-icon-pack-pro/Currency/Star Gem/Star Gem Flat White.svg"),
		"vector-icon-pack-pro/currency/star_gem/star_gem_flat_white.svg")
	assert_eq(UiSvg.sanitize("rhosgfx/cartoony-ui-pack-full/Buttons/3D/Square/3. Yellow/button-square-3d-2.5-yellow-dark_hover.svg"),
		"cartoony-ui-pack-full/buttons/3d/square/3_yellow/button-square-3d-2_5-yellow-dark_hover.svg")
	assert_eq(UiSvg.sanitize("rhosgfx/cartoony-ui-pack-full/[THANK YOU!] Icons/Coin 2/coin.svg"),
		"cartoony-ui-pack-full/thank_you_icons/coin_2/coin.svg")
	assert_eq(UiSvg.runtime_path("pack", "rhosgfx/a/B c.svg"), "res://assets/ui/pack/a/b_c.svg")


func test_recolor_css_and_attributes() -> void:
	var out := UiSvg.recolor(BTN, Color("808080"))
	assert_true(out.contains(".cls-1{fill:#808080;}"), "CSS white -> tint: " + out)
	assert_true(out.contains("fill: #0c3c80"), "CSS colour multiplied")
	var ic := UiSvg.recolor(ICON, Color("ff0000"))
	assert_true(ic.contains("fill=\"#ff0000\"") and ic.contains("fill=\"#000000\""), "attributes: " + ic)
	assert_eq(UiSvg.recolor(ICON, null), ICON, "no tint = untouched")
	var grey := UiSvg.recolor("<path fill=\"#ff0000\"/>", null, 0.0)
	assert_true(grey.contains("#363636"), "desaturated to luminance: " + grey)


func test_palette_colours() -> void:
	assert_eq(UiSvg.color("palette:gold"), UiPalette.GOLD)
	assert_eq(UiSvg.color("palette:RARITY.rare"), UiPalette.RARE)
	assert_eq(UiSvg.color("#ff0000"), Color("ff0000"))
	assert_eq(UiSvg.color(null), null)


func test_svg_size_and_compose() -> void:
	assert_eq(UiSvg.svg_size(BTN), Vector2(64, 64))
	var c := UiSvg.compose([[BTN, Vector2(0, 2)], [ICON, Vector2(20, 0)]])
	assert_eq(UiSvg.svg_size(c), Vector2(148, 128))
	assert_true(c.contains(".p0-cls-1") and c.contains("class=\"p0-cls-2\""), "classes prefixed per part")
	var img := Image.new()
	assert_eq(img.load_svg_from_string(c, 0.5), OK, "composed SVG parses")


func test_icons_map_tint_and_fallback() -> void:
	_setup()
	Icons.set_map({
		"coin": {"svg": "rhosgfx/pack/Coin 2/Coin Flat White.svg", "tint": "palette:COIN"},
		"heart": {"svg": "rhosgfx/pack/missing.svg", "tint": null},
		"rune_frost": {"svg": "rhosgfx/pack/Coin 2/Coin Flat White.svg", "tint": "palette:auto"},
	})
	assert_true(Icons.is_mapped("coin"))
	assert_true(not Icons.is_mapped("heart"), "missing file -> not mapped")
	assert_true(Icons.exists("heart"), "legacy glyph still exists")
	assert_eq(Icons.effective_tint("coin"), UiPalette.COIN)
	assert_eq(Icons.effective_tint("coin", Color.RED), Color.RED, "caller overrides a tint")
	assert_eq(Icons.effective_tint("rune_frost"), UiIcons.default_color("rune_frost"))
	var t := Icons.texture("coin", 40)
	assert_true(t != null and t.get_size().is_equal_approx(Vector2(40, 40)), "mapped texture at logical size")
	assert_true(Icons.texture("coin", 40) == t, "cached")
	var h := Icons.texture("heart", 40)
	assert_true(h != null and h.get_size().is_equal_approx(Vector2(40, 40)), "fallback glyph at logical size")
	assert_eq(Icons.tex("coin", 64).get_size(), Vector2(64, 64), "fixed raster size")
	var r := Icons.rect("heart", 32)
	assert_eq(r.custom_minimum_size, Vector2(32, 32))
	r.free()
	assert_eq(Icons.class_icon("knight"), UiIcons.class_icon("knight"))
	_teardown()


func test_skin_stylebox_present_and_missing() -> void:
	_setup()
	UiSkin.set_manifest({
		"btn": {"fallback": "button", "slice": [10, 10, 10, 20], "scale": 1.5, "states": {
			"normal": {"svg": "rhosgfx/ui/Buttons/3. Yellow/btn_standard.svg"},
			"pressed": {"svg": "rhosgfx/ui/Buttons/3. Yellow/btn_standard.svg", "content": [1, 2, 3, 4], "modulate": "#ff000080"},
			"double": {"layers": [{"svg": "rhosgfx/ui/Buttons/3. Yellow/btn_standard.svg"},
				{"svg": "rhosgfx/ui/Buttons/3. Yellow/btn_standard.svg", "expand": [-2, -2, -2, -2]}]}}},
		"gone": {"fallback": "panel:card", "states": {"normal": {"svg": "rhosgfx/ui/nope.svg"}}},
	})
	assert_true(UiSkin.has("btn") and UiSkin.has("btn", "hover"), "missing state -> normal")
	var sb := UiSkin.stylebox("btn") as StyleBoxTexture
	assert_true(sb != null, "StyleBoxTexture")
	assert_near(sb.texture_margin_bottom, 30.0, 0.001, "slice x scale")
	assert_near(sb.content_margin_left, 15.0, 0.001, "content defaults to slice x scale")
	assert_true(sb.texture.get_size().is_equal_approx(Vector2(96, 96)), "texture = viewBox x scale")
	var pr := UiSkin.stylebox("btn", "pressed") as StyleBoxTexture
	assert_near(pr.content_margin_bottom, 4.0, 0.001, "state content override")
	assert_eq(pr.modulate_color, Color("ff000080"))
	assert_true(UiSkin.stylebox("btn", "double") is UiLayeredStyleBox, "layers -> UiLayeredStyleBox")
	assert_true(not UiSkin.has("gone"))
	assert_true(UiSkin.stylebox("gone") is StyleBoxFlat, "missing art -> flat fallback")
	assert_true(UiSkin.stylebox("unknown", "normal", StyleBoxEmpty.new()) is StyleBoxEmpty, "explicit fallback")
	assert_true(UiSkin.stylebox("btn", "hover") != UiSkin.stylebox("btn", "hover"), "fresh copies")
	var b := Button.new()
	UiSkin.apply_button(b, "btn")
	assert_true(b.has_theme_stylebox_override("hover_pressed"))
	b.free()
	_teardown()


func test_shipped_manifests_parse() -> void:
	UiSkin.set_manifest(null)
	assert_true(UiSkin.pieces().has("button_primary"), "ui_pack.json loads")
	assert_true(not Icons.load_map_file(Icons.DEMO_MAP_PATH).is_empty(), "demo map loads")
	for piece in UiSkin.pieces():
		# every piece yields a box whether or not the art is imported
		assert_true(UiSkin.stylebox(piece) != null, piece)


func test_strip_text_and_input_glyphs() -> void:
	var key := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 10 10\"><rect width=\"10\" height=\"10\"/><text x=\"1\" y=\"8\" class=\"a\">R</text><text/></svg>"
	var s := UiSvg.strip_text(key)
	assert_true(not s.contains("<text") and s.contains("<rect"), s)
	var path := FIX + "glyphs.json"
	DirAccess.make_dir_recursive_absolute(FIX)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "icons": {"a": {"svg": "x/a.svg"}},
		"input_glyphs": {"key_r": {"svg": "x/r.svg", "strip_text": true}, "a": {"svg": "x/other.svg"}}}))
	f.close()
	var m := Icons.load_map_file(path)
	assert_true(m.has("key_r"), "input_glyphs merged into the id space")
	assert_eq(String(m["a"]["svg"]), "x/a.svg", "icons win a clash")


func test_opts_rotate_and_3d_override() -> void:
	_setup()
	var r := UiSvg.rotate(BTN.replace("0 0 64 64", "0 0 64 16"), 90)
	assert_eq(UiSvg.svg_size(r), Vector2(16, 64), "rotated viewBox")
	var img := Image.new()
	assert_eq(img.load_svg_from_string(r, 1.0), OK)
	assert_eq(img.get_size(), Vector2i(16, 64))
	assert_true(img.get_pixel(8, 60).a > 0.5, "art still inside the rotated box")
	UiSkin.set_manifest({"plaque": {"slice": 9, "states": {"normal": {"layers": [
		{"svg": "rhosgfx/ui/Buttons/3. Yellow/btn_standard.svg"},
		{"svg": "rhosgfx/ui/Buttons/3. Yellow/btn_standard.svg", "runtime_tint": false}]}}}})
	var a := UiSkin.stylebox("plaque", "normal", {"tint": Color.RED}) as UiLayeredStyleBox
	var b := UiSkin.stylebox("plaque") as UiLayeredStyleBox
	assert_true(a != null and b != null)
	var ta := (a.layers[0] as StyleBoxTexture).texture as DPITexture
	var tb := (b.layers[0] as StyleBoxTexture).texture as DPITexture
	if ta != null and tb != null:
		assert_true(ta.get_source().contains("#ff0000") and not tb.get_source().contains("#ff0000"), "per-use tint")
		var t1 := (a.layers[1] as StyleBoxTexture).texture as DPITexture
		assert_true(not t1.get_source().contains("#ff0000"), "runtime_tint: false layer untouched")
	assert_true(UiSkin.stylebox("nope", "normal", {"fallback": StyleBoxEmpty.new()}) is StyleBoxEmpty)
	Icons.set_map({"3d:coins": {"svg": "rhosgfx/pack/Coin 2/Coin Flat White.svg", "tint": null}})
	var t := Icons.texture("3d:coins", 40)
	assert_true(t != null and t.get_size().is_equal_approx(Vector2(40, 40)), "map overrides a 3d: id")
	var g := Icons.texture("3d:coins", 40, {"saturation": 0.0})
	assert_true(g != t, "saturation variant cached separately")
	_teardown()


func test_badge_compact_and_entry_saturation() -> void:
	_setup()
	var comp := UiSvg.with_badge(ICON, BTN, "br", 0.5)
	assert_eq(UiSvg.svg_size(comp), Vector2(128, 128), "badge inside the base box")
	var img := Image.new()
	assert_eq(img.load_svg_from_string(comp, 1.0), OK)
	assert_true(img.get_pixel(120, 120).b > 0.9 and img.get_pixel(120, 120).r < 0.2, "badge drawn bottom-right")
	_put("icons/" + UiSvg.sanitize("rhosgfx/pack/small.svg"), BTN)
	Icons.set_map({"x": {"svg": "rhosgfx/pack/Coin 2/Coin Flat White.svg", "compact_svg": "rhosgfx/pack/small.svg",
		"saturation": 0.0, "badge": {"svg": "rhosgfx/pack/small.svg", "corner": "br", "scale": 0.45}}})
	var big := Icons.texture("x", 64) as DPITexture
	var small := Icons.texture("x", 20) as DPITexture
	if big != null and small != null:
		assert_true(big.get_source().contains("p1-"), "badge composited")
		assert_true(small.get_source().contains("rx=\"9\""), "compact art at small size")
		assert_true(not big.get_source().contains("#1778ff") and big.get_source().contains("fill: #"), "entry saturation 0 applied (badge too)")
	assert_true(Icons.texture("x", 64, {"saturation": 1.0}) != big, "caller saturation overrides the entry's")
	_teardown()


func test_ui_audit_no_spillover() -> void:
	# outside a tree: UiAudit sums positions (the shot harness runs it on the live tree)
	var host := Control.new()
	host.size = Vector2(400, 400)
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", UiTheme.panel_box("card"))
	card.position = Vector2(50, 50)
	card.size = Vector2(100, 100)
	host.add_child(card)
	var inside := Button.new()
	inside.position = Vector2(10, 10)
	inside.size = Vector2(40, 40)
	card.add_child(inside)
	var poke := Button.new()
	poke.name = "Close"
	poke.position = Vector2(80, -12)
	poke.size = Vector2(40, 40)
	card.add_child(poke)
	var l := Label.new()
	l.text = "a label far too long for its box"
	l.clip_text = true
	l.position = Vector2(10, 60)
	l.size = Vector2(60, 20)
	card.add_child(l)
	var lines := UiAudit.run(host)
	var joined := "\n".join(lines)
	assert_true(joined.contains("AUDIT_OVERFLOW 20") and joined.contains("Close"), "close button poking out: " + joined)
	assert_true(joined.contains("AUDIT_CLIP"), "clipped label reported: " + joined)
	assert_eq(lines.size(), 2, joined)
	poke.set_meta("allow_overflow", true)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size = Vector2(60, 20)
	assert_eq("\n".join(UiAudit.run(host)), "", "opt-out + ellipsis clean")
	poke.text = "an exempt button whose own label is far too long"
	poke.clip_text = true
	var inner := Label.new()
	inner.text = "clipped text inside an exempt node"
	inner.clip_text = true
	inner.size = Vector2(20, 20)
	poke.add_child(inner)
	assert_true("\n".join(UiAudit.run(host)).contains("AUDIT_CLIP"), "allow_overflow only exempts the frame check")
	poke.set_meta("audit_skip", true)
	assert_eq("\n".join(UiAudit.run(host)), "", "audit_skip skips the subtree")
	host.free()


func test_rgba_transparent_rect_is_not_drawn() -> void:
	# ThorVG ignores rgba() alpha: the pack's transparent helper rects rendered as black squares
	var svg := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 64\"><defs><style>.cls-1{fill: rgba(26, 26, 26, 0);}.cls-2{fill:#ff0000;}.cls-3{stroke: rgba(255, 0, 0, 0.5);}</style></defs>" \
		+ "<rect class=\"cls-1\" width=\"64\" height=\"64\"/><circle class=\"cls-2\" cx=\"32\" cy=\"32\" r=\"10\"/><rect fill=\"rgba(0,0,0,0)\" width=\"1\" height=\"1\"/></svg>"
	var fixed := UiSvg.fix_rgba(svg)
	assert_true(not fixed.contains("rgba("), "no rgba left: " + fixed)
	assert_true(fixed.contains("fill: none") and fixed.contains("fill=\"none\""), "transparent -> none")
	assert_true(fixed.contains("stroke: #ff0000; stroke-opacity: 0.5"), "alpha -> opacity: " + fixed)
	var img := Image.new()
	assert_eq(img.load_svg_from_string(fixed, 1.0), OK)
	assert_true(img.get_pixel(1, 1).a < 0.05, "corner transparent")
	assert_true(img.get_pixel(32, 32).a > 0.9, "icon drawn")
	# the real pack icon (when imported): star_gold_outline's corner is transparent
	var real := "res://assets/ui/icons/vector-icon-pack-pro/general/star/star_gold_outline.svg"
	UiSvg.roots = UiSvg.ROOTS.duplicate()
	UiSvg.clear_cache()
	if FileAccess.file_exists(real):
		var t := UiSvg.raster(UiSvg.source(real), 64)
		assert_true(t.get_image().get_pixel(1, 1).a < 0.05, "star icon corner transparent")


func test_key_glyph_label_of_handles_null_labels() -> void:
	# icon_map input_glyphs use "label": null for pure-art keys (arrows, blank, mouse):
	# they must yield "" instead of erroring, and plain keys keep their text.
	assert_eq(KeyGlyph.label_of("key_left"), "", "arrow key has no label")
	assert_eq(KeyGlyph.label_of("mouse_left"), "", "mouse glyph has no label")
	assert_eq(KeyGlyph.label_of("key_space"), "SPACE")
	assert_eq(KeyGlyph.label_of("key_unmapped_x"), "UNMAPPED_X", "unmapped ids derive a label")


func test_icon_only_button_glyph_is_centred() -> void:
	# an empty text column used to keep the HBox separation and push the glyph ~5 px left
	var b := GameButton.round_icon("close", 88)
	b._ready()
	assert_true(not b._text_col.visible, "icon-only button hides its text column")
	var t := GameButton.make("ROLL", "dice", GameButton.Kind.PRIMARY, 34)
	t._ready()
	assert_true(t._text_col.visible, "labelled button keeps its text column")
	b.text = "NOW LABELLED"
	assert_true(b._text_col.visible, "setting text shows the column again")
	b.free()
	t.free()

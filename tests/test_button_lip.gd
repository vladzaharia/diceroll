extends "res://tests/test_case.gd"
## 3D button lip contrast and label centring (short buttons such as the update banner's
## DOWNLOAD read off-centre when the lip was nearly the face colour). UiSvg.deepen_lip on a
## synthetic SVG always runs; the shipped-art checks run when the RhosGFX pack is imported.

const YELLOW := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 160 64\"><defs><style>.cls-1 { fill: #f15a24; } .cls-2 { fill: #fc9504; } .cls-3 { fill: #fdaf18; }</style></defs><rect class=\"cls-2\" x=\"4\" y=\"4\" width=\"152\" height=\"56\" rx=\"5\" ry=\"5\"/><rect class=\"cls-3\" x=\"4\" y=\"4\" width=\"152\" height=\"46\" rx=\"5\" ry=\"5\"/><path class=\"cls-1\" d=\"M0 0h160v64H0z\"/></svg>"
const RATIO := 0.72
const HEIGHTS := [48, 56, 64, 72, 80, 88, 96, 120]
const KINDS := [GameButton.Kind.PRIMARY, GameButton.Kind.SECONDARY, GameButton.Kind.DANGER,
	GameButton.Kind.SUCCESS, GameButton.Kind.GHOST]


func _teardown() -> void:
	UiSkin.clear_cache()


func test_deepen_lip_synthetic() -> void:
	var before := UiSvg.lip_shapes(YELLOW)
	assert_true(not before.is_empty(), "3D button shape found")
	assert_true((before["lip"] as Color).get_luminance() > (before["face"] as Color).get_luminance() * RATIO,
		"the pack's yellow lip is too close to the face")
	var out := UiSvg.deepen_lip(YELLOW, RATIO)
	var after := UiSvg.lip_shapes(out)
	assert_true((after["lip"] as Color).get_luminance() <= (after["face"] as Color).get_luminance() * RATIO + 0.001,
		"lip darkened to the ratio")
	assert_eq((after["face"] as Color).to_html(false), "fdaf18", "face untouched")
	assert_eq(after["face_rect"], Rect2(4, 4, 152, 46))
	# white focus ring as the outline: still darker, never lighter
	var focus := UiSvg.deepen_lip(YELLOW.replace("#f15a24", "#fff"), RATIO)
	var f := UiSvg.lip_shapes(focus)
	assert_true((f["lip"] as Color).get_luminance() < (before["lip"] as Color).get_luminance(), "focus lip darker")
	# not 3D button art / already dark enough: unchanged
	var flat := "<svg viewBox=\"0 0 10 10\"><rect x=\"1\" y=\"1\" width=\"8\" height=\"8\" fill=\"#fff\"/></svg>"
	assert_eq(UiSvg.deepen_lip(flat, RATIO), flat)
	var blue := YELLOW.replace("#fc9504", "#1778ff").replace("#fdaf18", "#37b9ff")
	assert_eq(UiSvg.deepen_lip(blue, RATIO), blue, "blue lip is already dark enough")


## Every shipped button piece / state: a clearly darker lip, and content margins that centre
## the label on the face (above the lip), not on the whole box.
func test_shipped_button_lips_and_content() -> void:
	if not UiSkin.has("button_primary"):
		return
	for piece in UiSkin.pieces():
		if not String(piece).begins_with("button_"):
			continue
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			var l: Dictionary = UiSkin.layers(piece, st)[0]
			var src := UiSvg.source(UiSvg.runtime_path("pack", String(l["svg"])))
			var sh := UiSvg.lip_shapes(UiSvg.deepen_lip(src, float(l.get("lip", 1.0))))
			var tag := "%s/%s" % [piece, st]
			assert_true(not sh.is_empty(), tag + " is 3D button art")
			if sh.is_empty():
				continue
			assert_true(l.has("lip"), tag + " has a lip ratio")
			assert_true((sh["lip"] as Color).get_luminance() <= (sh["face"] as Color).get_luminance() * RATIO + 0.001,
				tag + " lip clearly darker than the face")
			var s := float(l.get("scale", 1.0))
			var view := UiSvg.svg_size(src)
			var face: Rect2 = sh["face_rect"]
			var sb := UiSkin.stylebox(piece, st)
			var top_gap := sb.content_margin_top - face.position.y * s
			var bottom_gap := sb.content_margin_bottom - (view.y - face.end.y) * s
			assert_near(top_gap, bottom_gap, 0.75, tag + " content centred on the face")


## GameButton at every drawn height: the content box is centred on the face, not the box.
func test_game_button_label_centred_on_face() -> void:
	if not UiSkin.has("button_primary"):
		return
	for h in HEIGHTS:
		for k in KINDS:
			var b := GameButton.make("BUY", "", k, clampi(int(h * 0.42), 18, 40))
			b.min_height = h
			b._ready()
			b.size = b.get_combined_minimum_size()
			b._layout()
			var l: Dictionary = UiSkin.layers(b.piece(), "normal")[0]
			var src := UiSvg.source(UiSvg.runtime_path("pack", String(l["svg"])))
			var face: Rect2 = UiSvg.lip_shapes(src)["face_rect"]
			var s := float(l.get("scale", 1.0))
			var box := b.box_rect()
			var face_mid := box.position.y + (face.position.y * s + box.size.y - (64.0 - face.end.y) * s) * 0.5
			var mid := b._content.position.y + b._content.size.y * 0.5
			assert_near(mid, face_mid, 1.0, "%s %d px: label centred on the face" % [b.piece(), h])
			assert_true(mid < box.position.y + box.size.y * 0.5, "%s %d px: above the box centre (lip below)" % [b.piece(), h])
			b.free()

extends RefCounted
## Dice tray scenarios for the screenshot harness (tools/shot.gd).
##  dice_tray    6 mixed dice (runes, edited faces, Wild), two marked, one cursed; the
##               unmarked dice are thrown at 0.4 s, then the marked ones, looping.
##               Use --wait=0.5 --frames=6 to capture mid-roll frames.
##  dice_tray_3  3 plain dice settled on 4 4 2 with the pair highlighted as a combo group.

const MOCK_6 := [
	{"faces": [1, 2, 3, 4, 6, 6], "rune": "", "edited": [0, 0, 0, 0, 1, 0]},
	{"faces": [1, 2, 3, 4, 5, 6], "rune": "blade", "edited": [0, 0, 0, 0, 0, 0]},
	{"faces": [1, 2, 3, 4, 5, 6], "rune": "wild", "edited": [0, 0, 0, 0, 0, 0]},
	{"faces": [6, 2, 3, 4, 5, 6], "rune": "ember", "edited": [1, 0, 0, 0, 0, 0]},
	{"faces": [1, 2, 3, 4, 5, 6], "rune": "guard", "edited": [0, 0, 0, 0, 0, 0]},
	{"faces": [1, 2, 3, 4, 5, 6], "rune": "frost", "edited": [0, 0, 0, 0, 0, 0]},
]


static func names() -> PackedStringArray:
	return PackedStringArray(["dice_tray", "dice_tray_3"])


static func build(name: String) -> Node:
	if not names().has(name):
		return null
	var root := _Host.new()
	root.mode = name
	return root


class _Host:
	extends Control

	var mode := ""
	var tray: DiceTray
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rng.seed = 7
		var bg := TextureRect.new()
		var g := Gradient.new()
		g.set_color(0, Color(0.16, 0.17, 0.24))
		g.set_color(1, Color(0.04, 0.035, 0.05))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.3)
		gt.fill_to = Vector2(1.1, 1.0)
		bg.texture = gt
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		tray = DiceTray.new()
		add_child(tray)
		resized.connect(_place)
		_place()
		match mode:
			"dice_tray":
				tray.set_dice(MOCK_6)
				tray.set_values([3, 5, 2, 6, 1, 4])
				tray.set_marked(1, true)
				tray.set_marked(3, true)
				tray.set_locked(5, true)
				_loop()
			"dice_tray_3":
				var plain := {"faces": [1, 2, 3, 4, 5, 6], "rune": "", "edited": [0, 0, 0, 0, 0, 0]}
				tray.set_dice([plain, plain, plain])
				tray.set_values([4, 4, 2])
				tray.highlight_group([0, 1], Color(1.0, 0.8, 0.3))

	func _place() -> void:
		var vs := size if size.x > 0.0 else get_viewport_rect().size
		var portrait := vs.y > vs.x
		var w := vs.x - 32.0 if portrait else minf(vs.x - 32.0, 880.0)
		var h := 330.0 if portrait else 280.0
		tray.position = Vector2((vs.x - w) * 0.5, vs.y - h - 24.0)
		tray.size = Vector2(w, h)

	func _loop() -> void:
		await get_tree().create_timer(0.4).timeout
		while is_inside_tree():
			var idx: Array[int] = [0, 2, 4, 5]
			tray.roll(_values(), idx)
			await tray.settled
			await get_tree().create_timer(1.0).timeout
			var marked: Array[int] = [1, 3]
			for i in marked:
				tray.set_marked(i, false)
			tray.roll(_values(), marked)
			await tray.settled
			await get_tree().create_timer(0.8).timeout
			for i in marked:
				tray.set_marked(i, true)
			await get_tree().create_timer(0.6).timeout

	func _values() -> Array[int]:
		var out: Array[int] = []
		for d in MOCK_6:
			out.append(d.faces[_rng.randi_range(0, 5)])
		return out

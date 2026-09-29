class_name DressingSheet
extends Control
## Contact sheet (scenario `biome_variants`): every biome (columns) x dressing variants
## (rows), each cell its own SubViewport with a board in the overview camera.
##   --biomes=glade,magma   subset of Biome.IDS (default all six)
##   --variants=0,1,2       variant seeds to show (default 0,1,2)

var _cells: Array = []


func _ready() -> void:
	var args: Dictionary = Shot.args if Shot else {}
	var biomes: Array = Array(String(args.get("biomes", ",".join(Biome.IDS))).split(","))
	var variants: Array = Array(String(args.get("variants", "0,1,2")).split(","))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var grid := GridContainer.new()
	grid.columns = biomes.size()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	add_child(grid)
	var size := get_viewport().get_visible_rect().size
	var cell := Vector2i(int((size.x - 2 * (biomes.size() - 1)) / biomes.size()),
		int((size.y - 2 * (variants.size() - 1)) / variants.size()))
	for v in variants:
		for id in biomes:
			var box := SubViewportContainer.new()
			box.custom_minimum_size = Vector2(cell)
			box.stretch = true
			grid.add_child(box)
			var vp := SubViewport.new()
			vp.size = cell
			vp.own_world_3d = true
			vp.msaa_3d = Viewport.MSAA_2X
			box.add_child(vp)
			var board := BoardView.new()
			vp.add_child(board)
			board.variant_seed = int(v)
			board.hero_class = "knight"
			board.build(String(id), BoardScenarios.biome_tiles(String(id)))
			board.place_hero(0)
			var rig := CameraRig.new()
			vp.add_child(rig)
			rig.overview(board.ring_bounds(), true)
			var l := Label.new()
			l.text = "%s  v%s  (set %d / kits %d / corners %d)" % [id, v, Dressing.layout_of(int(v)) % 3,
				(Dressing.layout_of(int(v)) % 3 + Dressing.layout_of(int(v)) / 3) % 3,
				(Dressing.layout_of(int(v)) % 3 + 2 * (Dressing.layout_of(int(v)) / 3)) % 3]
			l.add_theme_font_size_override("font_size", 13)
			l.add_theme_color_override("font_outline_color", Color.BLACK)
			l.add_theme_constant_override("outline_size", 4)
			l.position = Vector2(6, 4)
			box.add_child(l)

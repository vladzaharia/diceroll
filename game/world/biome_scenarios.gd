class_name NewBiomeScenarios
extends RefCounted
## Board scenarios for the four 2026-09-29 biomes (docs/design/2026-09-29-new-biomes.md), for the
## screenshot harness (registered in tools/scenarios.gd):
##  board_mines / board_warcamp / board_ruins / board_moonlit
##                  overview of the biome's real generated board (its ore / drum / oasis tiles),
##                  hero and landing targets. --variant=N picks the dressing variant (0..8; layouts
##                  0..2 show the three set pieces), --tile=N the hero's tile.
##                  Moonlit: --phase=crescent|half|full sets the sky moon, --blood=1 the blood moon.
##  tiles_twists    close-up of the twist tiles and their states on one biome's board
##                  (--biome=mines: ore veins, a cave-in trap; warcamp: drums, a smashed drum;
##                  ruins: oases; moonlit: the moon rune chest). --anim=1 plays the state changes
##                  (cave-in, smash, splash) so --frames catches them.
##  biome_variants  (game/world/scenarios.gd) takes --biomes=mines,warcamp,ruins,moonlit too.

const BIOMES := ["mines", "warcamp", "ruins", "moonlit"]
const NAMES := ["board_mines", "board_warcamp", "board_ruins", "board_moonlit", "tiles_twists"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var d := _Driver.new()
	d.name = "NewBiomeScenario"
	d.scenario = name
	return d


class _Driver extends Node3D:
	var scenario := ""
	var board: BoardView
	var rig: CameraRig

	func _ready() -> void:
		var args: Dictionary = Shot.args if Shot else {}
		var id := String(args.get("biome", "mines"))
		if scenario.begins_with("board_"):
			id = scenario.trim_prefix("board_")
		board = BoardView.new()
		add_child(board)
		var tier := BoardScenarios.tier_of(id)
		board.hero_class = String(args.get("hero", ["knight", "barbarian", "mage"][tier - 1]))
		board.hero_idx = int(args.get("tile", "0"))
		board.variant_seed = int(args.get("variant", "0"))
		board.moon_phase = String(args.get("phase", "crescent")) if id == "moonlit" else ""
		board.build(id, BoardScenarios.biome_tiles(id))
		rig = CameraRig.new()
		add_child(rig)
		if args.get("blood", "0") == "1":
			board.set_blood_moon(true, false)
		if scenario == "tiles_twists":
			await _twists(id, args)
			return
		board.place_hero(int(args.get("tile", "0")))
		rig.overview(board.ring_bounds(), true)
		var from := board.hero_idx
		var t: Array[int] = [from + 2, from + 5, from + 3]
		var v: Array[int] = [2, 5, 3]
		board.show_targets(t, v)

	## One row of the biome's twist tiles next to the Start corner, framed close.
	func _twists(id: String, args: Dictionary) -> void:
		var row: Array = []
		match id:
			"mines":
				row = [{"type": "ore"}, {"type": "ore"}, {"type": "trap"}, {"type": "ore"}, {"type": "trap"}, {"type": "chest"}]
			"warcamp":
				row = [{"type": "drum"}, {"type": "empty"}, {"type": "drum"}, {"type": "enemy", "enemies": ["orc_raider"]},
					{"type": "drum"}, {"type": "empty"}]
			"ruins":
				row = [{"type": "oasis"}, {"type": "empty"}, {"type": "oasis"}, {"type": "campfire"}, {"type": "oasis"},
					{"type": "trap"}]
			"moonlit":
				row = [{"type": "chest", "moon": true}, {"type": "event"}, {"type": "chest"},
					{"type": "enemy", "enemies": ["werewolf"]}, {"type": "chest", "moon": true}, {"type": "empty"}]
		for k in row.size():
			board.set_tile(k + 1, row[k], false)
		if id == "warcamp":
			# smashed drums keep their staves on the Empty tile
			for k in [2, 6]:
				board._smashed[k] = true
				board.set_tile(k, {"type": "empty"}, false)
		board.place_hero(0)
		await get_tree().create_timer(0.1).timeout
		var pts := PackedVector3Array()
		for k in row.size() + 1:
			pts.append(board.tile_global_position(k))
		pts.append(board.tile_global_position(3) + Vector3.UP * 1.6)
		rig.frame_points(pts, float(args.get("yaw", "90")), float(args.get("pitch", "40")), true)
		if args.get("anim", "0") != "1":
			return
		await get_tree().create_timer(maxf(float(args.get("wait", "2.0")) - 0.9, 0.2)).timeout
		match id:
			"mines":
				board.cave_in(1)
			"warcamp":
				board.drum_beat(3)
				board.smash_drum(1)
			"ruins":
				board.oasis_splash(1)
				board.oasis_splash(5)
			"moonlit":
				board.set_moon_phase("full")

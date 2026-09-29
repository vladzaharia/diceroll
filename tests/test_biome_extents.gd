extends "res://tests/test_case.gd"
## Layout guard: every biome's walkable floor reaches BiomeExtents.MIN_PITCHES tile pitches
## past the ring on all four sides (see game/world/check_biome_extents.gd for all ring sizes).

func test_floor_margin_every_biome() -> void:
	for id in Biome.IDS:
		var r := BiomeExtents.measure(id, BiomeExtents.DEFAULT_RING)
		assert_true(r.ok, "floor margin short: " + BiomeExtents.describe(id, r))

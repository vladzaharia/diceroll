extends SceneTree
## Headless layout guard: every biome's walkable floor must reach at least
## BiomeExtents.MIN_PITCHES tile pitches past the ring on all four sides.
##
##   godot --headless --path . -s game/world/check_biome_extents.gd [-- --sizes=24,28,32]
##
## Prints per-biome margins and exits 1 if any side is short.


func _init() -> void:
	var sizes: Array[int] = [24, 28, 32]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sizes="):
			sizes.clear()
			for s in arg.substr(8).split(","):
				sizes.append(int(s))
	var bad := 0
	print("min margin %.2f (%.2f pitches)" % [BiomeExtents.min_margin(), BiomeExtents.MIN_PITCHES])
	for size in sizes:
		print("ring %d:" % size)
		for id in Biome.IDS:
			var r := BiomeExtents.measure(id, size)
			print("  " + BiomeExtents.describe(id, r))
			if not r.ok:
				bad += 1
	print("BIOME EXTENTS %s" % ("OK" if bad == 0 else "FAILED (%d)" % bad))
	quit(0 if bad == 0 else 1)

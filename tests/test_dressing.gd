extends "res://tests/test_case.gd"
## Seeded biome dressing (game/world/dressing): deterministic per seed, varied between
## seeds, and every seeded prop obeys the placement rules (off the ring, grounded, low on
## the camera side).

const EXTENT := 8.4     # 8x8 ring (the default board)
var extent := EXTENT


func _build(id: String, seed: int) -> Node3D:
	# (the runner executes from SceneTree._init, so the board is built detached)
	return Biome.build(id, extent, seed)


func _free(w: Node3D) -> void:
	w.free()


func _signature(w: Node3D) -> Array:
	var out: Array = []
	for holder in ["Dressing", "SetPiece", "InnerCorners"]:
		var n := w.get_node_or_null(holder)
		if n == null:
			continue
		for c in n.get_children():
			if c is Node3D:
				out.append("%s|%s|%.2f,%.2f" % [holder, String(c.scene_file_path).get_file(), c.position.x, c.position.z])
	return out


func test_same_seed_same_board() -> void:
	for id in Biome.IDS:
		var a := _build(id, 1234)
		var sa := _signature(a)
		_free(a)
		var b := _build(id, 1234)
		var sb := _signature(b)
		_free(b)
		assert_eq(sa, sb, "%s: same seed must rebuild the same dressing" % id)


func test_layouts_differ() -> void:
	for id in Biome.IDS:
		var sigs: Array = []
		for v in 3:
			var w := _build(id, v)
			sigs.append(_signature(w))
			_free(w)
		assert_true(sigs[0] != sigs[1] and sigs[1] != sigs[2] and sigs[0] != sigs[2],
			"%s: layouts 0..2 should differ" % id)


func test_layout_mapping() -> void:
	# layouts 0..2 use one kit index for every slot; 3..8 mix them, all 27 combos not needed
	for v in 3:
		Dressing.layout = v
		assert_eq([Dressing.kit(0), Dressing.kit(1), Dressing.kit(2)], [v, v, v], "layout %d" % v)
	var combos := {}
	for v in 9:
		Dressing.layout = v
		combos[[Dressing.kit(0), Dressing.kit(1), Dressing.kit(2)]] = true
	assert_eq(combos.size(), 9, "nine distinct kit combos")


func _check_rules(id: String, seed: int) -> void:
	var w := _build(id, seed)
	var d := w.get_node("Dressing")
	var e := extent
	var checked := 0
	for n in d.find_children("*", "Node3D", true, false):
		if not n.has_meta("dress"):
			continue
		if n is MultiMeshInstance3D:
			var mm := (n as MultiMeshInstance3D).multimesh
			for i in mm.instance_count:
				var p := mm.get_instance_transform(i).origin
				var m := maxf(absf(p.x), absf(p.z))
				assert_true(m < e - 2.1 - 0.05 or m > e + 0.3, "%s/%d: clutter on the ring at %s" % [id, seed, p])
				checked += 1
			continue
		var node := n as Node3D
		if node.get_parent() != d:
			continue
		var p := node.position
		var m := maxf(absf(p.x), absf(p.z))
		assert_true(m < e - 2.1 or m > e + 0.3, "%s/%d: %s on the ring at %s" % [id, seed, node.name, p])
		# grounded: stands on the terrain (small lifts allowed for props resting on others)
		var g := Dressing.gy(p.x, p.z)
		assert_true(p.y >= g - 0.01 and p.y <= g + 0.8, "%s/%d: %s floating / sunk (y %.2f, ground %.2f)" % [id, seed, node.name, p.y, g])
		checked += 1
	assert_true(checked > 10, "%s/%d: seeded dressing present (%d)" % [id, seed, checked])
	_free(w)


func test_placement_rules() -> void:
	for id in Biome.IDS:
		for seed in [0, 1, 2, 7, 123456]:
			_check_rules(id, seed)


func test_placement_rules_other_ring_sizes() -> void:
	# 7x7 (24 tiles) and 9x9 (32 tiles) rings
	for ext in [7.35, 9.45]:
		extent = ext
		for id in Biome.IDS:
			for seed in [0, 1, 2]:
				_check_rules(id, seed)
	extent = EXTENT

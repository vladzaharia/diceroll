class_name FishingProp
extends RefCounted
## Board-tile prop for fishing: a little pond corner. A round pool on a sandy rim, a wooden
## jetty with a fish barrel, a rod leaning out over the water with its line down to a bobbing
## red-and-white float, cattails at the back, a lily pad, and a golden fish leaping out of a
## splash (it hops in a slow loop). Fit ~1.4 x 1.4, y = tile top; MinigameProps adds the sparkle.



static func build(n: Node3D) -> void:
	# the pond: sand rim, water, a lighter shallow ring
	var sand := MinigameProps._mesh(n, _cyl(0.64, 0.05), MinigameProps._mat(Color("e8d49a"), 0.9), Vector3(0.05, 0.025, 0.0), Vector3.ZERO, "Sand")
	sand.scale = Vector3(1.0, 1.0, 0.92)
	var water_m := MinigameProps._mat(Color("3aa6e0"), 0.08, 0.0, 0.18)
	water_m.clearcoat_enabled = true
	water_m.clearcoat = 1.0
	var water := MinigameProps._mesh(n, _cyl(0.56, 0.05), water_m, Vector3(0.07, 0.045, 0.0), Vector3.ZERO, "Water")
	water.scale = Vector3(1.0, 1.0, 0.9)
	var deep := MinigameProps._mesh(n, _cyl(0.3, 0.01), MinigameProps._mat(Color("2170b8"), 0.1, 0.0, 0.1), Vector3(0.14, 0.071, -0.06))
	deep.scale = Vector3(1.0, 1.0, 0.85)
	# stones on the rim
	for k in 6:
		var a := -0.4 + k * 0.62
		var st := MinigameProps._mesh(n, MinigameProps._sphere(0.05 + 0.015 * (k % 2)), MinigameProps._mat(Color("a9a6a2"), 0.9), Vector3(0.05 + cos(a) * 0.6, 0.04, sin(a) * 0.55))
		st.scale = Vector3(1.2, 0.7, 1.0)
	_jetty(n)
	_reeds(n)
	# lily pad + flower
	var pad := MinigameProps._mesh(n, _cyl(0.1, 0.012), MinigameProps._mat(Color("3f9a3c"), 0.6), Vector3(-0.12, 0.078, 0.3), Vector3.ZERO, "LilyPad")
	pad.scale = Vector3(1.0, 1.0, 0.8)
	for k in 5:
		var a := TAU * k / 5.0
		var petal := MinigameProps._mesh(n, MinigameProps._sphere(0.028), MinigameProps._mat(Color("ff9cc2"), 0.5, 0.0, 0.15), Vector3(-0.1 + cos(a) * 0.03, 0.1, 0.3 + sin(a) * 0.03))
		petal.scale = Vector3(1.0, 0.6, 1.0)
	MinigameProps._mesh(n, MinigameProps._sphere(0.02), MinigameProps._mat(Color("ffd24a"), 0.4, 0.0, 0.4), Vector3(-0.1, 0.11, 0.3))
	# the bobber on the water (bobbing) with ripples
	var bob := Node3D.new()
	bob.name = "Bobber"
	bob.position = Vector3(0.28, 0.1, 0.12)
	n.add_child(bob)
	MinigameProps._mesh(bob, MinigameProps._sphere(0.055, 0.055), MinigameProps._mat(Color("ff3b4a"), 0.3, 0.0, 0.25), Vector3(0, 0.014, 0))
	MinigameProps._mesh(bob, MinigameProps._sphere(0.054, 0.05), MinigameProps._mat(Color("fbf6ec"), 0.4), Vector3(0, -0.012, 0))
	MinigameProps._mesh(bob, _cyl(0.008, 0.07), MinigameProps._mat(Color("fff4d0"), 0.5), Vector3(0, 0.07, 0))
	MinigameProps._mesh(bob, MinigameProps._sphere(0.014), MinigameProps._mat(Color("ffd24a"), 0.3, 0.0, 0.8), Vector3(0, 0.105, 0))
	MinigameProps._bob(bob, 0.018, 0.7)
	_ring(n, Vector3(0.28, 0.074, 0.12), 0.09)
	_ring(n, Vector3(0.28, 0.074, 0.12), 0.14)
	_leap(n)


static func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 28
	return c


static func _ring(n: Node3D, at: Vector3, r: float) -> void:
	var t := TorusMesh.new()
	t.inner_radius = r
	t.outer_radius = r + 0.012
	t.rings = 24
	t.ring_segments = 6
	var m := MinigameProps._mat(Color(1, 1, 1, 0.7), 0.2, 0.0, 0.4)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := MinigameProps._mesh(n, t, m, at)
	mi.scale = Vector3(1.0, 0.3, 1.0)


static func _jetty(n: Node3D) -> void:
	var j := Node3D.new()
	j.name = "Jetty"
	j.position = Vector3(-0.36, 0.0, 0.02)
	j.rotation.y = deg_to_rad(28.0)
	n.add_child(j)
	var wood := MinigameProps._mat(Color("b07a48"), 0.85)
	var wood2 := MinigameProps._mat(Color("9a663a"), 0.85)
	var post := MinigameProps._mat(Color("6a4226"), 0.9)
	for k in 5:
		MinigameProps._mesh(j, MinigameProps._box(Vector3(0.16, 0.035, 0.5)), wood if k % 2 == 0 else wood2, Vector3(-0.2 + k * 0.1, 0.16, 0.0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			MinigameProps._mesh(j, _cyl(0.028, 0.2), post, Vector3(sx * 0.21, 0.08, sz * 0.2))
	# a barrel of fish at the back of the jetty
	var barrel := Props.put(j, Props.K + "resources/Food_Barrel_Fish.gltf", Vector3(-0.14, 0.18, -0.16), 30.0, 0.26)
	barrel.name = "Barrel"
	# the rod: a tapered pole leaning out over the water, cork grip, a reel
	var rod := Node3D.new()
	rod.name = "Rod"
	rod.position = Vector3(0.04, 0.2, 0.1)
	j.add_child(rod)
	rod.rotation = Vector3(0.0, deg_to_rad(-28.0), deg_to_rad(-52.0))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.008
	pole.bottom_radius = 0.02
	pole.height = 0.95
	MinigameProps._mesh(rod, pole, MinigameProps._mat(Color("3a6fb0"), 0.35, 0.2), Vector3(0, 0.475, 0))
	MinigameProps._mesh(rod, _cyl(0.026, 0.18), MinigameProps._mat(Color("c89a62"), 0.9), Vector3(0, 0.09, 0))
	var reel := MinigameProps._mesh(rod, _cyl(0.045, 0.03), MinigameProps._mat(Color("c8ced8"), 0.3, 0.7), Vector3(0.04, 0.22, 0))
	reel.rotation.z = PI * 0.5
	MinigameProps._mesh(rod, MinigameProps._sphere(0.016), MinigameProps._mat(Color("ffd24a"), 0.3, 0.0, 0.5), Vector3(0, 0.95, 0))
	# the line: from the rod tip down to the bobber (world-space, computed after placement)
	var tip_local := Vector3(0, 0.95, 0)
	var tip := (j.transform * rod.transform) * tip_local
	var bob := Vector3(0.28, 0.16, 0.12)
	var mid := (tip + bob) * 0.5
	var line := MinigameProps._mesh(n, _cyl(0.004, tip.distance_to(bob)), MinigameProps._mat(Color(1, 1, 1), 0.3, 0.0, 0.6), mid, Vector3.ZERO, "Line")
	line.look_at_from_position(mid, bob, Vector3.UP)
	line.rotate_object_local(Vector3.RIGHT, PI * 0.5)


static func _reeds(n: Node3D) -> void:
	var stem := MinigameProps._mat(Color("5aa83e"), 0.7)
	var head := MinigameProps._mat(Color("8a5430"), 0.8)
	var spots := [Vector3(0.42, 0.0, -0.4), Vector3(0.5, 0.0, -0.3), Vector3(0.34, 0.0, -0.46), Vector3(0.56, 0.0, -0.18), Vector3(0.2, 0.0, -0.5)]
	for k in spots.size():
		var h := 0.42 + 0.08 * sin(k * 2.3)
		var r := Node3D.new()
		r.position = spots[k]
		r.rotation = Vector3(0.1 * sin(k), 0.0, 0.12 * cos(k * 1.7))
		n.add_child(r)
		MinigameProps._mesh(r, _cyl(0.012, h), stem, Vector3(0, h * 0.5, 0))
		if k % 2 == 0:
			MinigameProps._mesh(r, _cyl(0.028, 0.1), head, Vector3(0, h - 0.06, 0))
		else:
			var leaf := MinigameProps._mesh(r, MinigameProps._box(Vector3(0.02, h * 0.6, 0.05)), stem, Vector3(0.03, h * 0.35, 0))
			leaf.rotation.z = -0.35


static func _leap(n: Node3D) -> void:
	# the splash where it jumped: a ring of droplets
	var splash := Node3D.new()
	splash.name = "Splash"
	splash.position = Vector3(0.22, 0.075, -0.2)
	n.add_child(splash)
	var drop := MinigameProps._mat(Color("e6fbff"), 0.1, 0.0, 0.6)
	for k in 8:
		var a := TAU * k / 8.0
		var d := MinigameProps._mesh(splash, MinigameProps._sphere(0.022 + 0.01 * (k % 2)), drop, Vector3(cos(a) * 0.1, 0.02 + 0.04 * (k % 3), sin(a) * 0.08))
		d.scale = Vector3(1.0, 1.4, 1.0)
	_ring(n, splash.position, 0.12)
	# the golden fish arcing out of it
	var fish := Node3D.new()
	fish.name = "Fish"
	fish.position = Vector3(0.22, 0.42, -0.2)
	fish.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(-15.0), deg_to_rad(38.0))
	fish.scale = Vector3.ONE * 1.3
	n.add_child(fish)
	var gold := MinigameProps._mat(Color("ffc83a"), 0.3, 0.3, 0.35)
	var body := MinigameProps._mesh(fish, MinigameProps._sphere(0.11), gold, Vector3.ZERO, Vector3.ZERO, "Body")
	body.scale = Vector3(1.6, 0.8, 0.5)
	MinigameProps._mesh(fish, MinigameProps._sphere(0.045), MinigameProps._mat(Color("ff5a24"), 0.4, 0.0, 0.2), Vector3(0.0, 0.05, 0.03)).scale = Vector3(1.4, 0.7, 1.0)
	var fin_m := MinigameProps._mat(Color("ffe08a"), 0.4, 0.0, 0.3)
	for sg in [-1.0, 1.0]:
		var tail := MinigameProps._mesh(fish, MinigameProps._box(Vector3(0.13, 0.05, 0.02)), fin_m, Vector3(-0.2, sg * 0.04, 0.0))
		tail.rotation.z = sg * 0.6
	var fin := MinigameProps._mesh(fish, MinigameProps._box(Vector3(0.08, 0.06, 0.012)), MinigameProps._mat(Color("fff0c0"), 0.4), Vector3(0.0, 0.1, 0.0))
	fin.rotation.z = -0.3
	for sz in [-1.0, 1.0]:
		MinigameProps._mesh(fish, MinigameProps._sphere(0.018), MinigameProps._mat(Color("1b1530"), 0.3), Vector3(0.12, 0.025, sz * 0.05))
	# a slow hop: up and a little tilt, down again
	var y := fish.position.y
	var t := fish.create_tween().set_loops()
	t.tween_property(fish, "position:y", y + 0.07, 0.8).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(fish, "rotation:z", deg_to_rad(20.0), 0.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(fish, "position:y", y, 0.8).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(fish, "rotation:z", deg_to_rad(38.0), 0.8).set_trans(Tween.TRANS_SINE)

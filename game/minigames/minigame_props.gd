class_name MinigameProps
extends RefCounted
## Board props for minigame tiles ({type:"minigame", game:<id>}), one per game, built from
## KayKit pieces + simple procedural meshes in the tile style (fit ~1.4 x 1.4, y = tile top):
##   fossil_hunter   a dirt mound with a bone poking out and a shovel stuck in it
##   bubble_breaker  a bobbing cluster of glossy bubbles in the four game colours
##   scratch_off     a tilted scratch card (foil panels, gold title band) with a die
##   claw_machine    a tiny arcade cabinet: marquee, glass box, a claw over a prize


static func make(game: String) -> Node3D:
	var n := Node3D.new()
	n.name = "Minigame_" + game
	match game:
		"fossil_hunter": _fossil(n)
		"bubble_breaker": _bubbles(n)
		"scratch_off": _scratch(n)
		"claw_machine": _claw(n)
		_: _bubbles(n)
	# a slow arcade sparkle so the tile reads as "play me"
	var sp := Fx.elite_sparkle(n, Vector3(0, 0.1, 0), 0.6, 0.9)
	sp.name = "Sparkle"
	(sp.process_material as ParticleProcessMaterial).color = Color(1.0, 0.8, 0.95)
	return n


static func _mat(col: Color, rough := 0.55, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, nm := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	if nm != "":
		mi.name = nm
	parent.add_child(mi)
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _sphere(r: float, h := -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = 20
	s.rings = 10
	return s


static func _bob(n: Node3D, amp: float, time: float) -> void:
	var y := n.position.y
	var t := n.create_tween().set_loops()
	t.tween_property(n, "position:y", y + amp, time).set_trans(Tween.TRANS_SINE)
	t.tween_property(n, "position:y", y, time).set_trans(Tween.TRANS_SINE)


static func _fossil(n: Node3D) -> void:
	var mound := _mesh(n, _sphere(0.5, 0.42), _mat(Color("8a5a36"), 0.95), Vector3(0.05, 0.0, -0.1), Vector3.ZERO, "Mound")
	mound.scale = Vector3(1.1, 1.0, 0.95)
	for k in 5:
		var a := TAU * k / 5.0 + 0.4
		var r := _mesh(n, _sphere(0.07), _mat(Color("6d4a30"), 1.0), Vector3(cos(a) * 0.52, 0.02, sin(a) * 0.45 - 0.1))
		r.scale = Vector3(1.0, 0.6, 1.0)
	var bone := Props.put(n, Props.HAL + "bone_A.gltf", Vector3(-0.12, 0.2, 0.08), 35.0, 1.0)
	bone.name = "Bone"
	bone.rotation.z = deg_to_rad(-18.0)
	var skull := Props.put(n, Props.HAL + "skull.gltf", Vector3(0.36, 0.1, 0.25), -30.0, 0.34)
	skull.name = "Skull"
	var shovel := Props.put(n, Props.TOOLS + "shovel.gltf", Vector3(0.28, 0.08, -0.3), -60.0, 1.0)
	shovel.name = "Shovel"
	shovel.rotation.x = deg_to_rad(-12.0)
	shovel.rotation.z = deg_to_rad(16.0)
	# a glinting gem half out of the dirt (the dig's treasures), when the pack is installed
	if ResourceLoader.exists(Props.K + "resources/Gem_Medium.gltf"):
		var gem := Props.put(n, Props.K + "resources/Gem_Medium.gltf", Vector3(-0.38, 0.05, 0.3), 20.0, 0.9)
		gem.name = "Gem"
		gem.rotation.z = deg_to_rad(25.0)


static func _bubbles(n: Node3D) -> void:
	var cols: Array = MgLogic.BUBBLE_COLORS
	var spots := [Vector3(-0.3, 0.24, 0.05), Vector3(0.1, 0.24, -0.22), Vector3(0.34, 0.2, 0.2), Vector3(-0.05, 0.62, -0.05),
		Vector3(-0.38, 0.52, -0.3), Vector3(0.3, 0.58, -0.28)]
	var sizes := [0.24, 0.24, 0.2, 0.22, 0.16, 0.15]
	for k in spots.size():
		var holder := Node3D.new()
		holder.name = "Bubble%d" % k
		holder.position = spots[k]
		n.add_child(holder)
		var col: Color = cols[k % cols.size()]
		var m := _mat(col, 0.12, 0.0, 0.25)
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		m.rim_enabled = true
		m.rim = 0.6
		_mesh(holder, _sphere(sizes[k]), m, Vector3.ZERO)
		_mesh(holder, _sphere(sizes[k] * 0.28), _mat(Color(1, 1, 1), 0.1, 0.0, 1.2),
			Vector3(-sizes[k] * 0.4, sizes[k] * 0.5, sizes[k] * 0.55))
		_bob(holder, 0.05 + 0.02 * (k % 2), 0.9 + 0.13 * k)


static func _scratch(n: Node3D) -> void:
	var card := Node3D.new()
	card.name = "Card"
	card.position = Vector3(-0.05, 0.5, -0.12)
	card.rotation = Vector3(deg_to_rad(-14.0), deg_to_rad(10.0), deg_to_rad(-4.0))
	card.scale = Vector3.ONE * 1.12
	n.add_child(card)
	_mesh(card, _box(Vector3(0.96, 0.8, 0.04)), _mat(Color("fff1d6"), 0.6), Vector3.ZERO, Vector3.ZERO, "Paper")
	_mesh(card, _box(Vector3(0.9, 0.16, 0.05)), _mat(Color("7a2fbf"), 0.4, 0.0, 0.2), Vector3(0, 0.27, 0.005))
	_mesh(card, _box(Vector3(0.5, 0.05, 0.055)), _mat(Color("ffd24a"), 0.3, 0.6, 0.4), Vector3(0, 0.27, 0.01))
	for k in 6:
		var x := -0.29 + (k % 3) * 0.29
		var y := 0.05 - (k / 3) * 0.24
		var foil := k != 1 and k != 5
		var m := _mat(Color("c9d0de") if foil else Color("fffaf0"), 0.25 if foil else 0.8, 0.75 if foil else 0.0)
		_mesh(card, _box(Vector3(0.24, 0.19, 0.05)), m, Vector3(x, y, 0.005))
	# a revealed 6 and a die at the foot
	var d := Props.put(n, Props.BGB + "D6_A.gltf", Vector3(0.45, 0.0, 0.38), 25.0, 0.55)
	d.name = "Die"
	var coin := Props.put(n, Props.DUN + "coin.gltf", Vector3(-0.42, 0.0, 0.3), 0.0, 0.9)
	coin.name = "Coin"
	_bob(card, 0.04, 1.3)


static func _claw(n: Node3D) -> void:
	var cab := Node3D.new()
	cab.name = "Cabinet"
	cab.position = Vector3(0.0, 0.0, -0.1)
	cab.rotation.y = deg_to_rad(-12.0)
	cab.scale = Vector3.ONE * 1.25
	n.add_child(cab)
	var pink := _mat(Color("ff5d95"), 0.45)
	_mesh(cab, _box(Vector3(0.72, 0.36, 0.62)), pink, Vector3(0, 0.18, 0), Vector3.ZERO, "Base")
	_mesh(cab, _box(Vector3(0.28, 0.14, 0.04)), _mat(Color("22102e"), 0.8), Vector3(-0.16, 0.2, 0.31))
	_mesh(cab, _box(Vector3(0.08, 0.08, 0.06)), _mat(Color("ff3b5c"), 0.3, 0.0, 0.6), Vector3(0.2, 0.3, 0.3))
	# glass box: four thin metal pillars + a see-through pane
	var metal_dark := _mat(Color("c9cfdc"), 0.3, 0.7)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_mesh(cab, _box(Vector3(0.045, 0.56, 0.045)), metal_dark, Vector3(sx * 0.33, 0.64, sz * 0.28))
	var glass := _mat(Color(0.7, 0.9, 1.0, 0.26), 0.05, 0.0, 0.15)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh(cab, _box(Vector3(0.66, 0.56, 0.56)), glass, Vector3(0, 0.64, 0), Vector3.ZERO, "Glass")
	# marquee: a glowing sign band all around under a pink cap, with bulbs
	_mesh(cab, _box(Vector3(0.74, 0.14, 0.64)), _mat(Color("ffd84a"), 0.3, 0.0, 1.1), Vector3(0, 0.99, 0), Vector3.ZERO, "Marquee")
	_mesh(cab, _box(Vector3(0.8, 0.07, 0.7)), pink, Vector3(0, 1.09, 0))
	for k in 5:
		for sz in [-1.0, 1.0]:
			_mesh(cab, _sphere(0.022), _mat(Color("fff6c0"), 0.2, 0.0, 2.2), Vector3(-0.3 + k * 0.15, 0.99, sz * 0.325))
	# prize + claw inside
	var star := Props.put(cab, Props.PLAT + "yellow/star_yellow.gltf", Vector3(0.08, 0.38, 0.02), 0.0, 0.3)
	star.name = "Prize"
	var claw := Node3D.new()
	claw.name = "Claw"
	claw.position = Vector3(-0.08, 0.8, 0.0)
	cab.add_child(claw)
	var metal := _mat(Color("d6dcea"), 0.3, 0.8)
	_mesh(claw, CylinderMesh.new(), metal, Vector3(0, 0.06, 0)).scale = Vector3(0.03, 0.08, 0.03)
	_mesh(claw, _sphere(0.045), _mat(Color("ffc93d"), 0.3, 0.5), Vector3.ZERO)
	for k in 3:
		var a := TAU * k / 3.0
		var prong := _mesh(claw, _box(Vector3(0.02, 0.12, 0.02)), metal, Vector3(cos(a) * 0.04, -0.06, sin(a) * 0.04))
		prong.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
	var t := claw.create_tween().set_loops()
	t.tween_property(claw, "position:x", 0.16, 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_property(claw, "position:x", -0.16, 1.2).set_trans(Tween.TRANS_SINE)

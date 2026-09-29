class_name ShooterProp
extends RefCounted
## Board-tile prop for bubble_shooter: a round periwinkle bubble cannon with googly eyes on a
## little deck, its nozzle tipped up with a bubble loaded, two bubbles already flying off in an
## arc (bobbing), and the gem chest prize it is aiming for. Built into `n` in the minigame tile
## style (fit ~1.4 x 1.4, y = tile top); MinigameProps adds the sparkle.


static func build(root: Node3D) -> void:
	var n := Node3D.new()
	n.name = "Shooter"
	n.scale = Vector3.ONE * 1.12
	root.add_child(n)
	var gc: Color = MgLogic.GAME_COLORS.get("bubble_shooter", Color("7f8cff"))
	var cols: Array = MgLogic.BUBBLE_COLORS
	# the deck
	var deck := CylinderMesh.new()
	deck.top_radius = 0.46
	deck.bottom_radius = 0.5
	deck.height = 0.12
	MinigameProps._mesh(n, deck, MinigameProps._mat(Color("2a2f6e"), 0.6), Vector3(0.12, 0.06, 0.18), Vector3.ZERO, "Deck")
	var rim := TorusMesh.new()
	rim.inner_radius = 0.43
	rim.outer_radius = 0.5
	MinigameProps._mesh(n, rim, MinigameProps._mat(Color("ffd84a"), 0.3, 0.5, 0.2), Vector3(0.12, 0.12, 0.18))
	# the cannon critter
	var cannon := Node3D.new()
	cannon.name = "Cannon"
	cannon.position = Vector3(0.12, 0.12, 0.18)
	n.add_child(cannon)
	var body := MinigameProps._mesh(cannon, MinigameProps._sphere(0.3), MinigameProps._mat(gc, 0.35, 0.0, 0.1), Vector3(0, 0.26, 0), Vector3.ZERO, "Body")
	body.scale = Vector3(1.0, 0.86, 1.0)
	for s in [-1.0, 1.0]:
		MinigameProps._mesh(cannon, MinigameProps._sphere(0.08), MinigameProps._mat(Color.WHITE, 0.3), Vector3(s * 0.12, 0.33, 0.22))
		MinigameProps._mesh(cannon, MinigameProps._sphere(0.042), MinigameProps._mat(Color("1b1530"), 0.3), Vector3(s * 0.11, 0.35, 0.29))
		MinigameProps._mesh(cannon, MinigameProps._sphere(0.04), MinigameProps._mat(Color("ff8fb0"), 0.6), Vector3(s * 0.22, 0.24, 0.2))
	# nozzle tipped up and forward-right, a bubble loaded in its mouth
	var nozzle := Node3D.new()
	nozzle.name = "Nozzle"
	nozzle.position = Vector3(-0.04, 0.4, -0.06)
	nozzle.rotation = Vector3(deg_to_rad(-14.0), 0, deg_to_rad(44.0))
	cannon.add_child(nozzle)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.13
	tube.bottom_radius = 0.11
	tube.height = 0.42
	MinigameProps._mesh(nozzle, tube, MinigameProps._mat(Color("d9def5"), 0.3, 0.4), Vector3(0, 0.12, 0))
	var lip := TorusMesh.new()
	lip.inner_radius = 0.1
	lip.outer_radius = 0.16
	MinigameProps._mesh(nozzle, lip, MinigameProps._mat(Color("ffd84a"), 0.3, 0.5, 0.25), Vector3(0, 0.3, 0))
	_bubble(nozzle, 0.12, cols[0], Vector3(0, 0.36, 0))
	var t := cannon.create_tween().set_loops()
	t.tween_property(cannon, "scale", Vector3(1.04, 0.95, 1.04), 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(cannon, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	# two bubbles in flight along the arc (dotted trail between)
	var fly := [[Vector3(-0.36, 0.88, 0.02), 1, 0.12], [Vector3(-0.58, 0.8, 0.06), 2, 0.11]]
	for k in fly.size():
		var h := Node3D.new()
		h.name = "Flying%d" % k
		h.position = fly[k][0]
		n.add_child(h)
		_bubble(h, float(fly[k][2]), cols[int(fly[k][1])], Vector3.ZERO)
		MinigameProps._bob(h, 0.05, 0.8 + 0.2 * k)
	for k in 3:
		var p := Vector3(-0.2 - 0.05 * k, 0.8 + 0.03 * k, 0.04)
		MinigameProps._mesh(n, MinigameProps._sphere(0.022), MinigameProps._mat(Color("fff3c0"), 0.2, 0.0, 1.2), p)
	# the prize: a gem chest behind, a spare bubble resting on the deck
	if ResourceLoader.exists(Props.K + "resources/Gems_Chest.gltf"):
		var chest := Props.put(n, Props.K + "resources/Gems_Chest.gltf", Vector3(-0.36, 0.0, -0.3), 30.0, 0.3)
		chest.name = "Chest"
	_bubble(n, 0.1, cols[3], Vector3(0.5, 0.1, 0.52))
	_bubble(n, 0.09, cols[1], Vector3(0.62, 0.09, 0.34))


static func _bubble(parent: Node3D, r: float, col: Color, pos: Vector3) -> void:
	var m := MinigameProps._mat(col, 0.12, 0.0, 0.25)
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.rim_enabled = true
	m.rim = 0.6
	MinigameProps._mesh(parent, MinigameProps._sphere(r), m, pos)
	MinigameProps._mesh(parent, MinigameProps._sphere(r * 0.28), MinigameProps._mat(Color.WHITE, 0.1, 0.0, 1.2), pos + Vector3(-r * 0.4, r * 0.5, r * 0.55))

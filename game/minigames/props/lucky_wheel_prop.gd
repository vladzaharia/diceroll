class_name WheelProp
extends RefCounted
## Board-tile prop for lucky_wheel: a little carnival prize wheel on a striped post. Twelve
## bright wedges (a vertex-coloured fan) under a gold rim studded with glowing bulbs, a gold
## hub, a red flapper on top, on a round crimson base with a coin pile and a gem at its foot.
## The wheel turns slowly, now and then giving a quick spin that eases to a stop.
## Built into `n` in the minigame tile style (fit ~1.4 x 1.4, y = tile top).

const COLS := [Color("ff4b5c"), Color("3aa0ff"), Color("ffc83a"), Color("a468ff"), Color("ff8a3d"), Color("34c77b")]
const R := 0.36


static func build(n: Node3D) -> void:
	var crimson := MinigameProps._mat(Color("b8243f"), 0.45)
	var gold := MinigameProps._mat(Color("ffc93d"), 0.3, 0.6, 0.15)
	# round base + post
	var base := CylinderMesh.new()
	base.top_radius = 0.26
	base.bottom_radius = 0.31
	base.height = 0.1
	MinigameProps._mesh(n, base, crimson, Vector3(0, 0.05, 0), Vector3.ZERO, "Base")
	var trim := CylinderMesh.new()
	trim.top_radius = 0.19
	trim.bottom_radius = 0.26
	trim.height = 0.04
	MinigameProps._mesh(n, trim, gold, Vector3(0, 0.12, 0))
	var post := CylinderMesh.new()
	post.top_radius = 0.045
	post.bottom_radius = 0.06
	post.height = 0.5
	MinigameProps._mesh(n, post, MinigameProps._mat(Color("f4ecff"), 0.5), Vector3(0, 0.38, -0.02), Vector3.ZERO, "Post")
	for k in 3:
		var band := CylinderMesh.new()
		band.top_radius = 0.058
		band.bottom_radius = 0.058
		band.height = 0.05
		MinigameProps._mesh(n, band, crimson, Vector3(0, 0.22 + k * 0.14, -0.02))
	# the wheel, facing the camera (+z), tipped back a touch
	var hold := Node3D.new()
	hold.name = "WheelHolder"
	hold.position = Vector3(0, 0.68, 0.04)
	hold.rotation.x = deg_to_rad(-22.0)
	n.add_child(hold)
	var wheel := Node3D.new()
	wheel.name = "Wheel"
	hold.add_child(wheel)
	var face := MeshInstance3D.new()
	face.name = "Face"
	face.mesh = _fan_mesh()
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.vertex_color_is_srgb = true
	fm.roughness = 0.4
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.emission_enabled = true
	fm.emission = Color(0.2, 0.14, 0.14)
	face.material_override = fm
	wheel.add_child(face)
	# back plate
	var back := CylinderMesh.new()
	back.top_radius = R
	back.bottom_radius = R
	back.height = 0.05
	back.radial_segments = 36
	MinigameProps._mesh(wheel, back, MinigameProps._mat(Color("6a1e30"), 0.6), Vector3(0, 0, -0.03), Vector3(PI * 0.5, 0, 0))
	# gold dividers (thin boxes) and pegs
	for k in 12:
		var a := TAU * k / 12.0
		var dv := MinigameProps._mesh(wheel, MinigameProps._box(Vector3(0.012, R * 0.86, 0.012)), gold,
			Vector3(cos(a), sin(a), 0) * R * 0.52 + Vector3(0, 0, 0.012), Vector3(0, 0, a - PI * 0.5))
		dv.name = "Divider%d" % k
		MinigameProps._mesh(wheel, MinigameProps._sphere(0.018), MinigameProps._mat(Color("f0f2fa"), 0.25, 0.4),
			Vector3(cos(a), sin(a), 0) * R * 0.93 + Vector3(0, 0, 0.02))
	# hub
	var hub := CylinderMesh.new()
	hub.top_radius = 0.075
	hub.bottom_radius = 0.085
	hub.height = 0.05
	MinigameProps._mesh(wheel, hub, gold, Vector3(0, 0, 0.03), Vector3(PI * 0.5, 0, 0), "Hub")
	MinigameProps._mesh(wheel, MinigameProps._sphere(0.04), MinigameProps._mat(Color("ff4b5c"), 0.3, 0.0, 0.3), Vector3(0, 0, 0.06))
	# the rim (stationary): a gold torus with bulbs
	var rim := TorusMesh.new()
	rim.inner_radius = R * 0.97
	rim.outer_radius = R * 1.1
	rim.rings = 36
	rim.ring_segments = 10
	MinigameProps._mesh(hold, rim, crimson, Vector3.ZERO, Vector3(PI * 0.5, 0, 0), "Rim")
	var bulb_on := MinigameProps._mat(Color("fff2a0"), 0.2, 0.0, 2.2)
	var bulb_off := MinigameProps._mat(Color("ffb070"), 0.3, 0.0, 0.6)
	for k in 16:
		var a := TAU * k / 16.0
		MinigameProps._mesh(hold, MinigameProps._sphere(0.024), bulb_on if k % 2 == 0 else bulb_off,
			Vector3(cos(a), sin(a), 0) * R * 1.035 + Vector3(0, 0, 0.035), Vector3.ZERO, "Bulb%d" % k)
	# the flapper on top
	var flap := Node3D.new()
	flap.name = "Flapper"
	flap.position = Vector3(0, R * 1.2, 0.08)
	hold.add_child(flap)
	var prism := PrismMesh.new()
	prism.size = Vector3(0.13, 0.17, 0.05)
	MinigameProps._mesh(flap, prism, MinigameProps._mat(Color("e8384f"), 0.35, 0.0, 0.2), Vector3(0, -0.05, 0), Vector3(0, 0, PI), "Pointer")
	MinigameProps._mesh(flap, MinigameProps._sphere(0.032), gold, Vector3(0, 0.02, 0.01))
	# treasure at the foot
	var coins := ModelIcons.K + "resources/Money_Coins_Stack_Medium.gltf"
	if ResourceLoader.exists(coins):
		var c := Props.put(n, coins, Vector3(0.36, 0.0, 0.3), 20.0, 0.45)
		c.name = "Coins"
	var gem := ModelIcons.K + "resources/Gem_Small.gltf"
	if ResourceLoader.exists(gem):
		var g := Props.put(n, gem, Vector3(-0.36, 0.0, 0.28), -30.0, 0.9)
		g.name = "Gem"
	# idle: a slow turn, and every few seconds a quick spin easing to a stop (the flapper wags)
	var t := wheel.create_tween().set_loops()
	t.tween_property(wheel, "rotation:z", -TAU * 0.25, 3.0).as_relative().set_trans(Tween.TRANS_LINEAR)
	t.tween_property(wheel, "rotation:z", -TAU * 2.4, 2.6).as_relative().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.6)
	var ft := flap.create_tween().set_loops()
	ft.tween_property(flap, "rotation:z", 0.25, 0.08)
	ft.tween_property(flap, "rotation:z", 0.0, 0.14)
	ft.tween_interval(0.3)


## The wheel face: a fan of 12 vertex-coloured wedges (+z facing), the jackpot one dark.
static func _fan_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3(0, 0, 1))
	var steps := 4
	for k in 12:
		var col: Color = Color("2a1145") if k == 7 else COLS[k % COLS.size()]
		for s in steps:
			var a0 := TAU * (k + float(s) / steps) / 12.0
			var a1 := TAU * (k + float(s + 1) / steps) / 12.0
			var outer := col.lightened(0.15)
			st.set_color(col.darkened(0.2))
			st.add_vertex(Vector3.ZERO)
			st.set_color(outer)
			st.add_vertex(Vector3(cos(a1), sin(a1), 0) * R)
			st.set_color(outer)
			st.add_vertex(Vector3(cos(a0), sin(a0), 0) * R)
	return st.commit()

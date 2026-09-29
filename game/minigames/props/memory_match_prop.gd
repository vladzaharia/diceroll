class_name MemoryProp
extends RefCounted
## Board-tile prop for memory_match: a fan of three oversized playing cards standing on a round
## felt pad with a gold rim. Two show the ornate purple backs (gold frame + medallion), the
## front one is turned face up on a die face (five pips). A little gold star rune floats and
## spins over the fan; a die sits at the foot. The fan sways gently. Built into `n` in the
## minigame tile style (fit ~1.4 x 1.4, y = tile top); MinigameProps adds the sparkle.

const CW := 0.46
const CH := 0.66
const CD := 0.035


static func build(n: Node3D) -> void:
	var col: Color = MgLogic.GAME_COLORS.get("memory_match", Color("b08cff"))
	# the felt pad
	var rim := CylinderMesh.new()
	rim.top_radius = 0.6
	rim.bottom_radius = 0.62
	rim.height = 0.06
	MinigameProps._mesh(n, rim, MinigameProps._mat(Color("e8b547"), 0.3, 0.6), Vector3(0, 0.03, 0), Vector3.ZERO, "Rim")
	var felt := CylinderMesh.new()
	felt.top_radius = 0.54
	felt.bottom_radius = 0.54
	felt.height = 0.07
	MinigameProps._mesh(n, felt, MinigameProps._mat(col.darkened(0.6), 0.95), Vector3(0, 0.04, 0), Vector3.ZERO, "Felt")
	# the fan (pivots at the bottom of the cards)
	var fan := Node3D.new()
	fan.name = "Fan"
	fan.position = Vector3(0.0, 0.08, -0.05)
	fan.rotation.x = deg_to_rad(-12.0)
	n.add_child(fan)
	var spec := [[40.0, Vector3(-0.2, 0, -0.08), false], [15.0, Vector3(-0.06, 0, -0.05), false], [-14.0, Vector3(0.13, 0, 0.0), true]]
	for k in spec.size():
		var holder := Node3D.new()
		holder.name = "Card%d" % k
		holder.position = spec[k][1]
		holder.rotation.z = deg_to_rad(float(spec[k][0]))
		fan.add_child(holder)
		if bool(spec[k][2]):
			_face_card(holder)
		else:
			_back_card(holder, col)
	var sway := fan.create_tween().set_loops()
	sway.tween_property(fan, "rotation:y", deg_to_rad(9.0), 1.6).set_trans(Tween.TRANS_SINE)
	sway.tween_property(fan, "rotation:y", deg_to_rad(-9.0), 1.6).set_trans(Tween.TRANS_SINE)
	# a floating star rune
	var star_path := Props.K + "platformer/yellow/star_yellow.gltf"
	var star_holder := Node3D.new()
	star_holder.name = "Star"
	star_holder.position = Vector3(0.44, 0.84, -0.22)
	n.add_child(star_holder)
	if ResourceLoader.exists(star_path):
		Props.put(star_holder, star_path, Vector3.ZERO, 0.0, 0.24)
	else:
		MinigameProps._mesh(star_holder, MinigameProps._sphere(0.08), MinigameProps._mat(Color("ffd84a"), 0.3, 0.3, 0.8), Vector3.ZERO)
	MinigameProps._bob(star_holder, 0.06, 1.1)
	var spin := star_holder.create_tween().set_loops()
	spin.tween_property(star_holder, "rotation:y", TAU, 3.0).from(0.0)
	# a die at the foot
	var d := Props.put(n, Props.BGB + "D6_A.gltf", Vector3(0.4, 0.07, 0.32), -20.0, 0.3)
	d.name = "Die"


static func _card_body(h: Node3D, front: Color, nm: String, emit := 0.0) -> Node3D:
	var card := Node3D.new()
	card.name = nm
	card.position = Vector3(0, CH * 0.5, 0)
	h.add_child(card)
	# a dark outline shell, then the card itself
	MinigameProps._mesh(card, MinigameProps._box(Vector3(CW + 0.03, CH + 0.03, CD * 0.8)), MinigameProps._mat(Color("1b1530"), 0.8), Vector3(0, 0, -0.004))
	MinigameProps._mesh(card, MinigameProps._box(Vector3(CW, CH, CD)), MinigameProps._mat(front, 0.5, 0.0, emit), Vector3.ZERO)
	return card


static func _back_card(h: Node3D, col: Color) -> void:
	var card := _card_body(h, col.darkened(0.25), "Back")
	var z := CD * 0.5
	MinigameProps._mesh(card, MinigameProps._box(Vector3(CW * 0.84, CH * 0.88, 0.006)), MinigameProps._mat(Color("ffd24a"), 0.3, 0.6, 0.15), Vector3(0, 0, z + 0.002))
	MinigameProps._mesh(card, MinigameProps._box(Vector3(CW * 0.78, CH * 0.83, 0.006)), MinigameProps._mat(col, 0.5), Vector3(0, 0, z + 0.005))
	# the medallion
	var disc := CylinderMesh.new()
	disc.top_radius = CW * 0.24
	disc.bottom_radius = CW * 0.24
	disc.height = 0.012
	MinigameProps._mesh(card, disc, MinigameProps._mat(Color("ffd24a"), 0.3, 0.7, 0.2), Vector3(0, 0, z + 0.009), Vector3(PI * 0.5, 0, 0))
	var inner := CylinderMesh.new()
	inner.top_radius = CW * 0.18
	inner.bottom_radius = CW * 0.18
	inner.height = 0.014
	MinigameProps._mesh(card, inner, MinigameProps._mat(col.darkened(0.55), 0.6), Vector3(0, 0, z + 0.011), Vector3(PI * 0.5, 0, 0))
	var star := MinigameProps._mesh(card, MinigameProps._box(Vector3(0.05, 0.05, 0.01)), MinigameProps._mat(Color("fff0b0"), 0.3, 0.2, 0.9), Vector3(0, 0, z + 0.019))
	star.rotation.z = PI * 0.25


static func _face_card(h: Node3D) -> void:
	var card := _card_body(h, Color("fff6e3"), "Face", 0.25)
	var z := CD * 0.5
	MinigameProps._mesh(card, MinigameProps._box(Vector3(CW * 0.84, CH * 0.88, 0.004)), MinigameProps._mat(Color("c9a8ff"), 0.6), Vector3(0, 0, z + 0.001))
	MinigameProps._mesh(card, MinigameProps._box(Vector3(CW * 0.8, CH * 0.85, 0.006)), MinigameProps._mat(Color("fff6e3"), 0.6, 0.0, 0.25), Vector3(0, 0, z + 0.003))
	# a die face: a rounded ivory tile with five pips
	MinigameProps._mesh(card, MinigameProps._box(Vector3(CW * 0.62, CW * 0.62, 0.02)), MinigameProps._mat(Color("1b1530"), 0.8), Vector3(0, 0, z + 0.008))
	MinigameProps._mesh(card, MinigameProps._box(Vector3(CW * 0.57, CW * 0.57, 0.024)), MinigameProps._mat(Color("fbf1dc"), 0.45), Vector3(0, 0, z + 0.01))
	var pip := MinigameProps._mat(Color("241a3a"), 0.4)
	var o := CW * 0.17
	for p in [Vector2(-o, o), Vector2(o, o), Vector2(0, 0), Vector2(-o, -o), Vector2(o, -o)]:
		var s := MinigameProps._mesh(card, MinigameProps._sphere(0.028), pip, Vector3(p.x, p.y, z + 0.022))
		s.scale = Vector3(1, 1, 0.45)

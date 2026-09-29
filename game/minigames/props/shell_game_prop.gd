class_name ShellProp
extends RefCounted
## Board-tile prop for shell_game: a little round hustler's table (green felt top, wooden rim and
## pedestal) with three copper cups; the front one tips up now and then to show the gem under
## it. A few coins at the foot. Built into `n` in the minigame tile style (fit ~1.4 x 1.4,
## y = tile top); MinigameProps adds the sparkle.

const COPPER := Color("d27a3c")
const BAND := Color("ffd36a")
const TOP_Y := 0.42


static func build(n: Node3D) -> void:
	var M := MinigameProps
	var wood := M._mat(Color("8a5a36"), 0.8)
	var wood_dark := M._mat(Color("5a3620"), 0.85)
	# pedestal table: foot, post, rim, felt
	var foot := CylinderMesh.new()
	foot.top_radius = 0.26
	foot.bottom_radius = 0.34
	foot.height = 0.08
	M._mesh(n, foot, wood_dark, Vector3(0, 0.04, 0), Vector3.ZERO, "Foot")
	var post := CylinderMesh.new()
	post.top_radius = 0.09
	post.bottom_radius = 0.12
	post.height = TOP_Y - 0.08
	M._mesh(n, post, wood, Vector3(0, 0.08 + post.height * 0.5, 0), Vector3.ZERO, "Post")
	var rim := CylinderMesh.new()
	rim.top_radius = 0.66
	rim.bottom_radius = 0.6
	rim.height = 0.09
	rim.radial_segments = 32
	M._mesh(n, rim, wood, Vector3(0, TOP_Y, 0), Vector3.ZERO, "Top")
	var felt := CylinderMesh.new()
	felt.top_radius = 0.58
	felt.bottom_radius = 0.58
	felt.height = 0.02
	felt.radial_segments = 32
	M._mesh(n, felt, M._mat(Color("1f7a5a"), 0.95), Vector3(0, TOP_Y + 0.04, 0), Vector3.ZERO, "Felt")
	# gold studs round the rim
	var gold := M._mat(Color("ffc93d"), 0.3, 0.6, 0.2)
	for k in 10:
		var a := TAU * k / 10.0
		M._mesh(n, M._sphere(0.028), gold, Vector3(cos(a) * 0.64, TOP_Y, sin(a) * 0.64))
	var surf := TOP_Y + 0.05
	# the gem, peeking from under the tipped front cup
	var gem_path := Props.K + "resources/Gem_Medium.gltf"
	var gem_at := Vector3(0.02, surf, 0.3)
	if ResourceLoader.exists(gem_path):
		var gem := Props.put(n, gem_path, gem_at, 20.0, 0.7)
		gem.name = "Gem"
		var spin := gem.create_tween().set_loops()
		spin.tween_property(gem, "rotation:y", gem.rotation.y + TAU, 4.0).from(gem.rotation.y)
	else:
		var g := M._mesh(n, M._sphere(0.07), M._mat(Color("ff7ad0"), 0.1, 0.0, 0.8), gem_at + Vector3(0, 0.06, 0), Vector3.ZERO, "Gem")
		g.scale = Vector3(1, 1.3, 1)
	# three cups: two resting at the back, one tipped up over the gem
	_cup(n, Vector3(-0.3, surf, -0.12), 0.0, "CupL")
	_cup(n, Vector3(0.3, surf, -0.14), 0.0, "CupR")
	var tip := Node3D.new()
	tip.name = "CupTip"
	# hinge at the cup's back edge so it tips up to the rear, opening toward the camera
	tip.position = Vector3(0.02, surf, 0.26 - 0.17)
	n.add_child(tip)
	_cup(tip, Vector3(0, 0, 0.17), 0.0, "Cup")
	tip.rotation.x = deg_to_rad(-34.0)
	var t := tip.create_tween().set_loops()
	t.tween_property(tip, "rotation:x", deg_to_rad(-46.0), 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(tip, "rotation:x", deg_to_rad(-28.0), 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.8)
	# coins at the foot
	for k in 3:
		var c := Props.put(n, Props.DUN + "coin.gltf", Vector3(0.5 + 0.04 * k, 0.02 + 0.03 * k, 0.4 - 0.02 * k), 40.0 * k, 0.4)
		c.name = "Coin%d" % k


## One copper cup (mouth down) with its bottom centre at `at` under `parent`.
static func _cup(parent: Node3D, at: Vector3, yaw: float, nm: String) -> Node3D:
	var M := MinigameProps
	var cup := Node3D.new()
	cup.name = nm
	cup.position = at
	cup.rotation.y = yaw
	parent.add_child(cup)
	var body := CylinderMesh.new()
	body.bottom_radius = 0.17
	body.top_radius = 0.11
	body.height = 0.32
	body.radial_segments = 24
	var copper := M._mat(COPPER, 0.35, 0.45)
	M._mesh(cup, body, copper, Vector3(0, 0.16, 0), Vector3.ZERO, "Body")
	var band := CylinderMesh.new()
	band.bottom_radius = 0.146
	band.top_radius = 0.136
	band.height = 0.045
	band.radial_segments = 24
	M._mesh(cup, band, M._mat(BAND, 0.3, 0.6, 0.15), Vector3(0, 0.16, 0), Vector3.ZERO, "Band")
	var lip := CylinderMesh.new()
	lip.bottom_radius = 0.18
	lip.top_radius = 0.176
	lip.height = 0.04
	lip.radial_segments = 24
	M._mesh(cup, lip, M._mat(COPPER.darkened(0.25), 0.4, 0.4), Vector3(0, 0.02, 0), Vector3.ZERO, "Lip")
	M._mesh(cup, M._sphere(0.05), M._mat(BAND, 0.3, 0.6, 0.1), Vector3(0, 0.34, 0), Vector3.ZERO, "Knob")
	return cup

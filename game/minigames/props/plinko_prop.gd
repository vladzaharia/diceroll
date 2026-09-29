class_name PlinkoProp
extends RefCounted
## Board-tile prop for plinko: a little upright plinko cabinet (teal frame, navy face, glowing
## mint pegs with one golden peg, a row of coloured prize buckets, a lit marquee) on a stand,
## a die-ball bouncing down the pegs on a loop, and a coin pile + gem spilled at its foot.
## Built into `n` in the minigame tile style (fit ~1.4 x 1.4, y = tile top); MinigameProps
## adds the sparkle.

const TEAL := Color("4fd8b4")
const BUCKETS := [Color("5ab8ff"), Color("8fd85a"), Color("ffc93d"), Color("c98cff"), Color("ff6fb0")]
const ROWS := 5
const DX := 0.15
const DY := 0.12
const TOP := 1.0


static func build(n: Node3D) -> void:
	var cab := Node3D.new()
	cab.name = "Cabinet"
	cab.position = Vector3(0.0, 0.0, -0.08)
	cab.rotation = Vector3(deg_to_rad(-6.0), deg_to_rad(-14.0), 0.0)
	cab.scale = Vector3.ONE * 1.02
	n.add_child(cab)
	var teal := MinigameProps._mat(TEAL, 0.4)
	var teal_dark := MinigameProps._mat(TEAL.darkened(0.35), 0.5)
	# stand: a base with two little feet
	MinigameProps._mesh(cab, MinigameProps._box(Vector3(0.96, 0.1, 0.36)), teal_dark, Vector3(0, 0.05, 0.04), Vector3.ZERO, "Base")
	for sx in [-1.0, 1.0]:
		MinigameProps._mesh(cab, MinigameProps._box(Vector3(0.14, 0.06, 0.44)), teal, Vector3(sx * 0.38, 0.03, 0.04))
	# the board: navy face inside a teal frame
	var face := MinigameProps._mat(Color("13233d"), 0.7, 0.0, 0.15)
	MinigameProps._mesh(cab, MinigameProps._box(Vector3(0.84, 1.0, 0.06)), face, Vector3(0, 0.6, -0.03), Vector3.ZERO, "Face")
	for sx in [-1.0, 1.0]:
		MinigameProps._mesh(cab, MinigameProps._box(Vector3(0.07, 1.06, 0.14)), teal, Vector3(sx * 0.45, 0.6, 0.0))
	# marquee: a glowing sign with bulbs under a teal cap
	MinigameProps._mesh(cab, MinigameProps._box(Vector3(0.97, 0.14, 0.16)), MinigameProps._mat(Color("ffd84a"), 0.3, 0.0, 1.0),
		Vector3(0, 1.17, 0.0), Vector3.ZERO, "Marquee")
	MinigameProps._mesh(cab, MinigameProps._box(Vector3(1.02, 0.05, 0.2)), teal, Vector3(0, 1.265, 0.0))
	for k in 6:
		MinigameProps._mesh(cab, MinigameProps._sphere(0.022), MinigameProps._mat(Color("fff6c0"), 0.2, 0.0, 2.2),
			Vector3(-0.36 + k * 0.144, 1.17, 0.085))
	# pegs: rows alternating offsets, one golden
	var peg := MinigameProps._mat(Color("bff8ea"), 0.25, 0.0, 1.1)
	var gold := MinigameProps._mat(Color("ffd23d"), 0.2, 0.4, 1.6)
	for r in ROWS:
		var cnt := 5 if r % 2 == 0 else 4
		for i in cnt:
			var x := (i - (cnt - 1) * 0.5) * DX
			var is_gold := r == 2 and i == 3
			var mi := MinigameProps._mesh(cab, MinigameProps._sphere(0.036 if is_gold else 0.026), gold if is_gold else peg,
				Vector3(x, TOP - r * DY, 0.025))
			if is_gold:
				mi.name = "GoldenPeg"
	# buckets: coloured cups with dividers at the bottom of the board
	for b in 5:
		var x := (b - 2) * DX
		var col: Color = BUCKETS[b]
		MinigameProps._mesh(cab, MinigameProps._box(Vector3(DX - 0.025, 0.14, 0.1)), MinigameProps._mat(col.darkened(0.05), 0.35, 0.0, 0.12),
			Vector3(x, 0.2, 0.03), Vector3.ZERO, "Bucket%d" % b)
		MinigameProps._mesh(cab, MinigameProps._box(Vector3(DX - 0.02, 0.025, 0.11)), MinigameProps._mat(col.lightened(0.5), 0.3, 0.0, 0.6),
			Vector3(x, 0.28, 0.03))
	for b in 4:
		MinigameProps._mesh(cab, MinigameProps._box(Vector3(0.018, 0.2, 0.08)), MinigameProps._mat(Color("dffcf4"), 0.3, 0.2),
			Vector3((b - 1.5) * DX, 0.27, 0.035))
	# the die-ball bouncing down the pegs
	var ball := Node3D.new()
	ball.name = "Ball"
	cab.add_child(ball)
	var die := Props.put(ball, Props.BGB + "D6_A.gltf", Vector3.ZERO, 0.0, 0.16)
	die.position = Vector3(0, -0.036, 0)
	_bounce(ball)
	# spilled prizes at the foot
	if ResourceLoader.exists(Props.K + "resources/Money_Pile_Small.gltf"):
		var pile := Props.put(n, Props.K + "resources/Money_Pile_Small.gltf", Vector3(0.44, 0.0, 0.4), -20.0, 0.5)
		pile.name = "Coins"
	if ResourceLoader.exists(Props.K + "resources/Gem_Small.gltf"):
		var gem := Props.put(n, Props.K + "resources/Gem_Small.gltf", Vector3(-0.42, 0.0, 0.38), 30.0, 0.8)
		gem.name = "Gem"
		gem.rotation.z = deg_to_rad(20.0)


## A looping zig-zag down the peg rows (short hops with a tumble), a drop into a bucket,
## then back to the top.
static func _bounce(ball: Node3D) -> void:
	var zs := 0.07
	var xs := [0.0, 0.075, 0.0, 0.075, 0.15, 0.075]
	var pts: Array = [Vector3(0.0, TOP + 0.1, zs)]
	for r in ROWS:
		pts.append(Vector3(xs[r], TOP - r * DY + 0.055, zs))
	pts.append(Vector3(0.15, 0.3, zs))
	ball.position = pts[0]
	var t := ball.create_tween().set_loops()
	t.tween_property(ball, "position", pts[0], 0.01).from(pts[0])
	t.tween_property(ball, "scale", Vector3.ONE, 0.2).from(Vector3.ZERO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var hop := 0.05 if i > 1 else 0.0
		t.tween_method(func(k: float) -> void:
			ball.position = a.lerp(b, k) + Vector3(0, hop * 4.0 * k * (1.0 - k), 0)
			ball.rotation.z = -(i - 1 + k) * PI * 0.5, 0.0, 1.0, 0.22 if i < pts.size() - 1 else 0.3)
	t.tween_interval(0.35)
	t.tween_property(ball, "scale", Vector3.ZERO, 0.15)
	t.tween_interval(0.6)

class_name LadderProp
extends RefCounted
## Board-tile prop for high_low: a little prize ladder standing on the tile, its safety rungs
## blue, a gem chest glinting on the top platform, a yellow pawn part way up (bobbing, as if
## mid-climb), a big die at its foot rocking to and fro and a coin stack beside it. Built into
## `n` in the minigame tile style (fit ~1.4 x 1.4, y = tile top); MinigameProps adds the sparkle.


static func build(n: Node3D) -> void:
	var lad := Node3D.new()
	lad.name = "Ladder"
	lad.position = Vector3(-0.05, 0.0, -0.12)
	lad.rotation = Vector3(deg_to_rad(-9.0), deg_to_rad(12.0), 0.0)
	n.add_child(lad)
	var wood := MinigameProps._mat(Color("b9824a"), 0.75)
	var rail := MinigameProps._mat(Color("8a5a30"), 0.8)
	var h := 0.9
	for sx in [-1.0, 1.0]:
		MinigameProps._mesh(lad, MinigameProps._box(Vector3(0.1, h, 0.1)), rail, Vector3(sx * 0.3, h * 0.5, 0.0))
	var safe := MinigameProps._mat(Color("5f8fc8"), 0.55, 0.2, 0.15)
	for k in 4:
		var y := 0.13 + k * 0.2
		var is_safe := k == 1 or k == 3
		MinigameProps._mesh(lad, MinigameProps._box(Vector3(0.62, 0.07, 0.12)), safe if is_safe else wood, Vector3(0, y, 0.0), Vector3.ZERO, "Rung%d" % k)
	# the top platform and the prize on it
	MinigameProps._mesh(lad, MinigameProps._box(Vector3(0.78, 0.07, 0.42)), MinigameProps._mat(Color("e0a93a"), 0.4, 0.4, 0.2), Vector3(0, h + 0.03, -0.06), Vector3.ZERO, "Top")
	var chest_path := Props.K + "resources/Gems_Chest.gltf"
	if ResourceLoader.exists(chest_path):
		var chest := Props.put(lad, chest_path, Vector3(0, h + 0.065, -0.04), -10.0, 0.32)
		chest.name = "Chest"
	else:
		Props.put(lad, Props.DUN + "chest_gold.gltf", Vector3(0, h + 0.065, -0.04), -10.0, 0.3).name = "Chest"
	# the climbing pawn
	var pawn_holder := Node3D.new()
	pawn_holder.name = "Pawn"
	pawn_holder.position = Vector3(0.0, 0.565, 0.02)
	lad.add_child(pawn_holder)
	Props.put(pawn_holder, Props.BGB + "pawn_A_yellow.gltf", Vector3.ZERO, 0.0, 0.42)
	MinigameProps._bob(pawn_holder, 0.06, 0.55)
	# the die at the foot, rocking
	var die_holder := Node3D.new()
	die_holder.name = "Die"
	die_holder.position = Vector3(0.46, 0.0, 0.4)
	n.add_child(die_holder)
	var d := Props.put(die_holder, Props.BGB + "D6_A_green.gltf", Vector3(0, 0.15, 0), 25.0, 0.4)
	d.name = "D6"
	var t := die_holder.create_tween().set_loops()
	t.tween_property(die_holder, "rotation:z", deg_to_rad(6.0), 0.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(die_holder, "rotation:z", deg_to_rad(-6.0), 0.8).set_trans(Tween.TRANS_SINE)
	var coins := Props.put(n, Props.DUN + "coin_stack_small.gltf", Vector3(-0.44, 0.0, 0.36), 30.0, 0.42)
	coins.name = "Coins"

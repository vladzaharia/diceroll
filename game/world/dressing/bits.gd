class_name DressBits
extends RefCounted
## Small reusable vignettes shared by several biomes (bone piles, weapon barrels, ore heaps,
## supply stacks). Each builds under a group node at a local origin (0, 0, 0) facing +z;
## callers position / rotate the group. `tint` (alpha = strength) re-colours atlas props.

const H := Props.HAL
const RES := Dressing.RES
const SKP := Dressing.SKP
const WX := Dressing.WX


static func _p(g: Node3D, path: String, pos: Vector3, yaw: float, k: float, tint := Color(0, 0, 0, 0)) -> Node3D:
	var n := Props.put(g, path, pos, yaw, k)
	if tint.a > 0.0:
		Props.tint(n, Color(tint.r, tint.g, tint.b), tint.a)
	return n


## Skull, ribcage and loose bones with a broken arrow or two. k ~ 0.7..1.
static func bone_pile(g: Node3D, k := 1.0, rng: RandomNumberGenerator = null, tint := Color(0, 0, 0, 0)) -> void:
	var r := rng if rng else Dressing.rng
	_p(g, H + "ribcage.gltf", Vector3(0.0, 0.3 * k, -0.1), r.randf_range(-30, 30), 0.8 * k, tint)
	_p(g, H + "skull.gltf", Vector3(0.45 * k, 0, 0.25 * k), r.randf_range(-40, 40), 0.42 * k, tint)
	_p(g, H + "bone_A.gltf", Vector3(-0.45 * k, 0.1 * k, 0.3 * k), r.randf() * 360.0, 0.8 * k, tint)
	_p(g, H + "bone_C.gltf", Vector3(0.1 * k, 0.1 * k, 0.5 * k), r.randf() * 360.0, 0.7 * k, tint)
	_p(g, H + "bone_B.gltf", Vector3(-0.2 * k, 0.07 * k, -0.55 * k), r.randf() * 360.0, 0.8 * k, tint)
	if r.randf() < 0.7:
		Dressing.stuck(g, SKP + "Skeleton_Arrow_Broken_Half.gltf", Vector3(0.6 * k, 0, -0.3 * k), r.randf() * 360.0, 25.0, k)
	if r.randf() < 0.5:
		Dressing.lying(g, SKP + "Skeleton_Shield_Small_A.gltf", Vector3(-0.6 * k, 0, -0.2 * k), r.randf() * 360.0, 0.7 * k, tint)


## A barrel with spears / swords standing in it and a shield leaning on it.
static func weapon_barrel(g: Node3D, k := 1.0, skeleton := false, tint := Color(0, 0, 0, 0)) -> void:
	_p(g, Props.DUN + "barrel_small.gltf", Vector3.ZERO, 0.0, 0.62 * k)
	var tall := [WX + "spear_A.gltf", WX + "halberd.gltf", WX + "sword_E.gltf"] if not skeleton \
		else [SKP + "Skeleton_Staff.gltf", SKP + "Skeleton_Scythe.gltf", SKP + "Skeleton_Blade.gltf"]
	for i in 3:
		var a := TAU * i / 3.0
		var n := Dressing.stuck(g, tall[i], Vector3(cos(a) * 0.12 * k, 0.9 * k, sin(a) * 0.12 * k), rad_to_deg(a),
			8.0 + 6.0 * i, 0.65 * k, tint)
		n.rotation.z = deg_to_rad(cos(a) * 10.0)
	var sh := Dressing.stuck(g, (SKP + "Skeleton_Shield_Large_A.gltf") if skeleton else (WX + "shield_B.gltf"),
		Vector3(0.0, 0.42 * k, 0.42 * k), 0.0, -18.0, 0.62 * k, tint)
	sh.name = "Shield"


## A rack: two posts and a crossbar with swords / axes hanging point-down, facing +z.
static func weapon_rack(g: Node3D, k := 1.0, set := 0, tint := Color(0, 0, 0, 0)) -> void:
	var wood := Props.flat_material(Color(0.42, 0.28, 0.18))
	for sx in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.12, 1.25, 0.12) * k
		post.mesh = bm
		post.material_override = wood
		post.position = Vector3(sx * 0.75 * k, 0.62 * k, 0)
		g.add_child(post)
	var bar := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.75, 0.1, 0.14) * k
	bar.mesh = bb
	bar.material_override = wood
	bar.position = Vector3(0, 1.2 * k, 0)
	g.add_child(bar)
	var sets := [
		[WX + "sword_A.gltf", WX + "axe_B.gltf", WX + "sword_C.gltf", WX + "hammer_B.gltf"],
		[SKP + "Skeleton_Blade.gltf", SKP + "Skeleton_Axe.gltf", SKP + "Skeleton_Dagger.gltf", SKP + "Skeleton_Mace.gltf"],
		[WX + "sword_D.gltf", WX + "sword_B.gltf", WX + "sword_F.gltf", WX + "dagger_A.gltf"],
	]
	var list: Array = sets[posmod(set, sets.size())]
	for i in list.size():
		var x := (-0.52 + 0.35 * i) * k
		var n := Props.put(g, list[i], Vector3(x, 1.18 * k, 0.1 * k), 0.0, 0.62 * k)
		# hang point-down: flip so the grip rests on the bar
		n.rotation = Vector3(0.0, 0.0, PI)
		if tint.a > 0.0:
			Props.tint(n, Color(tint.r, tint.g, tint.b), tint.a)


## Heap of ore nuggets and bars (metal = "Gold" | "Iron" | "Copper" | "Silver").
static func ore_heap(g: Node3D, metal: String, k := 1.0, tint := Color(0, 0, 0, 0), emission := Color.BLACK) -> void:
	var parts := [[metal + "_Nuggets", Vector3(0, 0, 0), 0.0, 1.0], [metal + "_Nugget_Large", Vector3(0.5, 0, 0.2), 30.0, 1.0],
		[metal + "_Bars_Stack_Small", Vector3(-0.55, 0, -0.2), 20.0, 0.8], [metal + "_Nugget_Medium", Vector3(0.1, 0, 0.5), 0.0, 1.0],
		[metal + "_Bar", Vector3(-0.3, 0, 0.45), 70.0, 0.9]]
	for p in parts:
		var n := _p(g, RES + String(p[0]) + ".gltf", Vector3(p[1]) * k, float(p[2]), float(p[3]) * k)
		if p[0].contains("Nugget_"):
			n.position.y += 0.2 * k * float(p[3])
		if tint.a > 0.0 or emission != Color.BLACK:
			Props.tint(n, Color(tint.r, tint.g, tint.b) if tint.a > 0.0 else Color.WHITE, tint.a, emission)


## Supply stack: crates / sacks / barrels (style 0 wood crates, 1 sacks + pile, 2 kegs).
static func supplies(g: Node3D, style: int, k := 1.0, tint := Color(0, 0, 0, 0)) -> void:
	match posmod(style, 3):
		0:
			_p(g, RES + "Containers_Crate_Large.gltf", Vector3(0, 0, 0), 10.0, 0.8 * k, tint)
			_p(g, RES + "Containers_Box_Large.gltf", Vector3(0.1, 0.84 * k, 0.05), -15.0, 0.8 * k, tint)
			_p(g, RES + "Containers_Crate_Small_Grey.gltf", Vector3(0.95 * k, 0, 0.3 * k), 40.0, 0.9 * k, tint)
		1:
			_p(g, RES + "Containers_Pile_Medium.gltf", Vector3(0, 0, 0), 0.0, 0.75 * k, tint)
			_p(g, RES + "Food_Flour.gltf", Vector3(0.85 * k, 0, 0.25 * k), 20.0, 0.9 * k, tint)
			_p(g, RES + "Containers_Box_Small.gltf", Vector3(-0.8 * k, 0, 0.35 * k), 25.0, 0.9 * k, tint)
		2:
			_p(g, Props.DUN + "barrel_large.gltf", Vector3(0, 0, 0), 0.0, 0.55 * k, tint)
			_p(g, Props.DUN + "barrel_small.gltf", Vector3(0.8 * k, 0, 0.25 * k), 0.0, 0.55 * k, tint)
			_p(g, Props.DUN + "keg.gltf", Vector3(-0.75 * k, 0, 0.35 * k), 90.0, 0.42 * k, tint)

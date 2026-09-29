class_name ModelIcons
extends RefCounted
## 3D KayKit models as 2D icons for the minigame boards (gems, coin pouches, claw prizes):
## each model renders once into its own small transparent SubViewport (own world, soft key
## light + rim), and the ViewportTexture is drawn like any texture. Cached per path.
##
##   var tex := ModelIcons.get_icon(ModelIcons.GEM)   # null until the renderer is in a tree
## Boards draw a vector fallback while the texture is null (headless tests, first frame).

const K := "res://assets/kaykit/"
const GEM := K + "resources/Gem_Large.gltf"
const GEM_SMALL := K + "resources/Gem_Medium.gltf"
const COINS := K + "resources/Money_Pile_Small.gltf"
const COIN_STACK := K + "resources/Money_Coins_Stack_Medium.gltf"
const GEM_CHEST := K + "resources/Gems_Chest.gltf"
const NUGGET := K + "resources/Gold_Nugget_Large.gltf"
const BALLOON_DOG := K + "mystery/clown/balloon_dog_red.gltf"
const ROBOT := K + "mystery/figures/Robot_One.glb"
const ACTION_FIGURE := K + "mystery/figures/ActionFigure.glb"
const SHOVEL := K + "tools_extra/shovel.gltf"
const PICKAXE := K + "tools_extra/pickaxe.gltf"
const MAGNIFIER := K + "tools_extra/magnifying_glass.gltf"
const MAP := K + "tools_extra/map_rolled.gltf"
const POTION := K + "dungeon/bottle_A_labeled_green.gltf"

const PX := 256
const ARM_AXIS := Vector3(1, 0, 0)
const ARM_DROP := 70.0

static var _cache := {}
static var _holder: Node


## The icon texture for a model (yaw / pitch in degrees), or null while unavailable.
static func get_icon(path: String, yaw := 30.0, pitch := -18.0) -> Texture2D:
	var key := "%s|%d|%d" % [path, int(yaw), int(pitch)]
	if _cache.has(key):
		var v: Variant = _cache[key]
		return v as Texture2D
	if not ResourceLoader.exists(path) or not _ensure_holder():
		_cache[key] = null
		return null
	var tex := _render(path, yaw, pitch)
	_cache[key] = tex
	return tex


static func _ensure_holder() -> bool:
	if _holder != null and is_instance_valid(_holder):
		return true
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null or DisplayServer.get_name() == "headless":
		return false
	_holder = Node.new()
	_holder.name = "ModelIcons"
	loop.root.add_child.call_deferred(_holder)
	return true


static func _render(path: String, yaw: float, pitch: float) -> Texture2D:
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var vp := SubViewport.new()
	vp.size = Vector2i(PX, PX)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	# render for a moment (shader pipelines may still be compiling on the first frames), then
	# freeze: the texture keeps its last image
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.95)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	key.light_energy = 1.25
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15.0, 150.0, 0.0)
	rim.light_energy = 0.6
	rim.light_color = Color(0.8, 0.9, 1.0)
	vp.add_child(rim)
	var pivot := Node3D.new()
	vp.add_child(pivot)
	var model := ps.instantiate() as Node3D
	pivot.add_child(model)
	_relax_arms(model)
	pivot.rotation_degrees = Vector3(0.0, yaw, 0.0)
	# frame the model: orthographic camera fit to its bounds
	var box := _bounds(model, pivot)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var c := box.get_center()
	var ext := maxf(box.size.x, maxf(box.size.y, box.size.z))
	cam.size = ext * 1.18
	var dir := Vector3(0, 0, 1).rotated(Vector3.RIGHT, deg_to_rad(pitch))
	cam.position = c + dir * (ext * 3.0 + 1.0)
	cam.near = 0.01
	cam.far = ext * 8.0 + 10.0
	vp.add_child(cam)
	cam.look_at_from_position(cam.position, c, Vector3.UP)
	_holder.add_child.call_deferred(vp)
	var loop := Engine.get_main_loop() as SceneTree
	loop.create_timer(1.5, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(vp):
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	return vp.get_texture()


## Rigged figures come in a T-pose: drop the arms to the sides (a toy on a shelf).
static func _relax_arms(model: Node) -> void:
	for sk: Skeleton3D in model.find_children("*", "Skeleton3D", true, false):
		for side in ["l", "r"]:
			var i := sk.find_bone("upperarm." + side)
			if i < 0:
				continue
			var rest := sk.get_bone_rest(i).basis.get_rotation_quaternion()
			var ang := deg_to_rad(ARM_DROP if side == "l" else -ARM_DROP)
			sk.set_bone_pose_rotation(i, rest * Quaternion(ARM_AXIS, ang))


## World-space AABB of every mesh under `n` (as posed under `pivot`).
static func _bounds(n: Node3D, pivot: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var xf := pivot.transform * _rel(mi, pivot)
		var b := xf * mi.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	if first:
		return AABB(Vector3(-0.5, 0, -0.5), Vector3.ONE)
	return out


static func _rel(n: Node3D, stop: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != stop:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

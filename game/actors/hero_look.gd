class_name HeroLook
extends RefCounted
## A class's hero as it is seen everywhere (board, combat, Camp, class select, Wardrobe): the
## class signature kit (Character.KITS, ArmorBinder pieces) in the equipped skin, plus the A10
## prestige overlay (docs/design/2026-09-28-classes-enemies-skins.md §4.2).
##
##   var hero := HeroLook.create("paladin", "ascendant", true)   # helmet skin + golden statue
##   HeroLook.boo_head(kid, true)                                # Monster Kid: hood down (BOO!)
##
## Skin rows come from SkinDefs.LOOKS: `texture` (an atlas name, resolved in TEX_DIRS), `helmet`
## (the Paladin wears its helm piece), `mesh` (prestige body swap: Chieftain, Shade) and
## `overlay` (prestige: crown | statue | chieftain | shade | full_suit | gold_turret).
## Unknown ids (enemy models, the mannequin) fall back to a plain Character.create(id).

const TEX_DIRS := ["res://assets/kaykit/foes/adventurers/textures/", "res://assets/kaykit/adventurers_x/assets/",
	"res://assets/kaykit/foes/monthly/paladin/textures/", "res://assets/kaykit/foes/monthly/ninja/textures/",
	"res://assets/kaykit/foes/monthly/monster/textures/"]
const MONSTER_GLB := "res://assets/kaykit/foes/monthly/monster/Monster.glb"
const TURRET_GLB := "res://assets/kaykit/adventurers_x/assets/turret_base.gltf"
## Where the Engineer's Clockwork Turret stands, beside the hero (hero-local).
const TURRET_AT := Vector3(-1.0, 0.0, 0.3)
const GOLD := Color(1.0, 0.78, 0.3)
## Per-class body wash [colour, default-skin strength, other skins' strength]: the Necromancer's hooded-rogue
## palettes are bright, so a dusk-violet wash keeps him a grave-caller (never the Rogue).
const SHADE := {"necromancer": [Color(0.25, 0.08, 0.38), 0.75, 0.3]}
## The Necromancer's soul-green accent (ClassBeats.SOUL) on his crown and staff.
const NECRO_GLOW := Color(0.45, 1.0, 0.7)
## The Necromancer's hood scale (from behind the full-size hood hid the whole figure).
const NECRO_HOOD := 0.8
const BONE_SCALE := preload("res://game/actors/bone_scale.gd")
static func color(class_id: String) -> Color:
	return UiPalette.class_color(class_id)


## The class hero in `skin` (a SkinDefs slot id; "" = default), with the prestige overlay.
## `p_loadout` ({} = the class kit): an ArmoryLook loadout, the equipped Armory items.
static func create(class_id: String, skin := "default", prestige := false, p_loadout: Dictionary = {}) -> Character:
	if not Character.KITS.has(class_id):
		return Character.create(class_id if Character.MODELS.has(class_id) else "knight")
	var lo := p_loadout if not p_loadout.is_empty() else loadout(class_id, skin, prestige)
	var ch := Character.create(String(lo.model), "", lo)
	var tex := texture_of(class_id, skin)
	if tex != null:
		ch.set_texture(tex)
	if SHADE.has(class_id) and not (prestige and String(SkinDefs.def(class_id, "prestige").get("overlay", "")) == "statue"):
		var sh: Array = SHADE[class_id]
		var k := float(sh[1]) if skin in ["", "default"] else float(sh[2])
		ch.tint_where(func(mi: MeshInstance3D) -> bool: return mi.get_parent() == ch.skeleton, sh[0], k)
		if class_id == "necromancer":
			_grave_contrast(ch, skin in ["", "default"])
	ch.set_meta("class_id", class_id)
	ch.set_meta("skin", skin if skin != "" else "default")
	if prestige:
		apply_overlay(ch, class_id)
	if HeroDefs.mechanic(class_id) == "turret":
		add_turret(ch, prestige and String(SkinDefs.def(class_id, "prestige").get("overlay", "")) == "gold_turret")
	return ch


## The Necromancer as seen from behind (the combat camera): under one wash the big hood and the
## floor-length cape merged into a single grey column. A near-black grave-violet cape sets the lighter
## hood apart, and a soul-green glow on the bone crown and the staff's skull keeps the grave-caller
## (and his staff) readable from any side.
static func _grave_contrast(ch: Character, default_skin: bool) -> void:
	# the hood (and the crown on it) a touch smaller: the head bone is scaled after the animation
	if ch.skeleton and ch.skeleton.find_bone("head") >= 0 and ch.skeleton.get_node_or_null("HoodScale") == null:
		var m: SkeletonModifier3D = BONE_SCALE.new()
		m.name = "HoodScale"
		m.set("factor", NECRO_HOOD)
		ch.skeleton.add_child(m)
	ch.tint_where(func(mi: MeshInstance3D) -> bool: return String(mi.name).contains("_Cape"),
		Color(0.08, 0.02, 0.12), 0.9 if default_skin else 0.6)
	if default_skin:
		# the default atlas has a cream hood and a rose robe: under a strong key light (class
		# select, Camp portrait) the violet wash still read as a white hood on a pink body, so
		# the hood goes a deep violet and the robe a darker plum (the cape stays the darkest)
		ch.tint_where(func(mi: MeshInstance3D) -> bool: return String(mi.name).ends_with("_Head") and mi.get_parent() == ch.skeleton,
			Color(0.3, 0.14, 0.46), 0.85)
		ch.tint_where(func(mi: MeshInstance3D) -> bool:
			var n := String(mi.name)
			return mi.get_parent() == ch.skeleton and (n.ends_with("_Body") or n.contains("_Arm") or n.contains("_Leg")),
			Color(0.2, 0.08, 0.3), 0.85)
	ch.tint_where(func(mi: MeshInstance3D) -> bool: return String(mi.name).contains("Necromancer_Crown"),
		Color(0.93, 0.95, 0.88), 0.25, NECRO_GLOW * 0.3)
	ch.tint_where(func(mi: MeshInstance3D) -> bool: return _held_in(mi, "handslot_r"),
		Color(0.9, 1.0, 0.94), 0.15, NECRO_GLOW * 0.3)


static func _held_in(mi: Node, slot: String) -> bool:
	var p := mi.get_parent()
	while p != null and not (p is Character):
		if String(p.name).begins_with("Attach_" + slot):
			return true
		p = p.get_parent()
	return false


## The Engineer's Clockwork Turret prop beside the hero (gold for the prestige skin).
static func add_turret(ch: Character, gold := false) -> Node3D:
	if not ResourceLoader.exists(TURRET_GLB):
		return null
	var holder := Node3D.new()
	holder.name = "Turret"
	holder.position = TURRET_AT
	ch.add_child(holder)
	var t: Node3D = (load(TURRET_GLB) as PackedScene).instantiate()
	t.name = "Model"
	t.scale = Vector3.ONE * 0.8
	holder.add_child(t)
	if gold:
		for mi in t.find_children("*", "MeshInstance3D", true, false):
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1.0, 0.76, 0.3)
			m.metallic = 0.9
			m.roughness = 0.25
			m.emission_enabled = true
			m.emission = Color(0.5, 0.32, 0.05)
			(mi as MeshInstance3D).material_override = m
	return holder


## The hero's turret prop (null for other classes).
static func turret_of(ch: Node3D) -> Node3D:
	return ch.get_node_or_null("Turret") as Node3D if ch else null


## The kit loadout for a class in a skin (model swaps and the Paladin helm applied).
static func loadout(class_id: String, skin := "default", prestige := false) -> Dictionary:
	var lo := Character.kit(class_id)
	var s := SkinDefs.def(class_id, skin if skin != "" else "default")
	if bool(s.get("helmet", false)):
		var ap: Dictionary = lo.get("appearance", {})
		ap["head"] = "piece"
		lo["appearance"] = ap
	if prestige:
		var p := SkinDefs.def(class_id, "prestige")
		match String(p.get("overlay", "")):
			"shade":
				lo["model"] = "rogue_hooded"
				lo["head"] = ""
				(lo.get("appearance", {}) as Dictionary).erase("head")
			"chieftain":
				lo = {"model": "barbarian_large"}
			"full_suit":
				lo["model"] = "monster"
	return lo


## The skin's albedo atlas (null = the model's own).
static func texture_of(class_id: String, skin: String) -> Texture2D:
	var s := SkinDefs.def(class_id, skin if skin != "" else "default")
	var name := String(s.get("texture", ""))
	if name == "":
		return null
	for d in TEX_DIRS:
		var p := String(d) + name + ".png"
		if ResourceLoader.exists(p):
			return load(p)
	return null


## Prestige overlay on a created hero (crown + gold trim, golden statue, Chieftain's axe, the
## Monster Kid's paper crown). The Engineer's gold turret is drawn by the turret prop.
static func apply_overlay(ch: Character, class_id: String) -> void:
	var ov := String(SkinDefs.def(class_id, "prestige").get("overlay", ""))
	ch.set_meta("prestige", ov)
	match ov:
		"statue":
			ch.tint_where(func(_mi: MeshInstance3D) -> bool: return true, Color(1.0, 0.8, 0.38), 0.82,
				Color(0.3, 0.2, 0.04), 0.28, 0.85)
		"chieftain":
			ch.attach("handslot.r", "res://assets/kaykit/adventurers/weapons/axe_2handed.gltf")
			ch.scale = Vector3.ONE * 0.8
			add_crown(ch, 0.9)
		"full_suit":
			add_crown(ch, 0.7, true)
		"gold_turret":
			pass
		_:
			add_crown(ch)
			ch.tint_where(func(mi: MeshInstance3D) -> bool: return mi.has_meta("donor"), GOLD, 0.12,
				Color(0.22, 0.15, 0.03))


## A small gold crown on top of the head (paper: a folded yellow paper crown).
static func add_crown(ch: Character, size := 1.0, paper := false) -> Node3D:
	var head := ch.skeleton.find_bone("head")
	if head < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.name = "PrestigeCrown"
	ba.bone_name = "head"
	ch.skeleton.add_child(ba)
	var root := Node3D.new()
	ba.add_child(root)
	# the top of the head / headwear at rest, in the head bone's space
	var top := _head_top(ch)
	var rest := ch.skeleton.get_bone_global_rest(head)
	root.position = rest.affine_inverse() * top - Vector3.UP * 0.07
	root.scale = Vector3.ONE * size
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.86, 0.4) if paper else Color(1.0, 0.76, 0.26)
	m.metallic = 0.0 if paper else 0.9
	m.roughness = 0.8 if paper else 0.28
	m.emission_enabled = true
	m.emission = Color(1.0, 0.7, 0.2)
	m.emission_energy_multiplier = 0.25
	var band := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.19
	cm.height = 0.1
	cm.radial_segments = 16
	band.mesh = cm
	band.material_override = m
	band.position.y = 0.05
	root.add_child(band)
	for k in 5:
		var a := TAU * float(k) / 5.0
		var sp := MeshInstance3D.new()
		var pm: Mesh = PrismMesh.new() if paper else CylinderMesh.new()
		if paper:
			(pm as PrismMesh).size = Vector3(0.18, 0.16, 0.02)
		else:
			(pm as CylinderMesh).top_radius = 0.0
			(pm as CylinderMesh).bottom_radius = 0.06
			(pm as CylinderMesh).height = 0.16
			(pm as CylinderMesh).radial_segments = 6
		sp.mesh = pm
		sp.material_override = m
		sp.position = Vector3(sin(a) * 0.18, 0.17, cos(a) * 0.18)
		sp.rotation.y = a
		root.add_child(sp)
		if not paper:
			var gem := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.028
			sm.height = 0.056
			gem.mesh = sm
			var gm := StandardMaterial3D.new()
			var gems: Array[Color] = [Color(0.9, 0.15, 0.2), Color(0.2, 0.5, 1.0), Color(0.3, 0.9, 0.4)]
			gm.albedo_color = gems[k % 3]
			gm.emission_enabled = true
			gm.emission = gm.albedo_color
			gm.emission_energy_multiplier = 0.6
			gem.material_override = gm
			gem.position = Vector3(sin(a) * 0.205, 0.05, cos(a) * 0.205)
			root.add_child(gem)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## Highest visible point of the head / headwear meshes at rest (skeleton space).
static func _head_top(ch: Character) -> Vector3:
	var pm: Dictionary = Character.PART_MAP.get(ch.model_id, {})
	var names: Array = []
	names.append_array(pm.get("head", []))
	names.append_array(pm.get("headwear", []))
	var best := Vector3(0, -INF, 0)
	var meshes: Array = []
	for n in ch.model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.visible:
			continue
		if names.has(String(mi.name)) or (mi.has_meta("donor") and _is_head_piece(mi)):
			meshes.append(mi)
	for mi: MeshInstance3D in meshes:
		var ab := mi.get_aabb()
		var xf := Transform3D.IDENTITY
		if mi.get_parent() is BoneAttachment3D:
			var ba := mi.get_parent() as BoneAttachment3D
			xf = ch.skeleton.get_bone_global_rest(ch.skeleton.find_bone(ba.bone_name)) * mi.transform
		var top := xf * (ab.position + Vector3(ab.size.x * 0.5, ab.size.y, ab.size.z * 0.5))
		if top.y > best.y:
			best = top
	if best.y == -INF:
		var h := ch.skeleton.find_bone("head")
		return ch.skeleton.get_bone_global_rest(h).origin + Vector3.UP * 0.9
	return best


static func _is_head_piece(mi: MeshInstance3D) -> bool:
	var n := String(mi.name).to_lower()
	return n.contains("head") or n.contains("helm") or n.contains("hat") or n.contains("hood") or n.contains("crown") \
		or n.contains("mask") or n.contains("goggles")


## Monster Kid BOO!: the dino hood comes down (Monster_Head from Monster.glb replaces the kid's
## face) or goes back up. No-op for other heroes and the Full Suit (its hood is always down).
static func boo_head(ch: Character, down: bool) -> void:
	if ch == null or ch.model_id != "monster_kid":
		return
	var own: Array = Character.PART_MAP.monster_kid.head
	if down:
		if ch.has_meta("boo_nodes"):
			return
		var nodes := ArmorBinder.bind(ch, MONSTER_GLB, ["Monster_Head"])
		var tex: Texture2D = null
		for mi in ch.model.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name) == "MonsterCostume_Body":
				var b := (mi as MeshInstance3D).get_active_material(0) as BaseMaterial3D
				tex = b.albedo_texture if b else null
		if tex:
			ArmorBinder._retexture(nodes, tex)
		ch.show_parts(own, false)
		ch.set_meta("boo_nodes", nodes)
	else:
		if not ch.has_meta("boo_nodes"):
			return
		for n in ch.get_meta("boo_nodes"):
			if is_instance_valid(n):
				n.queue_free()
		ch.remove_meta("boo_nodes")
		ch.show_parts(own, true)

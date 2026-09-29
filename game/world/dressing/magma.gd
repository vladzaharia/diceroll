class_name DressMagma
extends RefCounted
## Magma Depths kits. The framing (tight basalt island, the lava channel beside the ring,
## lava falls at the back, basalt columns and spires) stays in BiomeBlocks._magma(); this
## varies what stands on the side shelves, the front clutter, the set piece and corners.
##  sides (kit(1)): 0 forge yard, 1 mine camp (ore heaps, pickaxes, carts of stone),
##                  2 battlefield (orc war drum, skeleton remains, broken arms);
##  set pieces (kit(0)): 0 Cinder Forge (BiomeBlocks), 1 molten hoard, 2 war-drum altar;
##  moat corners (kit(2)): 0 lava vents, 1 glowing ore heaps, 2 remains.

const D := Props.DUN
const T := Props.TOOLS
const TX := Dressing.TX
const RES := Dressing.RES
const SKP := Dressing.SKP
const HOT := Color(1.0, 0.42, 0.1)
const ASH := Color(0.36, 0.33, 0.36, 0.6)      ## soot re-tint for wood / bone


## One side shelf (x = the raised basalt column beyond the channel).
static func side(d: Node3D, sx: float, side_x: float) -> void:
	var x := sx * side_x
	var face := -90.0 * sx
	# every kit keeps a brazier (the shelves' light)
	var bz := BiomeBlocks.put(d, D + "torch_lit.gltf", Vector3(x / Dressing.s, 0, 1.2), 0.0, 1.3)
	bz.name = "Brazier"
	Biome.flame(d, bz.position + Vector3(0, 1.0, 0), Color(1.0, 0.5, 0.15), 0.42, 10).set_meta("prescaled", true)
	Biome.flicker_light(d, bz.position + Vector3(0, 1.5, 0.3), Color(1.0, 0.5, 0.2), 1.6, 5.0).set_meta("prescaled", true)
	Dressing.occupy(bz.position.x, bz.position.z, 0.5)
	var e := Dressing.extent
	match Dressing.kit(1):
		0:  # forge yard
			Dressing.place(T + "anvil.gltf", Vector3(x, 0, -2.4 * Dressing.s), sx * 70.0, 1.4)
			Dressing.place(T + "hammer.gltf", Vector3(x + 0.1, 0.02, -1.4 * Dressing.s), sx * 20.0, 1.1)
			Dressing.place(TX + "tongs.gltf", Vector3(x - sx * 0.3, 0.1, -1.1 * Dressing.s), 0.0, 1.0).rotation.x = PI * 0.5
			Dressing.place(TX + "bucket_metal.gltf", Vector3(x + sx * 0.2, 0, 2.6 * Dressing.s), 0.0, 0.8)
			Dressing.place(D + "barrel_large.gltf", Vector3(x, 0, 3.9 * Dressing.s), sx * 30.0, 0.75)
			if sx < 0.0:
				Dressing.place(T + "grindstone.gltf", Vector3(x, 0, 5.4 * Dressing.s), 80.0, 1.2)
			else:
				Dressing.place(D + "sword_shield_broken.gltf", Vector3(x, 0, 5.5 * Dressing.s), -80.0, 0.85)
		1:  # mine camp
			var g := Dressing.group("Ore", x, -2.2 * Dressing.s, 1.0)
			g.rotation.y = deg_to_rad(face)
			DressBits.ore_heap(g, String(Dressing.pick(["Gold", "Copper", "Iron"])), 1.2)
			Dressing.place(Dressing.DX + "bucket_pickaxes.gltf", Vector3(x, 0, 3.0 * Dressing.s), face, 0.75)
			Dressing.place(RES + "Stone_Chunks_Large.gltf", Vector3(x + sx * 0.1, 0, 4.4 * Dressing.s), face, 0.8)
			var pk := Dressing.stuck(d, TX + "pickaxe.gltf", Vector3(x - sx * 0.35, Dressing.gy(x, -0.6) + 0.35, -0.6 * Dressing.s),
				face, 20.0, 1.0)
			pk.name = "Pickaxe"
			Dressing.place(RES + "Iron_Bars_Stack_Small.gltf", Vector3(x, 0, 5.6 * Dressing.s), face, 0.9)
		2:  # battlefield
			var drum := Dressing.place(Dressing.ORC + "Orc_Wardrum.gltf.glb", Vector3(x, 0, -2.3 * Dressing.s), face, 1.0)
			drum.name = "WarDrum"
			Dressing.stuck(d, Dressing.ORC + "Orc_WardrumStick.gltf.glb", drum.position + Vector3(0.3, 0.9, 0.3), 20.0, 40.0, 1.0)
			var g := Dressing.group("Remains", x, 3.2 * Dressing.s, 0.9)
			DressBits.bone_pile(g, 0.9, null, ASH)
			Dressing.stuck(d, Dressing.ORC + "Orc_Axe.gltf.glb", Vector3(x - sx * 0.2, Dressing.gy(x, -0.4) + 0.5, -0.4 * Dressing.s),
				face, -22.0, 1.0)
			Dressing.place(SKP + "Skeleton_Shield_Large_A.gltf", Vector3(x + sx * 0.1, 0.55, 5.0 * Dressing.s), face, 0.9) \
				.rotation.x = deg_to_rad(-60.0)
	# a smoking crack beside the channel
	Dressing.occupy(x, -5.8 * Dressing.s, 1.2)


## Front strip clutter (low: nuggets, cracks, spent weapons) on top of the basalt boulders.
static func front(d: Node3D) -> void:
	var e := Dressing.extent
	var h := Dressing.half
	match Dressing.kit(1):
		0:
			for p in [Vector2(-3.8, e + 1.6), Vector2(4.2, e + 1.8)]:
				if Dressing.fits(p.x, p.y, 0.6, 0.6):
					var g := Dressing.group("Scrap", p.x, p.y, 0.6)
					g.rotation.y = Dressing.rng.randf() * TAU
					Props.put(g, RES + "Iron_Bars.gltf", Vector3.ZERO, 0.0, 0.7)
					Dressing.lying(g, T + "hammer.gltf", Vector3(0.55, 0, 0.25), 40.0, 0.9)
					Dressing.lying(g, TX + "tongs.gltf", Vector3(-0.45, 0, 0.35), -30.0, 0.9)
		1:
			for p in [Vector2(-3.6, e + 1.7), Vector2(3.9, e + 2.0)]:
				var g := Dressing.group("Ore", p.x, p.y, 0.7)
				DressBits.ore_heap(g, String(Dressing.pick(["Iron", "Copper"])), 0.8)
		2:
			for p in [Vector2(-3.6, e + 1.7), Vector2(3.9, e + 2.0)]:
				if Dressing.fits(p.x, p.y, 0.6, 0.6):
					var g := Dressing.group("Remains", p.x, p.y, 0.6)
					DressBits.bone_pile(g, 0.7, null, ASH)
	# glowing nuggets and scorched pebbles over the whole island (never in the channel)
	Dressing.scatter([RES + "Iron_Nugget_Small.gltf", RES + "Iron_Nugget_Medium.gltf", RES + "Gold_Nugget_Small.gltf"],
		int(26 * Dressing.s), "all", Vector2(0.9, 1.3), Color(0.3, 0.26, 0.28, 0.85))
	Dressing.scatter([Dressing.FOREST + "Rock_5_A_Color1.gltf", Dressing.FOREST + "Rock_5_B_Color1.gltf",
		Dressing.FOREST + "Rock_2_A_Color1.gltf"], int(24 * Dressing.s), "border", Vector2(0.7, 1.2), Color(0.2, 0.18, 0.2, 0.9))


# --- set pieces ---------------------------------------------------------------------------------

static func _dais(c: Node3D) -> float:
	var moat := BiomeBlocks.lava_pool(c, Vector3(0, 0.01, -0.1), 2.05)
	moat.name = "ForgeMoat"
	var tiers := [[3.0, 0.4, 0.0], [2.2, 0.4, 20.0]]
	var y := 0.0
	for t in tiers:
		var mi := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = float(t[0]) * 0.5
		cy.bottom_radius = float(t[0]) * 0.54
		cy.height = float(t[1])
		cy.radial_segments = 8
		cy.rings = 1
		mi.mesh = cy
		mi.material_override = BiomeBlocks.basalt_material()
		mi.position = Vector3(0, y + float(t[1]) * 0.5, -0.1)
		mi.rotation.y = deg_to_rad(float(t[2]) + 22.5)
		c.add_child(mi)
		y += float(t[1])
	var ring := Biome._rune_circle(Color(1.0, 0.42, 0.12), 2.85)
	ring.position = Vector3(0, 0.04, 0)
	(ring.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.6)
	c.add_child(ring)
	return y


## Set piece 1: the molten hoard: gold bars and ore heaped on the dais, glowing hot, with a
## crucible of tongs and a smoking brazier on each side.
static func hoard(c: Node3D) -> void:
	var y := _dais(c)
	var stack := Props.put(c, RES + "Gold_Bars_Stack_Large.gltf", Vector3(0.0, y, -0.35), 20.0, 0.66)
	stack.name = "Hoard"
	Props.tint(stack, Color(1.0, 0.78, 0.35), 0.25)
	var heap := Node3D.new()
	heap.position = Vector3(-0.45, y, 0.45)
	c.add_child(heap)
	DressBits.ore_heap(heap, "Gold", 0.9)
	var heap2 := Node3D.new()
	heap2.position = Vector3(0.6, y, 0.4)
	heap2.rotation.y = 2.0
	c.add_child(heap2)
	DressBits.ore_heap(heap2, "Copper", 0.8)
	Props.put(c, TX + "tongs.gltf", Vector3(0.9, y + 0.1, -0.5), 30.0, 1.0).rotation.x = PI * 0.5
	Biome.flame(c, Vector3(0, y + 0.3, 0.1), Color(1.0, 0.55, 0.15), 0.5, 10)
	var sm := BiomeBlocks.smoke(c, Vector3(0, y + 1.6, -0.2), 1.0, Color(0.3, 0.28, 0.4, 0.5))
	sm.name = "HoardSmoke"
	for sx in [-1.0, 1.0]:
		BiomeBlocks.spire(c, Vector3(sx * 1.85, 0, -0.9), 1.05, int(sx * 3 + 70))
		var bz := Props.put(c, D + "torch_lit.gltf", Vector3(sx * 1.7, 0, 1.25), 0.0, 0.95)
		bz.name = "Brazier"
		Biome.flame(c, Vector3(sx * 1.7, 0.75, 1.25), Color(1.0, 0.5, 0.15), 0.3, 7)
	Biome.flicker_light(c, Vector3(0, y + 1.5, 0.9), Color(1.0, 0.55, 0.2), 2.6, 6.5)


## Set piece 2: the war-drum altar: a great orc war drum on the dais, a huge skeleton axe
## driven in beside it, war banners of bone and fire bowls.
static func war_drum(c: Node3D) -> void:
	var y := _dais(c)
	var drum := Props.put(c, Dressing.ORC + "Orc_Wardrum.gltf.glb", Vector3(0, y, -0.2), 20.0, 1.55)
	drum.name = "WarDrum"
	Dressing.stuck(c, Dressing.ORC + "Orc_WardrumStick.gltf.glb", Vector3(0.45, y + 1.45, 0.25), -30.0, 35.0, 1.5)
	var axe := Dressing.stuck(c, SKP + "Skeleton_Golem_Axe_Large.gltf", Vector3(-1.05, 1.25, 0.25), -15.0, 10.0, 1.05)
	axe.name = "GiantAxe"
	Props.tint(axe, Color(0.34, 0.3, 0.34), 0.5, Color(0.5, 0.12, 0.0))
	Dressing.lying(c, Dressing.ORC + "Orc_Club.gltf.glb", Vector3(0.95, y, 0.6), 60.0, 1.0)
	Props.put(c, Props.HAL + "skull.gltf", Vector3(0.9, 0.0, 1.45), -20.0, 0.55)
	for sx in [-1.0, 1.0]:
		BiomeBlocks.spire(c, Vector3(sx * 1.9, 0, -1.0), 1.15, int(sx * 3 + 80))
		var bz := Props.put(c, D + "torch_lit.gltf", Vector3(sx * 1.55, 0, 1.3), 0.0, 0.95)
		bz.name = "Brazier"
		Biome.flame(c, Vector3(sx * 1.55, 0.75, 1.3), Color(1.0, 0.5, 0.15), 0.3, 7)
	Biome.flame(c, Vector3(0, y + 1.5, -0.2), Color(1.0, 0.5, 0.15), 0.3, 6)
	Biome.flicker_light(c, Vector3(0, y + 1.8, 1.0), Color(1.0, 0.5, 0.18), 2.4, 6.5)


# --- moat corners -------------------------------------------------------------------------------

static func corner(holder: Node3D, p: Vector3, yaw: float, sx: float, sz: float) -> bool:
	match Dressing.kit(2):
		1:
			var g := Node3D.new()
			g.name = "OreHeap"
			g.position = p
			g.rotation.y = deg_to_rad(yaw)
			holder.add_child(g)
			DressBits.ore_heap(g, String(["Iron", "Gold", "Copper"][int(sx + 1.0 + (sz + 1.0) * 0.5) % 3]), 0.9,
				Color(0.3, 0.27, 0.3, 0.55))
			BiomeBlocks.crack_decal(holder, p + Vector3(-sx * 0.3, 0.02, -sz * 0.3), 1.4, yaw)
			Biome.flicker_light(holder, p + Vector3(0, 0.8, 0), Color(1.0, 0.42, 0.12), 0.8, 3.0)
			return true
		2:
			var g := Node3D.new()
			g.name = "Remains"
			g.position = p
			g.rotation.y = deg_to_rad(yaw)
			holder.add_child(g)
			DressBits.bone_pile(g, 0.8, null, ASH)
			var club := Dressing.stuck(holder, Dressing.ORC + "Orc_Club.gltf.glb", p + Vector3(-sx * 0.6, 0.35, sz * 0.1), yaw, 18.0, 0.8)
			club.name = "Club"
			BiomeBlocks.crack_decal(holder, p + Vector3(-sx * 0.2, 0.02, sz * 0.5), 1.3, yaw + 40.0)
			Biome.flicker_light(holder, p + Vector3(0, 0.8, 0), Color(1.0, 0.42, 0.12), 0.7, 3.0)
			return true
	return false

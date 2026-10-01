class_name AffixLooks
extends RefCounted
## The affix overlay layer (SkinRules.AFFIXES, §3A.5): "body = how strong, overlay = what rule".
## Each affix adds an eye colour, a rim accent (a fresnel glow in tint.gdshader, never an albedo
## change) and one prop on a fixed socket. Trait-type affixes (armored, thorned, warded, piercing,
## frenzied) draw their trait's overlay (EnemyLooks._trait_overlay) as the prop; the rest are here.
## Called by EnemyLooks.create / retint; board previews (full = false) get static props only.
##
##   AffixLooks.set_stacks(ch, 4)        # Frenzy: the head steam thickens per stack
##   AffixLooks.set_ward_active(ch, on)  # Warded: the shimmer dome only while it protects
##   AffixLooks.pulse(ch, "thorned")     # a proc: the rim flares in the affix colour

## Eye glow meshes on bodies without their own eye meshes (the look's "eyes" key, or added).
const DOME_SHADER := preload("res://game/enemies/shimmer_dome.gdshader")
const EYE_OFFSETS := {
	"orc": Vector3(0, 0.02, 0.16), "werewolf": Vector3(0, 0.02, 0.06), "werewolf_man": Vector3(0, -0.02, 0.14),
	"necromancer": Vector3(0, -0.02, 0.0), "paladin_helm": Vector3(0, 0.08, 0.06),
}


## Rim colour of a look's affixes (the last one; with two the eyes show the first).
static func rim_color(L: Dictionary) -> Color:
	var a: Array = L.get("affixes", [])
	if a.is_empty():
		return Color(0, 0, 0, 0)
	var c := SkinRules.affix_color(String(a[-1]), String(L.get("biome", "")))
	return Color(c, SkinRules.AFFIX_RIM * (1.25 if SkinRules.clashes(String(a[-1]), String(L.get("biome", ""))) else 1.0))


static func eye_color(L: Dictionary) -> Color:
	var a: Array = L.get("affixes", [])
	return SkinRules.affix_color(String(a[0]), String(L.get("biome", ""))) if not a.is_empty() else Color.BLACK


## Builds the affix props (call before the first retint: it sets the rim uniform).
static func apply(ch: Character, L: Dictionary, full: bool) -> void:
	var affixes: Array = L.get("affixes", [])
	if affixes.is_empty():
		return
	ch.tint_params["rim_color"] = rim_color(L)
	var root := Node3D.new()
	root.name = "AffixMarks"
	ch.add_child(root)
	# eyes: bodies without eye meshes get glowing ones (the look's own "eyes" are recoloured)
	var eye := eye_color(L)
	var native := not ch.model.find_children("*_Eyes", "MeshInstance3D", true, false).is_empty()
	if not native:
		var socket := ch.skeleton.get_node_or_null("Eyes")
		if socket:
			_recolour_eyes(socket, eye)
		else:
			EnemyLooks._eyes(ch, eye, EYE_OFFSETS.get(ch.model_id, Vector3.ZERO))
	for a in affixes:
		_prop(ch, root, String(a), SkinRules.affix_color(String(a), String(L.get("biome", ""))), full)


## Affix tints over retint(): native eye meshes, the vampire's cape, gilded gear.
static func retint(ch: Character, L: Dictionary, flash: Color) -> void:
	var affixes: Array = L.get("affixes", [])
	var eye := eye_color(L)
	ch.tint_where(func(m: MeshInstance3D) -> bool: return String(m.name).ends_with("_Eyes"), eye, 1.0, eye * 2.0 + flash)
	if "vampiric" in affixes:
		ch.tint_where(func(m: MeshInstance3D) -> bool:
				var n := String(m.name)
				return n.contains("Cape") or n.contains("Cloak") or n.contains("Hood"),
			Color(0.5, 0.02, 0.08), 0.88, Color(0.22, 0.0, 0.03) + flash)
	if "gilded" in affixes:
		ch.tint_where(func(m: MeshInstance3D) -> bool: return EnemyLooks._in_attachment(m, ""),
			Color(1.0, 0.8, 0.3), 0.85, Color(0.35, 0.22, 0.02) + flash, 0.25, 1.0)


static func _recolour_eyes(socket: Node, c: Color) -> void:
	for e in socket.get_children():
		if e is MeshInstance3D:
			var m := (e as MeshInstance3D).material_override as StandardMaterial3D
			if m:
				m = m.duplicate()
				m.albedo_color = c.lightened(0.3)
				(e as MeshInstance3D).material_override = m


static func _socket(ch: Character, bone: String, tag: String) -> Node3D:
	var s := EnemyLooks._socket(ch, bone)
	if s:
		s.name = "AffixSocket_%s_%s" % [tag, bone.replace(".", "_")]
	return s


static func _prop(ch: Character, root: Node3D, a: String, col: Color, full: bool) -> void:
	var k := EnemyLooks._rig_k(ch)
	match a:
		"regenerating":
			# leaf motes rising at the feet (static leaves on board previews)
			if full:
				var p := Fx.elite_sparkle(root, Vector3(0, 0.1, 0), 0.55, 1.5)
				p.name = "RegenMotes"
				(p.process_material as ParticleProcessMaterial).color = col
			var ring := Node3D.new()
			ring.name = "RegenLeaves"
			root.add_child(ring)
			for i in 5:
				var an := TAU * i / 5.0
				var lf := EnemyLooks._blob(ring, Vector3(cos(an) * 0.62, 0.08, sin(an) * 0.62), 0.13, col.darkened(0.25 + 0.1 * (i % 2)),
					70 + i, Vector3(1.3, 0.45, 0.8))
				lf.rotation.y = -an
			var sp := ring.create_tween().set_loops()
			sp.tween_property(ring, "rotation:y", TAU, 6.0).from(0.0)
		"vampiric":
			if full:
				var p := _drips(col)
				root.add_child(p)
				p.position = Vector3(0, 1.1 * k, 0.15)
			else:
				for sx in [-1.0, 1.0]:
					var d := EnemyLooks._dome(root, Vector3(sx * 0.18, 0.9, 0.32) * k, 0.06 * k, EnemyLooks._mat(col.darkened(0.2), col * 0.6))
					d.scale = Vector3(1.0, 1.6, 1.0)
		"hexing":
			var h := _socket(ch, "head", "hex")
			if h:
				var halo := Node3D.new()
				halo.name = "HexCircle"
				halo.position = Vector3(0, 1.05, 0)
				h.add_child(halo)
				var ring := Biome._rune_circle(col, 0.42)
				(ring.material_override as ShaderMaterial).set_shader_parameter("intensity", 1.4)
				halo.add_child(ring)
				var t := halo.create_tween().set_loops()
				t.tween_property(halo, "rotation:y", TAU, 5.0).from(0.0)
				var b := halo.create_tween().set_loops()
				b.tween_property(halo, "position:y", 1.14, 0.9).set_trans(Tween.TRANS_SINE)
				b.tween_property(halo, "position:y", 1.02, 0.9).set_trans(Tween.TRANS_SINE)
		"frostbound":
			var s := _socket(ch, "handslot.r", "ice")
			if s:
				var cc := BiomeBlocks.crystal_cluster(s, Vector3(0, 0.12, 0.05) * k, 0.42 * k, 4, 21, false)
				cc.name = "IceWeapon"
			if full:
				var p := Fx.elite_sparkle(root, Vector3(0, 0.1, 0), 0.55, 1.1)
				p.name = "FrostMist"
				(p.process_material as ParticleProcessMaterial).color = col.lightened(0.3)
		"gilded":
			var h := _socket(ch, "head", "gild")
			if h:
				var halo := Node3D.new()
				halo.name = "CoinHalo"
				halo.position = Vector3(0, 1.0, 0)
				h.add_child(halo)
				var gold := EnemyLooks._mat(Color(1.0, 0.78, 0.25), Color(0.45, 0.28, 0.02), 0.25)
				gold.metallic = 0.9
				for i in 4:
					var an := TAU * i / 4.0
					var coin := MeshInstance3D.new()
					var cm := CylinderMesh.new()
					cm.top_radius = 0.1
					cm.bottom_radius = 0.1
					cm.height = 0.03
					cm.radial_segments = 12
					coin.mesh = cm
					coin.material_override = gold
					coin.position = Vector3(cos(an) * 0.34, 0.04 * (i % 2), sin(an) * 0.34)
					coin.rotation = Vector3(PI * 0.5, -an, 0)
					halo.add_child(coin)
				var t := halo.create_tween().set_loops()
				t.tween_property(halo, "rotation:y", TAU, 3.0).from(0.0)
			if full:
				var p := Fx.elite_sparkle(root, Vector3(0, 0.3, 0), 0.5, 1.6)
				p.name = "CoinSparkle"
				(p.process_material as ParticleProcessMaterial).color = col


## Red drops falling from the figure (Vampiric).
static func _drips(col: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "BloodDrips"
	p.amount = 6
	p.lifetime = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3.DOWN
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.2
	pm.gravity = Vector3(0, -3.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	pm.color = col
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.18)
	q.material = Props.particle_material("dot")
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.preprocess = 1.0
	return p


# --- trait-type overlays drawn by EnemyLooks._trait_overlay -----------------------------------

## Frenzy: steam puffs from the head that thicken per stack (set_stacks).
static func steam(ch: Character, root: Node3D, col: Color, full: bool) -> void:
	var h := EnemyLooks._trait_socket(ch, "head")
	if h == null:
		return
	var k := EnemyLooks._rig_k(ch)
	var anchor := Node3D.new()
	anchor.name = "FrenzySteam"
	anchor.position = Vector3(0, 0.95, 0) * (1.0 if k <= 1.0 else 0.75)
	h.add_child(anchor)
	# angry ember-orange brow glow: two short slanted bars over the eyes
	var brow := EnemyLooks._mat(col, col * 1.2)
	for sx in [-1.0, 1.0]:
		var b := EnemyLooks._dome(anchor, Vector3(sx * 0.16, -0.38, 0.4) * k, 0.07 * k, brow)
		b.scale = Vector3(1.8, 0.45, 0.6)
		b.rotation.z = sx * 0.45
		b.name = "Brow"
	if full:
		var p := GPUParticles3D.new()
		p.name = "Puffs"
		p.amount = 10
		p.lifetime = 1.1
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.2 * k
		pm.direction = Vector3.UP
		pm.spread = 25.0
		pm.initial_velocity_min = 0.5
		pm.initial_velocity_max = 0.9
		pm.gravity = Vector3.ZERO
		pm.scale_min = 0.7
		pm.scale_max = 1.2
		var sc := Curve.new()
		sc.add_point(Vector2(0.0, 0.3))
		sc.add_point(Vector2(0.4, 1.0))
		sc.add_point(Vector2(1.0, 0.0))
		var sct := CurveTexture.new()
		sct.curve = sc
		pm.scale_curve = sct
		pm.color = Color(0.92, 0.9, 0.88, 0.7)
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.3, 0.3) * k
		q.material = Props.particle_material("dot")
		p.draw_pass_1 = q
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.preprocess = 1.0
		p.amount_ratio = 0.35
		anchor.add_child(p)
	else:
		for i in 2:
			var d := EnemyLooks._dome(anchor, Vector3((-0.12 + 0.24 * i), 0.08 + 0.12 * i, 0) * k, (0.1 + 0.03 * i) * k,
				EnemyLooks._mat(Color(0.92, 0.9, 0.88)))
			d.name = "Puff"


## Frenzy stacks (0..FRENZY_MAX): the steam thickens and the brows glow hotter.
static func set_stacks(ch: Character, stacks: int) -> void:
	if not is_instance_valid(ch):
		return
	var f := clampf(float(stacks) / float(EnemyDefs.FRENZY_MAX), 0.0, 1.0)
	for n in ch.find_children("Puffs", "GPUParticles3D", true, false):
		var p := n as GPUParticles3D
		p.amount_ratio = 0.35 + 0.65 * f
		(p.process_material as ParticleProcessMaterial).color = Color(0.92, 0.9, 0.88, 0.7).lerp(Color(1.0, 0.55, 0.3, 0.85), f)
		p.scale = Vector3.ONE * (1.0 + 0.6 * f)
	for n in ch.find_children("Brow", "MeshInstance3D", true, false):
		var m := (n as MeshInstance3D).material_override as StandardMaterial3D
		if m:
			m.emission_energy_multiplier = 1.5 + 2.5 * f


## Warded: a small violet shimmer dome (the Bone Warden's ward at 0.6x).
static func shimmer_dome(_ch: Character, root: Node3D, col: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "ShimmerDome"
	var sm := SphereMesh.new()
	var r := 1.1
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	# a fresnel shell: clear in the middle, a violet edge (the Bone Warden's ward, lighter)
	var m := ShaderMaterial.new()
	m.shader = DOME_SHADER
	m.set_shader_parameter("color", col)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3.UP * 1.0
	mi.scale = Vector3(1.0, 1.05, 1.0)
	root.add_child(mi)


## Shows / hides the Warded dome (it protects only while another non-warded enemy stands).
static func set_ward_active(ch: Character, on: bool) -> void:
	if not is_instance_valid(ch):
		return
	for n in ch.find_children("ShimmerDome", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.visible == on:
			continue
		if on:
			mi.visible = true
			mi.scale = Vector3.ONE * 0.01
			mi.create_tween().tween_property(mi, "scale", Vector3(1.0, 1.05, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			var t := mi.create_tween()
			t.tween_property(mi, "scale", Vector3.ONE * 1.3, 0.25)
			t.tween_callback(func() -> void: mi.visible = false)


## A proc: the rim flares bright in the affix colour, then settles.
static func pulse(ch: Character, affix: String) -> void:
	if not is_instance_valid(ch) or not ch.has_meta("look"):
		return
	var L: Dictionary = ch.get_meta("look")
	var base: Color = ch.tint_params.get("rim_color", Color(0, 0, 0, 0))
	var hot := Color(SkinRules.affix_color(affix, String(L.get("biome", ""))).lightened(0.2), 3.0)
	var id := String(ch.get_meta("enemy_id", ""))
	var t := ch.create_tween()
	t.tween_method(func(c: Color) -> void:
		if is_instance_valid(ch):
			ch.tint_params["rim_color"] = c
			EnemyLooks.retint(ch, id), hot, base, 0.5)


# --- board previews --------------------------------------------------------------------------

## Affix chips floating above a board tile (the affixes of its enemies, unique, max 3), so the
## rule is visible before the board Reroll / GO decision. `lists`: one affix array per enemy.
static func tile_chips(holder: Node3D, lists: Array, height := 1.15) -> void:
	var ids: Array = []
	for l in lists:
		for a in (l if l is Array else []):
			if SkinRules.AFFIXES.has(String(a)) and not ids.has(String(a)):
				ids.append(String(a))
	if ids.is_empty():
		return
	ids = ids.slice(0, 3)
	var row := Node3D.new()
	row.name = "AffixChips"
	row.position = Vector3(0, height, 0)
	holder.add_child(row)
	var size := 0.62
	for k in ids.size():
		var a := String(ids[k])
		var b := UnitHud.affix_badge(String(SkinRules.AFFIXES[a].icon), SkinRules.AFFIXES[a].color, size, 0.0)
		b.name = "Chip_" + a
		var m := b.material_override as ShaderMaterial
		m.set_shader_parameter("billboard", 1.0)
		m.render_priority = 4
		m.set_shader_parameter("offset", Vector2((float(k) - (ids.size() - 1) * 0.5) * (size + 0.06), 0.0))
		b.extra_cull_margin = 1.0
		row.add_child(b)
	var bob := row.create_tween().set_loops()
	bob.tween_property(row, "position:y", height + 0.08, 0.9).set_trans(Tween.TRANS_SINE)
	bob.tween_property(row, "position:y", height, 0.9).set_trans(Tween.TRANS_SINE)

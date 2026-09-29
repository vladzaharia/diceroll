class_name EnemyLooks
extends RefCounted
## Enemy id -> dressed Character: a family look (EnemyRoster), one of its cosmetic variants,
## then the meaningful skins from SkinRules (tier colourway, elite gold, trait overlays).
##
##   var ctx := EnemyLooks.spawn_context(enemy_dict, tile_idx, earlier_enemies, biome_id)
##   var ch := EnemyLooks.create("skeleton_warrior", true, ctx)   # full: lights, particles, aura
##   var fig := EnemyLooks.create("ember_imp", false, ctx)        # lite: board previews
##   ch.play(EnemyLooks.clip("skeleton_warrior", "idle"))          # role aliases resolve per figure
##   EnemyLooks.retint(ch, id, flash_emission)                     # hit flash, keeps part tints
##   EnemyLooks.set_traits(ch, ["ward"])                           # boss phase changes
##   EnemyLooks.shatter(ch)                                        # Magma Golem phase 2
##
## ctx keys (all optional): variant (cosmetic index; default 0), tier (1..3), elite, traits.
## Variants are picked per spawn from a hash of the run seed, the tile and the enemy's
## occurrence on it, so the board preview and the fight on that tile match.

const BONE := Color(0.94, 0.9, 0.8)
const GHOST_SHADER := preload("res://game/actors/ghost.gdshader")
## Legacy alias: every enemy id with a look.
const DEFS := EnemyRoster.LOOKS

## Set at run start (GameController.start) so variants differ between runs.
static var run_seed := 0
static var _hud_cache: Dictionary = {}


## Family look merged with a cosmetic variant (no tier / elite / trait layers).
static func def(id: String, variant := 0) -> Dictionary:
	var base: Dictionary = DEFS.get(id, DEFS["skeleton_minion"])
	var out := base.duplicate(true)
	out.erase("variants")
	var vs: Array = base.get("variants", [])
	if vs.is_empty():
		return out
	var v: Dictionary = vs[posmod(variant, vs.size())]
	for k in v:
		if v[k] == null:
			out.erase(k)
		elif k == "clips":
			var c: Dictionary = out.get("clips", {}).duplicate()
			c.merge(v[k], true)
			out["clips"] = c
		else:
			out[k] = v[k]
	return out


static func variant_count(id: String) -> int:
	return maxi(1, (DEFS.get(id, {}) as Dictionary).get("variants", []).size())


## Cosmetic variant for the `prior.size()`-th spawn slot of a tile: consecutive same-id enemies
## on a tile step through the variants, so a line of three minions never repeats one.
## `prior`: the enemies spawned before this one (dicts with "id", or id strings).
static func variant_for(id: String, tile: int, prior: Array = []) -> int:
	var n := variant_count(id)
	if n <= 1:
		return 0
	var k := 0
	for e in prior:
		if (String(e.get("id", "")) if e is Dictionary else String(e)) == id:
			k += 1
	return posmod(hash("%s|%d|%d" % [id, tile, run_seed]) + k, n)


## Full spawn context from a combat / board enemy entry. d: enemy dict ({id, elite, traits})
## or an id string; `elite` forces the elite skin (board tiles carry it on the tile).
static func spawn_context(d: Variant, tile: int, prior: Array = [], biome := "", elite := false) -> Dictionary:
	var id := String(d.get("id", "")) if d is Dictionary else String(d)
	var traits: Array = (d.get("traits", EnemyDefs.traits(id)) if d is Dictionary else EnemyDefs.traits(id)) \
		if _core_has(id) else []
	return {"variant": variant_for(id, tile, prior), "tier": SkinRules.tier_for(biome),
		"elite": elite or (bool(d.get("elite", false)) if d is Dictionary else false), "traits": traits.duplicate()}


static func _core_has(id: String) -> bool:
	return EnemyDefs.ENEMIES.has(id) or EnemyDefs.BOSSES.has(id) or EnemyDefs.MINIBOSSES.has(id)


## The final look for a spawn: variant + tier colourway + elite (regular enemies only).
static func look(id: String, ctx: Dictionary = {}) -> Dictionary:
	var L := def(id, int(ctx.get("variant", 0)))
	L["id"] = id
	var unique := bool(L.get("boss", false)) or bool(L.get("miniboss", false))
	var tier := clampi(int(ctx.get("tier", 1)), 1, 3)
	L["tier"] = tier
	if not unique:
		var tex: Variant = SkinRules.tier_texture(String(L.model), tier)
		if tex != null:
			L["texture"] = tex
		L["eye_glow"] = SkinRules.TIER_EYES[tier]
		if tier == 3:
			var s := float(L.get("strength", 0.0))
			var t: Color = L.get("tint", SkinRules.LATE_TINT)
			L["tint"] = t.lerp(SkinRules.LATE_TINT, SkinRules.LATE_TINT_STRENGTH) if s > 0.0 else SkinRules.LATE_TINT
			L["strength"] = maxf(s, SkinRules.LATE_TINT_STRENGTH)
			if L.has("eyes"):
				L["eyes"] = SkinRules.LATE_EYES
		if bool(ctx.get("elite", false)):
			L["elite"] = true
			L["eye_glow"] = SkinRules.ELITE.eyes
			if L.has("eyes"):
				L["eyes"] = SkinRules.ELITE.eyes
	L["traits"] = (ctx.get("traits", []) as Array).duplicate()
	return L


static func is_boss(id: String) -> bool:
	return bool(DEFS.get(id, {}).get("boss", false))


static func is_miniboss(id: String) -> bool:
	return bool(DEFS.get(id, {}).get("miniboss", false))


## True when a look's body uses the Large rig (board previews shrink those).
static func is_large(id: String, ctx: Dictionary = {}) -> bool:
	return String(Character.MODELS[String(def(id, int(ctx.get("variant", 0))).model)][1]) == "large"


## Ranged attacker (projectile instead of a lunge): "bolt" | "arrow" | "magic" | "".
static func ranged_kind(ch: Character) -> String:
	var L: Dictionary = ch.get_meta("look", {}) if ch else {}
	return String(L.get("ranged", ""))


## Projectile colour for a ranged attacker.
static func shot_color(ch: Character) -> Color:
	var L: Dictionary = ch.get_meta("look", {}) if ch else {}
	return L.get("shot", Color(1.0, 0.9, 0.7) if String(L.get("ranged", "")) in ["bolt", "arrow"] else Color(0.7, 0.4, 1.0))


## Height of the HUD above the feet, in unit-scale model units (big rigs, hats and crowns are
## taller). The tallest variant sets it, so every spawn of an id shares one HUD anchor.
static func hud_height(id: String) -> float:
	if _hud_cache.has(id):
		return _hud_cache[id]
	var h := 0.0
	for v in variant_count(id):
		var d := def(id, v)
		var x := 2.2 * scale_of(id)
		if String(Character.MODELS[String(d.model)][1]) == "large":
			x *= 1.42
		var ex: Array = d.get("extras", [])
		if "crown" in ex or "skull_crest" in ex or "bush_head" in ex or "ice_crown" in ex:
			x += 0.35 * scale_of(id)
		x += float(d.get("hud", 0.0)) * scale_of(id)
		h = maxf(h, x)
	_hud_cache[id] = h
	return h


## Scale multiplier relative to a normal unit (bosses 1.6-1.8).
static func scale_of(id: String) -> float:
	return float(DEFS.get(id, {}).get("scale", 1.0))


## Clip alias for a role (idle | attack | hit | death | spawn | walk | cast | cheer). Each figure
## resolves the alias through its own look (Character.clip_overrides).
static func clip(_id: String, role: String) -> String:
	return role


## `full` adds lights, particles and the mini-boss aura (combat); board previews pass false.
static func create(id: String, full := true, ctx: Dictionary = {}) -> Character:
	var L := look(id, ctx)
	var ch := Character.create(String(L.model), false)
	ch.name = id.to_pascal_case()
	ch.set_meta("enemy_id", id)
	ch.set_meta("look", L)
	ch.set_meta("full", full)
	if String(L.get("texture", "")) != "":
		ch.set_texture(load(String(L.texture)))
	_set_clips(ch, L)
	var gear: Dictionary = L.get("gear", {})
	var xf: Dictionary = L.get("gear_xf", {})
	for slot in gear:
		var inst := ch.attach(slot, gear[slot])
		if inst and xf.has(slot):
			var t: Array = xf[slot]
			inst.position = t[0]
			inst.rotation_degrees = t[1]
			inst.scale = Vector3.ONE * float(t[2])
	if bool(L.get("ghost", false)):
		ch.tint_shader = GHOST_SHADER
	var cracks: Color = L.get("cracks", Color(0, 0, 0, 0))
	if cracks.a > 0.0:
		ch.tint_params["crack_color"] = cracks
		ch.tint_params["crack_scale"] = float(L.get("crack_scale", 3.2 if is_large(id, ctx) else 4.2))
		# board previews are tiny: fewer, simpler cracks so the figure keeps its silhouette
		ch.tint_params["crack_sparsity"] = 0.45 if full else 0.7
	for n in L.get("hide", []):
		_hide_meshes(ch, String(n))
	if bool(L.get("pumpkin", false)):
		_pumpkin_head(ch, float(L.get("pumpkin_scale", 0.62)))
	if L.get("eyes") != null:
		_eyes(ch, L.eyes, L.get("eyes_offset", Vector3.ZERO) + (L.get("eyes_at", Vector3.ZERO) as Vector3))
	for e in L.get("extras", []):
		_extra(ch, L, String(e), full)
	if bool(L.get("elite", false)):
		ch.model.scale *= float(SkinRules.ELITE.scale)
		if full:
			_elite_ring(ch)
	set_traits(ch, L.get("traits", []))
	retint(ch, id)
	if full:
		if L.has("aura"):
			_aura(ch, L.aura)
		if L.has("light"):
			var l := OmniLight3D.new()
			l.name = "BodyLight"
			l.light_color = L.light
			l.light_energy = 1.3 if is_boss(id) else 0.9
			l.omni_range = 3.2
			l.position = Vector3(0.0, 1.4, 0.9)
			ch.add_child(l)
		if bool(L.get("glow", false)):
			var l := OmniLight3D.new()
			l.light_color = Color(0.7, 0.4, 1.0)
			l.light_energy = 2.0
			l.omni_range = 3.0
			l.position = Vector3(0.6, 2.0, 0.6)
			ch.add_child(l)
	ch.play("idle", 0.0)
	ch.anim_player.seek(randf() * 0.8, true)
	return ch


## Per-figure role -> clip table: the rig defaults, the undead set, then the look's clips.
static func _set_clips(ch: Character, L: Dictionary) -> void:
	var large := String(Character.MODELS[String(L.model)][1]) == "large"
	var c := {}
	if large:
		c = {"idle": "Idle_A", "hit": "Hit_A", "death": "Death_A", "spawn": "Melee_Unarmed_Smash", "cheer": "Flexing",
			"cast": "Melee_Unarmed_Smash", "walk": "Walking_A"}
	else:
		c = {"idle": "Idle_A", "hit": ["Hit_A", "Hit_B"], "death": ["Death_A", "Death_B"], "spawn": "Spawn_Ground",
			"cast": "Ranged_Magic_Spellcasting", "walk": "Walking_A"}
		if bool(L.get("undead", false)):
			c.merge({"idle": "Skeletons_Idle", "spawn": "Skeletons_Awaken_Standing", "death": "Skeletons_Death",
				"cheer": "Skeletons_Taunt", "walk": "Skeletons_Walking"}, true)
	c.merge(L.get("clips", {}), true)
	ch.clip_overrides = c


## Re-applies the look's tints (body, parts, eyes, elite gear, trait marks) with an optional
## emission override (hit flash). Use instead of Character.set_tint for enemies.
static func retint(ch: Character, id: String, flash := Color.BLACK) -> void:
	var L: Dictionary = ch.get_meta("look", {}) if ch.has_meta("look") else look(id)
	var em: Color = flash if flash != Color.BLACK else L.get("emission", Color.BLACK)
	if ch.has_meta("shattered"):
		em = Color(1.0, 0.35, 0.04) if flash == Color.BLACK else flash
	var parts: Dictionary = L.get("parts", {})
	var st := float(L.get("strength", 0.0))
	var eye: Color = L.get("eye_glow", Color.BLACK)
	var elite := bool(L.get("elite", false))
	var traits: Array = L.get("traits", [])
	var shader_needed := not parts.is_empty() or eye != Color.BLACK or elite or "pierce" in traits
	# a tiny strength keeps every surface on the tint shader so part / gear tints can apply
	ch.set_tint(L.get("tint", Color.WHITE), maxf(st, 0.001) if shader_needed else st, em)
	for key in parts:
		var pt: Array = parts[key]
		ch.tint_where(func(m: MeshInstance3D) -> bool: return String(m.name).contains(String(key)),
			pt[0], float(pt[1]), pt[2] if pt.size() > 2 else (flash if flash != Color.BLACK else Color.BLACK))
	if eye != Color.BLACK:
		ch.tint_where(func(m: MeshInstance3D) -> bool: return String(m.name).ends_with("_Eyes"),
			eye, 1.0, eye * 1.6 + flash)
	if elite:
		var e: Dictionary = SkinRules.ELITE
		ch.tint_where(func(m: MeshInstance3D) -> bool: return _in_attachment(m, ""), e.gear_tint, float(e.gear_strength),
			(e.gear_emission as Color) + flash, 0.35, 0.85)
	if "pierce" in traits:
		ch.tint_where(func(m: MeshInstance3D) -> bool: return _in_attachment(m, "handslot_r"),
			Color(0.55, 0.08, 0.05), 0.6, Color(0.9, 0.12, 0.04) + flash)


static func _in_attachment(m: Node, slot: String) -> bool:
	var p := m.get_parent()
	while p != null and not (p is Character):
		if String(p.name).begins_with("Attach_" + slot):
			return true
		p = p.get_parent()
	return false


# --- traits: one overlay per trait, the same on every family (SkinRules.TRAITS) -------------

## Shows exactly `traits` on the figure (rebuilds the overlays; call on boss phase changes).
static func set_traits(ch: Character, traits: Array) -> void:
	if not is_instance_valid(ch):
		return
	var L: Dictionary = ch.get_meta("look", {})
	var had: Array = L.get("traits", [])
	var root := ch.get_node_or_null("TraitMarks")
	if root and had == traits:
		return
	if root:
		root.name = "TraitMarksOld"
		root.queue_free()
	for s in ch.skeleton.get_children():
		if String(s.name).begins_with("TraitSocket"):
			s.queue_free()
	L["traits"] = traits.duplicate()
	ch.set_meta("look", L)
	root = Node3D.new()
	root.name = "TraitMarks"
	ch.add_child(root)
	for t in traits:
		_trait_overlay(ch, root, String(t), bool(ch.get_meta("full", true)))
	if ch.has_meta("enemy_id"):
		retint(ch, String(ch.get_meta("enemy_id")))


## Size of the body's bones relative to Rig_Medium (Rig_Large bones are ~2.3x longer).
static func _rig_k(ch: Character) -> float:
	return 2.2 if String(Character.MODELS[ch.model_id][1]) == "large" else 1.0


static func _trait_socket(ch: Character, bone: String) -> Node3D:
	var s := _socket(ch, bone)
	if s:
		s.name = "TraitSocket_" + bone.replace(".", "_")
	return s


static func _trait_overlay(ch: Character, root: Node3D, kind: String, full: bool) -> void:
	var k := _rig_k(ch)
	var col: Color = SkinRules.TRAITS[kind].color if SkinRules.TRAITS.has(kind) else Color.WHITE
	match kind:
		"armor":
			# steel shoulder caps with a rim and rivets, plus a small breastplate
			var ka := 2.5 if k > 1.0 else 1.35
			var steel := _mat(col.lightened(0.15), Color(0.05, 0.06, 0.08), 0.3)
			steel.metallic = 0.3
			var dark := _mat(col.darkened(0.45), Color.BLACK, 0.4)
			dark.metallic = 0.5
			var c := _trait_socket(ch, "chest")
			if c:
				# on the chest bone (chibi arms are thin and hide inside wide torsos): caps sit
				# proud of the shoulders so the silhouette reads "plated" even at preview size
				for sx in [-1.0, 1.0]:
					var at := Vector3(sx * 0.3, 0.36, -0.02) * ka
					var cap := _dome(c, at, 0.17 * ka, steel, true)
					cap.scale = Vector3(1.25, 0.62, 1.15)
					cap.rotation.z = -sx * 0.45
					var rim := _dome(c, at - Vector3(0, 0.01, 0) * ka, 0.19 * ka, dark, true)
					rim.scale = Vector3(1.2, 0.2, 1.15)
					rim.rotation.z = -sx * 0.45
					for j in 3:
						var r := _dome(c, at + Vector3(sx * (0.02 + 0.05 * j), 0.1 - 0.035 * j, 0.1) * ka, 0.025 * ka, dark)
						r.name = "Rivet"
				var cp := _dome(c, Vector3(0, 0.2, 0.2) * ka, 0.19 * ka, steel, true)
				cp.rotation.x = PI * 0.5
				cp.scale = Vector3(1.25, 1.0, 0.5)
				cp.name = "Breastplate"
		"thorns":
			var m := _mat(col.darkened(0.2))
			var c := _trait_socket(ch, "chest")
			if c:
				for i in 7:
					var a := lerpf(-1.1, 1.1, float(i) / 6.0)
					_cone(c, Vector3(sin(a) * 0.36 * k, (0.2 + 0.22 * float(i % 2)) * k, (-cos(a) * 0.26 - 0.08) * k),
						0.06 * k, 0.34 * k, m, Vector3(-1.1, 0, sin(a) * 0.9))
			for b in ["lowerarm.l", "lowerarm.r"]:
				var s := _trait_socket(ch, b)
				if s:
					for j in 2:
						_cone(s, Vector3(0, (0.08 + 0.14 * j) * k, -0.1 * k), 0.045 * k, 0.22 * k, m, Vector3(-1.2, 0, 0))
			_bramble_ring(root, 1.05, col)
		"ward":
			var ring := Biome._rune_circle(col, 1.0)
			ring.name = "WardRunes"
			ring.position.y = 0.05
			(ring.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.9)
			root.add_child(ring)
			if full:
				var p := Fx.elite_sparkle(root, Vector3(0, 0.2, 0), 0.7, 1.8)
				(p.process_material as ParticleProcessMaterial).color = col.lightened(0.3)
		"pierce":
			var s := _trait_socket(ch, "lowerarm.r")
			if s:
				var m := _mat(Color(0.35, 0.05, 0.04), col, 0.4)
				var band := _dome(s, Vector3(0, 0.12 * k, 0), 0.13 * k, _mat(Color(0.18, 0.14, 0.14), Color.BLACK, 0.4))
				band.scale = Vector3(1.0, 1.3, 1.0)
				for j in 5:
					var a := TAU * j / 5.0
					_cone(s, Vector3(cos(a) * 0.12 * k, (0.08 + 0.05 * (j % 2)) * k, sin(a) * 0.12 * k), 0.035 * k, 0.2 * k, m,
						Vector3(sin(a) * 1.4, 0, -cos(a) * 1.4))


## Gold ring + rising motes at an elite's feet (SkinRules.ELITE).
static func _elite_ring(ch: Character) -> void:
	var col: Color = SkinRules.ELITE.ring
	var ring := Biome._rune_circle(col, 0.85)
	ring.name = "EliteRing"
	ring.position.y = 0.035
	(ring.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.8)
	ch.add_child(ring)
	var motes := Fx.elite_sparkle(ch, Vector3(0, 0.1, 0), 0.5, 1.4)
	(motes.process_material as ParticleProcessMaterial).color = col.lightened(0.2)


static func _bramble_ring(parent: Node3D, radius: float, thorn: Color) -> void:
	var ring := Node3D.new()
	ring.name = "Brambles"
	parent.add_child(ring)
	var m := _mat(thorn.darkened(0.25))
	var leaf := [_mat(Color(0.3, 0.46, 0.16)), _mat(Color(0.36, 0.52, 0.2))]
	for k in 14:
		var a := TAU * k / 14.0
		var r := radius + 0.08 * float(k % 3)
		var tuft := _dome(ring, Vector3(cos(a) * r, 0.0, sin(a) * r), 0.14, leaf[k % 2], true)
		tuft.scale = Vector3(1.4, 0.8, 1.1)
		tuft.rotation.y = a
		_cone(ring, Vector3(cos(a) * r, 0.2, sin(a) * r), 0.06, 0.34 + 0.12 * float(k % 2), m,
			Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5))


# --- sockets & procedural pieces ----------------------------------------------------------------

static func _socket(ch: Character, bone: String) -> Node3D:
	if ch.skeleton.find_bone(bone) < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.name = "Socket_" + bone.replace(".", "_")
	ba.bone_name = bone
	ch.skeleton.add_child(ba)
	return ba


static func _hide_meshes(ch: Character, fragment: String) -> void:
	for m in ch.model.find_children("*", "MeshInstance3D", true, false):
		if String(m.name).contains(fragment):
			(m as MeshInstance3D).visible = false


static func _mat(color: Color, emission := Color.BLACK, rough := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 1.5
	return m


static func _blob(parent: Node3D, pos: Vector3, r: float, color: Color, seed := 1, squash := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BiomeBlocks.faceted(BiomeBlocks._sphere(r, 7, 4), color, r * 0.15, seed, color.darkened(0.3), squash)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _dome(parent: Node3D, pos: Vector3, r: float, mat: Material, half := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r if half else r * 2.0
	sm.is_hemisphere = half
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _cone(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Two small glowing eyes on the face (spirits, visors, imps).
static func _eyes(ch: Character, color: Color, offset := Vector3.ZERO) -> void:
	var head := _socket(ch, "head")
	if head == null:
		return
	head.name = "Eyes"
	var big := String(Character.MODELS[ch.model_id][1]) == "large"
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.lightened(0.3)
	var y := 0.42 if not big else 0.36
	var z := 0.4 if not big else 0.36
	var dx := 0.15 if not big else 0.13
	match ch.model_id:
		"knight", "paladin_helm":
			y = 0.5
			z = 0.44
		"mage":
			y = 0.4
			z = 0.42
		"barbarian":
			y = 0.46
			z = 0.44
		"barbarian_large":
			y = 0.5
			z = 0.5
	for sx in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.055
		sm.height = 0.08
		sm.radial_segments = 8
		sm.rings = 4
		e.mesh = sm
		e.material_override = m
		e.position = Vector3(sx * dx, y, z) + offset
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(e)


static func _extra(ch: Character, L: Dictionary, kind: String, full: bool) -> void:
	var k := _rig_k(ch)
	match kind:
		"leaf_crown":
			var h := _socket(ch, "head")
			var leaf: Color = L.get("leaf", Color(0.36, 0.7, 0.24))
			for i in 6:
				var a := TAU * i / 6.0
				var lf := _blob(h, Vector3(cos(a) * 0.36, 0.78 + 0.05 * (i % 2), sin(a) * 0.36), 0.16,
					leaf.lightened(0.08 * (i % 2)), 40 + i, Vector3(1.0, 0.55, 1.0))
				lf.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)
			var bloom := _blob(h, Vector3(0.0, 0.92, 0.1), 0.14, L.get("bloom", Color(1.0, 0.55, 0.72)), 9)
			bloom.name = "Bloom"
			_blob(h, Vector3(0.0, 0.98, 0.14), 0.07, Color(1.0, 0.9, 0.35), 10)
		"leaf_shoulders":
			var leaf: Color = L.get("leaf", Color(0.3, 0.56, 0.2))
			for b in ["upperarm.l", "upperarm.r"]:
				var s := _socket(ch, b)
				if s:
					_blob(s, Vector3(0, 0.1, 0) * k, 0.26 * k, leaf.darkened(0.1), b.length(), Vector3(1.0, 0.7, 1.0))
					_blob(s, Vector3(0.12, 0.22, -0.05) * k, 0.16 * k, leaf, 3)
		"leaf_motes":
			if full:
				var p := Fx.elite_sparkle(ch, Vector3(0, 0.3, 0), 0.5, 1.6)
				(p.process_material as ParticleProcessMaterial).color = Color(0.6, 1.0, 0.4)
		"fur_collar":
			var c := _socket(ch, "chest")
			var fur: Color = L.get("fur", Color(0.6, 0.6, 0.62))
			for i in 9:
				var a := TAU * i / 9.0
				_blob(c, Vector3(cos(a) * 0.3, 0.32 + 0.04 * (i % 2), sin(a) * 0.26 - 0.02), 0.17,
					fur.lightened(0.08 * (i % 3)), 60 + i, Vector3(1.0, 0.8, 1.0))
		"float":
			for n in ["LegLeft", "LegRight"]:
				_hide_meshes(ch, n)
			ch.model.position.y = 0.45
			var t := ch.model.create_tween().set_loops()
			t.tween_property(ch.model, "position:y", 0.62, 1.3).set_trans(Tween.TRANS_SINE)
			t.tween_property(ch.model, "position:y", 0.45, 1.3).set_trans(Tween.TRANS_SINE)
		"wisp_trail":
			if full:
				var p := Fx.elite_sparkle(ch, Vector3(0, 0.3, 0), 0.35, 0.8)
				(p.process_material as ParticleProcessMaterial).color = L.get("shot", Color(0.5, 1.0, 0.9))
		"shoulder_ice":
			for b in ["upperarm.l", "upperarm.r"]:
				var s := _socket(ch, b)
				if s:
					var cc := BiomeBlocks.crystal_cluster(s, Vector3(0, 0.12, 0), 0.32, 3, b.length() * 3, false)
					cc.rotation.z = 0.3 if b.ends_with("l") else -0.3
		"ice_crown":
			var h := _socket(ch, "head")
			var y := 0.95 if ch.model_id in ["knight", "paladin_helm"] else 0.8
			for i in 5:
				var a := TAU * i / 5.0
				var cr := MeshInstance3D.new()
				cr.mesh = BiomeBlocks.crystal_mesh()
				cr.material_override = BiomeBlocks.crystal_material()
				var s := 0.5 if i == 0 else 0.34
				cr.scale = Vector3(s, s * (1.3 if i == 0 else 1.0), s)
				cr.position = Vector3(cos(a) * 0.22, y - 0.1, sin(a) * 0.22) if i > 0 else Vector3(0, y, 0)
				cr.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35) if i > 0 else Vector3.ZERO
				h.add_child(cr)
		"frost_mist":
			if full:
				var p := Fx.elite_sparkle(ch, Vector3(0, 0.1, 0), 0.55, 1.2)
				(p.process_material as ParticleProcessMaterial).color = Color(0.75, 0.92, 1.0)
		"horns":
			var h := _socket(ch, "head")
			var m := _mat(Color(0.12, 0.08, 0.08), Color(0.3, 0.08, 0.0))
			for sx in [-1.0, 1.0]:
				_cone(h, Vector3(sx * 0.3, 0.85, 0.05), 0.14, 0.52, m, Vector3(0.25, 0, -sx * 0.6))
		"head_flame":
			if full:
				var h := _socket(ch, "head")
				Biome.flame(h, Vector3(0, 0.95, 0), L.get("light", Color(1.0, 0.5, 0.12)), 0.35, 10)
		"hand_flame_green":
			if full:
				var s := _socket(ch, "handslot.l")
				if s:
					Biome.flame(s, Vector3(0, 0.25, 0), Color(0.4, 1.0, 0.55), 0.3, 8)
		"motes":
			if full:
				var p := Fx.elite_sparkle(ch, Vector3(0, 0.3, 0), 0.7, 2.2)
				(p.process_material as ParticleProcessMaterial).color = L.get("mote", Color.WHITE)
		"embers":
			if full:
				var p := Fx.elite_sparkle(ch, Vector3(0, 0.2, 0), 0.6, 2.0)
				(p.process_material as ParticleProcessMaterial).color = Color(1.0, 0.5, 0.15)
		"shoulder_flames":
			for b in ["upperarm.l", "upperarm.r"]:
				var s := _socket(ch, b)
				if s and full:
					Biome.flame(s, Vector3(0, 0.25, 0) * k, Color(1.0, 0.5, 0.12), 0.3 * k, 8)
		"thorns_back":
			var c := _socket(ch, "chest")
			var m := _mat(Color(0.42, 0.28, 0.16))
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i in 9:
				var a := lerpf(-1.2, 1.2, float(i) / 8.0)
				var y := 0.25 + 0.3 * float(i % 3)
				_cone(c, Vector3(sin(a) * 0.45, y, -cos(a) * 0.3 - 0.1) * k, 0.07 * k, 0.42 * k, m,
					Vector3(-1.1 + rng.randf() * 0.3, 0, sin(a) * 0.9))
		"thorns_front":
			var m := _mat(Color(0.52, 0.32, 0.15))
			for b in ["upperarm.l", "upperarm.r", "upperleg.l", "upperleg.r"]:
				var s := _socket(ch, b)
				if s:
					for j in 3:
						var a := float(j) * 2.1
						_cone(s, Vector3(cos(a) * 0.2, 0.1 + 0.14 * j, sin(a) * 0.2) * k, 0.08 * k, 0.42 * k, m,
							Vector3(sin(a) * 1.2, 0, -cos(a) * 1.2))
		"bone_pauldrons":
			for b in ["upperarm.l", "upperarm.r"]:
				var s := _socket(ch, b)
				if s:
					var sk := Props.put(s, Props.HAL + "skull.gltf", Vector3(0, 0.12, 0) * k, 0.0, 0.42 * k)
					sk.rotation.y = PI * (0.5 if b.ends_with("l") else -0.5)
		"skull_crest":
			var h := _socket(ch, "head")
			var sk := Props.put(h, Props.HAL + "skull.gltf", Vector3(0, 1.0, 0.05), 0.0, 0.36)
			sk.name = "Crest"
		"bramble_ring":
			_bramble_ring(ch, 1.15, Color(0.52, 0.32, 0.16))
		"grave_candles":
			if full:
				for j in 3:
					var a := TAU * j / 3.0 + 0.5
					var cd := Props.put(ch, Props.HAL + "candle_triple.gltf", Vector3(cos(a) * 0.9, 0, sin(a) * 0.9), 0.0, 0.5)
					cd.name = "Candle%d" % j
					Biome.flame(cd, Vector3(0, 0.5, 0), Color(0.45, 1.0, 0.55), 0.12, 4)
		"crown":
			_crown(ch)
		"rock_shell":
			_rock_shell(ch)


## A gold crown with glowing ember gems (Cinder King, the Lich).
static func _crown(ch: Character) -> void:
	var h := _socket(ch, "head")
	h.name = "Crown"
	var k := _rig_k(ch)
	var y := {"skel_mage": 0.78, "barbarian_large": 0.62}.get(ch.model_id, 0.8) as float
	var gold := _mat(Color(1.0, 0.72, 0.2), Color(0.4, 0.18, 0.0), 0.3)
	gold.metallic = 0.8
	var band := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.36
	cm.height = 0.16
	cm.radial_segments = 10
	cm.rings = 1
	band.mesh = cm
	band.material_override = gold
	band.position = Vector3(0, y, 0)
	h.add_child(band)
	var gem := _mat(Color(1.0, 0.3, 0.05), Color(1.0, 0.35, 0.05))
	for i in 7:
		var a := TAU * i / 7.0
		_cone(h, Vector3(cos(a) * 0.37, y + 0.18, sin(a) * 0.37), 0.08, 0.26 if i % 2 == 0 else 0.18, gold)
		if i % 2 == 0:
			var g := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.05
			sm.height = 0.1
			g.mesh = sm
			g.material_override = gem
			g.position = Vector3(cos(a) * 0.4, y, sin(a) * 0.4)
			h.add_child(g)
	if k > 1.0:
		h.scale = Vector3.ONE * 1.3


## Grey faceted rock plates over the Golem's glowing body; each piece is tagged so shatter()
## can throw them off.
static func _rock_shell(ch: Character) -> void:
	var rock := Color(0.52, 0.47, 0.46)
	# sized for the Large rig (its chest is ~2 units wide): plates sit proud of the body so the
	# lava glow shows only in the gaps between them
	var pieces := {
		"chest": [[Vector3(0, 0.3, 0.42), 0.62, Vector3(1.35, 1.0, 0.62)], [Vector3(0, 0.45, -0.4), 0.62, Vector3(1.3, 1.0, 0.6)],
			[Vector3(0.55, 0.7, 0.05), 0.42, Vector3.ONE], [Vector3(-0.55, 0.7, 0.05), 0.42, Vector3.ONE]],
		"spine": [[Vector3(0, 0.05, 0.4), 0.5, Vector3(1.3, 0.7, 0.62)]],
		"head": [[Vector3(0, 0.36, 0.02), 0.46, Vector3(1.0, 0.9, 1.0)]],
		"upperarm.l": [[Vector3(0, 0.2, 0), 0.44, Vector3.ONE]], "upperarm.r": [[Vector3(0, 0.2, 0), 0.44, Vector3.ONE]],
		"lowerarm.l": [[Vector3(0, 0.3, 0), 0.36, Vector3(0.95, 1.2, 0.95)]], "lowerarm.r": [[Vector3(0, 0.3, 0), 0.36, Vector3(0.95, 1.2, 0.95)]],
		"upperleg.l": [[Vector3(0, -0.25, 0.08), 0.34, Vector3(1.0, 1.3, 1.0)]], "upperleg.r": [[Vector3(0, -0.25, 0.08), 0.34, Vector3(1.0, 1.3, 1.0)]],
		"lowerleg.l": [[Vector3(0, -0.2, 0.1), 0.3, Vector3(1.0, 1.2, 1.0)]], "lowerleg.r": [[Vector3(0, -0.2, 0.1), 0.3, Vector3(1.0, 1.2, 1.0)]],
	}
	var k := 0
	for b in pieces:
		var s := _socket(ch, String(b))
		if s == null:
			continue
		for p in pieces[b]:
			var mi := _blob(s, p[0], float(p[1]), rock.lightened(0.05 * (k % 3)), 200 + k, p[2])
			mi.name = "Shell%d" % k
			if b != "head":
				# the rock head stays on after the shatter (the eyes live on it)
				mi.add_to_group("golem_shell")
				mi.set_meta("shell", true)
			k += 1


## Magma Golem phase 2: the rock shell cracks off (pieces fly out and fall), the body flares.
static func shatter(ch: Character) -> void:
	if not is_instance_valid(ch) or ch.has_meta("shattered"):
		return
	ch.set_meta("shattered", true)
	var world := ch.get_parent() as Node3D
	for mi in ch.find_children("Shell*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if not m.has_meta("shell"):
			continue
		var gt := m.global_transform
		m.get_parent().remove_child(m)
		if world == null:
			m.queue_free()
			continue
		world.add_child(m)
		m.global_transform = gt
		var out := (gt.origin - ch.global_position)
		out.y = 0.0
		out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
		var dest := gt.origin + out * randf_range(1.2, 2.2) + Vector3.UP * randf_range(0.3, 0.9)
		var t := m.create_tween()
		t.set_parallel(true)
		t.tween_property(m, "global_position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(m, "rotation", m.rotation + Vector3(randf_range(-2, 2), randf_range(-2, 2), 0), 0.9)
		t.chain().tween_property(m, "global_position:y", ch.global_position.y - 0.2, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.chain().tween_property(m, "scale", Vector3.ONE * 0.01, 0.4)
		t.chain().tween_callback(m.queue_free)
	var id := String(ch.get_meta("enemy_id", "boss_magma_golem"))
	retint(ch, id)
	if world:
		Fx.burst(world, ch.global_position + Vector3.UP * 1.6, {"amount": 40, "lifetime": 1.0, "speed": Vector2(2.0, 6.0),
			"gravity": Vector3(0, -9, 0), "size": 0.3, "color": Color(1.0, 0.5, 0.15), "tex": "spark", "spread": 80.0})


## Mini-boss aura: a coloured rim light and slow rising motes around the figure.
static func _aura(ch: Character, color: Color) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 1.6
	l.omni_range = 3.2
	l.position = Vector3(0.0, 1.6, -0.9)
	ch.add_child(l)
	var motes := Fx.elite_sparkle(ch, Vector3(0, 0.1, 0), 0.75, 2.2)
	(motes.process_material as ParticleProcessMaterial).color = color.lightened(0.2)
	var ring := Biome._rune_circle(color, 1.05)
	ring.name = "AuraRing"
	ring.position.y = 0.04
	(ring.material_override as ShaderMaterial).set_shader_parameter("intensity", 0.7)
	ch.add_child(ring)


static func _pumpkin_head(ch: Character, k := 0.62) -> void:
	for m in ch.model.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name).to_lower()
		if n.contains("head") or n.contains("hat") or n.contains("helmet"):
			(m as MeshInstance3D).visible = false
	var p := ch.attach("head", "res://assets/kaykit/halloween/pumpkin_orange_jackolantern.gltf")
	if p:
		p.scale = Vector3.ONE * k
		p.position = Vector3(0, 0.1, 0.05)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.15)
		l.light_energy = 1.5
		l.omni_range = 2.5
		l.position = Vector3(0, 0.5, 0.9)
		p.add_child(l)

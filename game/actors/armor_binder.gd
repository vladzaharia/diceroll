class_name ArmorBinder
extends RefCounted
## Armor on the real character parts (docs/design/2026-09-29-armory-items.md §8.2, §8.4).
##
## Every Medium-rig character GLB shares the Rig_Medium bone names, and Godot imports the glTF
## skins with *named* binds, so a donor's skinned MeshInstance3D can be moved under the hero's
## Skeleton3D and keep its own Skin: it then follows the hero's animation. Rigid donor pieces
## (the Paladin cape, the skeleton helmets / hoods, parented to a bone in the GLB) move to a
## BoneAttachment3D on the same bone of the hero.
##
##   ArmorBinder.apply(hero, {head = "wizard_hat", body = "ninja_gi", back = "mage_cape",
##       appearance = {head = "piece" | "own" | "hidden" | <head id>, body = "piece" | "own" | <body id>}})
##
## Slot keys left out keep the hero's own parts. head "" = no headwear; back "" = no back piece.
## Donor meshes carry meta "donor" (their GLB path); Character.set_texture skips them unless
## they share the hero's atlas family (Rogue <-> Rogue_Hooded, Paladin <-> Paladin_with_Helmet).

## Head fit per (hero model, head piece), from the armor_fit screenshot pass (every hero x every
## head, `armor_fit --hero=<model> --zoom=head`). Missing pairs are "ok". Hair volume decides it:
## the skeleton pieces (helm_bone, hat_grave, hood_grave) are cut for bald skulls, so hair pokes
## through unless they grow; the Barbarian (bald) wears everything as authored.
##   "bad"        : falls back to appearance hidden (the stat still applies; the Armory shows an "i")
##   {scale, off} : the piece is scaled about the head bone (the neck) and nudged (bone space)
##   {swap_head}  : the hero's head is replaced (SWAP_BY_MODEL, else SWAP_HEAD) under the piece
## "*|<head>" would be the piece's default for every hero.
const HEAD_FIT := {
	"knight|wizard_hat": {"scale": 1.04}, "knight|helm_bone": {"scale": 1.1},
	"knight|hat_grave": {"scale": 1.1}, "knight|hood_grave": {"scale": 1.1},
	"mage|ninja_headband": {"scale": 1.08, "off": Vector3(0.0, -0.02, 0.05)},
	"mage|ninja_mask": {"scale": 1.08, "off": Vector3(0.0, -0.02, 0.05)},
	"mage|helm_bone": {"scale": 1.08}, "mage|hood_grave": {"scale": 1.15},
	"rogue|ninja_headband": {"scale": 1.08, "off": Vector3(0.0, -0.02, 0.06)},
	"rogue|ninja_mask": {"scale": 1.08, "off": Vector3(0.0, -0.02, 0.06)}, "rogue|helm_bone": {"scale": 1.13},
	"rogue|hat_grave": {"scale": 1.12}, "rogue|hood_grave": {"scale": 1.17},
	"rogue_hooded|ninja_headband": {"scale": 1.1, "off": Vector3(0.0, -0.02, 0.06)},
	"rogue_hooded|ninja_mask": {"scale": 1.1, "off": Vector3(0.0, -0.02, 0.06)},
	"rogue_hooded|helm_bone": {"swap_head": true, "scale": 1.13},
	"rogue_hooded|hat_grave": {"swap_head": true, "scale": 1.12},
	"rogue_hooded|hood_grave": {"swap_head": true, "scale": 1.17},
	"ranger|wizard_hat": {"scale": 1.05}, "ranger|bear_hat": {"scale": 1.08}, "ranger|goggles": {"scale": 1.1},
	"ranger|ninja_headband": {"scale": 1.12, "off": Vector3(0.0, -0.02, 0.08)},
	"ranger|ninja_mask": {"scale": 1.12, "off": Vector3(0.0, -0.02, 0.08)},
	"ranger|helm_bone": {"scale": 1.2}, "ranger|hat_grave": {"scale": 1.15}, "ranger|hood_grave": {"scale": 1.2},
	# the Druid's antler hood goes through every hat: the hood swaps to a plain head under it
	"druid|knight_helm": {"swap_head": true}, "druid|wizard_hat": {"swap_head": true},
	"druid|bear_hat": {"swap_head": true}, "druid|ninja_headband": {"swap_head": true, "scale": 1.1},
	"druid|ninja_mask": {"swap_head": true, "scale": 1.1}, "druid|helm_bone": {"swap_head": true, "scale": 1.13},
	"druid|hat_grave": {"swap_head": true, "scale": 1.12}, "druid|hood_grave": {"swap_head": true, "scale": 1.17},
	# the Engineer's beard swallows face masks
	"engineer|bandit_mask": "bad", "engineer|ninja_mask": "bad", "engineer|helm_bone": {"scale": 1.12},
	"engineer|hat_grave": {"scale": 1.08}, "engineer|hood_grave": {"scale": 1.12},
	"paladin|wizard_hat": {"scale": 1.1}, "paladin|helm_bone": {"scale": 1.14},
	"paladin|hat_grave": {"scale": 1.15}, "paladin|hood_grave": {"scale": 1.15},
	# the top-knot pierces the hood
	"ninja|hood_grave": "bad",
	# the Dino Suit hood is huge and locked (§4.3): only small toppers sit on it
	"monster_kid|knight_helm": "bad", "monster_kid|paladin_helm": "bad", "monster_kid|bear_hat": "bad",
	"monster_kid|ninja_headband": "bad", "monster_kid|ninja_mask": "bad", "monster_kid|bandit_mask": "bad",
	"monster_kid|helm_bone": "bad", "monster_kid|hat_grave": "bad", "monster_kid|hood_grave": "bad",
	"monster_kid|wizard_hat": {"scale": 1.08},
}

## swap_head source per hero (same texture family where there is one: the hooded rogue shows the
## Rogue's face, so its skin still applies).
const SWAP_BY_MODEL := {
	"rogue_hooded": {"glb": ItemMounts.CHR + "Rogue.glb", "parts": ["Rogue_Head"]},
	"druid": {"glb": ItemMounts.CHR + "Rogue.glb", "parts": ["Rogue_Head"]},
}

## Rig_Large pieces on a Medium hero (the Bear Pelt). Per-bone scaling can't work: Rig_Large's
## chest-to-head distance is 1.14 against Rig_Medium's 0.27 (the chibi head sits on the chest), so
## the piece is re-posed as a whole: its rest shape is scaled by `scale` about the Large `anchor`
## bone, moved onto the Medium hero's anchor (+ `off`), and every bind is rebuilt against the
## hero's rest pose, so it still follows the chest / spine / head it is weighted to.
const LARGE_FIT := {"scale": 0.7, "anchor": "head", "off": Vector3(0.0, -0.06, -0.04)}
## Result of the Bear Pelt fit test on Medium heroes ("pass" | "fail"): a fail keeps the pelt
## off Medium heroes (only the Barbarian's Chieftain skin offers it, §4.5).
const BEAR_PELT_ON_MEDIUM := "pass"

## Fallback head for swap_head (a plain hero face).
const SWAP_HEAD := {"glb": ItemMounts.CHR + "Knight.glb", "parts": ["Knight_Head"]}

## (glb|part|scale|off) -> Skin (fitted duplicates, built once).
static var _skin_cache: Dictionary = {}


## Fit entry for a hero model + head piece: {fit: "ok"|"scale"|"swap_head"|"bad", scale, off}.
static func head_fit(model_id: String, head_id: String) -> Dictionary:
	var f: Variant = HEAD_FIT.get("%s|%s" % [model_id, head_id], HEAD_FIT.get("*|" + head_id, "ok"))
	if f is Dictionary:
		var d: Dictionary = f
		var fit_mode := "swap_head" if d.get("swap_head", false) else "scale"
		return {"fit": fit_mode, "scale": float(d.get("scale", 1.0)), "off": d.get("off", Vector3.ZERO)}
	return {"fit": String(f), "scale": 1.0, "off": Vector3.ZERO}


## Applies the head / body / back of a loadout to a freshly unequipped Character.
static func apply(ch: Character, lo: Dictionary) -> void:
	var pm: Dictionary = Character.PART_MAP.get(ch.model_id, {})
	var look: Dictionary = lo.get("appearance", {})
	if lo.has("head"):
		_apply_head(ch, pm, String(lo.head), String(look.get("head", "piece")))
	if lo.has("body"):
		_apply_body(ch, pm, String(lo.body), String(look.get("body", "piece")))
	if lo.has("back"):
		_apply_back(ch, pm, String(lo.back))


static func _apply_head(ch: Character, pm: Dictionary, id: String, mode: String) -> void:
	if not mode in ["piece", "own", "hidden"]:
		id = mode    # appearance shows another owned head piece
		mode = "piece"
	if mode == "own":
		return
	if id == "":
		mode = "hidden"
	var row := ItemMounts.piece("head", id)
	var fit := head_fit(ch.model_id, id)
	if mode == "piece" and (row.is_empty() or fit.fit == "bad"):
		mode = "hidden"
	ch.show_parts(pm.get("headwear", []), false)
	if mode == "hidden":
		return
	if ch.has_parts(row.parts):
		ch.show_parts(row.parts, true)
		return
	var covers := bool(row.get("covers_head", false))
	if covers or fit.fit == "swap_head":
		ch.show_parts(pm.get("head", []), false)
	if fit.fit == "swap_head" and not covers:
		var sw: Dictionary = SWAP_BY_MODEL.get(ch.model_id, row.get("swap", SWAP_HEAD))
		bind(ch, String(sw.glb), sw.parts)
	bind(ch, String(row.glb), row.parts, fit.scale, fit.off)


static func _apply_body(ch: Character, pm: Dictionary, id: String, mode: String) -> void:
	if not mode in ["piece", "own"]:
		id = mode
		mode = "piece"
	if id == "" or mode == "own":
		return
	var row := ItemMounts.piece("body", id)
	if row.is_empty() or ch.has_parts(row.parts):
		return
	ch.show_parts(pm.get("body", []) + pm.get("arms", []), false)
	if row.get("covers_head", false):
		ch.show_parts(pm.get("head", []) + pm.get("headwear", []), false)
	bind(ch, String(row.glb), row.parts)


static func _apply_back(ch: Character, pm: Dictionary, id: String) -> void:
	var row := ItemMounts.piece("back", id)
	ch.show_parts(pm.get("back", []), false)
	if row.is_empty():
		return
	if ch.has_parts(row.parts):
		ch.show_parts(row.parts, true)
		return
	if row.get("large", false) and String(Character.MODELS[ch.model_id][1]) != "large":
		if BEAR_PELT_ON_MEDIUM != "pass":
			return
		bind(ch, String(row.glb), row.parts, 1.0, Vector3.ZERO, LARGE_FIT)
		return
	var nodes := bind(ch, String(row.glb), row.parts)
	if row.has("texture"):
		_retexture(nodes, load(String(row.texture)))


## Moves the named donor meshes from `glb` onto the hero's skeleton. `scale` / `off` fit the
## piece about its bones (bone-local space). Returns the added nodes (also tracked by the
## Character, freed by unequip()).
static func bind(ch: Character, glb: String, parts: Array, scale := 1.0, off := Vector3.ZERO,
		repose := {}) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not ResourceLoader.exists(glb):
		push_warning("ArmorBinder: missing donor %s" % glb)
		return out
	var donor: Node = (load(glb) as PackedScene).instantiate()
	var dskel: Skeleton3D = donor.find_child("Skeleton3D", true, false)
	var fit := Transform3D(Basis.from_scale(Vector3.ONE * scale), off)
	for pname in parts:
		var mi := donor.find_child(String(pname), true, false) as MeshInstance3D
		if mi == null:
			push_warning("ArmorBinder: %s has no part %s" % [glb.get_file(), pname])
			continue
		var parent := mi.get_parent()
		mi.owner = null
		var node: Node3D
		if parent is BoneAttachment3D:
			# rigid piece: same bone on the hero
			var ba := BoneAttachment3D.new()
			ba.name = "Donor_" + String(pname)
			ba.bone_name = (parent as BoneAttachment3D).bone_name
			ch.skeleton.add_child(ba)
			var local := mi.transform
			parent.remove_child(mi)
			ba.add_child(mi)
			mi.transform = fit * local
			node = ba
		else:
			parent.remove_child(mi)
			mi.name = "Donor_" + String(pname)
			ch.skeleton.add_child(mi)
			mi.skeleton = NodePath("..")
			if mi.skin and not repose.is_empty():
				mi.skin = _reposed_skin(mi.skin, dskel, ch.skeleton, repose, "%s|%s|%s" % [glb, pname, repose])
			elif mi.skin:
				mi.skin = _fitted_skin(mi.skin, dskel, "%s|%s|%s|%s" % [glb, pname, scale, off], fit)
			if mi.skin:
				mi.skin = _on_skeleton(mi.skin, ch.skeleton, "%s|%s|%s|%s|%s" % [glb, pname, scale, off, ch.model_id])
			node = mi
		node.owner = ch.model
		mi.owner = ch.model
		mi.set_meta("donor", glb)
		out.append(node)
	donor.free()
	ch.track_worn(out)
	return out


## Gives donor meshes an atlas their GLB lacks.
static func _retexture(nodes: Array, tex: Texture2D) -> void:
	for n in nodes:
		var meshes: Array = [n] if n is MeshInstance3D else n.find_children("*", "MeshInstance3D", true, false)
		for mi: MeshInstance3D in meshes:
			for sidx in mi.mesh.get_surface_count():
				var base := mi.get_active_material(sidx) as BaseMaterial3D
				if base:
					var m := base.duplicate() as BaseMaterial3D
					m.albedo_texture = tex
					mi.set_surface_override_material(sidx, m)


## The donor Skin, with every bind named (rebuilt from the donor skeleton if a bind is by
## index) and pre-multiplied by `fit` (identity: the Skin is shared as-is).
static func _fitted_skin(skin: Skin, dskel: Skeleton3D, key: String, fit: Transform3D) -> Skin:
	var named := true
	for i in skin.get_bind_count():
		if skin.get_bind_name(i) == &"":
			named = false
			break
	if named and fit == Transform3D.IDENTITY:
		return skin
	if _skin_cache.has(key):
		return _skin_cache[key]
	var s := skin.duplicate() as Skin
	for i in s.get_bind_count():
		if s.get_bind_name(i) == &"" and dskel and s.get_bind_bone(i) >= 0:
			s.set_bind_name(i, dskel.get_bone_name(s.get_bind_bone(i)))
		s.set_bind_pose(i, fit * s.get_bind_pose(i))
	_skin_cache[key] = s
	return s


## A skin whose binds place the donor's rest shape (scaled about the donor's anchor bone) on the
## hero's anchor bone: bind(b) = hero_rest(b)^-1 * T, T = move(hero anchor + off) * scale * move(-donor anchor).
static func _reposed_skin(skin: Skin, dskel: Skeleton3D, hskel: Skeleton3D, fit: Dictionary, key: String) -> Skin:
	if _skin_cache.has(key):
		return _skin_cache[key]
	var anchor := String(fit.get("anchor", "head"))
	var from := dskel.get_bone_global_rest(dskel.find_bone(anchor)).origin
	var to := hskel.get_bone_global_rest(hskel.find_bone(anchor)).origin + (fit.get("off", Vector3.ZERO) as Vector3)
	var k := float(fit.get("scale", 1.0))
	var t := Transform3D(Basis.from_scale(Vector3.ONE * k), to - from * k)
	var s := skin.duplicate() as Skin
	for i in s.get_bind_count():
		var bone := String(s.get_bind_name(i))
		if bone == "" and s.get_bind_bone(i) >= 0:
			bone = dskel.get_bone_name(s.get_bind_bone(i))
			s.set_bind_name(i, bone)
		var hb := hskel.find_bone(bone)
		if hb < 0:
			continue
		# mesh vertices are in the donor's model space: T moves them into the hero's
		s.set_bind_pose(i, hskel.get_bone_global_rest(hb).affine_inverse() * t)
	_skin_cache[key] = s
	return s


## The Skin with binds to bones the hero lacks (the mannequins have no hand slots) moved to the
## nearest bone it has (handslot.l -> hand.l), so the donor still binds cleanly.
static func _on_skeleton(skin: Skin, hskel: Skeleton3D, key: String) -> Skin:
	var missing := false
	for i in skin.get_bind_count():
		var n := String(skin.get_bind_name(i))
		if n != "" and hskel.find_bone(n) < 0:
			missing = true
			break
	if not missing:
		return skin
	if _skin_cache.has("sk|" + key):
		return _skin_cache["sk|" + key]
	var s := skin.duplicate() as Skin
	for i in s.get_bind_count():
		var n := String(s.get_bind_name(i))
		if n == "" or hskel.find_bone(n) >= 0:
			continue
		var alt := n.replace("handslot", "hand")
		s.set_bind_name(i, alt if hskel.find_bone(alt) >= 0 else hskel.get_bone_name(0))
	_skin_cache["sk|" + key] = s
	return s


static func clear_cache() -> void:
	_skin_cache.clear()

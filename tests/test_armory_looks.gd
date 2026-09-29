extends "res://tests/test_case.gd"
## Armory presentation (game/actors/item_mounts.gd, armor_binder.gd, Character loadouts):
## PART_MAP matches the GLBs, every mount / piece resolves to a real scene, loadouts attach and
## detach cleanly, armor binds donor meshes to the hero skeleton, and the attack follows the weapon.

const ATTACK_CLIPS := ["Melee_1H_Attack_Slice_Diagonal", "Melee_2H_Attack_Slice", "Melee_1H_Attack_Chop",
	"Melee_2H_Attack_Chop", "Melee_2H_Attack_Stab", "Melee_2H_Attack_Spin", "Melee_1H_Attack_Stab",
	"Melee_1H_Attack_Slice_Horizontal", "Ranged_Magic_Shoot", "Ranged_Magic_Spellcasting", "Ranged_Bow_Release",
	"Ranged_1H_Shoot", "Ranged_2H_Shoot", "Melee_Unarmed_Attack_Punch_A", "Melee_2H_Idle", "Ranged_Bow_Idle"]


func _assets() -> bool:
	return ResourceLoader.exists(String(Character.MODELS["knight"][0])) \
		and ResourceLoader.exists(String(Character.MODELS["monster_kid"][0]))


## Mesh node names of a character GLB (instantiated once).
func _mesh_names(path: String) -> PackedStringArray:
	var n: Node = (load(path) as PackedScene).instantiate()
	var out := PackedStringArray()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		out.append(String(mi.name))
	n.free()
	return out


func test_part_map_covers_every_model() -> void:
	if not _assets():
		return
	for id in Character.MODELS:
		assert_true(Character.PART_MAP.has(id), "PART_MAP has no %s" % id)
	for id in Character.PART_MAP:
		assert_true(Character.MODELS.has(id), "PART_MAP %s is not a model" % id)
		var names := _mesh_names(String(Character.MODELS[id][0]))
		var pm: Dictionary = Character.PART_MAP[id]
		for key in ["head", "headwear", "body", "arms", "back"]:
			assert_true(pm.has(key), "%s PART_MAP lacks %s" % [id, key])
		for key in pm:
			for part in pm[key]:
				assert_true(names.has(String(part)), "%s: no mesh %s (%s)" % [id, part, key])


func test_every_mount_and_piece_resolves() -> void:
	if not _assets():
		return
	for m in ItemMounts.MOUNTS:
		var r: Dictionary = ItemMounts.MOUNTS[m]
		assert_true(ResourceLoader.exists(String(r.scene)), "missing scene %s" % r.scene)
		assert_true(ItemMounts.SOCKETS.has(String(r.socket)), "%s: unknown socket %s" % [m, r.socket])
		assert_true(ItemMounts.BASES.has(String(r.base)), "%s: unknown base %s" % [m, r.base])
	for id in ItemMounts.ITEMS:
		var it: Dictionary = ItemMounts.ITEMS[id]
		assert_true(ItemMounts.MOUNTS.has(String(it.model)), "%s: no mount %s" % [id, it.model])
		for k in ["model_2h", "model_left"]:
			if it.has(k):
				assert_true(ItemMounts.MOUNTS.has(String(it[k])), "%s: no mount %s" % [id, it[k]])
		if String(ItemMounts.base_of(id).get("slot", "")) == "weapon":
			var clip := ItemMounts.clip(id)
			assert_true(ATTACK_CLIPS.has(clip), "%s: attack clip %s not verified" % [id, clip])
			assert_true(Character.ATTACKS.has(ItemMounts.style(id)), "%s: style %s not in ATTACKS" % [id, ItemMounts.style(id)])
	for t in [ItemMounts.HEADS, ItemMounts.BODIES, ItemMounts.BACKS]:
		for id in t:
			var names := _mesh_names(String(t[id].glb))
			for part in t[id].parts:
				assert_true(names.has(String(part)), "%s: %s has no %s" % [id, String(t[id].glb).get_file(), part])


func test_attack_aliases_exist_in_rig() -> void:
	if not _assets():
		return
	var ch := Character.create("knight")
	for a in ["crossbow", "spear", "scythe"]:
		assert_true(ch.anim_player.has_animation(String(Character.ATTACKS[a])), "no clip for %s" % a)
	for c in ATTACK_CLIPS:
		assert_true(ch.anim_player.has_animation(c), "Rig_Medium lacks %s" % c)
	ch.free()


func test_every_class_kit_builds() -> void:
	if not _assets():
		return
	for cid in Character.KITS:
		var lo := Character.kit(cid)
		var ch := Character.create(String(lo.model), String(lo.get("skin", "")), lo)
		assert_true(ch.resolve("attack") != "", "%s kit: no attack clip" % cid)
		assert_true(ch.style() in ["melee", "ranged", "magic"], "%s kit: bad style" % cid)
		ch.free()


func test_legacy_create_signature() -> void:
	if not _assets():
		return
	var bare := Character.create("knight", false)
	assert_eq(bare._attachments.size(), 0, "with_gear=false attaches nothing")
	bare.free()
	var dressed := Character.create("knight")
	assert_true(dressed._attachments.has("handslot.r") and dressed._attachments.has("handslot.l"), "default gear")
	assert_eq(dressed.style(), "melee")
	dressed.free()
	var mage := Character.create("mage")
	assert_eq(mage.style(), "magic")
	mage.free()
	var ranger := Character.create("ranger")
	assert_eq(ranger.style(), "ranged")
	ranger.free()


func test_loadout_attach_detach() -> void:
	if not _assets():
		return
	var ch := Character.create("knight", "", {"weapon": "sword_saber", "offhand": "round_shield",
		"trinket": "compass", "trinket2": "lantern"})
	assert_eq(ch._attachments.keys().size(), 4, "weapon, shield, two trinkets")
	for s in ["handslot.r", "handslot.l", "hip", "hip2"]:
		assert_true(ch._attachments.has(s), "socket %s" % s)
	assert_eq(ch.resolve("attack"), "Melee_1H_Attack_Slice_Diagonal")
	# 2H weapon: the hand shield is blocked, the spellbook moves to the belt
	ch.equip({"weapon": "greatsword", "offhand": "round_shield"})
	assert_true(not ch._attachments.has("handslot.l"), "2H blocks the shield")
	assert_eq(ch.resolve("attack"), "Melee_2H_Attack_Slice")
	ch.equip({"weapon": "arcane_staff", "offhand": "spellbook"})
	assert_true(ch._attachments.has("belt"), "spellbook on the belt behind a 2H staff")
	ch.equip({"weapon": "wand", "offhand": "spellbook"})
	assert_true(ch._attachments.has("handslot.l"), "open spellbook in the free hand")
	assert_eq(ch.style(), "magic")
	# style follows the weapon
	ch.equip({"weapon": "crossbow"})
	assert_eq(ch.style(), "ranged")
	assert_eq(ch.resolve("attack"), "Ranged_1H_Shoot")
	ch.equip({"weapon": "spear"})
	assert_eq(ch.resolve("attack"), "Melee_2H_Attack_Stab")
	ch.in_combat = true
	assert_eq(ch.resolve("idle"), "Melee_2H_Idle")
	ch.equip({"weapon": "hunting_bow"})
	assert_eq(ch.resolve("idle"), "Ranged_Bow_Idle")
	assert_true(ch._attachments.has("handslot.l"), "bow in the left hand")
	ch.in_combat = false
	assert_eq(ch.resolve("idle"), "Idle_A")
	ch.equip({"weapon": "dagger", "offhand": "parrying_dagger"})
	assert_eq(ch.resolve("attack"), Character.ATTACKS.dual)
	ch.equip({"weapon": "claws"})
	assert_true(ch._attachments.has("handslot.r") and ch._attachments.has("handslot.l"), "two claws")
	# unequip restores a bare model
	ch.unequip()
	assert_eq(ch._attachments.size(), 0, "unequip clears items")
	assert_eq(ch.loadout, {})
	ch.free()


func test_armor_binds_and_restores() -> void:
	if not _assets():
		return
	var ch := Character.create("knight", "", {"head": "wizard_hat", "body": "ninja_gi", "back": "mage_cape"})
	assert_true(not ch.part_visible("Knight_Helmet"), "own helmet hidden")
	assert_true(not ch.part_visible("Knight_Body") and not ch.part_visible("Knight_ArmLeft"), "own body hidden")
	assert_true(not ch.part_visible("Knight_Cape"), "own cape hidden")
	assert_true(ch.part_visible("Knight_Head"), "face stays")
	var worn := ch.worn_meshes()
	var names := worn.map(func(m: MeshInstance3D) -> String: return String(m.name))
	assert_eq(worn.size(), 5, "hat + chest + 2 arms + cape: %s" % [names])
	for mi in worn:
		assert_true(mi.get_parent() == ch.skeleton, "%s bound under the hero skeleton" % mi.name)
		assert_eq(mi.get_node(mi.skeleton), ch.skeleton, "%s skinned to the hero" % mi.name)
		assert_true(mi.skin != null and mi.skin.get_bind_name(0) != &"", "%s: named binds" % mi.name)
		assert_true(mi.owner == ch.model, "%s owned (tintable)" % mi.name)
	# the class's own piece shows the own part, no donor
	ch.equip({"head": "knight_helm", "back": "knight_cape"})
	assert_eq(ch.worn_meshes().size(), 0, "own pieces need no donor")
	assert_true(ch.part_visible("Knight_Helmet") and ch.part_visible("Knight_Cape"), "own pieces visible")
	# appearance: hidden head, empty back
	ch.equip({"head": "bear_hat", "back": "", "appearance": {"head": "hidden"}})
	assert_eq(ch.worn_meshes().size(), 0, "hidden head binds nothing")
	assert_true(not ch.part_visible("Knight_Helmet") and not ch.part_visible("Knight_Cape"), "hidden")
	ch.equip({"head": "bear_hat", "appearance": {"head": "own"}})
	assert_true(ch.part_visible("Knight_Helmet"), "own appearance keeps the helmet")
	# rigid donor (bone-parented in its GLB) goes on a BoneAttachment3D of the same bone
	ch.equip({"head": "helm_bone", "back": "paladin_cape"})
	var rigid := ch.worn_meshes()
	assert_eq(rigid.size(), 2, "helmet + cape")
	for mi in rigid:
		assert_true(mi.get_parent() is BoneAttachment3D, "%s on a bone attachment" % mi.name)
	ch.unequip()
	assert_eq(ch.worn_meshes().size(), 0, "unequip frees donors")
	for p in ["Knight_Helmet", "Knight_Body", "Knight_Cape", "Knight_Head"]:
		assert_true(ch.part_visible(p), "%s restored" % p)
	assert_eq(ch.skeleton.find_children("Donor_*", "", false, false).size(), 0, "no donor nodes left")
	ch.free()


func test_covering_pieces_hide_the_head() -> void:
	if not _assets():
		return
	var ch := Character.create("paladin", "", {"head": "paladin_helm"})
	assert_true(not ch.part_visible("Paladin_Head"), "the full helmet replaces the face")
	assert_eq(ch.worn_meshes().size(), 1)
	ch.equip({"body": "dino_suit"})
	assert_true(not ch.part_visible("Paladin_Head") and not ch.part_visible("Paladin_Body"), "dino suit covers all")
	ch.free()


func test_skin_only_on_own_parts() -> void:
	if not _assets():
		return
	var ch := Character.create("rogue", "alt_A", {"body": "hooded_robe", "head": "wizard_hat"})
	var own := ch.model.find_child("Rogue_Head", true, false) as MeshInstance3D
	var mat := own.get_active_material(0) as BaseMaterial3D
	assert_true(mat.albedo_texture.resource_path.ends_with("rogue_texture_alt_A.png"), "own part skinned")
	for mi in ch.worn_meshes():
		var m := mi.get_active_material(0) as BaseMaterial3D
		var p := m.albedo_texture.resource_path
		if String(mi.name).contains("RogueHooded"):
			assert_true(p.ends_with("rogue_texture_alt_A.png"), "same-family donor shares the skin (%s)" % mi.name)
		else:
			assert_true(p.ends_with("mage_texture.png"), "foreign donor keeps its atlas (%s: %s)" % [mi.name, p])
	ch.free()

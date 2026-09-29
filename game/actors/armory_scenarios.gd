class_name ArmoryScenarios
extends RefCounted
## Armory presentation scenarios (docs/design/2026-09-29-armory-items.md §8), served through
## game/actors/scenarios.gd:
##  loadout_gallery  every class in its signature kit (§6); --set=mixed: swapped kits
##  armor_fit        one hero x every head piece (+ own / hidden), labelled with the HEAD_FIT
##                   entry; --hero=<model or class> (default knight), --zoom=head (close-up)
##  weapon_grips     every weapon / off-hand / trinket model (and variant) in hand;
##                   --hero=knight|rogue|..., --group=weapons|fwb|bones|offhands|trinkets|all
##  back_gallery     back pieces, seen from behind; --hero=<model> (every back on that hero,
##                   default: each back on a different hero)
##  body_gallery     body pieces; --hero=<model> (every body on that hero, default: a sample)
## Common: --anim=<alias|clip> (default idle; weapon_grips: attack), --t=0..1 freezes the clip
## at that fraction (else it loops), --cols=N, --view=front|back|side|three, --pitch=deg,
## --per=N --page=K (N cells per shot), --sx / --sz (grid spacing).

const ACT := preload("res://game/actors/scenarios.gd")

## Heroes of the fit pass: [label, model, skin].
const HEROES := [["Knight", "knight", ""], ["Barbarian", "barbarian", ""], ["Mage", "mage", ""],
	["Rogue", "rogue", ""], ["Rogue Hooded", "rogue_hooded", ""], ["Ranger", "ranger", ""],
	["Druid", "druid", ""], ["Engineer", "engineer", ""], ["Paladin", "paladin", ""], ["Ninja", "ninja", ""],
	["Necromancer", "rogue_hooded", "alt_C"], ["Monster Kid", "monster_kid", ""]]

const CLASSES := ["knight", "barbarian", "mage", "rogue", "paladin", "ranger", "ninja", "druid", "engineer",
	"necromancer", "monster_kid"]

## Mixed kits for loadout_gallery --set=mixed: [class, overrides].
const MIXED := [
	["knight", {"weapon": "greatsword_zwei", "offhand": "", "head": "bear_hat", "body": "ninja_gi", "back": "bone_cloak"}],
	["barbarian", {"weapon": "hammer_morningstar", "offhand": "shield_dragon", "head": "knight_helm", "body": "paladin_cuirass"}],
	["mage", {"weapon": "wand_orb", "offhand": "spellbook", "head": "hat_grave", "body": "druid_robe", "back": "grave_cape"}],
	["rogue", {"weapon": "crossbow", "offhand": "smoke_bomb", "head": "goggles", "body": "engineer_overalls", "back": "engineer_backpack", "trinket2": "compass"}],
	["paladin", {"weapon": "spear_halberd", "offhand": "", "head": "paladin_helm", "back": "knight_cape"}],
	["ranger", {"weapon": "bow_long", "offhand": "quiver_bone", "head": "ninja_mask", "body": "rogue_leathers"}],
	["ninja", {"weapon": "scythe_bone", "offhand": "", "head": "helm_bone", "body": "knight_plate", "back": "orc_warpack"}],
	["druid", {"weapon": "staff_living", "head": "wizard_hat", "body": "mage_robe", "back": "mage_cape", "trinket": "lantern"}],
	["engineer", {"weapon": "claws_gauntlet", "head": "bandit_mask", "body": "barbarian_harness", "back": "bear_pelt"}],
	["necromancer", {"weapon": "scythe", "head": "hood_grave", "body": "hooded_robe", "trinket2": "loaded_die"}],
	["monster_kid", {"weapon": "claws_knuckles", "back": "druid_backpack", "trinket": "coin_purse"}],
	["knight", {"weapon": "sword_flame", "offhand": "shield_heraldic", "head": "paladin_helm", "body": "paladin_cuirass", "back": "paladin_cape"}],
]

const GROUPS := {
	"weapons": ["sword", "greatsword", "greatsword_plain", "hand_axe", "great_axe", "warhammer", "spear", "scythe",
		"dagger", "katana", "arcane_staff", "druid_staff", "wand", "hunting_bow", "crossbow", "crossbow_arbalest",
		"claws", "wrench"],
	"fwb": ["sword_training", "sword_knight", "sword_saber", "sword_rapier", "sword_flame", "sword_frost",
		"greatsword_zwei", "axe_twinbit", "axe_cleaver", "axe_war", "axe_jagged", "hammer_smith", "hammer_morningstar",
		"hammer_club", "hammer_mallet", "spear_halberd", "spear_trident", "dagger_leaf", "dagger_venom",
		"staff_quarter", "staff_frost", "staff_sun", "staff_living", "wand_sapphire", "wand_orb", "bow_short",
		"bow_composite", "bow_long", "claws_knuckles", "claws_gauntlet"],
	"bones": ["axe_bone", "axe_golem", "hammer_bone", "scythe_bone", "dagger_bone", "staff_bone", "crossbow_bone"],
	"offhands": ["round_shield", "round_shield_badge", "shield_plank", "shield_heraldic", "shield_tower", "shield_bone",
		"spiked_shield", "shield_dragon", "shield_bone_large", "oath_shield", "parrying_dagger", "parry_sai",
		"spellbook", "quiver", "quiver_bone", "smoke_bomb", "shuriken"],
	"trinkets": ["tankard", "compass", "lantern", "coin_purse", "traders_map", "healers_flask", "skeleton_key",
		"loaded_die"],
}


static func names() -> PackedStringArray:
	return PackedStringArray(["loadout_gallery", "armor_fit", "weapon_grips", "back_gallery", "body_gallery"])


static func build(name: String) -> Node:
	if not names().has(name):
		return null
	var args: Dictionary = Shot.args if Shot else {}
	var cells: Array = []    # {model, skin, loadout, label, [anim]}
	var cols := 4
	var view := "front"
	var anim := String(args.get("anim", "idle"))
	var zoom := String(args.get("zoom", ""))
	match name:
		"loadout_gallery":
			var set_ := String(args.get("set", "default"))
			if set_ == "mixed":
				for m in MIXED:
					var lo := Character.kit(String(m[0]))
					lo.erase("appearance")    # mixed kits show the equipped pieces
					lo.merge(m[1], true)
					cells.append(_cell(lo, "%s\n%s" % [String(m[0]).capitalize(), _kit_line(lo)]))
			else:
				for c in CLASSES:
					var lo := Character.kit(c)
					cells.append(_cell(lo, "%s\n%s" % [String(c).capitalize(), _kit_line(lo)]))
			cols = 4
		"armor_fit":
			var h := _hero(String(args.get("hero", "knight")))
			cells.append({"model": h[1], "skin": h[2], "loadout": {"head": "", "appearance": {"head": "own"}},
				"label": "%s\nown" % h[0]})
			cells.append({"model": h[1], "skin": h[2], "loadout": {"head": ""}, "label": "hidden"})
			for id in ItemMounts.HEADS:
				var fit := ArmorBinder.head_fit(String(h[1]), String(id))
				var tag := String(fit.fit)
				if tag == "scale":
					tag = "x%.2f" % float(fit.scale)
				elif tag == "swap_head" and float(fit.scale) != 1.0:
					tag = "swap_head x%.2f" % float(fit.scale)
				elif tag == "bad":
					tag = "bad: hidden"
				cells.append({"model": h[1], "skin": h[2], "loadout": {"head": id}, "label": "%s\n%s" % [id, tag]})
			cols = 5
		"weapon_grips":
			var h := _hero(String(args.get("hero", "knight")))
			var group := String(args.get("group", "weapons"))
			var ids: Array = []
			if args.has("ids"):
				ids = Array(String(args.ids).split(","))
			elif group == "all":
				for g in GROUPS:
					ids.append_array(GROUPS[g])
			else:
				ids = GROUPS.get(group, GROUPS.weapons)
			if not args.has("anim"):
				anim = "attack"
			for id in ids:
				var lo := {}
				var slot := String(ItemMounts.base_of(String(id)).get("slot", "weapon"))
				lo[slot] = id
				if slot == "offhand":
					lo["weapon"] = "sword" if not String(id) in ["shuriken", "parrying_dagger", "parry_sai"] else "dagger"
				cells.append({"model": h[1], "skin": h[2], "loadout": lo,
					"label": "%s\n%s" % [id, ItemMounts.item(String(id)).get("model", "")]})
			cols = 6
		"back_gallery":
			view = "back"
			if args.has("hero"):
				var h := _hero(String(args.hero))
				cells.append({"model": h[1], "skin": h[2], "loadout": {"back": ""}, "label": "%s\nno back" % h[0]})
				for id in ItemMounts.BACKS:
					cells.append({"model": h[1], "skin": h[2], "loadout": {"back": id}, "label": String(id)})
			else:
				var i := 0
				for id in ItemMounts.BACKS:
					var h: Array = HEROES[i % HEROES.size()]
					i += 1
					cells.append({"model": h[1], "skin": h[2], "loadout": {"back": id}, "label": "%s\n%s" % [id, h[0]]})
			cols = 5
		"body_gallery":
			if args.has("hero"):
				var h := _hero(String(args.hero))
				for id in ItemMounts.BODIES:
					cells.append({"model": h[1], "skin": h[2], "loadout": {"body": id}, "label": "%s\n%s" % [id, h[0]]})
			else:
				var i := 0
				for id in ItemMounts.BODIES:
					var h: Array = HEROES[(i * 5 + 1) % HEROES.size()]
					i += 1
					cells.append({"model": h[1], "skin": h[2], "loadout": {"body": id}, "label": "%s\n%s" % [id, h[0]]})
			cols = 4
	# paging: --per=N cells per shot, --page=K (0-based)
	if args.has("per"):
		var per := int(args.per)
		var page := int(args.get("page", "0"))
		cells = cells.slice(page * per, (page + 1) * per)
	# portrait windows get half the columns (taller grid, bigger heroes)
	var win := (Engine.get_main_loop() as SceneTree).root.size
	if win.y > win.x:
		cols = maxi(2, ceili(cols / 2.0))
	cols = int(args.get("cols", cols))
	view = String(args.get("view", view))
	return _stage(name, cells, cols, view, anim, zoom, args)


## [label, model, skin] for a model id or a class id (necromancer -> the hooded rogue + alt_C).
static func _hero(id: String) -> Array:
	for h in HEROES:
		if h[1] == id or String(h[0]).to_lower().replace(" ", "_") == id:
			return h
	if Character.KITS.has(id):
		return [id.capitalize(), Character.KITS[id].model, String(Character.KITS[id].get("skin", ""))]
	return [id.capitalize(), id if Character.MODELS.has(id) else "knight", ""]


static func _cell(lo: Dictionary, label: String) -> Dictionary:
	return {"model": String(lo.model), "skin": String(lo.get("skin", "")), "loadout": lo, "label": label}


static func _kit_line(lo: Dictionary) -> String:
	var bits := PackedStringArray()
	for k in ["weapon", "offhand", "head", "body", "back"]:
		if String(lo.get(k, "")) != "":
			bits.append(String(lo[k]))
	return " ".join(bits)


static func _stage(name: String, cells: Array, cols: int, view: String, anim: String, zoom: String,
		args: Dictionary) -> Node:
	var root := Node3D.new()
	root.name = "Armory_" + name
	ACT._add_environment(root)
	_add_floor(root)
	var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var sx := float(args.get("sx", "1.45" if zoom == "head" else "2.3"))
	var sz := float(args.get("sz", "3.4"))
	var rows := int(ceil(float(cells.size()) / float(cols)))
	var t := float(args.get("t", "-1"))
	var yaw := {"front": 0.0, "back": 180.0, "side": 90.0, "left": -90.0, "three": 35.0, "three_l": -35.0}.get(view, 0.0) as float
	var pts: Array[Vector3] = []
	for i in cells.size():
		var c: Dictionary = cells[i]
		var col := i % cols
		var row := i / cols
		var pos := Vector3((float(col) - (cols - 1) * 0.5) * sx, 0.0, (float(row) - (rows - 1) * 0.5) * sz)
		var ch := Character.create(String(c.model), String(c.get("skin", "")), c.loadout)
		ch.position = pos
		ch.rotation.y = deg_to_rad(yaw)
		root.add_child(ch)
		if t >= 0.0:
			_freeze(ch, anim, t)
		else:
			ACT._loop(ch, anim)
		var label := Label3D.new()
		label.text = String(c.label)
		label.font = font
		label.font_size = int(args.get("font", "64"))
		label.pixel_size = 0.0045
		label.outline_size = 12
		label.outline_modulate = Color(0.08, 0.06, 0.1, 0.9)
		label.modulate = Color(1.0, 0.86, 0.5)
		if zoom == "head":
			label.position = pos + Vector3(0.0, 3.05, 0.0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.pixel_size = 0.003
		else:
			label.position = pos + Vector3(0.0, 0.05, 0.75)
			label.rotation_degrees.x = -90.0
		label.width = 420.0
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(label)
		var lo_y := 1.3 if zoom == "head" else 0.0
		var hi_y := 3.3 if zoom == "head" else 2.9
		var hw := 0.62 if zoom == "head" else 0.75
		for dx in [-hw, hw]:
			for dz in ([-0.2, 0.4] if zoom == "head" else [-0.4, 1.1]):
				pts.append(pos + Vector3(dx, lo_y, dz))
				pts.append(pos + Vector3(dx, hi_y, dz))
	var cam := _GridCamera.new()
	cam.points = pts
	var tall := (Engine.get_main_loop() as SceneTree).root.size.y > (Engine.get_main_loop() as SceneTree).root.size.x
	cam.pitch = float(args.get("pitch", "18" if zoom == "head" else ("50" if tall else "34")))
	root.add_child(cam)
	cam.current = true
	print("ARMORY_SCENARIO %s cells=%d" % [name, cells.size()])
	return root


## Plain tiled floor (no props: nothing hides a grip).
static func _add_floor(root: Node3D) -> void:
	var tile: PackedScene = load("res://assets/kaykit/dungeon/floor_tile_large.gltf")
	for gx in range(-6, 6):
		for gz in range(-6, 4):
			var t: Node3D = tile.instantiate()
			t.position = Vector3(gx * 4.0 + 2.0, -0.15, gz * 4.0 + 2.0)
			root.add_child(t)


## Holds `alias` at fraction t of its clip (a readable pose: attack mid-swing, idle).
static func _freeze(ch: Character, alias: String, t: float) -> void:
	var clip := ch.resolve(alias)
	if clip == "":
		return
	ch.ready.connect(func() -> void:
		ch.anim_player.play(clip, 0.0)
		ch.anim_player.seek(ch.anim_player.current_animation_length * clampf(t, 0.0, 1.0), true)
		ch.anim_player.pause(), CONNECT_ONE_SHOT)


## Frames every point (both orientations): backs off until all are inside the frustum.
class _GridCamera extends Camera3D:
	var points: Array[Vector3] = []
	var pitch := 30.0

	func _ready() -> void:
		fov = float(Shot.args.get("fov", "26")) if Shot else 26.0
		get_viewport().size_changed.connect(_fit)
		_fit()

	func _fit() -> void:
		var s := get_viewport().get_visible_rect().size
		keep_aspect = Camera3D.KEEP_WIDTH if s.y > s.x else Camera3D.KEEP_HEIGHT
		var c := Vector3.ZERO
		for p in points:
			c += p
		c /= maxf(1.0, float(points.size()))
		var dir := Vector3(0.0, sin(deg_to_rad(pitch)), cos(deg_to_rad(pitch)))
		var d := 2.0
		while d < 80.0:
			position = c + dir * d
			look_at(c)
			var ok := true
			for p in points:
				if not is_position_in_frustum(p):
					ok = false
					break
			if ok:
				break
			d += 0.25

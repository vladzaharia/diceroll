extends RefCounted
## Class presentation scenarios (classes, mechanics, skins, Wardrobe), served through
## tools/scenarios.gd PROVIDERS.
##
##  class_looks     every class hero (HeroLook) in a row; --skins=1: one row per class with its
##                  5 looks (default, victor, ascendant, bossbane, prestige overlay);
##                  --class=<id>: that class's skins only. --view=front|three, --anim=<alias>

const ARM := preload("res://game/actors/armory_scenarios.gd")
const ACT := preload("res://game/actors/scenarios.gd")

const NAMES := ["class_looks"]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var args: Dictionary = Shot.args if Shot else {}
	match name:
		"class_looks":
			return _looks(args)
	return null


## A grid of heroes: cells [{class, skin, prestige, label}].
static func _looks(args: Dictionary) -> Node:
	var cells: Array = []
	var cols := 6
	if args.has("class"):
		var cid := String(args["class"])
		for s in ["default", "victor", "ascendant", "bossbane"]:
			cells.append({"class": cid, "skin": s, "prestige": false, "label": SkinDefs.NAMES[s]})
		cells.append({"class": cid, "skin": "default", "prestige": true, "label": "Prestige"})
		cols = 5
	elif String(args.get("skins", "0")) == "1":
		var ids: Array = HeroDefs.IDS.slice(int(args.get("from", "0")), int(args.get("to", "11")))
		for cid in ids:
			for s in ["default", "victor", "ascendant", "bossbane"]:
				cells.append({"class": cid, "skin": s, "prestige": false, "label": "%s %s" % [HeroDefs.DATA[cid].name, SkinDefs.NAMES[s]]})
			cells.append({"class": cid, "skin": "default", "prestige": true, "label": "Prestige"})
		cols = 5
	else:
		for cid in HeroDefs.IDS:
			cells.append({"class": cid, "skin": "default", "prestige": false, "label": String(HeroDefs.DATA[cid].name)})
	cols = int(args.get("cols", str(cols)))
	var root := Node3D.new()
	root.name = "ClassLooks"
	ACT._add_environment(root)
	ARM._add_floor(root)
	var font: Font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var sx := float(args.get("sx", "2.3"))
	var sz := float(args.get("sz", "3.4"))
	var rows := int(ceil(float(cells.size()) / float(cols)))
	var view := String(args.get("view", "front"))
	var yaw := {"front": 0.0, "three": 35.0, "back": 180.0, "side": 90.0}.get(view, 0.0) as float
	var anim := String(args.get("anim", "idle"))
	var pts: Array[Vector3] = []
	for i in cells.size():
		var c: Dictionary = cells[i]
		var pos := Vector3((float(i % cols) - (cols - 1) * 0.5) * sx, 0.0, (float(i / cols) - (rows - 1) * 0.5) * sz)
		var ch := HeroLook.create(String(c["class"]), String(c.skin), bool(c.prestige))
		ch.position = pos
		ch.rotation.y = deg_to_rad(yaw)
		root.add_child(ch)
		ACT._loop(ch, anim)
		var label := Label3D.new()
		label.text = String(c.label)
		label.font = font
		label.font_size = int(args.get("font", "64"))
		label.pixel_size = 0.0045
		label.outline_size = 12
		label.outline_modulate = Color(0.08, 0.06, 0.1, 0.9)
		label.modulate = Color(1.0, 0.86, 0.5)
		label.position = pos + Vector3(0.0, 0.05, 0.75)
		label.rotation_degrees.x = -90.0
		label.width = 420.0
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		root.add_child(label)
		var head := String(args.get("zoom", "")) == "head"
		for dx in [-0.75, 0.75]:
			for dz in ([-0.2, 0.3] if head else [-0.4, 1.1]):
				pts.append(pos + Vector3(dx, 1.2 if head else 0.0, dz))
				pts.append(pos + Vector3(dx, 3.1 if head else 2.9, dz))
	var cam := ArmoryScenarios._GridCamera.new()
	cam.points = pts
	var tall := (Engine.get_main_loop() as SceneTree).root.size.y > (Engine.get_main_loop() as SceneTree).root.size.x
	cam.pitch = float(args.get("pitch", "50" if tall else "30"))
	root.add_child(cam)
	cam.current = true
	return root

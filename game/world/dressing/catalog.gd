class_name DressingCatalog
extends Node3D
## Dev aid (scenario `dressing_catalog`): lays out every model of a runtime asset folder in
## a labelled grid, lit neutrally, to pick dressing props.
##   --dir=forest            folder under res://assets/kaykit/
##   --filter=Tree_+Color1,Bush_1   comma-separated alternatives; '+' joins required substrings
##   --cols=10  --gap=2.4    grid layout

var dir := "forest"
var filter := ""


func _ready() -> void:
	var args: Dictionary = Shot.args if Shot else {}
	dir = String(args.get("dir", dir))
	filter = String(args.get("filter", filter))
	var cols := int(args.get("cols", "10"))
	var gap := float(args.get("gap", "2.4"))
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.17, 0.2)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.82, 0.9)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.2
	add_child(sun)
	var files: Array[String] = []
	for f in DirAccess.get_files_at(Props.K + dir):
		if not (f.ends_with(".gltf") or f.ends_with(".glb")):
			continue
		if filter != "":
			var ok := false
			for part in filter.split(","):
				var all := true
				for sub in part.split("+"):
					all = all and f.contains(sub)
				if all:
					ok = true
			if not ok:
				continue
		files.append(f)
	files.sort()
	var pts := PackedVector3Array()
	for i in files.size():
		var p := Vector3(float(i % cols) * gap, 0, float(i / cols) * gap * 1.2)
		var n := Props.put(self, dir + "/" + files[i], p)
		var box := Props.world_aabb(n)
		var l := Label3D.new()
		l.text = files[i].get_basename().replace(".gltf", "") + "\n%.1fx%.1fx%.1f" % [box.size.x, box.size.y, box.size.z]
		l.font_size = int(Shot.args.get("font", "22")) if Shot else 22
		l.pixel_size = 0.004
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = p + Vector3(0, -0.2, 0.7)
		l.modulate = Color(1, 1, 0.8)
		add_child(l)
		pts.append(p)
		pts.append(p + Vector3.UP * minf(box.size.y, 3.0))
	var rig := CameraRig.new()
	add_child(rig)
	rig.frame_points(pts, 0.0, float(args.get("pitch", "35")), true)

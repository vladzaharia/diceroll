extends SceneTree
## Headless compile check for every script under ui/:
##   godot --headless --path . -s ui/check_scripts.gd
## Prints UI_SCRIPTS_OK or the failing paths (and exits 1).


func _init() -> void:
	var bad: Array[String] = []
	for path in _scripts("res://ui"):
		var s: Script = load(path)
		if s == null or not s.can_instantiate():
			bad.append(path)
	if bad.is_empty():
		print("UI_SCRIPTS_OK")
	else:
		print("UI_SCRIPTS_FAILED ", bad)
	quit(0 if bad.is_empty() else 1)


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_scripts(dir + "/" + sub))
	return out

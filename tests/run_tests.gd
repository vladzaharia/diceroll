extends SceneTree
## Minimal headless test runner.
## Usage: godot --headless --path . -s tests/run_tests.gd [-- --filter=<substring>]
## Discovers res://tests/test_*.gd; each file extends TestCase and defines test_* methods.
## Exit code 0 when all pass, 1 otherwise.

const TestCase := preload("res://tests/test_case.gd")

func _init() -> void:
	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.substr(9)
	var passed := 0
	var failed := 0
	var dir := DirAccess.open("res://tests")
	var files: Array[String] = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			if filter != "" and not (f + "::" + name).contains(filter):
				continue
			var inst: TestCase = script.new()
			inst.call(name)
			if inst.failures.is_empty():
				passed += 1
			else:
				failed += 1
				print("FAIL %s::%s" % [f, name])
				for msg in inst.failures:
					print("    " + msg)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)

extends SceneTree
## Report-only visual diff for CI screenshots (no dependencies beyond Godot):
##   godot --headless --path . -s tools/ci/img_diff.gd -- --current=DIR --baseline=DIR --out=DIR
## For every PNG in --current that also exists in --baseline, both are downscaled to 320 px wide
## (removes AA / software-rasteriser noise) and compared per pixel; a pixel "differs" when any
## channel moves by more than 12%. Writes <out>/<name>.diff.png (changed pixels in magenta over a
## dimmed baseline) and <out>/diff.json {name: {"changed": fraction, "size_changed": bool}}.
## Always exits 0: the diff is informational (see tools/ci/contact_sheet.py).

const WIDTH := 320
const THRESHOLD := 0.12


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var cur := String(args.get("current", ""))
	var base := String(args.get("baseline", ""))
	var out := String(args.get("out", cur + "/diff"))
	DirAccess.make_dir_recursive_absolute(out)
	var report := {}
	var d := DirAccess.open(cur)
	if d == null or not DirAccess.dir_exists_absolute(base):
		print("IMG_DIFF no baseline")
		_write(out, report)
		quit(0)
		return
	for f in d.get_files():
		if not f.ends_with(".png") or f.ends_with(".diff.png"):
			continue
		var bp := base.path_join(f)
		if not FileAccess.file_exists(bp):
			report[f] = {"changed": -1.0, "new": true}
			continue
		report[f] = _compare(cur.path_join(f), bp, out.path_join(f.get_basename() + ".diff.png"))
	_write(out, report)
	print("IMG_DIFF compared ", report.size(), " images")
	quit(0)


func _compare(a_path: String, b_path: String, diff_path: String) -> Dictionary:
	var a := Image.load_from_file(a_path)
	var b := Image.load_from_file(b_path)
	if a == null or b == null:
		return {"changed": 1.0, "error": true}
	var size_changed := a.get_size() != b.get_size()
	var h := maxi(1, int(round(float(WIDTH) * a.get_height() / a.get_width())))
	for img in [a, b]:
		img.convert(Image.FORMAT_RGBA8)
		img.resize(WIDTH, h, Image.INTERPOLATE_BILINEAR)
	var diff := Image.create(WIDTH, h, false, Image.FORMAT_RGBA8)
	var changed := 0
	for y in h:
		for x in WIDTH:
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var delta := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			if delta > THRESHOLD:
				changed += 1
				diff.set_pixel(x, y, Color(1, 0, 1))
			else:
				diff.set_pixel(x, y, cb.darkened(0.6))
	diff.save_png(diff_path)
	return {"changed": float(changed) / float(WIDTH * h), "size_changed": size_changed}


func _write(out: String, report: Dictionary) -> void:
	var f := FileAccess.open(out.path_join("diff.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  ", true))

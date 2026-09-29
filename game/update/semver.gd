extends RefCounted
## Semantic Versioning 2.0.0 parse / compare (no class_name: the Updater autoload and its
## helpers must not depend on the global class cache).
##
##   const Semver := preload("res://game/update/semver.gd")
##   Semver.compare("0.2.0-rc.1", "0.2.0")   # -1
##   Semver.is_newer("0.2.0", "0.1.9")       # true
##
## A leading "v" is accepted. Build metadata (+...) is ignored for ordering. Missing minor /
## patch parts count as 0 ("1.2" == "1.2.0"). Unparseable versions sort below everything.


## {"ok", "major", "minor", "patch", "pre": Array (ints / strings)}.
static func parse(v: String) -> Dictionary:
	var s := v.strip_edges()
	if s.begins_with("v") or s.begins_with("V"):
		s = s.substr(1)
	var plus := s.find("+")
	if plus >= 0:
		s = s.substr(0, plus)
	var pre_s := ""
	var dash := s.find("-")
	if dash >= 0:
		pre_s = s.substr(dash + 1)
		s = s.substr(0, dash)
	var core := s.split(".")
	if s == "" or core.size() > 3:
		return {"ok": false}
	var nums: Array[int] = [0, 0, 0]
	for i in core.size():
		if not core[i].is_valid_int() or int(core[i]) < 0:
			return {"ok": false}
		nums[i] = int(core[i])
	var pre: Array = []
	if dash >= 0:
		if pre_s == "":
			return {"ok": false}
		for id in pre_s.split("."):
			if id == "":
				return {"ok": false}
			pre.append(int(id) if id.is_valid_int() else id)
	return {"ok": true, "major": nums[0], "minor": nums[1], "patch": nums[2], "pre": pre}


static func is_valid(v: String) -> bool:
	return parse(v)["ok"]


## -1 if a < b, 0 if equal precedence, 1 if a > b.
static func compare(a: String, b: String) -> int:
	var pa := parse(a)
	var pb := parse(b)
	if not pa["ok"] or not pb["ok"]:
		return signi(int(pa["ok"]) - int(pb["ok"]))
	for k in ["major", "minor", "patch"]:
		if pa[k] != pb[k]:
			return signi(pa[k] - pb[k])
	var ra: Array = pa["pre"]
	var rb: Array = pb["pre"]
	# a release has higher precedence than any of its prereleases
	if ra.is_empty() or rb.is_empty():
		return signi(int(ra.is_empty()) - int(rb.is_empty()))
	for i in mini(ra.size(), rb.size()):
		var x: Variant = ra[i]
		var y: Variant = rb[i]
		if typeof(x) == typeof(y):
			if x != y:
				return -1 if x < y else 1
		else:
			# numeric identifiers sort below alphanumeric ones
			return -1 if typeof(x) == TYPE_INT else 1
	return signi(ra.size() - rb.size())


static func is_newer(candidate: String, current: String) -> bool:
	return compare(candidate, current) > 0

extends RefCounted
## On-disk pack store for content updates (desktop GitHub builds). No class_name.
##
##   <root>/staged/   diceroll.pck + meta.json   downloaded, verified, not yet active
##   <root>/current/  diceroll.pck + meta.json   the pack the game relaunches into (--main-pack)
##   <root>/previous/ diceroll.pck + meta.json   the last good pack (rollback target)
##   <root>/state.cfg [state] boot_attempts, active, skip_version, binary_version; [check] last
##
## meta.json: {"version", "sha256", "size", "engine"}.
## Root defaults to user://updates; tests inject their own (user://test_updates/...).
## All file operations are synchronous; boot() runs before the main scene matters.

const Semver := preload("res://game/update/semver.gd")

const PCK := "diceroll.pck"
const META := "meta.json"
const STATE := "state.cfg"
const SLOTS := ["staged", "current", "previous"]
## Boots into a pack that never reached "boot OK" before it is rolled back.
const MAX_BOOT_ATTEMPTS := 2
const CHUNK := 1 << 20

var root: String


func _init(p_root := "user://updates") -> void:
	root = p_root.trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(root)


func dir(slot: String) -> String:
	return root + "/" + slot


func pck_path(slot: String) -> String:
	return dir(slot) + "/" + PCK


## Absolute OS path of a slot's pack (for --main-pack).
func pck_abs(slot: String) -> String:
	return ProjectSettings.globalize_path(pck_path(slot))


func has_pack(slot: String) -> bool:
	return FileAccess.file_exists(pck_path(slot)) and FileAccess.file_exists(dir(slot) + "/" + META)


func read_meta(slot: String) -> Dictionary:
	var f := FileAccess.open(dir(slot) + "/" + META, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	return v if typeof(v) == TYPE_DICTIONARY else {}


func write_meta(slot: String, meta: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir(slot))
	var f := FileAccess.open(dir(slot) + "/" + META, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(meta, "\t"))
	return true


func slot_version(slot: String) -> String:
	return String(read_meta(slot).get("version", "")) if has_pack(slot) else ""


# ------------------------------------------------------------------ state

func load_state() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(root + "/" + STATE)
	return c


func save_state(c: ConfigFile) -> void:
	c.save(root + "/" + STATE)


func get_state(key: String, default: Variant = null) -> Variant:
	return load_state().get_value("state", key, default)


func set_state(key: String, value: Variant) -> void:
	var c := load_state()
	c.set_value("state", key, value)
	save_state(c)


func boot_attempts() -> int:
	return int(get_state("boot_attempts", 0))


## Called right before relaunching into the current pack.
func note_launch() -> void:
	set_state("boot_attempts", boot_attempts() + 1)


## Called once the pack has run long enough to count as a good boot.
func mark_boot_ok() -> void:
	set_state("boot_attempts", 0)


func last_check() -> int:
	return int(load_state().get_value("check", "last", 0))


func set_last_check(unix: int) -> void:
	var c := load_state()
	c.set_value("check", "last", unix)
	save_state(c)


# ------------------------------------------------------------------ hashing

## Lower-case hex SHA-256 of a file, streamed in 1 MiB chunks ("" if unreadable).
static func sha256_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	var left := f.get_length()
	while left > 0:
		var n := mini(CHUNK, left)
		hc.update(f.get_buffer(n))
		left -= n
	return hc.finish().hex_encode()


static func file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_length() if f else -1


## Full check: pack present, size and sha256 match meta.json.
func verify_slot(slot: String) -> bool:
	if not has_pack(slot):
		return false
	var m := read_meta(slot)
	var path := pck_path(slot)
	if m.has("size") and int(m["size"]) != file_size(path):
		return false
	return String(m.get("sha256", "")) != "" and sha256_file(path) == String(m["sha256"]).to_lower()


# ------------------------------------------------------------------ staging

## Clears staged/ and returns the path a download should be written to.
func begin_staging() -> String:
	discard("staged")
	DirAccess.make_dir_recursive_absolute(dir("staged"))
	return dir("staged") + "/" + PCK + ".part"


## Verifies a downloaded .part (size + sha256 from the signed manifest), renames it into
## staged/diceroll.pck and writes meta.json. info: {"version","sha256","size","engine"}.
func finish_staging(part: String, info: Dictionary) -> Dictionary:
	if file_size(part) != int(info.get("size", -1)):
		DirAccess.remove_absolute(part)
		return {"ok": false, "error": "size mismatch (%d != %d)" % [file_size(part), int(info.get("size", -1))]}
	var sha := sha256_file(part)
	if sha == "" or sha != String(info.get("sha256", "")).to_lower():
		DirAccess.remove_absolute(part)
		return {"ok": false, "error": "sha256 mismatch"}
	var dest := pck_path("staged")
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	if DirAccess.rename_absolute(part, dest) != OK:
		return {"ok": false, "error": "could not rename staged pack"}
	write_meta("staged", {"version": info["version"], "sha256": sha, "size": int(info["size"]),
		"engine": info.get("engine", "")})
	return {"ok": true, "error": ""}


# ------------------------------------------------------------------ rotation

func discard(slot: String) -> void:
	_rm_tree(dir(slot))


## staged -> current (current -> previous). Returns false (and leaves things as they were
## as far as possible) when a rename fails, e.g. Windows while the current pack is open.
func activate_staged() -> bool:
	if not has_pack("staged"):
		return false
	if has_pack("current"):
		discard("previous")
		if not _rename(dir("current"), dir("previous")):
			return false
	else:
		discard("current")
	if not _rename(dir("staged"), dir("current")):
		# put the old current back so we still boot something known
		if has_pack("previous") and not DirAccess.dir_exists_absolute(dir("current")):
			_rename(dir("previous"), dir("current"))
		return false
	var c := load_state()
	c.set_value("state", "boot_attempts", 0)
	c.set_value("state", "active", read_meta("current").get("version", ""))
	save_state(c)
	return true


## previous -> current, dropping the failing current and remembering its version so the
## checker doesn't download it again.
func rollback() -> void:
	var bad := slot_version("current")
	discard("current")
	if has_pack("previous"):
		_rename(dir("previous"), dir("current"))
	var c := load_state()
	c.set_value("state", "boot_attempts", 0)
	if bad != "":
		c.set_value("state", "skip_version", bad)
	c.set_value("state", "active", slot_version("current"))
	save_state(c)


## Boot-time maintenance (run by the Updater autoload before relaunching). Returns
## {"pack": abs path of current/diceroll.pck or "", "activated": bool, "rolled_back": bool,
##  "log": Array[String]}.
## - drops packs built for another engine version (the binary was replaced) or not newer than
##   the running binary (a newer binary already contains that content);
## - rolls back when the current pack failed to boot MAX_BOOT_ATTEMPTS times;
## - activates a staged pack whose sha256 still matches (a corrupt one is discarded).
func boot(engine: String, binary_version: String) -> Dictionary:
	var out := {"pack": "", "activated": false, "rolled_back": false, "log": []}
	for slot in SLOTS:
		if not DirAccess.dir_exists_absolute(dir(slot)):
			continue
		var m := read_meta(slot)
		var v := String(m.get("version", ""))
		if not has_pack(slot):
			discard(slot)
		elif String(m.get("engine", "")) != engine:
			out["log"].append("%s: engine %s != %s, discarded" % [slot, m.get("engine", ""), engine])
			discard(slot)
		elif binary_version != "" and not Semver.is_newer(v, binary_version):
			out["log"].append("%s: %s not newer than binary %s, discarded" % [slot, v, binary_version])
			discard(slot)
	if has_pack("current") and boot_attempts() >= MAX_BOOT_ATTEMPTS:
		out["log"].append("current %s failed to boot %d times, rolled back" % [slot_version("current"), boot_attempts()])
		rollback()
		out["rolled_back"] = true
	if has_pack("staged"):
		if verify_slot("staged"):
			if activate_staged():
				out["activated"] = true
				out["log"].append("activated %s" % slot_version("current"))
			else:
				out["log"].append("could not activate staged pack")
		else:
			out["log"].append("staged pack failed verification, discarded")
			discard("staged")
	if has_pack("current") and file_size(pck_path("current")) == int(read_meta("current").get("size", -1)):
		out["pack"] = pck_abs("current")
	elif DirAccess.dir_exists_absolute(dir("current")):
		discard("current")
	if out["pack"] == "":
		set_state("active", "")
	return out


# ------------------------------------------------------------------ fs helpers

## Renames with retries: on Windows the old process may still hold the pack open for a moment.
func _rename(from: String, to: String) -> bool:
	for i in 12:
		if DirAccess.rename_absolute(from, to) == OK:
			return true
		OS.delay_msec(250)
	return false


static func _rm_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(path + "/" + f)
	for sub in d.get_directories():
		_rm_tree(path + "/" + sub)
	DirAccess.remove_absolute(path)

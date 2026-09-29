class_name ProfileStore
extends RefCounted
## Profile persistence (spec §16: user://profile.json, separate from the run save).
## The file is Profile.to_json(); a missing or unreadable file means a fresh profile.
## Writes go to a temp file first and are then renamed over the old one, so a crash mid-write
## never leaves a half-written profile.
##
##   var p := ProfileStore.load_profile()        # null when there is none yet
##   if p == null: p = Profile.fresh()
##   ProfileStore.save(p)

const PATH := "user://profile.json"


static func exists(path := PATH) -> bool:
	return FileAccess.file_exists(path)


## The stored profile, or null when there is no file (or it can't be parsed).
static func load_profile(path := PATH) -> Profile:
	if not FileAccess.file_exists(path):
		return null
	var j := JSON.new()
	var v: Variant = j.data if j.parse(FileAccess.get_file_as_string(path)) == OK else null
	if not (v is Dictionary) or (v as Dictionary).is_empty():
		push_warning("ProfileStore: %s is unreadable, starting a fresh profile" % path)
		return null
	return Profile.from_dict(v)


## Writes `p` to `path`. Returns false (with a warning) when the file can't be written.
static func save(p: Profile, path := PATH) -> bool:
	if p == null:
		return false
	var dir := path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("ProfileStore: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(Profile.to_json(p))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("ProfileStore: cannot replace %s (%s)" % [path, error_string(err)])
		return false
	return true


static func delete(path := PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

extends "res://tests/test_case.gd"

const Store := preload("res://game/update/update_store.gd")

const ENGINE := "4.7.2"


func _store(name: String) -> Store:
	var root := "user://test_updates/" + name
	Store._rm_tree(root)
	return Store.new(root)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _sha(text: String) -> String:
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(text.to_utf8_buffer())
	return hc.finish().hex_encode()


## Puts a pack with `text` content into `slot` with a correct meta.json.
func _put(s: Store, slot: String, version: String, text: String, engine := ENGINE) -> void:
	_write(s.pck_path(slot), text)
	s.write_meta(slot, {"version": version, "sha256": _sha(text), "size": text.length(), "engine": engine})


func test_sha256_file_streams() -> void:
	var s := _store("sha")
	var p := s.root + "/big.bin"
	var f := FileAccess.open(p, FileAccess.WRITE)
	var chunk := PackedByteArray()
	chunk.resize(700000)
	for i in chunk.size():
		chunk[i] = i % 251
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	for i in 3:  # 2.1 MB: spans several 1 MiB chunks
		f.store_buffer(chunk)
		hc.update(chunk)
	f.close()
	assert_eq(Store.sha256_file(p), hc.finish().hex_encode())
	assert_eq(Store.sha256_file(s.root + "/missing"), "")
	assert_eq(Store.sha256_file(p), Store.sha256_file(p), "stable")


func test_finish_staging_verifies() -> void:
	var s := _store("staging")
	var part := s.begin_staging()
	_write(part, "PACKDATA")
	var bad := s.finish_staging(part, {"version": "0.2.0", "sha256": _sha("OTHER"), "size": 8, "engine": ENGINE})
	assert_true(not bad["ok"], "sha mismatch rejected")
	assert_true(not FileAccess.file_exists(part), "bad part removed")
	assert_true(not s.has_pack("staged"))
	part = s.begin_staging()
	_write(part, "PACKDATA")
	assert_true(not s.finish_staging(part, {"version": "0.2.0", "sha256": _sha("PACKDATA"), "size": 9})["ok"], "size mismatch")
	part = s.begin_staging()
	_write(part, "PACKDATA")
	var ok := s.finish_staging(part, {"version": "0.2.0", "sha256": _sha("PACKDATA"), "size": 8, "engine": ENGINE})
	assert_true(ok["ok"], ok["error"])
	assert_true(s.verify_slot("staged"))
	assert_eq(s.slot_version("staged"), "0.2.0")
	assert_eq(s.read_meta("staged")["engine"], ENGINE)


func test_rotation_staged_current_previous() -> void:
	var s := _store("rotate")
	_put(s, "staged", "0.2.0", "v2")
	var b := s.boot(ENGINE, "0.1.0")
	assert_true(b["activated"])
	assert_eq(b["pack"], s.pck_abs("current"))
	assert_eq(s.slot_version("current"), "0.2.0")
	assert_true(not s.has_pack("staged"))
	assert_true(not s.has_pack("previous"))
	_put(s, "staged", "0.3.0", "v3")
	b = s.boot(ENGINE, "0.1.0")
	assert_true(b["activated"])
	assert_eq(s.slot_version("current"), "0.3.0")
	assert_eq(s.slot_version("previous"), "0.2.0")
	_put(s, "staged", "0.4.0", "v4")
	s.boot(ENGINE, "0.1.0")
	assert_eq(s.slot_version("current"), "0.4.0")
	assert_eq(s.slot_version("previous"), "0.3.0", "oldest dropped")
	assert_eq(s.get_state("active"), "0.4.0")


func test_corrupt_staged_discarded() -> void:
	var s := _store("corrupt")
	_put(s, "current", "0.2.0", "v2")
	_put(s, "staged", "0.3.0", "v3")
	_write(s.pck_path("staged"), "tampered")
	var b := s.boot(ENGINE, "0.1.0")
	assert_true(not b["activated"])
	assert_true(not s.has_pack("staged"), "corrupt staged removed")
	assert_eq(s.slot_version("current"), "0.2.0", "current kept")
	assert_eq(b["pack"], s.pck_abs("current"))


func test_boot_attempts_rollback() -> void:
	var s := _store("rollback")
	_put(s, "current", "0.3.0", "v3")
	_put(s, "previous", "0.2.0", "v2")
	s.note_launch()
	var b := s.boot(ENGINE, "0.1.0")
	assert_true(not b["rolled_back"], "one failed boot tolerated")
	s.note_launch()
	assert_eq(s.boot_attempts(), 2)
	b = s.boot(ENGINE, "0.1.0")
	assert_true(b["rolled_back"], "rolled back after 2 attempts")
	assert_eq(s.slot_version("current"), "0.2.0")
	assert_true(not s.has_pack("previous"))
	assert_eq(s.boot_attempts(), 0)
	assert_eq(s.get_state("skip_version"), "0.3.0", "bad version remembered")
	# the previous one keeps failing too -> nothing left, boot the binary
	s.note_launch()
	s.note_launch()
	b = s.boot(ENGINE, "0.1.0")
	assert_true(b["rolled_back"])
	assert_eq(b["pack"], "")
	assert_true(not s.has_pack("current"))


func test_mark_boot_ok_resets() -> void:
	var s := _store("bootok")
	_put(s, "current", "0.3.0", "v3")
	s.note_launch()
	s.mark_boot_ok()
	s.note_launch()
	var b := s.boot(ENGINE, "0.1.0")
	assert_true(not b["rolled_back"])
	assert_eq(b["pack"], s.pck_abs("current"))


func test_engine_mismatch_discarded() -> void:
	var s := _store("engine")
	_put(s, "current", "0.3.0", "v3", "4.6.0")
	_put(s, "previous", "0.2.0", "v2", "4.6.0")
	_put(s, "staged", "0.4.0", "v4", "4.8.0")
	var b := s.boot(ENGINE, "0.1.0")
	assert_eq(b["pack"], "")
	for slot in Store.SLOTS:
		assert_true(not s.has_pack(slot), "%s discarded" % slot)


func test_pack_not_newer_than_binary_discarded() -> void:
	var s := _store("oldpack")
	_put(s, "current", "0.2.0", "v2")
	var b := s.boot(ENGINE, "0.2.0")
	assert_eq(b["pack"], "", "binary already at 0.2.0")
	assert_true(not s.has_pack("current"))


func test_current_wrong_size_not_used() -> void:
	var s := _store("size")
	_put(s, "current", "0.2.0", "v2")
	_write(s.pck_path("current"), "truncated-or-grown")
	assert_eq(s.boot(ENGINE, "0.1.0")["pack"], "")

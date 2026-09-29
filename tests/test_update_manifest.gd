extends "res://tests/test_case.gd"

const Manifest := preload("res://game/update/update_manifest.gd")

const FIX := "res://tests/fixtures/update/"


func _bytes(name: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(FIX + name)


func _text(name: String) -> String:
	return FileAccess.get_file_as_string(FIX + name)


func _valid() -> Dictionary:
	return JSON.parse_string(_text("feed/update-stable.json"))


func test_fixture_parses() -> void:
	var r := Manifest.parse(_bytes("feed/update-stable.json"), "stable")
	assert_true(r["ok"], "fixture valid: " + r["error"])
	var m: Dictionary = r["manifest"]
	assert_eq(m["version"], "0.2.0")
	assert_eq(m["pack"]["size"], 3000)
	assert_eq(m["pack"]["sha256"].length(), 64)
	assert_true(m["binaries"].has("macos"))


func test_wrong_schema_and_channel() -> void:
	var m := _valid()
	m["schema"] = 2
	assert_true(not Manifest.validate(m, "stable")["ok"], "schema 2 rejected")
	m.erase("schema")
	assert_true(not Manifest.validate(m, "stable")["ok"], "missing schema rejected")
	var r := Manifest.validate(_valid(), "beta")
	assert_true(not r["ok"] and r["error"].contains("channel"), "wrong channel rejected")


func test_missing_and_bad_fields() -> void:
	for k in ["version", "engine", "min_binary", "channel"]:
		var m := _valid()
		m.erase(k)
		assert_true(not Manifest.validate(m, "stable")["ok"], "missing %s rejected" % k)
	var m2 := _valid()
	m2["version"] = "latest"
	assert_true(not Manifest.validate(m2, "stable")["ok"], "non-semver version rejected")
	var m3 := _valid()
	m3["pack"]["sha256"] = "xyz"
	assert_true(not Manifest.validate(m3, "stable")["ok"], "bad sha rejected")
	var m4 := _valid()
	m4["pack"].erase("size")
	assert_true(not Manifest.validate(m4, "stable")["ok"], "pack without size rejected")
	assert_true(not Manifest.parse("not json".to_utf8_buffer(), "stable")["ok"], "garbage rejected")
	assert_true(not Manifest.parse("[1,2]".to_utf8_buffer(), "stable")["ok"], "array rejected")


func test_optional_fields_normalised() -> void:
	var m := _valid()
	m["pack"] = null
	m.erase("binaries")
	m.erase("stores")
	m.erase("min_supported")
	m["notes"] = "x".repeat(900)
	var r := Manifest.validate(m, "stable")
	assert_true(r["ok"], r["error"])
	assert_eq(r["manifest"]["pack"], {})
	assert_eq(r["manifest"]["binaries"], {})
	assert_eq(r["manifest"]["min_supported"], "")
	assert_eq(r["manifest"]["notes"].length(), Manifest.MAX_NOTES)


func test_signature_valid() -> void:
	var ok := Manifest.verify_signature(_bytes("feed/update-stable.json"),
		_text("feed/update-stable.json.sig"), _text("test_signing.pub.pem"))
	assert_true(ok, "fixture signature verifies")


func test_signature_wrapped_base64() -> void:
	# GNU base64 wraps at 76 columns; whitespace must be ignored.
	var sig := _text("feed/update-stable.json.sig").strip_edges()
	var wrapped := ""
	for i in range(0, sig.length(), 76):
		wrapped += sig.substr(i, 76) + "\n"
	assert_true(Manifest.verify_signature(_bytes("feed/update-stable.json"), wrapped,
		_text("test_signing.pub.pem")), "wrapped sig verifies")


func test_signature_tampered() -> void:
	var data := _bytes("feed/update-stable.json")
	var t := data.get_string_from_utf8().replace("\"0.2.0\"", "\"9.9.9\"").to_utf8_buffer()
	assert_true(not Manifest.verify_signature(t, _text("feed/update-stable.json.sig"),
		_text("test_signing.pub.pem")), "tampered manifest rejected")
	var one := data.duplicate()
	one[10] = one[10] ^ 1
	assert_true(not Manifest.verify_signature(one, _text("feed/update-stable.json.sig"),
		_text("test_signing.pub.pem")), "one flipped bit rejected")


func test_signature_wrong_key_and_garbage() -> void:
	var data := _bytes("feed/update-stable.json")
	var sig := _text("feed/update-stable.json.sig")
	assert_true(not Manifest.verify_signature(data, sig, _text("test_wrong.pub.pem")), "wrong key")
	assert_true(not Manifest.verify_signature(data, sig, ""), "empty key (placeholder) fails closed")
	assert_true(not Manifest.verify_signature(data, sig, "-----BEGIN PUBLIC KEY-----\nAAAA\n-----END PUBLIC KEY-----\n"), "junk key")
	var pem := _text("test_signing.pub.pem")
	assert_true(not Manifest.verify_signature(data, "", pem), "empty sig")
	assert_true(not Manifest.verify_signature(data, "!!!not base64!!!", pem), "non-base64 sig")
	assert_true(not Manifest.verify_signature(data, Marshalls.raw_to_base64("hello".to_utf8_buffer()), pem), "short sig")
	var junk := PackedByteArray()
	junk.resize(256)
	junk.fill(7)
	assert_true(not Manifest.verify_signature(data, Marshalls.raw_to_base64(junk), pem), "right-size junk sig")


func test_modulus_bits() -> void:
	assert_eq(Manifest._modulus_bits(_text("test_signing.pub.pem")), 2048)

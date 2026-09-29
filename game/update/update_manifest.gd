extends RefCounted
## Update manifest (schema 1): signature verification, parsing and validation. Pure functions.
##
##   const Manifest := preload("res://game/update/update_manifest.gd")
##   if Manifest.verify_signature(bytes, sig_text, UpdateKeys.PUBLIC_KEY_PEM):
##       var r := Manifest.parse(bytes, "stable")   # {"ok", "manifest", "error"}
##
## Manifest (published by CI as <base>/update-<channel>.json + .json.sig):
##   {"schema":1, "channel", "version", "released", "notes", "notes_url", "engine",
##    "min_binary", "min_supported", "pack": {"url","sha256","size"} | null,
##    "binaries": {"<platform key>": {"url","sha256"}}, "stores": {"ios": url, "android": url}}
## The .sig is base64 (line wrapping allowed) of an RSA PKCS#1 v1.5 SHA-256 signature over
## the exact manifest bytes.

const Semver := preload("res://game/update/semver.gd")

const SCHEMA := 1
const MAX_NOTES := 500


## True when `sig_text` (base64) is a valid signature of `data` by `public_pem`.
## Never throws / logs on bad input: garbage just returns false.
static func verify_signature(data: PackedByteArray, sig_text: String, public_pem: String) -> bool:
	if public_pem.strip_edges() == "" or data.is_empty():
		return false
	var b64 := ""
	for c in sig_text:
		if not c in " \t\r\n":
			b64 += c
	if b64 == "" or b64.length() % 4 != 0:
		return false
	for c in b64:
		if not (c in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="):
			return false
	var sig := Marshalls.base64_to_raw(b64)
	if sig.size() < 64:
		return false
	# Pre-check the key shape and that sig length == modulus length: mbedtls logs engine
	# errors for malformed keys / wrong-size signatures instead of just failing.
	if sig.size() * 8 != _modulus_bits(public_pem):
		return false
	var key := CryptoKey.new()
	if key.load_from_string(public_pem, true) != OK:
		return false
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(data)
	return Crypto.new().verify(HashingContext.HASH_SHA256, hc.finish(), sig, key)


## Modulus size of an RSA SubjectPublicKeyInfo PEM (0 if unknown). Reads the DER just far
## enough to find the modulus INTEGER.
static func _modulus_bits(pem: String) -> int:
	var body := ""
	for line in pem.split("\n"):
		var l := line.strip_edges()
		if l != "" and not l.begins_with("-----"):
			body += l
	var der := Marshalls.base64_to_raw(body)
	# SEQUENCE { SEQUENCE { oid, null }, BIT STRING { 00, SEQUENCE { INTEGER n, INTEGER e } } }
	var p := [0]
	if not _enter(der, p, 0x30):
		return 0
	var alg_len := _enter_len(der, p, 0x30)
	if alg_len < 0:
		return 0
	p[0] += alg_len
	if _enter_len(der, p, 0x03) < 0:
		return 0
	p[0] += 1  # unused-bits byte
	if not _enter(der, p, 0x30):
		return 0
	var n_len := _enter_len(der, p, 0x02)
	if n_len <= 0 or p[0] + n_len > der.size():
		return 0
	if der[p[0]] == 0:
		n_len -= 1
	return n_len * 8


static func _enter(der: PackedByteArray, p: Array, tag: int) -> bool:
	return _enter_len(der, p, tag) >= 0


## Reads tag + length at p, advances p to the content, returns the content length (-1 on error).
static func _enter_len(der: PackedByteArray, p: Array, tag: int) -> int:
	var i: int = p[0]
	if i + 2 > der.size() or der[i] != tag:
		return -1
	var n := der[i + 1]
	i += 2
	if n & 0x80:
		var k := n & 0x7f
		if k < 1 or k > 3 or i + k > der.size():
			return -1
		n = 0
		for j in k:
			n = (n << 8) | der[i + j]
		i += k
	p[0] = i
	return n


## Parses + validates manifest bytes for `channel`. Returns {"ok": bool, "manifest": Dictionary,
## "error": String}. The manifest dictionary is normalised: pack is {} when absent/null,
## binaries / stores are {} when absent, notes are clamped to MAX_NOTES chars.
static func parse(data: PackedByteArray, channel: String) -> Dictionary:
	var text := data.get_string_from_utf8()
	var j := JSON.new()
	if text == "" or j.parse(text) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return _err("manifest is not a JSON object")
	return validate(j.data, channel)


static func validate(m: Dictionary, channel: String) -> Dictionary:
	if not m.has("schema") or typeof(m["schema"]) not in [TYPE_INT, TYPE_FLOAT] or int(m["schema"]) != SCHEMA:
		return _err("unsupported schema %s" % str(m.get("schema")))
	for k in ["channel", "version", "engine", "min_binary"]:
		if typeof(m.get(k)) != TYPE_STRING or String(m[k]) == "":
			return _err("missing field '%s'" % k)
	if m["channel"] != channel:
		return _err("channel mismatch: manifest '%s', expected '%s'" % [m["channel"], channel])
	for k in ["version", "engine", "min_binary"]:
		if not Semver.is_valid(m[k]):
			return _err("invalid version in '%s': %s" % [k, m[k]])
	var out := m.duplicate(true)
	if typeof(m.get("min_supported")) == TYPE_STRING and m["min_supported"] != "":
		if not Semver.is_valid(m["min_supported"]):
			return _err("invalid version in 'min_supported'")
	else:
		out["min_supported"] = ""
	for k in ["notes", "notes_url", "released"]:
		out[k] = String(m[k]) if typeof(m.get(k)) == TYPE_STRING else ""
	out["notes"] = String(out["notes"]).substr(0, MAX_NOTES)
	var pack: Variant = m.get("pack")
	if pack == null:
		out["pack"] = {}
	elif typeof(pack) != TYPE_DICTIONARY:
		return _err("pack must be an object or null")
	else:
		if typeof(pack.get("url")) != TYPE_STRING or pack["url"] == "":
			return _err("pack.url missing")
		if not _is_sha256(pack.get("sha256")):
			return _err("pack.sha256 must be 64 hex chars")
		if typeof(pack.get("size")) not in [TYPE_INT, TYPE_FLOAT] or int(pack["size"]) <= 0:
			return _err("pack.size missing")
		out["pack"] = {"url": pack["url"], "sha256": String(pack["sha256"]).to_lower(), "size": int(pack["size"])}
	for k in ["binaries", "stores"]:
		var v: Variant = m.get(k)
		if v == null:
			out[k] = {}
		elif typeof(v) != TYPE_DICTIONARY:
			return _err("%s must be an object" % k)
	return {"ok": true, "manifest": out, "error": ""}


static func _is_sha256(v: Variant) -> bool:
	if typeof(v) != TYPE_STRING or String(v).length() != 64:
		return false
	return String(v).is_valid_hex_number()


static func _err(msg: String) -> Dictionary:
	return {"ok": false, "manifest": {}, "error": msg}

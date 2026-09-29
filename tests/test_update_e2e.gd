extends "res://tests/test_case.gd"
## Check + download against the local fixture feed (no network): manifest + .sig are read via
## the local-path fetcher, verified with the fixture key, the pack is downloaded into
## staged/ and verified.

const Client := preload("res://game/update/update_client.gd")
const Store := preload("res://game/update/update_store.gd")
const Fetcher := preload("res://game/update/update_fetcher.gd")
const Policy := preload("res://game/update/update_policy.gd")

const FIX := "res://tests/fixtures/update/"


func _client(name: String) -> Client:
	var root := "user://test_updates/" + name
	Store._rm_tree(root)
	return Client.new(Store.new(root))


func _ctx(over := {}) -> Dictionary:
	var c := {"base_url": ProjectSettings.globalize_path(FIX + "feed"), "channel": "stable",
		"public_key": FileAccess.get_file_as_string(FIX + "test_signing.pub.pem"),
		"distribution": "github", "platform": "macos", "engine": "4.7.2",
		"version": "0.1.0", "binary_version": "0.1.0"}
	c.merge(over, true)
	return c


func test_fetcher_paths() -> void:
	assert_true(Fetcher.is_local("/tmp/x"))
	assert_true(Fetcher.is_local("file:///tmp/x"))
	assert_true(Fetcher.is_local("C:\\feed"))
	assert_true(not Fetcher.is_local("https://github.com/x"))
	assert_eq(Fetcher.local_path("file:///tmp/a%20b"), "/tmp/a b")
	assert_eq(Fetcher.join("https://h/channels/", "a.pck"), "https://h/channels/a.pck")
	assert_eq(Fetcher.join("https://h/channels", "https://cdn/a.pck"), "https://cdn/a.pck")
	assert_eq(Fetcher.join("/feed", "a.pck"), "/feed/a.pck")


func test_check_downloads_and_stages_pack() -> void:
	var c := _client("e2e")
	var progress := [0, 0]
	c.download_progress.connect(func(d: int, t: int) -> void:
		progress[0] = d
		progress[1] = t)
	var r: Dictionary = await c.check(_ctx())
	assert_true(r["ok"], "check ok: " + String(r["error"]))
	assert_eq(r["decision"]["action"], Policy.READY)
	assert_eq(progress, [3000, 3000], "progress reported")
	assert_true(c.store.verify_slot("staged"), "staged pack verifies")
	assert_eq(c.store.slot_version("staged"), "0.2.0")
	assert_eq(Store.sha256_file(c.store.pck_path("staged")),
		Store.sha256_file(FIX + "feed/diceroll-0.2.0-desktop.pck"))
	assert_true(not FileAccess.file_exists(c.store.pck_path("staged") + ".part"), "no .part left")
	# second check: already staged, no re-download
	var r2: Dictionary = await c.check(_ctx())
	assert_eq(r2["decision"]["action"], Policy.READY)
	# next boot activates it
	var b := c.store.boot("4.7.2", "0.1.0")
	assert_true(b["activated"])
	assert_eq(c.store.slot_version("current"), "0.2.0")
	c.free()


func test_file_url_base() -> void:
	var c := _client("e2e_fileurl")
	var r: Dictionary = await c.check(_ctx({"base_url": "file://" + ProjectSettings.globalize_path(FIX + "feed")}))
	assert_true(r["ok"], String(r["error"]))
	assert_eq(r["decision"]["action"], Policy.READY)
	c.free()


func test_wrong_key_rejects() -> void:
	var c := _client("e2e_wrongkey")
	var r: Dictionary = await c.check(_ctx({"public_key": FileAccess.get_file_as_string(FIX + "test_wrong.pub.pem")}))
	assert_true(not r["ok"])
	assert_true(String(r["error"]).contains("signature"))
	assert_true(not c.store.has_pack("staged"), "nothing staged")
	c.free()


func test_placeholder_key_fails_closed() -> void:
	var c := _client("e2e_nokey")
	var r: Dictionary = await c.check(_ctx({"public_key": ""}))
	assert_true(not r["ok"])
	c.free()


func test_up_to_date_and_binary_paths() -> void:
	var c := _client("e2e_paths")
	var r: Dictionary = await c.check(_ctx({"version": "0.2.0"}))
	assert_true(r["ok"])
	assert_eq(r["decision"]["action"], Policy.NONE)
	r = await c.check(_ctx({"engine": "4.6.1"}))
	assert_eq(r["decision"]["action"], Policy.BINARY)
	assert_true(not c.store.has_pack("staged"), "binary path downloads nothing")
	r = await c.check(_ctx({"channel": "nightly"}))
	assert_true(not r["ok"], "missing channel feed is an error, not a crash")
	c.free()


func test_download_false_only_decides() -> void:
	var c := _client("e2e_nodl")
	var r: Dictionary = await c.check(_ctx({"download": false}))
	assert_eq(r["decision"]["action"], Policy.PACK)
	assert_true(not c.store.has_pack("staged"))
	c.free()

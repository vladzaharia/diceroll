extends "res://tests/test_case.gd"
## Runtime update-channel override (Developer menu): persistence, use by UpdatePolicy /
## Updater / UpdateClient, reset, store lock-out and the no-downgrade guard.

const Policy := preload("res://game/update/update_policy.gd")
const Client := preload("res://game/update/update_client.gd")
const Store := preload("res://game/update/update_store.gd")
const UpdaterScript := preload("res://game/update/updater.gd")

const FIX := "res://tests/fixtures/update/"
const ROOT := "user://test_updates/channel"
const CFG := ROOT + "/settings.cfg"


func _fresh() -> void:
	Store._rm_tree(ROOT)
	DirAccess.make_dir_recursive_absolute(ROOT)


func _info(over := {}) -> Dictionary:
	var i := {"version": "0.1.0", "commit": "abc1234", "channel": "stable", "distribution": "github",
		"godot": "4.7.2", "built": "2026-09-29T12:00:00Z"}
	i.merge(over, true)
	return i


func _updater(info_over := {}, platform := "macos") -> Node:
	var up: Node = UpdaterScript.new()
	up.info = _info(info_over)
	up.settings_path = CFG
	up.platform = platform
	return up


func test_channels_match_release_workflow() -> void:
	# tools/ci/update_manifest.py writes update-stable.json and update-beta.json only
	assert_eq(Policy.CHANNELS, ["stable", "beta"])
	var py := FileAccess.get_file_as_string("res://tools/ci/update_manifest.py")
	assert_true(py.contains("\"beta\" if \"-\" in v else \"stable\""), "manifest script channel rule changed")


func test_override_persists() -> void:
	_fresh()
	assert_eq(Policy.channel_override(CFG), "", "no override yet")
	assert_true(Policy.set_channel_override("beta", CFG))
	assert_eq(Policy.channel_override(CFG), "beta")
	# survives a fresh read of the file and keeps other settings
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(CFG), OK)
	cfg.set_value("game", "speed", 2.0)
	cfg.save(CFG)
	assert_true(Policy.set_channel_override("stable", CFG))
	cfg.load(CFG)
	assert_eq(cfg.get_value("update", "channel"), "stable")
	assert_eq(cfg.get_value("game", "speed"), 2.0, "other settings kept")
	assert_true(not Policy.set_channel_override("nightly", CFG), "unknown channel rejected")
	assert_eq(Policy.channel_override(CFG), "stable")
	# a hand-edited unknown value is ignored
	cfg.set_value("update", "channel", "alpha")
	cfg.save(CFG)
	assert_eq(Policy.channel_override(CFG), "")


func test_policy_uses_override() -> void:
	_fresh()
	var info := _info()
	assert_eq(Policy.effective_channel(info, CFG, "macos"), "stable", "build default")
	Policy.set_channel_override("beta", CFG)
	assert_eq(Policy.effective_channel(info, CFG, "macos"), "beta")
	assert_eq(Policy.effective_channel(_info({"channel": "beta"}), CFG, "windows.x86_64"), "beta")
	Policy.set_channel_override("stable", CFG)
	assert_eq(Policy.effective_channel(_info({"channel": "beta"}), CFG, "linux.x86_64"), "stable",
		"override beats a beta build default")
	assert_eq(Policy.build_channel(_info({"channel": "weird"})), "stable", "unknown build channel -> stable")


func test_updater_and_client_use_override() -> void:
	_fresh()
	var up := _updater()
	assert_eq(up.channel(), "stable")
	assert_eq(up.check_context()["channel"], "stable")
	Policy.set_channel_override("beta", CFG)
	assert_eq(up.channel(), "beta")
	assert_true(up.has_channel_override())
	var ctx: Dictionary = up.check_context()
	assert_eq(ctx["channel"], "beta", "Updater passes the override to the client")
	# the client then fetches + validates update-beta.json
	ctx["base_url"] = ProjectSettings.globalize_path(FIX + "feed")
	ctx["public_key"] = FileAccess.get_file_as_string(FIX + "test_signing.pub.pem")
	ctx["download"] = false
	var c := Client.new(Store.new(ROOT + "/store"))
	var r: Dictionary = await c.check(ctx)
	assert_true(r["ok"], "beta check ok: " + String(r["error"]))
	assert_eq(r["manifest"].get("channel"), "beta")
	assert_eq(r["decision"]["version"], "0.3.0-beta.1")
	assert_eq(r["decision"]["action"], Policy.PACK)
	c.free()
	up.free()


func test_reset_to_build_default() -> void:
	_fresh()
	var up := _updater({"channel": "beta"})
	Policy.set_channel_override("stable", CFG)
	assert_eq(up.channel(), "stable")
	var r: Dictionary = await up.reset_channel()
	assert_true(not r["ok"], "headless build doesn't check")
	assert_eq(Policy.channel_override(CFG), "")
	assert_true(not up.has_channel_override())
	assert_eq(up.channel(), "beta", "back to build default")
	up.free()


func test_switch_persists_and_drops_staged_pack() -> void:
	_fresh()
	var up := _updater()
	up.store = Store.new(ROOT + "/store")
	var part: String = up.store.begin_staging()
	var f := FileAccess.open(part, FileAccess.WRITE)
	f.store_string("x")
	f.close()
	DirAccess.rename_absolute(part, up.store.pck_path("staged"))
	up.store.write_meta("staged", {"version": "0.2.0", "sha256": "00", "size": 1, "engine": "4.7.2"})
	assert_true(up.store.has_pack("staged"))
	var r: Dictionary = await up.switch_channel("beta")
	assert_true(not r["ok"], "no check in headless runs")
	assert_eq(Policy.channel_override(CFG), "beta", "switch persisted")
	assert_true(not up.store.has_pack("staged"), "old channel's staged pack dropped")
	r = await up.switch_channel("nightly")
	assert_true(String(r["error"]).contains("unknown channel"))
	assert_eq(Policy.channel_override(CFG), "beta")
	up.free()


func test_store_builds_lock_channel() -> void:
	_fresh()
	Policy.set_channel_override("beta", CFG)
	for d in ["appstore", "testflight", "play"]:
		assert_true(Policy.channel_lock_reason(d, "ios") != "", d + " locked")
		assert_eq(Policy.effective_channel(_info({"distribution": d}), CFG, "ios"), "stable", d + " ignores override")
	assert_true(Policy.channel_lock_reason("web", "web") != "")
	assert_true(Policy.channel_lock_reason("github", "ios") != "", "sideloaded iOS")
	assert_true(Policy.channel_lock_reason("github", "android") != "", "sideloaded Android")
	assert_eq(Policy.channel_lock_reason("github", "macos"), "")
	assert_eq(Policy.channel_lock_reason("github", "linux.arm64"), "")
	assert_eq(Policy.channel_lock_reason("dev", "macos"), "")
	var up := _updater({"distribution": "appstore"}, "ios")
	var r: Dictionary = await up.switch_channel("stable")
	assert_true(not r["ok"] and String(r["error"]).contains("App Store"), "switch refused on store builds")
	assert_eq(Policy.channel_override(CFG), "beta", "override untouched")
	up.free()


func test_downgrade_guard() -> void:
	var m: Dictionary = preload("res://game/update/update_manifest.gd").parse(
		FileAccess.get_file_as_bytes(FIX + "feed/update-stable.json"), "stable")["manifest"]
	var ctx := {"distribution": "github", "platform": "macos", "engine": "4.7.2",
		"version": "0.3.0-beta.1", "binary_version": "0.3.0-beta.1"}
	var d := Policy.decide(m, ctx)
	assert_eq(d["action"], Policy.NONE, "stable 0.2.0 never replaces 0.3.0-beta.1")
	assert_true(d["behind"])
	assert_true(String(d["reason"]).contains("no downgrade"))
	# even a min_supported bump on the lower channel can't force a downgrade
	m["min_supported"] = "9.0.0"
	d = Policy.decide(m, ctx)
	assert_eq(d["action"], Policy.NONE)
	assert_true(not d["mandatory"])
	# same version / newer are not "behind"
	assert_true(not Policy.decide(m, {"version": "0.2.0", "distribution": "github"})["behind"])
	assert_true(Policy.is_downgrade("0.2.0", "0.3.0-beta.1"))
	assert_true(not Policy.is_downgrade("0.3.0", "0.3.0-beta.1"), "release > its prerelease")
	var text := Policy.describe_result({"ok": true, "decision": d}, "stable", "0.3.0-beta.1")
	assert_true(text.contains("Nothing is downgraded") and text.contains("0.3.0-beta.1"), text)
	# the menu confirms beta -> stable while a prerelease runs
	assert_true(Policy.switch_needs_confirm("0.3.0-beta.1", "stable"))
	assert_true(not Policy.switch_needs_confirm("0.3.0", "stable"))
	assert_true(not Policy.switch_needs_confirm("0.3.0-beta.1", "beta"))


func test_downgrade_guard_client_end_to_end() -> void:
	_fresh()
	var c := Client.new(Store.new(ROOT + "/store_dg"))
	var r: Dictionary = await c.check({"base_url": ProjectSettings.globalize_path(FIX + "feed"),
		"channel": "stable", "public_key": FileAccess.get_file_as_string(FIX + "test_signing.pub.pem"),
		"distribution": "github", "platform": "macos", "engine": "4.7.2",
		"version": "0.3.0-beta.1", "binary_version": "0.3.0-beta.1"})
	assert_true(r["ok"], String(r["error"]))
	assert_eq(r["decision"]["action"], Policy.NONE)
	assert_true(not c.store.has_pack("staged"), "nothing downloaded")
	c.free()

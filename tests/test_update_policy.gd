extends "res://tests/test_case.gd"

const Policy := preload("res://game/update/update_policy.gd")
const Manifest := preload("res://game/update/update_manifest.gd")


func _m(over := {}) -> Dictionary:
	var m: Dictionary = Manifest.parse(FileAccess.get_file_as_bytes(
		"res://tests/fixtures/update/feed/update-stable.json"), "stable")["manifest"]
	m.merge(over, true)
	return m


func _ctx(over := {}) -> Dictionary:
	var c := {"distribution": "github", "platform": "macos", "engine": "4.7.2", "version": "0.1.0",
		"binary_version": "0.1.0", "staged_version": "", "skip_version": ""}
	c.merge(over, true)
	return c


func test_pack_when_compatible() -> void:
	var d := Policy.decide(_m(), _ctx())
	assert_eq(d["action"], Policy.PACK)
	assert_eq(d["url"], "diceroll-0.2.0-desktop.pck")
	assert_true(not d["mandatory"])


func test_none_when_up_to_date() -> void:
	assert_eq(Policy.decide(_m(), _ctx({"version": "0.2.0"}))["action"], Policy.NONE)
	assert_eq(Policy.decide(_m(), _ctx({"version": "0.3.0"}))["action"], Policy.NONE)
	assert_eq(Policy.decide(_m({"version": "0.2.0-rc.1"}), _ctx({"version": "0.2.0-rc.1"}))["action"], Policy.NONE)
	assert_eq(Policy.decide(_m(), _ctx({"version": "0.2.0-rc.1"}))["action"], Policy.PACK, "rc -> release")


func test_binary_when_engine_differs() -> void:
	var d := Policy.decide(_m({"engine": "4.8.0"}), _ctx())
	assert_eq(d["action"], Policy.BINARY)
	assert_eq(d["url"], "https://example.invalid/diceroll-0.2.0-macos.zip")
	d = Policy.decide(_m({"engine": "4.8.0"}), _ctx({"platform": "linux.arm64"}))
	assert_eq(d["url"], "https://example.invalid/diceroll-0.2.0-linux-arm64.zip")
	d = Policy.decide(_m({"engine": "4.8.0"}), _ctx({"platform": "linux.riscv64"}))
	assert_eq(d["url"], "https://github.com/vladzaharia/diceroll/releases/tag/v0.2.0", "falls back to notes_url")


func test_binary_when_below_min_binary_or_no_pack() -> void:
	assert_eq(Policy.decide(_m({"min_binary": "0.1.5"}), _ctx())["action"], Policy.BINARY)
	assert_eq(Policy.decide(_m({"min_binary": "0.1.5"}), _ctx({"version": "0.1.7"}))["action"], Policy.BINARY,
		"running a 0.1.7 pack on a 0.1.0 binary")
	assert_eq(Policy.decide(_m({"pack": {}}), _ctx())["action"], Policy.BINARY)


func test_running_pack_uses_binary_version_for_min_binary() -> void:
	var d := Policy.decide(_m({"version": "0.3.0", "min_binary": "0.1.0"}), _ctx({"version": "0.2.0", "binary_version": "0.1.0"}))
	assert_eq(d["action"], Policy.PACK)


func test_mandatory_min_supported() -> void:
	var d := Policy.decide(_m({"min_supported": "0.2.0"}), _ctx())
	assert_eq(d["action"], Policy.BINARY)
	assert_true(d["mandatory"])
	# even when content is current (pack 0.2.0 on binary 0.1.0), an old binary must update
	d = Policy.decide(_m({"min_supported": "0.2.0"}), _ctx({"version": "0.2.0"}))
	assert_eq(d["action"], Policy.BINARY)
	assert_true(d["mandatory"])


## The live beta manifest that flagged every rc build: min_supported "0.1.0" on a 0.1.0-rc.6
## release (a prerelease sorts below its release, so the build "failed" its own floor).
func _rc_manifest(over := {}) -> Dictionary:
	var m := _m({"channel": "beta", "version": "0.1.0-rc.6", "min_supported": "0.1.0", "min_binary": "0.1.0"})
	m.merge(over, true)
	return m


func test_prerelease_at_channel_version_is_up_to_date() -> void:
	var d := Policy.decide(_rc_manifest(), _ctx({"version": "0.1.0-rc.6", "binary_version": "0.1.0-rc.6"}))
	assert_eq(d["action"], Policy.NONE)
	assert_true(not d["mandatory"], "nothing newer exists, so nothing can be required")
	var r := {"ok": true, "decision": d}
	assert_eq(Policy.describe_result(r, "beta", "0.1.0-rc.6"), "Up to date on beta (v0.1.0-rc.6).")
	# a running pack at the channel version on an older rc binary: still nothing to require
	d = Policy.decide(_rc_manifest(), _ctx({"version": "0.1.0-rc.6", "binary_version": "0.1.0-rc.6"}))
	assert_eq(d["action"], Policy.NONE)


func test_prerelease_below_channel_version_updates_but_not_required() -> void:
	var d := Policy.decide(_rc_manifest(), _ctx({"version": "0.1.0-rc.5", "binary_version": "0.1.0-rc.5"}))
	assert_eq(d["action"], Policy.PACK, "min_binary above the release is capped at the release")
	assert_true(not d["mandatory"], "rc.6 doesn't satisfy min_supported 0.1.0 either: not required")
	d = Policy.decide(_rc_manifest({"min_supported": "0.1.0-rc.6"}),
		_ctx({"version": "0.1.0-rc.5", "binary_version": "0.1.0-rc.5"}))
	assert_eq(d["action"], Policy.BINARY)
	assert_true(d["mandatory"], "rc.6 satisfies an rc.6 floor: rc.5 must update")


func test_min_supported_bump_on_stable_and_beta() -> void:
	# stable 0.3.0 raises the floor to 0.3.0: 0.2.x must take the binary
	var d := Policy.decide(_m({"version": "0.3.0", "min_supported": "0.3.0"}), _ctx({"version": "0.2.0", "binary_version": "0.2.0"}))
	assert_eq(d["action"], Policy.BINARY)
	assert_true(d["mandatory"])
	d = Policy.decide(_m({"version": "0.3.0", "min_supported": "0.3.0"}), _ctx({"version": "0.3.0", "binary_version": "0.3.0"}))
	assert_eq(d["action"], Policy.NONE)
	assert_true(not d["mandatory"])
	# beta 0.4.0-beta.2 raises the floor to 0.4.0-beta.1
	var b := {"channel": "beta", "version": "0.4.0-beta.2", "min_supported": "0.4.0-beta.1"}
	d = Policy.decide(_m(b), _ctx({"version": "0.3.0", "binary_version": "0.3.0"}))
	assert_eq(d["action"], Policy.BINARY)
	assert_true(d["mandatory"])
	d = Policy.decide(_m(b), _ctx({"version": "0.4.0-beta.1", "binary_version": "0.4.0-beta.1"}))
	assert_true(not d["mandatory"], "already at the floor")
	d = Policy.decide(_m(b), _ctx({"version": "0.4.0-beta.2", "binary_version": "0.4.0-beta.2"}))
	assert_eq(d["action"], Policy.NONE)
	assert_true(not d["mandatory"])
	# a floor above the channel's own version can't be met by updating: never required
	d = Policy.decide(_m({"version": "0.3.0", "min_supported": "0.4.0"}), _ctx({"version": "0.2.0", "binary_version": "0.2.0"}))
	assert_true(not d["mandatory"])
	d = Policy.decide(_m({"version": "0.3.0", "min_supported": "0.4.0"}), _ctx({"version": "0.3.0", "binary_version": "0.3.0"}))
	assert_eq(d["action"], Policy.NONE)
	assert_true(not d["mandatory"])


func test_none_is_never_mandatory() -> void:
	# store build with no listing for this platform, and a distribution updated elsewhere
	for dist in ["appstore", "steam"]:
		var d := Policy.decide(_m({"min_supported": "0.2.0", "stores": {}}), _ctx({"distribution": dist}))
		assert_eq(d["action"], Policy.NONE, dist)
		assert_true(not d["mandatory"], dist)


func test_ready_and_skip() -> void:
	assert_eq(Policy.decide(_m(), _ctx({"staged_version": "0.2.0"}))["action"], Policy.READY)
	var d := Policy.decide(_m(), _ctx({"skip_version": "0.2.0"}))
	assert_eq(d["action"], Policy.BINARY, "rolled-back pack not re-downloaded")


func test_store_builds() -> void:
	var d := Policy.decide(_m(), _ctx({"distribution": "appstore", "platform": "ios"}))
	assert_eq(d["action"], Policy.STORE)
	assert_eq(d["url"], "https://apps.apple.com/app/id000000000")
	d = Policy.decide(_m(), _ctx({"distribution": "play", "platform": "android"}))
	assert_eq(d["url"], "https://play.google.com/store/apps/details?id=gg.vlad.diceroll")
	assert_eq(Policy.decide(_m({"stores": {}}), _ctx({"distribution": "play"}))["action"], Policy.NONE)
	assert_eq(Policy.decide(_m(), _ctx({"distribution": "appstore", "version": "0.2.0"}))["action"], Policy.NONE)


func test_other_distributions_do_nothing() -> void:
	for dist in ["itch", "steam", "web", "dev"]:
		assert_eq(Policy.decide(_m(), _ctx({"distribution": dist}))["action"], Policy.NONE, dist)


func test_build_info_defaults() -> void:
	var info := Policy.build_info("res://tests/fixtures/update/does_not_exist.json")
	assert_eq(info["distribution"], "dev")
	assert_eq(info["channel"], "stable")
	assert_eq(info["version"], ProjectSettings.get_setting("application/config/version"))
	assert_eq(info["godot"], Policy.engine_version())
	var b := Policy.build_info("res://tests/fixtures/update/build_info.json")
	assert_eq(b["distribution"], "github")
	assert_eq(b["version"], "0.2.0")
	assert_eq(b["channel"], "beta")


func test_platform_and_urls() -> void:
	var k := Policy.platform_key()
	assert_true(k in ["macos", "windows.x86_64", "windows.arm64", "linux.x86_64", "linux.arm64"], k)
	assert_eq(Policy.manifest_name("beta"), "update-beta.json")
	assert_true(Policy.base_url().begins_with("https://") or OS.get_environment(Policy.ENV_BASE_URL) != "")

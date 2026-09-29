extends "res://tests/test_case.gd"

const Semver := preload("res://game/update/semver.gd")


func test_basic_ordering() -> void:
	assert_eq(Semver.compare("0.1.0", "0.2.0"), -1)
	assert_eq(Semver.compare("0.10.0", "0.9.9"), 1, "numeric, not lexical")
	assert_eq(Semver.compare("1.0.0", "1.0.0"), 0)
	assert_eq(Semver.compare("v1.2.3", "1.2.3"), 0, "leading v")
	assert_eq(Semver.compare("1.2", "1.2.0"), 0, "missing patch")
	assert_eq(Semver.compare("2.0.0", "1.99.99"), 1)


func test_prerelease_ordering() -> void:
	# spec example: 1.0.0-alpha < -alpha.1 < -alpha.beta < -beta < -beta.2 < -beta.11 < -rc.1 < 1.0.0
	var chain := ["1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2",
		"1.0.0-beta.11", "1.0.0-rc.1", "1.0.0"]
	for i in chain.size() - 1:
		assert_eq(Semver.compare(chain[i], chain[i + 1]), -1, "%s < %s" % [chain[i], chain[i + 1]])
		assert_eq(Semver.compare(chain[i + 1], chain[i]), 1, "%s > %s" % [chain[i + 1], chain[i]])
	assert_true(Semver.compare("0.2.0-rc.1", "0.2.0") < 0, "rc below release")
	assert_true(Semver.is_newer("0.2.0-rc.1", "0.1.9"), "rc of next above previous release")


func test_build_metadata_ignored() -> void:
	assert_eq(Semver.compare("1.0.0+abc", "1.0.0+def"), 0)
	assert_eq(Semver.compare("1.0.0-rc.1+build.5", "1.0.0-rc.1"), 0)
	assert_eq(Semver.compare("1.0.1+x", "1.0.0"), 1)


func test_invalid_versions() -> void:
	for bad in ["", "abc", "1.x.0", "1.2.3.4", "1.0.0-", "1.0.0-a..b", "-1.0.0"]:
		assert_true(not Semver.is_valid(bad), "invalid: '%s'" % bad)
	assert_eq(Semver.compare("garbage", "0.0.1"), -1, "invalid sorts lowest")
	assert_true(not Semver.is_newer("garbage", "0.1.0"))

extends RefCounted
## Pure update decisions + build/environment facts. No class_name, no autoload dependencies.
##
##   const Policy := preload("res://game/update/update_policy.gd")
##   var info := Policy.build_info()          # res://build_info.json or dev defaults
##   var d := Policy.decide(manifest, ctx)    # {"action", "mandatory", "url", "version", "reason"}

const Semver := preload("res://game/update/semver.gd")

const BUILD_INFO_PATH := "res://build_info.json"
const DEFAULT_BASE_URL := "https://github.com/vladzaharia/diceroll/releases/download/channels"
const BASE_URL_SETTING := "diceroll/update/base_url"
const ENV_BASE_URL := "DICEROLL_UPDATE_BASE_URL"
const ENV_TOKEN := "DICEROLL_UPDATE_TOKEN"

## Distributions that update themselves through this code.
const DIST_GITHUB := "github"
const STORE_DISTS := {"appstore": "ios", "play": "android"}

## decide() actions
const NONE := "none"          # nothing to do
const PACK := "pack"          # download manifest.pack, then "Restart to update"
const READY := "ready"        # that pack is already staged: "Restart to update"
const BINARY := "binary"      # needs a new executable: open url (release / binary download)
const STORE := "store"        # iOS / Android: open the store page


## res://build_info.json (written by CI at export) merged over dev defaults.
static func build_info(path := BUILD_INFO_PATH) -> Dictionary:
	var info := {
		"version": String(ProjectSettings.get_setting("application/config/version", "0.0.0")),
		"commit": "", "channel": "stable", "distribution": "dev", "godot": engine_version(), "built": "",
	}
	if FileAccess.file_exists(path):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(v) == TYPE_DICTIONARY:
			for k in v:
				if typeof(v[k]) == TYPE_STRING and v[k] != "":
					info[k] = v[k]
	return info


## "4.7.2" of the running executable.
static func engine_version() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v["major"], v["minor"], v["patch"]]


## Key into manifest.binaries / stores for this device.
static func platform_key() -> String:
	if OS.has_feature("web"):
		return "web"
	match OS.get_name():
		"macOS":
			return "macos"
		"iOS":
			return "ios"
		"Android":
			return "android"
		"Windows":
			return "windows." + _arch()
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			return "linux." + _arch()
	return OS.get_name().to_lower()


static func _arch() -> String:
	var a := Engine.get_architecture_name()
	return "arm64" if a in ["arm64", "aarch64"] else a


## Manifest base URL: env DICEROLL_UPDATE_BASE_URL > project setting > default.
static func base_url() -> String:
	var env := OS.get_environment(ENV_BASE_URL)
	if env != "":
		return env
	var s := String(ProjectSettings.get_setting(BASE_URL_SETTING, ""))
	return s if s != "" else DEFAULT_BASE_URL


static func manifest_name(channel: String) -> String:
	return "update-%s.json" % channel


## Decides what to do about a validated manifest. ctx:
##   distribution  build_info distribution ("github", "appstore", "play", ...)
##   platform      platform_key()
##   engine        engine_version()
##   version       effective version (running pack if any, else binary)
##   binary_version version of the executable
##   staged_version version already downloaded into staged/ ("" if none)
##   skip_version  a pack version that was rolled back ("" if none)
## Returns {"action": NONE|PACK|READY|BINARY|STORE, "mandatory": bool, "url": String,
##          "version": String, "reason": String}.
static func decide(m: Dictionary, ctx: Dictionary) -> Dictionary:
	var ver := String(m.get("version", ""))
	var dist := String(ctx.get("distribution", "dev"))
	var bin := String(ctx.get("binary_version", ctx.get("version", "")))
	var cur := String(ctx.get("version", bin))
	var min_sup := String(m.get("min_supported", ""))
	var mandatory := min_sup != "" and Semver.compare(bin, min_sup) < 0
	var newer := Semver.is_newer(ver, cur)
	var out := {"action": NONE, "mandatory": mandatory, "url": "", "version": ver, "reason": ""}
	if not newer and not mandatory:
		out["reason"] = "up to date (%s >= %s)" % [cur, ver]
		return out
	if STORE_DISTS.has(dist):
		# Android: Play In-App Updates (via a Godot Android plugin) is a future option; for
		# now both stores just open the listing.
		var url := String((m.get("stores", {}) as Dictionary).get(STORE_DISTS[dist], ""))
		if url != "":
			out["action"] = STORE
			out["url"] = url
		out["reason"] = "store build"
		return out
	if dist != DIST_GITHUB:
		out["reason"] = "distribution '%s' updates elsewhere" % dist
		return out
	var pack: Dictionary = m.get("pack", {}) if typeof(m.get("pack")) == TYPE_DICTIONARY else {}
	if not mandatory and newer:
		if String(ctx.get("staged_version", "")) == ver:
			out["action"] = READY
			out["reason"] = "already staged"
			return out
		var skip := String(ctx.get("skip_version", "")) == ver
		var engine_ok := String(m.get("engine", "")) == String(ctx.get("engine", ""))
		var bin_ok := Semver.compare(bin, String(m.get("min_binary", "0.0.0"))) >= 0
		if not pack.is_empty() and engine_ok and bin_ok and not skip:
			out["action"] = PACK
			out["url"] = String(pack["url"])
			out["reason"] = "content update"
			return out
		out["reason"] = "pack rolled back" if skip else ("no pack" if pack.is_empty()
			else ("engine %s != %s" % [m.get("engine"), ctx.get("engine")] if not engine_ok
			else "binary %s < min_binary %s" % [bin, m.get("min_binary")]))
	else:
		out["reason"] = "binary %s < min_supported %s" % [bin, min_sup]
	out["action"] = BINARY
	out["url"] = binary_url(m, String(ctx.get("platform", "")))
	return out


## Download URL for a new executable: binaries[platform].url, else the release notes page.
static func binary_url(m: Dictionary, platform: String) -> String:
	var b: Variant = (m.get("binaries", {}) as Dictionary).get(platform)
	if typeof(b) == TYPE_DICTIONARY and String(b.get("url", "")) != "":
		return String(b["url"])
	return String(m.get("notes_url", ""))

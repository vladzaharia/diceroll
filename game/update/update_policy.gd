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
const DIST_DEV := "dev"
const STORE_DISTS := {"appstore": "ios", "play": "android"}
## Other store-managed distributions (updates + track chosen by the store, never by us).
const STORE_MANAGED := ["appstore", "testflight", "play"]

## Update channels the release workflow publishes (tools/ci/update_manifest.py writes
## update-stable.json for final releases, update-beta.json for prereleases, and refreshes
## beta on every final release). Keep in sync with that script.
const CHANNELS := ["stable", "beta"]
const DEFAULT_CHANNEL := "stable"
## Runtime channel override (Developer menu): user://settings.cfg [update] channel.
const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "update"
const SETTINGS_CHANNEL := "channel"

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


# ------------------------------------------------------------------ channel override

static func is_channel(ch: String) -> bool:
	return ch in CHANNELS


## Build default channel (build_info "channel"; unknown values fall back to stable).
static func build_channel(info: Dictionary) -> String:
	var ch := String(info.get("channel", DEFAULT_CHANNEL))
	return ch if is_channel(ch) else DEFAULT_CHANNEL


## Saved override ("" when none or not a published channel).
static func channel_override(cfg_path := SETTINGS_PATH) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return ""
	var ch := String(cfg.get_value(SETTINGS_SECTION, SETTINGS_CHANNEL, ""))
	return ch if is_channel(ch) else ""


## Saves `ch` as the override (clear_channel_override() goes back to the build default).
## Returns false for a channel the release workflow doesn't publish.
static func set_channel_override(ch: String, cfg_path := SETTINGS_PATH) -> bool:
	if not is_channel(ch):
		return false
	var cfg := ConfigFile.new()
	cfg.load(cfg_path)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_CHANNEL, ch)
	return cfg.save(cfg_path) == OK


static func clear_channel_override(cfg_path := SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(cfg_path) != OK:
		return
	if cfg.has_section_key(SETTINGS_SECTION, SETTINGS_CHANNEL):
		cfg.erase_section_key(SETTINGS_SECTION, SETTINGS_CHANNEL)
		cfg.save(cfg_path)


## Channel the updater uses: the override when set and allowed for this build, else the
## build default. Store / sideload builds ignore the override (their store picks the track).
static func effective_channel(info: Dictionary, cfg_path := SETTINGS_PATH, platform := "") -> String:
	var o := channel_override(cfg_path)
	var plat := platform if platform != "" else platform_key()
	if o != "" and channel_lock_reason(String(info.get("distribution", DIST_DEV)), plat) == "":
		return o
	return build_channel(info)


## Why the channel can't be switched in this build ("" = it can). Self-updating builds are
## GitHub desktop builds (and dev builds, which save the choice but never check).
static func channel_lock_reason(dist: String, platform: String) -> String:
	if dist in STORE_MANAGED:
		return ("This build updates through %s, which picks the release track. Use a GitHub "
			+ "desktop build to switch channels.") % {"appstore": "the App Store / TestFlight",
			"testflight": "TestFlight", "play": "Google Play"}[dist]
	if dist == "web":
		return "The web build always serves the latest release; there is no channel to pick."
	if dist == DIST_DEV:
		return ""
	if dist != DIST_GITHUB:
		return "This '%s' build is updated by its storefront, not the in-game updater." % dist
	if platform.get_slice(".", 0) not in ["macos", "windows", "linux"]:
		return "Sideloaded mobile builds update through AltStore / SideStore / Obtainium, not the in-game updater."
	return ""


## True when switching to a channel whose latest version is `target` would mean going back
## from `current`. The updater never downgrades (decide() returns NONE with behind=true).
static func is_downgrade(target: String, current: String) -> bool:
	return target != "" and Semver.compare(target, current) < 0


## Moving to `to_ch` while running a prerelease that `to_ch` can't contain (e.g. beta ->
## stable on 0.3.0-beta.1): the menu confirms first and explains that nothing is downgraded.
static func switch_needs_confirm(current_version: String, to_ch: String) -> bool:
	var p := Semver.parse(current_version)
	return to_ch == "stable" and bool(p.get("ok", false)) and not (p["pre"] as Array).is_empty()


## One-line, player-readable summary of a check result for `channel` (used by the dev menu).
static func describe_result(r: Dictionary, channel: String, current: String) -> String:
	if not bool(r.get("ok", false)):
		return "Check failed: %s" % String(r.get("error", "unknown error"))
	var d: Dictionary = r.get("decision", {})
	var ver := String(d.get("version", ""))
	match String(d.get("action", NONE)):
		PACK, READY:
			return "%s v%s downloaded. Restart to update." % [channel.capitalize(), ver]
		BINARY:
			return "%s v%s needs a new download (see the update banner)." % [channel.capitalize(), ver]
		STORE:
			return "%s v%s is available in the store." % [channel.capitalize(), ver]
	if bool(d.get("behind", false)):
		return ("%s is at v%s, older than the running v%s. Nothing is downgraded: you stay on "
			+ "v%s until %s ships a newer version.") % [channel.capitalize(), ver, current, current, channel]
	return "Up to date on %s (v%s)." % [channel, current]


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
	var out := _decide(m, ctx)
	# "required" only ever accompanies an action the player can take: NONE (up to date, behind,
	# a store build without a listing, a distribution updated elsewhere) is never mandatory.
	if String(out["action"]) == NONE:
		out["mandatory"] = false
	return out


static func _decide(m: Dictionary, ctx: Dictionary) -> Dictionary:
	var ver := String(m.get("version", ""))
	var dist := String(ctx.get("distribution", "dev"))
	var bin := String(ctx.get("binary_version", ctx.get("version", "")))
	var cur := String(ctx.get("version", bin))
	var min_sup := String(m.get("min_supported", ""))
	var newer := Semver.is_newer(ver, cur)
	# min_supported only makes an update *required* when there is something to update to: the
	# channel's version is newer than the executable and itself satisfies min_supported. A
	# manifest whose min_supported the release fails (e.g. "0.1.0" on 0.1.0-rc.6, since a
	# prerelease sorts below its release) must never flag the build that is already on it.
	var mandatory := (min_sup != "" and Semver.compare(bin, min_sup) < 0
		and Semver.is_newer(ver, bin) and Semver.compare(ver, min_sup) >= 0)
	# behind: the channel's latest is older than what runs (e.g. beta -> stable on a beta
	# build). Never a downgrade: nothing to do until the channel passes the running version.
	var out := {"action": NONE, "mandatory": mandatory, "url": "", "version": ver, "reason": "",
		"behind": is_downgrade(ver, cur)}
	if out["behind"]:
		# even a min_supported bump on that channel would send us to an older version
		out["mandatory"] = false
		out["reason"] = "channel behind (%s < %s): no downgrade" % [ver, cur]
		return out
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
		# a release can't need an executable newer than itself: a min_binary above the version
		# is a manifest slip (old CI wrote "0.1.0" on every 0.1.0-rc.N, refusing every rc
		# binary), so it is ignored and only the engine match gates the pack
		var min_bin := String(m.get("min_binary", "0.0.0"))
		if min_bin == "" or Semver.compare(min_bin, ver) > 0:
			min_bin = "0.0.0"
		var bin_ok := Semver.compare(bin, min_bin) >= 0
		if not pack.is_empty() and engine_ok and bin_ok and not skip:
			out["action"] = PACK
			out["url"] = String(pack["url"])
			out["reason"] = "content update"
			return out
		out["reason"] = "pack rolled back" if skip else ("no pack" if pack.is_empty()
			else ("engine %s != %s" % [m.get("engine"), ctx.get("engine")] if not engine_ok
			else "binary %s < min_binary %s" % [bin, min_bin]))
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

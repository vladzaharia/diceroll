extends Node
## Updater autoload (`Updater`, FIRST in [autoload]). Class-less and free of global classes /
## other autoloads so it works before anything else and across --main-pack versions.
##
## Desktop GitHub builds (build_info distribution "github"):
##   boot   staged pack verified -> current (current -> previous); if current/diceroll.pck
##          exists and we were not started with --main-pack, relaunch the same executable with
##          `--main-pack <abs current pck>` (+ the original args) and quit. Running a pack for
##          BOOT_OK_SECONDS marks the boot good; MAX_BOOT_ATTEMPTS bad boots roll back.
##   check  after the title shows (at most every CHECK_INTERVAL unless forced / check_now()):
##          signed manifest -> content pack download -> update_ready, or binary_update_available.
## iOS / Android store builds only check and emit store_update_available(url).
## Web, itch, Steam and dev builds never check (they update elsewhere / are always latest).
## Everything is inert in the editor, headless runs, the screenshot/scenario harness and dev
## builds; activation and automatic checks are skipped when the player turns Auto-update off
## (user://settings.cfg [update] auto).
##
##   Updater.update_ready.connect(func(version): ...)
##   Updater.check_now()            # manual "Check now" (coroutine; returns the check result)
##   Updater.restart_to_update()    # apply the staged pack and relaunch into it
##   Updater.set_auto_enabled(false)

## Download progress of a content pack (0..100).
signal download_progress(percent: int)
## A content pack is downloaded + verified in staged/: offer "Restart to update".
signal update_ready(version: String)
## A newer version needs a new executable: open `url` (OS.shell_open). No binary self-replace
## yet; a future swap step would download binaries[platform] here instead.
signal binary_update_available(version: String, url: String, mandatory: bool)
## Store builds (iOS / Android): open the store listing.
signal store_update_available(version: String, url: String, mandatory: bool)
## Every finished check: the UpdateClient result {"ok", "error", "decision", "manifest"}.
signal check_finished(result: Dictionary)

const Policy := preload("res://game/update/update_policy.gd")
const Store := preload("res://game/update/update_store.gd")
const Client := preload("res://game/update/update_client.gd")
const Keys := preload("res://game/update/update_keys.gd")

const SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "update"
const SETTINGS_AUTO := "auto"
const BANNER_SCRIPT := "res://ui/widgets/update_banner.gd"
const CHECK_INTERVAL := 6 * 3600
const CHECK_DELAY := 4.0
const BOOT_OK_SECONDS := 10.0
## User args we add when relaunching into a pack.
const ARG_PACK := "--diceroll-pack="
const ARG_BINARY_VERSION := "--diceroll-binary-version="
const DESKTOP := ["macos", "windows", "linux"]

var info: Dictionary = {}
var store: Store
var client: Client
## Running from a downloaded pack (started with --main-pack by the boot relaunch).
var running_pack := false
## Last decision / state for UI: "", "downloading", "ready", "binary", "store".
var status := ""
var status_version := ""
var status_url := ""
var status_mandatory := false
var _banner: Node
var _layer: CanvasLayer


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	info = Policy.build_info()
	running_pack = _started_with_pack()
	if not can_apply_packs():
		return
	store = Store.new()
	if running_pack:
		return
	store.set_state("binary_version", info["version"])
	var boot := store.boot(Policy.engine_version(), info["version"])
	for line in boot["log"]:
		print("Updater: ", line)
	if boot["pack"] != "":
		_relaunch(boot["pack"])


func _ready() -> void:
	if not _active():
		return
	if running_pack and can_apply_packs():
		get_tree().create_timer(BOOT_OK_SECONDS, true, false, true).timeout.connect(func() -> void:
			store.mark_boot_ok())
	if is_auto_enabled() and can_check():
		get_tree().create_timer(CHECK_DELAY, true, false, true).timeout.connect(func() -> void:
			check_now(false))


# ------------------------------------------------------------------ gating

## Headless / editor / screenshot-harness runs: the updater never does anything.
func _active() -> bool:
	if DisplayServer.get_name() == "headless" or OS.has_feature("editor") or Engine.is_editor_hint():
		return false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenario") or a.begins_with("--shot"):
			return false
	return true


func is_desktop() -> bool:
	return Policy.platform_key().get_slice(".", 0) in DESKTOP


## Content packs are applied only by exported desktop GitHub builds with Auto-update on.
func can_apply_packs() -> bool:
	return _active() and OS.has_feature("template") and info.get("distribution") == Policy.DIST_GITHUB \
		and is_desktop() and is_auto_enabled()


## Builds that look for updates at all (GitHub desktop + App Store / Play).
func can_check() -> bool:
	if not _active() or OS.has_feature("web"):
		return false
	var d := String(info.get("distribution", "dev"))
	return (d == Policy.DIST_GITHUB and is_desktop()) or Policy.STORE_DISTS.has(d)


static func is_auto_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return true
	return bool(cfg.get_value(SETTINGS_SECTION, SETTINGS_AUTO, true))


static func set_auto_enabled(on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(SETTINGS_SECTION, SETTINGS_AUTO, on)
	cfg.save(SETTINGS_PATH)


# ------------------------------------------------------------------ versions

## Version of the running content (the pack when running one).
func current_version() -> String:
	return String(info.get("version", "0.0.0"))


## Version of the executable (differs from current_version() while running a pack).
func binary_version() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(ARG_BINARY_VERSION):
			return a.substr(ARG_BINARY_VERSION.length())
	if running_pack and store:
		return String(store.get_state("binary_version", current_version()))
	return current_version()


func _started_with_pack() -> bool:
	if "--main-pack" in OS.get_cmdline_args():
		return true
	for a in OS.get_cmdline_user_args():
		if a.begins_with(ARG_PACK):
			return true
	return false


# ------------------------------------------------------------------ checking

## Checks for an update (force=true ignores the 6 h throttle) and, for a content update,
## downloads it. Coroutine; returns the UpdateClient result ({"ok": false} when not allowed).
func check_now(force := true) -> Dictionary:
	if not can_check():
		return {"ok": false, "error": "updates not supported in this build", "decision": {"action": Policy.NONE}}
	if store == null:
		store = Store.new()
	var now := int(Time.get_unix_time_from_system())
	if not force and now - store.last_check() < CHECK_INTERVAL:
		return {"ok": false, "error": "checked recently", "decision": {"action": Policy.NONE}}
	if client == null:
		client = Client.new(store)
		client.name = "Client"
		add_child(client)
		var token := OS.get_environment(Policy.ENV_TOKEN)
		if token != "":
			client.fetcher.headers = PackedStringArray(["Authorization: Bearer " + token])
		client.download_progress.connect(_on_progress)
	store.set_last_check(now)
	var ctx := {
		"base_url": Policy.base_url(), "channel": info.get("channel", "stable"),
		"public_key": Keys.PUBLIC_KEY_PEM, "distribution": info.get("distribution", "dev"),
		"platform": Policy.platform_key(), "engine": Policy.engine_version(),
		"version": current_version(), "binary_version": binary_version(),
		"download": info.get("distribution") == Policy.DIST_GITHUB and is_desktop(),
	}
	var r: Dictionary = await client.check(ctx)
	if not r["ok"]:
		push_warning("Updater: check failed: %s" % r["error"])
		if status == "downloading":
			_set_status("")
	var d: Dictionary = r["decision"]
	var ver := String(d.get("version", ""))
	match String(d.get("action", Policy.NONE)):
		Policy.READY:
			_set_status("ready", ver)
			update_ready.emit(ver)
		Policy.BINARY:
			_set_status("binary", ver, d["url"], d["mandatory"])
			binary_update_available.emit(ver, d["url"], d["mandatory"])
		Policy.STORE:
			_set_status("store", ver, d["url"], d["mandatory"])
			store_update_available.emit(ver, d["url"], d["mandatory"])
	check_finished.emit(r)
	return r


func _on_progress(done: int, total: int) -> void:
	var pct := int(100.0 * done / total) if total > 0 else 0
	if status != "downloading":
		_set_status("downloading")
	download_progress.emit(pct)


# ------------------------------------------------------------------ applying

## Applies the staged pack and relaunches into it (the "Restart" button). Falls back to a
## plain relaunch, whose boot step activates it, when the pack can't be moved while running
## (Windows keeps the running pack open).
func restart_to_update() -> void:
	if store == null or not store.has_pack("staged"):
		return
	if store.activate_staged():
		_relaunch(store.pck_abs("current"))
	else:
		OS.create_process(OS.get_executable_path(), _base_args(), false)
		get_tree().quit()


## Opens a binary / store download link.
func open_download(url := "") -> void:
	var u := url if url != "" else status_url
	if u != "":
		OS.shell_open(u)


func dismiss() -> void:
	if _banner:
		_banner.queue_free()
		_banner = null


func _relaunch(pack: String) -> void:
	store.note_launch()
	var args := PackedStringArray(["--main-pack", pack])
	args.append_array(_base_args([ARG_PACK + store.slot_version("current"),
		ARG_BINARY_VERSION + binary_version()]))
	var pid := OS.create_process(OS.get_executable_path(), args, false)
	if pid <= 0:
		push_error("Updater: relaunch failed, running the built-in version")
		store.mark_boot_ok()
		return
	# Quit before the main scene shows anything (it is still built this frame; keep it silent).
	AudioServer.set_bus_mute(0, true)
	get_tree().quit()


## Original engine args without any --main-pack, then "--" + original user args (minus ours)
## + `extra`.
func _base_args(extra: Array = []) -> PackedStringArray:
	var out := PackedStringArray()
	var args := OS.get_cmdline_args()
	var i := 0
	while i < args.size():
		if args[i] == "--main-pack":
			i += 2
			continue
		out.append(args[i])
		i += 1
	var user := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if not a.begins_with(ARG_PACK) and not a.begins_with(ARG_BINARY_VERSION):
			user.append(a)
	for a in extra:
		user.append(a)
	if not user.is_empty():
		out.append("--")
		out.append_array(user)
	return out


# ------------------------------------------------------------------ banner

func _set_status(s: String, ver := "", url := "", mandatory := false) -> void:
	status = s
	status_version = ver
	status_url = url
	status_mandatory = mandatory
	if s == "":
		dismiss()
		return
	if _banner == null and ResourceLoader.exists(BANNER_SCRIPT):
		if _layer == null:
			_layer = CanvasLayer.new()
			_layer.name = "UpdateLayer"
			_layer.layer = 90
			add_child(_layer)
		_banner = (load(BANNER_SCRIPT) as GDScript).new()
		_layer.add_child(_banner)
		_banner.call("bind", self)
	if _banner:
		_banner.call("refresh")

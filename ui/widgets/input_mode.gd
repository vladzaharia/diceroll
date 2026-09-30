class_name InputMode
extends Node
## Keyboard / mouse ("kbm") vs touch mode, for desktop-only affordances (the GameButton hover
## keycap, hover art). Spec docs/design/2026-09-30-ui-reskin.md section 6:
##   - kbm on desktop builds (OS "pc", not web_ios / web_android) until a touch arrives;
##   - any touch (or touch-emulated mouse event) switches to touch;
##   - a real mouse button / motion or any key switches back to kbm.
## A Settings override ([input] hover_hints in user://settings.cfg: "auto" / "always" /
## "never") and the screenshot flag `--input=touch|kbm` pin the mode.
##
##   InputMode.is_kbm()                         # show hover keycaps?
##   InputMode.instance(get_tree()).changed.connect(func(kbm: bool) -> void: ...)
##   InputMode.set_override("never")            # Settings: Auto / Always / Never
##
## The watcher node is added to the tree root on first use (GameButton does it), so no
## autoload is needed; the static state works without it (tests call note_event()).

signal changed(kbm: bool)

const CFG := "user://settings.cfg"
const OVERRIDES := ["auto", "always", "never"]

static var _inst: InputMode
static var _kbm := true
static var _started := false
static var _override := ""
static var _forced := ""


## The watcher (created and added to `tree`'s root on first call; null without a tree).
static func instance(tree: SceneTree = null) -> InputMode:
	_start()
	if _inst != null and is_instance_valid(_inst):
		return _inst
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_inst = InputMode.new()
	_inst.name = "InputMode"
	_inst.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child.call_deferred(_inst)
	return _inst


## True in keyboard / mouse mode (after the override and the shot flag).
static func is_kbm() -> bool:
	_start()
	if _forced != "":
		return _forced == "kbm"
	match _override:
		"always":
			return true
		"never":
			return false
	return _kbm


static func is_touch() -> bool:
	return not is_kbm()


## Default mode before any input: kbm on desktop builds, touch on mobile / mobile web.
static func platform_default_kbm() -> bool:
	return OS.has_feature("pc") and not (OS.has_feature("web_ios") or OS.has_feature("web_android") or OS.has_feature("mobile"))


## Settings override: "auto" (follow the last input), "always", "never". Persisted.
static func override_mode() -> String:
	_start()
	return _override if _override != "" else "auto"


static func set_override(mode: String, persist := true) -> void:
	_start()
	var was := is_kbm()
	_override = mode if mode in OVERRIDES else "auto"
	if persist:
		var cfg := ConfigFile.new()
		cfg.load(CFG)
		cfg.set_value("input", "hover_hints", _override)
		cfg.save(CFG)
	_emit_if(was)


## Feeds one input event (the watcher calls this; tests may too).
static func note_event(e: InputEvent) -> void:
	_start()
	var was := is_kbm()
	if e is InputEventScreenTouch or e is InputEventScreenDrag:
		_kbm = false
	elif e is InputEventMouseButton or e is InputEventMouseMotion:
		# touch-emulated mouse events carry the emulation device id: they are touches
		if e.device != InputEvent.DEVICE_ID_EMULATION:
			if e is InputEventMouseMotion and (e as InputEventMouseMotion).relative.length() < 0.5:
				return
			_kbm = true
	elif e is InputEventKey and (e as InputEventKey).pressed:
		_kbm = true
	_emit_if(was)


## Test hook: back to the platform default, no override, no flag.
static func reset(kbm: Variant = null) -> void:
	_started = true
	_kbm = platform_default_kbm() if kbm == null else bool(kbm)
	_override = ""
	_forced = ""


static func _start() -> void:
	if _started:
		return
	_started = true
	_kbm = platform_default_kbm()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--input="):
			var v := a.substr(8)
			_forced = "touch" if v == "touch" else ("kbm" if v in ["kbm", "mouse", "desktop"] else "")
	var cfg := ConfigFile.new()
	if cfg.load(CFG) == OK:
		var o := String(cfg.get_value("input", "hover_hints", "auto"))
		_override = o if o in OVERRIDES and o != "auto" else ""


static func _emit_if(was: bool) -> void:
	var now := is_kbm()
	if now != was and _inst != null and is_instance_valid(_inst):
		_inst.changed.emit(now)


func _input(event: InputEvent) -> void:
	note_event(event)

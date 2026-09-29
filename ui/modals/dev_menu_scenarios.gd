extends RefCounted
## Screenshot scenarios for the hidden Developer menu (registered in tools/scenarios.gd):
##   dev_menu          title screen, menu just unlocked (toast), GitHub desktop build
##   dev_menu_confirm  running a beta prerelease, STABLE picked: the no-downgrade confirmation
##   dev_menu_store    App Store build: channel picker disabled with the explanation
##   dev_menu_boot     the menu over the missing-assets boot screen
## The Updater autoload is inert in the harness; these only stage its `info` / `platform`
## (and point its settings at a scratch file so nothing touches user://settings.cfg).

const NAMES := ["dev_menu", "dev_menu_confirm", "dev_menu_store", "dev_menu_boot"]
const SCRATCH_CFG := "user://dev_menu_scenario.cfg"


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	var info := {"version": "0.4.0", "commit": "38b2c2d9a1f4", "channel": "stable", "distribution": "github",
		"godot": "4.7.2", "built": "2026-09-29T12:00:00Z"}
	match name:
		"dev_menu_confirm":
			info["version"] = "0.5.0-beta.2"
			info["channel"] = "beta"
		"dev_menu_store":
			info["distribution"] = "appstore"
	_stage_updater(info, "ios" if name == "dev_menu_store" else "macos")
	var root: Node
	var gesture: DevGesture
	if name == "dev_menu_boot":
		root = AssetCheck.screen()
		for c in root.get_children():
			if c is DevGesture:
				gesture = c
	else:
		root = load("res://ui/scenarios.gd").build("ui_title")
		var title := root.find_children("*", "TitleScreen", true, false)
		gesture = (title[0] as TitleScreen).dev_gesture
	root.ready.connect(func() -> void:
		var m := gesture.open_menu(true)
		if name == "dev_menu":
			gesture.toast("Developer menu unlocked")
		elif name == "dev_menu_confirm":
			m._on_channel_pressed("stable"), CONNECT_DEFERRED)
	return root


static func _stage_updater(info: Dictionary, platform: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var up := tree.root.get_node_or_null("Updater") if tree else null
	if up == null:
		return
	up.set("info", info)
	up.set("platform", platform)
	up.set("settings_path", SCRATCH_CFG)
	DirAccess.remove_absolute(SCRATCH_CFG)

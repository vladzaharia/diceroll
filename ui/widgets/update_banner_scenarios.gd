extends RefCounted
## Screenshot scenarios for the update banner and GameButton sizing (tools/scenarios.gd PROVIDERS):
##   update_banner           title screen + "Update required v0.1.1" (mandatory: no [x])
##   update_banner_optional  title screen + "New version v0.1.1 available" [DOWNLOAD] [x]
##   update_banner_ready     title screen + "Update ready v0.1.1" [RESTART] [x]
##   ui_button_sizes         every text-button kind at 48..120 px drawn height (the _sm art
##                           at <= 72 px), with and without icons: lip contrast + label centring
## The Updater autoload is inert in the harness; these only drive its banner (_set_status).

const NAMES := ["update_banner", "update_banner_optional", "update_banner_ready", "ui_button_sizes"]
const HEIGHTS := [48, 56, 64, 72, 80, 88, 96, 120]


static func names() -> PackedStringArray:
	return PackedStringArray(NAMES)


static func build(name: String) -> Node:
	if not NAMES.has(name):
		return null
	if name == "ui_button_sizes":
		return _sizes()
	var root: Node = load("res://ui/scenarios.gd").build("ui_title")
	var tree := Engine.get_main_loop() as SceneTree
	var up := tree.root.get_node_or_null("Updater") if tree else null
	if up != null:
		root.ready.connect(_show.bind(up, name), CONNECT_DEFERRED)
		root.tree_exiting.connect(func() -> void: up.call("_set_status", ""))
	return root


static func _show(up: Node, name: String) -> void:
	match name:
		"update_banner":
			up.call("_set_status", "binary", "0.1.1", "https://example.invalid", true)
		"update_banner_optional":
			up.call("_set_status", "binary", "0.1.1", "https://example.invalid", false)
		"update_banner_ready":
			up.call("_set_status", "ready", "0.1.1")


static func _sizes() -> Node:
	var root := CanvasLayer.new()
	root.name = "ButtonSizes"
	var bg := ColorRect.new()
	bg.color = UiPalette.INK
	UiTheme.full_rect(bg)
	root.add_child(bg)
	var ui := Control.new()
	ui.theme = UiTheme.get_theme()
	UiTheme.full_rect(ui)
	root.add_child(ui)
	var col := UiTheme.vbox(10)
	var m := UiTheme.margin(col, 20, 20, 20, 20)
	UiTheme.full_rect(m)
	ui.add_child(m)
	var kinds := [GameButton.Kind.PRIMARY, GameButton.Kind.SECONDARY, GameButton.Kind.DANGER,
		GameButton.Kind.SUCCESS, GameButton.Kind.GHOST]
	for h in HEIGHTS:
		var row := UiTheme.hbox(10)
		row.add_child(UiTheme.label("%d" % h, 20, UiPalette.TEXT_MUTED, false, 0))
		for i in kinds.size():
			var fs := clampi(int(h * 0.42), 18, 40)
			var b := GameButton.make("GO" if i % 2 else "BUY", "coin" if i == 1 else "", kinds[i], fs)
			b.min_height = h
			b.pad_x = 14.0 if h <= 72 else 22.0
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(b)
		col.add_child(row)
	return root

extends Control
## Small self-contained update toast, top-centre, built in code. Created and owned by the
## Updater autoload (game/update/updater.gd) on its own CanvasLayer, so no screen has to host
## it; never shown in screenshot/scenario runs (the Updater is inert there).
##
##   Downloading update… 42%
##   Update ready (v0.2.0)            [RESTART]  [x]
##   New version v0.2.0 available     [DOWNLOAD] [x]   (binary / store; mandatory: no [x])
##
## The updater is duck-typed (status, status_version, status_mandatory, download_progress,
## restart_to_update(), open_download(), dismiss()) so this file stays out of its way.

var _updater: Node
var _panel: PanelContainer
var _text: Label
var _action: GameButton
var _close: GameButton
var _pct := 0


func bind(updater: Node) -> void:
	_updater = updater
	if updater.has_signal("download_progress"):
		updater.download_progress.connect(func(p: int) -> void:
			_pct = p
			refresh())


func _init() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# callout art (spec 4.3): ink + a Thin rim in the info blue
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.callout_box(UiPalette.PACK_BLUE), 20, 12))
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var row := UiTheme.hbox(12)
	_panel.add_child(row)
	row.add_child(Icons.rect("gear", 34, UiPalette.TEXT))
	_text = UiTheme.label("", 26, UiPalette.TEXT, true, 0)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 220
	row.add_child(_text)
	_action = GameButton.make("RESTART", "", GameButton.Kind.PRIMARY, 24)
	_action.min_height = 64
	_action.pad_x = 18
	_action.pressed.connect(_on_action)
	row.add_child(_action)
	_close = GameButton.round_icon("close", 56)
	_close.pressed.connect(func() -> void:
		if _updater:
			_updater.call("dismiss"))
	row.add_child(_close)
	resized.connect(_layout)


func _ready() -> void:
	refresh()


func refresh() -> void:
	if _updater == null:
		return
	var st := String(_updater.get("status"))
	var ver := String(_updater.get("status_version"))
	var mandatory := bool(_updater.get("status_mandatory"))
	var v := (" v" + ver) if ver != "" else ""
	match st:
		"downloading":
			_text.text = "Downloading update… %d%%" % _pct
			_action.visible = false
		"ready":
			_text.text = "Update ready%s" % v
			_action.text = "RESTART"
			_action.visible = true
		"binary", "store":
			_text.text = ("Update required%s" if mandatory else "New version%s available") % v
			_action.text = "DOWNLOAD" if st == "binary" else "UPDATE"
			_action.visible = true
	_close.visible = not mandatory
	_layout.call_deferred()


func _on_action() -> void:
	if _updater == null:
		return
	if String(_updater.get("status")) == "ready":
		_updater.call("restart_to_update")
	else:
		_updater.call("open_download", "")


func _layout() -> void:
	if not is_inside_tree():
		return
	var m := UiTheme.safe_margins(self)
	var w := minf(size.x - m.left - m.right, 640.0)
	_panel.size = Vector2(w, 0)
	_panel.reset_size()
	_panel.size.x = w
	_panel.position = Vector2((size.x - w) * 0.5, m.top)

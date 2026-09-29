class_name DevMenu
extends UiModal
## Hidden Developer menu (opened by DevGesture: 5 quick taps in the bottom-right corner of
## the boot / title screen). Sections of rows; built-ins:
##   updates (10)  update-channel picker, CHECK NOW, RESET TO BUILD DEFAULT, status line
##   build   (90)  version, commit, channel, distribution, Godot, build date + COPY DIAGNOSTICS
##
## Other systems add rows (before the menu is built, e.g. from their _ready):
##   DevMenu.register_section("debug", "DEBUG", 50)
##   DevMenu.register_row("debug", "fps", func(m: DevMenu) -> Control:
##       return m.info_row("FPS", str(Engine.get_frames_per_second())))
## Rows are built once per menu instance; row builders get the menu for its helpers
## (info_row, button_row, note) and `updater`.

const Policy := preload("res://game/update/update_policy.gd")

## id -> {"title": String, "order": int}
static var _sections: Dictionary = {}
## section id -> Array of {"id": String, "order": int, "build": Callable}
static var _rows: Dictionary = {}
static var _builtins := false

## The Updater autoload (or a stand-in); null = no updater (plain build info only).
var updater: Node
## Build info shown when there is no updater (defaults to UpdatePolicy.build_info()).
var info: Dictionary = {}

var _channel_btns: Dictionary = {}
var _channel_note: Label
var _status: Label
var _confirm: PanelContainer
var _confirm_text: Label
var _confirm_ok: GameButton
var _pending_channel := ""
var _check_btn: GameButton
var _reset_btn: GameButton
var _build_values: Dictionary = {}
var _busy := false


# ---------------------------------------------------------------- registration API

static func register_section(id: String, p_title: String, order := 50) -> void:
	_sections[id] = {"title": p_title, "order": order}
	if not _rows.has(id):
		_rows[id] = []


## Adds (or replaces, by id) a row. `build` is `func(menu: DevMenu) -> Control`.
static func register_row(section: String, id: String, build: Callable, order := 50) -> void:
	if not _sections.has(section):
		register_section(section, section.to_upper())
	unregister_row(section, id)
	(_rows[section] as Array).append({"id": id, "order": order, "build": build})
	(_rows[section] as Array).sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["order"] < b["order"])


static func unregister_row(section: String, id: String) -> void:
	if _rows.has(section):
		_rows[section] = (_rows[section] as Array).filter(func(r: Dictionary) -> bool: return r["id"] != id)


static func section_ids() -> PackedStringArray:
	_register_builtins()
	var ids: Array = _sections.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return int(_sections[a]["order"]) < int(_sections[b]["order"]))
	return PackedStringArray(ids)


static func row_ids(section: String) -> PackedStringArray:
	_register_builtins()
	var out := PackedStringArray()
	for r: Dictionary in _rows.get(section, []):
		out.append(r["id"])
	return out


static func _register_builtins() -> void:
	if _builtins:
		return
	_builtins = true
	register_section("updates", "UPDATES", 10)
	register_row("updates", "channel", func(m: DevMenu) -> Control: return m._channel_section(), 10)
	register_row("updates", "actions", func(m: DevMenu) -> Control: return m._actions_row(), 20)
	register_section("build", "BUILD", 90)
	register_row("build", "info", func(m: DevMenu) -> Control: return m._build_section(), 10)
	register_row("build", "copy", func(m: DevMenu) -> Control:
		return m.button_row("COPY DIAGNOSTICS", "", m.copy_diagnostics), 20)


# ---------------------------------------------------------------- build

func _build() -> void:
	set_title("DEVELOPER")
	max_width = 640.0
	_register_builtins()
	var first := true
	for sid in section_ids():
		if (_rows.get(sid, []) as Array).is_empty():
			continue
		if not first:
			body.add_child(UiTheme.spacer(2))
		first = false
		body.add_child(UiModal.section_label(String(_sections[sid]["title"])))
		for r: Dictionary in _rows[sid]:
			var c: Variant = (r["build"] as Callable).call(self)
			if c is Control:
				(c as Control).name = "%s_%s" % [sid, r["id"]]
				body.add_child(c)
	body.add_child(UiTheme.spacer(4))
	var done := GameButton.make("CLOSE", "close", GameButton.Kind.PRIMARY, 34)
	done.icon_tint = UiPalette.TEXT_DARK
	done.pressed.connect(func() -> void: close())
	body.add_child(done)


func _ready() -> void:
	super._ready()
	if updater == null:
		updater = get_tree().root.get_node_or_null("Updater")
	refresh()


# ---------------------------------------------------------------- row helpers (public)

## "Label ........ value" line.
func info_row(label_text: String, value: String) -> HBoxContainer:
	var r := UiTheme.hbox(12)
	var l := UiTheme.label(label_text, 22, UiPalette.TEXT_DIM, false, 0, false, 500)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	var v := UiTheme.label(value, 22, UiPalette.TEXT, false, 0, false, 600)
	v.name = "Value"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.clip_text = true
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	return r


func button_row(text: String, icon: String, action: Callable, kind := GameButton.Kind.SECONDARY) -> GameButton:
	var b := GameButton.make(text, icon, kind, 26)
	b.icon_tint = UiPalette.GOLD
	b.min_height = 76
	b.pressed.connect(action)
	return b


func note(text: String, color: Color = UiPalette.TEXT_DIM) -> Label:
	return UiTheme.para(text, 21, color)


# ---------------------------------------------------------------- updates section

func _channel_section() -> Control:
	var col := UiTheme.vbox(10)
	var r := UiTheme.hbox(10)
	col.add_child(r)
	r.add_child(UiIcons.rect("gear", 36, UiPalette.GOLD))
	var l := UiTheme.label("Channel", 28, UiPalette.TEXT, true, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	for ch: String in Policy.CHANNELS:
		var b := GameButton.make(ch.to_upper(), "", GameButton.Kind.SECONDARY, 24)
		b.name = "Channel_" + ch
		b.toggle_mode = true
		b.toggle_primary = true
		b.min_height = 72
		b.pad_x = 16
		b.pressed.connect(_on_channel_pressed.bind(ch))
		r.add_child(b)
		_channel_btns[ch] = b
	_channel_note = note("")
	_channel_note.name = "ChannelNote"
	col.add_child(_channel_note)
	# inline confirmation (beta -> stable while running a prerelease)
	_confirm = UiTheme.panel("inset")
	_confirm.name = "Confirm"
	_confirm.visible = false
	var cv := UiTheme.vbox(10)
	_confirm.add_child(cv)
	_confirm_text = note("", UiPalette.TEXT)
	cv.add_child(_confirm_text)
	var cr := UiTheme.hbox(10)
	cv.add_child(cr)
	_confirm_ok = GameButton.make("SWITCH", "check", GameButton.Kind.PRIMARY, 24)
	_confirm_ok.icon_tint = UiPalette.TEXT_DARK
	_confirm_ok.min_height = 68
	_confirm_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_ok.pressed.connect(func() -> void:
		var ch := _pending_channel
		_hide_confirm()
		_switch(ch))
	cr.add_child(_confirm_ok)
	var cancel := GameButton.make("CANCEL", "", GameButton.Kind.SECONDARY, 24)
	cancel.min_height = 68
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(func() -> void:
		_hide_confirm()
		refresh())
	cr.add_child(cancel)
	col.add_child(_confirm)
	_status = note("", UiPalette.GOLD_BRIGHT)
	_status.name = "Status"
	_status.visible = false
	col.add_child(_status)
	return col


func _actions_row() -> Control:
	var r := UiTheme.hbox(12)
	_check_btn = button_row("CHECK NOW", "reroll", check_now)
	_check_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(_check_btn)
	_reset_btn = button_row("RESET TO DEFAULT", "arrow_left", reset_channel)
	_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(_reset_btn)
	return r


func _build_section() -> Control:
	var p := UiTheme.panel("inset")
	var col := UiTheme.vbox(6)
	p.add_child(col)
	for k in [["version", "Version"], ["commit", "Commit"], ["channel", "Channel"],
			["distribution", "Distribution"], ["godot", "Godot"], ["built", "Built"]]:
		var row := info_row(k[1], "")
		col.add_child(row)
		_build_values[k[0]] = row.get_node("Value")
	return p


# ---------------------------------------------------------------- state

func _info() -> Dictionary:
	if updater != null and updater.get("info") is Dictionary and not (updater.get("info") as Dictionary).is_empty():
		return updater.get("info")
	if info.is_empty():
		info = Policy.build_info()
	return info


func _has(method: String) -> bool:
	return updater != null and updater.has_method(method)


func current_channel() -> String:
	return String(updater.call("channel")) if _has("channel") else Policy.build_channel(_info())


func build_channel() -> String:
	return Policy.build_channel(_info())


func has_override() -> bool:
	return bool(updater.call("has_channel_override")) if _has("has_channel_override") else false


## "" when the channel picker is usable in this build.
func lock_reason() -> String:
	if _has("channel_lock_reason"):
		return String(updater.call("channel_lock_reason"))
	return Policy.channel_lock_reason(String(_info().get("distribution", "dev")), Policy.platform_key())


func running_version() -> String:
	return String(updater.call("current_version")) if _has("current_version") else String(_info().get("version", ""))


func refresh(_flow: GameFlow = null) -> void:
	var i := _info()
	var ch := current_channel()
	var locked := lock_reason()
	for c: String in _channel_btns:
		var b: GameButton = _channel_btns[c]
		b.set_pressed_no_signal(c == ch)
		b.set_enabled(locked == "" and not _busy)
		b.call("_refresh")
	if _channel_note:
		if locked != "":
			_channel_note.text = locked
		elif has_override():
			_channel_note.text = "Override: %s (build default: %s). Saved on this device." % [ch, build_channel()]
		else:
			_channel_note.text = "Using the build default (%s). Picking a channel re-checks at once; the updater never downgrades." % ch
	if _check_btn:
		_check_btn.set_enabled(not _busy)
	if _reset_btn:
		_reset_btn.set_enabled(not _busy and locked == "" and has_override())
	for k: String in _build_values:
		var v := String(i.get(k, ""))
		if k == "channel":
			v = ch + ("  (override; build %s)" % build_channel() if ch != build_channel() else "")
		elif k == "commit" and v.length() > 12:
			v = v.substr(0, 12)
		(_build_values[k] as Label).text = v if v != "" else "—"
	relayout()


# ---------------------------------------------------------------- actions

func _on_channel_pressed(ch: String) -> void:
	if _busy or lock_reason() != "":
		refresh()
		return
	if ch == current_channel():
		refresh()
		return
	if Policy.switch_needs_confirm(running_version(), ch):
		_pending_channel = ch
		_confirm_text.text = ("You're running v%s (a prerelease). Switching to %s won't downgrade "
			+ "it: you keep v%s until %s ships a newer version, then update from %s.") % [
			running_version(), ch, running_version(), ch, ch]
		_confirm_ok.text = "SWITCH TO %s" % ch.to_upper()
		_confirm.visible = true
		refresh()
		return
	_switch(ch)


func _hide_confirm() -> void:
	_pending_channel = ""
	if _confirm:
		_confirm.visible = false
	relayout()


func _switch(ch: String) -> void:
	await _run("Switching to %s and checking…" % ch, ch, func() -> Dictionary:
		if _has("switch_channel"):
			return await updater.call("switch_channel", ch)
		Policy.set_channel_override(ch)
		return {})


func reset_channel() -> void:
	_hide_confirm()
	await _run("Back to the build default (%s); checking…" % build_channel(), build_channel(), func() -> Dictionary:
		if _has("reset_channel"):
			return await updater.call("reset_channel")
		Policy.clear_channel_override()
		return {})


func check_now() -> void:
	_hide_confirm()
	await _run("Checking %s…" % current_channel(), "", func() -> Dictionary:
		if _has("check_now"):
			return await updater.call("check_now", true)
		return {})


## Runs an updater action and shows its outcome in the status line.
func _run(busy_text: String, ch: String, action: Callable) -> void:
	if _busy:
		return
	_busy = true
	set_status(busy_text)
	refresh()
	var r: Dictionary = await action.call()
	_busy = false
	if not is_inside_tree():
		return
	var channel := ch if ch != "" else current_channel()
	if not _has("can_check") or not bool(updater.call("can_check")):
		var why := "This build doesn't check for updates (dev / harness / non-updating build), so nothing was fetched."
		set_status(("Channel set to %s. " % channel if ch != "" else "") + why)
	else:
		set_status(Policy.describe_result(r, channel, running_version()))
	refresh()


func set_status(text: String) -> void:
	if _status:
		_status.text = text
		_status.visible = text != ""
		relayout()


## Plain-text build + updater facts for bug reports.
func diagnostics() -> String:
	return diagnostics_text(_info(), current_channel(), has_override(), Policy.platform_key(),
		running_version())


static func diagnostics_text(i: Dictionary, channel: String, override: bool, platform: String,
		running: String) -> String:
	var lines := PackedStringArray(["diceroll diagnostics"])
	lines.append("version: %s" % i.get("version", ""))
	if running != "" and running != String(i.get("version", "")):
		lines.append("running: %s" % running)
	lines.append("commit: %s" % i.get("commit", ""))
	lines.append("channel: %s%s" % [channel, " (override; build %s)" % Policy.build_channel(i) if override else ""])
	lines.append("distribution: %s" % i.get("distribution", ""))
	lines.append("godot: %s" % i.get("godot", Policy.engine_version()))
	lines.append("built: %s" % i.get("built", ""))
	lines.append("platform: %s (%s)" % [platform, OS.get_name()])
	return "\n".join(lines)


func copy_diagnostics() -> void:
	DisplayServer.clipboard_set(diagnostics())
	toast(get_parent() if get_parent() else self, "Diagnostics copied")


# ---------------------------------------------------------------- toast

## Small pill at the bottom centre of `host`'s view that fades out on its own.
static func toast(host: Node, text: String, seconds := 1.8) -> void:
	if host == null or not host.is_inside_tree():
		return
	var root := Control.new()
	root.name = "DevToast"
	root.theme = UiTheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTheme.full_rect(root)
	host.add_child(root)
	var pill := UiTheme.panel("pill")
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(UiTheme.label(text, 22, UiPalette.TEXT_DIM, false, 0, false, 600))
	root.add_child(pill)
	pill.modulate.a = 0.0
	var place := func() -> void:
		pill.reset_size()
		var view := root.get_viewport().get_visible_rect().size
		var m := UiTheme.safe_margins(root)
		pill.position = Vector2((view.x - pill.size.x) * 0.5, view.y - m.bottom - pill.size.y - 96.0)
	place.call_deferred()
	var t := root.create_tween()
	t.tween_interval(0.02)
	t.tween_property(pill, "modulate:a", 1.0, 0.18)
	t.tween_interval(seconds)
	t.tween_property(pill, "modulate:a", 0.0, 0.35)
	t.tween_callback(root.queue_free)

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
## (info_row, button_row, note, section_title) and `updater`.
##
## Look: its own "slate" skin (direction C of the reskin mockups) so it never passes for part
## of normal play: Square Corners grey-dark frame over a grey-darker container, a slate
## plaque, slate / teal buttons, monospace values and a DEVELOPER tag. Only the `dev_*` pieces
## of ui/theme/ui_pack.json are used here; every player-facing modal keeps the wood + navy kit.

const Policy := preload("res://game/update/update_policy.gd")

## Slate palette (pack grey family) + the tooling accent (muted teal, never the game's yellow).
const SLATE_BG := Color("324652")
const SLATE_RIM := Color("476475")
const SLATE_DEEP := Color("16242d")
const SLATE_DIM := Color("a3b8c3")
const SLATE_MUTED := Color("7b97a6")
const TEAL := Color("5ccfc3")
const TEAL_BRIGHT := Color("8ae6db")
const MONO_NAMES := ["JetBrains Mono", "SF Mono", "Menlo", "Cascadia Mono", "Consolas",
	"DejaVu Sans Mono", "Liberation Mono", "Roboto Mono", "monospace"]

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
var _confirm_cancel: GameButton
var _pending_channel := ""
var _check_btn: GameButton
var _reset_btn: GameButton
var _build_values: Dictionary = {}
var _busy := false
## 1 / 0 = the dev frame for a desktop / phone canvas is applied; -1 = not yet.
var _skin_lg := -1
static var _mono: Font
static var _mono_settings: Dictionary = {}


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
		var b := m.button_row("COPY DIAGNOSTICS", "copy", m.copy_diagnostics)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		return b, 20)


# ---------------------------------------------------------------- build

func _build() -> void:
	_install_plaque()
	ScrollFade.attach(self, _scroll, SLATE_BG, _frame)
	set_title("DEV TOOLS")
	max_width = 640.0
	# one exit (spec 3.2): the header close button, Esc and the backdrop; the channel-switch
	# confirm turns them off while it is up (its CANCEL / SWITCH are the exits, Esc = CANCEL)
	dismissible = true
	_register_builtins()
	body.add_child(_dev_tag())
	for sid in section_ids():
		if (_rows.get(sid, []) as Array).is_empty():
			continue
		body.add_child(section_title(String(_sections[sid]["title"])))
		for r: Dictionary in _rows[sid]:
			var c: Variant = (r["build"] as Callable).call(self)
			if c is Control:
				(c as Control).name = "%s_%s" % [sid, r["id"]]
				body.add_child(c)


func _ready() -> void:
	super._ready()
	if updater == null:
		updater = get_tree().root.get_node_or_null("Updater")
	refresh()


# ---------------------------------------------------------------- row helpers (public)

## "Label ........ value" line (value in monospace).
func info_row(label_text: String, value: String) -> HBoxContainer:
	var r := UiTheme.hbox(12)
	var l := UiTheme.label(label_text, 22, SLATE_DIM, false, 0, false, 500)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	var v := mono_label(value, 21, UiPalette.TEXT)
	v.name = "Value"
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.clip_text = true
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	return r


## A slate (SECONDARY) or teal (PRIMARY) dev button.
func button_row(text: String, icon: String, action: Callable, kind := GameButton.Kind.SECONDARY) -> GameButton:
	var b := DevButton.make_dev(text, icon, kind, 26)
	b.min_height = 76
	b.pressed.connect(action)
	return b


func note(text: String, color: Color = SLATE_DIM) -> Label:
	return UiTheme.para(text, 21, color)


## Section header: teal monospace caps + a hairline rule ("UPDATES ────────").
func section_title(text: String) -> Control:
	var r := UiTheme.hbox(14)
	r.add_child(mono_label(text.to_upper(), 19, TEAL, 3))
	var rule := ColorRect.new()
	rule.color = Color(TEAL, 0.3)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(rule)
	return r


## Monospace label (system mono font, Fredoka when the platform has none); `spacing` px
## between glyphs for caps tags.
static func mono_label(text: String, size: int, color: Color, spacing := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var key := "%d|%s|%d" % [size, color.to_html(), spacing]
	if not _mono_settings.has(key):
		var ls := LabelSettings.new()
		var f := mono_font()
		if spacing != 0:
			var v := FontVariation.new()
			v.base_font = f
			v.spacing_glyph = spacing
			f = v
		ls.font = f
		ls.font_size = size
		ls.font_color = color
		_mono_settings[key] = ls
	l.label_settings = _mono_settings[key]
	return l


static func mono_font() -> Font:
	if _mono == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(MONO_NAMES)
		f.font_weight = 500
		f.fallbacks = [UiTheme.body_font(600)]
		_mono = f
	return _mono


# ---------------------------------------------------------------- dev skin

## Swaps the base modal's yellow plaque for the slate dev plaque (same slot in the frame, so
## the plaque still straddles the frame top; UiAudit allows that overlap).
func _install_plaque() -> void:
	var old := ribbon
	var r := DevPlaque.new()
	r.font_size = 38
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.z_index = old.z_index
	r.set_meta(UiAudit.ALLOW, true)
	var at := old.get_index()
	_frame.remove_child(old)
	old.free()
	_frame.add_child(r)
	_frame.move_child(r, at)
	ribbon = r


## The base picks the wood frame per canvas size; the dev menu then puts its slate frame on.
func _apply_scale(view: Vector2) -> void:
	super._apply_scale(view)
	if _skin_lg != int(_large):
		_skin_lg = int(_large)
		panel.add_theme_stylebox_override("panel", dev_box("dev_panel_lg" if _large else "dev_panel"))


## A dev_* piece with a slate flat fallback (checkouts without the pack).
static func dev_box(piece: String) -> StyleBox:
	var fb: StyleBoxFlat
	match piece:
		"dev_panel", "dev_panel_lg":
			fb = UiTheme.box(SLATE_BG, 18, 6, SLATE_RIM)
			fb.set_content_margin_all(30)
		"dev_callout":
			fb = UiTheme.box(SLATE_DEEP, 14, 2, TEAL)
			fb.content_margin_left = 18
			fb.content_margin_right = 18
			fb.content_margin_top = 14
			fb.content_margin_bottom = 14
		"dev_chip":
			fb = UiTheme.box(TEAL, 12, 0)
			fb.content_margin_left = 12
			fb.content_margin_right = 12
			fb.content_margin_top = 2
			fb.content_margin_bottom = 2
		_:
			fb = UiTheme.box(Color(SLATE_DEEP, 0.85), 12, 0)
			fb.content_margin_left = 16
			fb.content_margin_right = 16
			fb.content_margin_top = 12
			fb.content_margin_bottom = 12
	return UiSkin.stylebox(piece, "normal", fb)


static func dev_panel(piece: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", dev_box(piece))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Top row: the teal DEVELOPER tag + what this menu is.
func _dev_tag() -> Control:
	var r := UiTheme.hbox(12)
	r.name = "DevTag"
	var chip := dev_panel("dev_chip")
	chip.name = "Tag"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(mono_label("DEVELOPER", 17, UiPalette.INK_LABEL, 2))
	r.add_child(chip)
	var t := mono_label("internal tools, not part of play", 18, SLATE_MUTED)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	r.add_child(t)
	return r


# ---------------------------------------------------------------- updates section

func _channel_section() -> Control:
	var col := UiTheme.vbox(10)
	var r := UiTheme.hbox(10)
	col.add_child(r)
	r.add_child(Icons.rect("gear", 34, TEAL))
	var l := UiTheme.label("Channel", 28, UiPalette.TEXT, true, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	for ch: String in Policy.CHANNELS:
		var b := DevButton.make_dev(ch.to_upper(), "", GameButton.Kind.SECONDARY, 24)
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
	_confirm = dev_panel("dev_callout")
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.name = "Confirm"
	_confirm.visible = false
	var cv := UiTheme.vbox(10)
	_confirm.add_child(cv)
	_confirm_text = note("", UiPalette.TEXT)
	cv.add_child(_confirm_text)
	var cr := UiTheme.hbox(10)
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_child(cr)
	_confirm_ok = DevButton.make_dev("SWITCH", "check", GameButton.Kind.PRIMARY, 24)
	_confirm_ok.icon_tint = UiPalette.TEXT_DARK
	_confirm_ok.min_height = 68
	_confirm_ok.pressed.connect(func() -> void:
		var ch := _pending_channel
		_hide_confirm()
		_switch(ch))
	cr.add_child(_confirm_ok)
	_confirm_cancel = DevButton.make_dev("CANCEL", "", GameButton.Kind.SECONDARY, 24)
	_confirm_cancel.name = "Cancel"
	_confirm_cancel.min_height = 68
	_confirm_cancel.pressed.connect(func() -> void:
		_hide_confirm()
		refresh())
	# cancel first: the safe option leads
	cr.add_child(_confirm_cancel)
	cr.move_child(_confirm_cancel, 0)
	col.add_child(_confirm)
	_status = note("", TEAL_BRIGHT)
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
	var p := dev_panel("dev_inset")
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
		_set_confirming(true)
		refresh()
		return
	_switch(ch)


func _hide_confirm() -> void:
	_pending_channel = ""
	if _confirm:
		_confirm.visible = false
	_set_confirming(false)
	relayout()


## While the channel-switch confirm is up the menu is a confirm dialog (spec 3.2): no close
## button, no backdrop; Esc and Enter press CANCEL (the safe option).
func _set_confirming(on: bool) -> void:
	dismissible = not on
	cancel_action = _confirm_cancel if on else null
	primary_action = _confirm_cancel if on else null


func is_confirming() -> bool:
	return _confirm != null and _confirm.visible


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

## Small toast at the bottom centre of `host`'s view that fades out on its own (Toast helper).
static func toast(host: Node, text: String, seconds := 1.8) -> void:
	Toast.show(host, text, "", UiPalette.TEXT_DIM, {"at": "bottom", "font": 22, "hold": seconds, "rise": 0.0})


# ---------------------------------------------------------------- dev widgets

## GameButton on the dev_* pieces: slate (SECONDARY), teal (PRIMARY / toggled on), dark
## slate (toggle off). Round icon buttons keep the shared round art.
class DevButton extends GameButton:
	static func make_dev(p_text: String, p_icon := "", p_kind := GameButton.Kind.SECONDARY, p_font := 26) -> DevButton:
		var b := DevButton.new()
		b.kind = p_kind
		b.font_size = p_font
		b.text = p_text
		b.icon_name = p_icon
		return b

	func piece() -> String:
		if is_round():
			return super.piece()
		var n := "dev_button"
		if toggle_mode and toggle_primary:
			n = "dev_button_accent" if button_pressed else "dev_button_dark"
		elif kind == GameButton.Kind.PRIMARY or kind == GameButton.Kind.SUCCESS:
			n = "dev_button_accent"
		return n + ("_sm" if min_height <= GameButton.SMALL_H else "")

	func _ink_face() -> bool:
		if is_round():
			return super._ink_face()
		return not piece().begins_with("dev_button_dark")

	func _text_color() -> Color:
		if not skinned():
			return super._text_color()
		if disabled:
			return DevMenu.SLATE_DIM
		return UiPalette.INK_LABEL if _ink_face() else UiPalette.TEXT

	func _colors() -> Array[Color]:
		# no pack: flat slate / teal instead of the game's yellow / blue
		if disabled:
			return [DevMenu.SLATE_RIM, DevMenu.SLATE_DEEP, Color(1, 1, 1, 0.06)]
		if _effective_kind() == GameButton.Kind.PRIMARY or kind == GameButton.Kind.SUCCESS:
			return [DevMenu.TEAL, Color("2c7f78"), DevMenu.TEAL_BRIGHT]
		return [DevMenu.SLATE_RIM, DevMenu.SLATE_DEEP, DevMenu.SLATE_DIM]


## The title plaque on the slate dev_plaque face (light ink title); without the pack, the
## drawn ribbon in slate.
class DevPlaque extends Ribbon:
	func _init() -> void:
		color = DevMenu.SLATE_RIM

	func skinned() -> bool:
		return UiSkin.has("dev_plaque")

	func _draw() -> void:
		if not skinned():
			_draw_ribbon()
			return
		draw_style_box(UiSkin.stylebox("dev_plaque", "normal", StyleBoxEmpty.new()), Rect2(Vector2.ZERO, size))
		var f := UiTheme.display_font()
		var fs := fitted_font()
		var t := shown_text()
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var face_mid := size.y * (4.0 + 46.0 * 0.5) / 64.0
		var base := face_mid + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		draw_string(f, Vector2((size.x - w) * 0.5, base), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiPalette.INK_LABEL)

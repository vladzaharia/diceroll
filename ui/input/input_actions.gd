class_name InputActions
extends RefCounted
## The game's keyboard actions: one table that registers the InputMap actions at boot, routes
## every shortcut (game_controller, menus, modals, minigames) and feeds the Settings ->
## Controls list, so the handlers, the hover keycaps and the Controls page can't drift apart.
## Spec docs/design/2026-09-30-ui-reskin.md section 6; plan ui-reskin/e-title-minigames-input.md.
##
##   InputActions.ensure()                       # registers the actions (main.gd, idempotent)
##   InputActions.pressed(event, "reroll")        # a fresh press of the action (no echo)
##   InputActions.list()                          # Controls rows: [{action, label, glyphs, group}]
##   InputActions.glyphs_for("pause")             # ["key_esc", "key_p"] (follows rebinding)
##   InputActions.glyph_for("primary")            # "key_space" (first binding)
##
## Every action is registered in code (project.godot has no [input] section), so the table
## is the one source. Keys may be shared between actions of different contexts (1-3 marks
## dice in combat and picks a cup in the shell game); a context only listens to its own.

## Run (board / combat) actions.
const PAUSE := "pause"
const PRIMARY := "primary"
const REROLL := "reroll"
const DIE := ["die_1", "die_2", "die_3", "die_4", "die_5", "die_6"]
## Menus: title, class select, run setup, modals, Camp.
const CONFIRM := "menu_confirm"
const BACK := "menu_back"
const NAV_LEFT := "nav_left"
const NAV_RIGHT := "nav_right"
const CONTROLS := "controls_help"
## Minigames (routed through each board's scripted_input).
const MG_ACTION := "mg_action"
const MG_PICK := ["mg_pick_1", "mg_pick_2", "mg_pick_3"]
const MG_LEFT := "mg_left"
const MG_RIGHT := "mg_right"
const MG_UP := "mg_up"
const MG_DOWN := "mg_down"
const MG_CASH := "mg_cash_out"

## action -> default keys (physical-layout independent keycodes).
const BINDINGS := {
	"pause": [KEY_ESCAPE, KEY_P],
	"primary": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	"reroll": [KEY_R],
	"die_1": [KEY_1], "die_2": [KEY_2], "die_3": [KEY_3],
	"die_4": [KEY_4], "die_5": [KEY_5], "die_6": [KEY_6],
	"menu_confirm": [KEY_ENTER, KEY_KP_ENTER],
	"menu_back": [KEY_ESCAPE],
	"nav_left": [KEY_LEFT],
	"nav_right": [KEY_RIGHT],
	"controls_help": [KEY_F1],
	"mg_action": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	"mg_pick_1": [KEY_1], "mg_pick_2": [KEY_2], "mg_pick_3": [KEY_3],
	"mg_left": [KEY_LEFT, KEY_A],
	"mg_right": [KEY_RIGHT, KEY_D],
	"mg_up": [KEY_UP, KEY_W],
	"mg_down": [KEY_DOWN, KEY_S],
	"mg_cash_out": [KEY_C],
}

## The Controls list, in display order. "actions" (optional) = several actions shown as one
## row (their glyphs joined, e.g. 1-6); otherwise the row is the single "action".
const ROWS := [
	{"action": "primary", "label": "Roll · Move · Attack", "group": "Run"},
	{"action": "reroll", "label": "Reroll", "group": "Run"},
	{"action": "pause", "label": "Pause", "group": "Run"},
	{"action": "die_1", "actions": DIE, "label": "Mark dice for a reroll", "group": "Combat",
		"range": true},
	{"action": "menu_confirm", "label": "Confirm · Start", "group": "Menus"},
	{"action": "menu_back", "label": "Back · Close", "group": "Menus"},
	{"action": "nav_left", "actions": ["nav_left", "nav_right"], "label": "Previous · Next",
		"group": "Menus"},
	{"action": "controls_help", "label": "Controls", "group": "Menus"},
	{"action": "mg_action", "label": "Drop · Spin · Shoot · Strike", "group": "Minigames"},
	{"action": "mg_left", "actions": ["mg_left", "mg_right"], "label": "Aim · Move",
		"group": "Minigames"},
	{"action": "mg_pick_1", "actions": MG_PICK, "label": "Pick a cup or a fishing spot",
		"group": "Minigames", "range": true},
	{"action": "mg_up", "actions": ["mg_up", "mg_down"], "label": "Higher · Lower",
		"group": "Minigames"},
	{"action": "mg_cash_out", "label": "Cash out", "group": "Minigames"},
]

## keycode -> input glyph id (icon_map "input_glyphs").
const KEY_GLYPHS := {
	KEY_SPACE: "key_space", KEY_ENTER: "key_enter", KEY_KP_ENTER: "key_enter",
	KEY_ESCAPE: "key_esc", KEY_P: "key_p", KEY_R: "key_r", KEY_C: "key_c", KEY_F1: "key_f1",
	KEY_1: "key_1", KEY_2: "key_2", KEY_3: "key_3", KEY_4: "key_4", KEY_5: "key_5",
	KEY_6: "key_6", KEY_TAB: "key_tab", KEY_SHIFT: "key_shift",
	KEY_LEFT: "key_left", KEY_RIGHT: "key_right", KEY_UP: "key_up", KEY_DOWN: "key_down",
}

static var _done := false


## Registers every action in the InputMap (missing ones only, so a later rebinding or a
## project.godot [input] entry wins). Idempotent; cheap after the first call.
static func ensure() -> void:
	if _done and InputMap.has_action(PAUSE):
		return
	_done = true
	for action in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code in BINDINGS[action]:
			var k := InputEventKey.new()
			k.keycode = code
			InputMap.action_add_event(action, k)


## All action names in the table.
static func actions() -> Array[String]:
	var out: Array[String] = []
	for a in BINDINGS:
		out.append(String(a))
	return out


## True when `event` is a fresh (non-echo) press of `action`.
static func pressed(event: InputEvent, action: String) -> bool:
	ensure()
	if event == null or event.is_echo():
		return false
	return event.is_action_pressed(action, false, true)


## Index of the first action in `names` that `event` presses, or -1 (1-6 dice, 1-3 picks).
static func pressed_index(event: InputEvent, names: Array) -> int:
	for i in names.size():
		if pressed(event, String(names[i])):
			return i
	return -1


## The keycodes currently bound to `action` (InputMap order).
static func keys_for(action: String) -> Array[int]:
	ensure()
	var out: Array[int] = []
	if not InputMap.has_action(action):
		return out
	for e in InputMap.action_get_events(action):
		var k := e as InputEventKey
		if k == null:
			continue
		var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		if code != KEY_NONE and not out.has(code):
			out.append(code)
	return out


## Glyph ids for `action`'s bindings (duplicates dropped: Enter and keypad Enter share one).
## Unknown keys map to "key_blank" (KeyGlyph then draws the key name via key_label()).
static func glyphs_for(action: String) -> Array[String]:
	var out: Array[String] = []
	for code in keys_for(action):
		var g := String(KEY_GLYPHS.get(code, "key_blank"))
		if not out.has(g) or g == "key_blank":
			out.append(g)
	return out


## First glyph id of `action` ("" when unbound): the hover keycap for its button.
static func glyph_for(action: String) -> String:
	var g := glyphs_for(action)
	return g[0] if not g.is_empty() else ""


## Human name of `action`'s first key ("Space", "Esc", "1"): minigame instruction copy.
static func key_label(action: String) -> String:
	var k := keys_for(action)
	if k.is_empty():
		return ""
	match k[0]:
		KEY_ESCAPE:
			return "Esc"
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
	return OS.get_keycode_string(k[0])


## The Settings -> Controls rows, built live from the InputMap:
##   {action, label, glyphs: [glyph_id...], group, actions: [..], range: bool}
## "glyphs" lists every glyph of the row ("range" rows are a key run such as 1-6; the list
## may render them as "[1]-[6]"). Groups in order: Run, Combat, Menus, Minigames.
static func list() -> Array[Dictionary]:
	ensure()
	var out: Array[Dictionary] = []
	for row in ROWS:
		var names: Array = row.get("actions", [row["action"]])
		var glyphs: Array[String] = []
		for a in names:
			for g in glyphs_for(String(a)):
				if not glyphs.has(g):
					glyphs.append(g)
		out.append({
			"action": String(row["action"]),
			"actions": names.duplicate(),
			"label": String(row["label"]),
			"glyphs": glyphs,
			"group": String(row["group"]),
			"range": bool(row.get("range", false)),
		})
	return out


## Distinct groups of list(), in order.
static func groups() -> Array[String]:
	var out: Array[String] = []
	for row in ROWS:
		if not out.has(String(row["group"])):
			out.append(String(row["group"]))
	return out

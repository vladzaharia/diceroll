class_name ClassCard
extends PanelContainer
## A tappable class card (run setup, class select, Wardrobe carousel): the class medallion,
## name, mechanic chip and HP. States: open, selected (gold rim + check), locked (dimmed,
## padlock + how it unlocks) and secret (the Monster Kid before its hidden milestone: a "???"
## mystery card with only the hint; never the name, icon or rule).
##
##   var c := ClassCard.make("ninja", ClassCard.State.SELECTED)
##   var c2 := ClassCard.make("paladin", ClassCard.State.LOCKED, "Win a run with the Knight.")
##   c.pressed.connect(...)
## `compact`: one row (medallion + name + chip), for grids; otherwise the rule line is added.

signal pressed

enum State { OPEN, SELECTED, LOCKED, SECRET }

const SECRET_HINT_DEFAULT := "A secret hero. Keep exploring."

var class_id := ""
var state: State = State.OPEN
var lock_text := ""
var compact := true
## Red "new" dot (Wardrobe: unseen skins).
var new_dot := false
var _down := false


static func make(id: String, p_state: State = State.OPEN, p_lock_text := "", p_compact := true, p_new := false) -> ClassCard:
	var c := ClassCard.new()
	c.class_id = id
	c.state = p_state
	c.lock_text = p_lock_text
	c.compact = p_compact
	c.new_dot = p_new
	c._build()
	return c


## The state a class shows for a profile (null = everything open, the legacy screen).
static func state_for(p: Profile, id: String, selected: String) -> State:
	if p != null and not p.class_allowed(id):
		return State.SECRET if is_secret(id) else State.LOCKED
	return State.SELECTED if id == selected else State.OPEN


## True for a secret class (HeroDefs `secret`: the Monster Kid).
static func is_secret(id: String) -> bool:
	return bool((HeroDefs.DATA.get(id, {}) as Dictionary).get("secret", false))


## The hidden milestone hint of a secret class ("" = none).
static func secret_hint(id: String) -> String:
	var m := CampInfo.milestone_for("classes", id)
	return String(m.get("hint", SECRET_HINT_DEFAULT)) if not m.is_empty() else SECRET_HINT_DEFAULT


## How a locked class unlocks (milestone text; Sigil price if it can be bought).
static func unlock_text(p: Profile, id: String) -> String:
	if is_secret(id):
		return secret_hint(id)
	return CampInfo.lock_text("classes", id, p)


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	var open := state == State.OPEN or state == State.SELECTED
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if open else Control.CURSOR_ARROW
	var accent := UiPalette.class_color(class_id)
	var sb: StyleBoxFlat
	match state:
		State.SELECTED:
			sb = UiTheme.box(UiPalette.NAVY_3, 20, 3, UiPalette.GOLD_BRIGHT, 12, Color(0.95, 0.7, 0.2, 0.3), Vector2.ZERO)
		State.OPEN:
			sb = UiTheme.box(Color(0.03, 0.03, 0.09, 0.6), 20, 2, Color(accent, 0.35))
		State.SECRET:
			sb = UiTheme.box(Color(0.08, 0.05, 0.14, 0.75), 20, 2, Color(ClassInfo.mechanic_color("boo"), 0.25))
		_:
			sb = UiTheme.box(Color(0.03, 0.03, 0.09, 0.35), 20, 2, Color(1, 1, 1, 0.05))
	UiTheme.pad(sb, 12, 10)
	add_theme_stylebox_override("panel", sb)
	var col := UiTheme.vbox(6)
	add_child(col)
	var row := UiTheme.hbox(10)
	col.add_child(row)
	var med: Control
	if state == State.SECRET:
		med = OptionCard.Medallion.make("question", 52, UiPalette.TEXT_MUTED, Color(0.45, 0.4, 0.6))
	else:
		med = OptionCard.Medallion.make(UiIcons.class_icon(class_id), 52, accent if open else UiPalette.TEXT_MUTED,
			accent if open else Color(0.4, 0.4, 0.5))
	med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(med)
	var txt := UiTheme.vbox(2)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(txt)
	var title := "???" if state == State.SECRET else String(HeroDefs.DATA[class_id].name)
	var tl := UiTheme.label(title, 24, (UiPalette.GOLD_BRIGHT if state == State.SELECTED else UiPalette.TEXT) if open else UiPalette.TEXT_MUTED, true, 4)
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tl.custom_minimum_size.x = 40
	txt.add_child(tl)
	if open:
		txt.add_child(mechanic_chip(class_id, 16))
	elif state == State.LOCKED:
		txt.add_child(CampUi.lock_line("Locked", 17))
	if state == State.SELECTED:
		var ck := UiIcons.rect("check", 28, UiPalette.GOLD_BRIGHT)
		ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ck)
	if new_dot:
		var dot := CampUi.chip("NEW", UiPalette.HP, UiPalette.TEXT, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(dot)
	if state == State.SECRET:
		var h := UiTheme.para(lock_text if lock_text != "" else secret_hint(class_id), 17, Color("b9a6d8"), 600)
		col.add_child(h)
	elif state == State.LOCKED and lock_text != "":
		col.add_child(UiTheme.para(lock_text, 16, UiPalette.TEXT_MUTED, 500))
	elif not compact:
		col.add_child(UiTheme.para(ClassInfo.tagline(class_id), 17, UiPalette.TEXT_DIM, 500))


## The mechanic chip: mechanic icon + name on a tinted pill ("" mechanic -> the class's
## starting runes, e.g. "Guard die").
static func mechanic_chip(id: String, size := 18) -> PanelContainer:
	var mech := ClassInfo.mechanic(id)
	var col := ClassInfo.mechanic_color(mech) if mech != "" else UiPalette.class_color(id)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(col.darkened(0.72), 0.95), 12, 2, Color(col, 0.7)), 8, 2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var r := UiTheme.hbox(5)
	p.add_child(r)
	var icon := UiIcons.mechanic_icon(mech) if mech != "" else UiIcons.rune_icon(String((HeroDefs.DATA[id].runes as Array)[0]))
	r.add_child(UiIcons.rect(icon, int(size * 1.35), col))
	var name := ClassInfo.mechanic_name(mech) if mech != "" else starter_text(id)
	r.add_child(UiTheme.label(name.to_upper(), size, col.lightened(0.25), false, 0, false, 800))
	return p


## "Guard die" / "Ember + Echo": the starting runes of a class without a mechanic.
static func starter_text(id: String) -> String:
	var bits := PackedStringArray()
	for r in HeroDefs.DATA[id].runes:
		if String(r) != "" and Runes.DEFS.has(String(r)):
			bits.append(String(Runes.DEFS[String(r)].name))
	return " + ".join(bits) if not bits.is_empty() else "Plain dice"


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_down = true
		accept_event()
	elif _down:
		_down = false
		accept_event()
		if get_global_rect().has_point(mb.global_position):
			if state == State.OPEN or state == State.SELECTED:
				UiTheme.sfx("click")
				UiTheme.pop(self, 1.04, 0.18)
				pressed.emit()
			else:
				UiTheme.sfx("error")
				UiTheme.pop(self, 1.03, 0.15)

class_name EventModal
extends UiModal
## Board event card (offer {kind:"event", id, title, text, choices}). Medallion art, flavour
## text and one card per choice (disabled choices greyed). Emits event_chosen(i).
## Also shows the Last Camp (offer {kind:"camp", healed, boss, choices}): a campfire medallion in
## a warm frame, the rest heal as a pill ("+N HP" by the fire) and the three gifts.

signal event_chosen(index: int)

const ART := {
	"shrine": ["star", Color("ffd86a")], "duel": ["dice", UiPalette.DIE_BODY], "outbreak": ["skull", Color("efe6d4")],
	"garden": ["rune_lucky", Color("7ad35a")], "merchant": ["coin", UiPalette.COIN], "idol": ["curse", UiPalette.CURSE],
	"ore": ["ore", Color("c4bcd4")], "camp": ["campfire", Color("ffb36a")],
}
## Frame colour per event id (default violet); the Deep Mines ore vein is teal.
const RIM := {"ore": Color("3fb8aa"), "camp": Color("ff9a4a")}
const CAMP_ICONS := {"potion": "potion_healing", "rune": "rune_wild", "steady": "reroll"}
const CHOICE_ICONS := {
	"atk": "sword", "max_hp": "heart", "gold": "3d:coins", "face": "anvil",
}

var _art: CenterContainer
var _text: Label
var _choices: VBoxContainer
## The Last Camp's rest pill ("RESTED +N HP"), hidden for other events.
var _rest: PanelContainer
var _rest_label: Label


func _build() -> void:
	_art = CenterContainer.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_art)
	_rest = PanelContainer.new()
	_rest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rest.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_rest.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.box(Color(UiPalette.HEAL, 0.16), 14, 2, Color(UiPalette.HEAL, 0.8)), 16, 4))
	var rr := UiTheme.hbox(8)
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	rr.add_child(UiIcons.rect("heart", 30))
	_rest_label = UiTheme.label("", 24, UiPalette.HEAL, true, 4)
	rr.add_child(_rest_label)
	_rest.add_child(rr)
	body.add_child(_rest)
	_text = UiTheme.para("", 26, UiPalette.TEXT, 500)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_text)
	body.add_child(UiTheme.spacer(4))
	_choices = UiTheme.vbox(12)
	body.add_child(_choices)


func refresh(flow: GameFlow) -> void:
	var o := flow.offer
	var id := String(o.get("id", ""))
	var rim: Color = RIM.get(id, Color("9a7ae0"))
	set_title(String(o.get("title", "Event")).to_upper(), rim)
	UiTheme.clear(_art)
	var art: Array = ART.get(id, ["star", UiPalette.GOLD])
	_art.add_child(OptionCard.Medallion.make(art[0], 132, art[1], rim))
	_text.text = String(o.get("text", ""))
	_rest.visible = id == "camp"
	if id == "camp":
		_rest_label.text = "RESTED  +%d HP" % int(o.get("healed", 0))
	UiTheme.clear(_choices)
	var choices: Array = o.get("choices", [])
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var c := OptionCard.make(String(ch.get("label", "")), String(ch.get("desc", "")))
		var icon := _choice_icon(id, ch, i)
		if icon != "":
			c.set_icon(icon)
		c.set_tag("", rim)
		c.set_enabled(bool(ch.get("enabled", true)))
		if not bool(ch.get("enabled", true)):
			c.set_tag("LOCKED", UiPalette.TEXT_MUTED)
		c.pressed.connect(func() -> void: event_chosen.emit(i))
		_choices.add_child(c)
	relayout()


static func _choice_icon(id: String, ch: Dictionary, i: int) -> String:
	if id == "camp":
		return CAMP_ICONS.get(String(ch.get("id", "")), "campfire")
	if ch.has("blessing"):
		return CHOICE_ICONS.get(String(ch.blessing), "star")
	if ch.has("ore"):
		return "3d:coins" if String(ch.ore) == "gold" else "anvil"
	match id:
		"duel":
			return "coin" if int(ch.get("bet", 0)) > 0 else "arrow_right"
		"merchant":
			return "rune_wild" if i == 0 else "arrow_right"
		"idol":
			return "heart" if i == 0 else "arrow_right"
		"outbreak":
			return "skull"
		"garden":
			return "3d:chest_gems"
	return "arrow_right"

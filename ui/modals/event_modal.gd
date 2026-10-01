class_name EventModal
extends UiModal
## Board event card (offer {kind:"event", id, title, text, choices}). Medallion art, flavour
## text and one card per choice (disabled choices greyed). Emits event_chosen(i).

signal event_chosen(index: int)

const ART := {
	"shrine": ["star", Color("ffd86a")], "duel": ["dice", UiPalette.DIE_BODY], "outbreak": ["skull", Color("efe6d4")],
	"garden": ["rune_lucky", Color("7ad35a")], "merchant": ["coin", UiPalette.COIN], "idol": ["curse", UiPalette.CURSE],
	"ore": ["ore", Color("c4bcd4")],
}
## Frame colour per event id (default violet); the Deep Mines ore vein is teal.
const RIM := {"ore": Color("3fb8aa")}
const CHOICE_ICONS := {
	"atk": "sword", "max_hp": "heart", "gold": "3d:coins", "face": "anvil",
}

var _art: CenterContainer
var _text: Label
var _choices: VBoxContainer


func _build() -> void:
	_art = CenterContainer.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_art)
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
	# a colour without a native plaque family (steel, silver...): the white plaque x colour
	if not ribbon.skinned():
		ribbon.family = "white"
	UiTheme.clear(_art)
	var art: Array = ART.get(id, ["star", UiPalette.GOLD])
	_art.add_child(OptionCard.Medallion.make(art_icon(id, String(art[0])), 128, art[1], rim))
	_text.text = String(o.get("text", ""))
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
			return "chest"
	return "arrow_right"


## The event's art id: the pack's event_<id> icon when the map has one (spec 4.3), else the
## per-event glyph from ART.
static func art_icon(id: String, fallback: String) -> String:
	return "event_" + id if Icons.is_mapped("event_" + id) else fallback

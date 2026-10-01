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
## The decline choice of every event (core label): always the same arrow.
const WALK_AWAY := "Walk away"
const CHOICE_ICONS := {
	"atk": "sword", "max_hp": "heart", "gold": "coin", "face": "anvil",
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
	_rest.add_theme_stylebox_override("panel", UiTheme.pad(UiTheme.chip_box("green"), 16, 4))
	var rr := UiTheme.hbox(8)
	rr.alignment = BoxContainer.ALIGNMENT_CENTER
	rr.add_child(Icons.rect("heart", 30))
	_rest_label = UiTheme.label("", 24, UiPalette.TEXT, true, 4)
	rr.add_child(_rest_label)
	_rest.add_child(rr)
	body.add_child(_rest)
	_text = UiTheme.para("", 26, UiPalette.TEXT, 500)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_text)
	body.add_child(UiModal.section_gap())
	_choices = UiTheme.vbox(12)
	body.add_child(_choices)


func refresh(flow: GameFlow) -> void:
	var o := flow.offer
	var id := String(o.get("id", ""))
	var rim: Color = RIM.get(id, Color("9a7ae0"))
	if id == "camp":
		dismissible = false
		set_title(String(o.get("title", "The Last Camp")).to_upper(), PLAQUE_DEFAULT) # forced: one gift, no close
	else:
		set_title(String(o.get("title", "Event")).to_upper(), PLAQUE_DEFAULT)
	UiTheme.clear(_art)
	var art: Array = ART.get(id, ["star", UiPalette.GOLD])
	_art.add_child(OptionCard.Medallion.make(art_icon(id, String(art[0])), 128, art[1], rim))
	_text.text = String(o.get("text", ""))
	_rest.visible = id == "camp"
	if id == "camp":
		_rest_label.text = "RESTED  +%d HP" % int(o.get("healed", 0))
	UiTheme.clear(_choices)
	var choices: Array = o.get("choices", [])
	for i in choices.size():
		var ch: Dictionary = choices[i]
		var c := OptionCard.make(String(ch.get("label", "")), String(ch.get("desc", "")))
		if ch.has("passive") and Passives.DEFS.has(String(ch.passive)):
			# a shrine passive reads like every other passive card: its icon + rarity tag
			c.set_passive(String(ch.passive))
		elif ch.has("kind"):
			c.set_die(String(ch.kind))
		else:
			c.set_icon(_choice_icon(id, ch, i))
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
		return "coin" if String(ch.ore) == "gold" else "anvil"
	if String(ch.get("label", "")) == WALK_AWAY:
		return "arrow_right"
	match id:
		"duel":
			return "coin"
		"merchant":
			return "rare_rune"
		"idol":
			return "heart"
		"outbreak":
			return "skull"
		"garden":
			return "chest"
	return "arrow_right"


## The event's art id: the pack's event_<id> icon when the map has one (spec 4.3), else the
## per-event glyph from ART.
static func art_icon(id: String, fallback: String) -> String:
	return "event_" + id if Icons.is_mapped("event_" + id) else fallback

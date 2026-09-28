class_name DraftModal
extends UiModal
## Level-up draft / rune reward: three option cards (rune colours + rarity frames), pick one,
## confirm. Emits draft_picked(i). Reads flow.offer {kind:"draft", options, source}.

signal draft_picked(index: int)

const ICONS := {"new_die": "dice", "max_hp": "heart", "combat_reroll": "reroll", "face_raise": "anvil"}
const TITLES := {"level": "LEVEL UP!", "elite": "ELITE SPOILS", "chest": "TREASURE!", "reward": "REWARD"}
const SUBS := {"level": "Choose one upgrade", "elite": "Choose a rune", "chest": "The chest holds a rune. Choose one",
	"reward": "Choose one"}

var _sub: Label
var _list: VBoxContainer
var _take: GameButton
var _cards: Array[OptionCard] = []
var _choice := -1


func _build() -> void:
	_sub = UiTheme.label("", 24, UiPalette.TEXT_DIM, false, 0, false, 600)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_sub)
	_list = UiTheme.vbox(14)
	body.add_child(_list)
	body.add_child(UiTheme.spacer(2))
	_take = GameButton.make("TAKE", "check", GameButton.Kind.PRIMARY, 38)
	_take.icon_tint = UiPalette.TEXT_DARK
	_take.pressed.connect(func() -> void:
		if _choice >= 0:
			draft_picked.emit(_choice))
	body.add_child(_take)


func refresh(flow: GameFlow) -> void:
	var offer := flow.offer
	var source := String(offer.get("source", "level"))
	set_title(TITLES.get(source, "REWARD"), UiPalette.XP if source == "level" else UiPalette.GOLD)
	_sub.text = SUBS.get(source, "Choose one")
	UiTheme.clear(_list)
	_cards.clear()
	var options: Array = offer.get("options", [])
	for i in options.size():
		var o: Dictionary = options[i]
		var id := String(o.get("id", ""))
		var c := OptionCard.make(String(o.get("label", id)), String(o.get("desc", "")))
		if id == "rune" and o.has("rune"):
			c.set_rune(String(o.rune))
		else:
			c.set_icon(ICONS.get(id, "star"))
			c.set_tag("BOON", UiPalette.GOLD)
		c.pressed.connect(select.bind(i))
		_list.add_child(c)
		_cards.append(c)
		if is_inside_tree() and visible:
			c.modulate.a = 0.0
			c.position.x += 40
			var t := create_tween()
			t.tween_interval(0.06 * i)
			t.tween_property(c, "modulate:a", 1.0, 0.18)
	_choice = -1
	_take.set_enabled(false)
	_take.text = "CHOOSE ONE"
	relayout()


func select(i: int) -> void:
	_choice = i
	for k in _cards.size():
		_cards[k].selected = k == i
	_take.set_enabled(true)
	_take.text = "TAKE"
	UiTheme.pop(_take, 1.06, 0.2)

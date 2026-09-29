class_name MinigameRewardModal
extends UiModal
## The minigame prize: the tier medal and 2-3 reward cards from the core's offer
## {kind:"reward", source:"minigame", id, tier, options}. Pick one, TAKE -> reward_picked(i)
## (GameFlow.pick_draft). Same card API as DraftModal (select, _cards, _take) so AUTO's
## highlight works on it.

signal reward_picked(index: int)

const ICONS := {"gold": "coin", "crown": "crown", "potion": "potion", "potion_gold": "potion", "face_raise": "anvil",
	"rune_choice": "star", "reroll_boost": "reroll", "passive_common": "trophy"}
const TAGS := {"gold": "GOLD", "crown": "META", "potion": "POTION", "potion_gold": "POTION", "face_raise": "FORGE",
	"rune_choice": "RUNE", "new_die": "DIE", "reroll_boost": "BOOST", "passive_common": "PASSIVE"}

var _medal: MgWidgets.Medal
var _sub: Label
var _list: VBoxContainer
var _take: GameButton
var _cards: Array[OptionCard] = []
var _choice := -1


func _build() -> void:
	var top := UiTheme.hbox(16)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(top)
	_medal = MgWidgets.Medal.new()
	_medal.custom_minimum_size = Vector2(96, 108)
	top.add_child(_medal)
	_sub = UiTheme.label("", 26, UiPalette.TEXT_DIM, false, 0, false, 600)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.custom_minimum_size.x = 300
	top.add_child(_sub)
	_list = UiTheme.vbox(14)
	body.add_child(_list)
	body.add_child(UiTheme.spacer(2))
	_take = GameButton.make("TAKE", "check", GameButton.Kind.PRIMARY, 38)
	_take.icon_tint = UiPalette.TEXT_DARK
	_take.pressed.connect(func() -> void:
		if _choice >= 0:
			reward_picked.emit(_choice))
	body.add_child(_take)


func refresh(flow: GameFlow) -> void:
	var offer := flow.offer
	var tier := String(offer.get("tier", "silver"))
	var col: Color = MgLogic.TIER_COLORS.get(tier, UiPalette.GOLD)
	set_title("%s PRIZE" % tier.to_upper(), col.darkened(0.1) if tier != "silver" else Color("8e9bb8"))
	_medal.tier = tier
	_sub.text = "%s\nChoose one reward" % MinigameDefs.name_of(String(offer.get("id", "")))
	UiTheme.clear(_list)
	_cards.clear()
	var options: Array = offer.get("options", [])
	for i in options.size():
		var o: Dictionary = options[i]
		var id := String(o.get("id", ""))
		var c := OptionCard.make(String(o.get("label", id)), String(o.get("desc", "")))
		if id == "new_die":
			c.set_die(String(o.get("kind", "standard")))
		else:
			c.set_icon(ICONS.get(id, "star"))
			c.set_tag(TAGS.get(id, "PRIZE"), col)
		c.premium = tier == "gold"
		c.pressed.connect(select.bind(i))
		_list.add_child(c)
		_cards.append(c)
		if is_inside_tree() and visible:
			c.modulate.a = 0.0
			var t := create_tween()
			t.tween_interval(0.07 * i)
			t.tween_property(c, "modulate:a", 1.0, 0.2)
	_choice = -1
	_take.set_enabled(false)
	relayout()


func select(i: int) -> void:
	_choice = i
	for k in _cards.size():
		_cards[k].selected = k == i
	_take.set_enabled(true)
	UiTheme.pop(_take, 1.06, 0.2)

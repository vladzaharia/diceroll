class_name PassiveModal
extends UiModal
## Passive reward: offer {kind:"passive", options:[{id, label, desc, rarity, icon}], source}
## (source elite | miniboss; boss-tier rolls come from the mini-boss and rare elite drops).
## Three passive cards; boss-tier cards get the premium gold frame and the whole modal a
## warm glow. Pick one and TAKE. Emits passive_picked(i) (GameFlow.pick_draft).

signal passive_picked(index: int)

const TITLES := {"elite": "ELITE SPOILS", "miniboss": "MINI-BOSS TROPHY", "boss": "BOSS TROPHY"}

var _sub: Label
var _list: VBoxContainer
var _take: GameButton
var _cards: Array[OptionCard] = []
var _choice := -1
var _glow: TextureRect


func _build() -> void:
	_glow = TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.62, 0.18, 0.32), Color(1.0, 0.62, 0.18, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	_glow.texture = gt
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.visible = false
	add_child(UiTheme.full_rect(_glow))
	move_child(_glow, 1)
	_sub = UiTheme.label("", 24, UiPalette.TEXT_DIM, false, 0, false, 600)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_sub)
	_list = UiTheme.vbox(14)
	body.add_child(_list)
	body.add_child(UiTheme.spacer(2))
	_take = GameButton.make("TAKE", "check", GameButton.Kind.PRIMARY, 38)
	_take.icon_tint = UiPalette.TEXT_DARK
	_take.pressed.connect(func() -> void:
		if _choice >= 0:
			passive_picked.emit(_choice))
	body.add_child(_take)


func refresh(flow: GameFlow) -> void:
	var offer := flow.offer
	var source := String(offer.get("source", "elite"))
	var options: Array = offer.get("options", [])
	var boss_tier := false
	for o: Dictionary in options:
		if String(o.get("rarity", "")) == "boss":
			boss_tier = true
	set_title(TITLES.get(source, "PASSIVE"), UiPalette.BOSS if boss_tier else UiPalette.UNCOMMON.darkened(0.1))
	_sub.text = "Choose a boss-tier passive. It lasts the whole run." if boss_tier else "Choose a passive. It lasts the whole run."
	_glow.visible = boss_tier
	UiTheme.clear(_list)
	_cards.clear()
	for i in options.size():
		var o: Dictionary = options[i]
		var id := String(o.get("id", ""))
		var c := OptionCard.make(String(o.get("label", id)), String(o.get("desc", "")))
		c.set_passive(id)
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

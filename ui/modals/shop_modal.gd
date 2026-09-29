class_name ShopModal
extends UiModal
## Shop (offer {kind:"shop", items}). Gold header, item cards with prices, restock, leave.
## Items with needs_die open an inline die picker before buying.
## Emits shop_buy(i, die_idx), shop_reroll_pressed, shop_leave_pressed.

signal shop_buy(index: int, die_idx: int)
signal shop_reroll_pressed
signal shop_leave_pressed

const ICONS := {"die": "dice", "potion": "3d:potion_red", "face_raise": "anvil", "combat_reroll": "reroll"}

var gold: Counter
var _restock: GameButton
var _list: VBoxContainer
var _picker: VBoxContainer
var _pick_title: Label
var _pick_grid: GridContainer
var _buy: GameButton
var _leave: GameButton
var _cards: Array[OptionCard] = []
var _chips: Array[DieChip] = []
var _flow: GameFlow
var _sel := -1
var _die := -1


func _build() -> void:
	set_title("SHOP")
	var head := UiTheme.hbox(12)
	body.add_child(head)
	gold = Counter.make("3d:coins", 0, 34, UiPalette.TEXT, "pill")
	head.add_child(gold)
	head.add_child(UiTheme.spacer(0, true))
	_restock = GameButton.make("RESTOCK", "reroll", GameButton.Kind.SECONDARY, 26)
	_restock.icon_tint = UiPalette.GOLD_BRIGHT
	_restock.min_height = 80
	_restock.pad_x = 20
	_restock.pressed.connect(func() -> void: shop_reroll_pressed.emit())
	head.add_child(_restock)
	_list = UiTheme.vbox(12)
	body.add_child(_list)
	_picker = UiTheme.vbox(10)
	_picker.visible = false
	body.add_child(_picker)
	_pick_title = UiModal.section_label("Choose a die")
	_picker.add_child(_pick_title)
	_pick_grid = GridContainer.new()
	_pick_grid.columns = 3
	_pick_grid.add_theme_constant_override("h_separation", 12)
	_pick_grid.add_theme_constant_override("v_separation", 12)
	_pick_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_picker.add_child(_pick_grid)
	var foot := UiTheme.hbox(14)
	body.add_child(foot)
	_leave = GameButton.make("LEAVE", "arrow_right", GameButton.Kind.SECONDARY, 32)
	_leave.icon_tint = UiPalette.TEXT
	_leave.pressed.connect(func() -> void: shop_leave_pressed.emit())
	foot.add_child(_leave)
	_buy = GameButton.make("BUY", "coin", GameButton.Kind.PRIMARY, 34)
	_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy.sfx_id = "coin"
	_buy.pressed.connect(_on_buy)
	foot.add_child(_buy)


func refresh(flow: GameFlow) -> void:
	_flow = flow
	var run := flow.run
	gold.set_value(run.gold, visible)
	_restock.sub_text = "%d gold" % Balance.SHOP_RESTOCK_PRICE
	_restock.set_enabled(run.gold >= Balance.SHOP_RESTOCK_PRICE)
	UiTheme.clear(_list)
	_cards.clear()
	var items: Array = flow.offer.get("items", [])
	for i in items.size():
		var it: Dictionary = items[i]
		var id := String(it.id)
		var c := OptionCard.make(String(it.label), String(it.desc))
		if id == "rune" and it.has("rune"):
			c.set_rune(String(it.rune))
		elif id == "die":
			c.set_die(String(it.get("kind", "standard")))
		elif id == "passive" and it.has("passive"):
			c.set_passive(String(it.passive))
		else:

			c.set_icon(ICONS.get(id, "star"))
			c.set_tag("", UiPalette.GOLD)
		c.set_price(int(it.price), run.gold >= int(it.price))
		if bool(it.sold):
			c.set_sold(true)
		c.pressed.connect(select.bind(i))
		_list.add_child(c)
		_cards.append(c)
	_sel = -1
	_die = -1
	_picker.visible = false
	_update_buy()
	relayout()


func on_event(ev: Dictionary) -> void:
	if String(ev.get("type", "")) == "gold_changed":
		gold.set_value(int(ev.total), true)


func select(i: int) -> void:
	_sel = i
	_die = -1
	for k in _cards.size():
		_cards[k].selected = k == i
	var it: Dictionary = _flow.offer.items[i]
	if bool(it.needs_die):
		begin_pick(i)
	else:
		_picker.visible = false
	_update_buy()
	relayout()


## Opens the die picker for item i (also used by the ui_shop_pick scenario).
func begin_pick(i: int) -> void:
	if _sel != i:
		_sel = i
		for k in _cards.size():
			_cards[k].selected = k == i
	var it: Dictionary = _flow.offer.items[i]
	_pick_title.text = ("Which die gets the rune?" if String(it.id) == "rune" else "Raise the lowest face of which die?").to_upper()
	UiTheme.clear(_pick_grid)
	_chips.clear()
	for d in _flow.run.dice.size():
		var die: Die = _flow.run.dice[d]
		var chip := DieChip.make(die, d)
		if String(it.id) == "face_raise":
			chip.faces[die.lowest_face()].selected = true
			if not die.can_raise(die.lowest_face()):

				chip.disabled = true
				chip.modulate.a = 0.45
		chip.pressed.connect(_pick_die.bind(d))
		_pick_grid.add_child(chip)
		_chips.append(chip)
	_picker.visible = true
	_update_buy()
	relayout()


func _pick_die(d: int) -> void:
	_die = d
	for k in _chips.size():
		_chips[k].selected = k == d
	_update_buy()


func _update_buy() -> void:
	if _flow == null:
		return
	if _sel < 0:
		_buy.text = "PICK AN ITEM"
		_buy.set_enabled(false)
		return
	var it: Dictionary = _flow.offer.items[_sel]
	var price := int(it.price)
	var ok := not bool(it.sold) and _flow.run.gold >= price
	if bool(it.needs_die) and _die < 0:
		_buy.text = "CHOOSE A DIE"
		_buy.set_enabled(false)
		return
	_buy.text = "BUY  %d" % price if ok else ("SOLD" if bool(it.sold) else "NEED %d" % price)
	_buy.set_enabled(ok)


func _on_buy() -> void:
	if _sel < 0:
		return
	shop_buy.emit(_sel, _die)

extends "res://tests/test_case.gd"
## Camp stations pass (docs/design/2026-10-01-camp-stations.md): the Carousel widget (paging,
## keys, swipe, remembered pages) and the shared StationCard (every card of a station is the
## same height, whatever it holds).


func _tiles(n: int) -> Array:
	var out: Array = []
	for i in n:
		var c := Control.new()
		c.name = "T%d" % i
		c.mouse_filter = Control.MOUSE_FILTER_PASS
		out.append(c)
	return out


func _shown(c: Carousel) -> Array:
	var out: Array = []
	for i in c.items.size():
		if c.items[i].visible:
			out.append(i)
	return out


## A strip exactly `n` tiles wide.
func _w(n: int, tile_w := 104.0) -> float:
	return n * tile_w + (n - 1) * Carousel.GAP


func test_carousel_paging() -> void:
	Carousel.reset_memory()
	var c := Carousel.make(_tiles(25), 132.0, 104.0)
	c.layout_for_width(_w(4) + 20.0)
	assert_eq(c.per_page, 4, "4 tiles fit")
	assert_eq(c.page_count(), 7, "25 items, 4 a page")
	assert_eq(_shown(c), [0, 1, 2, 3], "first page")
	c.next_page()
	assert_eq(c.page, 1)
	assert_eq(_shown(c), [4, 5, 6, 7], "second page")
	for i in 10:
		c.next_page()
	assert_eq(c.page, 6, "clamped at the last page")
	assert_eq(_shown(c), [24], "the last page holds the 25th item")
	c.prev_page()
	assert_eq(c.page, 5)
	c.set_page(-3, false)
	assert_eq(c.page, 0, "clamped at the first page")
	# a wider strip keeps the first visible item on screen
	c.set_page(3, false)
	c.layout_for_width(_w(6))
	assert_eq(c.per_page, 6)
	assert_eq(c.page, 2, "item 12 was first; page 2 of 6 a page shows it")
	assert_true(_shown(c).has(12))
	c.free()


func test_carousel_one_page_has_no_arrows() -> void:
	Carousel.reset_memory()
	var c := Carousel.make(_tiles(3), 132.0, 104.0)
	c.layout_for_width(_w(5))
	assert_eq(c.page_count(), 1)
	assert_true(not c._prev.visible and not c._next.visible, "one page: no arrows")
	c.next_page()
	assert_eq(c.page, 0, "nothing to page to")
	var many := Carousel.make(_tiles(9), 132.0, 104.0)
	many.layout_for_width(_w(4))
	assert_true(many._prev.visible and many._next.visible, "several pages: arrows")
	assert_true(many._prev.disabled and not many._next.disabled, "first page: only next works")
	assert_true(many._dots.visible and many._dots.count == 3, "three pages: three dots")
	var lots := Carousel.make(_tiles(40), 132.0, 104.0)
	lots.layout_for_width(_w(4))
	assert_true(not lots._dots.visible and lots._pager.text == "1/10", "ten pages: N/M instead of dots")
	c.free()
	many.free()
	lots.free()


func _key(code: Key) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = true
	return k


func test_carousel_keys() -> void:
	Carousel.reset_memory()
	var c := Carousel.make(_tiles(12), 132.0, 104.0)
	c.layout_for_width(_w(4))
	assert_true(c.handle_key(_key(KEY_RIGHT)), "right is used")
	assert_eq(c.page, 1, "right: next page")
	c.handle_key(_key(KEY_RIGHT))
	c.handle_key(_key(KEY_RIGHT))
	assert_eq(c.page, 2, "clamped")
	assert_true(c.handle_key(_key(KEY_LEFT)), "left is used")
	assert_eq(c.page, 1, "left: previous page")
	assert_true(not c.handle_key(_key(KEY_A)), "other keys pass through")
	var up := _key(KEY_RIGHT)
	up.pressed = false
	assert_true(not c.handle_key(up), "a key release does nothing")
	assert_eq(c.page, 1)
	# keys go to the carousel used last
	var d := Carousel.make(_tiles(12), 132.0, 104.0)
	d.layout_for_width(_w(4))
	d.next_page()
	assert_true(d.has_key_focus() and not c.has_key_focus(), "the last one used has the keys")
	c.free()
	d.free()


func _mouse(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	e.global_position = at
	return e


func _move(at: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	return e


func _drag(c: Carousel, from: Vector2, to: Vector2) -> void:
	c._gui_input(_mouse(from, true))
	for i in range(1, 5):
		c._gui_input(_move(from.lerp(to, i / 4.0)))
	c._gui_input(_mouse(to, false))


func test_carousel_swipe() -> void:
	Carousel.reset_memory()
	var c := Carousel.make(_tiles(12), 132.0, 104.0)
	c.layout_for_width(_w(4))
	_drag(c, Vector2(300, 60), Vector2(180, 64))
	assert_eq(c.page, 1, "swipe left: next page")
	_drag(c, Vector2(180, 60), Vector2(320, 58))
	assert_eq(c.page, 0, "swipe right: previous page")
	_drag(c, Vector2(300, 60), Vector2(270, 60))
	assert_eq(c.page, 0, "a short drag snaps back")
	_drag(c, Vector2(300, 60), Vector2(280, 260))
	assert_eq(c.page, 0, "a vertical drag scrolls the screen, it doesn't page")
	assert_true(not c.is_swiping(), "the gesture ended")
	# a tap on a tile is still a tap
	var tile := Carousel.ItemTile.make(null, "Blade Rune", "COMMON")
	var hits := [0]
	tile.pressed.connect(func() -> void: hits[0] += 1)
	var e := Carousel.make([tile], 132.0, 104.0)
	tile.size = Vector2(104, 132)
	tile._gui_input(_mouse(Vector2(10, 10), true))
	tile._gui_input(_mouse(Vector2(12, 11), false))
	assert_eq(hits[0], 1, "a tap on a tile presses it")
	tile._gui_input(_mouse(Vector2(10, 10), true))
	tile._gui_input(_mouse(Vector2(90, 11), false))
	assert_eq(hits[0], 1, "a drag across a tile doesn't")
	c.free()
	e.free()


func test_carousel_remembers_its_page() -> void:
	Carousel.reset_memory()
	var c := Carousel.make(_tiles(20), 132.0, 104.0, "test:pack")
	c.layout_for_width(_w(4))
	for i in 3:
		c.next_page()
	c.free()
	# the screen rebuilt (a purchase, a toggle): the same carousel comes back on its page
	var again := Carousel.make(_tiles(20), 132.0, 104.0, "test:pack")
	again.layout_for_width(_w(4))
	assert_eq(again.page, 3, "page kept across rebuilds")
	assert_true(again.has_key_focus(), "and the keyboard focus")
	again.free()
	Carousel.reset_memory()


func _cards(root: Node, prefix: String) -> Array:
	var out: Array = []
	for n in root.find_children(prefix + "*", "StationCard", true, false):
		out.append(n)
	return out


func test_workshop_pack_cards_are_one_height() -> void:
	Carousel.reset_memory()
	for preset in ["mid", "max"]:
		var p := Profile.from_dict(MetaPresets.get_preset(preset))
		var m := WorkshopModal.new()
		# in the tree, so the cards' theme (tile margins, separations) applies to their sizes
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			tree.root.add_child(m)
		m.profile = p
		m.rebuild(p)
		var packs := _cards(m.body, "Pack_")
		assert_eq(packs.size(), UnlockDefs.PACK_IDS.size(), "a card per pack")
		var h := -1.0
		for c in packs:
			var card := c as StationCard
			var ch := card.get_combined_minimum_size().y
			if h < 0.0:
				h = ch
			assert_near(ch, h, 0.5, "%s: %s is %.0f, Starter is %.0f" % [preset, card.name, ch, h])
			for r in card.row_heights():
				assert_near(float(r[0]), float(r[1]), 0.5, "%s: %s row %s stays in its budget" % [preset, card.name, r[2]])
		# the 25-item Starter pack pages its items instead of growing
		var starter := m.body.find_child("Pack_starter", true, false) as StationCard
		var car := starter.find_children("*", "Carousel", true, false)[0] as Carousel
		assert_eq(car.items.size(), 25, "Starter: 25 item tiles")
		var pools := _cards(m.body, "Pool_")
		assert_eq(pools.size(), 3, "three pool cards")
		for c in pools:
			assert_near((c as StationCard).get_combined_minimum_size().y, (pools[0] as StationCard).get_combined_minimum_size().y, 0.5,
				"pool cards share a height")
		if m.get_parent():
			m.get_parent().remove_child(m)
		m.free()


func test_workshop_unlock_and_toggle_commands() -> void:
	Carousel.reset_memory()
	var p := Profile.from_dict(MetaPresets.get_preset("mid"))
	p.sigils = 50
	var sent: Array = []
	var m := WorkshopModal.new()
	m.camp_command.connect(func(c: Array) -> void: sent.append(c))
	m.profile = p
	m.rebuild(p)
	var locked := ""
	for id in UnlockDefs.PACK_IDS:
		if not p.owns("packs", String(id)):
			locked = String(id)
			break
	assert_true(locked != "", "the mid profile has a locked pack")
	var card := m.body.find_child("Pack_" + locked, true, false) as StationCard
	var b := card.find_child("Unlock", true, false) as GameButton
	assert_true(b != null and b.text.begins_with("UNLOCK"), "a locked pack's one action is UNLOCK")
	b.pressed.emit()
	assert_eq(sent.back(), ["unlock", "packs", locked])
	var tog := m.body.find_child("Toggle_blade", true, false) as Carousel.ItemTile
	assert_true(tog != null, "a pool toggle tile for Blade")
	tog.pressed.emit()
	assert_eq(sent.back(), ["toggle_pool", "runes", "blade", false], "tap switches it off")
	m.free()


func test_drop_info_reads_every_item() -> void:
	for id in UnlockDefs.PACK_IDS:
		var d: Dictionary = UnlockDefs.PACKS[id]
		assert_true(String(CampInfo.PACK_BLURB.get(id, "")) != "", "a blurb for %s" % id)
		for pool in ["runes", "kinds", "passives"]:
			for item in d[pool]:
				var info := WorkshopModal.drop_info(String(pool), String(item))
				assert_true(String(info.desc) != "" and String(info.name) != "" and String(info.detail) != "",
					"%s/%s: name, rule and detail" % [pool, item])

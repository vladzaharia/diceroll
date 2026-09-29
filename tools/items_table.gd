extends SceneTree
## Prints the Armory item tables (ItemDefs) as markdown: every item with its rule text at tiers
## I / II / III (Standard variant), and every variant's secondary. For docs/plans/balance.md.
## Usage: godot --headless --path . -s tools/items_table.gd

func _init() -> void:
	for slot in ["weapon", "offhand", "head", "body", "trinket"]:
		print("")
		print("| %s | rule | I | II | III | Standard |" % slot)
		print("|---|---|---|---|---|---|")
		for id in ItemDefs.of_slot(slot):
			var eff: Dictionary = ItemDefs.def(String(id)).effect
			var nums := []
			for t in [1, 2, 3]:
				var parts := []
				for key in (eff.n as Dictionary):
					parts.append("%s %s" % [key, ItemDefs._fmt(ItemDefs.num(String(id), String(key), t, ""))])
				nums.append(", ".join(parts))
			print("| %s | %s: %s | %s | %s | %s | %s |" % [ItemDefs.name_of(String(id)), String(eff.name), ItemDefs.rule_text(String(id), 3, ""),
				nums[0], nums[1], nums[2], ItemDefs.std_text(String(id)).trim_prefix("Standard: ")])
	print("")
	print("| variant | base | secondary | unlock | craft |")
	print("|---|---|---|---|---|")
	for v in ItemDefs.VARIANTS:
		var vd: Dictionary = ItemDefs.VARIANTS[v]
		var cost := ItemDefs.craft_cost(String(v))
		print("| %s (`%s`) | %s | %s: %s | %s | %d Crowns / %d Sigils |" % [String(vd.name), v, ItemDefs.name_of(String(vd.item)),
			String(vd.sec_name), String(vd.desc), ItemDefs.unlock_text(String(v)), int(cost.get("crowns", 0)), ItemDefs.CRAFT_SIGILS])
	quit()

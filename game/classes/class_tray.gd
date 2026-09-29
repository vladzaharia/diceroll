class_name ClassTray
extends RefCounted
## Pure helpers for what the dice tray shows with the class mechanics (no scene access):
## the combat pool with temporary Bone dice, and board rolls where a ★ face shows the star.


## The dice the tray shows: the combat pool (with temporary Bone dice) during a fight.
static func pool(flow: GameFlow) -> Array:
	if flow == null:
		return []
	if flow.combat != null and flow.phase == GameFlow.Phase.COMBAT:
		return flow.combat.pool_dice(flow.run)
	return flow.run.dice


## Board roll values as the tray should land them: a ★ face shows the star, not its copy.
static func board_values(ev: Dictionary, values: Array[int]) -> Array[int]:
	var stars: Array = ev.get("pretend", [])
	if stars.is_empty():
		return values
	var idx: Array = ev.get("indices", [])
	var out := values.duplicate()
	for i in stars:
		var j := int(i)
		if values.size() == idx.size() and idx.has(j):
			j = idx.find(j)
		if j >= 0 and j < out.size():
			out[j] = Die.PRETEND
	return out

class_name MinigameUi
extends RefCounted
## Wires the minigame screen and its reward modal into UiRoot (kept here so UiRoot only
## needs two calls):
##
##   MinigameUi.attach(ui)              creates ui.minigame + ui.minigame_reward, connects them
##                                      to ui.command (minigame_action / _finish,
##                                      pick_draft; there is no AUTO in minigames)
##   want = MinigameUi.sync(ui, flow)   in UiRoot.sync: shows/refreshes/closes the screen for
##                                      phase MINIGAME; returns the reward modal for a
##                                      minigame reward offer (else null)


static func attach(ui: UiRoot) -> void:
	var scr := MinigameScreen.new()
	var rew := MinigameRewardModal.new()
	ui.minigame = scr
	ui.minigame_reward = rew
	# under the AUTO layer (the AUTO toggle and speed pill stay usable) and above the modals
	ui.add_child(scr)
	ui.add_child(rew)
	var at := ui.auto_hud.get_index()
	ui.move_child(scr, at)
	ui.move_child(rew, at + 1)
	scr.action.connect(func(args: Array) -> void: ui.command.emit("minigame_action", [args]))
	scr.finish_requested.connect(func() -> void: ui.command.emit("minigame_finish", []))
	rew.reward_picked.connect(func(i: int) -> void: ui.command.emit("pick_draft", [i]))


static func is_reward(flow: GameFlow) -> bool:
	return flow.phase == GameFlow.Phase.DRAFT and String(flow.offer.get("kind", "")) == "reward"


static func sync(ui: UiRoot, flow: GameFlow) -> UiModal:
	var scr := ui.minigame
	if flow.phase == GameFlow.Phase.MINIGAME and String(flow.offer.get("kind", "")) == "minigame":
		if not scr.is_open():
			scr.show_now(flow)
		scr.refresh(flow)
	elif scr.is_open() and not scr.in_result():
		scr.close()
	return ui.minigame_reward if is_reward(flow) else null

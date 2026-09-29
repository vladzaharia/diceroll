extends Node
## Entry point: boots the GameController on the title screen.
## Title -> Camp (profile hub) -> run setup -> run (GameController) -> results (banked into
## user://profile.json) -> Camp.
## "Continue" on the title loads user://save.json (auto-saved by the controller at every
## idle point outside combat).

var controller: GameController


func _ready() -> void:
	# Source checkouts without the git-ignored third-party assets get a plain explanation
	# screen instead of a broken game (see game/boot/asset_check.gd).
	if not AssetCheck.run().is_empty():
		add_child(AssetCheck.screen())
		return
	controller = GameController.new()
	add_child(controller)
	controller.show_title()


func _notification(what: int) -> void:
	# Phones: backgrounding the app opens the pause menu.
	if what == NOTIFICATION_APPLICATION_PAUSED and controller:
		controller.pause()

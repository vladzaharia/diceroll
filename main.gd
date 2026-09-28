extends Node
## Entry point: boots the GameController on the title screen.
## Title -> Class Select -> run (GameController) -> Victory/Defeat summary -> Title.
## "Continue" on the title loads user://save.json (auto-saved by the controller at every
## idle point outside combat).

var controller: GameController


func _ready() -> void:
	controller = GameController.new()
	add_child(controller)
	controller.show_title()


func _notification(what: int) -> void:
	# Phones: backgrounding the app opens the pause menu.
	if what == NOTIFICATION_APPLICATION_PAUSED and controller:
		controller.pause()

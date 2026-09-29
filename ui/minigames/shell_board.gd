class_name ShellBoard
extends MgBoard
## shell_game board (placeholder: to be replaced by the real screen). Draws the public state as text.


func _draw_board() -> void:
	text_c(size * 0.5, "SHELL GAME", 32, Color.WHITE, 6)

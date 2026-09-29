class_name LadderBoard
extends MgBoard
## high_low board (placeholder: to be replaced by the real screen). Draws the public state as text.


func _draw_board() -> void:
	text_c(size * 0.5, "HIGH LOW", 32, Color.WHITE, 6)

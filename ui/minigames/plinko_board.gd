class_name PlinkoBoard
extends MgBoard
## plinko board (placeholder: to be replaced by the real screen). Draws the public state as text.


func _draw_board() -> void:
	text_c(size * 0.5, "PLINKO", 32, Color.WHITE, 6)

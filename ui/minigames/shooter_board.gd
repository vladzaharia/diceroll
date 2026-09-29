class_name ShooterBoard
extends MgBoard
## bubble_shooter board (placeholder: to be replaced by the real screen). Draws the public state as text.


func _draw_board() -> void:
	text_c(size * 0.5, "BUBBLE SHOOTER", 32, Color.WHITE, 6)

class_name WheelBoard
extends MgBoard
## lucky_wheel board (placeholder: to be replaced by the real screen). Draws the public state as text.


func _draw_board() -> void:
	text_c(size * 0.5, "LUCKY WHEEL", 32, Color.WHITE, 6)

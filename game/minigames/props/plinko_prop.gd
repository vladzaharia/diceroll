class_name PlinkoProp
extends RefCounted
## Board-tile prop for plinko (placeholder: to be replaced by the game's own prop). Built into
## `n` in the minigame tile style (fit ~1.4 x 1.4, y = tile top); MinigameProps adds the sparkle.


static func build(n: Node3D) -> void:
	MinigameProps._bubbles(n)

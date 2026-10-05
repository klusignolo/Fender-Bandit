class_name UI
extends CanvasLayer
## The flow screens' layer (#35, #36): it shows one screen at a time (Title, Controls, Pause, Results,
## Initials, Scores) over the board, the HUD and the Tally card, and keeps processing while the tree is paused.

var screen: Node  # the one showing, or null


func _init() -> void:
	layer = 3  # over the HUD strip and the Tally card
	process_mode = Node.PROCESS_MODE_ALWAYS


## Show `s` in place of the screen showing now.
func show_screen(s: Node) -> void:
	clear()
	screen = s
	add_child(s)


func clear() -> void:
	if screen != null:
		screen.queue_free()
		screen = null

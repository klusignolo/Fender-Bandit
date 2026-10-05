class_name GridlockBanner
extends Card
## A plain GRIDLOCK banner over the frozen board, while input is locked before the results (#35). The death
## beat (#43) replaces it.


func _draw() -> void:
	dim()
	var view := get_viewport_rect().size
	text("GRIDLOCK!", Vector2(view.x / 2.0, view.y / 2.0 + 30), 96)

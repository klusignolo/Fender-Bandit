class_name LightPole
extends Node2D
## Draws one Light: its pole head, and its stop line glowing the Light's colour so every Light reads at
## the furthest zoom (#19 story 24). Greybox shapes; the art pass (#40) replaces them.

# signal_red, signal_green and signal_yellow from the palette in docs/sprites.md.
const COLORS := {
	Light.State.RED: Color("#E8322B"),
	Light.State.GREEN: Color("#2ECC40"),
	Light.State.YELLOW: Color("#F5C518"),
}
const HOUSING := Color(0.1, 0.1, 0.1)

var light: Light
var _shown := -1


func _init(l: Light) -> void:
	light = l
	position = l.pole


func _process(_delta: float) -> void:
	if light.state != _shown:
		_shown = light.state
		queue_redraw()


func _draw() -> void:
	var col: Color = COLORS[light.state]
	var across := Vector2(-light.direction.y, light.direction.x) * (Tuning.LW / 2.0 - 1.0)
	var mid := light.stop_point - light.pole
	var glow := col
	glow.a = 0.35
	draw_line(mid + across, mid - across, glow, 12.0)
	draw_line(mid + across, mid - across, col, 4.0)
	draw_circle(Vector2.ZERO, 9.0, HOUSING)
	draw_circle(Vector2.ZERO, 7.5, col)

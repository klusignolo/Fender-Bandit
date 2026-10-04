class_name LightPole
extends Node2D
## Draws one Light: its pole sprite (#39) standing at the kerb with the lamp for its state lit, and, on the decal layer,
## its stop line glowing the Light's colour so every Light reads at the furthest zoom (#19 story 24).

# signal_red, signal_green and signal_yellow from the palette in docs/sprites.md.
const COLORS := {
	Light.State.RED: Color("#E8322B"),
	Light.State.GREEN: Color("#2ECC40"),
	Light.State.YELLOW: Color("#F5C518"),
}
const LAMP := {Light.State.RED: 0, Light.State.YELLOW: 1, Light.State.GREEN: 2}  # index into Art.POLE_LAMPS
const GLOW_R := 6.0  # world px: the lit lamp's halo

var light: Light
var _shown := -1
var _line := Node2D.new()  # the stop line, under the vehicles


func _init(l: Light) -> void:
	light = l
	position = l.pole
	var pole := Art.sprite(Art.LIGHT_POLE)
	pole.offset = Art.LIGHT_POLE.get_size() / 2.0 - Art.POLE_BASE  # its base on the pole point
	pole.show_behind_parent = true  # under the lit lamp
	add_child(pole)
	_line.z_as_relative = false
	_line.z_index = Art.Z_DECAL
	_line.draw.connect(_draw_line)
	add_child(_line)


func _process(_delta: float) -> void:
	if light.state != _shown:
		_shown = light.state
		queue_redraw()
		_line.queue_redraw()


func _draw() -> void:
	var col: Color = COLORS[light.state]
	var lamp := Vector2(0.0, Art.POLE_LAMPS[LAMP[light.state]] - Art.POLE_BASE.y) * Art.SCALE
	draw_circle(lamp, GLOW_R, Color(col, 0.35))
	draw_circle(lamp, Art.POLE_LAMP_R * Art.SCALE, col)


func _draw_line() -> void:
	var col: Color = COLORS[light.state]
	var across := Vector2(-light.direction.y, light.direction.x) * (Tuning.LW / 2.0 - 1.0)
	var mid := light.stop_point - light.pole
	_line.draw_line(mid + across, mid - across, Color(col, 0.35), 12.0)
	_line.draw_line(mid + across, mid - across, col, 4.0)

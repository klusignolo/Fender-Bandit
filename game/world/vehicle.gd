class_name Vehicle
extends Node2D
## Draws one Car (greybox: a tinted box with a windscreen). Pooled by World; hidden while unused.

const GLASS := Color(0.15, 0.2, 0.3)

var car: Car
var _boosted := false


func show_car(c: Car) -> void:
	car = c
	visible = c != null
	if c != null:
		_sync()
		queue_redraw()


func _process(_delta: float) -> void:
	if car != null:
		_sync()


func _sync() -> void:
	transform = car.transform
	if car.boosted != _boosted:
		_boosted = car.boosted
		queue_redraw()


func _draw() -> void:
	if car == null:
		return
	var l := car.length
	var w := car.width
	draw_rect(Rect2(-l / 2.0, -w / 2.0, l, w), car.tint)
	draw_rect(Rect2(l / 2.0 - 12.0, -w / 2.0 + 3.0, 6.0, w - 6.0), GLASS)
	if car.boosted:  # speed lines behind a car waved through on green
		draw_line(Vector2(-l / 2.0 - 8.0, -5.0), Vector2(-l / 2.0 - 2.0, -5.0), Color.WHITE, 2.0)
		draw_line(Vector2(-l / 2.0 - 10.0, 5.0), Vector2(-l / 2.0 - 2.0, 5.0), Color.WHITE, 2.0)

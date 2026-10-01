class_name Vehicle
extends Node2D
## Draws one Car (greybox: a tinted box with a windscreen; Wreckage darkened, skewed and crossed out).
## Pooled by World; hidden while unused.

const GLASS := Color(0.15, 0.2, 0.3)
const WRECKAGE_DARKEN := 0.55
const WRECKAGE_SPIN := 0.6  # radians: Wreckage is drawn turned up to this far, so it reads as knocked askew

var car: Car
var _boosted := false
var _wreckage := false
var _spin := 0.0


func show_car(c: Car) -> void:
	car = c
	visible = c != null
	if c != null:
		_wreckage = c.wreckage
		_spin = 0.0
		_sync()
		queue_redraw()


func _process(_delta: float) -> void:
	if car != null:
		_sync()


func _sync() -> void:
	if car.wreckage and not _wreckage:
		# Same car, same skew, every run: the view stays repeatable from the seed.
		_spin = (float(hash(car.id) % 2001) / 1000.0 - 1.0) * WRECKAGE_SPIN
	transform = car.transform.rotated_local(_spin)
	if car.boosted != _boosted or car.wreckage != _wreckage:
		_boosted = car.boosted
		_wreckage = car.wreckage
		queue_redraw()


func _draw() -> void:
	if car == null:
		return
	var l := car.length
	var w := car.width
	var body := car.tint.darkened(WRECKAGE_DARKEN) if car.wreckage else car.tint
	draw_rect(Rect2(-l / 2.0, -w / 2.0, l, w), body)
	draw_rect(Rect2(l / 2.0 - 12.0, -w / 2.0 + 3.0, 6.0, w - 6.0), GLASS)
	if car.wreckage:
		draw_line(Vector2(-10, -7), Vector2(10, 7), Color.BLACK, 3.0)
		draw_line(Vector2(-10, 7), Vector2(10, -7), Color.BLACK, 3.0)
	elif car.boosted:  # speed lines behind a car waved through on green
		draw_line(Vector2(-l / 2.0 - 8.0, -5.0), Vector2(-l / 2.0 - 2.0, -5.0), Color.WHITE, 2.0)
		draw_line(Vector2(-l / 2.0 - 10.0, 5.0), Vector2(-l / 2.0 - 2.0, 5.0), Color.WHITE, 2.0)

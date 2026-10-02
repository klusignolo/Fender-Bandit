class_name Vehicle
extends Node2D
## Draws one Car (greybox: a tinted box with a windscreen; Wreckage darkened, skewed and crossed out).
## A right-turning car flashes its right blinker; a Turner carries an upright arrow that pulses amber
## while it holds. Pooled by World; hidden while unused.

const GLASS := Color(0.15, 0.2, 0.3)
const WRECKAGE_DARKEN := 0.55
const WRECKAGE_SPIN := 0.6  # radians: Wreckage is drawn turned up to this far, so it reads as knocked askew
const BLINKER := Color("#FFE3A3")  # `blinker` in docs/sprites.md
const BLINK_HZ := 2.0  # blinker flashes per second
const ARROW_R := 9.0  # the Turner arrow's bubble radius...
const ARROW_LIFT := 26.0  # ...and how far above the car's centre it floats, world px
const ARROW_IDLE := Color(1, 1, 1, 0.85)
const ARROW_STUCK := Color(1, 0.6, 0.05)  # pulsing toward ARROW_STUCK_HI while the Turner holds
const ARROW_STUCK_HI := Color(1, 0.9, 0.3)
const ARROW_INK := Color(0.1, 0.1, 0.1)
const PULSE_SPEED := 9.0  # radians per second of the stuck pulse

var car: Car
var _traffic: Traffic  # for sim time, so blinks and pulses repeat from the seed
var _boosted := false
var _wreckage := false
var _spin := 0.0
var _animated := false  # drawn with a blinker or arrow last frame


func _init(t: Traffic) -> void:
	_traffic = t


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
	z_index = 1 if _arrow_shown() else 0  # the arrow floats over neighbouring cars
	var animated := _blinking() or _arrow_shown()
	if animated or _animated or car.boosted != _boosted or car.wreckage != _wreckage:
		queue_redraw()  # every frame while animated, and once more as it stops
	_animated = animated
	_boosted = car.boosted
	_wreckage = car.wreckage


# A right-turning car signals from spawn until it's through its turn.
func _blinking() -> bool:
	return not car.wreckage and car.movement == RoadNet.Movement.RIGHT and not car.past_box()


# A Turner's arrow shows from spawn until it starts its turn.
func _arrow_shown() -> bool:
	return not car.wreckage and car.movement == RoadNet.Movement.LEFT and not car.committed


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
	if _blinking() and fmod(_traffic.time * BLINK_HZ, 1.0) < 0.5:
		# +y is the driver's right: a lamp at the front and back corners on that side.
		draw_rect(Rect2(l / 2.0 - 5.0, w / 2.0 - 4.0, 5.0, 4.0), BLINKER)
		draw_rect(Rect2(-l / 2.0, w / 2.0 - 4.0, 5.0, 4.0), BLINKER)
	if _arrow_shown():
		_draw_arrow()


# Drawn in world-aligned axes, so it stays upright however the car is turned. It points the way the
# Turner will go; quiet on the way in, then bigger and pulsing amber while it holds.
func _draw_arrow() -> void:
	draw_set_transform_matrix(Transform2D(transform.x, transform.y, Vector2.ZERO).affine_inverse())
	var to := RoadNet.left_of(car.light.direction)
	var pulse := 0.5 + 0.5 * sin(_traffic.time * PULSE_SPEED)
	var r := ARROW_R + (3.0 * pulse if car.holding else 0.0)
	var at := Vector2(0.0, -ARROW_LIFT - r)
	var bg := ARROW_STUCK.lerp(ARROW_STUCK_HI, pulse) if car.holding else ARROW_IDLE
	draw_circle(at, r + 1.5, Color(0, 0, 0, 0.6))
	draw_circle(at, r, bg)
	var tip := at + to * r * 0.65
	var tail := at - to * r * 0.55
	var side := to.orthogonal()
	draw_line(tail, tip, ARROW_INK, 2.5)
	draw_colored_polygon(PackedVector2Array([tip + to * 2.0, tip - to * 4.0 + side * 4.0, tip - to * 4.0 - side * 4.0]), ARROW_INK)
	if car.holding:
		draw_arc(at, r + 4.0, 0.0, TAU, 24, Color(ARROW_STUCK, 1.0 - pulse), 2.0)
	draw_set_transform(Vector2.ZERO)

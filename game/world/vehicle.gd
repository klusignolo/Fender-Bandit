class_name Vehicle
extends Node2D
## Draws one Car (greybox: a tinted box with a windscreen, a slim motorcycle, or a semi's cab and trailer;
## Wreckage darkened, skewed and crossed out).
## A right-turning car flashes its right blinker; a Turner carries an upright arrow that pulses amber
## while it holds. A driver spending Patience shows a ring once it has Honked, a "HONK!" at each Honk,
## and "!!" before it Blows the red; Blowing the red, it's outlined red. Cues are upright. Pooled by
## World; hidden while unused.

const GLASS := Color(0.15, 0.2, 0.3)
const TYRE := Color(0.08, 0.08, 0.1)  # a motorcycle's wheels...
const BIKE := Color(0.25, 0.25, 0.3)  # ...and its body, a greybox grey; the rider's helmet takes the tint (docs/sprites.md)
const CAB := Color("#D9D4C7")  # a semi's cab, a greybox grey (docs/sprites.md fixes the cab's details, not a swatch); its trailer takes the tint
const SEMI_CAB := 24.0  # a semi's cab length, world px; the trailer is the rest
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
const SIGNAL_RED := Color("#E8322B")  # `signal_red` in docs/sprites.md
const SIGNAL_YELLOW := Color("#F5C518")  # `signal_yellow`
const INK := Color("#1B2340")  # `ink`
const RING_R := 17.0  # the Patience ring's radius around the car's centre
const PIP_DROP := 24.0  # the Patience pips sit this far below the car's centre, world px
const HONK_TIME := 0.8  # seconds a "HONK!" shows...
const HONK_RISE := 10.0  # ...rising this far as it fades
const HONK_SIZE := 16.0  # on-screen font sizes of "HONK!" and "!!", so they read at any zoom
const WARN_SIZE := 24.0
const WARN_HZ := 3.0  # "!!" flashes per second

var car: Car
var _traffic: Traffic  # for sim time, so blinks and pulses repeat from the seed
var _boosted := false
var _wreckage := false
var _spin := 0.0
var _honks := 0  # the car's Honks when last drawn
var _honk_at := -INF  # sim time of its latest Honk
var _honk_text := ""  # what its latest Honk says, kept while it fades even if the Honks reset
var _animated := false  # drawn with a blinker or arrow last frame


func _init(t: Traffic) -> void:
	_traffic = t


func show_car(c: Car) -> void:
	car = c
	visible = c != null
	if c != null:
		_wreckage = c.wreckage
		_spin = 0.0
		_honks = c.honks
		_honk_at = -INF
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
	if car.honks > _honks:
		_honk_at = _traffic.time
		_honk_text = "HONK!" if car.honks == 1 else "HONK HONK!"
	_honks = car.honks
	var cued := _arrow_shown() or _ring_shown() or _honk_shown() or car.blow_warning
	z_index = 1 if cued else 0  # cues float over neighbouring cars
	var animated := _blinking() or cued or car.blowing
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


# The Patience ring shows once the driver has Honked: a calm wait at red is normal.
func _ring_shown() -> bool:
	return not car.wreckage and car.honks > 0


func _honk_shown() -> bool:
	return not car.wreckage and _traffic.time - _honk_at < HONK_TIME


func _draw() -> void:
	if car == null:
		return
	var l := car.length
	var w := car.width
	_draw_body()
	if car.wreckage:
		var x := Vector2(minf(l / 2.0 - 4.0, 10.0), maxf(w / 2.0 - 3.0, 4.0))
		draw_line(-x, x, Color.BLACK, 3.0)
		draw_line(Vector2(-x.x, x.y), Vector2(x.x, -x.y), Color.BLACK, 3.0)
	elif car.boosted:  # speed lines behind a car waved through on green
		draw_line(Vector2(-l / 2.0 - 8.0, -5.0), Vector2(-l / 2.0 - 2.0, -5.0), Color.WHITE, 2.0)
		draw_line(Vector2(-l / 2.0 - 10.0, 5.0), Vector2(-l / 2.0 - 2.0, 5.0), Color.WHITE, 2.0)
	if _blinking() and fmod(_traffic.time * BLINK_HZ, 1.0) < 0.5:
		# +y is the driver's right: a lamp at the front and back corners on that side.
		draw_rect(Rect2(l / 2.0 - 5.0, w / 2.0 - 4.0, 5.0, 4.0), BLINKER)
		draw_rect(Rect2(-l / 2.0, w / 2.0 - 4.0, 5.0, 4.0), BLINKER)
	if car.blowing and not car.wreckage:
		draw_rect(Rect2(-l / 2.0 - 3.0, -w / 2.0 - 3.0, l + 6.0, w + 6.0), SIGNAL_RED, false, 3.0)
	if _arrow_shown():
		_draw_arrow()
	if _ring_shown() or _honk_shown() or car.blow_warning:
		_draw_patience()


# Its body, a distinct shape per kind, along +x: a car is a box with a windscreen; a motorcycle a slim body
# between two wheels with handlebars and a tinted helmet; a semi a tinted trailer behind a pale cab.
func _draw_body() -> void:
	var l := car.length
	var w := car.width
	var tint := _shade(car.tint)
	match car.kind:
		Car.Kind.MOTORCYCLE:
			draw_rect(Rect2(-l / 2.0, -1.5, l, 3.0), TYRE)
			draw_rect(Rect2(-l / 2.0 + 4.0, -w / 2.0 + 1.0, l - 8.0, w - 2.0), _shade(BIKE))
			draw_line(Vector2(l / 2.0 - 6.0, -w / 2.0), Vector2(l / 2.0 - 6.0, w / 2.0), INK, 2.0)
			draw_circle(Vector2(-1.0, 0.0), w * 0.42, tint)
		Car.Kind.SEMI:
			draw_rect(Rect2(-l / 2.0, -w / 2.0, l - SEMI_CAB, w), tint)
			draw_rect(Rect2(l / 2.0 - SEMI_CAB, -w / 2.0, SEMI_CAB, w), _shade(CAB))
			draw_line(Vector2(l / 2.0 - SEMI_CAB, -w / 2.0), Vector2(l / 2.0 - SEMI_CAB, w / 2.0), INK, 2.0)  # the hitch
			draw_rect(Rect2(l / 2.0 - 9.0, -w / 2.0 + 3.0, 5.0, w - 6.0), GLASS)
		_:
			draw_rect(Rect2(-l / 2.0, -w / 2.0, l, w), tint)
			draw_rect(Rect2(l / 2.0 - 12.0, -w / 2.0 + 3.0, 6.0, w - 6.0), GLASS)


# A body colour, darkened on Wreckage.
func _shade(c: Color) -> Color:
	return c.darkened(WRECKAGE_DARKEN) if car.wreckage else c


# Drawn in world-aligned axes, so it stays upright however the car is turned. It points the way the
# Turner will go; quiet on the way in, then bigger and pulsing amber while it holds.
func _draw_arrow() -> void:
	_upright()
	var to := car.route.heading_out
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


# Drawn in world-aligned axes, upright: the ring fills through the current Patience stage, pips below
# count the stages gone (yellow, yellow, then red with "!!"), "HONK!" rises off each Honk, and "!!" flashes before Blowing the red.
func _draw_patience() -> void:
	_upright()
	if _ring_shown():
		var per := car.patience / Tuning.PATIENCE_RINGS
		var fill := clampf((car.wait - car.honks * per) / per, 0.0, 1.0)
		var colour := SIGNAL_RED if car.honks >= Tuning.PATIENCE_RINGS - 1 else SIGNAL_YELLOW
		draw_arc(Vector2.ZERO, RING_R, 0.0, TAU, 24, Color(INK, 0.5), 5.0)
		draw_arc(Vector2.ZERO, RING_R, -PI / 2.0, -PI / 2.0 + TAU * fill, 24, colour, 4.0)
		for p in Tuning.PATIENCE_RINGS:
			var pip := Vector2((p - (Tuning.PATIENCE_RINGS - 1) / 2.0) * 10.0, PIP_DROP)
			draw_circle(pip, 3.5, Color(INK, 0.6))
			if p < car.honks or (p == Tuning.PATIENCE_RINGS - 1 and car.blow_warning):
				draw_circle(pip, 2.5, SIGNAL_RED if p == Tuning.PATIENCE_RINGS - 1 else SIGNAL_YELLOW)
	if _honk_shown():
		var k := (_traffic.time - _honk_at) / HONK_TIME
		_cue(_honk_text, Vector2(RING_R, -RING_R - HONK_RISE * k), Color(SIGNAL_YELLOW, 1.0 - k * k), HONK_SIZE)
	if car.blow_warning and fmod(_traffic.time * WARN_HZ, 1.0) < 0.5:
		_cue("!!", Vector2(-RING_R, -RING_R), SIGNAL_RED, WARN_SIZE, true)
	draw_set_transform(Vector2.ZERO)


# A cue word outlined in ink, `on_screen` px tall at any zoom, with its bottom left at `at` (bottom right if `leftward`).
func _cue(text: String, at: Vector2, colour: Color, on_screen: float, leftward := false) -> void:
	var cam := get_viewport().get_camera_2d()
	var size := roundi(on_screen / (cam.zoom.x if cam else 1.0))
	var font := ThemeDB.fallback_font
	if leftward:
		at.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, roundi(size / 6.0), Color(INK, colour.a))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


# Undo the car's rotation, so what's drawn next stays upright however the car is turned.
func _upright() -> void:
	draw_set_transform_matrix(Transform2D(transform.x, transform.y, Vector2.ZERO).affine_inverse())

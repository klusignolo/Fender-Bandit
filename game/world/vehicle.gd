class_name Vehicle
extends Node2D
## Draws one Car from its kind's first-pass sprite layers (#39, docs/sprites.md): a body tinted the car's colour,
## untinted details (crumpled once it's Wreckage, still turned askew), and a shadow that falls down-right however it turns.
## A right-turning car flashes its right blinker; a Turner carries an upright arrow that pulses amber
## while it holds. A driver spending Patience shows a ring once it has Honked, a "HONK!" at each Honk,
## and "!!" before it Blows the red; Blowing the red, it's outlined red. Cues sit on their own layer, upright and over
## everything upright. Pooled by World; hidden while unused.

const WRECKAGE_SPIN := 0.6  # radians: Wreckage is drawn turned up to this far, so it reads as knocked askew
const BLINKER := Color("#FFE3A3")  # `blinker` in docs/sprites.md
const BLINK_HZ := 2.0  # blinker flashes per second
const ARROW_R := 9.0  # the Turner arrow's bubble radius...
const ARROW_LIFT := 26.0  # ...and how far above the car's centre it floats, world px
const ARROW_BUBBLE := 14.0  # the bubble's radius in its texture, px
const ARROW_IDLE := Color(1, 1, 1, 0.9)
const ARROW_STUCK := Color("#F5C518")  # signal_yellow, pulsing toward ARROW_STUCK_HI while the Turner holds: not orange, the Raccoon's
const ARROW_STUCK_HI := Color("#FFF3B0")
const PULSE_SPEED := 9.0  # radians per second of the stuck pulse
const SIGNAL_RED := Color("#E8322B")  # `signal_red` in docs/sprites.md
const SIGNAL_YELLOW := Color("#F5C518")  # `signal_yellow`
const INK := Art.INK
const RING_R := 17.0  # the Patience ring's radius around the car's centre
const PIP_DROP := 24.0  # the Patience pips sit this far below the car's centre, world px
const HONK_TIME := 0.8  # seconds a "HONK!" shows...
const HONK_RISE := 10.0  # ...rising this far as it fades
const HONK_SIZE := 16.0  # on-screen px tall: "HONK!" and "!!", so they read at any zoom
const WARN_SIZE := 24.0
const WARN_HZ := 3.0  # "!!" flashes per second

var car: Car
var body := Art.sprite(null)  # the tinted layer
var details := Art.sprite(null)  # never tinted: swapped for the crumpled details on Wreckage
var shadow := Art.sprite(null)  # positioned so it always falls Art.SHADOW_FALL in world px
var _cues := Node2D.new()  # upright, at the car's centre, on the cue layer
var _traffic: Traffic  # for sim time, so blinks and pulses repeat from the seed
var _layers: Dictionary  # this kind's Art.vehicle layers
var _boosted := false
var _wreckage := false
var _spin := 0.0
var _honks := 0  # the car's Honks when last drawn
var _honk_at := -INF  # sim time of its latest Honk
var _honk_text := ""  # what its latest Honk says, kept while it fades even if the Honks reset
var _animated := false  # drawn with a blinker or cue last frame


func _init(t: Traffic) -> void:
	_traffic = t
	z_index = Art.Z_VEHICLE
	shadow.modulate = Art.SHADOW
	shadow.z_as_relative = false
	shadow.z_index = Art.Z_SHADOW
	for s: Sprite2D in [shadow, body, details]:
		s.show_behind_parent = true  # under the lamps and outline this node draws
		add_child(s)
	_cues.top_level = true
	_cues.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # top-level: it doesn't inherit World's filter
	_cues.z_as_relative = false
	_cues.z_index = Art.Z_CUE
	_cues.draw.connect(_draw_cues)
	add_child(_cues)


func show_car(c: Car) -> void:
	car = c
	visible = c != null
	if c != null:
		_layers = Art.vehicle(c.kind)
		body.texture = _layers.body
		body.modulate = c.tint
		shadow.texture = _layers.shadow
		_wreckage = c.wreckage
		_spin = 0.0
		_honks = c.honks
		_honk_at = -INF
		_sync()
		queue_redraw()
		_cues.queue_redraw()


func _process(_delta: float) -> void:
	if car != null:
		_sync()


func _sync() -> void:
	if car.wreckage and not _wreckage:
		# Same car, same skew, every run: the view stays repeatable from the seed.
		_spin = (float(hash(car.id) % 2001) / 1000.0 - 1.0) * WRECKAGE_SPIN
	transform = car.transform.rotated_local(_spin)
	shadow.position = transform.basis_xform_inv(Art.SHADOW_FALL)
	details.texture = _layers.wreck if car.wreckage else _layers.details
	_cues.position = transform.origin
	if car.honks > _honks:
		_honk_at = _traffic.time
		_honk_text = "HONK!" if car.honks == 1 else "HONK HONK!"
	_honks = car.honks
	var cued := _arrow_shown() or _ring_shown() or _honk_shown() or car.blow_warning
	var animated := _blinking() or cued or car.blowing
	if animated or _animated or car.boosted != _boosted or car.wreckage != _wreckage:
		queue_redraw()  # every frame while animated, and once more as it stops
		_cues.queue_redraw()
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


# Over the sprite layers, in the car's own axes: speed lines, blinkers and the Blowing-the-red outline.
func _draw() -> void:
	if car == null or car.wreckage:
		return
	var l := car.length
	var w := car.width
	if car.boosted:  # speed lines behind a car waved through on green
		draw_line(Vector2(-l / 2.0 - 8.0, -5.0), Vector2(-l / 2.0 - 2.0, -5.0), Color.WHITE, 2.0)
		draw_line(Vector2(-l / 2.0 - 10.0, 5.0), Vector2(-l / 2.0 - 2.0, 5.0), Color.WHITE, 2.0)
	if _blinking() and fmod(_traffic.time * BLINK_HZ, 1.0) < 0.5:
		# +y is the driver's right: a lamp at the front and back corners on that side.
		draw_rect(Rect2(l / 2.0 - 5.0, w / 2.0 - 4.0, 5.0, 4.0), BLINKER)
		draw_rect(Rect2(-l / 2.0, w / 2.0 - 4.0, 5.0, 4.0), BLINKER)
	if car.blowing:
		draw_rect(Rect2(-l / 2.0 - 3.0, -w / 2.0 - 3.0, l + 6.0, w + 6.0), SIGNAL_RED, false, 3.0)


# The upright cues, on _cues: in world axes, centred on the car.
func _draw_cues() -> void:
	if car == null:
		return
	if _arrow_shown():
		_draw_arrow()
	if _ring_shown() or _honk_shown() or car.blow_warning:
		_draw_patience()


# The Turner's bubble, with its arrow pointing the way the Turner will go; quiet on the way in, then bigger and
# pulsing amber while it holds.
func _draw_arrow() -> void:
	var pulse := 0.5 + 0.5 * sin(_traffic.time * PULSE_SPEED)
	var r := ARROW_R + (3.0 * pulse if car.holding else 0.0)
	var at := Vector2(0.0, -ARROW_LIFT - r)
	var size := Art.CUE_TURNER.get_size() * r / ARROW_BUBBLE
	var bg := ARROW_STUCK.lerp(ARROW_STUCK_HI, pulse) if car.holding else ARROW_IDLE
	_cues.draw_texture_rect(Art.CUE_TURNER, Rect2(at - size / 2.0, size), false, bg)
	_cues.draw_set_transform(at, car.route.heading_out.angle())
	_cues.draw_texture_rect(Art.CUE_TURNER_ARROW, Rect2(-size / 2.0, size), false)
	_cues.draw_set_transform(Vector2.ZERO)
	if car.holding:
		_cues.draw_arc(at, r + 4.0, 0.0, TAU, 24, Color(ARROW_STUCK, 1.0 - pulse), 2.0)


# The ring fills through the current Patience stage, pips below count the stages gone (yellow, yellow, then red with
# "!!"), a "HONK!" burst rises off each Honk, and "!!" flashes before Blowing the red.
func _draw_patience() -> void:
	if _ring_shown():
		var per := car.patience / Tuning.PATIENCE_RINGS
		var fill := clampf((car.wait - car.honks * per) / per, 0.0, 1.0)
		var colour := SIGNAL_RED if car.honks >= Tuning.PATIENCE_RINGS - 1 else SIGNAL_YELLOW
		_cues.draw_arc(Vector2.ZERO, RING_R, 0.0, TAU, 24, Color(INK, 0.5), 5.0)
		_cues.draw_arc(Vector2.ZERO, RING_R, -PI / 2.0, -PI / 2.0 + TAU * fill, 24, colour, 4.0)
		for p in Tuning.PATIENCE_RINGS:
			var pip := Vector2((p - (Tuning.PATIENCE_RINGS - 1) / 2.0) * 10.0, PIP_DROP)
			_cues.draw_circle(pip, 3.5, Color(INK, 0.6))
			if p < car.honks or (p == Tuning.PATIENCE_RINGS - 1 and car.blow_warning):
				_cues.draw_circle(pip, 2.5, SIGNAL_RED if p == Tuning.PATIENCE_RINGS - 1 else SIGNAL_YELLOW)
	var per_px := 1.0 / _zoom()  # world px per on-screen px
	if _honk_shown():
		var k := (_traffic.time - _honk_at) / HONK_TIME
		_honk(Vector2(RING_R, -RING_R - HONK_RISE * k), roundi(HONK_SIZE * per_px), 1.0 - k * k)
	if car.blow_warning and fmod(_traffic.time * WARN_HZ, 1.0) < 0.5:
		var tex := Art.CUE_BLOW
		var size := tex.get_size() * WARN_SIZE * per_px / tex.get_size().y
		_cues.draw_texture_rect(tex, Rect2(Vector2(-RING_R, -RING_R) - size, size), false)


# The Honk burst with its word in ink, `size` world px tall, its bottom left at `at`.
func _honk(at: Vector2, size: int, alpha: float) -> void:
	var font := ThemeDB.fallback_font
	var text_w := font.get_string_size(_honk_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var burst := Vector2(text_w * 1.4 + size, size * 2.2)  # the spikes eat into the sides
	var centre := at + Vector2(text_w / 2.0, -size * 0.35)
	_cues.draw_texture_rect(Art.CUE_HONK, Rect2(centre - burst / 2.0, burst), false, Color(1, 1, 1, alpha))
	_cues.draw_string(font, at, _honk_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(INK, alpha))


func _zoom() -> float:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	return cam.zoom.x if cam else 1.0

class_name Vehicle
extends Node2D
## Draws one Car from its kind's first-pass sprite layers (#39, docs/sprites.md): a body tinted the car's colour,
## untinted details (crumpled once it's Wreckage, still turned askew), and a shadow that falls down-right however it turns.
## Its brake lamps light while it slows or waits. A turning car flashes the blinker on its turning side until it's
## through its turn, and Wreckage trails a smoke wisp until it's Towed. A Turner carries an upright arrow that pulses amber
## while it holds. A driver spending Patience shows a ring once it has Honked, a "HONK!" at each Honk,
## and "!!" before it Blows the red; Blowing the red, it's outlined red. Cues sit on their own layer, upright and over
## everything upright, and past the cue floor zoom (#41) they hold their size on screen.
## Pooled by World; hidden while unused.
## At Gridlock (#43) it coasts on along its heading on scaled delta, so in the beat's slow-mo (a stopped car lurches
## forward into the one ahead), until the pile-up crumples it as Wreckage in the view alone: the Car is left as it was.

const WRECKAGE_SPIN := 0.6  # radians: Wreckage is drawn turned up to this far, so it reads as knocked askew
const BLINK_HZ := 2.0  # blinker flashes per second
const SMOKE_PUFFS := 3  # puffs in a Wreckage's smoke wisp, evenly staggered...
const SMOKE_LIFE := 1.6  # ...each rising for this many seconds...
const SMOKE_DRIFT := Vector2(10.0, -30.0)  # ...this far, world px: up and off with the wind...
const SMOKE_SIZE := Vector2(14.0, 30.0)  # ...growing from and to these widths, world px
const SMOKE_ALPHA := 0.95  # ...peaking at this opacity once faded in over...
const SMOKE_FADE_IN := 0.15  # ...this share of its rise, then fading out
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
const CREW := 3  # little raccoons that grab a garbage truck's trash while it collects (#46): charm only
const CREW_H := 20.0  # world px tall, before the cue floor
const CREW_KERB := 24.0  # world px past the truck's right side that they run from: the kerb
const CREW_REACH := 5.0  # ...to this close to its side
const CREW_STAGGER := 0.12  # share of the pickup between one raccoon setting off and the next
const CREW_TRIP := 0.6  # share of the pickup each round trip takes: out empty-handed, back with a bag
const CREW_HOPS := 3.0  # hops each way
const BAG := Color("#2E3A2F")  # a trash bag: dark, so it reads against the grey road and the fur

var car: Car
var body := Art.sprite(null)  # the tinted layer
var details := Art.sprite(null)  # never tinted: swapped for the crumpled details on Wreckage
var shadow := Art.sprite(null)  # positioned so it always falls Art.SHADOW_FALL in world px
var brake := Art.sprite(null)  # the brake lamps, lit while it slows or waits
var blink := Art.sprite(null)  # the right-hand blinkers, mirrored for a left turn, shown while they flash on
var smoke := Node2D.new()  # Wreckage's smoke wisp: upright, at its centre
var coast := false  # the Gridlock beat: drive on along its heading, at its last speed, until it piles up
var _cues := Node2D.new()  # upright, at the car's centre, on the cue layer
var _crew := Node2D.new()  # the little raccoons, upright, at the car's centre, over the vehicles (#46)
var _crewing := false  # collecting when last drawn
var _traffic: Traffic  # for sim time, so blinks and pulses repeat from the seed
var _layers: Dictionary  # this kind's Art.vehicle layers
var _boosted := false
var _drawn_wrecked := false
var _spin := 0.0
var _honks := 0  # the car's Honks when last drawn
var _honk_at := -INF  # sim time of its latest Honk
var _honk_text := ""  # what its latest Honk says, kept while it fades even if the Honks reset
var _animated := false  # drawn with a cue or the Blowing outline last frame
var _piled := false  # crumpled by the Gridlock pile-up
var _coasted := 0.0  # world px it has coasted


func _init(t: Traffic) -> void:
	_traffic = t
	z_index = Art.Z_VEHICLE
	shadow.modulate = Art.SHADOW
	shadow.z_as_relative = false
	shadow.z_index = Art.Z_SHADOW
	for s: Sprite2D in [shadow, body, details, brake, blink]:
		s.show_behind_parent = true  # under the speed lines and outline this node draws
		add_child(s)
	brake.visible = false
	blink.visible = false
	for n: Node2D in [smoke, _cues, _crew]:
		n.top_level = true
		n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # top-level: it doesn't inherit World's filter
		n.z_as_relative = false
		add_child(n)
	smoke.z_index = Art.Z_VEHICLE
	smoke.visible = false
	smoke.draw.connect(_draw_smoke)
	_cues.z_index = Art.Z_CUE
	_cues.draw.connect(_draw_cues)
	_crew.z_index = Art.Z_UPRIGHT
	_crew.draw.connect(_draw_crew)


func show_car(c: Car) -> void:
	car = c
	visible = c != null
	if c != null:
		_layers = Art.vehicle(c.kind)
		body.texture = _layers.body
		body.modulate = c.tint
		shadow.texture = _layers.shadow
		brake.texture = _layers.brake
		blink.texture = _layers.blink
		coast = false
		_piled = false
		_coasted = 0.0
		_drawn_wrecked = c.wreckage
		_spin = 0.0
		_honks = c.honks
		_honk_at = -INF
		_sync()
		queue_redraw()
		_cues.queue_redraw()


func _process(delta: float) -> void:
	if car != null:
		if coast and not _wrecked():
			_coasted += maxf(car.speed, Tuning.GRIDLOCK_LURCH) * delta  # a stopped queue lurches into itself
		_sync()


## The Gridlock pile-up: it crumples where it is.
func pile_up() -> void:
	_piled = true


func _wrecked() -> bool:
	return car.wreckage or _piled


func _sync() -> void:
	if _wrecked() and not _drawn_wrecked:
		# Same car, same skew, every run: the view stays repeatable from the seed.
		_spin = (float(hash(car.id) % 2001) / 1000.0 - 1.0) * WRECKAGE_SPIN
	transform = car.transform.translated_local(Vector2(_coasted, 0.0)).rotated_local(_spin)
	shadow.position = transform.basis_xform_inv(Art.SHADOW_FALL)
	details.texture = _layers.wreck if _wrecked() else _layers.details
	_cues.position = transform.origin
	_cues.scale = Vector2.ONE * Art.cue_scale(_zoom())  # past the cue floor they hold their size on screen
	_crew.position = transform.origin
	if car.collecting or _crewing:
		_crew.queue_redraw()  # every frame while it collects, and once more as it stops
	_crewing = car.collecting
	brake.visible = car.braking and not _wrecked()
	var side := _blink_side()
	blink.visible = side != 0.0 and fmod(_traffic.time * BLINK_HZ, 1.0) < 0.5
	blink.scale.y = Art.SCALE * (side if side != 0.0 else 1.0)
	smoke.visible = _wrecked() and not car.towed
	if smoke.visible:
		smoke.position = transform.origin
		smoke.queue_redraw()
	if car.honks > _honks:
		_honk_at = _traffic.time
		_honk_text = "HONK!" if car.honks == 1 else "HONK HONK!"
	_honks = car.honks
	var cued := _arrow_shown() or _ring_shown() or _honk_shown() or car.blow_warning
	var animated := cued or car.blowing
	if animated or _animated or car.boosted != _boosted or _wrecked() != _drawn_wrecked:
		queue_redraw()  # every frame while animated, and once more as it stops
		_cues.queue_redraw()
	_animated = animated
	_boosted = car.boosted
	_drawn_wrecked = _wrecked()


# Which side a turning car signals, from spawn until it's through its turn: 1.0 for its right (+y), -1.0 for its left,
# 0.0 for none.
func _blink_side() -> float:
	if _wrecked() or car.past_box():
		return 0.0
	match car.movement:
		RoadNet.Movement.RIGHT:
			return 1.0
		RoadNet.Movement.LEFT:
			return -1.0
	return 0.0


# A Turner's arrow shows from spawn until it starts its turn.
func _arrow_shown() -> bool:
	return not _wrecked() and car.movement == RoadNet.Movement.LEFT and not car.committed


# The Patience ring shows once the driver has Honked: a calm wait at red is normal.
func _ring_shown() -> bool:
	return not _wrecked() and car.honks > 0


func _honk_shown() -> bool:
	return not _wrecked() and _traffic.time - _honk_at < HONK_TIME


# Over the sprite layers, in the car's own axes: speed lines and the Blowing-the-red outline.
func _draw() -> void:
	if car == null or _wrecked():
		return
	var l := car.length
	var w := car.width
	if car.boosted:  # speed lines behind a car waved through on green
		draw_line(Vector2(-l / 2.0 - 8.0, -5.0), Vector2(-l / 2.0 - 2.0, -5.0), Color.WHITE, 2.0)
		draw_line(Vector2(-l / 2.0 - 10.0, 5.0), Vector2(-l / 2.0 - 2.0, 5.0), Color.WHITE, 2.0)
	if car.blowing:  # as thick on screen as a cue at the cue floor
		var o := 3.0 * Art.cue_scale(_zoom())
		draw_rect(Rect2(-l / 2.0 - o, -w / 2.0 - o, l + o * 2.0, w + o * 2.0), SIGNAL_RED, false, o)


# The smoke wisp, on smoke: puffs rise off the Wreckage's centre in world axes, growing and fading, staggered by the
# car's id so neighbouring wrecks don't puff in step.
func _draw_smoke() -> void:
	var phase := float(hash(car.id) % 1000) / 1000.0
	for i in SMOKE_PUFFS:
		var k := fmod(_traffic.time / SMOKE_LIFE + phase + float(i) / SMOKE_PUFFS, 1.0)
		var w := lerpf(SMOKE_SIZE.x, SMOKE_SIZE.y, k)
		var at := SMOKE_DRIFT * k
		var alpha := SMOKE_ALPHA * minf(k / SMOKE_FADE_IN, 1.0) * (1.0 - k)
		smoke.draw_texture_rect(Art.SMOKE_PUFF, Rect2(at - Vector2(w, w) / 2.0, Vector2(w, w)), false, Color(1, 1, 1, alpha))


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
	var per_px := 1.0 / (_zoom() * _cues.scale.x)  # cue px per on-screen px: HONK! and "!!" are sized on screen
	if _honk_shown():
		var k := (_traffic.time - _honk_at) / HONK_TIME
		_honk(Vector2(RING_R, -RING_R - HONK_RISE * k), roundi(HONK_SIZE * per_px), 1.0 - k * k)
	if car.blow_warning and fmod(_traffic.time * WARN_HZ, 1.0) < 0.5:
		var tex := Art.CUE_BLOW
		var size := tex.get_size() * WARN_SIZE * per_px / tex.get_size().y
		_cues.draw_texture_rect(tex, Rect2(Vector2(-RING_R, -RING_R) - size, size), false)


# The Honk burst with its word in ink, `size` world px tall, its bottom left at `at`.
func _honk(at: Vector2, size: int, alpha: float) -> void:
	var font := Sign.FONT
	var text_w := font.get_string_size(_honk_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var burst := Vector2(text_w * 1.4 + size, size * 2.2)  # the spikes eat into the sides
	var centre := at + Vector2(text_w / 2.0, -size * 0.35)
	_cues.draw_texture_rect(Art.CUE_HONK, Rect2(centre - burst / 2.0, burst), false, Color(1, 1, 1, alpha))
	_cues.draw_string(font, at, _honk_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(INK, alpha))


func _zoom() -> float:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	return cam.zoom.x if cam else 1.0


# A garbage truck's trash crew (#46), on _crew while it collects: little raccoons staggered along its back half hop
# from the kerb on its right to its side and back, a bag in their arms on the way back. Charm only: the sim never
# sees them. Upright, in world axes, held to the cue floor so they read zoomed out.
func _draw_crew() -> void:
	if car == null or not car.collecting or _wrecked():
		return
	var tex := Art.RACCOON_FRONT
	var k := Art.cue_scale(_zoom())
	var size := tex.get_size() * CREW_H * k / tex.get_size().y
	var p := car.collect_time / Tuning.PICKUP_TIME
	var basis := Transform2D(transform.get_rotation(), Vector2.ZERO)  # the truck's axes, about its centre
	for i in CREW:
		var q := (p - i * CREW_STAGGER) / CREW_TRIP
		if q <= 0.0 or q >= 1.0:
			continue
		var x := -car.length / 2.0 + car.length * (i + 0.5) / (CREW * 2.0)  # along its back half
		var kerb := basis * Vector2(x, car.width / 2.0 + CREW_KERB)
		var side := basis * Vector2(x, car.width / 2.0 + CREW_REACH)
		var out := q < 0.5
		var at := kerb.lerp(side, q * 2.0 if out else 2.0 - q * 2.0)
		at.y -= absf(sin(q * PI * CREW_HOPS * 2.0)) * 3.0 * k  # hop
		_crew.draw_texture_rect(tex, Rect2(at - Vector2(size.x / 2.0, size.y), size), false)
		if not out:
			_crew.draw_circle(at + Vector2(0.0, -size.y * 0.3), size.x * 0.32, BAG)

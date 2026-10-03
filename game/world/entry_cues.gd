class_name EntryCues
extends Node2D
## At each map entry (#27): triple chevrons on the Swell road, lighting up one after another
## toward the crossing like a marquee while the Swell is on it;
## and, when cars are waiting to get on, its backlog as "+N", with the lane pulsing red while the Jam is Heavy
## (story 52). Greybox: the cue_swell sprite (docs/sprites.md) replaces the drawn chevrons.

const INSET := 110.0  # on-screen px in from the map edge, along the lane, where the cues sit: clear of the HUD strip at the top at any zoom
const CHEVRON_OUT := 34.0  # world px from the lane's centre out past the kerb to the chevrons...
const TAG_OUT := 74.0  # ...and to the "+N"
const PULSE_LENGTH := 160.0  # world px of lane, in from the map edge, that pulses under a backlog
const MARQUEE_HZ := 1.0  # times a second the light runs along the chevrons, back to front
const MARQUEE_DIM := 0.2  # an unlit chevron's opacity
const PULSE_HZ := 1.6
const TAG_SIZE := 26
const MARKING := Color("#EEF1F6")  # the chevrons and "+N": white, like a road marking (palette in docs/sprites.md)
const HEAVY_RED := Color("#E8322B")  # signal_red: the pulse is part of the Heavy Jam signal
const INK := Color("#1B2340")

var _traffic: Traffic
var _clock := 0.0


func _init(traffic: Traffic) -> void:
	_traffic = traffic
	z_index = 5


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_clock * TAU * PULSE_HZ)
	var heavy := _traffic.jam.level() >= Jam.Level.HEAVY 
	var cam := get_viewport().get_camera_2d()
	var inset := INSET / (cam.zoom.x if cam else 1.0)
	for i in _traffic.net.approaches.size():
		var a := _traffic.net.approaches[i]
		if not a.entry:
			continue
		var d := a.direction
		var right := RoadNet.right_of(d)
		var edge := _traffic.net.segments[a.incoming].curve.get_point_position(0) + d * Tuning.SPAWN_BACK
		var at := edge + d * inset
		var waiting := _traffic.backlog(i)
		if waiting > 0 and heavy:  # an outline, as the lane under it is full of cars
			var lane := Rect2(edge, Vector2.ZERO).expand(edge + d * PULSE_LENGTH).grow(Tuning.LW / 2.0 + 2.0)
			draw_rect(lane, Color(HEAVY_RED, 0.35 + 0.65 * pulse), false, 2.0 + 3.0 * pulse)
		if _traffic.k_swell and i == _traffic.swell:
			_chevrons(at + right * CHEVRON_OUT, d)
		if waiting > 0:
			_tag("+%d" % waiting, at + right * TAG_OUT, MARKING)


# Three chevrons along the lane, pointing the way its cars drive, lit in turn from the back one to the front one:
# each brightens and fades smoothly, a third of a cycle after the one behind it.
func _chevrons(at: Vector2, d: Vector2) -> void:
	var side := RoadNet.right_of(d)
	for k in 3:
		var lit := 0.5 + 0.5 * cos(TAU * (_clock * MARQUEE_HZ - k / 3.0))
		var alpha := lerpf(MARQUEE_DIM, 1.0, lit * lit)
		var tip := at + d * (k - 1) * 12.0
		var arm := PackedVector2Array([tip - d * 7.0 + side * 11.0, tip, tip - d * 7.0 - side * 11.0])
		draw_polyline(arm, Color(INK, alpha), 7.0)
		draw_polyline(arm, Color(MARKING, alpha), 4.0)


func _tag(text: String, centre: Vector2, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE)
	var at := centre + Vector2(-size.x / 2.0, TAG_SIZE * 0.35)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE, 6, INK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_SIZE, col)

class_name Raccoon
extends Node2D
## The player (ADR 0001: the one node that moves itself). Moves with any bound input at a constant
## on-screen speed, Dashes the way it faces, Switches the nearest Light in range (biased toward the way it
## faces), Tows Wreckage, and feeds its position and Dash to Traffic every tick. Grab, drop, the slower walk,
## getting hit and the stun are Traffic rules: while stunned it only drifts with Traffic's knockback.
## First-pass look (#39): one whole sprite per view, picked from its facing, until the cutout rig (#41).

## Which way it shows: the front moving down, the back moving up, and the side (mirrored for left) on any diagonal.
enum View { FRONT, BACK, RIGHT, LEFT }

signal dashed  # a Dash started: Audio's whoosh (#37)

## What it's asked to do this tick: the player's input, or the autopilot's.
class Intent:
	var move := Vector2.ZERO  # as Input.get_vector: length up to 1
	var dash := false
	var switch := false
	var tow := false

const SIDE_FROM := 0.38  # the side view shows once the facing is this far across (sin 22.5°): every diagonal
const TARGET := Color("#FF7A1A")  # raccoon_orange: the Switch target is a Raccoon UI moment
const ROPE := Art.INK
const ROPE_CORE := Color("#C9CED8")
const SHADOW_R := Vector2(12, 5)  # world px: the shadow ellipse under its feet
const COOLDOWN := Color(0.4, 0.8, 1.0)
const BONK := Color(1, 0.85, 0.1)
const BONK_SIZE := 22

var traffic: Traffic
var facing := Vector2.UP
var target: Light  # the Light a Switch would hit now, or null
var cam_zoom := 1.0  # the camera zoom, which World sets each tick: speeds and ranges scale with 1/zoom
var pilot: Autopilot  # plays it in Attract (#34); null reads the player's input

var _pressed := Intent.new()  # the buttons pressed since the last tick

var _dash_left := 0.0  # seconds left in the current Dash
var _dash_cooldown := 0.0  # seconds until the next Dash can start
var _dash_dir := Vector2.UP
var _sprite := Art.sprite(Art.RACCOON_FRONT)
var _shadow := Node2D.new()


func _init(t: Traffic) -> void:
	traffic = t
	process_physics_priority = -1  # move and feed Traffic before World steps it
	_sprite.offset = Art.RACCOON_FRONT.get_size() / 2.0 - Art.RACCOON_FEET  # feet on its position
	_sprite.show_behind_parent = true  # under the rope, target and rings it draws
	add_child(_sprite)
	_shadow.z_as_relative = false
	_shadow.z_index = Art.Z_SHADOW
	_shadow.draw.connect(func() -> void:
		_shadow.draw_set_transform(Art.SHADOW_FALL, 0.0, SHADOW_R / SHADOW_R.x)
		_shadow.draw_circle(Vector2.ZERO, SHADOW_R.x, Art.SHADOW))
	add_child(_shadow)


func _physics_process(delta: float) -> void:
	var world_per_px := 1.0 / cam_zoom  # world px per on-screen px
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	var intent := _player_intent()  # read every tick, so presses made while the autopilot plays don't pile up
	if pilot != null:
		intent = pilot.decide(position, target, world_per_px)
	var dashing := false
	if traffic.raccoon_stun > 0.0:
		_dash_left = 0.0
		position += traffic.raccoon_knock * delta
	else:
		dashing = _move(intent, delta, world_per_px)
	var r := Tuning.RACCOON_R
	position = position.clamp(traffic.net.bounds.position + Vector2(r, r), traffic.net.bounds.end - Vector2(r, r))
	traffic.set_raccoon(position, dashing)
	target = _pick_target(world_per_px) if traffic.raccoon_stun <= 0.0 else null
	_show_view()
	if target != null and intent.switch:
		traffic.switch(target)
	if intent.tow:
		traffic.tow(Tuning.TOW_RANGE * world_per_px)
	queue_redraw()


## The player's intent this tick, from the InputMap: the stick as held now, and the buttons pressed since the last tick.
func _player_intent() -> Intent:
	var i := _pressed
	_pressed = Intent.new()
	i.move = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	return i


## Button presses come as events, not polled, so one that reached Main while this was paused or not yet built (the
## press that resumes from Pause, or closes the controls card) is never seen here as well (#35).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	_pressed.dash = _pressed.dash or event.is_action_pressed(&"dash")
	_pressed.switch = _pressed.switch or event.is_action_pressed(&"switch")
	_pressed.tow = _pressed.tow or event.is_action_pressed(&"tow")


## Walk or Dash as `intent` asks; true while Dashing.
func _move(intent: Intent, delta: float, world_per_px: float) -> bool:
	var input := intent.move
	if input != Vector2.ZERO:  # the InputMap deadzone already filtered drift
		facing = input.normalized()
	if intent.dash and _dash_cooldown <= 0.0:
		_dash_left = Tuning.DASH_TIME
		_dash_cooldown = Tuning.DASH_COOLDOWN
		_dash_dir = facing
		dashed.emit()
	var dashing := _dash_left > 0.0
	traffic.set_raccoon(position, dashing)  # towing slows a walk and a Dash differently
	var speed_scale := traffic.raccoon_speed_scale() * world_per_px
	if dashing:
		_dash_left -= delta
		position += _dash_dir * Tuning.DASH_SPEED * speed_scale * delta
	else:
		position += input * Tuning.RACCOON_SPEED * speed_scale * delta
	return dashing


## Its view for a facing: the side on any diagonal, else the front or back.
static func view_of(f: Vector2) -> View:
	if absf(f.x) >= SIDE_FROM:
		return View.RIGHT if f.x > 0.0 else View.LEFT
	return View.FRONT if f.y > 0.0 else View.BACK


func _show_view() -> void:
	var v := view_of(facing)
	_sprite.texture = [Art.RACCOON_FRONT, Art.RACCOON_BACK, Art.RACCOON_SIDE, Art.RACCOON_SIDE][v]
	_sprite.flip_h = v == View.LEFT


## The nearest Light pole in range, with Lights the Raccoon faces counting as nearer.
func _pick_target(world_per_px: float) -> Light:
	var best: Light = null
	var best_score := INF
	for l in traffic.lights:
		var d := position.distance_to(l.pole)
		if d > Tuning.SIGNAL_RANGE * world_per_px:
			continue
		var score := d - Tuning.TARGET_BIAS * world_per_px * facing.dot((l.pole - position).normalized())
		if score < best_score:
			best_score = score
			best = l
	return best


func _draw() -> void:
	if traffic.towing != null:
		var wreck := to_local(traffic.towing.transform.origin)
		draw_line(Vector2.ZERO, wreck, ROPE, 4.0)
		draw_line(Vector2.ZERO, wreck, ROPE_CORE, 1.5)
	if target != null:
		var at := to_local(target.pole)
		draw_arc(at, 14.0, 0, TAU, 24, TARGET, 3.0)
		draw_dashed_line(Vector2.ZERO, at, Color(TARGET, 0.5), 2.0, 6.0)
	var r := Tuning.RACCOON_R
	# Dash cooldown: a ring that fills back up; gone once a Dash is ready.
	if _dash_cooldown > 0.0:
		var filled := 1.0 - _dash_cooldown / Tuning.DASH_COOLDOWN
		draw_arc(Vector2.ZERO, r + 7.0, -PI / 2.0, -PI / 2.0 + TAU * filled, 32, COOLDOWN, 3.0)
	if traffic.raccoon_stun > 0.0:
		var font := ThemeDB.fallback_font
		var w := font.get_string_size("BONK!", HORIZONTAL_ALIGNMENT_LEFT, -1, BONK_SIZE).x
		var at := Vector2(-w / 2.0, -Art.RACCOON_FEET.y * Art.SCALE - 6.0)  # over its head
		draw_string_outline(font, at, "BONK!", HORIZONTAL_ALIGNMENT_LEFT, -1, BONK_SIZE, 5, Color.BLACK)
		draw_string(font, at, "BONK!", HORIZONTAL_ALIGNMENT_LEFT, -1, BONK_SIZE, BONK)

class_name Raccoon
extends Node2D
## The player (ADR 0001: the one node that moves itself). Moves with any bound input at a constant
## on-screen speed, Dashes the way it faces, Switches the nearest Light in range (biased toward the way it
## faces), Tows Wreckage, and feeds its position and Dash to Traffic every tick. Grab, drop, the slower walk,
## getting hit and the stun are Traffic rules: while stunned it only drifts with Traffic's knockback.
## Greybox look until the rig (#41).

const FUR := Color(0.55, 0.55, 0.58)
const MASK := Color(0.1, 0.1, 0.1)
const VEST := Color(1, 0.6, 0.1)
const TARGET := Color(1, 1, 0)
const ROPE := Color(0.8, 0.6, 0.3)
const COOLDOWN := Color(0.4, 0.8, 1.0)
const BONK := Color(1, 0.85, 0.1)
const BONK_SIZE := 22

var traffic: Traffic
var facing := Vector2.UP
var target: Light  # the Light a Switch would hit now, or null

var _dash_left := 0.0  # seconds left in the current Dash
var _dash_cooldown := 0.0  # seconds until the next Dash can start
var _dash_dir := Vector2.UP


func _init(t: Traffic) -> void:
	traffic = t
	process_physics_priority = -1  # move and feed Traffic before World steps it


func _physics_process(delta: float) -> void:
	var world_per_px := _world_per_screen()
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	var dashing := false
	if traffic.raccoon_stun > 0.0:
		_dash_left = 0.0
		position += traffic.raccoon_knock * delta
	else:
		dashing = _move(delta, world_per_px)
	var r := Tuning.RACCOON_R
	position = position.clamp(traffic.net.bounds.position + Vector2(r, r), traffic.net.bounds.end - Vector2(r, r))
	traffic.set_raccoon(position, dashing)
	target = _pick_target(world_per_px) if traffic.raccoon_stun <= 0.0 else null
	if target != null and Input.is_action_just_pressed(&"switch"):
		traffic.switch(target)
	if Input.is_action_just_pressed(&"tow"):
		traffic.tow(Tuning.TOW_RANGE * world_per_px)
	queue_redraw()


## Walk or Dash with the input; true while Dashing.
func _move(delta: float, world_per_px: float) -> bool:
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if input != Vector2.ZERO:  # the InputMap deadzone already filtered drift
		facing = input.normalized()
	if Input.is_action_just_pressed(&"dash") and _dash_cooldown <= 0.0:
		_dash_left = Tuning.DASH_TIME
		_dash_cooldown = Tuning.DASH_COOLDOWN
		_dash_dir = facing
	var dashing := _dash_left > 0.0
	traffic.set_raccoon(position, dashing)  # towing slows a walk and a Dash differently
	var speed_scale := traffic.raccoon_speed_scale() * world_per_px
	if dashing:
		_dash_left -= delta
		position += _dash_dir * Tuning.DASH_SPEED * speed_scale * delta
	else:
		position += input * Tuning.RACCOON_SPEED * speed_scale * delta
	return dashing


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


## World px per on-screen px, so speed and range stay the same on screen at any zoom.
func _world_per_screen() -> float:
	var cam := get_viewport().get_camera_2d()
	return 1.0 / cam.zoom.x if cam else 1.0


func _draw() -> void:
	if traffic.towing != null:
		draw_line(Vector2.ZERO, to_local(traffic.towing.transform.origin), ROPE, 3.0)
	if target != null:
		var at := to_local(target.pole)
		draw_arc(at, 14.0, 0, TAU, 24, TARGET, 3.0)
		draw_dashed_line(Vector2.ZERO, at, Color(TARGET, 0.5), 2.0, 6.0)
	var r := Tuning.RACCOON_R
	var tail := -facing * 18.0
	draw_circle(tail, 8.0, FUR)
	draw_arc(tail, 5.0, 0, TAU, 12, MASK, 3.0)
	draw_circle(Vector2.ZERO, r, FUR)
	var side := Vector2(-facing.y, facing.x)
	draw_line(facing * 5 + side * 10, facing * 5 - side * 10, MASK, 6.0)
	draw_circle(facing * 5 + side * 5, 2.0, Color.WHITE)
	draw_circle(facing * 5 - side * 5, 2.0, Color.WHITE)
	draw_circle(facing * 14.0, 3.0, MASK)
	draw_arc(Vector2.ZERO, r + 3.0, 0, TAU, 24, VEST, 2.0)
	# Dash cooldown: a ring that fills back up; gone once a Dash is ready.
	if _dash_cooldown > 0.0:
		var filled := 1.0 - _dash_cooldown / Tuning.DASH_COOLDOWN
		draw_arc(Vector2.ZERO, r + 7.0, -PI / 2.0, -PI / 2.0 + TAU * filled, 32, COOLDOWN, 3.0)
	if traffic.raccoon_stun > 0.0:
		var font := ThemeDB.fallback_font
		var w := font.get_string_size("BONK!", HORIZONTAL_ALIGNMENT_LEFT, -1, BONK_SIZE).x
		var at := Vector2(-w / 2.0, -r - 12.0)
		draw_string_outline(font, at, "BONK!", HORIZONTAL_ALIGNMENT_LEFT, -1, BONK_SIZE, 5, Color.BLACK)
		draw_string(font, at, "BONK!", HORIZONTAL_ALIGNMENT_LEFT, -1, BONK_SIZE, BONK)

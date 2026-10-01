class_name Raccoon
extends Node2D
## The player (ADR 0001: the one node that moves itself). Moves with any bound input at a constant
## on-screen speed, Switches the nearest Light in range (biased toward the way it faces), Tows Wreckage
## (grab, drop and the slower walk are Traffic rules), and feeds its position to Traffic every tick.
## Greybox look until the rig (#41).

const FUR := Color(0.55, 0.55, 0.58)
const MASK := Color(0.1, 0.1, 0.1)
const VEST := Color(1, 0.6, 0.1)
const TARGET := Color(1, 1, 0)
const ROPE := Color(0.8, 0.6, 0.3)

var traffic: Traffic
var facing := Vector2.UP
var target: Light  # the Light a Switch would hit now, or null


func _init(t: Traffic) -> void:
	traffic = t
	process_physics_priority = -1  # move and feed Traffic before World steps it


func _physics_process(delta: float) -> void:
	var world_per_px := _world_per_screen()
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if input != Vector2.ZERO:  # the InputMap deadzone already filtered drift
		facing = input.normalized()
	var r := Tuning.RACCOON_R
	var speed := Tuning.RACCOON_SPEED * traffic.raccoon_speed_scale() * world_per_px
	position = (position + input * speed * delta).clamp(
			traffic.net.bounds.position + Vector2(r, r), traffic.net.bounds.end - Vector2(r, r))
	traffic.set_raccoon(position, false)
	target = _pick_target(world_per_px)
	if target != null and Input.is_action_just_pressed(&"switch"):
		traffic.switch(target)
	if Input.is_action_just_pressed(&"tow"):
		traffic.tow(Tuning.TOW_RANGE * world_per_px)
	queue_redraw()


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

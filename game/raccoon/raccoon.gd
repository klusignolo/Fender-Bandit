class_name Raccoon
extends Node2D
## The player (ADR 0001: the one node that moves itself). Moves with any bound input at a constant
## on-screen speed, Dashes the way it faces, Switches the nearest Light in range (biased toward the way it
## faces), Tows Wreckage, and feeds its position and Dash to Traffic every tick. Grab, drop, the slower walk,
## getting hit and the stun are Traffic rules: while stunned it only drifts with Traffic's knockback.
## Its look is a cutout rig (#41): each tick it picks the view from its facing and the animation from what it is doing
## (Bonk, Dash, Switch, Tow, Walk, Idle, in that order), and poses the RaccoonRig.

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
const TARGET := Sign.ORANGE  # raccoon_orange: the Switch target is a Raccoon UI moment
const ROPE := Art.INK
const ROPE_CORE := Color("#C9CED8")
const COOLDOWN := Color(0.4, 0.8, 1.0)
const BONK := Sign.ORANGE  # raccoon_orange: its own moment, clear of the signal yellow
const BONK_SIZE := 22
const DUST_PUFFS := 2  # dust_puff: the smoke puff, small, kicked up behind a Dash

var traffic: Traffic
var facing := Vector2.UP
var target: Light  # the Light a Switch would hit now, or null
var cam_zoom := 1.0  # the camera zoom, which World sets each tick: speeds and ranges scale with 1/zoom
var pilot: Autopilot  # plays it in Attract (#34); null reads the player's input
var rig := RaccoonRig.new()
var stride := 0.0  # seconds of full-speed walking covered: the Walk and Tow clock, so its legs keep step with its speed

var _pressed := Intent.new()  # the buttons pressed since the last tick

var _dash_left := 0.0  # seconds left in the current Dash
var _dash_cooldown := 0.0  # seconds until the next Dash can start
var _dash_dir := Vector2.UP
var _switch_left := 0.0  # seconds left in the Switch animation
var _switch_dir := Vector2.UP  # toward the pole it Switched
var _idle_t := 0.0  # seconds it has stood idle


func _init(t: Traffic) -> void:
	traffic = t
	process_physics_priority = -1  # move and feed Traffic before World steps it
	rig.show_behind_parent = true  # under the rope, target and rings it draws
	add_child(rig)


## One tick of `delta` seconds. World steps it with Traffic, so a Crash's freeze holds both on the same ticks (#43).
func step(delta: float) -> void:
	var intent := _player_intent()  # read every tick, so presses made while the autopilot plays don't pile up
	if pilot != null:
		intent = pilot.decide(position, target, 1.0 / cam_zoom)
	act(intent, delta)


## One tick of `delta` seconds doing what `intent` asks.
func act(intent: Intent, delta: float) -> void:
	var world_per_px := 1.0 / cam_zoom  # world px per on-screen px
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_switch_left = maxf(_switch_left - delta, 0.0)
	var from := position
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
	if target != null and intent.switch:
		traffic.switch(target)
		_switch_left = RaccoonRig.SWITCH_TIME
		_switch_dir = target.pole - position
	stride += position.distance_to(from) / world_per_px / Tuning.RACCOON_SPEED
	_animate(position != from, dashing, delta)
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


## Poses the rig for what it did this tick: hit, Dashing, Switching, towing, walking or standing, first match wins.
## A Tow that didn't move this tick (towing in place) stands with both feet down; a stick pushed into the map edge
## doesn't move it, so it's Idle.
func _animate(moved: bool, dashing: bool, delta: float) -> void:
	var anim := RaccoonRig.Anim.IDLE
	var t := 0.0
	var dir := facing
	var view := view_of(facing)
	if traffic.raccoon_stun > 0.0:
		anim = RaccoonRig.Anim.BONK
		t = Tuning.STUN_TIME - traffic.raccoon_stun
	elif dashing:
		anim = RaccoonRig.Anim.DASH
		t = Tuning.DASH_TIME - _dash_left
		dir = _dash_dir
		view = view_of(_dash_dir)  # facing the Dash, even if the stick turns mid-Dash
	elif _switch_left > 0.0:
		anim = RaccoonRig.Anim.SWITCH
		t = RaccoonRig.SWITCH_TIME - _switch_left
		dir = _switch_dir
	elif traffic.towing != null:
		anim = RaccoonRig.Anim.TOW
		t = stride if moved else _stance()
		dir = position - traffic.towing.transform.origin  # away from the Wreckage
	elif moved:
		anim = RaccoonRig.Anim.WALK
		t = stride
	else:
		# Read before show_pose sets this tick's anim: a fresh Idle starts its breath from the top.
		_idle_t = _idle_t + delta if rig.anim == RaccoonRig.Anim.IDLE else 0.0
		t = _idle_t
	rig.zoom = cam_zoom
	rig.show_pose(view, anim, t, dir)


# The stride clock at the nearest point of the cycle where both feet are down: where a stopped Tow stands.
func _stance() -> float:
	var half := RaccoonRig.WALK_CYCLE / 2.0
	return roundf(stride / half) * half


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


## Over the rig: the rope from its shoulder, the Switch target, the Dash's dust and cooldown, and BONK! while stunned.
## They hold their size on screen past the floor zooms, like the rig (RACCOON_MIN_ZOOM) and the cues (CUE_MIN_ZOOM).
func _draw() -> void:
	var k := RaccoonRig.floor_scale(cam_zoom)
	var cue := Art.cue_scale(cam_zoom)
	if traffic.towing != null:
		var wreck := to_local(traffic.towing.transform.origin)
		var shoulder := rig.pivot_in_parent(&"arm_r")  # over the shoulder
		draw_line(shoulder, wreck, ROPE, 4.0 * k)
		draw_line(shoulder, wreck, ROPE_CORE, 1.5 * k)
	if target != null:
		var at := to_local(target.pole)
		draw_arc(at, 14.0 * cue, 0, TAU, 24, TARGET, 3.0 * cue)
		draw_dashed_line(Vector2.ZERO, at, Color(TARGET, 0.5), 2.0 * cue, 6.0 * cue)
	if rig.anim == RaccoonRig.Anim.DASH:
		_draw_dust(clampf(1.0 - _dash_left / Tuning.DASH_TIME, 0.0, 1.0), k)
	# Dash cooldown: a ring that fills back up; gone once a Dash is ready.
	if _dash_cooldown > 0.0:
		var filled := 1.0 - _dash_cooldown / Tuning.DASH_COOLDOWN
		draw_arc(Vector2.ZERO, (Tuning.RACCOON_R + 7.0) * k, -PI / 2.0, -PI / 2.0 + TAU * filled, 32, COOLDOWN, 3.0 * k)
	if traffic.raccoon_stun > 0.0:
		var font := Sign.FONT
		var size := roundi(BONK_SIZE * k)
		var w := font.get_string_size("BONK!", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var at := Vector2(-w / 2.0, (RaccoonRig.STAR_TOP - 10.0) * k)  # over its head and the stars
		draw_string_outline(font, at, "BONK!", HORIZONTAL_ALIGNMENT_LEFT, -1, size, roundi(5 * k), Art.INK)
		draw_string(font, at, "BONK!", HORIZONTAL_ALIGNMENT_LEFT, -1, size, BONK)


# A Dash `done` of the way through: dust kicked up behind its feet, and two speed lines.
func _draw_dust(done: float, k: float) -> void:
	var back := -_dash_dir.normalized()
	var across := back.orthogonal()
	for i in DUST_PUFFS:
		var w := (8.0 + 5.0 * i + 8.0 * done) * k
		var at := back * (10.0 + 10.0 * i + 12.0 * done) * k
		draw_texture_rect(Art.SMOKE_PUFF, Rect2(at - Vector2(w, w) / 2.0, Vector2(w, w)), false, Color(1, 1, 1, 0.85 * (1.0 - done)))
	for side: float in [-1.0, 1.0]:
		var from := (Vector2(0, -16) + back * 12.0 + across * side * 7.0) * k
		draw_line(from, from + back * 14.0 * k, Color(Color.WHITE, 1.0 - done), 2.0 * k)

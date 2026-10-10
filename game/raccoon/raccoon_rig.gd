class_name RaccoonRig
extends Node2D
## The Raccoon's cutout rig (#41, docs/sprites.md "Raccoon"): a part set for each view (front, back, and the side,
## mirrored for left), every part drawn on one shared canvas with the feet at the rig's origin, so a part at rest sits
## exactly where it did in the whole-sprite first pass (#39). pose_of says, for a view, an animation and how far into it,
## how each part turns about its pivot and lifts, and how the whole body moves about its feet; show_pose puts the parts
## there. The Raccoon picks the animation each tick. Nothing here decides a rule.

enum Anim { IDLE, WALK, DASH, SWITCH, TOW, BONK }

const CANVAS := Vector2(64, 84)  # texture px: every part of every view is drawn on this canvas...
const FEET := Vector2(32, 80)  # ...with the feet here, at the rig's origin
const CENTRE := Vector2(0, -19)  # world px: the middle of the body, which a Dash stretches and a Bonk spins about
const IDLE_CYCLE := 1.2  # seconds of one breath
const WALK_CYCLE := 0.4  # seconds of one stride at full walking speed: the Raccoon advances it by distance walked
const SWITCH_TIME := 0.25  # seconds of the Switch: the arm is up from the press, holds, then comes back down
const BLINK_EVERY := 3.0  # seconds between blinks while idle...
const BLINK_TIME := 0.12  # ...each this long
const REACH_SHOULDER := Vector2(12, 36)  # texture px of the shoulder in raccoon_arm_reach, which points up
const REACH_MAX := 1.1  # radians: the paw-open arm tilts toward the pole at most this far from straight up
const TOW_LEAN := 0.2  # radians the side view leans away from the Wreckage it tows
const STAR_ORBIT := Vector2(13, 4)  # world px: the Bonk stars circle the head on this ellipse...
const STAR_TOP := -38.0  # ...centred this far above the feet...
const STAR_HZ := 1.5  # ...this many times a second
const STAR_SIZE := 9.0  # world px across a star
const SHADOW_R := Vector2(12, 5)  # world px: the shadow ellipse under its feet

const REACH := preload("res://art/raccoon_arm_reach.svg")
const STAR := preload("res://art/raccoon_star.svg")

## Each view's parts in draw order: [name, texture, pivot in texture px]. The left view mirrors the side's.
const _PARTS := {
	Raccoon.View.FRONT: [
		[&"tail", preload("res://art/raccoon_front_tail.svg"), Vector2(44, 57)],
		[&"leg_l", preload("res://art/raccoon_front_leg_l.svg"), Vector2(25.5, 65)],
		[&"leg_r", preload("res://art/raccoon_front_leg_r.svg"), Vector2(38.5, 65)],
		[&"body", preload("res://art/raccoon_front_body.svg"), Vector2(32, 68)],
		[&"arm_l", preload("res://art/raccoon_front_arm_l.svg"), Vector2(16, 48)],
		[&"arm_r", preload("res://art/raccoon_front_arm_r.svg"), Vector2(48, 48)],
		[&"head", preload("res://art/raccoon_front_head.svg"), Vector2(32, 42)],
		[&"blink", preload("res://art/raccoon_front_blink.svg"), Vector2(32, 42)],
	],
	Raccoon.View.BACK: [
		[&"leg_l", preload("res://art/raccoon_back_leg_l.svg"), Vector2(25.5, 65)],
		[&"leg_r", preload("res://art/raccoon_back_leg_r.svg"), Vector2(38.5, 65)],
		[&"body", preload("res://art/raccoon_back_body.svg"), Vector2(32, 68)],
		[&"arm_l", preload("res://art/raccoon_back_arm_l.svg"), Vector2(16, 48)],
		[&"arm_r", preload("res://art/raccoon_back_arm_r.svg"), Vector2(48, 48)],
		[&"head", preload("res://art/raccoon_back_head.svg"), Vector2(32, 42)],
		[&"tail", preload("res://art/raccoon_back_tail.svg"), Vector2(40, 64)],
	],
	Raccoon.View.RIGHT: [
		[&"tail", preload("res://art/raccoon_side_tail.svg"), Vector2(21, 53)],
		[&"leg_l", preload("res://art/raccoon_side_leg_l.svg"), Vector2(22.5, 65)],  # the far leg
		[&"body", preload("res://art/raccoon_side_body.svg"), Vector2(30, 68)],
		[&"leg_r", preload("res://art/raccoon_side_leg_r.svg"), Vector2(35.5, 65)],  # the near leg
		[&"arm_r", preload("res://art/raccoon_side_arm_r.svg"), Vector2(34, 48)],  # its one arm
		[&"head", preload("res://art/raccoon_side_head.svg"), Vector2(30, 42)],
		[&"blink", preload("res://art/raccoon_side_blink.svg"), Vector2(30, 42)],
	],
}


## How the parts sit at one moment of an animation, in the rig's own axes (the side view faces right).
class Pose:
	var whole := Transform2D.IDENTITY  # the whole body's move, world px about the feet
	var turn := {}  # part → radians about its pivot
	var lift := {}  # part → world px it shifts
	var reach := &""  # the arm the paw-open arm stands in for, or none
	var reach_turn := 0.0  # radians the paw-open arm tilts from straight up
	var eyes_shut := false
	var stars := false


var view := Raccoon.View.FRONT
var skin := Skins.GUARD  # change it with set_skin()
var anim := Anim.IDLE
var zoom := 1.0  # the camera's: past Tuning.RACCOON_MIN_ZOOM the rig grows to hold its size on screen
var stars := Node2D.new()  # the Bonk stars, circling the head

var _pose := Node2D.new()  # the whole body: Dash stretch, Bonk spin and squash, Tow lean
var _sets := {}  # view (FRONT, BACK, RIGHT) → its parts' Node2D
var _parts := {}  # view → {part → Sprite2D}, with &"reach" for the paw-open arm
var _rest := {}  # view → {part → its rest position}
var _star_t := 0.0
var _shadow := Node2D.new()


func _init() -> void:
	_shadow.name = "Shadow"
	_shadow.z_as_relative = false
	_shadow.z_index = Art.Z_SHADOW
	_shadow.draw.connect(func() -> void:
		_shadow.draw_set_transform(Vector2.ZERO, 0.0, SHADOW_R / SHADOW_R.x)
		_shadow.draw_circle(Vector2.ZERO, SHADOW_R.x, Art.SHADOW))
	add_child(_shadow)
	add_child(_pose)
	for v: Raccoon.View in _PARTS:
		var group := Node2D.new()
		var parts := {}
		var rest := {}
		for p: Array in _PARTS[v]:
			if p[0] == &"head":  # the paw-open arm goes up in front of the body, behind the head
				var reach := _part(REACH, REACH_SHOULDER)
				reach.visible = false
				group.add_child(reach)
				parts[&"reach"] = reach
			var s := _part(p[1], p[2])
			group.add_child(s)
			parts[p[0]] = s
			rest[p[0]] = s.position
		group.visible = false
		_pose.add_child(group)
		_sets[v] = group
		_parts[v] = parts
		_rest[v] = rest
	stars.draw.connect(_draw_stars)
	add_child(stars)
	show_pose(view, anim, 0.0)


# A part's sprite, turning about `pivot` (texture px), placed so the canvas's FEET land on the rig's origin.
func _part(tex: Texture2D, pivot: Vector2) -> Sprite2D:
	var s := Art.sprite(tex)
	s.offset = tex.get_size() / 2.0 - pivot
	s.position = (pivot - FEET) * Art.SCALE
	return s


## Wear `s` (#45): every part of every view, and the paw-open arm, swap to its textures.
func set_skin(s: StringName) -> void:
	skin = s
	for v: Raccoon.View in _PARTS:
		for p: Array in _PARTS[v]:
			(_parts[v][p[0]] as Sprite2D).texture = Skins.texture(p[1], s)
		(_parts[v][&"reach"] as Sprite2D).texture = Skins.texture(REACH, s)


## The part names of a view, in draw order.
static func parts_of(v: Raccoon.View) -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Array in _PARTS[_set_of(v)]:
		out.append(p[0])
	return out


## The texture of a view's part, or null if the view has no such part.
static func texture_of(v: Raccoon.View, part: StringName) -> Texture2D:
	for p: Array in _PARTS[_set_of(v)]:
		if p[0] == part:
			return p[1]
	return null


static func _set_of(v: Raccoon.View) -> Raccoon.View:
	return Raccoon.View.RIGHT if v == Raccoon.View.LEFT else v


## The rig's scale at a camera zoom: world size down to Tuning.RACCOON_MIN_ZOOM, then growing to hold its size on screen.
static func floor_scale(z: float) -> float:
	return Art.floor_scale(z, Tuning.RACCOON_MIN_ZOOM)


## Shows view `v` posed `t` seconds into `a` (for Walk and Tow, `t` is the stride clock); `dir` is the way it Dashes, toward the
## pole it Switches, or away from the Wreckage it Tows.
func show_pose(v: Raccoon.View, a: Anim, t: float, dir := Vector2.ZERO) -> void:
	view = v
	anim = a
	var k := floor_scale(zoom)
	scale = Vector2(-k if v == Raccoon.View.LEFT else k, k)
	_shadow.position = Art.SHADOW_FALL / scale  # down-right on screen, mirrored or not
	var shown := _set_of(v)
	for s: Raccoon.View in _sets:
		_sets[s].visible = s == shown
	var p := pose_of(v, a, t, dir)
	_pose.transform = p.whole
	var parts: Dictionary = _parts[shown]
	var rest: Dictionary = _rest[shown]
	for part_name: StringName in rest:
		var like := &"head" if part_name == &"blink" else part_name  # the eyelids move with the head
		var s: Sprite2D = parts[part_name]
		s.rotation = p.turn.get(like, 0.0)
		s.position = rest[part_name] + p.lift.get(like, Vector2.ZERO)
		s.visible = part_name != p.reach
	if parts.has(&"blink"):
		parts[&"blink"].visible = p.eyes_shut
	var reach: Sprite2D = parts[&"reach"]
	reach.visible = p.reach != &""
	if reach.visible:
		reach.position = rest[p.reach] + p.lift.get(p.reach, Vector2.ZERO)
		reach.rotation = p.reach_turn
	stars.visible = p.stars
	stars.position = p.whole * Vector2(0.0, STAR_TOP)
	_star_t = t
	stars.queue_redraw()


## The sprite showing a part of the current view (&"reach" is the paw-open arm), or null.
func part(part_name: StringName) -> Sprite2D:
	return _parts[_set_of(view)].get(part_name)


## Whether the current view has this part (the paw-open arm doesn't count).
func has_part(part_name: StringName) -> bool:
	return _parts[_set_of(view)].has(part_name) and part_name != &"reach"


## Where texture px `tex_px` of a part's canvas is now, in the rig's own axes (before its scale and mirror).
func point_of(part_name: StringName, tex_px: Vector2) -> Vector2:
	var s := part(part_name)
	return _pose.transform * (s.transform * (s.offset + tex_px - s.texture.get_size() / 2.0))


## Where a part's pivot is now, in the rig's parent's axes: the rope leaves the shoulder.
func pivot_in_parent(part_name: StringName) -> Vector2:
	var s := part(part_name)
	return transform * (_pose.transform * s.position)


# --- the poses --------------------------------------------------------------------

## How the parts sit `t` seconds into animation `a` (the stride clock for Walk and Tow), in the rig's own axes;
## `dir` is on screen, and is mirrored here for the left view.
static func pose_of(v: Raccoon.View, a: Anim, t: float, dir := Vector2.ZERO) -> Pose:
	var p := Pose.new()
	var side := _set_of(v) == Raccoon.View.RIGHT
	var d := Vector2(-dir.x, dir.y) if v == Raccoon.View.LEFT else dir
	match a:
		Anim.IDLE:
			_idle(p, t)
		Anim.WALK:
			_walk(p, side, t, 1.0)
		Anim.TOW:
			_tow(p, side, t, d)
		Anim.DASH:
			_dash(p, t, d)
		Anim.SWITCH:
			_switch(p, side, t, d)
		Anim.BONK:
			_bonk(p, t)
	return p


# Breathing: the body rises and settles, the head a touch more, the tail sways; a blink every few seconds.
static func _idle(p: Pose, t: float) -> void:
	var ph := TAU * fmod(t, IDLE_CYCLE) / IDLE_CYCLE
	var breath := Vector2(0.0, -0.5 * (1.0 - cos(ph)))  # 0 to -1 world px
	p.lift[&"body"] = breath * 0.6
	p.lift[&"arm_l"] = breath * 0.8
	p.lift[&"arm_r"] = breath * 0.8
	p.lift[&"head"] = breath
	p.turn[&"tail"] = 0.12 * sin(ph)
	p.eyes_shut = fmod(t, BLINK_EVERY) >= BLINK_EVERY - BLINK_TIME


# A two-beat stride: the body bobs on each step; from the side the legs swing apart and the arm swings against the
# near leg, from the front or back each leg steps up in turn and the arms lift against it. `heavy` deepens the bob.
static func _walk(p: Pose, side: bool, t: float, heavy: float) -> void:
	var ph := TAU * fmod(t, WALK_CYCLE) / WALK_CYCLE
	var s := sin(ph)
	var bob := Vector2(0.0, -heavy * absf(s))
	p.lift[&"body"] = bob
	p.lift[&"head"] = bob * 1.15
	p.lift[&"tail"] = bob
	if side:
		p.lift[&"arm_r"] = bob
		p.turn[&"leg_l"] = 0.5 * s
		p.turn[&"leg_r"] = -0.5 * s
		p.turn[&"arm_r"] = 0.6 * s
		p.turn[&"tail"] = 0.15 + 0.12 * sin(2.0 * ph)  # trailing, flicking on each step
	else:
		p.lift[&"leg_l"] = Vector2(0.0, -2.5 * maxf(s, 0.0))
		p.lift[&"leg_r"] = Vector2(0.0, -2.5 * maxf(-s, 0.0))
		p.lift[&"arm_l"] = bob + Vector2(0.0, -1.2 * maxf(-s, 0.0))
		p.lift[&"arm_r"] = bob + Vector2(0.0, -1.2 * maxf(s, 0.0))
		p.turn[&"tail"] = 0.15 * s


# A heavy walk, leaning away from the Wreckage (`away` points from it to the Raccoon), with an arm up over the
# shoulder holding the rope.
static func _tow(p: Pose, side: bool, t: float, away: Vector2) -> void:
	_walk(p, side, t, 1.6)
	if side:
		p.whole = Transform2D(TOW_LEAN * clampf(away.normalized().x * 2.0, -1.0, 1.0), Vector2.ZERO)  # pulling away
		p.turn[&"arm_r"] = 2.4  # back over the shoulder
	else:
		p.whole = Transform2D(0.0, Vector2(1.04, 0.94), 0.0, Vector2.ZERO)  # hunched into the pull
		p.turn[&"arm_r"] = -2.4


# A squash against the move, then a stretch along it, easing back, with the legs tucked.
static func _dash(p: Pose, t: float, d: Vector2) -> void:
	var k := clampf(t / Tuning.DASH_TIME, 0.0, 1.0)
	var along: float
	var across: float
	if k < 0.25:
		var e := sin(k / 0.25 * PI / 2.0)
		along = lerpf(1.0, 0.78, e)
		across = lerpf(1.0, 1.12, e)
	else:
		var e := (k - 0.25) / 0.75
		along = lerpf(1.35, 1.0, e * e)
		across = lerpf(0.82, 1.0, e * e)
	var a := d.angle() if d != Vector2.ZERO else 0.0
	var m := Transform2D(a, Vector2.ZERO) * Transform2D(0.0, Vector2(along, across), 0.0, Vector2.ZERO) * Transform2D(-a, Vector2.ZERO)
	p.whole = _about(CENTRE, m)
	p.lift[&"leg_l"] = Vector2(0.0, -3.0)
	p.lift[&"leg_r"] = Vector2(0.0, -3.0)
	p.lift[&"arm_l"] = Vector2(0.0, -1.0)
	p.lift[&"arm_r"] = Vector2(0.0, -1.0)


# The paw-open arm snaps up toward the pole on the press (the stop line changes then), holds, and comes back down,
# while the head tilts up to look.
static func _switch(p: Pose, side: bool, t: float, d: Vector2) -> void:
	var k := clampf(t / SWITCH_TIME, 0.0, 1.0)
	var up := 1.0 if k < 0.6 else 1.0 - (k - 0.6) / 0.4
	if k < 0.8:
		p.reach = &"arm_r" if side or d.x >= 0.0 else &"arm_l"
		p.reach_turn = clampf(atan2(d.x, -d.y), -REACH_MAX, REACH_MAX) if d != Vector2.ZERO else 0.0
	p.lift[&"head"] = Vector2(0.0, -1.5 * up)
	p.turn[&"head"] = (-0.25 if side else 0.12 * signf(d.x)) * up
	p.whole = Transform2D(0.0, Vector2(1.0, 1.0 + 0.05 * up), 0.0, Vector2.ZERO)  # up on its toes


# Knocked flat: one spin, squashed flat with its eyes shut and stars circling, then a pop back up as the stun ends.
static func _bonk(p: Pose, t: float) -> void:
	var k := clampf(t / Tuning.STUN_TIME, 0.0, 1.0)
	if k < 0.35:
		var e := k / 0.35
		p.whole = _about(CENTRE, Transform2D(TAU * (1.0 - (1.0 - e) * (1.0 - e)), Vector2.ZERO))
	else:
		var sq := Vector2(1.3, 0.55)
		if k < 0.42:
			sq = Vector2.ONE.lerp(sq, (k - 0.35) / 0.07)
		elif k >= 0.85:
			var e := (k - 0.85) / 0.15
			sq = sq.lerp(Vector2(0.9, 1.15), e / 0.6) if e < 0.6 else Vector2(0.9, 1.15).lerp(Vector2.ONE, (e - 0.6) / 0.4)
		p.whole = Transform2D(0.0, sq, 0.0, Vector2.ZERO)  # about the feet: it stays on the ground
	p.stars = k > 0.2 and k < 1.0
	p.eyes_shut = p.stars


static func _about(at: Vector2, m: Transform2D) -> Transform2D:
	return Transform2D(0.0, at) * m * Transform2D(0.0, -at)


func _draw_stars() -> void:
	for i in 3:
		var a := TAU * (_star_t * STAR_HZ + i / 3.0)
		var at := Vector2(cos(a), sin(a)) * STAR_ORBIT
		stars.draw_texture_rect(STAR, Rect2(at - Vector2.ONE * STAR_SIZE / 2.0, Vector2.ONE * STAR_SIZE), false)

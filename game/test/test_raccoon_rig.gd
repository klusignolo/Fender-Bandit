extends TestCase
## The Raccoon's cutout rig (#41, docs/sprites.md "Raccoon"): part sets for the front, back and side views, posed by
## RaccoonRig.pose_of for the six animations, and the Raccoon picking the animation and facing each tick.

const V := Raccoon.View
const A := RaccoonRig.Anim
const VIEWS: Array[Raccoon.View] = [V.FRONT, V.BACK, V.RIGHT, V.LEFT]


func _scale_along(m: Transform2D, d: Vector2) -> float:
	return m.basis_xform(d.normalized()).length()


# --- the parts --------------------------------------------------------------------

func test_every_view_has_its_parts_on_one_canvas() -> void:
	var want := {V.FRONT: 8, V.BACK: 7, V.RIGHT: 7, V.LEFT: 7}
	for v: Raccoon.View in VIEWS:
		var parts := RaccoonRig.parts_of(v)
		check_eq(parts.size(), want[v], "view %d's part count" % v)
		for p: StringName in parts:
			var tex := RaccoonRig.texture_of(v, p)
			if check(tex != null, "view %d has its %s" % [v, p]):
				check_eq(tex.get_size(), RaccoonRig.CANVAS, "view %d %s is drawn on the shared canvas" % [v, p])
	check(RaccoonRig.parts_of(V.FRONT).has(&"blink"), "the front can blink")
	check(RaccoonRig.parts_of(V.RIGHT).has(&"blink"), "so can the side")
	check(not RaccoonRig.parts_of(V.BACK).has(&"blink"), "the back has no face")


func test_at_rest_every_part_stands_on_the_feet() -> void:
	var rig := RaccoonRig.new()
	for v: Raccoon.View in VIEWS:
		rig.show_pose(v, A.IDLE, 0.0)
		for p: StringName in RaccoonRig.parts_of(v):
			var at := rig.point_of(p, RaccoonRig.FEET)
			check(at.length() < 1.5, "view %d: %s's canvas has its feet at the rig's origin: %s" % [v, p, at])
	rig.free()


func test_the_side_view_mirrors_for_left() -> void:
	var rig := RaccoonRig.new()
	rig.show_pose(V.RIGHT, A.IDLE, 0.0)
	check(rig.scale.x > 0.0, "facing right: as drawn")
	rig.show_pose(V.LEFT, A.IDLE, 0.0)
	check(rig.scale.x < 0.0, "facing left: mirrored")
	check_eq(rig.part(&"head").texture, RaccoonRig.texture_of(V.RIGHT, &"head"), "with the side's parts")
	check_eq(rig.scale.y, absf(rig.scale.x), "mirrored, not squashed")
	rig.show_pose(V.BACK, A.IDLE, 0.0)
	check(rig.scale.x > 0.0, "the back isn't mirrored")
	check(not rig.has_part(&"blink"), "and shows no blink")
	rig.free()


func test_it_keeps_a_floor_size_as_the_camera_zooms_out() -> void:
	check_eq(RaccoonRig.floor_scale(1.0), 1.0, "at 1× it's drawn at world size")
	check_eq(RaccoonRig.floor_scale(Tuning.RACCOON_MIN_ZOOM), 1.0, "down to its floor zoom")
	check_near(RaccoonRig.floor_scale(Tuning.READ_FLOOR), Tuning.RACCOON_MIN_ZOOM / Tuning.READ_FLOOR, 0.001,
			"past it, it grows to hold its on-screen size")
	var rig := RaccoonRig.new()
	rig.zoom = Tuning.READ_FLOOR
	rig.show_pose(V.LEFT, A.IDLE, 0.0)
	check_near(rig.scale.y, RaccoonRig.floor_scale(Tuning.READ_FLOOR), 0.001, "the rig holds it")
	check_near(rig.scale.x, -rig.scale.y, 0.001, "still mirrored")
	rig.free()


# --- the six animations -----------------------------------------------------------

func test_idle_breathes_in_a_loop_and_blinks_now_and_then() -> void:
	var a := RaccoonRig.pose_of(V.FRONT, A.IDLE, 0.0)
	var b := RaccoonRig.pose_of(V.FRONT, A.IDLE, RaccoonRig.IDLE_CYCLE)
	check((b.lift.get(&"body") as Vector2).distance_to(a.lift.get(&"body")) < 0.0001, "it loops every %.1fs" % RaccoonRig.IDLE_CYCLE)
	var low := RaccoonRig.pose_of(V.FRONT, A.IDLE, RaccoonRig.IDLE_CYCLE / 4.0)
	check(low.lift.get(&"body", Vector2.ZERO) != a.lift.get(&"body", Vector2.ZERO), "the body bobs")
	check(low.turn.get(&"tail", 0.0) != a.turn.get(&"tail", 0.0), "the tail sways")
	var shut := 0
	var samples := 600
	for i in samples:
		var t := RaccoonRig.BLINK_EVERY * 2.0 * i / samples
		if RaccoonRig.pose_of(V.FRONT, A.IDLE, t).eyes_shut:
			shut += 1
	check(shut > 0, "it blinks")
	check(shut < samples / 10, "but its eyes are mostly open: shut %d of %d" % [shut, samples])


func test_walk_swings_the_legs_in_turn() -> void:
	var q := RaccoonRig.WALK_CYCLE / 4.0
	var one := RaccoonRig.pose_of(V.FRONT, A.WALK, q)
	var two := RaccoonRig.pose_of(V.FRONT, A.WALK, 3.0 * q)
	check(one.lift.get(&"leg_l", Vector2.ZERO).y < -1.0, "front: the left leg steps up first")
	check(one.lift.get(&"leg_r", Vector2.ZERO).y > -0.5, "while the right stays down")
	check(two.lift.get(&"leg_r", Vector2.ZERO).y < -1.0, "then the right")
	var side := RaccoonRig.pose_of(V.RIGHT, A.WALK, q)
	check(side.turn.get(&"leg_l", 0.0) * side.turn.get(&"leg_r", 0.0) < 0.0, "side: the legs swing apart")
	check(side.turn.get(&"arm_r", 0.0) != 0.0, "and the arm swings")
	var again := RaccoonRig.pose_of(V.RIGHT, A.WALK, q + RaccoonRig.WALK_CYCLE)
	check_near(again.turn.get(&"leg_l"), side.turn.get(&"leg_l"), 0.0001, "a walk cycle loops")


func test_dash_squashes_then_stretches_along_the_move() -> void:
	for d: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2(1, 1)]:
		var v := Raccoon.view_of(d)
		var squash := RaccoonRig.pose_of(v, A.DASH, Tuning.DASH_TIME * 0.1, d)
		var stretch := RaccoonRig.pose_of(v, A.DASH, Tuning.DASH_TIME * 0.5, d)
		check(_scale_along(squash.whole, d) < 0.95, "%s: squashed along the move first" % d)
		check(_scale_along(stretch.whole, d) > 1.15, "%s: then stretched along it" % d)
		check(_scale_along(stretch.whole, d.orthogonal()) < 0.95, "%s: and thinned across it" % d)
		check(stretch.lift.get(&"leg_l", Vector2.ZERO).y < -1.0, "%s: legs tucked" % d)
	# The left view is mirrored by the rig, so its pose stretches along the mirrored move: still the move on screen.
	var left := RaccoonRig.pose_of(V.LEFT, A.DASH, Tuning.DASH_TIME * 0.5, Vector2(-1, 1))
	check(_scale_along(left.whole, Vector2(1, 1)) > 1.15, "left: stretched along the mirrored move")


func test_switch_snaps_an_arm_up_toward_the_pole_then_comes_back_down() -> void:
	var peak := RaccoonRig.pose_of(V.FRONT, A.SWITCH, 0.0, Vector2(1, -1))
	check_eq(peak.reach, &"arm_r", "front, pole up-right: the right arm reaches")
	check(peak.lift.get(&"head", Vector2.ZERO).y < 0.0, "the head tilts up")
	var up := Vector2.UP.rotated(peak.reach_turn)
	check(up.x > 0.2 and up.y < -0.5, "the paw points up toward the pole: %s" % up)
	check_eq(RaccoonRig.pose_of(V.FRONT, A.SWITCH, 0.0, Vector2(-1, -1)).reach, &"arm_l", "pole up-left: the left arm")
	check_eq(RaccoonRig.pose_of(V.BACK, A.SWITCH, 0.0, Vector2(1, -1)).reach, &"arm_r", "the back: the arm on the pole's side of the screen")
	check_eq(RaccoonRig.pose_of(V.RIGHT, A.SWITCH, 0.0, Vector2(-1, 0)).reach, &"arm_r", "the side: its one arm")
	check_eq(RaccoonRig.pose_of(V.FRONT, A.SWITCH, RaccoonRig.SWITCH_TIME, Vector2(1, -1)).reach, &"", "back down at the end")
	var rig := RaccoonRig.new()
	rig.show_pose(V.FRONT, A.SWITCH, 0.0, Vector2(1, -1))
	check(rig.part(&"reach").visible and not rig.part(&"arm_r").visible, "the paw-open arm swaps in")
	rig.show_pose(V.FRONT, A.IDLE, 0.0)
	check(not rig.part(&"reach").visible and rig.part(&"arm_r").visible, "and out again")
	rig.free()


func test_tow_leans_into_a_heavy_walk() -> void:
	var q := RaccoonRig.WALK_CYCLE / 4.0
	var tow := RaccoonRig.pose_of(V.RIGHT, A.TOW, q, Vector2.RIGHT)
	check(tow.whole.basis_xform(Vector2.UP).x > 0.1, "side: leans forward, away from the Wreckage behind")
	check(tow.turn.get(&"leg_l", 0.0) != 0.0, "and walks")
	var back := RaccoonRig.pose_of(V.RIGHT, A.TOW, q, Vector2.LEFT)
	check(back.whole.basis_xform(Vector2.UP).x < -0.1, "walking toward the Wreckage, it still leans away from it")
	var walk := RaccoonRig.pose_of(V.FRONT, A.WALK, q)
	var heavy := RaccoonRig.pose_of(V.FRONT, A.TOW, q, Vector2.DOWN)
	check(heavy.lift.get(&"body", Vector2.ZERO).y < walk.lift.get(&"body", Vector2.ZERO).y, "a heavier bob than a walk")
	check(heavy.turn.get(&"arm_r", 0.0) < -1.5, "an arm up over the shoulder, holding the rope")


func test_bonk_spins_once_squashes_flat_with_stars_and_pops_up() -> void:
	var stun := Tuning.STUN_TIME
	var start := RaccoonRig.pose_of(V.FRONT, A.BONK, 0.0)
	check_near(start.whole.get_rotation(), 0.0, 0.01, "it starts upright")
	var spun := false
	for i in 20:
		var p := RaccoonRig.pose_of(V.FRONT, A.BONK, stun * 0.35 * i / 20.0)
		spun = spun or absf(p.whole.get_rotation()) > 2.0
	check(spun, "it spins")
	var flat := RaccoonRig.pose_of(V.FRONT, A.BONK, stun * 0.6)
	check(_scale_along(flat.whole, Vector2.UP) < 0.7, "squashed flat")
	check(flat.whole * Vector2.ZERO == Vector2.ZERO, "onto its feet")
	check(flat.stars and flat.eyes_shut, "seeing stars, eyes shut")
	var end := RaccoonRig.pose_of(V.FRONT, A.BONK, stun)
	check(end.whole.is_equal_approx(Transform2D.IDENTITY), "popped back up by the end of the stun: %s" % end.whole)
	var rig := RaccoonRig.new()
	rig.show_pose(V.FRONT, A.BONK, stun * 0.6)
	check(rig.stars.visible, "the stars show")
	rig.show_pose(V.FRONT, A.IDLE, 0.0)
	check(not rig.stars.visible, "and go")
	rig.free()


# --- the Raccoon plays them -------------------------------------------------------

func _intent(move := Vector2.ZERO) -> Raccoon.Intent:
	var i := Raccoon.Intent.new()
	i.move = move
	return i


func _act(r: Raccoon, i: Raccoon.Intent, seconds := Traffic.DT) -> void:
	for n in maxi(roundi(seconds * Traffic.TICK_HZ), 1):
		r.act(i, Traffic.DT)
		i = _intent(i.move)  # a press lasts one tick


func test_the_raccoon_plays_each_animation_with_the_right_facing() -> void:
	var t := straight_traffic(3)
	var r := Raccoon.new(t)
	r.position = t.lights[0].pole + Vector2(40, 40)
	_act(r, _intent(), 0.1)
	check_eq(r.rig.anim, A.IDLE, "standing: Idle")
	var light := r.target
	if check(light != null, "a pole in range"):
		var was := light.state
		var sw := _intent()
		sw.switch = true
		_act(r, sw)
		check_eq(r.rig.anim, A.SWITCH, "Switching: Switch")
		check(light.state != was, "the stop line changes as the arm is up")
		_act(r, _intent(), RaccoonRig.SWITCH_TIME + 0.05)
		check_eq(r.rig.anim, A.IDLE, "and back to Idle")
	_act(r, _intent(Vector2.RIGHT), 0.2)
	check_eq([r.rig.anim, r.rig.view], [A.WALK, V.RIGHT], "walking right: Walk, the side view")
	check(r.rig.scale.x > 0.0, "as drawn")
	_act(r, _intent(Vector2.LEFT), 0.2)
	check_eq([r.rig.anim, r.rig.view], [A.WALK, V.LEFT], "walking left")
	check(r.rig.scale.x < 0.0, "mirrored")
	_act(r, _intent(), 0.1)
	check_eq([r.rig.anim, r.rig.view], [A.IDLE, V.LEFT], "stopping: Idle, still facing left")
	var dash := _intent(Vector2.DOWN)
	dash.dash = true
	_act(r, dash)
	check_eq([r.rig.anim, r.rig.view], [A.DASH, V.FRONT], "Dashing down: Dash, the front")
	_act(r, _intent(Vector2.DOWN), Tuning.DASH_TIME + 0.05)
	check_eq(r.rig.anim, A.WALK, "then back to a walk")
	_act(r, _intent(), 0.1)
	t.towing = Car.new(500, t.net.approaches[0].routes[0], t.lights[0])
	_act(r, _intent(Vector2.UP), 0.2)
	check_eq([r.rig.anim, r.rig.view], [A.TOW, V.BACK], "towing up: Tow, the back")
	t.towing = null
	t.raccoon_stun = Tuning.STUN_TIME
	_act(r, _intent(Vector2.RIGHT))
	check_eq([r.rig.anim, r.rig.view], [A.BONK, V.BACK], "hit: Bonk, keeping its facing")
	t.raccoon_stun = 0.0
	_act(r, _intent())
	check_eq(r.rig.anim, A.IDLE, "recovered: Idle")
	r.free()


func test_a_dash_keeps_its_facing_and_a_stopped_tow_stands_on_both_feet() -> void:
	var t := straight_traffic(3)
	var r := Raccoon.new(t)
	r.position = t.lights[0].pole + Vector2(60, 60)
	var dash := _intent(Vector2.RIGHT)
	dash.dash = true
	_act(r, dash)
	_act(r, _intent(Vector2.UP), 0.05)
	check_eq([r.rig.anim, r.rig.view], [A.DASH, V.RIGHT], "the stick turning mid-Dash doesn't turn the Dash")
	_act(r, _intent(), Tuning.DASH_TIME)
	t.towing = Car.new(500, t.net.approaches[0].routes[0], t.lights[0])
	t.towing.transform = Transform2D(0.0, r.position + Vector2(-20, 0))
	_act(r, _intent(Vector2.RIGHT), RaccoonRig.WALK_CYCLE * 0.3)  # stopping mid-stride
	_act(r, _intent())
	check_eq(r.rig.anim, A.TOW, "towing in place is still a Tow")
	check_near(r.rig.part(&"leg_l").rotation, 0.0, 0.01, "with the far leg down")
	check_near(r.rig.part(&"leg_r").rotation, 0.0, 0.01, "and the near leg")
	t.towing = null
	r.free()


func test_the_walk_keeps_step_with_the_raccoons_speed() -> void:
	var t := straight_traffic(3)
	var r := Raccoon.new(t)
	r.position = t.lights[0].pole + Vector2(60, 60)
	_act(r, _intent(Vector2.RIGHT), RaccoonRig.WALK_CYCLE)
	check_near(r.stride, RaccoonRig.WALK_CYCLE, 0.02, "full speed for one cycle: one stride")
	r.cam_zoom = 0.5
	var s := r.stride
	_act(r, _intent(Vector2.RIGHT), RaccoonRig.WALK_CYCLE)
	check_near(r.stride - s, RaccoonRig.WALK_CYCLE, 0.02, "zoomed out it covers more world, at the same on-screen pace")
	r.free()

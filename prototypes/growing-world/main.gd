# PROTOTYPE, throw away: greybox for "Does the growing world with a Jam meter feel fun?" (issue #16).
# Forked from prototypes/crossing-guard (#5, #9, #14) and generalised from one crossing to several
# linked ones. Defaults baked in from earlier playtests: own-Arrow turn lanes with RB, Swells +
# Platoons, front-car-only Patience that only Honks. The world draws in _draw(); the HUD draws on
# a CanvasLayer so it stays put while the camera zooms. No polish, no tests.
extends Node2D

const SW := 1280.0          # screen size
const SH := 720.0
const LINK := 720.0         # centre-to-centre distance between linked crossings
const ARM_X := 640.0        # entry arm length (centre to map edge), horizontal
const ARM_Y := 360.0        # ...vertical; grows to fill the frame's aspect
const FIT := 1.03           # zoom a touch past "fits everything", so the map edges bleed off
const DRIFT := 0.08         # how far the camera leans toward the Raccoon
const SIX_ZOOM := 0.45      # the scale six crossings would need (#6), for a legibility check
const REVEAL_TIME := 2.5
const DRAIN_MAX := 12.0     # the drain gives up and sweeps the roads after this long
const TURN_CHANCE := 0.35   # a car arriving over a link picks the turn lane this often
const MERGE_SPEED := 60.0   # lateral px/s while changing lanes on a link

const LW := 30.0            # lane width; each road is 4 lanes: out, out | turn, through
const ROAD := 120.0
const STOP_D := 72.0
const TURN_SHARE := 0.45
const TURN_SPEED := 0.7
const CAR_L := 38.0
const CAR_W := 20.0
const LOOK := 220.0
const BASE_SPEED := 150.0
const GO_BOOST := 1.45
const ACCEL := 260.0
const DECEL := 420.0
const RACCOON_R := 14.0
const RACCOON_SPEED := 230.0  # on-screen px/s: world speed scales with 1/zoom
const DASH_SPEED := 640.0
const DASH_TIME := 0.18
const DASH_CD := 0.9
const SIGNAL_RANGE := 160.0   # on screen, too
const TOW_RANGE := 30.0
const YELLOW_TIME := 1.5
const PATIENCE_RINGS := 3
const PATIENCE_MIN := 12.0
const PATIENCE_MAX := 15.0

const SWELL_HEAVY := 2.0
const SWELL_LIGHT := 0.67
const SWELL_MIN := 20.0
const SWELL_MAX := 30.0
const SHIFT_WARN := 4.0
const BURST_MIN := 8.0
const BURST_MAX := 14.0
const BURST_WARN := 2.0
const BURST_GAP := 0.5
const BURST_TURN := 0.3

# The Jam (#15): one meter for the whole city. Starting numbers, all to tune.
const JAM_CAP := 100.0
const DENT := 2.0                    # capacity each Crash takes away for good
const JAM_HONK := [0.0, 0.5, 1.0]    # per second, per metered car, by Honks so far
const JAM_BACKLOG := 0.6             # per second, per car waiting to get onto the map
const JAM_DRAIN := 1.5               # per second, always
const JAM_EXIT := 0.4                # per car that leaves the map
const EDGE_TIME := 8.0               # old rule: an entry backed up this long ends the Run
const LEVEL_NAMES := ["CLEAR", "BUSY", "HEAVY", "GRIDLOCK"]

# Sides of a crossing, and the way cars on that side's incoming lanes travel.
const SIDE_NAMES := ["N", "S", "W", "E"]
const SIDE_DIR := [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]
const X_NAMES := ["A", "B", "C", "D", "E", "F"]

enum Phase { PLAY, DRAIN, REVEAL, OVER }
enum End { JAM, EDGE }

class Crossing:
	var c: Vector2
	var link := [-1, -1, -1, -1]  # per side: the crossing that road leads to, or -1 for a map entry

# One incoming lane. Index = crossing * 8 + side * 2 + (1 if turn lane); twin = index ^ 1.
class Approach:
	var label: String
	var x: int
	var dir: Vector2
	var spawn: Vector2
	var stop_point: Vector2
	var lamp: Vector2
	var turn := false
	var entry := false      # fed from the map edge, not from another crossing
	var go := false
	var yellow_t := 0.0
	var spawn_t := 0.0
	var backlog := 0        # cars that want in but the road is full
	var edge_t := 0.0       # how long the backlog has been stuck (old edge rule)
	var jam := 0.0          # this lane's Jam fill this frame, for the Heavy pulse

class Car:
	var ap: int
	var pos: Vector2
	var dir: Vector2
	var speed := 0.0
	var color: Color
	var wait := 0.0
	var patience := 10.0
	var honks := 0
	var boosted := false
	var passed_line := false
	var wreck := false
	var wreck_rot := 0.0
	var towed := false
	var turn := false
	var arc_s := -1.0
	var turned := false
	var merging := false    # changing lanes on a link: can't crash while doing it

var end_rule: int = End.JAM
var six_zoom := false
var jam_mult := 1.0

var xs: Array = []
var aps: Array = []
var entries: Array = []  # through-lane index of every entry road
var cars: Array = []
var floats: Array = []
var bounds := Rect2()

var phase: int = Phase.PLAY
var phase_t := 0.0
var stage := 1
var stage_t := 0.0
var quota_n := 0
var elapsed := 0.0
var score := 0
var combo := 0
var throughput := 0
var crashes := 0
var jam := 0.0
var jam_fill := 0.0
var over_reason := ""
var banner := ""
var banner_t := 0.0

var heavy := 0
var heavy_next := 0
var heavy_t := 0.0
var burst_t := 0.0
var burst_lane := -1
var burst_left := 0

var r_pos := Vector2(70, 70)
var r_facing := Vector2.UP
var r_dash_t := 0.0
var r_dash_cd := 0.0
var r_dash_dir := Vector2.ZERO
var r_stun := 0.0
var r_knock := Vector2.ZERO
var r_target := -1
var towing: Car = null
var tow_offset := Vector2.ZERO

var cam: Camera2D
var hud: Node2D
var rev_zoom := 1.0
var rev_pos := Vector2.ZERO
var shake := 0.0
var font: Font

var start_stage2 := false
var start_go := false
var shot_path := ""
var shot_at := 15.0   # seconds of real time (frames run uncapped headless)
var shot_clock := 0.0
var shot_quota := -1.0  # agent check: meet the Quota at this many seconds


func _ready() -> void:
	randomize()
	font = ThemeDB.fallback_font
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Node2D.new()
	layer.add_child(hud)
	hud.draw.connect(_draw_hud)
	_setup_input()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		if a.begins_with("--at="):
			shot_at = float(a.substr(5))
		if a.begins_with("--quota-at="):
			shot_quota = float(a.substr(11))
		if a == "--stage2":
			start_stage2 = true
		if a == "--go":
			start_go = true
		if a == "--six":
			six_zoom = true
	_restart()


func _bind(action: String, keys: Array, buttons: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.3)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)


func _axis(action: String, axis: int, value: float) -> void:
	var m := InputEventJoypadMotion.new()
	m.axis = axis
	m.axis_value = value
	InputMap.action_add_event(action, m)


func _setup_input() -> void:
	_bind("mv_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT])
	_bind("mv_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT])
	_bind("mv_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP])
	_bind("mv_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN])
	_axis("mv_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("mv_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("mv_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("mv_down", JOY_AXIS_LEFT_Y, 1.0)
	_bind("switch", [KEY_J, KEY_K, KEY_Z, KEY_X], [JOY_BUTTON_A])
	_bind("dash", [KEY_L, KEY_C, KEY_SHIFT], [JOY_BUTTON_X])
	_bind("tow", [KEY_U, KEY_V], [JOY_BUTTON_Y])
	_bind("arrow", [KEY_I, KEY_B], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("restart", [KEY_R], [JOY_BUTTON_START])
	_bind("t_end", [KEY_1], [JOY_BUTTON_BACK])
	_bind("t_zoom", [KEY_2], [JOY_BUTTON_LEFT_SHOULDER])
	_bind("t_quota", [KEY_0], [])
	_bind("jam_down", [KEY_MINUS], [])
	_bind("jam_up", [KEY_EQUAL], [])


# --- the world ----------------------------------------------------------------

# n crossings in a row, each linked to the next by a road.
func _build(n: int) -> void:
	xs.clear()
	for k in n:
		var x := Crossing.new()
		x.c = Vector2(k * LINK, 0)
		xs.append(x)
	for k in n - 1:
		xs[k].link[3] = k + 1
		xs[k + 1].link[2] = k
	var w := (n - 1) * LINK + ARM_X * 2.0
	var hy := maxf(ARM_Y, w * SH / SW / 2.0)
	bounds = Rect2(-ARM_X, -hy, w, hy * 2.0)
	aps.clear()
	entries.clear()
	for k in n:
		var X: Vector2 = xs[k].c
		for s in 4:
			var d: Vector2 = SIDE_DIR[s]
			var right := Vector2(-d.y, d.x)
			var reach := hy if absf(d.y) > 0.5 else (X.x - bounds.position.x if d.x > 0.0 else bounds.end.x - X.x)
			var linked: bool = xs[k].link[s] >= 0
			if not linked:
				entries.append(aps.size())
			for turn in [false, true]:
				var off := LW * (0.5 if turn else 1.5)
				var a := Approach.new()
				a.label = "%s-%s%s" % [X_NAMES[k], SIDE_NAMES[s], "-left" if turn else ""]
				a.x = k
				a.dir = d
				a.turn = turn
				a.entry = not linked
				a.stop_point = X - d * STOP_D + right * off
				a.spawn = X - d * (reach + 24.0) + right * off
				a.lamp = a.stop_point - d * 10.0 + (right * -(LW / 2.0 + 14.0) if turn else right * (LW / 2.0 + 14.0))
				aps.append(a)


func _restart() -> void:
	_build(2 if start_stage2 else 1)
	stage = 2 if start_stage2 else 1
	cars.clear()
	floats.clear()
	elapsed = 0.0
	score = 0
	combo = 0
	throughput = 0
	crashes = 0
	r_pos = Vector2(70, 70)
	r_stun = 0.0
	r_dash_t = 0.0
	towing = null
	phase = Phase.PLAY
	phase_t = 0.0
	_start_stage()
	_show_banner("STAGE %d" % stage)


func _start_stage() -> void:
	stage_t = 0.0
	quota_n = 0
	jam = 0.0
	for a: Approach in aps:
		a.go = start_go
		a.yellow_t = 0.0
		a.backlog = 0
		a.edge_t = 0.0
		a.spawn_t = randf_range(2.5, 4.5)
	heavy = entries.pick_random()
	heavy_next = _other_entry(heavy)
	heavy_t = randf_range(SWELL_MIN, SWELL_MAX)
	burst_t = randf_range(6.0, 9.0)
	burst_lane = -1
	burst_left = 0


func _next_stage() -> void:
	stage += 1
	cars.clear()
	towing = null
	phase_t = 0.0
	if xs.size() < 2:
		rev_zoom = cam.zoom.x
		rev_pos = cam.position
		_build(2)
		phase = Phase.REVEAL
		_show_banner("STAGE %d: A SECOND INTERSECTION" % stage)
	else:
		phase = Phase.PLAY
		_show_banner("STAGE %d" % stage)
	_start_stage()


func _quota() -> int:
	return 20 + 15 * (stage - 1)


func _cap() -> float:
	return maxf(10.0, JAM_CAP - crashes * DENT)


func _level() -> int:
	var f := jam / _cap()
	if f >= 0.999:
		return 3
	if f >= 0.7:
		return 2
	if f >= 0.4:
		return 1
	return 0


func _other_entry(e: int) -> int:
	var pick: int = entries.pick_random()
	while pick == e and entries.size() > 1:
		pick = entries.pick_random()
	return pick


# The side a car heading v leaves a crossing by.
func _side(v: Vector2) -> int:
	if v.y < -0.5:
		return 0
	if v.y > 0.5:
		return 1
	if v.x < -0.5:
		return 2
	return 3


func _show_banner(s: String) -> void:
	banner = s
	banner_t = 3.0


func _over(reason: String) -> void:
	phase = Phase.OVER
	over_reason = reason


# --- geometry ---------------------------------------------------------------

func _rect_at(pos: Vector2, dir: Vector2) -> Rect2:
	var size := Vector2(CAR_L, CAR_W) if absf(dir.x) > 0.5 else Vector2(CAR_W, CAR_L)
	return Rect2(pos - size / 2.0, size)


func _rect(c: Car) -> Rect2:
	return _rect_at(c.pos, c.dir)


func _front(c: Car) -> Vector2:
	return c.pos + c.dir * CAR_L / 2.0


func _gap(front: Vector2, dir: Vector2, r: Rect2) -> float:
	if dir.x > 0.5:
		return r.position.x - front.x
	if dir.x < -0.5:
		return front.x - r.end.x
	if dir.y > 0.5:
		return r.position.y - front.y
	return front.y - r.end.y


func _strip(c: Car) -> Rect2:
	var f := _front(c)
	var r := Rect2(f, Vector2.ZERO).expand(f + c.dir * LOOK)
	var hw := CAR_W / 2.0 - 2.0
	if absf(c.dir.x) > 0.5:
		return r.grow_individual(0, hw, 0, hw)
	return r.grow_individual(hw, 0, hw, 0)


func _on_road(p: Vector2) -> bool:
	for x: Crossing in xs:
		if absf(p.x - x.c.x) < ROAD / 2.0 + 10.0 or absf(p.y - x.c.y) < ROAD / 2.0 + 10.0:
			return true
	return false


# The part of the world on screen.
func _view() -> Rect2:
	var s := Vector2(SW, SH) / cam.zoom.x
	return Rect2(cam.position - s / 2.0, s)


func _switch(i: int) -> void:
	var a: Approach = aps[i]
	if a.yellow_t > 0.0:
		return
	var at := a.stop_point - a.dir * 30.0
	if a.go:
		a.yellow_t = YELLOW_TIME
		_float("YELLOW", at, Color.ORANGE)
	else:
		a.go = true
		for c: Car in cars:
			if c.ap == i and not c.passed_line and not c.wreck:
				c.boosted = true
		_float("GREEN ARROW!" if a.turn else "GREEN!", at, Color.GREEN)


func _float(text: String, pos: Vector2, color: Color) -> void:
	floats.append({"text": text, "pos": pos, "t": 1.0, "color": color})


# --- update -----------------------------------------------------------------

func _process(dt: float) -> void:
	_handle_toggles()
	if Input.is_action_just_pressed("restart"):
		_restart()
	if phase != Phase.OVER:
		elapsed += dt
		stage_t += dt
		_update_raccoon(dt)
		if phase == Phase.PLAY:
			_update_flow(dt)
			_update_spawns(dt)
		_update_cars(dt)
		_check_crashes()
		_update_phase(dt)
	for f in floats:
		f.t -= dt
		f.pos.y -= 30.0 * dt / cam.zoom.x
	floats = floats.filter(func(f): return f.t > 0.0)
	shake = maxf(0.0, shake - dt)
	banner_t = maxf(0.0, banner_t - dt)
	_update_camera()
	queue_redraw()
	hud.queue_redraw()
	if shot_path != "":
		var was := shot_clock
		shot_clock += dt
		if was < shot_quota and shot_clock >= shot_quota and phase == Phase.PLAY:
			quota_n = _quota()
		if was < shot_at and shot_clock >= shot_at:
			get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()


func _handle_toggles() -> void:
	if Input.is_action_just_pressed("t_end"):
		end_rule = (end_rule + 1) % 2
	if Input.is_action_just_pressed("t_zoom"):
		six_zoom = not six_zoom
	if Input.is_action_just_pressed("t_quota") and phase == Phase.PLAY:
		quota_n = _quota()
	if Input.is_action_just_pressed("jam_up"):
		jam_mult = minf(3.0, jam_mult + 0.25)
	if Input.is_action_just_pressed("jam_down"):
		jam_mult = maxf(0.25, jam_mult - 0.25)


func _goal_zoom() -> float:
	if six_zoom:
		return SIX_ZOOM
	return minf(SW / bounds.size.x, SH / bounds.size.y) * FIT


func _goal_pos() -> Vector2:
	var mid := bounds.get_center()
	return mid + (r_pos - mid) * DRIFT


func _update_camera() -> void:
	var z := _goal_zoom()
	var p := _goal_pos()
	if phase == Phase.REVEAL:
		var k := ease(clampf(phase_t / REVEAL_TIME, 0.0, 1.0), -2.0)
		z = lerpf(rev_zoom, z, k)
		p = rev_pos.lerp(p, k)
	cam.zoom = Vector2(z, z)
	cam.position = p
	cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 22.0 / z


func _update_phase(dt: float) -> void:
	phase_t += dt
	match phase:
		Phase.PLAY:
			jam = clampf(jam + (jam_fill * jam_mult - JAM_DRAIN) * dt, 0.0, _cap())
			if end_rule == End.JAM and _level() == 3:
				_over("the city Jammed up")
			if end_rule == End.EDGE:
				for a: Approach in aps:
					if a.edge_t >= EDGE_TIME:
						_over("the %s entry backed up off the map" % a.label)
			if phase == Phase.PLAY and quota_n >= _quota():
				phase = Phase.DRAIN
				phase_t = 0.0
				for a: Approach in aps:
					a.backlog = 0
				_show_banner("QUOTA MET! Clear the roads")
		Phase.DRAIN:
			var moving := cars.any(func(c: Car) -> bool: return not c.wreck)
			if not moving or phase_t >= DRAIN_MAX:
				_next_stage()
		Phase.REVEAL:
			if phase_t >= REVEAL_TIME:
				phase = Phase.PLAY
				phase_t = 0.0


func _update_raccoon(dt: float) -> void:
	var k := 1.0 / cam.zoom.x  # speed, Dash and targeting range are constant on screen
	r_dash_cd = maxf(0.0, r_dash_cd - dt)
	var inp := Input.get_vector("mv_left", "mv_right", "mv_up", "mv_down")
	if r_stun > 0.0:
		r_stun -= dt
		r_pos += r_knock * dt
		r_knock = r_knock.move_toward(Vector2.ZERO, 900.0 * dt)
	else:
		if inp.length() > 0.1:
			r_facing = inp.normalized()
		if Input.is_action_just_pressed("dash") and r_dash_cd <= 0.0:
			r_dash_t = DASH_TIME
			r_dash_cd = DASH_CD
			r_dash_dir = r_facing
		var spd := RACCOON_SPEED * k * (0.55 if towing else 1.0)
		if r_dash_t > 0.0:
			r_dash_t -= dt
			r_pos += r_dash_dir * DASH_SPEED * k * (0.6 if towing else 1.0) * dt
		else:
			r_pos += inp * spd * dt
	r_pos = r_pos.clamp(bounds.position + Vector2.ONE * RACCOON_R, bounds.end - Vector2.ONE * RACCOON_R)

	# Target: nearest through-lane lamp in range, biased toward the way the raccoon faces.
	r_target = -1
	var best := INF
	for i in aps.size():
		if aps[i].turn:
			continue
		var d: float = r_pos.distance_to(aps[i].lamp)
		if d > SIGNAL_RANGE * k:
			continue
		var s: float = d - 60.0 * k * r_facing.dot((aps[i].lamp - r_pos).normalized())
		if s < best:
			best = s
			r_target = i

	for a: Approach in aps:
		if a.yellow_t > 0.0:
			a.yellow_t -= dt
			if a.yellow_t <= 0.0:
				a.go = false

	if r_stun <= 0.0 and r_target >= 0 and Input.is_action_just_pressed("switch"):
		_switch(r_target)
	if r_stun <= 0.0 and r_target >= 0 and Input.is_action_just_pressed("arrow"):
		_switch(r_target ^ 1)

	if Input.is_action_just_pressed("tow") and r_stun <= 0.0:
		if towing:
			_drop_tow()
		else:
			var nearest: Car = null
			var nd := INF
			for c: Car in cars:
				if c.wreck and _rect(c).grow(TOW_RANGE * k).has_point(r_pos):
					var d := r_pos.distance_to(c.pos)
					if d < nd:
						nd = d
						nearest = c
			if nearest:
				towing = nearest
				nearest.towed = true
				tow_offset = (nearest.pos - r_pos).limit_length(26.0)
	if towing:
		towing.pos = r_pos + tow_offset
		if not _on_road(towing.pos):
			_drop_tow()


func _drop_tow() -> void:
	var c := towing
	towing = null
	c.towed = false
	if not _on_road(c.pos):
		cars.erase(c)
		score += 5
		_float("CLEARED +5", c.pos, Color.SKY_BLUE)


func _update_flow(dt: float) -> void:
	heavy_t -= dt
	if heavy_t <= 0.0:
		heavy = heavy_next
		heavy_next = _other_entry(heavy)
		heavy_t = randf_range(SWELL_MIN, SWELL_MAX)
		_float("RUSH FROM %s" % aps[heavy].label, aps[heavy].stop_point - aps[heavy].dir * 160.0, Color.ORANGE)
	if burst_left <= 0:
		burst_t -= dt
		if burst_t <= BURST_WARN and burst_lane < 0:
			var e: int = entries.pick_random()
			burst_lane = e + (1 if randf() < BURST_TURN else 0)
		if burst_t <= 0.0:
			burst_left = randi_range(4, 6)
			aps[burst_lane].spawn_t = 0.0
			burst_t = randf_range(BURST_MIN, BURST_MAX)


# Every car that's due joins its entry's backlog, then drives on as soon as the road has room.
func _update_spawns(dt: float) -> void:
	var interval := maxf(1.0, 3.2 - (stage - 1) * 0.2 - stage_t * 0.008)
	for i in aps.size():
		var a: Approach = aps[i]
		if not a.entry:
			continue
		a.spawn_t -= dt
		if a.spawn_t <= 0.0:
			var mult := SWELL_HEAVY if i >> 1 == heavy >> 1 else SWELL_LIGHT
			a.spawn_t = interval * randf_range(0.6, 1.4) / (TURN_SHARE if a.turn else 1.0) / mult
			if i == burst_lane and burst_left > 0:
				burst_left -= 1
				if burst_left > 0:
					a.spawn_t = BURST_GAP
				else:
					burst_lane = -1
			a.backlog += 1
		if a.backlog <= 0:
			a.edge_t = 0.0
			continue
		var r := _rect_at(a.spawn, a.dir).grow(4.0)
		var blocked := false
		for c: Car in cars:
			if _rect(c).intersects(r):
				blocked = true
				break
		if blocked:
			a.edge_t += dt
			continue
		a.edge_t = 0.0
		a.backlog -= 1
		var c := Car.new()
		c.ap = i
		c.turn = a.turn
		c.pos = a.spawn
		c.dir = a.dir
		c.speed = BASE_SPEED * 0.8
		c.color = Color.from_hsv(randf(), 0.65, 0.95)
		c.patience = randf_range(PATIENCE_MIN, PATIENCE_MAX)
		cars.append(c)


# A car clearing a crossing onto a link joins the next crossing's approach, picking a lane.
func _hand_over(c: Car, nx: int) -> void:
	c.turn = randf() < TURN_CHANCE
	c.ap = nx * 8 + _side(-c.dir) * 2 + (1 if c.turn else 0)
	c.passed_line = false
	c.boosted = false
	c.turned = false
	c.arc_s = -1.0
	c.wait = 0.0
	c.honks = 0
	c.patience = randf_range(PATIENCE_MIN, PATIENCE_MAX)


func _update_cars(dt: float) -> void:
	var rush := minf(1.4, 1.0 + stage_t * 0.0015 + (stage - 1) * 0.04)
	var keep: Array = []
	var bye := bounds.grow(60.0)
	jam_fill = 0.0
	for a: Approach in aps:
		a.jam = 0.0
		if a.backlog > 0:
			a.jam += JAM_BACKLOG * a.backlog
	var fronts := {}
	var front_d := {}
	for c: Car in cars:
		if c.wreck or c.passed_line:
			continue
		var d: float = (aps[c.ap].stop_point - _front(c)).dot(aps[c.ap].dir)
		if not front_d.has(c.ap) or d < front_d[c.ap]:
			fronts[c.ap] = c
			front_d[c.ap] = d
	for c: Car in cars:
		if c.wreck:
			keep.append(c)
			continue
		var a: Approach = aps[c.ap]
		var front := _front(c)
		var target := BASE_SPEED * rush * (GO_BOOST if c.boosted else 1.0)

		# Stop line.
		var dist := (a.stop_point - front).dot(a.dir)
		if not c.passed_line:
			if dist < 0.0:
				c.passed_line = true
				if a.go:
					c.boosted = true
			elif not a.go or a.yellow_t > 0.0:
				var need := c.speed * c.speed / (4.0 * DECEL) * (2.0 if a.yellow_t > 0.0 else 1.0)
				if dist < need - 1.0 and c.speed > 40.0:
					c.passed_line = true
				else:
					target = minf(target, sqrt(2.0 * DECEL * maxf(dist - 2.0, 0.0)))

		# Left turners (protected arrow) start their arc at the stop point.
		if c.turn and c.arc_s < 0.0 and c.passed_line:
			var ds := (a.stop_point - c.pos).dot(a.dir)
			if ds <= 0.0:
				c.arc_s = -ds
		if c.turn and c.arc_s >= 0.0 and not c.turned:
			target = minf(target, BASE_SPEED * rush * TURN_SPEED)

		# Obstacles: anything ahead heading the same way (so a queue on a link backs up into
		# the crossing behind it), and any wreckage.
		var strip := _strip(c)
		for o: Car in cars:
			if o == c:
				continue
			if not o.wreck and o.dir.dot(c.dir) < 0.7:
				continue
			var r := _rect(o)
			if not strip.intersects(r):
				continue
			var g := _gap(front, c.dir, r)
			if g < -CAR_L:
				continue
			target = minf(target, sqrt(2.0 * DECEL * maxf(g - 8.0, 0.0)))

		# The raccoon in the lane ahead.
		var rr := Rect2(r_pos - Vector2.ONE * RACCOON_R, Vector2.ONE * RACCOON_R * 2.0)
		if strip.grow(RACCOON_R - 6.0).intersects(rr):
			var g := _gap(front, c.dir, rr)
			if g >= -CAR_L / 2.0 or (g >= -CAR_L and c.speed < 40.0):
				target = minf(target, sqrt(2.0 * DECEL * maxf(g - 6.0, 0.0)))

		if c.speed < target:
			c.speed = minf(target, c.speed + ACCEL * dt)
		else:
			c.speed = maxf(target, c.speed - DECEL * 2.0 * dt)
		if c.turn and c.arc_s >= 0.0 and not c.turned:
			c.arc_s += c.speed * dt
			var rad := STOP_D + LW * 0.5
			var th := c.arc_s / rad
			var lf := Vector2(a.dir.y, -a.dir.x)
			if th >= PI / 2.0:
				c.turned = true
				c.dir = lf
				c.pos = a.stop_point + (a.dir + lf) * rad + lf * (c.arc_s - rad * PI / 2.0)
			else:
				c.pos = a.stop_point + lf * rad - lf * rad * cos(th) + a.dir * rad * sin(th)
				c.dir = (lf * sin(th) + a.dir * cos(th)).normalized()
		else:
			c.pos += c.dir * c.speed * dt

		# On a link, drift sideways into the lane picked for the next crossing.
		c.merging = false
		if not c.passed_line:
			var perp := Vector2(-c.dir.y, c.dir.x)
			var e := (a.stop_point - c.pos).dot(perp)
			if absf(e) > 0.5:
				c.pos += perp * clampf(e, -MERGE_SPEED * dt, MERGE_SPEED * dt)
				c.merging = true

		# Cleared the crossing: onto a link, or on its way off the map.
		if c.passed_line and (not c.turn or c.turned):
			var X: Vector2 = xs[a.x].c
			if (c.pos - X).dot(c.dir) > ROAD / 2.0 + CAR_L:
				var nx: int = xs[a.x].link[_side(c.dir)]
				if nx >= 0:
					_hand_over(c, nx)

		# Waiting feeds the Jam. Only the front car at a Light (and anyone stuck in a box)
		# spends Patience, and it only Honks: nobody blows the red in this prototype.
		var metered: bool = c.passed_line or fronts.get(c.ap) == c
		if not metered:
			c.wait = 0.0
		elif c.speed < 8.0:
			c.wait += dt
		elif c.speed > 40.0:
			c.wait = maxf(0.0, c.wait - dt * 2.0)
		if not c.passed_line:
			c.wait = minf(c.wait, c.patience - 0.01)
		var ring_i := mini(int(c.wait / (c.patience / PATIENCE_RINGS)), PATIENCE_RINGS - 1)
		if ring_i > c.honks:
			_float("HONK!" if ring_i == 1 else "HONK HONK!", c.pos + Vector2(0, -24), Color.YELLOW)
		c.honks = ring_i
		if metered and c.honks > 0:
			var f: float = JAM_HONK[c.honks]
			aps[c.ap].jam += f

		if not bye.has_point(c.pos):
			throughput += 1
			quota_n += 1
			combo += 1
			score += 10 * (1 + combo / 5)
			jam = maxf(0.0, jam - JAM_EXIT)
			continue
		keep.append(c)
	cars = keep
	for a: Approach in aps:
		jam_fill += a.jam


func _check_crashes() -> void:
	var n := cars.size()
	for i in n:
		var a: Car = cars[i]
		var ra := _rect(a).grow(-2.0)
		for j in range(i + 1, n):
			var b: Car = cars[j]
			if (a.wreck and b.wreck) or a.towed or b.towed or a.merging or b.merging:
				continue
			if ra.intersects(_rect(b).grow(-2.0)):
				_crash(a, b)
	if r_stun <= 0.0:
		for c: Car in cars:
			if not c.wreck and c.speed > 30.0 and _rect(c).grow(RACCOON_R - 4.0).has_point(r_pos):
				r_stun = 0.8
				r_knock = c.dir * 420.0 / cam.zoom.x
				r_dash_t = 0.0
				if towing:
					towing.towed = false
					towing = null
				_float("BONK", r_pos + Vector2(0, -26), Color.YELLOW)
				break


func _crash(a: Car, b: Car) -> void:
	var fresh := not a.wreck or not b.wreck
	for c in [a, b]:
		if not c.wreck:
			c.wreck = true
			c.speed = 0.0
			c.wreck_rot = randf_range(-0.6, 0.6)
		if c.towed:
			c.towed = false
			towing = null
	if not fresh:
		return
	crashes += 1
	combo = 0
	shake = 0.35
	var mid: Vector2 = (a.pos + b.pos) / 2.0
	_float("CRASH!  DENT -%d%%" % int(DENT), mid + Vector2(0, -20), Color.ORANGE_RED)
	var p := CPUParticles2D.new()
	p.position = mid
	p.one_shot = true
	p.amount = 28
	p.explosiveness = 1.0
	p.lifetime = 0.6
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color.ORANGE
	p.z_index = 5
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


# --- draw -------------------------------------------------------------------

func _text(ci: CanvasItem, s: String, pos: Vector2, size: int, color: Color, center := false) -> void:
	if center:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		pos.x -= w / 2.0
	var sh := maxf(1.0, size / 16.0)
	ci.draw_string(font, pos + Vector2(sh, sh), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7))
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# A font size in world units that reads as px on screen.
func _ws(px: float) -> int:
	return int(px / cam.zoom.x)


func _seg(a: Vector2, b: Vector2, col: Color, dashed: bool) -> void:
	if not dashed:
		draw_line(a, b, col, 2.0)
		return
	var n := int(a.distance_to(b) / 28.0)
	var d := (b - a).normalized()
	for k in n:
		draw_line(a + d * k * 28.0, a + d * (k * 28.0 + 14.0), col, 2.0)


# A marking along a road, broken at every crossing box on it.
func _marking(horizontal: bool, at: float, off: float, col: Color, dashed: bool) -> void:
	var edge := ROAD / 2.0 + 4.0
	var ext := bounds.grow(60.0)
	var cuts: Array = []
	for x: Crossing in xs:
		var on: float = x.c.y if horizontal else x.c.x
		if absf(on - at) < 1.0:
			cuts.append(x.c.x if horizontal else x.c.y)
	cuts.sort()
	var lo: float = ext.position.x if horizontal else ext.position.y
	var hi: float = ext.end.x if horizontal else ext.end.y
	cuts.append(hi + edge)
	for cut: float in cuts:
		var b := cut - edge
		if horizontal:
			_seg(Vector2(lo, at + off), Vector2(b, at + off), col, dashed)
		else:
			_seg(Vector2(at + off, lo), Vector2(at + off, b), col, dashed)
		lo = cut + edge


func _draw() -> void:
	var ext := bounds.grow(60.0)
	draw_rect(bounds.grow(3000.0), Color(0.12, 0.2, 0.12))
	draw_rect(ext, Color(0.2, 0.36, 0.2))
	var road := Color(0.28, 0.28, 0.3)
	var yel := Color(0.9, 0.8, 0.2)
	var dash := Color(1, 1, 1, 0.6)
	var rows := {}
	for x: Crossing in xs:
		draw_rect(Rect2(x.c.x - ROAD / 2, ext.position.y, ROAD, ext.size.y), road)
		draw_rect(Rect2(ext.position.x, x.c.y - ROAD / 2, ext.size.x, ROAD), road)
	for x: Crossing in xs:
		for s in [-1.0, 1.0]:
			_marking(false, x.c.x, s * 2.0, yel, false)
			_marking(false, x.c.x, s * LW, dash, true)
			if not rows.has(x.c.y):
				_marking(true, x.c.y, s * 2.0, yel, false)
				_marking(true, x.c.y, s * LW, dash, true)
		rows[x.c.y] = true

	# Heavy: the lanes feeding the Jam pulse red.
	if phase == Phase.PLAY and _level() == 2:
		var al := 0.22 + 0.18 * sin(elapsed * 10.0)
		for a: Approach in aps:
			if a.jam > 0.0:
				var sp := a.stop_point
				draw_rect(Rect2(sp, Vector2.ZERO).expand(sp - a.dir * 160.0).grow(LW / 2 - 1), Color(1, 0.1, 0.05, al))

	for a: Approach in aps:
		var perp := Vector2(-a.dir.y, a.dir.x)
		draw_line(a.stop_point + perp * (LW / 2 - 1), a.stop_point - perp * (LW / 2 - 1), Color.WHITE, 3.0)
		if a.turn:
			var lf := -perp
			var b := a.stop_point - a.dir * 60.0
			var k := b + a.dir * 18.0
			draw_polyline(PackedVector2Array([b - a.dir * 8.0, k, k + lf * 8.0]), Color(1, 1, 1, 0.8), 3.0)
			draw_colored_polygon(PackedVector2Array([k + lf * 14.0, k + lf * 7.0 + a.dir * 6.0, k + lf * 7.0 - a.dir * 6.0]), Color(1, 1, 1, 0.8))
	for a: Approach in aps:
		var lamp_col := Color.ORANGE if a.yellow_t > 0.0 else (Color.GREEN if a.go else Color.RED)
		draw_circle(a.lamp, 9.0, Color(0.1, 0.1, 0.1))
		draw_circle(a.lamp, 7.5, lamp_col)
		if a.turn:
			var lf := Vector2(a.dir.y, -a.dir.x)
			draw_line(a.lamp - lf * 4.0, a.lamp + lf * 4.0, Color.BLACK, 2.0)
			draw_line(a.lamp + lf * 4.0, a.lamp + lf * 1.0 + a.dir * 3.0, Color.BLACK, 2.0)
			draw_line(a.lamp + lf * 4.0, a.lamp + lf * 1.0 - a.dir * 3.0, Color.BLACK, 2.0)
	if r_target >= 0:
		var t: Approach = aps[r_target]
		var tw: Approach = aps[r_target ^ 1]
		draw_arc(t.lamp, 14.0, 0, TAU, 24, Color.YELLOW, 3.0)
		draw_dashed_line(r_pos, t.lamp, Color(1, 1, 0, 0.5), 2.0, 6.0)
		var sp := t.stop_point
		draw_rect(Rect2(sp, Vector2.ZERO).expand(sp - t.dir * 90.0).grow(LW / 2 - 2), Color(1, 1, 0, 0.12))
		draw_arc(tw.lamp, 14.0, 0, TAU, 24, Color(0.4, 0.8, 1.0), 2.0)
		_text(self, "RB", tw.lamp + Vector2(-9, -16), 13, Color(0.4, 0.8, 1.0))

	for c: Car in cars:
		var rot := c.dir.angle() + (c.wreck_rot if c.wreck else 0.0)
		draw_set_transform(c.pos, rot)
		var body := c.color.darkened(0.55) if c.wreck else c.color
		draw_rect(Rect2(-CAR_L / 2, -CAR_W / 2, CAR_L, CAR_W), body)
		draw_rect(Rect2(CAR_L / 2 - 12, -CAR_W / 2 + 3, 6, CAR_W - 6), Color(0.15, 0.2, 0.3))
		if c.wreck:
			draw_line(Vector2(-10, -7), Vector2(10, 7), Color.BLACK, 3.0)
			draw_line(Vector2(-10, 7), Vector2(10, -7), Color.BLACK, 3.0)
		elif c.boosted:
			draw_line(Vector2(-CAR_L / 2 - 8, -5), Vector2(-CAR_L / 2 - 2, -5), Color.WHITE, 2.0)
			draw_line(Vector2(-CAR_L / 2 - 10, 5), Vector2(-CAR_L / 2 - 2, 5), Color.WHITE, 2.0)
		if c.turn and not c.turned and not c.wreck and fmod(elapsed * 3.0, 1.0) < 0.5:
			draw_rect(Rect2(CAR_L / 2 - 6, -CAR_W / 2 - 2, 6, 5), Color(1, 0.65, 0))
			draw_rect(Rect2(-CAR_L / 2, -CAR_W / 2 - 2, 6, 5), Color(1, 0.65, 0))
		draw_set_transform(Vector2.ZERO, 0.0)
		if not c.wreck and c.wait > 0.6:
			var per := c.patience / PATIENCE_RINGS
			var ring_i := mini(int(c.wait / per), PATIENCE_RINGS - 1)
			var k := clampf((c.wait - ring_i * per) / per, 0.0, 1.0)
			var ring: Color = [Color.YELLOW, Color.ORANGE, Color.RED][ring_i]
			draw_arc(c.pos, 17.0, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 5.0)
			draw_arc(c.pos, 17.0, -PI / 2, -PI / 2 + TAU * k, 24, ring, 4.0)
			for p in PATIENCE_RINGS:
				var pip := c.pos + Vector2(-10 + p * 10, 24)
				draw_circle(pip, 3.5, Color(0, 0, 0, 0.6))
				if p < ring_i:
					draw_circle(pip, 2.5, [Color.YELLOW, Color.ORANGE, Color.RED][p])

	if towing:
		draw_line(r_pos, towing.pos, Color(0.8, 0.6, 0.3), 3.0)
	var fur := Color(0.55, 0.55, 0.58)
	var tail := r_pos - r_facing * 18.0
	draw_circle(tail, 8.0, fur)
	draw_arc(tail, 5.0, 0, TAU, 12, Color(0.15, 0.15, 0.15), 3.0)
	draw_circle(r_pos, RACCOON_R, fur)
	var side := Vector2(-r_facing.y, r_facing.x)
	draw_line(r_pos + r_facing * 5 + side * 10, r_pos + r_facing * 5 - side * 10, Color(0.1, 0.1, 0.1), 6.0)
	draw_circle(r_pos + r_facing * 5 + side * 5, 2.0, Color.WHITE)
	draw_circle(r_pos + r_facing * 5 - side * 5, 2.0, Color.WHITE)
	draw_circle(r_pos + r_facing * 14.0, 3.0, Color(0.1, 0.1, 0.1))
	draw_arc(r_pos, RACCOON_R + 3.0, 0, TAU, 24, Color(1, 0.6, 0.1), 2.0)
	if r_stun > 0.0:
		for k in 3:
			var ang := elapsed * 8.0 + k * TAU / 3.0
			_text(self, "*", r_pos + Vector2(cos(ang), sin(ang)) * 18.0 + Vector2(-4, 4), 16, Color.YELLOW)
	if r_dash_t > 0.0:
		draw_line(r_pos, r_pos - r_dash_dir * 30.0, Color(1, 1, 1, 0.6), 6.0)

	_draw_entries()

	for f in floats:
		var col: Color = f.color
		col.a = clampf(f.t * 2.0, 0.0, 1.0)
		_text(self, f.text, f.pos, _ws(18), col, true)


func _chevrons(p: Vector2, dir: Vector2, n: int, col: Color, s: float) -> void:
	var side := Vector2(-dir.y, dir.x)
	for k in n:
		var tip := p + dir * (k * 12.0 - (n - 1) * 6.0) * s
		draw_polyline(PackedVector2Array([tip - (dir * 7.0 - side * 11.0) * s, tip, tip - (dir * 7.0 + side * 11.0) * s]), col, 4.0 * s)


# At each map entry: the backlog "+N", the heavy road, the road about to turn heavy, and platoons.
# Labels are pinned inside the view, so a pile-up off screen still shows.
func _draw_entries() -> void:
	var s := 1.0 / cam.zoom.x
	var blink := fmod(elapsed * 4.0, 1.0) < 0.5
	var view := _view()
	var heavy_lvl := phase == Phase.PLAY and _level() == 2
	for e: int in entries:
		var a: Approach = aps[e]
		var right := Vector2(-a.dir.y, a.dir.x)
		var p := a.spawn + a.dir * (24.0 + 70.0 * s) - right * LW * 0.5
		p = p.clamp(view.position + Vector2(60, 70) * s, view.end - Vector2(60, 100) * s)
		var out := right * 64.0 * s
		var tags: Array = []
		var backlog: int = a.backlog + aps[e + 1].backlog
		if backlog > 0:
			var hot := heavy_lvl and blink
			tags.append(["+%d" % backlog, Color.WHITE if hot else Color(1, 0.35, 0.3), 22])
		if e == heavy:
			_chevrons(p, a.dir, 3, Color.ORANGE, s)
			tags.append(["HEAVY", Color.ORANGE, 15])
		elif e == heavy_next and heavy_t <= SHIFT_WARN:
			if blink:
				_chevrons(p, a.dir, 3, Color(1, 0.65, 0, 0.6), s)
			tags.append(["RUSH IN %d" % ceili(heavy_t), Color(1, 0.8, 0.4), 15])
		if burst_lane >= 0 and burst_lane >> 1 == e >> 1:
			var tag := "PLATOON" + (" (LEFT)" if burst_lane & 1 else "")
			tags.append([tag if burst_left > 0 else tag + "!", Color.WHITE, 15])
		var y := -(tags.size() - 1) * 10.0
		for t in tags:
			_text(self, t[0], p + out + Vector2(0, (y + 6.0) * s), _ws(t[2]), t[1], true)
			y += 20.0


func _draw_hud() -> void:
	var ci := hud
	ci.draw_rect(Rect2(0, 0, 330, 140), Color(0, 0, 0, 0.55))
	_text(ci, "PROTOTYPE: growing world + Jam (#16)", Vector2(10, 20), 14, Color(1, 1, 1, 0.6))
	_text(ci, "Stage %d   Quota %d / %d" % [stage, mini(quota_n, _quota()), _quota()], Vector2(10, 48), 22, Color.WHITE)
	_text(ci, "Score %d   Combo %d (x%d)" % [score, combo, 1 + combo / 5], Vector2(10, 72), 16, Color.WHITE)
	_text(ci, "Through %d   Crashes %d   %ds" % [throughput, crashes, int(elapsed)], Vector2(10, 94), 16, Color.WHITE)
	var dash_s := "ready" if r_dash_cd <= 0.0 else "%.1f" % r_dash_cd
	_text(ci, "Dash %s   Zoom %.2f" % [dash_s, cam.zoom.x], Vector2(10, 116), 16, Color.WHITE)

	# The Jam bar. The dark red tail is capacity lost to Dents.
	var bx := 420.0
	var by := 12.0
	var bw := 440.0
	var bh := 22.0
	var cap := _cap()
	var cw := bw * cap / JAM_CAP
	var lvl := _level()
	var blink := fmod(elapsed * 4.0, 1.0) < 0.5
	var col: Color = [Color(0.45, 0.85, 0.45), Color(1, 0.72, 0.1), Color(0.95, 0.15, 0.1), Color(0.95, 0.15, 0.1)][lvl]
	if lvl == 2 and blink:
		col = col.lightened(0.45)
	ci.draw_rect(Rect2(bx - 4, by - 4, bw + 8, bh + 50), Color(0, 0, 0, 0.55))
	ci.draw_rect(Rect2(bx, by, cw, bh), Color(0.16, 0.16, 0.16))
	ci.draw_rect(Rect2(bx + cw, by, bw - cw, bh), Color(0.3, 0.04, 0.04))
	var hx := bx + cw + 4.0
	while hx < bx + bw:
		ci.draw_line(Vector2(hx, by + bh), Vector2(minf(hx + bh, bx + bw), by), Color(0.6, 0.1, 0.1), 2.0)
		hx += 8.0
	ci.draw_rect(Rect2(bx, by, cw * clampf(jam / cap, 0.0, 1.0), bh), col)
	for f in [0.4, 0.7]:
		ci.draw_line(Vector2(bx + cw * f, by - 3), Vector2(bx + cw * f, by + bh + 3), Color.WHITE, 2.0)
	_text(ci, "JAM  %s  %d%%%s" % [LEVEL_NAMES[lvl], int(100.0 * jam / cap), "" if end_rule == End.JAM else "  (not lethal)"], Vector2(bx, by + bh + 20), 18, col)
	_text(ci, "Dents %d (-%d%%)" % [crashes, int(crashes * DENT)], Vector2(bx + bw - 118, by + bh + 20), 16, Color(1, 0.5, 0.45))
	_text(ci, "fill %.1f/s x%.2f   drain %.1f/s" % [jam_fill, jam_mult, JAM_DRAIN], Vector2(bx, by + bh + 40), 13, Color(1, 1, 1, 0.7))

	var help := [
		"Move WASD/arrows/stick   Switch J/K/Z/X (A)   Arrow I/B (RB)   Dash L/C/Shift (X)   Tow U/V (Y)   R restart",
		"[1 / Back] Run ends on: %s   [2 / LB] Zoom: %s" % [
			"JAM full (new)" if end_rule == End.JAM else "EDGE: an entry backed up %ds (old)" % int(EDGE_TIME),
			"SIX-crossing scale (%.2f)" % SIX_ZOOM if six_zoom else "AUTO (fit the map)"],
		"[0] Meet the Quota now   [- / =] Jam fill x%.2f" % jam_mult,
	]
	ci.draw_rect(Rect2(0, SH - 64, SW, 64), Color(0, 0, 0, 0.55))
	_text(ci, help[0], Vector2(10, SH - 45), 14, Color.WHITE)
	_text(ci, help[1], Vector2(10, SH - 26), 14, Color(1, 0.9, 0.6))
	_text(ci, help[2], Vector2(10, SH - 7), 14, Color(0.7, 0.85, 1))

	if banner_t > 0.0 and phase != Phase.OVER:
		var a := clampf(banner_t, 0.0, 1.0)
		_text(ci, banner, Vector2(SW / 2, 150), 36, Color(1, 1, 1, a), true)
	if phase == Phase.DRAIN:
		_text(ci, "Draining... %ds" % ceili(DRAIN_MAX - phase_t), Vector2(SW / 2, 186), 18, Color(1, 1, 1, 0.8), true)

	if phase == Phase.OVER:
		ci.draw_rect(Rect2(0, 0, SW, SH), Color(0, 0, 0, 0.6))
		_text(ci, "GRIDLOCK!", Vector2(SW / 2, SH / 2 - 40), 64, Color.ORANGE_RED, true)
		_text(ci, over_reason, Vector2(SW / 2, SH / 2), 22, Color.WHITE, true)
		_text(ci, "Stage %d   Score %d   Through %d   Crashes %d   %ds" % [stage, score, throughput, crashes, int(elapsed)], Vector2(SW / 2, SH / 2 + 36), 22, Color.WHITE, true)
		_text(ci, "R / Start to run again", Vector2(SW / 2, SH / 2 + 76), 18, Color(1, 1, 1, 0.7), true)

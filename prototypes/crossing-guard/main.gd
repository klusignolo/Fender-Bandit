# PROTOTYPE, throw away: greybox for "Does crossing-guard traffic direction feel fun?" (issue #5).
# Everything lives in this one script and is drawn with _draw(). No polish, no tests.
extends Node2D

const W := 1280.0
const H := 720.0
const C := Vector2(640, 360)
const LANE := 22.0          # lane centre offset from road centre
const ROAD := 88.0          # road width (two lanes)
const STOP_D := 58.0        # stop line distance from the centre
const CAR_L := 38.0
const CAR_W := 20.0
const LOOK := 220.0         # how far drivers look ahead in their own lane
const BASE_SPEED := 150.0
const GO_BOOST := 1.45
const ACCEL := 260.0
const DECEL := 420.0
const RACCOON_R := 14.0
const RACCOON_SPEED := 230.0
const DASH_SPEED := 640.0
const DASH_TIME := 0.18
const DASH_CD := 0.9
const SIGNAL_RANGE := 160.0
const TOW_RANGE := 30.0
const WHISTLE_FREEZE := 2.0
const WHISTLE_CD := 10.0
const WRECK_AUTOCLEAR := 12.0
const GRIDLOCK_BLOCK_TIME := 8.0
const YELLOW_TIME := 1.5
const PATIENCE_MIN := 8.0
const PATIENCE_MAX := 12.0
const WARN_TIME := 2.0      # seconds of flashing before a driver runs the Stop

enum Pen { RUN, COMBO, ANGER }
const PEN_NAMES := ["impatient drivers RUN the Stop", "honks BREAK the Combo", "honks fill an ANGER meter"]

class Approach:
	var label: String
	var dir: Vector2
	var spawn: Vector2
	var stop_point: Vector2
	var go := false
	var yellow_t := 0.0     # >0: amber, counting down to red
	var spawn_t := 0.0
	var blocked_t := 0.0

class Car:
	var ap: int
	var pos: Vector2
	var dir: Vector2
	var speed := 0.0
	var color: Color
	var wait := 0.0
	var patience := 10.0
	var running := false
	var boosted := false
	var passed_line := false
	var wreck := false
	var wreck_t := 0.0
	var wreck_rot := 0.0
	var towed := false

# Dev toggles (keys 1-4)
var tow_enabled := true
var whistle_enabled := false  # playtest: never reached for it
var penalty: int = Pen.RUN
var start_go := false
var yield_raccoon := true

var aps: Array = []
var cars: Array = []
var floats: Array = []

var elapsed := 0.0
var score := 0
var combo := 0
var throughput := 0
var crashes := 0
var anger := 0.0
var gridlocked := false
var gridlock_reason := ""

var r_pos := C + Vector2(70, 70)
var r_facing := Vector2.UP
var r_dash_t := 0.0
var r_dash_cd := 0.0
var r_dash_dir := Vector2.ZERO
var r_stun := 0.0
var r_knock := Vector2.ZERO
var r_target := -1
var towing: Car = null
var tow_offset := Vector2.ZERO

var freeze_t := 0.0
var whistle_cd := 0.0
var whistle_ring := 0.0
var shake := 0.0
var font: Font

var shot_path := ""
var shot_frame := 0
var shot_yellow := false  # agent check: --yellow flips every green light to yellow just before the shot


func _ready() -> void:
	randomize()
	font = ThemeDB.fallback_font
	_setup_input()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			shot_path = a.substr(7)
		if a == "--yellow":
			shot_yellow = true
		if a == "--go":
			start_go = true
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
	_bind("whistle", [KEY_I, KEY_B], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("restart", [KEY_R], [JOY_BUTTON_START])
	_bind("t_tow", [KEY_1], [])
	_bind("t_whistle", [KEY_2], [])
	_bind("t_penalty", [KEY_3], [JOY_BUTTON_BACK])
	_bind("t_start", [KEY_4], [])
	_bind("t_yield", [KEY_5], [])


func _restart() -> void:
	aps.clear()
	_add_ap("N", Vector2.DOWN, Vector2(C.x - LANE, -24), Vector2(C.x - LANE, C.y - STOP_D))
	_add_ap("S", Vector2.UP, Vector2(C.x + LANE, H + 24), Vector2(C.x + LANE, C.y + STOP_D))
	_add_ap("W", Vector2.RIGHT, Vector2(-24, C.y + LANE), Vector2(C.x - STOP_D, C.y + LANE))
	_add_ap("E", Vector2.LEFT, Vector2(W + 24, C.y - LANE), Vector2(C.x + STOP_D, C.y - LANE))
	cars.clear()
	floats.clear()
	elapsed = 0.0
	score = 0
	combo = 0
	throughput = 0
	crashes = 0
	anger = 0.0
	gridlocked = false
	r_pos = C + Vector2(70, 70)
	r_stun = 0.0
	r_dash_t = 0.0
	towing = null
	freeze_t = 0.0
	whistle_cd = 0.0


func _add_ap(label: String, dir: Vector2, spawn: Vector2, stop_point: Vector2) -> void:
	var a := Approach.new()
	a.label = label
	a.dir = dir
	a.spawn = spawn
	a.stop_point = stop_point
	a.go = start_go
	a.spawn_t = randf_range(0.3, 2.0)
	aps.append(a)


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
	return absf(p.x - C.x) < ROAD / 2.0 + 10.0 or absf(p.y - C.y) < ROAD / 2.0 + 10.0


func _float(text: String, pos: Vector2, color: Color) -> void:
	floats.append({"text": text, "pos": pos, "t": 1.0, "color": color})


# --- update -----------------------------------------------------------------

func _process(dt: float) -> void:
	_handle_toggles()
	if Input.is_action_just_pressed("restart"):
		_restart()
	if not gridlocked:
		elapsed += dt
		_update_raccoon(dt)
		_update_spawns(dt)
		_update_cars(dt)
		_check_crashes()
		_check_gridlock(dt)
	for f in floats:
		f.t -= dt
		f.pos.y -= 30.0 * dt
	floats = floats.filter(func(f): return f.t > 0.0)
	shake = maxf(0.0, shake - dt)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 22.0
	whistle_ring = maxf(0.0, whistle_ring - dt)
	queue_redraw()
	if shot_path != "":
		shot_frame += 1
		if shot_yellow and shot_frame == 870:
			for ap: Approach in aps:
				if ap.go:
					ap.yellow_t = YELLOW_TIME
		if shot_frame == 900:
			get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()


func _handle_toggles() -> void:
	if Input.is_action_just_pressed("t_tow"):
		tow_enabled = not tow_enabled
		if not tow_enabled and towing:
			towing.towed = false
			towing = null
	if Input.is_action_just_pressed("t_whistle"):
		whistle_enabled = not whistle_enabled
	if Input.is_action_just_pressed("t_penalty"):
		penalty = (penalty + 1) % 3
		anger = 0.0
	if Input.is_action_just_pressed("t_yield"):
		yield_raccoon = not yield_raccoon
	if Input.is_action_just_pressed("t_start"):
		start_go = not start_go
		_restart()


func _update_raccoon(dt: float) -> void:
	r_dash_cd = maxf(0.0, r_dash_cd - dt)
	whistle_cd = maxf(0.0, whistle_cd - dt)
	freeze_t = maxf(0.0, freeze_t - dt)
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
		var spd := RACCOON_SPEED * (0.55 if towing else 1.0)
		if r_dash_t > 0.0:
			r_dash_t -= dt
			r_pos += r_dash_dir * DASH_SPEED * (0.6 if towing else 1.0) * dt
		else:
			r_pos += inp * spd * dt
	r_pos = r_pos.clamp(Vector2(RACCOON_R, RACCOON_R), Vector2(W - RACCOON_R, H - RACCOON_R))

	# Target: nearest stop line in range, biased toward the way the raccoon faces.
	r_target = -1
	var best := INF
	for i in aps.size():
		var d: float = r_pos.distance_to(aps[i].stop_point)
		if d > SIGNAL_RANGE:
			continue
		var s: float = d - 60.0 * r_facing.dot((aps[i].stop_point - r_pos).normalized())
		if s < best:
			best = s
			r_target = i

	# Yellow lights count down to red on their own.
	for a: Approach in aps:
		if a.yellow_t > 0.0:
			a.yellow_t -= dt
			if a.yellow_t <= 0.0:
				a.go = false

	# One button tampers with the light: red -> green, green -> yellow (-> red).
	if r_stun <= 0.0 and r_target >= 0 and Input.is_action_just_pressed("switch"):
		var a: Approach = aps[r_target]
		if a.yellow_t > 0.0:
			pass  # already on its way to red
		elif a.go:
			a.yellow_t = YELLOW_TIME
			_float("YELLOW", a.stop_point - a.dir * 30.0, Color.ORANGE)
		else:
			a.go = true
			for c: Car in cars:
				if c.ap == r_target and not c.passed_line and not c.wreck:
					c.boosted = true
			_float("GREEN!", a.stop_point - a.dir * 30.0, Color.GREEN)

	if tow_enabled and Input.is_action_just_pressed("tow") and r_stun <= 0.0:
		if towing:
			_drop_tow()
		else:
			var nearest: Car = null
			var nd := INF
			for c: Car in cars:
				if c.wreck and _rect(c).grow(TOW_RANGE).has_point(r_pos):
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
		if not _on_road(towing.pos) or towing.pos.x < -20 or towing.pos.x > W + 20:
			_drop_tow()

	if whistle_enabled and Input.is_action_just_pressed("whistle") and whistle_cd <= 0.0:
		freeze_t = WHISTLE_FREEZE
		whistle_cd = WHISTLE_CD
		whistle_ring = 0.5
		_float("TWEEEET!", r_pos + Vector2(0, -30), Color.WHITE)


func _drop_tow() -> void:
	var c := towing
	towing = null
	c.towed = false
	if not _on_road(c.pos):
		cars.erase(c)
		score += 5
		_float("CLEARED +5", c.pos, Color.SKY_BLUE)


func _update_spawns(dt: float) -> void:
	var interval := maxf(1.0, 3.2 - elapsed * 0.008)  # peaks at ~4.5 min
	for i in aps.size():
		var a: Approach = aps[i]
		a.spawn_t -= dt
		if a.spawn_t > 0.0:
			continue
		var r := _rect_at(a.spawn, a.dir).grow(4.0)
		var blocked := false
		for c: Car in cars:
			if _rect(c).intersects(r):
				blocked = true
				break
		if blocked:
			a.blocked_t += dt
			continue
		a.blocked_t = 0.0
		a.spawn_t = interval * randf_range(0.6, 1.4)
		var c := Car.new()
		c.ap = i
		c.pos = a.spawn
		c.dir = a.dir
		c.speed = BASE_SPEED * 0.8
		c.color = Color.from_hsv(randf(), 0.65, 0.95)
		c.patience = randf_range(PATIENCE_MIN, PATIENCE_MAX)
		cars.append(c)


func _update_cars(dt: float) -> void:
	var rush := minf(1.4, 1.0 + elapsed * 0.0015)
	var keep: Array = []
	for c: Car in cars:
		if c.wreck:
			if not tow_enabled and not c.towed:
				c.wreck_t += dt
				if c.wreck_t >= WRECK_AUTOCLEAR:
					continue
			keep.append(c)
			continue
		var a: Approach = aps[c.ap]
		var front := _front(c)
		var target := BASE_SPEED * rush * (GO_BOOST if c.boosted else 1.0)

		# Stop line.
		var dist := (a.stop_point - front).dot(c.dir)
		if not c.passed_line:
			if dist < 0.0:
				c.passed_line = true
				if a.go:
					c.boosted = true
			elif (not a.go or a.yellow_t > 0.0) and not c.running:
				# On yellow, drivers who'd have to brake hard push through instead.
				var need := c.speed * c.speed / (4.0 * DECEL) * (2.0 if a.yellow_t > 0.0 else 1.0)
				if dist < need - 1.0 and c.speed > 40.0:
					c.passed_line = true  # too close to stop: commits
				else:
					target = minf(target, sqrt(2.0 * DECEL * maxf(dist - 2.0, 0.0)))

		# Obstacles in the own lane: queued cars and any wreckage.
		var strip := _strip(c)
		for o: Car in cars:
			if o == c:
				continue
			if not o.wreck and o.ap != c.ap:
				continue
			var r := _rect(o)
			if not strip.intersects(r):
				continue
			var g := _gap(front, c.dir, r)
			if g < -CAR_L:
				continue
			target = minf(target, sqrt(2.0 * DECEL * maxf(g - 8.0, 0.0)))

		# The raccoon in the lane ahead: brake for it. Braking is capped (see below),
		# so a fast car that's already close can't stop in time and still bonks.
		if yield_raccoon and r_stun <= 0.0:
			var rr := Rect2(r_pos - Vector2.ONE * RACCOON_R, Vector2.ONE * RACCOON_R * 2.0)
			if strip.grow(RACCOON_R - 6.0).intersects(rr):
				var g := _gap(front, c.dir, rr)
				if g >= -CAR_L / 2.0:
					target = minf(target, sqrt(2.0 * DECEL * maxf(g - 6.0, 0.0)))

		if freeze_t > 0.0:
			c.speed = maxf(0.0, c.speed - 900.0 * dt)
		elif c.speed < target:
			c.speed = minf(target, c.speed + ACCEL * dt)
		else:
			c.speed = maxf(target, c.speed - DECEL * 2.0 * dt)
		c.pos += c.dir * c.speed * dt

		# Waiting and the waiting penalty.
		if c.speed < 8.0 and freeze_t <= 0.0:
			c.wait += dt
		elif c.speed > 40.0:
			c.wait = maxf(0.0, c.wait - dt * 2.0)
		if c.wait >= c.patience * 0.5:
			if penalty == Pen.ANGER:
				anger += dt * 6.0
		if c.wait >= c.patience:
			match penalty:
				Pen.RUN:
					if not c.passed_line and dist < 14.0 and not c.running:
						c.running = true
						_float("RUNS IT!", c.pos + Vector2(0, -24), Color.ORANGE)
				Pen.COMBO:
					if combo > 0:
						_float("COMBO LOST", c.pos + Vector2(0, -24), Color.ORANGE)
					combo = 0
					c.wait = 0.0
					c.patience = randf_range(PATIENCE_MIN, PATIENCE_MAX)

		# Left the screen safely.
		if c.pos.x < -60 or c.pos.x > W + 60 or c.pos.y < -60 or c.pos.y > H + 60:
			throughput += 1
			combo += 1
			score += 10 * (1 + combo / 5)
			continue
		keep.append(c)
	cars = keep
	if penalty == Pen.ANGER:
		anger = maxf(0.0, anger - dt * 2.0)


func _check_crashes() -> void:
	var n := cars.size()
	for i in n:
		var a: Car = cars[i]
		var ra := _rect(a).grow(-2.0)
		for j in range(i + 1, n):
			var b: Car = cars[j]
			if a.wreck and b.wreck:
				continue
			if ra.intersects(_rect(b).grow(-2.0)):
				_crash(a, b)
	# Cars bonk the raccoon.
	if r_stun <= 0.0:
		for c: Car in cars:
			if not c.wreck and c.speed > 30.0 and _rect(c).grow(RACCOON_R - 4.0).has_point(r_pos):
				r_stun = 0.8
				r_knock = c.dir * 420.0
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
	_float("CRASH!", mid + Vector2(0, -20), Color.ORANGE_RED)
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


func _check_gridlock(dt: float) -> void:
	for a: Approach in aps:
		if a.blocked_t >= GRIDLOCK_BLOCK_TIME:
			gridlocked = true
			gridlock_reason = "the %s approach backed up to the edge" % a.label
	if penalty == Pen.ANGER and anger >= 100.0:
		gridlocked = true
		gridlock_reason = "the drivers lost it"


# --- draw -------------------------------------------------------------------

func _text(s: String, pos: Vector2, size: int, color: Color, center := false) -> void:
	if center:
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		pos.x -= w / 2.0
	draw_string(font, pos + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.7))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw() -> void:
	draw_rect(Rect2(-40, -40, W + 80, H + 80), Color(0.2, 0.36, 0.2))
	var road := Color(0.28, 0.28, 0.3)
	draw_rect(Rect2(C.x - ROAD / 2, -40, ROAD, H + 80), road)
	draw_rect(Rect2(-40, C.y - ROAD / 2, W + 80, ROAD), road)
	# Centre dashes (outside the box).
	var y := -20.0
	while y < H + 20:
		if absf(y - C.y) > ROAD / 2 + 10:
			draw_line(Vector2(C.x, y), Vector2(C.x, y + 14), Color(0.9, 0.8, 0.2), 2.0)
		y += 28.0
	var x := -20.0
	while x < W + 20:
		if absf(x - C.x) > ROAD / 2 + 10:
			draw_line(Vector2(x, C.y), Vector2(x + 14, C.y), Color(0.9, 0.8, 0.2), 2.0)
		x += 28.0

	# Stop lines and signal lamps.
	for i in aps.size():
		var a: Approach = aps[i]
		var perp := Vector2(-a.dir.y, a.dir.x)
		var p0 := a.stop_point + perp * (LANE - 2)
		var p1 := a.stop_point - perp * (LANE - 2)
		draw_line(p0, p1, Color.WHITE, 3.0)
		var lamp := a.stop_point - a.dir * 8.0 - perp * (LANE + 22.0)
		draw_circle(lamp, 9.0, Color.ORANGE if a.yellow_t > 0.0 else (Color.GREEN if a.go else Color.RED))
		if i == r_target:
			draw_arc(lamp, 14.0, 0, TAU, 24, Color.YELLOW, 3.0)
			var box := Rect2(a.stop_point, Vector2.ZERO).expand(a.stop_point - a.dir * 90.0)
			box = box.grow_individual(12, 12, 12, 12) if true else box
			draw_rect(box, Color(1, 1, 0, 0.12))
			draw_dashed_line(r_pos, lamp, Color(1, 1, 0, 0.5), 2.0, 6.0)

	# Cars.
	for c: Car in cars:
		var rot := c.dir.angle() + (c.wreck_rot if c.wreck else 0.0)
		draw_set_transform(c.pos, rot)
		var body := c.color.darkened(0.55) if c.wreck else c.color
		draw_rect(Rect2(-CAR_L / 2, -CAR_W / 2, CAR_L, CAR_W), body)
		draw_rect(Rect2(CAR_L / 2 - 12, -CAR_W / 2 + 3, 6, CAR_W - 6), Color(0.15, 0.2, 0.3))
		if c.wreck:
			draw_line(Vector2(-10, -7), Vector2(10, 7), Color.BLACK, 3.0)
			draw_line(Vector2(-10, 7), Vector2(10, -7), Color.BLACK, 3.0)
		elif c.running:
			draw_rect(Rect2(-CAR_L / 2, -CAR_W / 2, CAR_L, CAR_W), Color.ORANGE, false, 2.0)
		elif c.boosted:
			draw_line(Vector2(-CAR_L / 2 - 8, -5), Vector2(-CAR_L / 2 - 2, -5), Color.WHITE, 2.0)
			draw_line(Vector2(-CAR_L / 2 - 10, 5), Vector2(-CAR_L / 2 - 2, 5), Color.WHITE, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0)
		if not c.wreck and not c.running and c.wait > 0.6:
			# Patience ring: fills green -> red; last WARN_TIME seconds flash with "!!".
			var k := clampf(c.wait / c.patience, 0.0, 1.0)
			var ring := Color(minf(1.0, k * 2.0), minf(1.0, 2.0 - k * 2.0), 0)
			draw_arc(c.pos, 17.0, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 5.0)
			draw_arc(c.pos, 17.0, -PI / 2, -PI / 2 + TAU * k, 24, ring, 4.0)
			var left := c.patience - c.wait
			if left <= WARN_TIME:
				if fmod(elapsed * 6.0, 1.0) < 0.5:
					draw_set_transform(c.pos, c.dir.angle())
					draw_rect(Rect2(-CAR_L / 2 - 3, -CAR_W / 2 - 3, CAR_L + 6, CAR_W + 6), Color.RED, false, 3.0)
					draw_set_transform(Vector2.ZERO, 0.0)
				_text("!!", c.pos + Vector2(-6, -26), 18, Color.RED)
			elif k >= 0.5:
				_text("HONK", c.pos + Vector2(-16, -26), 12, Color.YELLOW)
		if c.wreck and not tow_enabled and not c.towed:
			var left := 1.0 - c.wreck_t / WRECK_AUTOCLEAR
			draw_arc(c.pos, 8.0, -PI / 2, -PI / 2 + TAU * left, 16, Color.WHITE, 2.0)

	# Raccoon.
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
	draw_arc(r_pos, RACCOON_R + 3.0, 0, TAU, 24, Color(1, 0.6, 0.1), 2.0)  # hi-vis vest
	if r_stun > 0.0:
		for k in 3:
			var ang := elapsed * 8.0 + k * TAU / 3.0
			_text("*", r_pos + Vector2(cos(ang), sin(ang)) * 18.0 + Vector2(-4, 4), 16, Color.YELLOW)
	if r_dash_t > 0.0:
		draw_line(r_pos, r_pos - r_dash_dir * 30.0, Color(1, 1, 1, 0.6), 6.0)
	if whistle_ring > 0.0:
		draw_arc(r_pos, (0.5 - whistle_ring) * 1600.0, 0, TAU, 64, Color(1, 1, 1, whistle_ring * 2.0), 4.0)
	if freeze_t > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.6, 0.8, 1.0, 0.12))

	for f in floats:
		var col: Color = f.color
		col.a = clampf(f.t * 2.0, 0.0, 1.0)
		_text(f.text, f.pos, 20, col, true)

	_draw_hud()


func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 330, 176), Color(0, 0, 0, 0.55))
	_text("PROTOTYPE: crossing guard (#5)", Vector2(10, 22), 14, Color(1, 1, 1, 0.6))
	_text("Score %d" % score, Vector2(10, 52), 26, Color.WHITE)
	_text("Combo %d  (x%d)" % [combo, 1 + combo / 5], Vector2(10, 78), 18, Color.WHITE)
	_text("Through %d   Crashes %d" % [throughput, crashes], Vector2(10, 100), 16, Color.WHITE)
	_text("Rush hour %d   %ds" % [int(elapsed / 20.0) + 1, int(elapsed)], Vector2(10, 120), 16, Color.WHITE)
	var dash_s := "ready" if r_dash_cd <= 0.0 else "%.1f" % r_dash_cd
	var wh_s := "off" if not whistle_enabled else ("ready" if whistle_cd <= 0.0 else "%.0fs" % whistle_cd)
	_text("Dash %s   Whistle %s" % [dash_s, wh_s], Vector2(10, 142), 16, Color.WHITE)
	if penalty == Pen.ANGER:
		draw_rect(Rect2(10, 152, 200, 12), Color(0.2, 0, 0))
		draw_rect(Rect2(10, 152, 2.0 * minf(anger, 100.0), 12), Color.RED)
		_text("anger", Vector2(216, 164), 12, Color.WHITE)

	var help := [
		"Move WASD/arrows/stick   Switch light J/K/Z/X (A)   Dash L/C/Shift (X)   Tow U/V (Y)   Whistle I/B (RB)   R restart",
		"Toggles: [1] Tow %s   [2] Whistle %s   [3] Wait penalty: %s   [4] Lanes start %s (restarts)   [5] Cars %s" % [
			"ON" if tow_enabled else "OFF (wreckage auto-clears in %ds)" % int(WRECK_AUTOCLEAR),
			"ON" if whistle_enabled else "OFF",
			PEN_NAMES[penalty],
			"GO" if start_go else "STOP",
			"YIELD to raccoon" if yield_raccoon else "IGNORE raccoon"],
	]
	draw_rect(Rect2(0, H - 46, W, 46), Color(0, 0, 0, 0.55))
	_text(help[0], Vector2(10, H - 27), 14, Color.WHITE)
	_text(help[1], Vector2(10, H - 8), 14, Color(1, 0.9, 0.6))

	if gridlocked:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
		_text("GRIDLOCK!", Vector2(W / 2, H / 2 - 40), 64, Color.ORANGE_RED, true)
		_text(gridlock_reason, Vector2(W / 2, H / 2), 22, Color.WHITE, true)
		_text("Score %d   Through %d   Crashes %d   %ds" % [score, throughput, crashes, int(elapsed)], Vector2(W / 2, H / 2 + 36), 22, Color.WHITE, true)
		_text("R / Start to run again", Vector2(W / 2, H / 2 + 76), 18, Color(1, 1, 1, 0.7), true)

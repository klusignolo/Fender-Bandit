# PROTOTYPE, throw away: greybox for "Does crossing-guard traffic direction feel fun?" (issue #5),
# extended for "How should turn lanes work?" (issue #9) and "What stops the light rhythm
# from going stale?" (issue #14).
# Everything lives in this one script and is drawn with _draw(). No polish, no tests.
extends Node2D

const W := 1280.0
const H := 720.0
const C := Vector2(640, 360)
const LW := 30.0            # lane width; each road is 4 lanes: out, out | turn, through
const ROAD := 120.0         # road width (four lanes)
const STOP_D := 72.0        # stop line distance from the centre
const TURN_SHARE := 0.45    # turn lanes spawn this fraction as often as through lanes
const TURN_SPEED := 0.7     # turning cars slow to this fraction of base speed in the arc
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
const PATIENCE_RINGS := 3     # ring 1 full: honk, ring 2: honk, ring 3: run the red
const PATIENCE_MIN := 12.0   # total across all rings
const PATIENCE_MAX := 15.0
const WARN_TIME := 2.0      # seconds of flashing before a driver runs the Stop

enum Pen { RUN, COMBO, ANGER }
const PEN_NAMES := ["impatient drivers RUN the Stop", "honks BREAK the Combo", "honks fill an ANGER meter"]

# Turn-lane models under test (key 6).
enum Turn { OFF, SHARED_YIELD, SHARED_BLIND, OWN_ARROW }
const TURN_NAMES := ["OFF (plain 4-way)", "SHARED light, turners yield to oncoming", "SHARED light, turners don't look", "OWN arrow light (protected)"]
# How the Raccoon reaches an arrow light (key 7, OWN_ARROW only).
enum Aim { NEAREST, BUTTON }
const AIM_NAMES := ["nearest lamp (one Switch)", "Switch = straight, RB = its arrow"]
# Traffic shapes under test (key 8), issue #14: does uneven flow break the fixed N/S <-> E/W cycle?
enum Flow { EVEN, SWELL, BURSTS, BOTH }
const FLOW_NAMES := ["EVEN (old)", "SWELL (one heavy road, shifts)", "BURSTS (platoons)", "SWELL + BURSTS"]
const DIR_NAMES := ["N", "S", "W", "E"]
const SWELL_HEAVY := 2.0      # spawn rate multiplier on the heavy road
const SWELL_LIGHT := 0.67     # ...and on the other three (total stays about the same)
const SWELL_MIN := 20.0       # seconds between shifts of the heavy road
const SWELL_MAX := 30.0
const SHIFT_WARN := 4.0       # the next heavy road flashes this long before it takes over
const BURST_MIN := 8.0        # seconds between platoons
const BURST_MAX := 14.0
const BURST_WARN := 2.0
const BURST_GAP := 0.5        # seconds between cars inside a platoon
const BURST_TURN := 0.3       # share of platoons that come down a turn lane

# One lane approaching the intersection. Lanes come in pairs: index 2k is the
# through lane, 2k+1 its left-turn lane (twin).
class Approach:
	var label: String
	var dir: Vector2
	var spawn: Vector2
	var stop_point: Vector2
	var lamp: Vector2
	var turn := false
	var twin := -1
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
	var honks := 0
	var running := false
	var boosted := false
	var passed_line := false
	var wreck := false
	var wreck_t := 0.0
	var wreck_rot := 0.0
	var towed := false
	var turn := false
	var arc_s := -1.0       # distance travelled along the turn arc; <0 before it starts
	var turned := false
	var brave := 1.8        # smallest oncoming gap (seconds) this driver will turn into
	var gunned := false     # out of patience: turns regardless

# Dev toggles (keys 1-7)
var turn_mode: int = Turn.OWN_ARROW  # decided in #9
var aim_mode: int = Aim.BUTTON
var tow_enabled := true
var whistle_enabled := false  # playtest: never reached for it
var penalty: int = Pen.RUN
var start_go := false
var yield_raccoon := true
var flow_mode: int = Flow.BOTH

var heavy := 0          # road index (DIR_NAMES) that gets the heavy flow
var heavy_next := 1
var heavy_t := 0.0      # seconds until heavy_next takes over
var burst_t := 0.0      # seconds until the next platoon leaves
var burst_lane := -1    # approach the next or current platoon uses; -1 none
var burst_left := 0     # cars still to come in the current platoon

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
		if a.begins_with("--turn="):
			turn_mode = int(a.substr(7))
		if a.begins_with("--flow="):
			flow_mode = int(a.substr(7))
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
	_bind("whistle", [], [])  # cut in #5
	_bind("arrow", [KEY_I, KEY_B], [JOY_BUTTON_RIGHT_SHOULDER])
	_bind("restart", [KEY_R], [JOY_BUTTON_START])
	_bind("t_tow", [KEY_1], [])
	_bind("t_whistle", [KEY_2], [])
	_bind("t_penalty", [KEY_3], [JOY_BUTTON_BACK])
	_bind("t_start", [KEY_4], [])
	_bind("t_yield", [KEY_5], [])
	_bind("t_turn", [KEY_6], [JOY_BUTTON_LEFT_SHOULDER])
	_bind("t_aim", [KEY_7], [])
	_bind("t_flow", [KEY_8], [])
	_axis("t_flow", JOY_AXIS_TRIGGER_LEFT, 1.0)


func _restart() -> void:
	aps.clear()
	for dl in [["N", Vector2.DOWN], ["S", Vector2.UP], ["W", Vector2.RIGHT], ["E", Vector2.LEFT]]:
		var d: Vector2 = dl[1]
		var right := Vector2(-d.y, d.x)
		var half := H / 2.0 if absf(d.y) > 0.5 else W / 2.0
		for turn in [false, true]:
			var off := LW * (0.5 if turn else 1.5)
			var stop := C - d * STOP_D + right * off
			var lamp := stop - d * 10.0 + (right * -(LW / 2.0 + 14.0) if turn else right * (LW / 2.0 + 14.0))
			_add_ap(dl[0] + ("-left" if turn else ""), d, C - d * (half + 24.0) + right * off, stop)
			aps[-1].turn = turn
			aps[-1].lamp = lamp
			aps[-1].twin = aps.size() - (2 if turn else 0)
	for i in range(0, aps.size(), 2):
		aps[i].twin = i + 1
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
	heavy = randi() % 4
	heavy_next = _other_road(heavy)
	heavy_t = randf_range(SWELL_MIN, SWELL_MAX)
	burst_t = randf_range(4.0, 7.0)
	burst_lane = -1
	burst_left = 0


func _other_road(d: int) -> int:
	return (d + 1 + randi() % 3) % 4


func _swells() -> bool:
	return flow_mode == Flow.SWELL or flow_mode == Flow.BOTH


func _bursts() -> bool:
	return flow_mode == Flow.BURSTS or flow_mode == Flow.BOTH


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


# Where a road enters the screen, between its two incoming lanes.
func _edge(d: int) -> Vector2:
	var a: Approach = aps[d * 2]
	var half := H / 2.0 if absf(a.dir.y) > 0.5 else W / 2.0
	var inset := 40.0 if a.dir.y > 0.5 else (110.0 if a.dir.y < -0.5 else 80.0)  # clear the help bar
	return C - a.dir * (half - inset) + Vector2(-a.dir.y, a.dir.x) * LW


func _on_road(p: Vector2) -> bool:
	return absf(p.x - C.x) < ROAD / 2.0 + 10.0 or absf(p.y - C.y) < ROAD / 2.0 + 10.0


# Which lane's Light a lane obeys. With a shared light, the turn lane follows its through lane.
func _light_idx(i: int) -> int:
	if turn_mode == Turn.OWN_ARROW:
		return i
	return i - i % 2


# Lanes that carry their own lamp the Raccoon can target.
func _has_lamp(i: int) -> bool:
	if not aps[i].turn:
		return true
	return turn_mode == Turn.OWN_ARROW and aim_mode == Aim.NEAREST


func _switch(i: int) -> void:
	var a: Approach = aps[i]
	if a.yellow_t > 0.0:
		return  # already on its way to red
	var at := a.stop_point - a.dir * 30.0
	if a.go:
		a.yellow_t = YELLOW_TIME
		_float("YELLOW", at, Color.ORANGE)
	else:
		a.go = true
		for c: Car in cars:
			if _light_idx(c.ap) == i and not c.passed_line and not c.wreck:
				c.boosted = true
		_float("GREEN ARROW!" if a.turn else "GREEN!", at, Color.GREEN)


# Oncoming through traffic leaves a big enough gap for this turner to cut across.
func _gap_ok(c: Car) -> bool:
	var oi := ((c.ap / 2) ^ 1) * 2
	var ol: Approach = aps[_light_idx(oi)]
	var thr := c.brave * (1.0 - 0.6 * clampf(c.wait / c.patience, 0.0, 1.0))
	for o: Car in cars:
		if o.ap != oi or o.wreck:
			continue
		# The turn arc crosses the oncoming through lane just past the centre.
		var dcon := (C - _front(o)).dot(o.dir) - LW * 0.6
		if dcon < -CAR_L - 12.0:
			continue  # already cleared the turner's path
		if dcon <= 0.0:
			return false  # in the way right now
		if not o.passed_line and not o.running and (not ol.go or ol.yellow_t > 0.0):
			continue  # will stop at its light
		if dcon / maxf(o.speed, 25.0) < thr:
			return false
	return true


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
		_update_flow(dt)
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
	if Input.is_action_just_pressed("t_turn"):
		turn_mode = (turn_mode + 1) % 4
		_restart()
	if Input.is_action_just_pressed("t_aim"):
		aim_mode = (aim_mode + 1) % 2
	if Input.is_action_just_pressed("t_flow"):
		flow_mode = (flow_mode + 1) % 4
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

	# Target: nearest lamp in range, biased toward the way the raccoon faces.
	r_target = -1
	var best := INF
	for i in aps.size():
		if not _has_lamp(i):
			continue
		var d: float = r_pos.distance_to(aps[i].lamp)
		if d > SIGNAL_RANGE:
			continue
		var s: float = d - 60.0 * r_facing.dot((aps[i].lamp - r_pos).normalized())
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
		_switch(r_target)
	if r_stun <= 0.0 and r_target >= 0 and Input.is_action_just_pressed("arrow") \
			and turn_mode == Turn.OWN_ARROW and aim_mode == Aim.BUTTON:
		_switch(aps[r_target].twin)

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


# The heavy road shifts every so often; platoons leave from one lane at a time.
func _update_flow(dt: float) -> void:
	if _swells():
		heavy_t -= dt
		if heavy_t <= 0.0:
			heavy = heavy_next
			heavy_next = _other_road(heavy)
			heavy_t = randf_range(SWELL_MIN, SWELL_MAX)
			_float("RUSH FROM %s" % DIR_NAMES[heavy], _edge(heavy) + Vector2(0, -20), Color.ORANGE)
	if _bursts() and burst_left <= 0:
		burst_t -= dt
		if burst_t <= BURST_WARN and burst_lane < 0:
			var turn := turn_mode != Turn.OFF and randf() < BURST_TURN
			burst_lane = (randi() % 4) * 2 + (1 if turn else 0)
		if burst_t <= 0.0:
			burst_left = randi_range(4, 6)
			aps[burst_lane].spawn_t = 0.0
			burst_t = randf_range(BURST_MIN, BURST_MAX)


func _update_spawns(dt: float) -> void:
	var interval := maxf(1.0, 3.2 - elapsed * 0.008)  # peaks at ~4.5 min
	for i in aps.size():
		var a: Approach = aps[i]
		if a.turn and turn_mode == Turn.OFF:
			continue
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
		var mult := 1.0
		if _swells():
			mult = SWELL_HEAVY if i / 2 == heavy else SWELL_LIGHT
		a.spawn_t = interval * randf_range(0.6, 1.4) / (TURN_SHARE if a.turn else 1.0) / mult
		if i == burst_lane and burst_left > 0:
			burst_left -= 1
			if burst_left > 0:
				a.spawn_t = BURST_GAP
			else:
				burst_lane = -1
		var c := Car.new()
		c.ap = i
		c.turn = a.turn
		c.brave = randf_range(1.2, 2.4)
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
		var lt: Approach = aps[_light_idx(c.ap)]
		var front := _front(c)
		var target := BASE_SPEED * rush * (GO_BOOST if c.boosted else 1.0)

		# Stop line.
		var dist := (a.stop_point - front).dot(a.dir)
		if not c.passed_line:
			if dist < 0.0:
				c.passed_line = true
				if lt.go:
					c.boosted = true
			elif (not lt.go or lt.yellow_t > 0.0) and not c.running:
				# On yellow, drivers who'd have to brake hard push through instead.
				var need := c.speed * c.speed / (4.0 * DECEL) * (2.0 if lt.yellow_t > 0.0 else 1.0)
				if dist < need - 1.0 and c.speed > 40.0:
					c.passed_line = true  # too close to stop: commits
				else:
					target = minf(target, sqrt(2.0 * DECEL * maxf(dist - 2.0, 0.0)))

		# Left turners pull up to the turn point, then wait for a gap in oncoming traffic
		# (shared light only; with its own arrow the turn is protected, so they just go).
		# A turner caught in the box when the light drops clears out regardless.
		var hold := false
		if c.turn and c.arc_s < 0.0:
			var ds := (a.stop_point - c.pos).dot(a.dir)
			var green := lt.go and lt.yellow_t <= 0.0
			if turn_mode == Turn.SHARED_YIELD and (green or not c.passed_line) and not c.gunned and not c.running:
				if c.wait >= c.patience and c.passed_line:
					c.gunned = true
					_float("GUNS IT!", c.pos + Vector2(0, -24), Color.ORANGE)
				elif not _gap_ok(c):
					hold = true
					target = minf(target, sqrt(2.0 * DECEL * maxf(ds - 1.0, 0.0)))
			if ds <= 0.0:
				if hold:
					c.pos = a.stop_point
					c.speed = 0.0
				elif c.passed_line:
					c.arc_s = -ds
		if c.turn and c.arc_s >= 0.0 and not c.turned:
			target = minf(target, BASE_SPEED * rush * TURN_SPEED)

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
		# A slow car won't pull into a raccoon touching its nose; keeps yielding after a bonk.
		if yield_raccoon:
			var rr := Rect2(r_pos - Vector2.ONE * RACCOON_R, Vector2.ONE * RACCOON_R * 2.0)
			if strip.grow(RACCOON_R - 6.0).intersects(rr):
				var g := _gap(front, c.dir, rr)
				if g >= -CAR_L / 2.0 or (g >= -CAR_L and c.speed < 40.0):
					target = minf(target, sqrt(2.0 * DECEL * maxf(g - 6.0, 0.0)))

		if freeze_t > 0.0:
			c.speed = maxf(0.0, c.speed - 900.0 * dt)
		elif c.speed < target:
			c.speed = minf(target, c.speed + ACCEL * dt)
		else:
			c.speed = maxf(target, c.speed - DECEL * 2.0 * dt)
		if c.turn and c.arc_s >= 0.0 and not c.turned:
			# Quarter circle from the turn lane's stop point into the cross road's inner lane.
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

		# Waiting and the waiting penalty.
		if c.speed < 8.0 and freeze_t <= 0.0:
			c.wait += dt
		elif c.speed > 40.0:
			c.wait = maxf(0.0, c.wait - dt * 2.0)
		var ring_i := int(c.wait / (c.patience / PATIENCE_RINGS))
		if ring_i > c.honks and ring_i < PATIENCE_RINGS:
			_float("HONK!" if ring_i == 1 else "HONK HONK!", c.pos + Vector2(0, -24), Color.YELLOW)
		c.honks = mini(ring_i, PATIENCE_RINGS - 1)
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
			if (a.wreck and b.wreck) or a.towed or b.towed:  # a towed wreck is a ghost
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
	# Centre line (yellow, double) and lane dividers (white dashes), outside the box.
	var yel := Color(0.9, 0.8, 0.2)
	var edge := ROAD / 2 + 4
	for s in [-1.0, 1.0]:
		draw_line(Vector2(C.x + s * 2, -40), Vector2(C.x + s * 2, C.y - edge), yel, 2.0)
		draw_line(Vector2(C.x + s * 2, C.y + edge), Vector2(C.x + s * 2, H + 40), yel, 2.0)
		draw_line(Vector2(-40, C.y + s * 2), Vector2(C.x - edge, C.y + s * 2), yel, 2.0)
		draw_line(Vector2(C.x + edge, C.y + s * 2), Vector2(W + 40, C.y + s * 2), yel, 2.0)
		var y := -20.0
		while y < H + 20:
			if absf(y - C.y) > edge:
				draw_line(Vector2(C.x + s * LW, y), Vector2(C.x + s * LW, y + 14), Color(1, 1, 1, 0.6), 2.0)
			y += 28.0
		var x := -20.0
		while x < W + 20:
			if absf(x - C.x) > edge:
				draw_line(Vector2(x, C.y + s * LW), Vector2(x + 14, C.y + s * LW), Color(1, 1, 1, 0.6), 2.0)
			x += 28.0

	# Stop lines, turn arrows painted in the lane, and signal lamps.
	for i in aps.size():
		var a: Approach = aps[i]
		var perp := Vector2(-a.dir.y, a.dir.x)
		if a.turn and turn_mode == Turn.OFF:
			continue
		draw_line(a.stop_point + perp * (LW / 2 - 1), a.stop_point - perp * (LW / 2 - 1), Color.WHITE, 3.0)
		if a.turn:
			var lf := -perp
			var b := a.stop_point - a.dir * 60.0
			var k := b + a.dir * 18.0
			draw_polyline(PackedVector2Array([b - a.dir * 8.0, k, k + lf * 8.0]), Color(1, 1, 1, 0.8), 3.0)
			draw_colored_polygon(PackedVector2Array([k + lf * 14.0, k + lf * 7.0 + a.dir * 6.0, k + lf * 7.0 - a.dir * 6.0]), Color(1, 1, 1, 0.8))
	for i in aps.size():
		var a: Approach = aps[i]
		if a.turn and turn_mode != Turn.OWN_ARROW:
			continue
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
		draw_arc(t.lamp, 14.0, 0, TAU, 24, Color.YELLOW, 3.0)
		draw_dashed_line(r_pos, t.lamp, Color(1, 1, 0, 0.5), 2.0, 6.0)
		for j in aps.size():
			if _light_idx(j) == r_target and not (aps[j].turn and turn_mode == Turn.OFF):
				var sp: Vector2 = aps[j].stop_point
				draw_rect(Rect2(sp, Vector2.ZERO).expand(sp - aps[j].dir * 90.0).grow(LW / 2 - 2), Color(1, 1, 0, 0.12))
		if turn_mode == Turn.OWN_ARROW and aim_mode == Aim.BUTTON:
			var tw: Approach = aps[t.twin]
			draw_arc(tw.lamp, 14.0, 0, TAU, 24, Color(0.4, 0.8, 1.0), 2.0)
			_text("RB", tw.lamp + Vector2(-9, -16), 13, Color(0.4, 0.8, 1.0))

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
		if c.turn and not c.turned and not c.wreck and fmod(elapsed * 3.0, 1.0) < 0.5:
			# Left blinker, front and back (local -y is the driver's left).
			draw_rect(Rect2(CAR_L / 2 - 6, -CAR_W / 2 - 2, 6, 5), Color(1, 0.65, 0))
			draw_rect(Rect2(-CAR_L / 2, -CAR_W / 2 - 2, 6, 5), Color(1, 0.65, 0))
		draw_set_transform(Vector2.ZERO, 0.0)
		if not c.wreck and not c.running and c.wait > 0.6:
			# Patience rings: each fills in turn (yellow, orange, red), pips count the
			# ones used up; last WARN_TIME seconds flash with "!!".
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
			var left := c.patience - c.wait
			if left <= WARN_TIME:
				if fmod(elapsed * 6.0, 1.0) < 0.5:
					draw_set_transform(c.pos, c.dir.angle())
					draw_rect(Rect2(-CAR_L / 2 - 3, -CAR_W / 2 - 3, CAR_L + 6, CAR_W + 6), Color.RED, false, 3.0)
					draw_set_transform(Vector2.ZERO, 0.0)
				_text("!!", c.pos + Vector2(-6, -26), 18, Color.RED)
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

	_draw_flow()

	for f in floats:
		var col: Color = f.color
		col.a = clampf(f.t * 2.0, 0.0, 1.0)
		_text(f.text, f.pos, 20, col, true)

	_draw_hud()


func _chevrons(p: Vector2, dir: Vector2, n: int, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	for k in n:
		var tip := p + dir * (k * 12.0 - (n - 1) * 6.0)
		draw_polyline(PackedVector2Array([tip - dir * 7.0 + side * 11.0, tip, tip - dir * 7.0 - side * 11.0]), col, 4.0)


# Telegraphs at the road edges: the heavy road, the road about to turn heavy, and platoons.
func _draw_flow() -> void:
	var blink := fmod(elapsed * 4.0, 1.0) < 0.5
	for d in 4:
		var a: Approach = aps[d * 2]
		var p := _edge(d)
		var out := Vector2(-a.dir.y, a.dir.x) * 62.0
		var tags: Array = []
		if _swells() and d == heavy:
			_chevrons(p, a.dir, 3, Color.ORANGE)
			tags.append(["HEAVY", Color.ORANGE])
		elif _swells() and d == heavy_next and heavy_t <= SHIFT_WARN:
			if blink:
				_chevrons(p, a.dir, 3, Color(1, 0.65, 0, 0.6))
			tags.append(["RUSH IN %d" % ceili(heavy_t), Color(1, 0.8, 0.4)])
		if burst_lane >= 0 and burst_lane / 2 == d:
			var bl: Approach = aps[burst_lane]
			var tag := "PLATOON" + (" (LEFT)" if bl.turn else "")
			if burst_left > 0 or blink:
				draw_circle(bl.spawn + a.dir * 60.0, 9.0, Color.WHITE)
			tags.append([tag if burst_left > 0 else tag + "!", Color.WHITE])
		for t in tags.size():
			_text(tags[t][0], p + out + Vector2(0, 5 + t * 18 - (tags.size() - 1) * 9), 15, tags[t][1], true)


func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 330, 176), Color(0, 0, 0, 0.55))
	_text("PROTOTYPE: crossing guard (#5), turn lanes (#9), traffic (#14)", Vector2(10, 22), 14, Color(1, 1, 1, 0.6))
	_text("Score %d" % score, Vector2(10, 52), 26, Color.WHITE)
	_text("Combo %d  (x%d)" % [combo, 1 + combo / 5], Vector2(10, 78), 18, Color.WHITE)
	_text("Through %d   Crashes %d" % [throughput, crashes], Vector2(10, 100), 16, Color.WHITE)
	_text("Rush hour %d   %ds" % [int(elapsed / 20.0) + 1, int(elapsed)], Vector2(10, 120), 16, Color.WHITE)
	var dash_s := "ready" if r_dash_cd <= 0.0 else "%.1f" % r_dash_cd
	_text("Dash %s" % dash_s, Vector2(10, 142), 16, Color.WHITE)
	if penalty == Pen.ANGER:
		draw_rect(Rect2(10, 152, 200, 12), Color(0.2, 0, 0))
		draw_rect(Rect2(10, 152, 2.0 * minf(anger, 100.0), 12), Color.RED)
		_text("anger", Vector2(216, 164), 12, Color.WHITE)

	var arrow_btn := turn_mode == Turn.OWN_ARROW and aim_mode == Aim.BUTTON
	var help := [
		"Move WASD/arrows/stick   Switch light J/K/Z/X (A)   Dash L/C/Shift (X)   Tow U/V (Y)%s   R restart" % ("   Arrow I/B (RB)" if arrow_btn else ""),
		"Toggles: [1] Tow %s   [3] Wait penalty: %s   [4] Lanes start %s (restarts)   [5] Cars %s" % [
			"ON" if tow_enabled else "OFF (wreckage auto-clears in %ds)" % int(WRECK_AUTOCLEAR),
			PEN_NAMES[penalty],
			"GO" if start_go else "STOP",
			"YIELD to raccoon" if yield_raccoon else "IGNORE raccoon"],
		"[6 / LB] Turn lanes: %s (restarts)%s" % [TURN_NAMES[turn_mode],
			("   [7] Arrow aim: %s" % AIM_NAMES[aim_mode]) if turn_mode == Turn.OWN_ARROW else ""],
		"[8 / LT] Traffic: %s (restarts)" % FLOW_NAMES[flow_mode],
	]
	draw_rect(Rect2(0, H - 83, W, 83), Color(0, 0, 0, 0.55))
	_text(help[0], Vector2(10, H - 64), 14, Color.WHITE)
	_text(help[1], Vector2(10, H - 45), 14, Color(1, 0.9, 0.6))
	_text(help[2], Vector2(10, H - 26), 14, Color(0.6, 1, 0.8))
	_text(help[3], Vector2(10, H - 7), 14, Color(0.7, 0.85, 1))

	if gridlocked:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
		_text("GRIDLOCK!", Vector2(W / 2, H / 2 - 40), 64, Color.ORANGE_RED, true)
		_text(gridlock_reason, Vector2(W / 2, H / 2), 22, Color.WHITE, true)
		_text("Score %d   Through %d   Crashes %d   %ds" % [score, throughput, crashes, int(elapsed)], Vector2(W / 2, H / 2 + 36), 22, Color.WHITE, true)
		_text("R / Start to run again", Vector2(W / 2, H / 2 + 76), 18, Color(1, 1, 1, 0.7), true)

class_name Traffic
extends RefCounted
## The traffic simulation (ADR 0001): Lights and Cars on a RoadNet, stepped at a fixed 60 Hz.
## Nodes only draw it. Inputs: step(), switch(), set_raccoon(). Outputs: the public state below and
## the signals. Ported from the greybox (prototypes/turners on prototype/crossing-guard @ 667fa3a).

signal car_spawned(car: Car)
signal car_exited(car: Car)
signal light_changed(light: Light)

const TICK_HZ := 60
const DT := 1.0 / TICK_HZ

var net: RoadNet
var lights: Array[Light] = []
var cars: Array[Car] = []
var time := 0.0  # seconds simulated
var raccoon_position := Vector2.ZERO
var raccoon_dashing := false

# Stage knobs; Stages (#29) sets these per stage. Stage 1 until then.
var k_gap: float = Tuning.K_GAP[0]
var k_speed: float = Tuning.K_SPEED[0]

var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _spawn_left: Array[float] = []  # per approach: seconds until its next car is due
var _due: Array[int] = []  # per approach: cars due that haven't found room to drive on yet


func _init(seed_value: int) -> void:
	_rng.seed = seed_value
	net = RoadNet.new()
	for i in net.approaches.size():
		lights.append(Light.new(i, net.approaches[i]))
		_spawn_left.append(_rng.randf_range(Tuning.FIRST_SPAWN[0], Tuning.FIRST_SPAWN[1]))
		_due.append(0)


## The Raccoon's state this tick. Nothing reacts to it yet (Yield is #23).
func set_raccoon(position: Vector2, dashing: bool) -> void:
	raccoon_position = position
	raccoon_dashing = dashing


## Switch a Light: Red turns Green and waves its queue on, Green turns Yellow. Yellow ignores it.
func switch(light: Light) -> void:
	match light.state:
		Light.State.RED:
			light.state = Light.State.GREEN
			for c in cars:
				if c.light == light and not c.passed_line:
					c.boosted = true
		Light.State.GREEN:
			light.state = Light.State.YELLOW
			light.yellow_left = Tuning.YELLOW_TIME
		Light.State.YELLOW:
			return
	light_changed.emit(light)


func step() -> void:
	time += DT
	for l in lights:
		if l.state == Light.State.YELLOW:
			l.yellow_left -= DT
			if l.yellow_left <= 0.0:
				l.state = Light.State.RED
				light_changed.emit(l)
	_spawn()
	_drive()


# Every car that's due joins its entry's queue, then drives on as soon as the road has room.
func _spawn() -> void:
	for i in net.approaches.size():
		var a := net.approaches[i]
		if not a.entry:
			continue
		_spawn_left[i] -= DT
		if _spawn_left[i] <= 0.0:
			_spawn_left[i] += k_gap * _rng.randf_range(Tuning.SPAWN_JITTER[0], Tuning.SPAWN_JITTER[1])
			_due[i] += 1
		if _due[i] <= 0 or not _entry_clear(a):
			continue
		_due[i] -= 1
		var c := Car.new(_next_id, a.routes[0], lights[i])
		_next_id += 1
		c.speed = Tuning.BASE_SPEED * Tuning.SPAWN_SPEED
		c.tint = Color.from_hsv(_rng.randf(), 0.65, 0.95)
		_place(c)
		cars.append(c)
		car_spawned.emit(c)


func _entry_clear(a: RoadNet.Approach) -> bool:
	for c in cars:
		if c.route.segment_at(c.s) == a.incoming and c.s - c.length / 2.0 < Tuning.CAR_L / 2.0 + Tuning.SPAWN_CLEAR:
			return false
	return true


func _drive() -> void:
	var keep: Array[Car] = []
	for c in cars:
		var target := Tuning.BASE_SPEED * k_speed * (Tuning.GO_BOOST if c.boosted else 1.0)
		target = minf(target, _stop_line_limit(c))
		target = minf(target, _follow_limit(c))
		if c.speed < target:
			c.speed = minf(target, c.speed + Tuning.ACCEL * DT)
		else:
			c.speed = maxf(target, c.speed - Tuning.DECEL * Tuning.HARD_BRAKE * DT)
		c.s += c.speed * DT
		if c.s >= c.route.length:
			car_exited.emit(c)
			continue
		_place(c)
		keep.append(c)
	cars = keep


# Red stops a driver at the line. A driver too close to stop even braking hard pushes through; on
# Yellow it judges the stop longer, so more push through. A car crossing on Green or Yellow is waved on.
func _stop_line_limit(c: Car) -> float:
	if c.passed_line:
		return INF
	var dist := c.line_distance
	var l := c.light
	if dist < 0.0:
		c.passed_line = true
		if l.state != Light.State.RED:
			c.boosted = true
		return INF
	if l.state == Light.State.GREEN:
		return INF
	var need := c.speed * c.speed / (2.0 * Tuning.DECEL * Tuning.HARD_BRAKE)
	if l.state == Light.State.YELLOW:
		need *= Tuning.YELLOW_CAUTION
	if dist < need - Tuning.PUSH_SLACK and c.speed > Tuning.PUSH_MIN_SPEED:
		c.passed_line = true
		return INF
	return sqrt(2.0 * Tuning.DECEL * maxf(dist - Tuning.STOP_MARGIN, 0.0))


# Slow for the nearest car ahead on any stretch of this car's own route.
func _follow_limit(c: Car) -> float:
	var front := c.s + c.length / 2.0
	var nearest := INF
	var first := c.route.index_at(c.s)
	for o in cars:
		if o == c:
			continue
		var seg := o.route.segment_at(o.s)
		for k in range(first, c.route.segments.size()):
			if c.route.segments[k] != seg:
				continue
			var gap := c.route.starts[k] + o.route.local_at(o.s) - o.length / 2.0 - front
			if gap > -o.length and gap < Tuning.LOOK:
				nearest = minf(nearest, gap)
	if nearest == INF:
		return INF
	return sqrt(2.0 * Tuning.DECEL * maxf(nearest - Tuning.FOLLOW_GAP, 0.0))


func _place(c: Car) -> void:
	c.transform = c.route.pose(c.s)
	c.line_distance = c.route.stop_s - (c.s + c.length / 2.0)

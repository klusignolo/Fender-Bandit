class_name Traffic
extends RefCounted
## The traffic simulation (ADR 0001): Lights and Cars on a RoadNet, stepped at a fixed 60 Hz.
## Nodes only draw it. Inputs: step(), switch(), set_raccoon(), tow(). Outputs: the public state below
## and the signals. Ported from the greybox (prototypes/turners on prototype/crossing-guard @ 667fa3a).

signal car_spawned(car: Car)
signal car_exited(car: Car)
signal light_changed(light: Light)
signal crashed(a: Car, b: Car, at: Vector2)  # at least one of the two is fresh Wreckage
signal towed(car: Car, off_road: bool)  # towed Wreckage dropped; off the road, it's gone from cars
signal raccoon_hit(car: Car)  # a car too fast to stop hit the Raccoon: it is stunned and knocked back

const TICK_HZ := 60
const DT := 1.0 / TICK_HZ

var net: RoadNet
var lights: Array[Light] = []
var cars: Array[Car] = []
var time := 0.0  # seconds simulated
var raccoon_position := Vector2.ZERO  # from set_raccoon; RACCOON_START until then
var raccoon_dashing := false
var towing: Car = null  # the Wreckage the Raccoon is towing
var raccoon_stun := 0.0  # seconds the Raccoon is stunned for: it can't act, and is knocked back
var raccoon_knock := Vector2.ZERO  # world px/s the Raccoon is being knocked back at; the Raccoon moves itself by it

# Stage knobs; Stages (#29) sets these per stage. Stage 1 until then.
var k_gap: float = Tuning.K_GAP[0]
var k_speed: float = Tuning.K_SPEED[0]

var _rng := RandomNumberGenerator.new()
var _next_id := 1
var _spawn_left: Array[float] = []  # per approach: seconds until its next car is due
var _due: Array[int] = []  # per approach: cars due that haven't found room to drive on yet
var _wreckage: Array[Car] = []  # this tick's Wreckage, towed or not
var _by_route: Array[Array] = []  # this tick's moving cars, by route id
var _tow_hold := Vector2.ZERO  # where the towed Wreckage trails, from the Raccoon


func _init(seed_value: int) -> void:
	_rng.seed = seed_value
	net = RoadNet.new()
	raccoon_position = net.crossings[0] + Tuning.RACCOON_START
	for i in net.approaches.size():
		lights.append(Light.new(i, net.approaches[i]))
		_spawn_left.append(_rng.randf_range(Tuning.FIRST_SPAWN[0], Tuning.FIRST_SPAWN[1]))
		_due.append(0)


## The Raccoon's state this tick. Towed Wreckage follows it, and drivers Yield to it.
func set_raccoon(position: Vector2, dashing: bool) -> void:
	raccoon_position = position
	raccoon_dashing = dashing


## The Raccoon's speed as a share of its own walk or Dash speed: slower while towing.
func raccoon_speed_scale() -> float:
	if towing == null:
		return 1.0
	return Tuning.TOW_DASH if raccoon_dashing else Tuning.TOW_SPEED


## Switch a Light: Red turns Green and waves its queue on, Green turns Yellow. Yellow ignores it. So does a stunned Raccoon.
func switch(light: Light) -> void:
	if raccoon_stun > 0.0:
		return
	match light.state:
		Light.State.RED:
			light.state = Light.State.GREEN
			for c in cars:
				if c.light == light and not c.passed_line and not c.wreckage:
					c.boosted = true
		Light.State.GREEN:
			light.state = Light.State.YELLOW
			light.yellow_left = Tuning.YELLOW_TIME
		Light.State.YELLOW:
			return
	light_changed.emit(light)


## Tow: drop the Wreckage the Raccoon is towing, or grab the nearest Wreckage within `reach` world px
## of the Raccoon (the Raccoon converts its on-screen TOW_RANGE). A stunned Raccoon can't.
func tow(reach: float) -> void:
	if raccoon_stun > 0.0:
		return
	if towing != null:
		_drop()
		return
	var best_d := INF
	for c in cars:
		if not c.wreckage or not c.reaches(raccoon_position, reach):
			continue
		var d := raccoon_position.distance_to(c.transform.origin)
		if d < best_d:
			best_d = d
			towing = c
	if towing != null:
		towing.towed = true
		_tow_hold = (towing.transform.origin - raccoon_position).limit_length(Tuning.TOW_HOLD)


func step() -> void:
	time += DT
	raccoon_stun = maxf(raccoon_stun - DT, 0.0)
	raccoon_knock = raccoon_knock.move_toward(Vector2.ZERO, Tuning.KNOCK_DECAY * DT)
	for l in lights:
		if l.state == Light.State.YELLOW:
			l.yellow_left -= DT
			if l.yellow_left <= 0.0:
				l.state = Light.State.RED
				light_changed.emit(l)
	_haul()  # before cars drive, so they brake for where towed Wreckage is now
	_spawn()
	_drive()
	_check_crashes()
	_check_hit()


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
		if _due[i] <= 0:
			continue
		var c := Car.new(_next_id, a.routes[0], lights[i])
		_place(c)
		if not _entry_clear(a, c):
			continue
		_due[i] -= 1
		_next_id += 1
		c.speed = Tuning.BASE_SPEED * Tuning.SPAWN_SPEED
		c.tint = Color.from_hsv(_rng.randf(), 0.65, 0.95)
		cars.append(c)
		car_spawned.emit(c)


# Room for the new car: the last car in is far enough along, and no Wreckage lies within its stopping
# distance of where it would appear.
func _entry_clear(a: RoadNet.Approach, new: Car) -> bool:
	var v := Tuning.BASE_SPEED * Tuning.SPAWN_SPEED  # the speed a new car enters at
	var room := Tuning.SPAWN_CLEAR + Tuning.FOLLOW_GAP + v * v / (2.0 * Tuning.DECEL * Tuning.HARD_BRAKE)
	for c in cars:
		if c.wreckage:
			if c.overlaps(new, -room):
				return false
		elif c.route.segment_at(c.s) == a.incoming and c.s - c.length / 2.0 < Tuning.CAR_L / 2.0 + Tuning.SPAWN_CLEAR:
			return false
	return true


func _drive() -> void:
	_wreckage = cars.filter(func(c: Car) -> bool: return c.wreckage)
	_by_route.resize(net.routes.size())
	for r in _by_route.size():
		_by_route[r] = []
	for c in cars:
		if not c.wreckage:
			_by_route[c.route.id].append(c)
	var keep: Array[Car] = []
	for c in cars:
		if c.wreckage:
			keep.append(c)
			continue
		var target := Tuning.BASE_SPEED * k_speed * (Tuning.GO_BOOST if c.boosted else 1.0)
		target = minf(target, _stop_line_limit(c))
		target = minf(target, _obstacle_limit(c))
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


# Slow for whatever is nearest ahead: a moving car on the route, Wreckage, or the Raccoon (Yield).
func _obstacle_limit(c: Car) -> float:
	var gap := _follow_gap(c)
	gap = minf(gap, _wreckage_gap(c, minf(gap, Tuning.LOOK)))  # Wreckage past the car in front can't matter yet
	gap = minf(gap, _raccoon_gap(c, minf(gap, Tuning.LOOK)))
	if gap == INF:
		return INF
	return sqrt(2.0 * Tuning.DECEL * maxf(gap - Tuning.FOLLOW_GAP, 0.0))


# The bumper gap to the nearest moving car ahead on any stretch of this car's own route, or INF.
func _follow_gap(c: Car) -> float:
	var front := c.s + c.length / 2.0
	var nearest := INF
	var first := c.route.index_at(c.s)
	for r in c.route.sharing:
		for o: Car in _by_route[r]:
			if o == c:
				continue
			var seg := o.route.segment_at(o.s)
			for k in range(first, c.route.segments.size()):
				if c.route.segments[k] != seg:
					continue
				var gap := c.route.starts[k] + o.route.local_at(o.s) - o.length / 2.0 - front
				if gap > -o.length and gap < Tuning.LOOK:
					nearest = minf(nearest, gap)
	return nearest


# The gap to Wreckage, towed or not, wherever it lies, looking up to `within` along the route: the first
# point where a line across the car's width (less SIGHT_INSET each side) touches Wreckage. INF if none.
func _wreckage_gap(c: Car, within: float) -> float:
	var half := c.width / 2.0 - Tuning.SIGHT_INSET
	var bumper := c.transform.origin + c.transform.x * c.length / 2.0
	var near: Array[Car] = []  # only wreckage within sight can be on the road ahead
	for w in _wreckage:
		if w.transform.origin.distance_to(bumper) <= within + half + w.radius():
			near.append(w)
	if near.is_empty():
		return INF
	var front := c.s + c.length / 2.0
	var d := 0.0
	while d <= within:
		var p := c.route.pose(front + d)
		var left := p.origin - p.y * half
		var right := p.origin + p.y * half
		for w in near:
			if p.origin.distance_to(w.transform.origin) <= half + w.radius() and w.crosses(left, right):
				return d
		d += Tuning.SIGHT_STEP
	return INF


# Yield: the gap to the Raccoon, looking up to `within` along the route. It's in the car's path where a line
# across the car's width (less SIGHT_INSET each side) comes within RACCOON_R + YIELD_MARGIN of it. The margin
# only widens the path: the gap runs to its body (RACCOON_R), so the car pulls up close. The look starts half a
# car back from the bumper, so a Raccoon over the car's back half still holds it. INF if none.
func _raccoon_gap(c: Car, within: float) -> float:
	var half := c.width / 2.0 - Tuning.SIGHT_INSET
	var reach := Tuning.RACCOON_R + Tuning.YIELD_MARGIN
	var bumper := c.transform.origin + c.transform.x * c.length / 2.0
	if raccoon_position.distance_to(bumper) > within + c.length / 2.0 + half + reach:
		return INF
	var front := c.s + c.length / 2.0
	var d := -c.length / 2.0
	while d <= within:
		var p := c.route.pose(front + d)
		var near := Geometry2D.get_closest_point_to_segment(raccoon_position, p.origin - p.y * half, p.origin + p.y * half)
		if near.distance_to(raccoon_position) <= reach:
			return d + Tuning.YIELD_MARGIN
		d += Tuning.SIGHT_STEP
	return INF


# Towed Wreckage trails the Raccoon. Off the road, it's dropped there and gone.
func _haul() -> void:
	if towing == null:
		return
	towing.transform.origin = raccoon_position + _tow_hold
	if not net.on_road(towing.transform.origin):
		_drop()


func _drop() -> void:
	var c := towing
	towing = null
	c.towed = false
	var off_road := not net.on_road(c.transform.origin)
	if off_road:
		cars.erase(c)
	towed.emit(c, off_road)


# Crash: moving cars on conflicting connectors in the same box, or any car and Wreckage, whose
# footprints overlap (each shrunk by CRASH_INSET). Towed Wreckage never Crashes.
func _check_crashes() -> void:
	var boxed: Array[Car] = []  # moving cars with some of their body on a connector
	var under: Array[PackedInt32Array] = []  # ...and those connectors
	var wreckage: Array[Car] = []
	for c in cars:
		if c.wreckage:
			if not c.towed:
				wreckage.append(c)
			continue
		var u := _connectors_under(c)
		if not u.is_empty():
			boxed.append(c)
			under.append(u)
	for i in boxed.size():
		for j in range(i + 1, boxed.size()):
			var a := boxed[i]
			var b := boxed[j]
			if not (a.wreckage and b.wreckage) and _conflict(under[i], under[j]) and a.overlaps(b, Tuning.CRASH_INSET):
				_crash(a, b)
	for w in wreckage:
		for c in cars:
			if not c.wreckage and c.transform.origin.distance_to(w.transform.origin) < c.radius() + w.radius() \
					and w.overlaps(c, Tuning.CRASH_INSET):
				_crash(w, c)


# The Raccoon getting hit: a moving car faster than HIT_MIN_SPEED with the Raccoon within HIT_REACH of its
# footprint. It's stunned, knocked back the way the car drives, and drops its Tow. A stunned Raccoon can't be hit again.
func _check_hit() -> void:
	if raccoon_stun > 0.0:
		return
	for c in cars:
		if not c.wreckage and c.speed > Tuning.HIT_MIN_SPEED and c.reaches(raccoon_position, Tuning.HIT_REACH):
			raccoon_stun = Tuning.STUN_TIME
			raccoon_knock = c.transform.x * Tuning.KNOCK_SPEED
			if towing != null:
				_drop()
			raccoon_hit.emit(c)
			return


func _connectors_under(c: Car) -> PackedInt32Array:
	var out := PackedInt32Array()
	var back := c.s - c.length / 2.0
	var front := c.s + c.length / 2.0
	for k in c.route.segments.size():
		var id := c.route.segments[k]
		var seg := net.segments[id]
		if seg.kind == RoadNet.Segment.Kind.CONNECTOR and front > c.route.starts[k] and back < c.route.starts[k] + seg.length:
			out.append(id)
	return out


func _conflict(x: PackedInt32Array, y: PackedInt32Array) -> bool:
	for i in x:
		for j in net.conflicts[i]:
			if y.has(j):
				return true
	return false


func _crash(a: Car, b: Car) -> void:
	for c: Car in [a, b]:
		c.wreckage = true
		c.speed = 0.0
		c.boosted = false
	crashed.emit(a, b, (a.transform.origin + b.transform.origin) / 2.0)


func _place(c: Car) -> void:
	c.transform = c.route.pose(c.s)
	c.line_distance = c.route.stop_s - (c.s + c.length / 2.0)

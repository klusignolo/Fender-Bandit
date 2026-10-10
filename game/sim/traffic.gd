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
signal tow_grabbed(car: Car)  # the Raccoon took hold of Wreckage to Tow it
signal raccoon_hit(car: Car)  # a car too fast to stop hit the Raccoon: it is stunned and knocked back
signal honked(car: Car)  # a front driver (or holding Turner) Honked: car.honks says which Honk
signal blew_red(car: Car)  # a front driver out of Patience is Blowing the red
signal yielded(car: Car)  # a driver braking from YIELD_SQUEAL_SPEED or faster started to Yield to the Raccoon
signal jam_level_changed(level: Jam.Level)  # the Jam moved into another Jam-level, up or down
signal gridlocked  # the Jam is full: the Run is over
signal swell_flagged(next: int)  # the Swell moves to road `next` in SHIFT_WARN seconds
signal stage_cleared  # the Quota was met: Traffic stops on that tick. Audio's stinger hooks here (#37)

const TICK_HZ := 60
const DT := 1.0 / TICK_HZ
const PICKUP_SLACK := 4.0  # px either side of its pickup point that a garbage truck counts as there (#46)

var net: RoadNet
var lights: Array[Light] = []
var cars: Array[Car] = []
var time := 0.0  # seconds simulated
var raccoon_position := Vector2.ZERO  # from set_raccoon; RACCOON_START until then
var raccoon_dashing := false
var jam: Jam  # the city-wide Jam; a fresh one each stage, carrying the Run's Dents
var towing: Car = null  # the Wreckage the Raccoon is towing
var raccoon_stun := 0.0  # seconds the Raccoon is stunned for: it can't act, and is knocked back
var raccoon_knock := Vector2.ZERO  # world px/s the Raccoon is being knocked back at; the Raccoon moves itself by it
var swell := 0  # the Swell road: the entry approach spawning at SWELL_HEAVY, the rest at SWELL_LIGHT
var swell_next := 0  # the road the Swell moves to next
var swell_left := 0.0  # seconds until the Swell moves to swell_next
var quota := 0  # cars this stage needs to get off the map: its target length over k_gap, for each entry
var cars_through := 0  # cars off the map this stage
var cleared := false  # the Quota is met; step() does nothing more

# Stage knobs, from the StageDef. Tests may set them.
var k_gap := 0.0
var k_speed := 1.0
var k_turners := 0.0  # Turner share: zero while Turners are off
var k_right := Tuning.RIGHT_SHARE  # flat from stage 1; a knob so tests can turn right turns off
var k_patience := 0.0
var blowing_unlocked := false  # Blowing the red. While it's off, drivers out of Patience only Honk.
var k_swell := true  # Swells on; a knob so tests can keep every entry at k_gap
var k_motorcycles := 0.0  # the vehicle mix: share of new vehicles that are motorcycles...
var k_semis := 0.0  # ...and semis...
var k_garbage := 0.0  # ...and garbage trucks (#46); the rest are cars
var k_hotheads := Tuning.HOTHEAD_SHARE  # share of drivers who are hotheads (#45)

var _rng := RandomNumberGenerator.new()
var _hothead_rng := RandomNumberGenerator.new()  # its own stream, so hotheads never shift another seeded draw
var _patience_rng := RandomNumberGenerator.new()  # its own stream, so drawing Patience doesn't shift any other draw
var _swell_rng := RandomNumberGenerator.new()  # its own stream, so drawing Swells doesn't shift any other draw
var _kind_rng := RandomNumberGenerator.new()  # its own stream, so drawing vehicle kinds doesn't shift any other draw
var _next_id := 1
var _spawn_left: Array[float] = []  # per approach: seconds until its next car is due
var _due: Array[Array] = []  # per approach: the kinds of the vehicles due that haven't found room to drive on yet, first due first
var _wreckage: Array[Car] = []  # this tick's Wreckage, towed or not
var _by_route: Array[Array] = []  # this tick's moving cars, by route id
var _tow_hold := Vector2.ZERO  # where the towed Wreckage trails, from the Raccoon
var _jam_level := Jam.Level.CLEAR  # the Jam-level last signalled


## A stage's traffic, set up by its StageDef (stage 1 without one). The Run hands it the Dents from its earlier stages.
func _init(seed_value: int, dents := 0, stage: StageDef = null) -> void:
	if stage == null:
		stage = Stages.def(1, seed_value)
	k_gap = stage.gap
	k_speed = stage.speed
	k_patience = stage.patience
	if stage.features.has(Stages.Feature.TURNERS):
		k_turners = stage.turners
	blowing_unlocked = stage.features.has(Stages.Feature.BLOWING)
	k_motorcycles = stage.motorcycles
	k_semis = stage.semis
	k_garbage = stage.garbage
	_rng.seed = seed_value
	_patience_rng.seed = seed_value
	_hothead_rng.seed = seed_value
	_swell_rng.seed = seed_value
	_kind_rng.seed = seed_value
	net = RoadNet.new(stage.crossings)
	jam = Jam.new(net.crossings.size(), dents)
	raccoon_position = net.crossings[0] + Tuning.RACCOON_START
	for i in net.approaches.size():
		lights.append(Light.new(i, net.approaches[i]))
		_spawn_left.append(_rng.randf_range(Tuning.FIRST_SPAWN[0], Tuning.FIRST_SPAWN[1]))
		_due.append([])
	var entries := _entries()
	quota = roundi(stage.target_len / k_gap * entries.size())
	swell = entries[_swell_rng.randi_range(0, entries.size() - 1)]
	_draw_swell()


## Whether the Swell's move to swell_next is flagged: it moves within SHIFT_WARN seconds.
func swell_warning() -> bool:
	return swell_left <= Tuning.SHIFT_WARN


## Count the Quota as met now: the stage clears next tick. For the --quota-at agent flag.
func meet_quota() -> void:
	cars_through = maxi(cars_through, quota)


## Cars due at entry `i` that haven't found room on its road yet: its backlog.
func backlog(i: int) -> int:
	return _due[i].size()


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
	towing = towable(reach)
	if towing != null:
		towing.towed = true
		_tow_hold = (towing.transform.origin - raccoon_position).limit_length(Tuning.TOW_HOLD)
		tow_grabbed.emit(towing)


## The Wreckage a Tow would grab now: the nearest within `reach` world px of the Raccoon, or null while it's towing
## (a Tow then drops) or stunned. The Raccoon's Tow hint shows over it.
func towable(reach: float) -> Car:
	if raccoon_stun > 0.0 or towing != null:
		return null
	var best: Car = null
	var best_d := INF
	for c in cars:
		if not c.wreckage or not c.reaches(raccoon_position, reach):
			continue
		var d := raccoon_position.distance_to(c.transform.origin)
		if d < best_d:
			best_d = d
			best = c
	return best


func step() -> void:
	if cleared:
		return
	time += DT
	raccoon_stun = maxf(raccoon_stun - DT, 0.0)
	raccoon_knock = raccoon_knock.move_toward(Vector2.ZERO, Tuning.KNOCK_DECAY * DT)
	for l in lights:
		if l.state == Light.State.YELLOW:
			l.yellow_left -= DT
			if l.yellow_left <= 0.0:
				l.state = Light.State.RED
				light_changed.emit(l)
	_move_swell()
	_haul()  # before cars drive, so they brake for where towed Wreckage is now
	_spawn()
	_drive()
	_check_quota()
	if cleared:
		return  # the Quota is met: this tick can't Crash or Gridlock any more
	var honking := _spend_patience()
	jam.step(honking + Tuning.JAM_BACKLOG * _backlog_total(), DT)
	_check_crashes()
	_check_hit()
	_check_jam()


# Every vehicle that's due joins its entry's queue, its kind drawn as it falls due, then drives on as soon as the
# road has room.
func _spawn() -> void:
	for i in net.approaches.size():
		var a := net.approaches[i]
		if not a.entry:
			continue
		_spawn_left[i] -= DT
		if _spawn_left[i] <= 0.0:
			_spawn_left[i] += k_gap * _rng.randf_range(Tuning.SPAWN_JITTER[0], Tuning.SPAWN_JITTER[1]) / _swell_rate(i)
			_due[i].append(_pick_kind())
		if _due[i].is_empty():
			continue
		var c := Car.new(_next_id, a.routes[0], lights[i], _due[i][0])
		c.s = (Tuning.CAR_L - c.length) / 2.0  # its front bumper where a car's is, so a semi enters out of sight
		_place(c)
		if not _entry_clear(a, c):
			continue
		_due[i].pop_front()
		_next_id += 1
		_new_driver(c, i)
		c.speed = _entry_speed(c)
		c.tint = Car.TINTS[mini(int(_rng.randf() * Car.TINTS.size()), Car.TINTS.size() - 1)]  # randf, as for the hue it replaced: seeded streams stay put
		if c.kind == Car.Kind.GARBAGE:
			c.tint = Car.GARBAGE_TINT  # after the draw, so the seeded streams stay put
		cars.append(c)
		car_spawned.emit(c)


# A fresh driver for approach i's Light: it rolls its movement, and draws its Turner gap and Patience. Every car
# gets one as it spawns, and again each time it drives on to another crossing.
func _new_driver(c: Car, i: int) -> void:
	c.light = lights[i]
	c.route = _pick_route(net.approaches[i])
	if c.movement == RoadNet.Movement.LEFT:
		c.turn_gap = _rng.randf_range(Tuning.TURNER_GAP[0], Tuning.TURNER_GAP[1]) / c.pace  # a slow semi wants a longer gap
	c.patience = k_patience * _patience_rng.randf_range(Tuning.PATIENCE_JITTER[0], Tuning.PATIENCE_JITTER[1])
	c.hothead = _hothead_rng.randf() < k_hotheads


# A car whose back has cleared the box onto a road linked to the next crossing drives on as that crossing's car:
# along one of its Routes from the same point on the road, with a fresh driver. _by_route still files it under its
# old Route until next tick; that's safe, as the old Route ends on the same road, so cars behind still follow it.
func _hand_off(c: Car) -> void:
	c.s -= c.route.last_start()
	c.reset_driver()
	_new_driver(c, c.route.next)


# Cars waiting in every entry's backlog.
func _backlog_total() -> int:
	var n := 0
	for d in _due:
		n += d.size()
	return n


# The approaches fed from the map edge.
func _entries() -> Array[int]:
	var out: Array[int] = []
	for i in net.approaches.size():
		if net.approaches[i].entry:
			out.append(i)
	return out


# The next Swell is flagged SHIFT_WARN seconds ahead; the Swell road moves on once its time is up. With
# k_swell off the Swell stands still and is never flagged.
func _move_swell() -> void:
	if not k_swell:
		return
	var warned := swell_warning()
	swell_left -= DT
	if swell_warning() and not warned:
		swell_flagged.emit(swell_next)
	if swell_left <= 0.0:
		swell = swell_next
		_draw_swell()


# The next Swell: another road, and how long until the Swell moves to it.
func _draw_swell() -> void:
	var others := _entries().filter(func(i: int) -> bool: return i != swell)
	swell_next = others[_swell_rng.randi_range(0, others.size() - 1)]
	swell_left += _swell_rng.randf_range(Tuning.SWELL_MIN, Tuning.SWELL_MAX)


# An entry's spawn rate, as a multiple of k_gap's: the Swell road's is heavy, the rest light.
func _swell_rate(i: int) -> float:
	if not k_swell:
		return 1.0
	return Tuning.SWELL_HEAVY if i == swell else Tuning.SWELL_LIGHT


# A new driver's route at approach a: its movement drawn by _pick_movement, then, where the approach has more than
# one route making it (a 5-way), one of those at even odds. A 4-way has one of each, so it draws nothing more there.
func _pick_route(a: RoadNet.Approach) -> RoadNet.Route:
	var m := _pick_movement(a)
	var options := a.routes.filter(func(r: RoadNet.Route) -> bool: return r.movement == m)
	if options.size() == 1:
		return options[0]
	return options[_rng.randi_range(0, options.size() - 1)]


# A new driver's movement: Turner at the k_turners share, right at k_right, otherwise straight. A movement it can't
# make hands its share on: one the approach has no route for (on a T, or a 5-way's diagonal road), or a left turn
# while Turners are off. The share goes straight on, or, with no straight exit, is split evenly between the
# movements it can make. With both knobs at zero and a straight exit it draws nothing, so the run is the same as
# before turns existed.
func _pick_movement(a: RoadNet.Approach) -> RoadNet.Movement:
	if k_turners + k_right <= 0.0 and a.has(RoadNet.Movement.STRAIGHT):
		return RoadNet.Movement.STRAIGHT
	var odds: Dictionary[RoadNet.Movement, float] = {
		RoadNet.Movement.LEFT: k_turners,
		RoadNet.Movement.RIGHT: k_right,
		RoadNet.Movement.STRAIGHT: maxf(1.0 - k_turners - k_right, 0.0),
	}
	var can := odds.keys().filter(func(m: RoadNet.Movement) -> bool:
		return a.has(m) and (m != RoadNet.Movement.LEFT or k_turners > 0.0))
	var heirs := [RoadNet.Movement.STRAIGHT] if can.has(RoadNet.Movement.STRAIGHT) else can  # who takes the spare share
	var spare := 0.0
	for m: RoadNet.Movement in odds:
		if not can.has(m):
			spare += odds[m]
			odds[m] = 0.0
	for m: RoadNet.Movement in heirs:
		odds[m] += spare / heirs.size()
	var r := _rng.randf()
	var below := 0.0  # r below this picks the movement
	for m: RoadNet.Movement in [RoadNet.Movement.LEFT, RoadNet.Movement.RIGHT]:
		below += odds[m]
		if r < below:
			return m
	return heirs[heirs.size() - 1]  # straight, or the last turn when rounding leaves r just short of 1


# A vehicle falling due: a motorcycle at the k_motorcycles share, a semi at k_semis, a garbage truck at k_garbage,
# otherwise a car. With no mix it draws nothing.
func _pick_kind() -> Car.Kind:
	if k_motorcycles + k_semis + k_garbage <= 0.0:
		return Car.Kind.CAR
	var r := _kind_rng.randf()
	if r < k_motorcycles:
		return Car.Kind.MOTORCYCLE
	if r < k_motorcycles + k_semis:
		return Car.Kind.SEMI
	if r < k_motorcycles + k_semis + k_garbage:
		return Car.Kind.GARBAGE
	return Car.Kind.CAR


# Room for the new vehicle: the last car in is far enough ahead of its front bumper, and no Wreckage lies within
# its stopping distance of where it would appear.
func _entry_clear(a: RoadNet.Approach, new: Car) -> bool:
	var v := _entry_speed(new)
	var room := Tuning.SPAWN_CLEAR + Tuning.FOLLOW_GAP + v * v / (2.0 * Tuning.DECEL * Tuning.HARD_BRAKE)
	for c in cars:
		if c.wreckage:
			if c.overlaps(new, -room):
				return false
		elif c.route.segment_at(c.s) == a.incoming:
			var gap := c.s - c.length / 2.0 - (new.s + new.length / 2.0)
			if gap < Tuning.SPAWN_CLEAR or (c.speed < v and gap < room):  # behind a slower car it needs room to stop
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
		var target := _cruise(c) * (Tuning.GO_BOOST if c.boosted else 1.0)
		target = minf(target, _stop_line_limit(c))
		target = minf(target, _turn_limit(c))
		target = minf(target, _turner_limit(c))
		target = minf(target, _pickup_limit(c))
		var obstacle := _obstacle_limit(c)
		target = minf(target, obstacle)
		var yielding := c.raccoon_ahead and (c.yielding or obstacle < c.speed)  # braked for the Raccoon, which is still there
		if yielding and not c.yielding and c.speed >= Tuning.YIELD_SQUEAL_SPEED:
			yielded.emit(c)
		c.yielding = yielding
		var was := c.speed
		if c.speed < target:
			c.speed = minf(target, c.speed + Tuning.ACCEL * DT)
		else:
			c.speed = maxf(target, c.speed - Tuning.DECEL * Tuning.HARD_BRAKE * DT)
		c.braking = c.speed < was or (c.speed == was and c.speed < Tuning.WAIT_SPEED)  # slowing, or held at a crawl
		c.s += c.speed * DT
		if c.route.next >= 0 and c.out_of_box():
			_hand_off(c)
		if c.s >= c.route.length:
			cars_through += 1
			jam.exit()
			car_exited.emit(c)
			continue
		_place(c)
		keep.append(c)
	cars = keep


# Patience: only the front driver at each red (or Yellow) Light spends it, and a Turner holding for a gap,
# while stopped; once it moves, it starts again from zero. Only a front driver who is a hothead (#45) can be out of
# it: once Blowing the red has debuted, it flashes "!!" for its last BLOW_WARN seconds, then Blows the red. Everyone
# else, and everyone before then, only Honks. Returns the Jam fill per second from the drivers Honking.
func _spend_patience() -> float:
	var honking := 0.0  # Jam fill per second from the drivers Honking
	var fronts: Dictionary[Light, Car] = {}
	for c in cars:
		if c.wreckage or c.passed_line or c.light.state == Light.State.GREEN:
			continue
		if not fronts.has(c.light) or c.line_distance < fronts[c.light].line_distance:
			fronts[c.light] = c
	for c in cars:
		var front: bool = fronts.get(c.light) == c
		c.front = front or c.holding
		if not c.front or c.speed >= Tuning.WAIT_SPEED:
			c.wait = 0.0  # its honk counter resets once it moves (#45), or stops being the one waiting
		else:
			c.wait += DT
		var stage := mini(int(c.wait / (c.patience / Tuning.PATIENCE_RINGS)), Tuning.PATIENCE_RINGS - 1)
		var honk := stage > c.honks
		c.honks = stage
		c.worst_honks = maxi(c.worst_honks, stage)
		if honk:
			honked.emit(c)
		honking += Tuning.JAM_HONK[c.honks]
		c.blow_warning = blowing_unlocked and front and c.hothead and c.patience - c.wait <= Tuning.BLOW_WARN
		if c.blow_warning and c.wait >= c.patience and c.line_distance < Tuning.BLOW_REACH and not c.blowing:
			c.blowing = true
			blew_red.emit(c)
	return honking


# Red stops a driver at the line. A driver too close to stop even braking hard pushes through; on
# Yellow it judges the stop longer, so more push through. A car crossing on Green or Yellow is waved on.
# A driver Blowing the red ignores it.
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
	if l.state == Light.State.GREEN or c.blowing:
		return INF
	var need := c.speed * c.speed / (2.0 * Tuning.DECEL * Tuning.HARD_BRAKE)
	if l.state == Light.State.YELLOW:
		need *= Tuning.YELLOW_CAUTION
	if dist < need - Tuning.PUSH_SLACK and c.speed > Tuning.PUSH_MIN_SPEED:
		c.passed_line = true
		return INF
	return sqrt(2.0 * Tuning.DECEL * maxf(dist - Tuning.STOP_MARGIN, 0.0))


# A vehicle's normal speed this stage: a car's, times its pace.
func _cruise(c: Car) -> float:
	return Tuning.BASE_SPEED * k_speed * c.pace


# The speed a new vehicle enters at: a car's SPAWN_SPEED, slower for a semi but no faster for a motorcycle, so
# it can stop behind the queue at the entry as a car can.
func _entry_speed(c: Car) -> float:
	return Tuning.BASE_SPEED * Tuning.SPAWN_SPEED * minf(c.pace, 1.0)


# A car turning right or left takes its turn at TURN_SPEED: it slows in time to reach the box at that
# speed, and holds it until its centre is off the connector.
func _turn_limit(c: Car) -> float:
	if c.movement == RoadNet.Movement.STRAIGHT or c.past_box():
		return INF
	var v := _cruise(c) * Tuning.TURN_SPEED
	return sqrt(v * v + 2.0 * Tuning.DECEL * maxf(c.line_distance, 0.0))


# A Turner pulls up with its centre on its stop line and holds there, holding up everyone behind, until it
# has its gap. A motorcycle or semi holds with its front bumper where a car's would be, so a semi's nose stays out of
# the cross traffic. Then it's committed, and doesn't stop for oncoming traffic again.
func _turner_limit(c: Car) -> float:
	c.holding = false
	if c.movement != RoadNet.Movement.LEFT or c.committed:
		return INF
	var hold_s := c.route.stop_s + (Tuning.CAR_L - c.length) / 2.0  # where its centre holds: its front where a car's would be
	var to_hold := hold_s - c.s
	if to_hold > Tuning.LOOK:
		return INF
	if _gap_ok(c):
		c.committed = to_hold <= Tuning.HOLD_SLACK
		return INF
	if to_hold <= Tuning.HOLD_SLACK:
		c.holding = true
		c.hold_time += DT
	return sqrt(2.0 * Tuning.DECEL * maxf(to_hold, 0.0))


# A garbage truck (#46) pulls up with its centre PICKUP_BEFORE short of its stop line, once per crossing, and
# collects there for PICKUP_TIME, holding up everyone behind, whatever its Light shows. A truck already past the
# point (it entered or was handed on beyond it) skips this crossing's pickup.
func _pickup_limit(c: Car) -> float:
	c.collecting = false
	if c.kind != Car.Kind.GARBAGE or c.collected or c.passed_line:
		return INF
	var to_pickup := c.route.stop_s - Tuning.PICKUP_BEFORE - c.s
	if to_pickup < -PICKUP_SLACK:
		c.collected = true
		return INF
	if to_pickup > Tuning.LOOK:
		return INF
	if to_pickup <= PICKUP_SLACK and c.speed < Tuning.WAIT_SPEED:
		c.collecting = true
		c.collect_time += DT
		if c.collect_time >= Tuning.PICKUP_TIME:
			c.collected = true
			c.collecting = false
			return INF
	return sqrt(2.0 * Tuning.DECEL * maxf(to_pickup, 0.0))


# A Turner's gap: no oncoming car in the box, and none due at its line within the Turner gap. Oncoming cars
# that will stop at their own Light don't count, so a Turner caught by a red clears out once the oncoming
# road stops, whatever the cross traffic does. Opposing Turners take turns: of two holding, the one that has
# waited longer goes first (on a tie, the older car), and the cars stuck behind it can't come.
func _gap_ok(c: Car) -> bool:
	var opposite := net.approaches[c.light.id].opposite
	if opposite < 0:
		return true
	var oncoming := lights[opposite]
	var stuck := -INF  # oncoming cars behind this far along are stuck behind a Turner that waits for this one
	for o in cars:
		if o.light == oncoming and o.holding:
			if o.hold_time > c.hold_time or (o.hold_time == c.hold_time and o.id < c.id):
				return false
			stuck = maxf(stuck, o.s)
	for o in cars:
		if o.light != oncoming or o.wreckage or o.holding or o.s < stuck or o.out_of_box():
			continue
		if o.line_distance < 0.0:
			return false  # in the box
		if not o.passed_line and o.light.state != Light.State.GREEN:
			continue  # will stop at its Light
		if o.line_distance / maxf(o.speed, Tuning.GAP_MIN_SPEED) < c.turn_gap:
			return false
	return true


# Slow for whatever is nearest ahead: a moving car on the route, Wreckage, or the Raccoon (Yield).
func _obstacle_limit(c: Car) -> float:
	var gap := _follow_gap(c)
	gap = minf(gap, _wreckage_gap(c, minf(gap, Tuning.LOOK)))  # Wreckage past the car in front can't matter yet
	var raccoon := _raccoon_gap(c, minf(gap, Tuning.LOOK))
	c.raccoon_ahead = raccoon < gap
	gap = minf(gap, raccoon)
	if gap == INF:
		return INF
	return sqrt(2.0 * Tuning.DECEL * maxf(gap - Tuning.FOLLOW_GAP, 0.0))


# The bumper gap to the nearest moving car ahead on any stretch of this car's own route, or INF. A car from
# the same lane that took another way through the box counts until its back is out of the box: its turn
# starts where this car's path does.
func _follow_gap(c: Car) -> float:
	var front := c.s + c.length / 2.0
	var nearest := INF
	var first := c.route.index_at(c.s)
	for r in c.route.sharing:
		for o: Car in _by_route[r]:
			if o == c:
				continue
			if o.route != c.route and o.route.segments[0] == c.route.segments[0] and not o.out_of_box():
				var lane_gap := o.s - o.length / 2.0 - front  # same lane in, so distances along both routes agree
				if lane_gap > -o.length and lane_gap < Tuning.LOOK:
					nearest = minf(nearest, lane_gap)
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
	for w in wreckage:  # Wreckage hits a car on its own level only: an overpass keeps the two apart (#44)
		for c in cars:
			if not c.wreckage and c.underpass == w.underpass \
					and c.transform.origin.distance_to(w.transform.origin) < c.radius() + w.radius() \
					and w.overlaps(c, Tuning.CRASH_INSET):
				_crash(w, c)


# The Quota: the stage clears on the tick it's met, with the cars still on the map where they are (#45).
func _check_quota() -> void:
	if cars_through >= quota:
		cleared = true
		stage_cleared.emit()


# Signal the Jam-level when it changes. A full Jam is Gridlock; Jam stays full from then on.
func _check_jam() -> void:
	var l := jam.level()
	if l == _jam_level:
		return
	_jam_level = l
	jam_level_changed.emit(l)
	if l == Jam.Level.GRIDLOCK:
		gridlocked.emit()


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
		c.braking = false
		c.speed = 0.0
		c.boosted = false
		c.holding = false
	jam.dent()
	crashed.emit(a, b, (a.transform.origin + b.transform.origin) / 2.0)


func _place(c: Car) -> void:
	c.transform = c.route.pose(c.s)
	c.underpass = false
	for o in net.overpasses:
		if o.under.has(c.route.segment_at(c.s)) and c.transform.origin.distance_to(o.centre) < Tuning.LW * 2.0 + c.length:
			c.underpass = true
	c.line_distance = c.route.stop_s - (c.s + c.length / 2.0)

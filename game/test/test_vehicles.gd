extends TestCase
## Motorcycles and semis (#30), black-box through Traffic: the vehicle mix from the StageDef, footprints and
## speeds by kind, following and queueing in mixed traffic, and a semi's rigid footprint through a turn.

const N := 0  # Light indices follow RoadNet.ARM_ORDER: N, S, W, E
const S := 1
const W := 2
const E := 3
const KIND := Car.Kind


## Records what Traffic emits. Holds no reference to the Traffic, so nothing leaks.
class Log:
	var spawned: Array[Car] = []
	var crashes: Array[Array] = []  # [a, b]

	func _init(t: Traffic) -> void:
		t.car_spawned.connect(func(c: Car) -> void: spawned.append(c))
		t.crashed.connect(func(a: Car, b: Car, _at: Vector2) -> void: crashes.append([a, b]))


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


## Straight traffic, with the vehicle mix set: shares of motorcycles and semis, the rest cars.
func _mixed(seed_value: int, motorcycles: float, semis: float) -> Traffic:
	var t := straight_traffic(seed_value)
	t.k_motorcycles = motorcycles
	t.k_semis = semis
	return t


func _kinds(cars: Array[Car]) -> Dictionary:
	var out := {KIND.CAR: 0, KIND.MOTORCYCLE: 0, KIND.SEMI: 0}
	for c in cars:
		out[c.kind] += 1
	return out


# --- the vehicle mix ----------------------------------------------------------------

func test_the_stage_def_sets_the_mix_from_each_debut() -> void:
	for n in range(1, 12):
		var d := Stages.def(n, 1)
		var motos := Tuning.MOTO_SHARE if d.features.has(Stages.Feature.MOTORCYCLES) else 0.0
		var semis := Tuning.SEMI_SHARE if d.features.has(Stages.Feature.SEMIS) else 0.0
		check_eq(d.motorcycles, motos, "stage %d's motorcycle share" % n)
		check_eq(d.semis, semis, "stage %d's semi share" % n)
	check_eq(Stages.def(4, 1).motorcycles, 0.0, "no motorcycles before their Debut at stage 5")
	check(Stages.def(5, 1).motorcycles > 0.0, "motorcycles from stage 5")
	check_eq(Stages.def(7, 1).semis, 0.0, "no semis before their Debut at stage 8")
	check(Stages.def(8, 1).semis > 0.0, "semis from stage 8")


func test_vehicles_spawn_only_once_their_debut_is_unlocked() -> void:
	for n in [4, 5, 7, 8]:
		var t := Traffic.new(2, 0, Stages.def(n, 2))
		t.quota = NO_QUOTA
		var events := Log.new(t)
		t.blowing_unlocked = false
		_run(t, 90.0)  # all Red: every entry road fills up
		var k := _kinds(events.spawned)
		check(k[KIND.CAR] > 0, "stage %d spawns cars" % n)
		check_eq(k[KIND.MOTORCYCLE] > 0, n >= 5, "stage %d spawns motorcycles (%d of %d)" % [n, k[KIND.MOTORCYCLE], events.spawned.size()])
		check_eq(k[KIND.SEMI] > 0, n >= 8, "stage %d spawns semis (%d of %d)" % [n, k[KIND.SEMI], events.spawned.size()])


func test_the_mix_knobs_set_the_share_of_each_kind() -> void:
	var t := _mixed(5, 0.3, 0.2)
	t.k_gap = 1.0
	var events := Log.new(t)
	t.switch(t.lights[N])  # opposite roads: they never cross
	t.switch(t.lights[S])
	_run(t, 300.0)
	var k := _kinds(events.spawned)
	var n := float(events.spawned.size())
	check(n > 200, "enough spawns to judge the mix: %d" % n)
	check_near(k[KIND.MOTORCYCLE] / n, 0.3, 0.08, "motorcycle share")
	check_near(k[KIND.SEMI] / n, 0.2, 0.08, "semi share")


func test_no_mix_spawns_the_same_cars_as_before_vehicles_had_kinds() -> void:
	# The kind is drawn from its own stream, so turning the mix on doesn't shift any other draw.
	var plain := straight_traffic(9)
	var mixed := _mixed(9, 0.0, 0.0)
	var a := Log.new(plain)
	var b := Log.new(mixed)
	plain.k_turners = 0.2
	mixed.k_turners = 0.2
	plain.k_right = 0.2
	mixed.k_right = 0.2
	_run(plain, 30.0)
	_run(mixed, 30.0)
	check_eq(a.spawned.size(), b.spawned.size(), "same spawns")
	for i in mini(a.spawned.size(), b.spawned.size()):
		check_eq(b.spawned[i].kind, KIND.CAR, "all cars")
		check_eq(b.spawned[i].movement, a.spawned[i].movement, "spawn %d's movement" % i)


# --- footprints and speeds ----------------------------------------------------------

func test_each_kind_has_its_footprint_and_pace() -> void:
	var want := {
		KIND.CAR: [Tuning.CAR_L, Tuning.CAR_W, 1.0],
		KIND.MOTORCYCLE: [Tuning.MOTO_L, Tuning.MOTO_W, Tuning.MOTO_PACE],
		KIND.SEMI: [Tuning.SEMI_L, Tuning.SEMI_W, Tuning.SEMI_PACE],
	}
	var top := {}  # kind → the fastest any of that kind drove, waved on and cruising
	for kind: Car.Kind in want:
		var t := _mixed(4, 1.0 if kind == KIND.MOTORCYCLE else 0.0, 1.0 if kind == KIND.SEMI else 0.0)
		var events := Log.new(t)
		t.switch(t.lights[W])
		top[kind] = 0.0
		for i in 20 * Traffic.TICK_HZ:
			t.step()
			for c in t.cars:
				top[kind] = maxf(top[kind], c.speed)
		if not check(not events.spawned.is_empty(), "%s spawned" % Car.Kind.keys()[kind]):
			continue
		var c := events.spawned[0]
		check_eq(c.kind, kind, "the knob gives %s" % Car.Kind.keys()[kind])
		check_eq(c.length, want[kind][0], "%s length" % Car.Kind.keys()[kind])
		check_eq(c.width, want[kind][1], "%s width" % Car.Kind.keys()[kind])
	check_near(top[KIND.MOTORCYCLE] / top[KIND.CAR], Tuning.MOTO_PACE, 0.02, "motorcycles drive faster than cars")
	check_near(top[KIND.SEMI] / top[KIND.CAR], Tuning.SEMI_PACE, 0.02, "semis drive slower than cars")


# --- following and queueing -----------------------------------------------------------

func test_mixed_traffic_queues_at_red_without_touching() -> void:
	for seed_value in [3, 7]:
		var t := _mixed(seed_value, 0.35, 0.35)
		var events := Log.new(t)
		_run(t, 40.0)
		check(events.crashes.is_empty(), "no Crash on all-Red (seed %d)" % seed_value)
		for l in t.lights:
			var q := t.cars.filter(func(c: Car) -> bool: return c.light == l)
			q.sort_custom(func(a: Car, b: Car) -> bool: return a.line_distance < b.line_distance)
			if not check(q.size() >= 3, "a queue at %d (seed %d)" % [l.id, seed_value]):
				continue
			check(q[0].line_distance >= 0.0 and q[0].line_distance < 10.0, "the front %s waits just short of the line, %.1f px" % [Car.Kind.keys()[q[0].kind], q[0].line_distance])
			for i in range(1, q.size()):
				if q[i].speed < 1.0:  # the last may still be rolling in
					var gap: float = q[i].line_distance - q[i - 1].line_distance - q[i - 1].length
					check(gap > 2.0 and gap < 20.0, "bumper gap %s→%s at Light %d is %.1f px" % [Car.Kind.keys()[q[i - 1].kind], Car.Kind.keys()[q[i].kind], l.id, gap])


func test_mixed_traffic_follows_through_green_without_closing_up() -> void:
	var t := _mixed(3, 0.35, 0.35)
	var events := Log.new(t)
	t.switch(t.lights[N])
	var kinds := {}
	for i in 60 * Traffic.TICK_HZ:
		t.step()
		var q := t.cars.filter(func(c: Car) -> bool: return c.light == t.lights[N])
		for a: Car in q:
			kinds[a.kind] = true
			for b: Car in q:
				if a != b and absf(a.s - b.s) < (a.length + b.length) / 2.0:
					check(false, "%s %d and %s %d overlap at %.2fs" % [Car.Kind.keys()[a.kind], a.id, Car.Kind.keys()[b.kind], b.id, t.time])
					return
	check_eq(kinds.size(), 3, "all three kinds drove through")
	check(events.crashes.is_empty(), "no Crash with one road on Green")


func test_a_long_vehicle_turner_holds_with_its_front_where_a_cars_would_be() -> void:
	# A Turner holds with its centre on the stop line; a semi there would poke its nose into cross traffic.
	var held := {}  # kind → line_distance of the first one seen holding
	for kind: Car.Kind in [KIND.CAR, KIND.SEMI, KIND.MOTORCYCLE]:
		var t := _mixed(6, 1.0 if kind == KIND.MOTORCYCLE else 0.0, 1.0 if kind == KIND.SEMI else 0.0)
		t.k_turners = 1.0
		t.switch(t.lights[N])
		t.switch(t.lights[S])
		for i in 30 * Traffic.TICK_HZ:
			t.step()
			var h := t.cars.filter(func(c: Car) -> bool: return c.holding)
			if not h.is_empty():
				held[kind] = h[0].line_distance
				break
		check(held.has(kind), "a %s Turner held for oncoming traffic" % Car.Kind.keys()[kind])
	if held.size() == 3:
		check_near(held[KIND.CAR], -Tuning.CAR_L / 2.0, 2.0, "a car holds with its centre on the line")
		check_near(held[KIND.SEMI], held[KIND.CAR], 2.0, "a semi holds its front bumper where a car's would be")
		check_near(held[KIND.MOTORCYCLE], held[KIND.CAR], 2.0, "so does a motorcycle")


# --- a semi's footprint through a turn ------------------------------------------------

## Semis only, all turning right off N on Green; stepped until the first is halfway through its turn.
func _semi_mid_turn() -> Array:
	var t := _mixed(8, 0.0, 1.0)
	t.k_right = 1.0
	var events := Log.new(t)
	t.switch(t.lights[N])
	for i in 20 * Traffic.TICK_HZ:
		t.step()
		for c in t.cars:
			var seg := t.net.segments[c.route.segments[1]]
			if c.route.index_at(c.s) == 1 and c.route.local_at(c.s) >= seg.length / 2.0:
				return [t, c, events]
	return [t, null, events]


func test_a_semi_is_one_rigid_rectangle_through_a_turn() -> void:
	var r := _semi_mid_turn()
	var semi: Car = r[1]
	if not check(semi != null, "a semi reached the middle of its right turn"):
		return
	check_eq(semi.movement, RoadNet.Movement.RIGHT, "it's turning right")
	var p := semi.route.pose(semi.s)
	check(semi.transform.origin.distance_to(p.origin) < 0.01, "its centre is on its route")
	var k := semi.corners()
	check_near(k[0].distance_to(k[1]), Tuning.SEMI_L, 0.01, "its long side is the whole semi")
	check_near(k[1].distance_to(k[2]), Tuning.SEMI_W, 0.01, "its short side is its width")
	check_near((k[1] - k[0]).dot(k[2] - k[1]), 0.0, 0.01, "square corners: it doesn't bend")
	check_near((k[0] - k[1]).angle_to(p.x), 0.0, 0.01, "it lies along the way its centre is heading")


func test_a_semi_crashes_where_its_rigid_nose_swings_off_its_path() -> void:
	var r := _semi_mid_turn()
	var t: Traffic = r[0]
	var semi: Car = r[1]
	var events: Log = r[2]
	if not check(semi != null, "a semi reached the middle of its right turn"):
		return
	# Wreckage just touching the rigid nose, out where the route has already curved away.
	var w := Car.new(999, semi.route, semi.light)
	w.wreckage = true
	w.patience = semi.patience  # as a real driver's: Patience is spent per tick, wreckage or not
	w.transform = Transform2D(semi.transform.get_rotation(), semi.transform * Vector2(Tuning.SEMI_L / 2.0 + Tuning.CAR_L / 2.0 - 8.0, 0.0))
	var bend := semi.route.pose(semi.s + Tuning.SEMI_L / 2.0).origin  # where a bending nose would be
	check(not w.reaches(bend, 0.0), "the Wreckage is off the semi's path")
	t.cars.append(w)
	t.step()
	check(events.crashes.any(func(c: Array) -> bool: return c.has(semi) and c.has(w)), "the semi's nose hits it")


# --- entering, and a Turner's gap -----------------------------------------------------

func test_every_kind_enters_out_of_sight_and_no_faster_than_a_car() -> void:
	for kind: Car.Kind in [KIND.CAR, KIND.MOTORCYCLE, KIND.SEMI]:
		var t := _mixed(2, 1.0 if kind == KIND.MOTORCYCLE else 0.0, 1.0 if kind == KIND.SEMI else 0.0)
		var events := Log.new(t)
		_run(t, 5.0)
		if not check(not events.spawned.is_empty(), "a %s spawned" % Car.Kind.keys()[kind]):
			continue
		var c := events.spawned[0]
		var fresh := Car.new(0, c.route, c.light, kind)  # where it appeared: re-placed as _spawn places it
		fresh.s = (Tuning.CAR_L - fresh.length) / 2.0
		fresh.transform = fresh.route.pose(fresh.s)
		for p in fresh.corners():
			check(not t.net.bounds.has_point(p), "a new %s is wholly off the map: corner %s" % [Car.Kind.keys()[kind], p])
	var t := _mixed(2, 1.0, 0.0)
	var speeds: Array[float] = []
	t.car_spawned.connect(func(c: Car) -> void: speeds.append(c.speed))
	_run(t, 5.0)
	check(not speeds.is_empty(), "motorcycles spawned")
	for v in speeds:
		check_near(v, Tuning.BASE_SPEED * Tuning.SPAWN_SPEED, 0.01, "a motorcycle enters at a car's speed")


func test_a_slow_semi_turner_wants_a_longer_gap() -> void:
	var t := _mixed(5, 0.0, 1.0)
	t.k_turners = 1.0
	var events := Log.new(t)
	_run(t, 10.0)
	check(not events.spawned.is_empty(), "semis spawned")
	for c in events.spawned:
		check(c.turn_gap >= Tuning.TURNER_GAP[0] / Tuning.SEMI_PACE - 0.001, "a semi Turner's gap %.2fs is a car's over its pace" % c.turn_gap)

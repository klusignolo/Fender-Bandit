extends TestCase
## T-junctions and 5-ways (#32), black-box through Traffic and its RoadNet. In the City plan, C (crossing 2, from
## stage 9) is a T with no south arm, and E (crossing 4, from stage 17) a 5-way with a fifth arm to the north-west.

const A := 0
const C := 2
const E := 4


## straight_traffic at `stage`, with Blowing the red off, so no driver runs a red: any Crash comes from the Lights.
func _calm(seed_value: int, stage: int) -> Traffic:
	var t := straight_traffic(seed_value, stage)
	t.blowing_unlocked = false
	return t


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


## The Light of the approach into crossing x whose cars come in from compass point `from` ("N", "NW", ...).
func _at(t: Traffic, x: int, from: String) -> int:
	return t.net.approach_at(x, from)


func _in_box(c: Car) -> bool:
	return c.route.index_at(c.s + c.length / 2.0) >= 1 and c.route.index_at(c.s - c.length / 2.0) <= 1


## Records cars leaving the map and Crashes. Holds no reference to the Traffic, so nothing leaks.
class Log:
	var exited: Array[Car] = []
	var crashes: Array[Vector2] = []

	func _init(t: Traffic) -> void:
		t.car_exited.connect(func(c: Car) -> void: exited.append(c))
		t.crashed.connect(func(_a: Car, _b: Car, at: Vector2) -> void: crashes.append(at))

	func through(light: int) -> Array[Car]:
		return exited.filter(func(c: Car) -> bool: return c.light.id == light)


# --- the T --------------------------------------------------------------------------

func test_a_t_junction_approach_with_no_straight_exit_only_picks_movements_it_has() -> void:
	# Drivers would mostly go straight, but C has no south arm: cars coming down from A into C must turn, left to the
	# east or right to the west, about half each.
	var t := _calm(1, 9)
	t.k_turners = 0.2  # Turners are on from stage 3
	var log := Log.new(t)
	var c_n := _at(t, C, "N")
	t.switch(t.lights[_at(t, A, "N")])
	t.switch(t.lights[c_n])
	_run(t, 120.0)
	var through := log.through(c_n)
	var left := through.filter(func(c: Car) -> bool: return c.movement == RoadNet.Movement.LEFT)
	var right := through.filter(func(c: Car) -> bool: return c.movement == RoadNet.Movement.RIGHT)
	check(through.size() >= 10, "cars drove down from A through C: got %d" % through.size())
	check_eq(left.size() + right.size(), through.size(), "every one turned")
	check(left.size() >= through.size() / 4 and right.size() >= through.size() / 4,
			"both ways, about half each: %d left, %d right" % [left.size(), right.size()])
	check(left.all(func(c: Car) -> bool: return c.transform.origin.x > t.net.bounds.end.x), "the left turns left to the east")
	check(right.all(func(c: Car) -> bool: return c.transform.origin.x < t.net.bounds.position.x), "the right turns to the west")
	check(log.crashes.is_empty(), "no Crashes")


func test_with_turners_off_a_t_junction_approach_with_no_straight_exit_only_turns_right() -> void:
	var t := _calm(1, 9)  # Turners off: no left turns, so cars coming down from A into C all turn right, to the west
	var log := Log.new(t)
	var c_n := _at(t, C, "N")
	t.switch(t.lights[_at(t, A, "N")])
	t.switch(t.lights[c_n])
	_run(t, 90.0)
	var through := log.through(c_n)
	check(through.size() >= 10, "cars drove down from A through C: got %d" % through.size())
	check(through.all(func(c: Car) -> bool: return c.movement == RoadNet.Movement.RIGHT), "all turned right")


func test_a_t_junction_approach_with_no_right_turn_sends_its_right_turning_drivers_straight() -> void:
	var t := _calm(1, 9)
	t.k_right = 1.0  # every driver would turn right; from C's west road that's the south arm C doesn't have
	var c_w := _at(t, C, "W")
	var spawned: Array[Car] = []
	t.car_spawned.connect(func(c: Car) -> void: if c.light.id == c_w: spawned.append(c))
	t.switch(t.lights[c_w])
	_run(t, 40.0)
	check(spawned.size() >= 5, "cars came in to C from the west: got %d" % spawned.size())
	check(spawned.all(func(c: Car) -> bool: return c.movement == RoadNet.Movement.STRAIGHT), "all go straight")


# --- the 5-way ----------------------------------------------------------------------

func test_a_turner_on_a_5_way_holds_for_oncoming_traffic_and_goes_at_a_gap() -> void:
	# E's south road faces its north road. A Turner from the south turns left to the west or the north-west.
	var t := _calm(3, 17)
	var e_s := _at(t, E, "S")
	var e_n := _at(t, E, "N")
	var p := Plan.new(t, {e_s: [true], e_n: [false, false, false, false, false, false, false, false]})
	var log := Log.new(t)
	p.run(t, 10.0)  # both queue at Red
	var turner := p.car(e_s, 0)
	if not check(turner != null and p.car(e_n, 1) != null, "both roads have queued by 10s"):
		return
	t.switch(t.lights[e_s])
	t.switch(t.lights[e_n])
	var held_for_oncoming := false
	var oncoming_in_box_on_release := true
	var was_holding := false
	for i in 30 * Traffic.TICK_HZ:
		p.step(t)
		var oncoming := t.cars.filter(func(c: Car) -> bool: return c.light.id == e_n and _in_box(c))
		if turner.holding:
			held_for_oncoming = held_for_oncoming or not oncoming.is_empty()
			if turner.hold_time > 3.0 and t.lights[e_n].state == Light.State.GREEN:
				t.switch(t.lights[e_n])  # the oncoming road never leaves a gap at this stage's spawn rate: stop it
		elif was_holding:
			oncoming_in_box_on_release = not oncoming.is_empty()
		was_holding = turner.holding
		if log.exited.has(turner):
			break
	if not check(p.matches(), "spawns kept to the plan (else pick another seed)"):
		return
	check(held_for_oncoming, "the Turner held while an oncoming car was in the box")
	check(not oncoming_in_box_on_release, "the Turner went with no oncoming car in the box")
	check(log.exited.has(turner), "the Turner left the map")
	check(log.crashes.is_empty(), "no Crashes")


func test_cars_off_a_5_ways_diagonal_road_crash_with_cross_traffic() -> void:
	# The north-west road has no straight exit: its cars cut across or merge into the north road's.
	var t := _calm(1, 17)
	var log := Log.new(t)
	t.switch(t.lights[_at(t, E, "N")])
	t.switch(t.lights[_at(t, E, "NW")])
	for i in 40 * Traffic.TICK_HZ:
		t.step()
		if not log.crashes.is_empty():
			break
	if check(not log.crashes.is_empty(), "a Crash within 40s"):
		check(log.crashes[0].distance_to(t.net.crossings[E]) < 120.0, "in E's box, at %s" % log.crashes[0])


func test_opposing_straight_traffic_on_a_5_way_never_crashes() -> void:
	var t := _calm(1, 17)
	var log := Log.new(t)
	var e_n := _at(t, E, "N")
	var e_s := _at(t, E, "S")
	t.switch(t.lights[e_n])
	t.switch(t.lights[e_s])
	_run(t, 40.0)
	check(log.through(e_n).size() >= 5 and log.through(e_s).size() >= 5, "both roads flowed")
	check(log.crashes.is_empty(), "no Crashes")


func test_a_5_ways_diagonal_road_runs_to_the_map_edge_clear_of_its_neighbours() -> void:
	var net := _calm(1, 17).net
	var nw := net.approaches[net.approach_at(E, "NW")]
	check(nw.entry, "the north-west road is fed from the map edge")
	check(not net.bounds.has_point(net.segments[nw.incoming].curve.get_point_position(0)), "its cars start off the map")
	check(nw.direction.is_equal_approx(Vector2(1, 1).normalized()), "they drive in heading south-east, got %s" % nw.direction)
	_check_roads_part_by_the_stop_lines(net)


# --- the whole city -----------------------------------------------------------------

func test_a_stage_21_stagedef_builds_a_six_crossing_city_from_the_plans_arms() -> void:
	var t := _calm(1, 21)
	var net := t.net
	check_eq(net.crossings.size(), 6, "crossings at stage 21")
	var lights := 0
	for x in net.crossings.size():
		var arms: Array = City.ARMS[x]
		lights += arms.size()
		var here := net.approaches.filter(func(a: RoadNet.Approach) -> bool: return a.crossing == x)
		check_eq(here.size(), arms.size(), "an approach per arm at crossing %d" % x)
		for a: RoadNet.Approach in here:
			var outs: Array[float] = []
			for r in a.routes:
				outs.append(_deg(r.heading_out))
			outs.sort()
			var want: Array[float] = []
			for arm: int in arms:
				if arm != _deg(-a.direction):
					want.append(float(arm))
			want.sort()
			check_eq(outs, want, "crossing %d's %s road has a route out along every other arm" % [x, a.label])
	check_eq(t.lights.size(), lights, "a Light per arm")
	for l in City.LINKS:
		var d := (City.centre(l.y) - City.centre(l.x)).normalized()
		check(not net.approaches[net.approach_at(l.y, _compass(d))].entry, "link %s feeds %d from %d" % [l, l.y, l.x])
		check(not net.approaches[net.approach_at(l.x, _compass(-d))].entry, "link %s feeds %d from %d" % [l, l.x, l.y])
	check_eq(net.approaches.filter(func(a: RoadNet.Approach) -> bool: return a.entry).size(), 10, "ten entry roads")
	_check_roads_part_by_the_stop_lines(net)
	var log := Log.new(t)
	for a in net.approaches:
		if a.label == "N" or a.label == "S":
			t.switch(t.lights[net.approaches.find(a)])  # north-south green everywhere: on the T they turn
	_run(t, 40.0)
	check(log.exited.size() >= 20, "cars got through: %d" % log.exited.size())
	check(log.crashes.is_empty(), "no Crashes")


# A heading in whole degrees, 0 to 359: 0 is east, 90 south.
func _deg(v: Vector2) -> float:
	return fposmod(roundf(rad_to_deg(v.angle())), 360.0)


# The compass point cars heading `d` come in from.
func _compass(d: Vector2) -> String:
	return {Vector2.LEFT: "E", Vector2.RIGHT: "W", Vector2.UP: "S", Vector2.DOWN: "N"}[d.round()]


# At each stop line, a crossing's roads have parted: both lanes of each road are a lane's width clear of every other
# arm's lanes.
func _check_roads_part_by_the_stop_lines(net: RoadNet) -> void:
	for a in net.approaches:
		for b in net.approaches:
			if a.crossing != b.crossing or a == b:
				continue
			for p: Vector2 in [a.stop_point, net.segments[a.outgoing].curve.get_point_position(0)]:
				for lane: int in [b.incoming, b.outgoing]:
					var curve := net.segments[lane].curve
					var gap := curve.get_closest_point(p).distance_to(p)
					check(gap >= Tuning.LW - 0.01, "crossing %d: the %s road at its stop line is %.1f px from the %s road" % [a.crossing, a.label, gap, b.label])

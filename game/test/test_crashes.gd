extends TestCase
## Crashes, Wreckage and Tow (#22), black-box through Traffic: Switch, set_raccoon, tow, step.

const N := 0  # Light indices follow RoadNet.SIDE_NAMES: N, S, W, E
const S := 1
const W := 2
const E := 3


## Records what Traffic emits. Holds no reference to the Traffic, so nothing leaks.
class Log:
	var crashes: Array[Array] = []  # [a, b, at]
	var tows: Array[Array] = []  # [car, off_road]
	var exited: Array[Car] = []

	func _init(t: Traffic) -> void:
		t.crashed.connect(func(a: Car, b: Car, at: Vector2) -> void: crashes.append([a, b, at]))
		t.towed.connect(func(c: Car, off: bool) -> void: tows.append([c, off]))
		t.car_exited.connect(func(c: Car) -> void: exited.append(c))


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


## Green on N and W together, stepped until the first Crash (or 30s).
func _first_crash(seed_value := 3) -> Array:
	var t := Traffic.new(seed_value)
	var events := Log.new(t)
	t.switch(t.lights[N])
	t.switch(t.lights[W])
	for i in 30 * Traffic.TICK_HZ:
		t.step()
		if not events.crashes.is_empty():
			break
	return [t, events]


## Grab Wreckage w: stand on it and Tow.
func _grab(t: Traffic, w: Car) -> void:
	t.set_raccoon(w.transform.origin, false)
	t.tow(Tuning.TOW_RANGE)


## While towing, move the Raccoon so the Wreckage lands with its centre at `at`, and step once.
func _tow_to(t: Traffic, at: Vector2) -> void:
	var hold := t.towing.transform.origin - t.raccoon_position
	t.set_raccoon(at - hold, false)
	t.step()


func _moving_car(t: Traffic, light: int) -> Car:
	for c in t.cars:
		if not c.wreckage and c.light == t.lights[light] and c.speed > 100.0 and c.line_distance > 60.0:
			return c
	return null


## Step until a car from `light` is cruising on its incoming lane, at most `seconds`.
func _await_moving_car(t: Traffic, light: int, seconds := 10.0) -> Car:
	for i in roundi(seconds * Traffic.TICK_HZ):
		var c := _moving_car(t, light)
		if c != null:
			return c
		t.step()
	return null


# --- Crash detection --------------------------------------------------------------

func test_conflicting_cars_in_the_same_box_crash() -> void:
	var r := _first_crash()
	var t: Traffic = r[0]
	var events: Log = r[1]
	if not check_eq(events.crashes.size(), 1, "green both ways across the box makes a Crash within 30s"):
		return
	var a: Car = events.crashes[0][0]
	var b: Car = events.crashes[0][1]
	var at: Vector2 = events.crashes[0][2]
	check(a.wreckage and b.wreckage, "both cars are Wreckage")
	check(a.speed == 0.0 and b.speed == 0.0, "Wreckage doesn't move")
	check(absf(a.light.direction.dot(b.light.direction)) < 0.1, "the two came from crossing directions")
	check(at.length() < Tuning.STOP_D + Tuning.CAR_L, "it happened in the crossing box, at %s" % at)
	check(t.cars.has(a) and t.cars.has(b), "Wreckage stays on the road")
	var pose := a.transform
	_run(t, 2.0)
	check(a.transform == pose, "and stays put")


func test_cars_that_dont_conflict_never_crash() -> void:
	for pair: Array in [[N, S], [W, E]]:
		var t := Traffic.new(5)
		var events := Log.new(t)
		t.switch(t.lights[pair[0]])
		t.switch(t.lights[pair[1]])
		_run(t, 60.0)
		check_eq(events.crashes.size(), 0, "opposite straights on green together, %s" % [pair])
		check(events.exited.size() >= 20, "traffic flowed through: %d cars left" % events.exited.size())
		check(not t.cars.any(func(c: Car) -> bool: return c.wreckage), "no Wreckage")


func test_a_car_driving_into_wreckage_crashes() -> void:
	var r := _first_crash()
	var t: Traffic = r[0]
	var events: Log = r[1]
	if not check(not events.crashes.is_empty(), "a first Crash"):
		return
	var w: Car = events.crashes[0][0]
	_grab(t, w)
	t.switch(t.lights[E])
	var m := _await_moving_car(t, E)
	if not check(m != null, "a car cruising in on E"):
		return
	# Drop the Wreckage 2 px in front of its bumper: far too close to stop.
	var reach := 0.0
	for p in w.corners():
		reach = maxf(reach, (p - w.transform.origin).dot(m.transform.x))
	_tow_to(t, m.transform.origin + m.transform.x * (m.length / 2.0 + 2.0 + reach))
	t.tow(Tuning.TOW_RANGE)
	check(t.towing == null, "dropped")
	_run(t, 1.0)
	check(m.wreckage, "the car drove into the Wreckage")
	check(events.crashes.size() >= 2 and events.crashes.slice(1).any(
			func(e: Array) -> bool: return e[0] == m or e[1] == m), "and that's a Crash")


# --- Tow --------------------------------------------------------------------------

func test_tow_grabs_the_nearest_wreckage_in_range_and_slows_the_raccoon() -> void:
	var r := _first_crash()
	var t: Traffic = r[0]
	var events: Log = r[1]
	if not check(not events.crashes.is_empty(), "a first Crash"):
		return
	var a: Car = events.crashes[0][0]
	var b: Car = events.crashes[0][1]
	t.set_raccoon(Vector2(300, 200), false)
	t.tow(Tuning.TOW_RANGE)
	check(t.towing == null, "nothing in range, nothing towed")
	check_eq(t.raccoon_speed_scale(), 1.0, "full speed when not towing")
	# Just beyond a, on the side away from b: a is nearer.
	var away := (a.transform.origin - b.transform.origin).normalized()
	t.set_raccoon(a.transform.origin + away * 20.0, false)
	t.tow(Tuning.TOW_RANGE)
	check(t.towing == a, "grabs the nearest Wreckage")
	check(a.towed and not b.towed, "only that one is towed")
	check_eq(t.raccoon_speed_scale(), Tuning.TOW_SPEED, "towing walks at reduced speed")
	t.set_raccoon(Vector2(0, 150), false)  # down the N/S road, still on it
	_run(t, 0.5)
	check(a.transform.origin.distance_to(t.raccoon_position) <= Tuning.TOW_HOLD + 0.01, "the Wreckage follows the Raccoon")
	t.tow(Tuning.TOW_RANGE)
	check(t.towing == null and not a.towed, "Tow again drops it")
	check_eq(events.tows, [[a, false]] as Array[Array], "dropped on the road: towed, not off the road")
	check(t.cars.has(a) and a.wreckage, "it stays as Wreckage where it was dropped")
	check_eq(t.raccoon_speed_scale(), 1.0, "full speed again")


func test_towing_wreckage_off_the_road_removes_it() -> void:
	var r := _first_crash()
	var t: Traffic = r[0]
	var events: Log = r[1]
	if not check(not events.crashes.is_empty(), "a first Crash"):
		return
	var a: Car = events.crashes[0][0]
	_grab(t, a)
	t.set_raccoon(Vector2(150, 150), false)  # the grass between the roads
	t.step()
	check(t.towing == null, "leaving the road drops it")
	check_eq(events.tows, [[a, true]] as Array[Array], "towed, off the road")
	check(not t.cars.has(a), "it's gone from the road")
	check(not events.exited.has(a), "it didn't leave the map as traffic")


func test_towed_wreckage_never_crashes() -> void:
	var r := _first_crash()
	var t: Traffic = r[0]
	var events: Log = r[1]
	if not check(not events.crashes.is_empty(), "a first Crash"):
		return
	var w: Car = events.crashes[0][0]
	_grab(t, w)
	t.switch(t.lights[E])
	var m := _await_moving_car(t, E)
	if not check(m != null, "a car cruising in on E"):
		return
	for i in 2 * Traffic.TICK_HZ:
		_tow_to(t, m.transform.origin)  # right on top of it
	check_eq(events.crashes.size(), 1, "no Crash while the Wreckage is towed")
	check(not m.wreckage, "the car is fine")


func test_cars_brake_for_towed_wreckage() -> void:
	var r := _first_crash()
	var t: Traffic = r[0]
	var events: Log = r[1]
	if not check(not events.crashes.is_empty(), "a first Crash"):
		return
	var w: Car = events.crashes[0][0]
	_grab(t, w)
	t.switch(t.lights[E])
	var block := Vector2(250, -Tuning.LW / 2.0)  # in E's incoming lane, well before the box
	_tow_to(t, block)
	var ahead := t.cars.filter(func(c: Car) -> bool: return c.transform.origin.x < block.x)  # already past it
	for i in 10 * Traffic.TICK_HZ:
		_tow_to(t, block)
	check(t.towing == w, "still towing")
	check_eq(events.crashes.size(), 1, "no new Crash")
	var e_cars := t.cars.filter(func(c: Car) -> bool: return c.light == t.lights[E] and not c.wreckage and not ahead.has(c))
	check(e_cars.size() >= 2, "E traffic backed up behind it: %d cars" % e_cars.size())
	for c: Car in e_cars:
		check(c.transform.origin.x > block.x + 20.0, "car %d stopped short of the Wreckage, at x %.0f" % [c.id, c.transform.origin.x])
	check(e_cars.any(func(c: Car) -> bool: return c.speed < 1.0), "the front one is stopped")

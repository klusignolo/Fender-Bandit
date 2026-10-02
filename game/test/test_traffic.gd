extends TestCase
## Traffic, black-box (#19 Testing Decisions, seam 1): set up a scenario, step, then check state and signals.


## Records what Traffic emits. Holds no reference to the Traffic, so nothing leaks.
class Log:
	var spawned: Array[Car] = []
	var exited: Array[Car] = []
	var changes: Array[Light.State] = []

	func _init(t: Traffic) -> void:
		t.car_spawned.connect(func(c: Car) -> void: spawned.append(c))
		t.car_exited.connect(func(c: Car) -> void: exited.append(c))
		t.light_changed.connect(func(l: Light) -> void: changes.append(l.state))


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


func _cars_at(t: Traffic, l: Light) -> Array[Car]:
	return t.cars.filter(func(c: Car) -> bool: return c.light == l)


# --- stage 1 opening ----------------------------------------------------------

func test_stage_one_opens_on_red_with_the_first_car_about_three_seconds_in() -> void:
	for seed_value: int in [1, 2, 3, 4, 5]:
		var t := straight_traffic(seed_value)
		check_eq(t.lights.size(), 4, "one plain 4-way crossing has four Lights")
		check(t.lights.all(func(l: Light) -> bool: return l.state == Light.State.RED), "every Light starts on Red (seed %d)" % seed_value)
		var first := -1.0
		for i in 6 * Traffic.TICK_HZ:
			t.step()
			if first < 0.0 and not t.cars.is_empty():
				first = t.time
		check(first >= 2.0 and first <= 4.5, "first car at %.2fs, want about 3s (seed %d)" % [first, seed_value])


func test_spawned_cars_are_announced() -> void:
	var t := straight_traffic(1)
	var events := Log.new(t)
	_run(t, 10.0)
	check(events.spawned.size() >= 4, "about one car per entry every 3.2s: got %d in 10s" % events.spawned.size())
	check_eq(events.spawned.size(), t.cars.size(), "on all-Red nothing has left, so every spawned car is still on the map")


# --- the Light cycle ------------------------------------------------------------

func test_switch_takes_red_to_green_to_yellow_and_yellow_falls_to_red_by_itself() -> void:
	var t := straight_traffic(1)
	var events := Log.new(t)
	var l := t.lights[0]
	t.switch(l)
	check_eq(l.state, Light.State.GREEN, "Red Switches to Green")
	t.switch(l)
	check_eq(l.state, Light.State.YELLOW, "Green Switches to Yellow")
	t.switch(l)
	check_eq(l.state, Light.State.YELLOW, "Switching a Yellow Light does nothing")
	_run(t, 1.4)
	check_eq(l.state, Light.State.YELLOW, "still Yellow at 1.4s")
	_run(t, 0.2)
	check_eq(l.state, Light.State.RED, "Red by itself 1.5s after Yellow")
	check_eq(events.changes, [Light.State.GREEN, Light.State.YELLOW, Light.State.RED] as Array[Light.State], "light_changed once per change")
	for other in t.lights.slice(1):
		check_eq(other.state, Light.State.RED, "the other Lights are untouched")


# --- queueing and following -------------------------------------------------------

func test_cars_queue_behind_each_other_at_red_without_touching() -> void:
	var t := straight_traffic(7)
	_run(t, 30.0)
	for l in t.lights:
		var q := _cars_at(t, l)
		q.sort_custom(func(a: Car, b: Car) -> bool: return a.line_distance < b.line_distance)
		if not check(q.size() >= 4, "30s on Red queues several cars at %d, got %d" % [l.id, q.size()]):
			continue
		check(q[0].line_distance >= 0.0 and q[0].line_distance < 10.0, "the front car waits just short of the line, %.1f px" % q[0].line_distance)
		for i in q.size():
			check(q[i].speed < 1.0 or i == q.size() - 1, "queued car %d at Light %d is stopped" % [i, l.id])
			check(not q[i].passed_line, "nobody crosses on Red")
			if i > 0 and q[i].speed < 1.0:  # the last car may still be rolling in
				var gap := q[i].line_distance - q[i - 1].line_distance - q[i - 1].length
				check(gap > 2.0 and gap < 20.0, "bumper gap %d→%d at Light %d is %.1f px" % [i - 1, i, l.id, gap])


func test_green_lets_the_queue_drive_through_and_off_the_map() -> void:
	var t := straight_traffic(7)
	var events := Log.new(t)
	_run(t, 20.0)
	var l := t.lights[2]
	var queued := _cars_at(t, l)
	check(queued.size() >= 3, "a queue to release")
	t.switch(l)
	_run(t, 15.0)
	for c in queued:
		check(events.exited.has(c), "car %d left the map after Green" % c.id)
	check(not t.cars.any(func(c: Car) -> bool: return queued.has(c)), "exited cars are gone from Traffic")
	for other in t.lights:
		if other != l:
			check(events.exited.all(func(c: Car) -> bool: return c.light != other), "nothing left from a Red approach")


func test_a_follower_never_closes_on_the_car_in_front() -> void:
	var t := straight_traffic(3)
	t.switch(t.lights[0])
	for i in 40 * Traffic.TICK_HZ:
		t.step()
		var q := _cars_at(t, t.lights[0])
		for a in q:
			for b in q:
				if a != b and absf(a.s - b.s) < (a.length + b.length) / 2.0:
					check(false, "cars %d and %d overlap at %.2fs" % [a.id, b.id, t.time])
					return


# --- Yellow ---------------------------------------------------------------------

## Green on one Light, then Switch it to Yellow the moment a moving car is `near` to `far` px from the line.
func _yellow_with_car_at(near: float, far: float) -> Array:
	var t := straight_traffic(11)
	var l := t.lights[1]
	t.switch(l)
	for i in 30 * Traffic.TICK_HZ:
		t.step()
		for c in _cars_at(t, l):
			if not c.passed_line and c.line_distance >= near and c.line_distance <= far and c.speed > 100.0:
				t.switch(l)
				return [t, c]
	return [t, null]


func test_a_driver_close_to_the_line_on_yellow_pushes_through() -> void:
	var r := _yellow_with_car_at(5.0, 25.0)
	var t: Traffic = r[0]
	var c: Car = r[1]
	if not check(c != null, "a car reached the line on green"):
		return
	_run(t, 1.0)
	check(c.passed_line and c.line_distance < 0.0, "the driver went over the line, %.1f px" % c.line_distance)
	check(c.speed > 100.0, "without braking hard, %.0f px/s" % c.speed)


func test_a_driver_far_from_the_line_on_yellow_stops() -> void:
	var r := _yellow_with_car_at(150.0, 200.0)
	var t: Traffic = r[0]
	var c: Car = r[1]
	if not check(c != null, "a car approached on green"):
		return
	_run(t, 4.0)
	check(not c.passed_line and c.line_distance >= 0.0, "the driver stopped short of the line, %.1f px" % c.line_distance)
	check(c.speed < 1.0, "and waits at the Red that follows")

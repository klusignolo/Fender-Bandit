extends TestCase
## Dash, Yield and the Raccoon getting hit (#23), black-box through Traffic: set_raccoon, switch, tow, step.

const N := 0  # Light indices follow RoadNet.SIDE_NAMES: N, S, W, E
const W := 2
const E := 3
const E_LANE := -Tuning.LW / 2.0  # y of E's incoming lane; its cars drive toward -x


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


func _e_cars(t: Traffic) -> Array:
	return t.cars.filter(func(c: Car) -> bool: return c.light == t.lights[E] and not c.wreckage)


## Put the Raccoon just ahead of car m's bumper: far too close for it to stop.
func _step_in_front(t: Traffic, m: Car) -> void:
	t.set_raccoon(m.transform.origin + m.transform.x * (m.length / 2.0 + 4.0), false)


## Green on N and W together, stepped until the first Crash (or 30s): one of its Wreckage, or null.
func _wreckage(t: Traffic) -> Car:
	t.switch(t.lights[N])
	t.switch(t.lights[W])
	for i in 30 * Traffic.TICK_HZ:
		t.step()
		for c in t.cars:
			if c.wreckage:
				return c
	return null


## Step until a car is cruising in on E, well before the box, at most `seconds`.
func _await_moving_car(t: Traffic, seconds := 10.0) -> Car:
	for i in roundi(seconds * Traffic.TICK_HZ):
		for c: Car in _e_cars(t):
			if c.speed > 100.0 and c.line_distance > 60.0:
				return c
		t.step()
	return null


# --- Yield ------------------------------------------------------------------------

func test_cars_yield_to_the_raccoon_standing_in_their_lane() -> void:
	var t := straight_traffic(3)
	var hits := []
	t.raccoon_hit.connect(func(c: Car) -> void: hits.append(c))
	t.switch(t.lights[E])
	var stand := Vector2(250, E_LANE)  # well before the box
	t.set_raccoon(stand, false)
	_run(t, 12.0)
	var e_cars := _e_cars(t)
	check(e_cars.size() >= 2, "E traffic backed up behind the Raccoon: %d cars" % e_cars.size())
	for c: Car in e_cars:
		check(c.transform.origin.x > stand.x + Tuning.RACCOON_R + c.length / 2.0,
				"car %d stopped short of the Raccoon, at x %.0f" % [c.id, c.transform.origin.x])
	var front: float = e_cars.map(func(c: Car) -> float: return c.transform.origin.x - c.length / 2.0).min()
	check(front - stand.x <= 24.0, "the front one stops close, like the greybox (about 20 px from the Raccoon's centre): %.0f px" % (front - stand.x))
	check(e_cars.any(func(c: Car) -> bool: return c.speed < 1.0), "the front one is stopped")
	check_eq(hits, [], "nobody hit it")



func test_a_car_waiting_at_the_line_holds_for_the_raccoon_over_its_back_half() -> void:
	var t := straight_traffic(3)
	var hits := []
	t.raccoon_hit.connect(func(c: Car) -> void: hits.append(c))
	var m: Car = null
	for i in 10 * Traffic.TICK_HZ:
		t.step()
		m = _e_cars(t).filter(func(c: Car) -> bool: return c.speed < 1.0 and c.line_distance < 10.0).pop_front()
		if m != null:
			break
	if not check(m != null, "a car waiting at E's line"):
		return
	t.set_raccoon(m.transform.origin - m.transform.x * m.length / 4.0, false)  # over its back half
	var at := m.transform.origin
	t.switch(t.lights[E])
	_run(t, 2.0)
	check_eq(hits, [], "it doesn't run the Raccoon over")
	check(m.transform.origin.distance_to(at) < 1.0, "it holds")


# --- Getting hit -------------------------------------------------------------------

func test_a_car_too_fast_to_stop_hits_the_raccoon_and_knocks_it_back_stunned() -> void:
	var t := straight_traffic(3)
	var hits := []
	t.raccoon_hit.connect(func(c: Car) -> void: hits.append(c))
	t.switch(t.lights[E])
	var m := _await_moving_car(t)
	if not check(m != null, "a car cruising in on E"):
		return
	_step_in_front(t, m)
	t.step()
	_run(t, 0.3)
	check_eq(hits, [m], "that car hits the Raccoon, once")
	check(t.raccoon_stun > 0.0 and t.raccoon_stun < Tuning.STUN_TIME, "stunned: %.2fs left" % t.raccoon_stun)
	check(t.raccoon_knock.normalized().dot(m.transform.x) > 0.99, "knocked back the way the car drives")
	check(not m.wreckage, "the car drives on")


func test_getting_hit_drops_the_tow() -> void:
	var t := straight_traffic(3)
	var tows := []
	t.towed.connect(func(c: Car, off: bool) -> void: tows.append([c, off]))
	var w := _wreckage(t)
	if not check(w != null, "a first Crash"):
		return
	t.set_raccoon(w.transform.origin, false)
	t.tow(Tuning.TOW_RANGE)
	t.switch(t.lights[E])
	var m := _await_moving_car(t)
	if not check(t.towing == w and m != null, "towing, and a car cruising in on E"):
		return
	_step_in_front(t, m)
	t.step()
	check(t.raccoon_stun > 0.0, "hit")
	check(t.towing == null and not w.towed, "the Tow is dropped")
	check_eq(tows, [[w, false]], "dropped on the road")


func test_a_stunned_raccoon_cant_switch_or_tow_until_it_recovers() -> void:
	var t := straight_traffic(3)
	var w := _wreckage(t)
	if not check(w != null, "a first Crash"):
		return
	t.switch(t.lights[E])
	var m := _await_moving_car(t)
	if not check(m != null, "a car cruising in on E"):
		return
	_step_in_front(t, m)
	t.step()
	if not check(t.raccoon_stun > 0.0, "hit"):
		return
	t.set_raccoon(w.transform.origin, false)  # knocked onto the Wreckage
	t.tow(Tuning.TOW_RANGE)
	check(t.towing == null, "can't Tow while stunned")
	t.switch(t.lights[E])
	check_eq(t.lights[E].state, Light.State.GREEN, "can't Switch while stunned")
	_run(t, Tuning.STUN_TIME)
	check_eq(t.raccoon_stun, 0.0, "recovered after STUN_TIME")
	check_eq(t.raccoon_knock, Vector2.ZERO, "and the knockback has died away")
	t.tow(Tuning.TOW_RANGE)
	check(t.towing == w, "Tows again")
	t.switch(t.lights[E])
	check_eq(t.lights[E].state, Light.State.YELLOW, "Switches again")


# --- Dash ---------------------------------------------------------------------------

func test_dash_reaches_traffic_and_towing_slows_it() -> void:
	var t := straight_traffic(3)
	var w := _wreckage(t)
	if not check(w != null, "a first Crash"):
		return
	t.set_raccoon(Vector2(300, 200), true)
	check(t.raccoon_dashing, "Traffic knows the Raccoon is Dashing")
	check_eq(t.raccoon_speed_scale(), 1.0, "a Dash without a Tow is full Dash speed")
	t.set_raccoon(w.transform.origin, true)
	t.tow(Tuning.TOW_RANGE)
	check_eq(t.raccoon_speed_scale(), Tuning.TOW_DASH, "Dashing while towing")
	t.set_raccoon(w.transform.origin, false)
	check_eq(t.raccoon_speed_scale(), Tuning.TOW_SPEED, "walking while towing")

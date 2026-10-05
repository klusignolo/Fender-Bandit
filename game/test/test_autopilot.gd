extends TestCase
## The Attract autopilot (#34), through the real Raccoon: it reads the autopilot's intents instead of Input.
## Each tick steps the Raccoon, then Traffic, as World does.

const N := 0  # Light indices follow RoadNet.ARM_ORDER: N, S, W, E
const W := 2


## A Raccoon flown by an Autopilot over `t`, at zoom 1. Free it when done.
func _flown(t: Traffic) -> Raccoon:
	var r := Raccoon.new(t)
	r.position = t.raccoon_position
	r.pilot = Autopilot.new(t)
	return r


## Step the Raccoon and Traffic together for `seconds`, or until `stop` returns true. Returns the seconds run.
func _fly(t: Traffic, r: Raccoon, seconds: float, stop := func() -> bool: return false) -> float:
	for i in roundi(seconds * Traffic.TICK_HZ):
		r.step(Traffic.DT)
		t.step()
		if stop.call():
			return (i + 1) * Traffic.DT
	return seconds


## Cars held at a Light: on its approach, short of the line, not Wreckage.
func _waiting(t: Traffic, l: Light) -> int:
	return t.cars.filter(func(c: Car) -> bool: return c.light == l and not c.passed_line and not c.wreckage).size()


func test_it_first_switches_the_light_with_the_most_waiting_cars() -> void:
	var t := straight_traffic(4)
	for i in 8 * Traffic.TICK_HZ:  # every Light red: queues build
		t.step()
	var first: Array[Light] = []
	t.light_changed.connect(func(l: Light) -> void: first.append(l))
	var r := _flown(t)
	_fly(t, r, 10.0, func() -> bool: return not first.is_empty())
	r.free()
	if not check(not first.is_empty(), "it switched a Light within 10s"):
		return
	var most: int = t.lights.map(func(l: Light) -> int: return _waiting(t, l)).max()
	check_eq(first[0].state, Light.State.GREEN, "it turned a red Light green")
	check(_waiting(t, first[0]) + 1 >= most, "it picked a Light with about the most waiting cars: %d of %d" % [_waiting(t, first[0]), most])


func test_it_never_greens_a_light_while_a_crossing_one_is_green_or_yellow() -> void:
	for seed_value in [1, 2, 3]:
		var t := straight_traffic(seed_value)
		var greens := [0]
		var net := t.net  # not t itself: Traffic would hold a lambda that holds it, and leak
		var lights := t.lights
		t.light_changed.connect(func(l: Light) -> void:
			if l.state != Light.State.GREEN:
				return
			greens[0] += 1
			var opposite := net.approaches[l.id].opposite
			for o in lights:
				if o != l and o.id != opposite and o.state != Light.State.RED:
					failures.append("seed %d: Light %d went green while Light %d was %s" % [seed_value, l.id, o.id, Light.State.keys()[o.state]]))
		var r := _flown(t)
		_fly(t, r, 60.0)
		r.free()
		check(greens[0] >= 4, "seed %d: it kept the Lights cycling: %d greens in 60s" % [seed_value, greens[0]])


func test_it_keeps_stage_1_straight_traffic_flowing_without_crashes() -> void:
	var t := straight_traffic(5)
	var crashes := [0]
	t.crashed.connect(func(_a: Car, _b: Car, _at: Vector2) -> void: crashes[0] += 1)
	var r := _flown(t)
	_fly(t, r, 60.0)
	r.free()
	check_eq(crashes[0], 0, "Crashes in 60s")
	check(t.jam.level() != Jam.Level.GRIDLOCK, "no Gridlock in 60s")
	check(t.cars_through >= 30, "cars got through: %d" % t.cars_through)


func test_it_plays_stage_1_without_gridlock() -> void:
	for seed_value in [1, 2, 3]:
		var t := Traffic.new(seed_value, 0, Stages.def(1, seed_value))
		var over := [false]
		t.gridlocked.connect(func() -> void: over[0] = true)
		var r := _flown(t)
		var lasted := _fly(t, r, 90.0, func() -> bool: return over[0] or t.cleared)
		r.free()
		check(not over[0], "seed %d: no Gridlock (%s after %.1fs, %d cars through)" % [seed_value, "cleared" if t.cleared else "still going", lasted, t.cars_through])


func test_it_tows_nearby_wreckage_off_the_road() -> void:
	var t := straight_traffic(3)
	t.switch(t.lights[N])
	t.switch(t.lights[W])
	var wreck: Car = null
	while wreck == null and t.time < 30.0:
		t.step()
		for c in t.cars:
			if c.wreckage:
				wreck = c
	if not check(wreck != null, "a Crash within 30s"):
		return
	t.switch(t.lights[N])  # both to Yellow, so no more Crashes pile on
	t.switch(t.lights[W])
	var gone: Array[Car] = []
	t.towed.connect(func(c: Car, off_road: bool) -> void:
		if off_road:
			gone.append(c))
	var r := _flown(t)
	_fly(t, r, 20.0, func() -> bool: return gone.has(wreck))
	r.free()
	check(gone.has(wreck), "it towed the first Wreckage off the road within 20s")

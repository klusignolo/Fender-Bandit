extends TestCase
## Garbage trucks (#46), black-box through Traffic: their Debut at stage 6, footprint, pace and livery, and the trash
## stop: once per crossing a truck pulls up at its pickup point short of the stop line, collects for PICKUP_TIME and
## holds up its lane, then drives on.

const N := 0  # Light indices follow RoadNet.ARM_ORDER: N, S, W, E
const S := 1
const KIND := Car.Kind


class Log:
	var spawned: Array[Car] = []
	var crashes := 0

	func _init(t: Traffic) -> void:
		t.car_spawned.connect(func(c: Car) -> void: spawned.append(c))
		t.crashed.connect(func(_a: Car, _b: Car, _at: Vector2) -> void: crashes += 1)


func _trucks(seed_value: int, share := 1.0) -> Traffic:
	var t := straight_traffic(seed_value)
	t.k_garbage = share
	return t


func test_garbage_trucks_debut_at_stage_6() -> void:
	for n in range(1, 10):  # the Opening; from stage 10 a generated stage may draw the feature off
		var d := Stages.def(n, 1)
		check_eq(d.garbage, Tuning.GARBAGE_SHARE if n >= 6 else 0.0, "stage %d's garbage truck share" % n)
	check_eq(Stages.news(Stages.def(6, 1)), PackedStringArray(["Garbage trucks"]), "stage 6's news")


func test_a_garbage_truck_has_its_footprint_pace_and_livery() -> void:
	var t := _trucks(4)
	var log := Log.new(t)
	for i in roundi(20.0 * Traffic.TICK_HZ):
		t.step()
	check(not log.spawned.is_empty(), "trucks spawn")
	for c in log.spawned:
		check_eq(c.kind, KIND.GARBAGE, "every vehicle is a truck at a share of 1")
		check_eq([c.length, c.width, c.pace], [Tuning.GARBAGE_L, Tuning.GARBAGE_W, Tuning.GARBAGE_PACE], "its footprint and pace")
		check_eq(c.tint, Car.GARBAGE_TINT, "the municipal livery, not a random tint")


func test_no_trucks_without_the_share() -> void:
	var t := straight_traffic(4)
	t.k_motorcycles = 0.3
	t.k_semis = 0.3
	var log := Log.new(t)
	for i in roundi(30.0 * Traffic.TICK_HZ):
		t.step()
	check(log.spawned.all(func(c: Car) -> bool: return c.kind != KIND.GARBAGE), "no garbage trucks at a zero share")


func test_a_truck_stops_once_at_its_pickup_point_then_drives_through() -> void:
	var t := _trucks(5)
	t.switch(t.lights[N])
	t.switch(t.lights[S])
	var log := Log.new(t)
	var first: Car = null
	var stopped := 0.0  # seconds the first truck sat still before its line
	var collecting := 0.0
	var at := -1.0  # its centre's distance along its route while it stood
	for i in roundi(30.0 * Traffic.TICK_HZ):
		t.step()
		if first == null:  # the first truck on the green N road
			for c in log.spawned:
				if c.light == t.lights[N]:
					first = c
					break
		if first == null or first.passed_line or not t.cars.has(first):
			continue
		if first.speed < Tuning.WAIT_SPEED:
			stopped += Traffic.DT
			at = first.s
		if first.collecting:
			collecting += Traffic.DT
	check(first != null and first.passed_line, "the first truck gets through on green")
	check_near(stopped, Tuning.PICKUP_TIME, 0.4, "it stands for its pickup, on green")
	check_near(collecting, Tuning.PICKUP_TIME, 0.1, "collecting the whole time")
	if first != null:
		check_near(at, first.route.stop_s - Tuning.PICKUP_BEFORE, 2.0, "at its pickup point, short of the line")
	check_eq(log.crashes, 0, "the cars behind queue without a Crash")


func test_mixed_traffic_with_trucks_flows_on_green_without_crashing() -> void:
	for seed_value in [3, 7]:
		var t := _trucks(seed_value, 0.3)
		t.switch(t.lights[N])
		t.switch(t.lights[S])
		var log := Log.new(t)
		for i in roundi(60.0 * Traffic.TICK_HZ):
			t.step()
		check_eq(log.crashes, 0, "no Crash on N–S green with trucks stopping (seed %d)" % seed_value)
		check(t.cars_through > 10, "traffic still flows past the stops (seed %d): %d out" % [seed_value, t.cars_through])

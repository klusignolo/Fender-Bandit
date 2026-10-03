extends TestCase
## The city plan and crossings linked by roads (#31), black-box through Traffic and its RoadNet.

# Light indices: each crossing's four, in attach order, by RoadNet.SIDE_NAMES (N, S, W, E). An approach is named
# for the side its cars come in from: A_W's cars come in from the west and drive east, toward B.
const A_S := 1
const A_W := 2
const A_E := 3
const B_W := 6
const B_E := 7


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


## Records each car's Light as it spawns and as it exits. Holds no reference to the Traffic, so nothing leaks.
class Journeys:
	var spawned_at: Dictionary[int, int] = {}  # car id → the Light it spawned at
	var exited: Array[Car] = []
	var crashes := 0

	func _init(t: Traffic) -> void:
		t.car_spawned.connect(func(c: Car) -> void: spawned_at[c.id] = c.light.id)
		t.car_exited.connect(func(c: Car) -> void: exited.append(c))
		t.crashed.connect(func(_a: Car, _b: Car, _at: Vector2) -> void: crashes += 1)

	## The cars that spawned at Light `from` and left the map through Light `through`'s crossing.
	func cars(from: int, through: int) -> Array[Car]:
		return exited.filter(func(c: Car) -> bool: return spawned_at[c.id] == from and c.light.id == through)

	func count(from: int, through: int) -> int:
		return cars(from, through).size()


# --- the plan -------------------------------------------------------------------

func test_the_map_has_the_stages_crossings_from_the_plan_in_attach_order() -> void:
	for stage: int in [1, 4, 9, 13, 17, 21]:
		var t := straight_traffic(1, stage)
		var want := Stages.def(stage, 1).crossings
		check_eq(t.net.crossings.size(), want, "crossings at stage %d" % stage)
		check_eq(t.lights.size(), want * 4, "four Lights per crossing at stage %d" % stage)
		for k in t.net.crossings.size():
			check_eq(t.net.crossings[k], City.centre(k), "crossing %d at stage %d is where the plan puts it" % [k, stage])


func test_the_second_crossing_attaches_east_of_the_first_linked_by_one_road() -> void:
	var net := straight_traffic(1, 4).net
	check_eq(net.crossings[1], Vector2(Tuning.LINK, 0.0), "the second crossing is one LINK east")
	check(not net.approaches[B_W].entry and not net.approaches[A_E].entry, "the approaches along the link aren't fed from the map edge")
	check_eq(net.approaches.filter(func(a: RoadNet.Approach) -> bool: return a.entry).size(), 6, "six entry roads")
	check_eq(net.approaches[A_W].outgoing, net.approaches[B_W].incoming, "eastbound: the first crossing's way out is the second's way in")
	check_eq(net.approaches[B_E].outgoing, net.approaches[A_E].incoming, "westbound: the second crossing's way out is the first's way in")


func test_the_map_is_16_by_9_so_every_entry_road_runs_to_the_frame_edge() -> void:
	for stage: int in [1, 4, 9, 13, 21]:
		var b := straight_traffic(1, stage).net.bounds
		check_near(b.size.x / b.size.y, 16.0 / 9.0, 0.001, "map aspect at stage %d" % stage)
		for c in straight_traffic(1, stage).net.crossings:
			check(b.grow(-minf(Tuning.ARM_X, Tuning.ARM_Y) + 1.0).has_point(c), "an arm's length of road around %s at stage %d" % [c, stage])


# --- routes across crossings ------------------------------------------------------

func test_a_car_drives_straight_through_both_crossings() -> void:
	var t := straight_traffic(1, 4)
	var journeys := Journeys.new(t)
	t.switch(t.lights[A_W])
	t.switch(t.lights[B_W])
	_run(t, 30.0)
	check(journeys.count(A_W, B_W) >= 3, "cars from the first crossing's west entry leave past the second: got %d" % journeys.count(A_W, B_W))
	check_eq(journeys.count(A_W, A_W), 0, "none leave the map at the first crossing")
	check_eq(journeys.crashes, 0, "no Crashes")


func test_a_car_chooses_its_movement_afresh_at_the_next_crossing() -> void:
	# Half the drivers turn right. From the first crossing's south entry only those that turn right reach the link
	# east; at the second crossing each rolls again, so some go straight on east and some turn right, to the south.
	var t := straight_traffic(1, 4)
	t.k_right = 0.5
	var journeys := Journeys.new(t)
	t.switch(t.lights[A_S])
	t.switch(t.lights[B_W])
	_run(t, 90.0)
	var through := journeys.cars(A_S, B_W)
	var straight := through.filter(func(c: Car) -> bool: return c.movement == RoadNet.Movement.STRAIGHT)
	var right := through.filter(func(c: Car) -> bool: return c.movement == RoadNet.Movement.RIGHT)
	check(straight.size() >= 2, "some went straight on at the second crossing: got %d" % straight.size())
	check(right.size() >= 2, "some turned right again: got %d" % right.size())
	check(straight.all(func(c: Car) -> bool: return c.transform.origin.x > t.net.crossings[1].x), "...those left to the east")
	check(right.all(func(c: Car) -> bool: return c.transform.origin.y > t.net.crossings[1].y), "...and those to the south")
	check_eq(journeys.crashes, 0, "no Crashes")


func test_a_queue_at_the_second_crossing_backs_up_along_the_link_and_into_the_first() -> void:
	var t := straight_traffic(1, 4)
	var journeys := Journeys.new(t)
	t.switch(t.lights[A_W])  # A_W green feeds the link; B_W stays red
	_run(t, 90.0)
	var queue := t.cars.filter(func(c: Car) -> bool: return journeys.spawned_at[c.id] == A_W)
	check(queue.size() >= 15, "a long queue built up: got %d cars" % queue.size())
	check_eq(journeys.count(A_W, B_W), 0, "nothing ran the red at the second crossing")
	check_eq(journeys.crashes, 0, "no Crashes")
	check(queue.any(func(c: Car) -> bool: return c.light.id == A_W and c.passed_line),
			"the queue reaches back past the first crossing's stop line")
	check(queue.all(func(c: Car) -> bool: return c.speed < Tuning.WAIT_SPEED), "the whole queue is stopped")
	for i in queue.size():
		for j in range(i + 1, queue.size()):
			check(not queue[i].overlaps(queue[j]), "cars %d and %d don't overlap" % [queue[i].id, queue[j].id])
	for c: Car in queue:
		if c.light.id == B_W:
			check(c.line_distance >= 0.0, "car %d waits behind the second crossing's stop line" % c.id)


# --- the Jam ------------------------------------------------------------------------

func test_the_jam_drains_twice_as_fast_with_two_crossings() -> void:
	for stage: int in [1, 4]:
		var t := straight_traffic(1, stage)
		t.jam.fill = 20.0
		_run(t, 1.0)  # before the first car, so nothing fills it
		var crossings := t.net.crossings.size()
		check_near(20.0 - t.jam.fill, Tuning.JAM_DRAIN * crossings, 0.001, "drained in a second with %d crossings" % crossings)

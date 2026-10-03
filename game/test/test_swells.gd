extends TestCase
## Swells and entry backlog (#27), black-box through Traffic (step, switch, swell, swell_next, swell_left,
## swell_warning(), backlog(), and the car_spawned and swell_flagged signals).

const N := 0  # Light indices follow RoadNet.SIDE_NAMES: N, S, W, E
const S := 1
const W := 2
const E := 3


## Straight traffic with Swells on, as in the game.
func _swelling(seed_value: int) -> Traffic:
	var t := straight_traffic(seed_value)
	t.k_swell = true
	return t


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


## Counts the cars spawned at each entry. Holds no reference to the Traffic, so nothing leaks.
class Spawns:
	var at: Array[int] = [0, 0, 0, 0]

	func _init(t: Traffic) -> void:
		t.car_spawned.connect(func(c: Car) -> void: at[c.light.id] += 1)


func test_the_swell_road_spawns_at_twice_the_rate_and_the_others_at_two_thirds() -> void:
	# At four reds every car that comes due is either spawned or still in its entry's backlog, so the two
	# together count the cars due. Each one is credited to the Swell road or the others, by when it came due.
	var t := _swelling(1)
	var spawns := Spawns.new(t)
	var due := [0, 0, 0, 0]
	var heavy := 0
	var light := 0
	while t.time < 300.0:
		t.step()
		for i in 4:
			var now := spawns.at[i] + t.backlog(i)
			if now > due[i]:
				if i == t.swell:
					heavy += now - due[i]
				else:
					light += now - due[i]
				due[i] = now
	var gap: float = Tuning.K_GAP[0]
	check_near(heavy / t.time, Tuning.SWELL_HEAVY / gap, 0.1 * Tuning.SWELL_HEAVY / gap, "cars due a second on the Swell road")
	check_near(light / (3.0 * t.time), Tuning.SWELL_LIGHT / gap, 0.1 * Tuning.SWELL_LIGHT / gap, "cars due a second on each other road")


func test_the_swell_moves_to_its_next_road_every_20_to_30_seconds() -> void:
	var t := _swelling(2)
	check(t.swell_next != t.swell, "the first Swell's next road is another road")
	check(t.swell_left >= Tuning.SWELL_MIN and t.swell_left <= Tuning.SWELL_MAX, "first Swell lasts %.2fs, want 20–30s" % t.swell_left)
	var moved_at := 0.0
	var moves := 0
	var lengths := {}
	while t.time < 300.0:
		var was := t.swell
		var next := t.swell_next
		t.step()
		if t.swell == was:
			continue
		moves += 1
		var length := t.time - moved_at
		moved_at = t.time
		lengths[snappedf(length, 0.5)] = true
		check(length >= Tuning.SWELL_MIN - Traffic.DT and length <= Tuning.SWELL_MAX + Traffic.DT, "a Swell lasted %.2fs, want 20–30s" % length)
		check_eq(t.swell, next, "the road the Swell moved to at %.2fs" % t.time)
		check(t.swell_next != t.swell, "the next road differs from the Swell road at %.2fs" % t.time)
	check(moves >= 9, "Swell moves in 300s: %d, want 10 or so" % moves)
	check(lengths.size() >= 3, "Swells vary in length: %s" % [lengths.keys()])


func test_the_next_swell_is_flagged_shift_warn_before_it_moves() -> void:
	var t := _swelling(3)
	var flags: Array[int] = []  # the road of each swell_flagged
	t.swell_flagged.connect(func(next: int) -> void: flags.append(next))
	var warned_from := -1.0
	var moves := 0
	while t.time < 200.0:
		var was := t.swell
		var next := t.swell_next
		var warned := t.swell_warning()
		var flagged := flags.size()
		t.step()
		if t.swell_warning() and not warned:
			warned_from = t.time
			if check_eq(flags.size(), flagged + 1, "swell_flagged as the warning starts at %.2fs" % t.time):
				check_eq(flags[-1], t.swell_next, "the road flagged at %.2fs" % t.time)
		elif flags.size() != flagged:
			check(false, "swell_flagged at %.2fs without the warning starting" % t.time)
		if t.swell != was:
			moves += 1
			check(warned, "the warning was up just before the move at %.2fs" % t.time)
			check_eq(t.swell, next, "the road the Swell moved to")
			check_near(t.time - warned_from, Tuning.SHIFT_WARN, Traffic.DT * 1.01, "warning time before the move at %.2fs" % t.time)
			check(not t.swell_warning(), "the warning is down once the Swell has moved, at %.2fs" % t.time)
	check(moves >= 6, "Swell moves in 200s: %d" % moves)


func test_cars_that_cant_get_onto_a_full_entry_road_wait_in_its_backlog() -> void:
	# N and S on green keep their roads moving; W and E stay red until their queues reach the map edge.
	var t := straight_traffic(1)
	t.switch(t.lights[N])
	t.switch(t.lights[S])
	var spawns := Spawns.new(t)
	var full_at := -1.0  # when W's road first had no room for a car that came due
	while t.time < 90.0:
		t.step()
		for i in [N, S]:
			if not check_eq(t.backlog(i), 0, "backlog on green road %s at %.2fs" % [RoadNet.SIDE_NAMES[i], t.time]):
				return
		if full_at < 0.0 and t.backlog(W) > 0:
			full_at = t.time
	check(full_at > 20.0 and full_at < 60.0, "W's road was full at %.2fs, want 20–60s" % full_at)
	var waiting := t.backlog(W)
	# W got no further cars on once full, so each car due since then is waiting: one per k_gap or so.
	check_near(waiting, (t.time - full_at) / t.k_gap, 5.0, "W's backlog after %.0fs full" % (t.time - full_at))
	check(t.backlog(E) > 0, "E's road is full too: backlog %d" % t.backlog(E))
	# Green on W: its backlog drives on as the road clears.
	t.switch(t.lights[W])
	t.switch(t.lights[N])  # N and S to Red, so W crosses nothing
	t.switch(t.lights[S])
	var before := spawns.at[W]
	while t.backlog(W) > 0 and t.time < 200.0:
		t.step()
	check_eq(t.backlog(W), 0, "W's backlog once its road was moving")
	check(spawns.at[W] - before >= waiting, "cars on at W while its backlog cleared: %d, want %d+" % [spawns.at[W] - before, waiting])


func test_each_car_in_a_backlog_fills_the_jam_0_6_a_second() -> void:
	# At four reds the four front drivers reach their second Honk by 25s: 4.0/s less the 1.5/s drain is
	# 2.5/s. Once the queues reach the map edge, each car waiting to get on adds 0.6/s.
	var t := straight_traffic(1)
	_run(t, 25.0)
	var backed_up := 0.0  # seconds with a backlog somewhere
	while t.time < 90.0 and t.jam.level() != Jam.Level.GRIDLOCK:
		var before := t.jam.fill
		t.step()
		var waiting := 0
		for i in 4:
			waiting += t.backlog(i)
		if waiting > 0:
			backed_up += Traffic.DT
		if t.jam.level() == Jam.Level.GRIDLOCK:
			break
		var honks := t.cars.filter(func(c: Car) -> bool: return c.honks > 0).map(func(c: Car) -> int: return c.honks)
		if not check_eq(honks, [2, 2, 2, 2], "Honks at %.2fs" % t.time):
			return
		check_near((t.jam.fill - before) / Traffic.DT, 2.5 + Tuning.JAM_BACKLOG * waiting, 0.001, "Jam fill a second at %.2fs, %d car(s) waiting" % [t.time, waiting])
	check(backed_up >= 3.0, "seconds with a backlog before Gridlock: %.2f, want 3+" % backed_up)

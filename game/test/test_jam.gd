extends TestCase
## The Jam, Dents and a bare Gridlock (#26), black-box through Traffic (step, switch, the crashed, car_exited,
## jam_level_changed and gridlocked signals) and, for what one crossing can't show, Jam itself.

const N := 0  # Light indices follow RoadNet.ARM_ORDER: N, S, W, E
const S := 1
const W := 2
const E := 3


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


func _honks(t: Traffic) -> Array[int]:
	var out: Array[int] = []
	for c in t.cars:
		if c.honks > 0:
			out.append(c.honks)
	return out


func test_nothing_fills_the_jam_until_a_driver_honks() -> void:
	var t := straight_traffic(1)
	while _honks(t).is_empty() and t.time < 20.0:
		t.step()
		check_eq(t.jam.fill, 0.0, "Jam at %.2fs, before any Honk" % t.time)


func test_four_drivers_on_their_second_honk_fill_the_jam_at_2_5_a_second() -> void:
	# Four front drivers at 1.0/s each, less the drain of 1.5/s for the one crossing.
	var t := straight_traffic(1)
	_run(t, 25.0)
	check_eq(_honks(t), [2, 2, 2, 2] as Array[int], "Honks of the drivers Honking after 25s at four red Lights")
	var before := t.jam.fill
	_run(t, 1.0)
	check_eq(_honks(t), [2, 2, 2, 2] as Array[int], "Honks of the drivers Honking a second later")
	check_near(t.jam.fill - before, 2.5, 0.001, "Jam fill over that second")


func test_each_car_that_leaves_drains_0_4() -> void:
	# Fill the Jam at four reds, then wave N and S on. W and E keep their two drivers on their second Honk,
	# 2.0/s less the 1.5/s drain, so the Jam still rises 0.5/s, less 0.4 for each car that leaves.
	var t := straight_traffic(1)
	_run(t, 25.0)
	t.switch(t.lights[N])
	t.switch(t.lights[S])
	var exits := [0]
	t.car_exited.connect(func(_c: Car) -> void: exits[0] += 1)
	var seen := 0
	while t.time < 40.0:
		var before := t.jam.fill
		exits[0] = 0
		t.step()
		if not check_eq(_honks(t), [2, 2] as Array[int], "Honks at %.2fs, with W and E still red" % t.time):
			return
		seen += exits[0]
		check_near(t.jam.fill - before, 0.5 * Traffic.DT - 0.4 * exits[0], 0.0001, "Jam change in a tick %d car(s) left, at %.2fs" % [exits[0], t.time])
	check(seen >= 4, "cars that left: %d, want 4+" % seen)


## Green everywhere, stepped until `crashes` Crashes (or 30s). Returns the Crashes counted.
func _crash(t: Traffic, crashes: int) -> int:
	var seen := [0]
	t.crashed.connect(func(_a: Car, _b: Car, _at: Vector2) -> void: seen[0] += 1)
	for l in t.lights:
		t.switch(l)
	while seen[0] < crashes and t.time < 30.0:
		t.step()
	return seen[0]


func test_each_crash_leaves_a_dent() -> void:
	var t := straight_traffic(1)
	check_eq(t.jam.dents, 0, "Dents in a fresh Run")
	if check_eq(_crash(t, 2), 2, "Crashes with every Light green within 30s"):
		check_eq(t.jam.dents, 2, "Dents after two Crashes")


func test_a_stage_starts_with_the_dents_the_run_hands_it() -> void:
	var t := Traffic.new(3, 5)
	t.k_right = 0.0
	t.k_turners = 0.0
	t.k_swell = false
	check_eq(t.jam.dents, 5, "Dents handed to the stage")
	check_eq(t.jam.fill, 0.0, "Jam at the stage start")
	if check_eq(_crash(t, 1), 1, "Crashes with every Light green within 30s"):
		check_eq(t.jam.dents, 6, "Dents after one more Crash")


# --- Jam itself: what one crossing can't show -------------------------------------------

func _jam(crossings: int, dents: int, fill: float) -> Jam:
	var j := Jam.new(crossings, dents)
	j.fill = fill
	return j


func _second(j: Jam, honking: float) -> void:
	for i in Traffic.TICK_HZ:
		j.step(honking, Traffic.DT)


func test_the_drain_is_1_5_a_second_for_each_crossing() -> void:
	for x: Array in [[1, 8.5, 12.5], [2, 7.0, 11.0], [3, 5.5, 9.5]]:  # crossings, fill after 1s idle, ...and with 4.0/s of Honking
		var idle := _jam(x[0], 0, 10.0)
		_second(idle, 0.0)
		check_near(idle.fill, x[1], 0.0001, "Jam over 1s from 10 with %d crossing(s) and nobody Honking" % x[0])
		var honking := _jam(x[0], 0, 10.0)
		_second(honking, 4.0)
		check_near(honking.fill, x[2], 0.0001, "Jam over 1s from 10 with %d crossing(s) and 4.0/s of Honking" % x[0])


func test_each_dent_takes_2_off_the_capacity_down_to_a_floor_of_10() -> void:
	for x: Array in [[0, 100.0], [1, 98.0], [10, 80.0], [45, 10.0], [60, 10.0]]:  # Dents, capacity
		check_near(Jam.new(1, x[0]).capacity(), x[1], 0.0001, "capacity with %d Dents" % x[0])


func test_jam_levels_are_shares_of_the_capacity_left_after_dents() -> void:
	# 10 Dents leave 80: Busy from 40% (32), Heavy from 70% (56), Gridlock when full (80).
	for x: Array in [[0.0, Jam.Level.CLEAR], [31.9, Jam.Level.CLEAR], [32.0, Jam.Level.BUSY], [55.9, Jam.Level.BUSY],
			[56.0, Jam.Level.HEAVY], [79.9, Jam.Level.HEAVY], [80.0, Jam.Level.GRIDLOCK]]:
		check_eq(_jam(1, 10, x[0]).level(), x[1], "Jam-level at %.1f of 80" % x[0])


func test_the_jam_fills_only_up_to_the_capacity_left_after_dents() -> void:
	var j := _jam(1, 10, 79.0)
	_second(j, 10.0)
	check_near(j.fill, 80.0, 0.0001, "Jam after 1s of 10/s Honking from 79 of 80")
	j.dent()
	check_near(j.fill, 78.0, 0.0001, "Jam after a Dent takes the capacity to 78")
	check_eq(j.level(), Jam.Level.GRIDLOCK, "Jam-level when a Dent leaves it full")


# --- Jam-levels and Gridlock through Traffic ------------------------------------------

## Steps Traffic, recording each jam_level_changed level and each change of jam.level() polled after a step.
class Levels:
	var heard: Array[Jam.Level] = []
	var polled: Array[Jam.Level] = []
	var gridlocks := 0
	var _last := Jam.Level.CLEAR

	func _init(t: Traffic) -> void:
		t.jam_level_changed.connect(func(l: Jam.Level) -> void: heard.append(l))
		t.gridlocked.connect(func() -> void: gridlocks += 1)

	func run(t: Traffic, seconds: float) -> void:
		for i in roundi(seconds * Traffic.TICK_HZ):
			t.step()
			if t.jam.level() != _last:
				_last = t.jam.level()
				polled.append(_last)


func test_the_jam_level_signal_fires_on_each_change_up_and_down() -> void:
	# Four reds fill the Jam to Heavy. Then the Lights take turns, N/S then W/E, 6s of green each: a driver
	# held at red Honks once at most (0.5/s), so two of them can't beat the drain and the Jam empties.
	var t := straight_traffic(1)
	var levels := Levels.new(t)
	while t.jam.level() != Jam.Level.HEAVY and t.time < 60.0:
		levels.run(t, Traffic.DT)
	for i in 8:
		var pair := [N, S] if i % 2 == 0 else [W, E]
		for l: int in pair:
			t.switch(t.lights[l])  # Green
		levels.run(t, 6.0)
		for l: int in pair:
			t.switch(t.lights[l])  # Yellow, then Red
		levels.run(t, Tuning.YELLOW_TIME + 0.5)
	check_eq(levels.heard, levels.polled, "levels signalled, against each change seen after a step")
	check_eq(levels.heard.slice(0, 2), [Jam.Level.BUSY, Jam.Level.HEAVY] as Array[Jam.Level], "first levels signalled, on the way up")
	check_eq(levels.heard.back() if not levels.heard.is_empty() else null, Jam.Level.CLEAR, "last level signalled, once the Lights take turns")
	check_eq(t.jam.dents, 0, "Dents along the way")


func test_a_full_jam_reports_gridlock_once_and_stays_full() -> void:
	# Four reds fill the Jam at 2.5/s once every front driver is on its second Honk.
	var t := straight_traffic(1)
	var levels := Levels.new(t)
	while levels.gridlocks == 0 and t.time < 90.0:
		levels.run(t, Traffic.DT)
	if not check_eq(levels.gridlocks, 1, "Gridlocks within 90s at four reds"):
		return
	check_eq(t.jam.level(), Jam.Level.GRIDLOCK, "Jam-level at Gridlock")
	check_eq(levels.heard.back(), Jam.Level.GRIDLOCK, "last level signalled")
	# Waving N and S on would drain the Jam, but the Run is over.
	var heard := levels.heard.size()
	t.switch(t.lights[N])
	t.switch(t.lights[S])
	levels.run(t, 10.0)
	check_eq(levels.gridlocks, 1, "Gridlocks 10s later")
	check_eq(levels.heard.size(), heard, "levels signalled in those 10s")
	check_eq(t.jam.fill, t.jam.capacity(), "Jam 10s after Gridlock")

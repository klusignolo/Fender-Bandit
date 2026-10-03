extends TestCase
## The Quota and the drain (#29), black-box on Traffic: a stage's Traffic built from its StageDef, stepped
## until its Quota is met, then drained until stage_cleared.

const N := 0  # Light indices follow RoadNet.SIDE_NAMES: N, S, W, E
const S := 1
const W := 2
const E := 3


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


func test_the_quota_is_the_target_length_over_the_spawn_gap_for_each_entry() -> void:
	# One crossing: 4 entries. Stage 1: 45s ÷ 3.2s × 4 = 56.25. Stage 5: 60s ÷ 2.375s × 4 = 101.05.
	check_eq(Traffic.new(1, 0, Stages.def(1, 1)).quota, 56, "stage 1's Quota")
	check_eq(Traffic.new(1, 0, Stages.def(5, 1)).quota, 101, "stage 5's Quota")


func test_traffic_takes_its_stage_knobs_and_features() -> void:
	var t2 := Traffic.new(1, 0, Stages.def(2, 1))
	check_near(t2.k_gap, 2.925, 0.0001, "stage 2's spawn gap")
	check_near(t2.k_speed, 1.05, 0.0001, "stage 2's car speed")
	check_near(t2.k_patience, 14.625, 0.0001, "stage 2's Patience")
	check_eq(t2.k_turners, 0.0, "no Turners at stage 2")
	check(not t2.blowing_unlocked, "no Blowing the red at stage 2")
	var t7 := Traffic.new(1, 0, Stages.def(7, 1))
	check_near(t7.k_turners, 0.15, 0.0001, "stage 7's Turner share")
	check(t7.blowing_unlocked, "Blowing the red is on from stage 7")
	var off := Stages.def(12, 1)
	off.features.erase(Stages.Feature.TURNERS)
	check_eq(Traffic.new(1, 0, off).k_turners, 0.0, "a generated stage without Turners has none")
	check_near(Traffic.new(1).k_gap, Tuning.K_GAP[0], 0.0001, "with no StageDef, Traffic plays stage 1")


## Records stage_cleared, car_spawned and crashed. Holds no reference to the Traffic, so nothing leaks.
class Log:
	var met := 0
	var spawned := 0
	var crashes := 0

	func _init(t: Traffic) -> void:
		t.stage_cleared.connect(func() -> void: met += 1)
		t.car_spawned.connect(func(_c: Car) -> void: spawned += 1)
		t.crashed.connect(func(_a: Car, _b: Car, _at: Vector2) -> void: crashes += 1)


## Wave N and S on, so cars get through, until the Quota is met (or 40s have gone by).
func _meet(t: Traffic) -> void:
	t.switch(t.lights[N])
	t.switch(t.lights[S])
	for i in 40 * Traffic.TICK_HZ:
		if t.draining:
			return
		t.step()


func test_meeting_the_quota_stops_spawning_and_clears_the_backlog() -> void:
	var t := straight_traffic(1)
	t.quota = 3
	var log := Log.new(t)
	_meet(t)
	check(t.draining, "the Quota of 3 is met with N and S on Green")
	check_eq(t.cars_through, 3, "cars through when the Quota is met")
	var spawned := log.spawned
	_run(t, 10.0)
	check_eq(log.spawned, spawned, "no car spawns during the drain")
	for i in t.lights.size():
		check_eq(t.backlog(i), 0, "entry %d's backlog during the drain" % i)
	check_eq(log.met, 0, "W and E stay on Red, so their cars haven't drained yet")


func test_the_drain_ends_once_every_moving_car_is_off_the_map() -> void:
	var t := straight_traffic(1)
	t.k_gap = 1000.0  # one car per entry
	t.quota = 2
	var log := Log.new(t)
	_run(t, 5.0)  # every entry's first car is on the map by 4.5s
	_meet(t)  # N's and S's cars out
	check(t.draining, "N's and S's cars met the Quota")
	t.switch(t.lights[N])  # to Yellow, then Red
	t.switch(t.lights[S])
	_run(t, 3.0)
	check_eq(log.met, 0, "W's and E's cars are still waiting at Red")
	t.switch(t.lights[W])
	t.switch(t.lights[E])
	_run(t, 8.0)
	check_eq(log.met, 1, "stage_cleared, once, after W's and E's cars are out")
	check(t.cars.is_empty(), "the map is empty")


func test_the_drain_gives_up_after_twelve_seconds() -> void:
	var t := straight_traffic(1)
	t.quota = 2
	var log := Log.new(t)
	_meet(t)
	var from := t.time
	var met_at := -1.0
	for i in 20 * Traffic.TICK_HZ:  # W and E stay on Red: their queues never drain
		t.step()
		if log.met > 0 and met_at < 0.0:
			met_at = t.time
	check_eq(log.met, 1, "stage_cleared, once")
	check_near(met_at - from, Tuning.DRAIN_MAX, 2.0 * Traffic.DT, "the drain's length")


func test_crashes_still_count_during_the_drain_but_the_jam_is_held() -> void:
	var t := straight_traffic(1)
	t.quota = 2
	var log := Log.new(t)
	_meet(t)
	t.jam.fill = 30.0
	t.switch(t.lights[W])  # into N and S's Green: a Crash
	t.switch(t.lights[E])
	_run(t, 8.0)
	check(log.crashes > 0, "a Crash during the drain is signalled")
	check(t.jam.dents > 0, "and Dents the Jam")
	check_eq(t.jam.fill, 30.0, "the Jam neither fills nor drains during the drain")

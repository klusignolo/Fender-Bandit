extends TestCase
## The Quota (#29, #45), black-box on Traffic: a stage's Traffic built from its StageDef, stepped until its Quota
## is met, which clears the stage on that tick.

const N := 0  # Light indices follow RoadNet.ARM_ORDER: N, S, W, E
const S := 1
const W := 2
const E := 3


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


func test_the_quota_is_the_target_length_over_the_spawn_gap_for_each_entry() -> void:
	# Stage 1, one crossing with 4 entries: 24s ÷ 3.2s × 4 = 30. Stage 5, two linked crossings with 6 entries:
	# 49.5s ÷ 2.375s × 6 = 125.05.
	check_eq(Traffic.new(1, 0, Stages.def(1, 1)).quota, 30, "stage 1's Quota")
	check_eq(Traffic.new(1, 0, Stages.def(5, 1)).quota, 125, "stage 5's Quota")


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


## Records stage_cleared, car_spawned and car_exited. Holds no reference to the Traffic, so nothing leaks.
class Log:
	var met := 0
	var spawned := 0
	var exited := 0

	func _init(t: Traffic) -> void:
		t.stage_cleared.connect(func() -> void: met += 1)
		t.car_spawned.connect(func(_c: Car) -> void: spawned += 1)
		t.car_exited.connect(func(_c: Car) -> void: exited += 1)


## Wave N and S on, so cars get through, until the stage clears (or 40s have gone by).
func _meet(t: Traffic) -> void:
	t.switch(t.lights[N])
	t.switch(t.lights[S])
	for i in 40 * Traffic.TICK_HZ:
		if t.cleared:
			return
		t.step()


func test_the_stage_clears_on_the_tick_the_quota_is_met() -> void:
	var t := straight_traffic(1)
	t.quota = 3
	var log := Log.new(t)
	_meet(t)
	check(t.cleared, "the Quota of 3 is met with N and S on Green")
	check_eq(t.cars_through, 3, "cars through when the stage clears")
	check_eq(log.met, 1, "stage_cleared, once")
	check(not t.cars.is_empty(), "the cars still on the map don't hold it up")


func test_a_cleared_stage_stops() -> void:
	var t := straight_traffic(1)
	t.quota = 3
	var log := Log.new(t)
	_meet(t)
	var spawned := log.spawned
	var exited := log.exited
	_run(t, 5.0)
	check_eq(log.met, 1, "stage_cleared, still once")
	check_eq(log.spawned, spawned, "no car spawns")
	check_eq(log.exited, exited, "no car leaves")


func test_meet_quota_clears_the_stage_on_the_next_tick() -> void:
	var t := straight_traffic(1)
	var log := Log.new(t)
	t.meet_quota()
	t.step()
	check(t.cleared, "cleared")
	check_eq(log.met, 1, "stage_cleared, once")

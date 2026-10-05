extends TestCase
## Score and Combo (#28): a Run driven by its Traffic's signals. Most tests emit the signals directly, so
## each Combo value is exact; the last steps real traffic to show the Run is wired to it.

const N := 0  # Light indices follow RoadNet.ARM_ORDER: N, S, W, E
const S := 1


## Records what Run emits. Holds no reference to the Run, so nothing leaks.
class Log:
	var stepped: Array[int] = []  # multipliers
	var broken: Array[int] = []  # Combo lost

	func _init(r: Run) -> void:
		r.combo_stepped.connect(func(m: int) -> void: stepped.append(m))
		r.combo_broken.connect(func(lost: int) -> void: broken.append(lost))


func _run_on(t: Traffic) -> Run:
	var r := Run.new()
	r.attach(t)
	return r


## A stand-in car: Run only counts cars, it never looks at one.
func _car() -> Car:
	return Car.new(0, null, null)


func _exits(t: Traffic, n: int) -> void:
	for i in n:
		t.car_exited.emit(_car())


## A Crash as Traffic makes one: a Dent in the Jam, then the signal.
func _crash(t: Traffic) -> void:
	t.jam.dent()
	t.crashed.emit(_car(), _car(), Vector2.ZERO)


func test_each_exit_adds_combo_and_scores_with_its_multiplier() -> void:
	var t := straight_traffic(1)
	var r := _run_on(t)
	# 10 × (1 + combo / 5): ×1 for Combo 1–4, ×2 for 5–9, ×3 from 10
	var want := [10, 20, 30, 40, 60, 80, 100, 120, 140, 170, 200]
	for i in want.size():
		_exits(t, 1)
		check_eq(r.combo, i + 1, "combo after exit %d" % (i + 1))
		check_eq(r.score, want[i], "score after exit %d" % (i + 1))
	check_eq(r.multiplier(), 3, "multiplier at Combo 11")


func test_a_crash_resets_combo_but_keeps_the_score() -> void:
	var t := straight_traffic(1)
	var r := _run_on(t)
	_exits(t, 7)  # 4 × 10 + 3 × 20
	_crash(t)
	check_eq(r.combo, 0, "combo after the Crash")
	check_eq(r.multiplier(), 1, "multiplier after the Crash")
	check_eq(r.score, 100, "score after the Crash")
	_exits(t, 1)
	check_eq(r.score, 110, "the next exit scores at ×1")


func test_wreckage_towed_off_the_road_scores_the_tow_bonus() -> void:
	var t := straight_traffic(1)
	var r := _run_on(t)
	_exits(t, 2)
	t.towed.emit(_car(), false)
	check_eq(r.score, 20, "Wreckage dropped on the road scores nothing")
	t.towed.emit(_car(), true)
	check_eq(r.score, 25, "Wreckage dropped off the road scores the Tow bonus")
	check_eq(r.combo, 2, "a Tow leaves Combo alone")


func test_the_stage_counts_its_crashes_and_best_combo() -> void:
	var t := straight_traffic(1)
	var r := _run_on(t)
	check_eq(r.stage, 1, "a Run starts at stage 1")
	_exits(t, 6)
	_crash(t)
	_exits(t, 3)
	_crash(t)
	_crash(t)  # a pile-up into the Wreckage: one more Crash
	_exits(t, 2)
	check_eq(r.crashes, 3, "crashes")
	check_eq(r.best_combo, 6, "best Combo")
	check_eq(r.dents, 3, "a Dent per Crash")


func test_the_next_stage_resets_its_stats_but_keeps_score_combo_and_dents() -> void:
	var t := straight_traffic(1)
	var r := _run_on(t)
	_exits(t, 12)
	_crash(t)
	_exits(t, 7)  # best Combo 12, Combo 7
	var score := r.score
	r.next_stage()
	check_eq(r.stage, 2, "the stage after")
	check_eq(r.score, score, "the score carries over")
	check_eq(r.combo, 7, "the Combo carries over")
	check_eq(r.crashes, 0, "the new stage's Crashes")
	check_eq(r.best_combo, 7, "the new stage's best Combo starts at the Combo carried over")
	check_eq(r.stage_score(), 0, "nothing scored yet this stage")
	var t2 := Traffic.new(2, r.dents)
	r.attach(t2)
	check_eq(r.dents, 1, "the Dents carry over")
	_exits(t2, 1)
	check_eq(r.stage_score(), 20, "this stage's score: Combo 8 scores ×2")


func test_dents_come_from_the_stage_jam() -> void:
	check_eq(Run.new().dents, 0, "a Run with no stage yet")
	var r := _run_on(Traffic.new(1, 2))
	check_eq(r.dents, 2, "the Dents a stage starts with")


func test_combo_signals_its_steps_and_breaks() -> void:
	var t := straight_traffic(1)
	var r := _run_on(t)
	var log := Log.new(r)
	_crash(t)
	check_eq(log.broken, [] as Array[int], "a Crash with no Combo breaks nothing")
	_exits(t, 11)
	check_eq(log.stepped, [2, 3] as Array[int], "steps at Combo 5 and 10")
	_crash(t)
	check_eq(log.broken, [11] as Array[int], "the break carries the Combo lost")


func test_real_traffic_scores() -> void:
	var t := straight_traffic(1)
	var r := _run_on(t)
	t.switch(t.lights[N])
	t.switch(t.lights[S])
	for i in 40 * Traffic.TICK_HZ:
		t.step()
	check(r.score > 0, "cars exiting score: got %d" % r.score)
	check(r.combo > 0, "and build Combo: got %d" % r.combo)
	check_eq(r.crashes, 0, "crashes with N and S green")


func test_the_run_keeps_the_results_card_stats_across_stages() -> void:
	var t := straight_traffic(1)
	var r := _run_on(t)
	_exits(t, 9)
	_crash(t)
	_crash(t)
	_exits(t, 3)  # stage 1: 12 cars, best Combo 9, 2 Crashes
	r.next_stage()
	var t2 := Traffic.new(2, r.dents)
	r.attach(t2)
	_exits(t2, 4)  # Combo 7
	_crash(t2)
	_exits(t2, 1)  # stage 2: 5 cars, best Combo 7, 1 Crash
	check_eq(r.cars_through, 17, "cars through, every stage")
	check_eq(r.top_combo, 9, "best Combo of the Run")
	check_eq(r.most_crashes, 2, "most Crashes in one stage")
	r.next_stage()
	var t3 := Traffic.new(3, r.dents)
	r.attach(t3)
	for i in 3:
		_crash(t3)
	check_eq(r.most_crashes, 3, "a later stage can beat it")
	check_eq(r.dents, 6, "the Dents, every stage")

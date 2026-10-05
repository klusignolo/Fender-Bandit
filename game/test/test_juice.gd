extends TestCase
## Crash juice (#43): the hit-stop freeze and the camera shake. Juice counts physics ticks, so a freeze only delays
## the fixed-step simulation: the same seed reaches the same board, a few ticks later.


## Ticks `j` `n` times; returns the Traffic steps they owed.
func _ticks(j: Juice, n: int) -> int:
	var steps := 0
	for i in n:
		steps += j.tick()
	return steps


func test_with_no_crash_each_tick_owes_one_step_at_full_speed() -> void:
	var j := Juice.new()
	check_eq(_ticks(j, 600), 600, "steps over 600 ticks")
	check_eq(j.time_scale(), 1.0, "time scale")


func test_a_crash_freezes_the_board_for_about_60_ms() -> void:
	var j := Juice.new()
	j.crash()
	check_eq(j.time_scale(), 0.0, "the engine stops at once")
	check_eq(_ticks(j, Tuning.CRASH_FREEZE), 0, "no steps through the freeze")
	check_eq(j.time_scale(), 1.0, "the engine runs again after it")
	check_eq(j.tick(), 1, "then a step a tick")
	check_near(Tuning.CRASH_FREEZE / float(Traffic.TICK_HZ), 0.06, 0.01, "the freeze in seconds")


func test_crashes_in_one_tick_freeze_once() -> void:
	var j := Juice.new()
	j.crash()
	j.crash()
	check_eq(_ticks(j, Tuning.CRASH_FREEZE), 0, "frozen")
	check_eq(j.tick(), 1, "not frozen twice as long")


func test_slow_mo_owes_steps_at_its_share() -> void:
	var j := Juice.new()
	j.slowmo = 0.25
	check_eq(_ticks(j, 400), 100, "a quarter of the ticks")
	check_eq(j.time_scale(), 0.25, "the engine runs at the slow-mo")


func test_the_shake_kicks_on_a_crash_and_settles() -> void:
	var j := Juice.new()
	check_eq(j.shake(), Vector2.ZERO, "still before a Crash")
	j.crash()
	var most := 0.0
	for i in 20:
		j.tick()
		most = maxf(most, j.shake().length())
	check(most > 1.0, "a Crash shakes the camera: at most %.2f px" % most)
	check(most <= Tuning.SHAKE_PX * sqrt(2.0), "a small shake: %.2f px" % most)
	_ticks(j, ceili(Traffic.TICK_HZ / Tuning.SHAKE_DECAY))
	check_eq(j.shake(), Vector2.ZERO, "settled within a second of trauma")


func test_kicks_add_up_to_full_trauma_and_no_more() -> void:
	var j := Juice.new()
	for i in 5:
		j.kick(0.5)
	check_eq(j.trauma, 1.0, "trauma caps at 1")


func test_the_shake_repeats_from_the_same_crashes() -> void:
	var a := Juice.new()
	var b := Juice.new()
	_ticks(a, 7)
	_ticks(b, 7)
	a.crash()
	b.crash()
	_ticks(a, 3)
	_ticks(b, 3)
	check_eq(a.shake(), b.shake(), "the same shake")


## A seeded board stepped through Juice, freezing on every Crash, reaches the same state as one stepped plainly.
func test_freezes_only_delay_the_fixed_step_simulation() -> void:
	var plain := straight_traffic(3)
	var juiced := straight_traffic(3)
	for t: Traffic in [plain, juiced]:
		t.switch(t.lights[0])  # Green on N and W together: they crash (test_crashes.gd)
		t.switch(t.lights[2])
	var j := Juice.new()
	juiced.crashed.connect(func(_a: Car, _b: Car, _at: Vector2) -> void: j.crash())
	var crashes := [0]
	plain.crashed.connect(func(_a: Car, _b: Car, _at: Vector2) -> void: crashes[0] += 1)
	var n := 60 * 60
	for i in n:
		plain.step()
	var steps := 0
	var ticks := 0
	while steps < n:
		ticks += 1
		for k in j.tick():
			juiced.step()
			steps += 1
	check(crashes[0] > 0, "the board crashed, so it froze")
	check(ticks > n and ticks <= n + crashes[0] * Tuning.CRASH_FREEZE, "the freezes took %d extra ticks" % (ticks - n))
	check_eq(juiced.cars.size(), plain.cars.size(), "the same cars")
	check_eq(juiced.jam.fill, plain.jam.fill, "the same Jam")
	for i in plain.cars.size():
		check_eq(juiced.cars[i].transform, plain.cars[i].transform, "car %d in the same pose" % i)

extends TestCase
## What the board sounds like (#37, docs/audio.md "Sound list"): BoardCues turns a stage's Traffic, Run and Raccoon
## signals into named SFX cues for Audio, and the scrape loop on and off. Also the Traffic and Raccoon signals added
## for it: tow_grabbed, yielded and dashed.

const N := 0  # Light indices follow RoadNet.ARM_ORDER: N, S, W, E
const W := 2
const E := 3
const E_LANE := -Tuning.LW / 2.0  # y of E's incoming lane; its cars drive toward -x


## Cues heard from a BoardCues: [sound, pitch] pairs, and the scrape loop's on/off calls.
class Ear:
	var cues: BoardCues  # held, as Audio holds it: a dropped BoardCues is disconnected
	var heard: Array[StringName] = []
	var pitches: Array[float] = []
	var scrape: Array[bool] = []

	func listen(cues: BoardCues) -> void:
		cues.cue.connect(_on_cue)
		cues.scrape.connect(_on_scrape)

	func _on_cue(sound: StringName, pitch: float) -> void:
		heard.append(sound)
		pitches.append(pitch)

	func _on_scrape(on: bool) -> void:
		scrape.append(on)


## An Ear on `cues`, holding them unless `hold` is false.
func _ear(cues: BoardCues, hold := true) -> Ear:
	var ear := Ear.new()
	ear.listen(cues)
	if hold:
		ear.cues = cues
	return ear


func _car(t: Traffic, id: int) -> Car:
	var c := Car.new(id, t.net.routes[0], t.lights[0])
	return c


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


# --- Lights ----------------------------------------------------------------------

func test_a_switch_to_green_or_yellow_and_the_fall_to_red_each_have_a_clack() -> void:
	var t := straight_traffic(1)
	var ear := _ear(BoardCues.new(t, Run.new()))
	t.switch(t.lights[N])
	t.switch(t.lights[N])
	_run(t, Tuning.YELLOW_TIME + 0.1)
	check_eq(ear.heard, [&"switch_green", &"switch_yellow", &"light_red"], "Red → Green, Green → Yellow, Yellow falls to Red")


# --- drivers ---------------------------------------------------------------------

func test_each_honk_has_its_own_sound_and_each_car_its_own_pitch() -> void:
	var t := straight_traffic(1)
	var ear := _ear(BoardCues.new(t, Run.new()))
	var a := _car(t, 7)
	var b := _car(t, 8)
	a.honks = 1
	t.honked.emit(a)
	a.honks = 2
	t.honked.emit(a)
	b.honks = 1
	t.honked.emit(b)
	check_eq(ear.heard, [&"honk_1", &"honk_2", &"honk_1"], "the first Honk, then the second")
	check_eq(ear.pitches[0], ear.pitches[1], "one car keeps its horn")
	check(ear.pitches[0] != ear.pitches[2], "another car's horn is pitched differently")
	for p in ear.pitches:
		check(absf(p - 1.0) <= Tuning.SFX_JITTER + 0.0001, "pitch %s is within the jitter" % p)


func test_blowing_the_red_the_hit_and_the_swell_whistle() -> void:
	var t := straight_traffic(1)
	var ear := _ear(BoardCues.new(t, Run.new()))
	t.blew_red.emit(_car(t, 1))
	t.raccoon_hit.emit(_car(t, 2))
	t.swell_flagged.emit(1)
	check_eq(ear.heard, [&"blow_red", &"raccoon_hit", &"swell"], "one each")


func test_crashes_pick_one_of_three_crunches() -> void:
	var t := straight_traffic(1)
	var ear := _ear(BoardCues.new(t, Run.new()))
	for i in 30:
		t.crashed.emit(_car(t, 1), _car(t, 2), Vector2.ZERO)
	var kinds := {}
	for s in ear.heard:
		kinds[s] = true
	check_eq(kinds.keys().size(), 3, "all three crunches turn up: %s" % [kinds.keys()])
	for s: StringName in kinds:
		check([&"crash_1", &"crash_2", &"crash_3"].has(s), "%s is a crunch" % s)
	for p in ear.pitches:
		check(absf(p - 1.0) <= Tuning.SFX_JITTER + 0.0001, "pitch %s is within the jitter" % p)


# --- the Jam, the Combo and the stage ---------------------------------------------

func test_a_beep_on_each_jam_level_rise_and_none_as_it_falls() -> void:
	var t := straight_traffic(1)
	var ear := _ear(BoardCues.new(t, Run.new()))
	for l: Jam.Level in [Jam.Level.BUSY, Jam.Level.HEAVY, Jam.Level.BUSY, Jam.Level.CLEAR, Jam.Level.HEAVY]:
		t.jam_level_changed.emit(l)
	check_eq(ear.heard, [&"jam_busy", &"jam_heavy", &"jam_heavy"], "up to Busy, up to Heavy; down is quiet; Clear straight to Heavy beeps Heavy")


func test_combo_steps_and_breaks() -> void:
	var t := straight_traffic(1)
	var run := Run.new()
	run.attach(t)
	var ear := _ear(BoardCues.new(t, run))
	for i in Tuning.COMBO_STEP:
		t.car_exited.emit(_car(t, i))
	t.crashed.emit(_car(t, 1), _car(t, 2), Vector2.ZERO)
	check_eq(ear.heard.slice(0, 1), [&"combo_up"], "a blip at the step")
	check(ear.heard.has(&"combo_break"), "the wah-wah when a Crash ends it: %s" % [ear.heard])


func test_the_next_stage_cues_once_after_the_last_stages_cues_are_dropped() -> void:
	var run := Run.new()
	var t1 := straight_traffic(1)
	run.attach(t1)
	var first := _ear(BoardCues.new(t1, run), false)  # the BoardCues is dropped here, as Audio drops the last stage's
	var t2 := straight_traffic(2)
	run.next_stage()
	run.attach(t2)
	var cues := BoardCues.new(t2, run)
	var ear := _ear(cues)
	for i in Tuning.COMBO_STEP:
		t2.car_exited.emit(_car(t2, i))
	check_eq(ear.heard, [&"combo_up"], "one blip from this stage's cues")
	check_eq(first.heard, [], "none from the last stage's, which are gone")


func test_the_stinger_cues_when_the_stage_is_cleared() -> void:
	var t := straight_traffic(1)
	var ear := _ear(BoardCues.new(t, Run.new()))
	t.stage_cleared.emit()
	check_eq(ear.heard, [&"stinger"], "the stage-clear stinger")


# --- Tow -------------------------------------------------------------------------

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


func test_a_tow_clunks_and_scrapes_until_it_is_dropped() -> void:
	var t := straight_traffic(5)
	var grabbed := []
	t.tow_grabbed.connect(func(c: Car) -> void: grabbed.append(c.id))
	var w := _wreckage(t)
	if not check(w != null, "a Crash to tow"):
		return
	var ear := _ear(BoardCues.new(t, Run.new()))
	t.set_raccoon(w.transform.origin, false)
	t.tow(Tuning.TOW_RANGE)
	check_eq(grabbed, [t.towing.id] if t.towing != null else [-1], "tow_grabbed names the Wreckage taken")
	t.tow(Tuning.TOW_RANGE)
	check_eq(ear.heard, [&"tow_grab"], "the grab clunk")
	check_eq(ear.scrape, [true, false], "the scrape loops while towing, and stops on the drop")


func test_tow_reaching_nothing_is_silent() -> void:
	var t := straight_traffic(5)
	var ear := _ear(BoardCues.new(t, Run.new()))
	var grabbed := []
	t.tow_grabbed.connect(func(c: Car) -> void: grabbed.append(c))
	t.tow(Tuning.TOW_RANGE)
	check_eq(grabbed, [], "nothing grabbed")
	check_eq(ear.heard, [], "no clunk")
	check_eq(ear.scrape, [], "no scrape")


# --- Yield -----------------------------------------------------------------------

func test_a_car_braking_for_the_raccoon_squeals_once() -> void:
	var t := straight_traffic(3)
	var yields := []
	t.yielded.connect(func(c: Car) -> void: yields.append(c.id))
	var ear := _ear(BoardCues.new(t, Run.new()))
	t.switch(t.lights[E])
	t.set_raccoon(Vector2(250, E_LANE), false)  # in E's lane, well before the box
	_run(t, 12.0)
	check(yields.size() >= 1, "the first car on E Yields")
	var counts := {}
	for id: int in yields:
		counts[id] = counts.get(id, 0) + 1
	for id: int in counts:
		check_eq(counts[id], 1, "car %d squeals once as it pulls up" % id)
	check_eq(ear.heard.count(&"yield"), yields.size(), "a brake squeal for each")


func test_a_car_pulling_away_into_the_raccoon_doesnt_squeal() -> void:
	var t := straight_traffic(3)
	var yields := []
	t.yielded.connect(func(c: Car) -> void: yields.append(c.id))
	_run(t, 8.0)  # E's queue waits at its red
	var front: Car = null
	for c in t.cars:
		if c.light == t.lights[E] and (front == null or c.line_distance < front.line_distance):
			front = c
	if not check(front != null and front.speed < 1.0, "a car stopped at E's red"):
		return
	t.set_raccoon(front.transform.origin + front.transform.x * (front.length / 2.0 + Tuning.RACCOON_R + 20.0), false)
	t.switch(t.lights[E])
	_run(t, 3.0)
	check_eq(yields, [], "too slow to squeal, from a standstill")


# --- Dash ------------------------------------------------------------------------

func test_a_dash_whooshes_when_it_starts() -> void:
	var t := straight_traffic(1)
	var r := Raccoon.new(t)
	r.position = t.raccoon_position
	var ear := _ear(BoardCues.new(t, Run.new(), r))
	r._pressed.dash = true
	r._physics_process(Traffic.DT)
	r._pressed.dash = true  # still on cooldown: no second Dash
	r._physics_process(Traffic.DT)
	check_eq(ear.heard, [&"dash"], "one whoosh")
	r.free()

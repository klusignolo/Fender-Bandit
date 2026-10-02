extends TestCase
## Right turns and Turners (#24), black-box through Traffic: the k_right and k_turners knobs, Switch, step.

const N := 0  # Light indices follow RoadNet.SIDE_NAMES: N, S, W, E
const S := 1
const W := 2
const E := 3


func _traffic(seed_value: int, right: float, turners: float) -> Traffic:
	var t := Traffic.new(seed_value)
	t.k_right = right
	t.k_turners = turners
	return t


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


func _cars_of(t: Traffic, light: int) -> Array[Car]:
	var out: Array[Car] = []
	for c in t.cars:
		if c.light == t.lights[light]:
			out.append(c)
	return out


# --- Right turns ------------------------------------------------------------------

func test_right_turners_wait_for_green_then_turn_right() -> void:
	var t := _traffic(1, 1.0, 0.0)
	_run(t, 12.0)
	var queue := _cars_of(t, N)
	if not check(not queue.is_empty(), "N has cars after 12s"):
		return
	for c in t.cars:
		check_eq(c.movement, RoadNet.Movement.RIGHT, "car %d's movement with k_right at 1" % c.id)
		check(c.line_distance >= 0.0, "car %d stays behind its red line (%.1f px)" % [c.id, c.line_distance])
	var exited: Array[Car] = []
	t.car_exited.connect(func(c: Car) -> void: exited.append(c))
	t.switch(t.lights[N])
	for i in 15 * Traffic.TICK_HZ:
		t.step()
		if not exited.is_empty():
			break
	if not check(not exited.is_empty(), "an N car leaves within 15s of Green"):
		return
	var out := exited[0]
	check_eq(out.light, t.lights[N], "the first car out came from N")
	# N traffic heads down the screen; its driver's right is west.
	check(out.transform.x.dot(Vector2.LEFT) > 0.99, "it leaves heading west, got %s" % out.transform.x)
	check(out.transform.origin.x < t.net.bounds.position.x, "it leaves past the west edge, at %s" % out.transform.origin)


func test_right_turners_never_wait_for_a_gap() -> void:
	var t := _traffic(2, 0.5, 0.0)  # half turn right, half go straight, both ways
	var crashes := [0]
	t.crashed.connect(func(_a: Car, _b: Car, _at: Vector2) -> void: crashes[0] += 1)
	t.switch(t.lights[N])
	t.switch(t.lights[S])
	var slowest := INF
	var against_oncoming := 0  # ticks a right-turner was in the box with an oncoming car going straight through
	for i in 40 * Traffic.TICK_HZ:
		t.step()
		for c in t.cars:
			if c.movement != RoadNet.Movement.RIGHT or not c.passed_line or c.past_box():
				continue
			slowest = minf(slowest, c.speed)
			check(not c.holding, "right-turner %d never holds" % c.id)
			var oncoming := S if c.light.id == N else N
			for o in _cars_of(t, oncoming):
				if o.movement == RoadNet.Movement.STRAIGHT and _in_box(o):
					against_oncoming += 1
	check(against_oncoming > 0, "a right-turner turned while oncoming traffic crossed the box")
	check(slowest > 50.0, "no right-turner slows to wait: slowest in the box %.1f px/s" % slowest)
	check_eq(crashes[0], 0, "Crashes with N and S on Green")


func test_turning_cars_slow_to_the_turn_speed() -> void:
	var t := _traffic(1, 1.0, 0.0)
	_run(t, 6.0)
	t.switch(t.lights[N])
	var fastest := 0.0
	var turned := false
	for i in 15 * Traffic.TICK_HZ:
		t.step()
		for c in _cars_of(t, N):
			if c.route.index_at(c.s) == 1:
				fastest = maxf(fastest, c.speed)
				turned = true
	check(turned, "an N car turned")
	var limit := Tuning.BASE_SPEED * t.k_speed * Tuning.TURN_SPEED
	check(fastest <= limit + 0.01, "fastest through the turn %.1f px/s, limit %.1f" % [fastest, limit])


# --- Turners ----------------------------------------------------------------------

## Steps Traffic while steering k_turners so each planned light's cars come out as planned: plan[light][n]
## is whether its n-th car is a Turner (past the end of its list, either). Traffic draws a car's movement
## from the knob as it spawns, and the knob is shared, so a tick where one light's next car should be a
## Turner and another's shouldn't can spoil a plan. matches() catches that; then try another seed.
class Plan:
	var plan: Dictionary
	var spawned: Dictionary = {}  # light → the cars it has spawned, in order

	func _init(t: Traffic, p: Dictionary) -> void:  # holds no reference to the Traffic, so nothing leaks
		plan = p
		for l: int in p:
			spawned[l] = []
		t.car_spawned.connect(func(c: Car) -> void:
			if spawned.has(c.light.id):
				spawned[c.light.id].append(c))

	func step(t: Traffic) -> void:
		var turner := false
		for l: int in plan:
			var n: int = spawned[l].size()
			turner = turner or (n < plan[l].size() and plan[l][n])
		t.k_turners = 1.0 if turner else 0.0
		t.step()

	func run(t: Traffic, seconds: float) -> void:
		for i in roundi(seconds * Traffic.TICK_HZ):
			step(t)

	func car(light: int, n: int) -> Car:
		return spawned[light][n] if n < spawned[light].size() else null

	## Whether every planned car spawned so far is a Turner or not as planned.
	func matches() -> bool:
		for l: int in plan:
			for n in mini(spawned[l].size(), plan[l].size()):
				if (spawned[l][n].movement == RoadNet.Movement.LEFT) != plan[l][n]:
					return false
		return true


func _in_box(c: Car) -> bool:
	return c.route.index_at(c.s + c.length / 2.0) >= 1 and c.route.index_at(c.s - c.length / 2.0) <= 1


func test_a_turner_holds_for_oncoming_traffic_and_goes_at_a_gap() -> void:
	var t := _traffic(3, 0.0, 0.0)
	var p := Plan.new(t, {N: [true], S: [false, false, false, false, false, false]})
	var exited: Array[Car] = []
	t.car_exited.connect(func(c: Car) -> void: exited.append(c))
	var crashes := [0]
	t.crashed.connect(func(_a: Car, _b: Car, _at: Vector2) -> void: crashes[0] += 1)
	p.run(t, 10.0)  # both queue at Red
	var turner := p.car(N, 0)
	if not check(turner != null and p.car(S, 1) != null, "N and S have queued by 10s"):
		return
	t.switch(t.lights[N])
	t.switch(t.lights[S])
	var held_for_oncoming := false
	var behind_crossed_while_held := false
	var oncoming_in_box_on_release := true
	var was_holding := false
	for i in 25 * Traffic.TICK_HZ:
		p.step(t)
		if turner.holding:
			for c in _cars_of(t, S):
				held_for_oncoming = held_for_oncoming or _in_box(c)
			for c in _cars_of(t, N):
				behind_crossed_while_held = behind_crossed_while_held or (c != turner and c.line_distance < 0.0)
		elif was_holding:
			oncoming_in_box_on_release = _cars_of(t, S).any(func(c: Car) -> bool: return _in_box(c))
		was_holding = turner.holding
		if exited.has(turner):
			break
	if not check(p.matches(), "spawns kept to the plan (else pick another seed)"):
		return
	check(held_for_oncoming, "the Turner held while an oncoming car was in the box")
	check(not behind_crossed_while_held, "no N car behind the Turner crossed its line while it held")
	check(not oncoming_in_box_on_release, "the Turner went with no oncoming car in the box")
	check(exited.has(turner), "the Turner left the map")
	check(turner.transform.x.dot(Vector2.RIGHT) > 0.99, "N's Turner leaves heading east, got %s" % turner.transform.x)
	check_eq(crashes[0], 0, "Crashes")


func test_opposing_turners_take_turns_by_wait_time() -> void:
	# N's first car is a Turner; S's second is. N holds first, for S's first car (straight), so N has
	# waited longer by the time S's Turner pulls up opposite it.
	var t := _traffic(3, 0.0, 0.0)
	var p := Plan.new(t, {N: [true, false, false], S: [false, true, false, false]})
	var exited: Array[Car] = []
	t.car_exited.connect(func(c: Car) -> void: exited.append(c))
	var crashes := [0]
	t.crashed.connect(func(_a: Car, _b: Car, _at: Vector2) -> void: crashes[0] += 1)
	p.run(t, 10.0)
	var first := p.car(N, 0)
	var second := p.car(S, 1)
	if not check(first != null and second != null, "N's first car and S's second have spawned by 10s"):
		return
	t.switch(t.lights[N])
	t.switch(t.lights[S])
	var went := {}  # Turner → the tick it stopped holding and went
	var both_held := false
	var second_held_when_first_went := false
	for i in 30 * Traffic.TICK_HZ:
		var was := {first: first.holding, second: second.holding}
		p.step(t)
		both_held = both_held or (first.holding and second.holding)
		for c: Car in [first, second]:
			if was[c] and not c.holding and not went.has(c):
				went[c] = i
				if c == first:
					second_held_when_first_went = second.holding
		if exited.has(first) and exited.has(second):
			break
	if not check(p.matches(), "spawns kept to the plan (else pick another seed)"):
		return
	check(both_held, "both Turners held at once, facing each other")
	if check(went.has(first) and went.has(second), "both Turners went"):
		check(went[first] < went[second], "N's Turner, waiting longer, went first (ticks %d, %d)" % [went[first], went[second]])
	check(second_held_when_first_went, "S's Turner was still holding as N's went")
	check(exited.has(first) and exited.has(second), "both Turners left the map")
	check_eq(crashes[0], 0, "Crashes")


func test_a_turner_caught_by_a_red_clears_out_at_the_first_gap() -> void:
	var t := _traffic(3, 0.0, 0.0)
	t.k_gap = Tuning.K_GAP[1]  # stage-9 spacing: oncoming traffic too thick to turn through
	var p := Plan.new(t, {N: [true], S: [false, false]})
	var exited: Array[Car] = []
	t.car_exited.connect(func(c: Car) -> void: exited.append(c))
	var crashes := [0]
	t.crashed.connect(func(_a: Car, _b: Car, _at: Vector2) -> void: crashes[0] += 1)
	p.run(t, 6.0)
	var turner := p.car(N, 0)
	if not check(turner != null, "N's first car has spawned by 6s"):
		return
	t.switch(t.lights[N])
	t.switch(t.lights[S])
	for i in 10 * Traffic.TICK_HZ:
		p.step(t)
		if turner.holding:
			break
	if not check(turner.holding, "the Turner is holding for oncoming traffic"):
		return
	t.switch(t.lights[N])  # Yellow, then Red; S stays Green
	for i in roundi((Tuning.YELLOW_TIME + 0.5) * Traffic.TICK_HZ):
		p.step(t)
	check_eq(t.lights[N].state, Light.State.RED, "N's Light")
	if not check(turner.holding, "the Turner is still holding, caught by the red"):
		return
	var line := {}
	for c in _cars_of(t, N):
		line[c] = c.line_distance < 0.0
	t.switch(t.lights[S])  # Yellow: the oncoming road stops
	var went_on_red := false
	var behind_crossed := false
	var gap_at := -1  # the first tick with no oncoming car in the box or committed to its line
	var went_at := -1
	for i in 15 * Traffic.TICK_HZ:
		p.step(t)
		if gap_at < 0 and _cars_of(t, S).all(func(o: Car) -> bool: return o.out_of_box() or not (o.passed_line or _in_box(o))):
			gap_at = i
		if not turner.holding and went_at < 0:
			went_at = i
			went_on_red = t.lights[N].state == Light.State.RED
		for c in _cars_of(t, N):
			if c != turner and c.line_distance < 0.0 and not line.get(c, false):
				behind_crossed = true
		if exited.has(turner):
			break
	if not check(p.matches(), "spawns kept to the plan (else pick another seed)"):
		return
	check(went_on_red, "the Turner went while its own Light was Red")
	check(gap_at >= 0 and went_at >= gap_at and went_at - gap_at <= 2, "it went at the first gap: gap at tick %d, went at %d" % [gap_at, went_at])
	check(exited.has(turner), "the Turner cleared out and left the map")
	check(not behind_crossed, "no N car behind it crossed the red line")
	check_eq(crashes[0], 0, "Crashes")


func test_the_knobs_set_the_mix_of_movements() -> void:
	for knobs: Array in [[0.0, 0.0], [0.0, 1.0], [1.0, 0.0]]:
		var t := _traffic(4, knobs[0], knobs[1])
		var got := {}
		t.car_spawned.connect(func(c: Car) -> void: got[c.movement] = got.get(c.movement, 0) + 1)
		t.switch(t.lights[N])
		_run(t, 30.0)
		var want := RoadNet.Movement.LEFT if knobs[1] > 0.0 else (RoadNet.Movement.RIGHT if knobs[0] > 0.0 else RoadNet.Movement.STRAIGHT)
		check_eq(got.keys(), [want], "movements with k_right %.0f, k_turners %.0f" % knobs)
	# The defaults, stage 1: a flat share turning right, no Turners.
	var t := Traffic.new(4)
	t.k_gap = 0.3
	var got := {}
	t.car_spawned.connect(func(c: Car) -> void: got[c.movement] = got.get(c.movement, 0) + 1)
	t.switch(t.lights[N])  # N and S never cross, so nothing Crashes and blocks an entry
	t.switch(t.lights[S])
	_run(t, 120.0)
	var total: int = got.values().reduce(func(a: int, b: int) -> int: return a + b, 0)
	check(total > 300, "enough cars to judge the share: %d" % total)
	check_eq(got.get(RoadNet.Movement.LEFT, 0), 0, "Turners at stage 1")
	check_near(float(got.get(RoadNet.Movement.RIGHT, 0)) / total, 0.15, 0.05, "share turning right by default")

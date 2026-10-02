extends TestCase
## Patience, Honks and Blowing the red (#25), black-box through Traffic: the blowing_unlocked flag,
## the k_patience knob, Switch, step, and the honked and blew_red signals.

const N := 0  # Light indices follow RoadNet.SIDE_NAMES: N, S, W, E
const S := 1
const W := 2
const E := 3


func _run(t: Traffic, seconds: float) -> void:
	for i in roundi(seconds * Traffic.TICK_HZ):
		t.step()


# The cars queued for a Light, nearest the line first: the front driver, then those behind it.
func _queue(t: Traffic, light: int) -> Array[Car]:
	var out: Array[Car] = []
	for c in t.cars:
		if c.light == t.lights[light] and not c.passed_line and not c.wreckage:
			out.append(c)
	out.sort_custom(func(a: Car, b: Car) -> bool: return a.line_distance < b.line_distance)
	return out


func test_only_the_front_driver_at_a_red_spends_patience() -> void:
	var t := straight_traffic(1)
	_run(t, 20.0)
	for light in [N, S, W, E]:
		var queue := _queue(t, light)
		if not check(queue.size() >= 2, "light %d has a queue of 2+ after 20s at red, got %d" % [light, queue.size()]):
			continue
		check(queue[0].wait > 0.0, "light %d's front driver has waited (%.2fs)" % [light, queue[0].wait])
		for c in queue.slice(1):
			check_eq(c.wait, 0.0, "light %d: wait of car %d, queued behind the front one" % [light, c.id])
			check_eq(c.honks, 0, "light %d: Honks of car %d, queued behind the front one" % [light, c.id])


func test_front_drivers_honk_once_then_twice_at_a_third_and_two_thirds_of_their_patience() -> void:
	var t := straight_traffic(1)
	var heard: Array[Array] = []  # [car, its Honks, its wait] at each honked signal
	t.honked.connect(func(c: Car) -> void: heard.append([c, c.honks, c.wait]))
	_run(t, 40.0)
	var by_car: Dictionary[Car, Array] = {}
	for h in heard:
		if not by_car.has(h[0]):
			by_car[h[0]] = []
		by_car[h[0]].append(h)
	check_eq(by_car.size(), 4, "drivers who Honked in 40s at four red Lights")
	for c: Car in by_car:
		var p := Tuning.K_PATIENCE[0]
		check(c.patience >= p * Tuning.PATIENCE_JITTER[0] and c.patience <= p * Tuning.PATIENCE_JITTER[1], "car %d's Patience %.2fs is within its spread of %.0fs" % [c.id, c.patience, p])
		var honks: Array = by_car[c]
		if not check_eq(honks.size(), 2, "Honks from front driver %d in 40s at red" % c.id):
			continue
		check_eq(honks[0][1], 1, "car %d's first Honk is Honk 1" % c.id)
		check_near(honks[0][2], c.patience / Tuning.PATIENCE_RINGS, Traffic.DT, "car %d's wait at its first Honk" % c.id)
		check_eq(honks[1][1], 2, "car %d's second Honk is Honk 2" % c.id)
		check_near(honks[1][2], c.patience * 2.0 / Tuning.PATIENCE_RINGS, Traffic.DT, "car %d's wait at its second Honk" % c.id)


func test_out_of_patience_drivers_never_blow_the_red_before_its_debut() -> void:
	var t := straight_traffic(1)
	var blew := [0]
	t.blew_red.connect(func(_c: Car) -> void: blew[0] += 1)
	_run(t, 60.0)
	check_eq(blew[0], 0, "blew_red signals in 60s at red, with Blowing the red locked")
	for c in t.cars:
		check(not c.passed_line, "car %d is still behind its red line" % c.id)
		check(c.honks <= 2, "car %d has Honked at most twice (%d)" % [c.id, c.honks])


func test_out_of_patience_drivers_blow_the_red_once_it_has_debuted() -> void:
	var t := straight_traffic(1)
	t.blowing_unlocked = true
	var blew: Array[Array] = []  # [car, its wait] at each blew_red signal
	t.blew_red.connect(func(c: Car) -> void: blew.append([c, c.wait]))
	_run(t, 25.0)
	check_eq(blew.size(), 4, "drivers who Blew the red in 25s at four red Lights")
	for b in blew:
		var c: Car = b[0]
		check(c.blowing, "car %d is Blowing the red" % c.id)
		check_near(b[1], c.patience, Traffic.DT, "car %d's wait when it Blew the red" % c.id)
		check(c.passed_line, "car %d drove over its red line" % c.id)
	for l in t.lights:
		check_eq(l.state, Light.State.RED, "light %d's state" % l.id)


func test_the_blowing_warning_shows_for_the_last_seconds_of_patience_once_blowing_has_debuted() -> void:
	for unlocked: bool in [false, true]:
		var t := straight_traffic(1)
		t.blowing_unlocked = unlocked
		var first_warned: Dictionary[Car, float] = {}  # car -> its wait the first tick it showed the warning
		var blew_while_warned: Array[Car] = []
		t.blew_red.connect(func(c: Car) -> void: if c.blow_warning: blew_while_warned.append(c))
		for i in 25 * Traffic.TICK_HZ:
			t.step()
			for c in t.cars:
				if c.blow_warning and not first_warned.has(c):
					first_warned[c] = c.wait
		if not unlocked:
			check_eq(first_warned.size(), 0, "drivers showing the warning with Blowing the red locked")
			continue
		check_eq(first_warned.size(), 4, "drivers showing the warning in 25s at four red Lights")
		for c: Car in first_warned:
			check_near(first_warned[c], c.patience - Tuning.BLOW_WARN, Traffic.DT, "car %d's wait when its warning came on" % c.id)
			check(blew_while_warned.has(c), "car %d still shows the warning as it Blows the red" % c.id)


func test_a_holding_turner_spends_patience_and_honks() -> void:
	var t := straight_traffic(3)
	t.k_patience = 3.0  # Honks a second into a hold, so a short one shows them
	var p := Plan.new(t, {N: [true], S: [false, false, false, false, false, false]})
	p.run(t, 10.0)  # both queue at Red
	var turner := p.car(N, 0)
	if not check(turner != null and p.car(S, 1) != null, "N and S have queued by 10s"):
		return
	t.switch(t.lights[N])
	t.switch(t.lights[S])
	var honked_holding := [false]
	t.honked.connect(func(c: Car) -> void: honked_holding[0] = honked_holding[0] or (c == turner and c.holding))
	var waited_behind := false  # a car queued behind the Turner, at its Green, spent Patience
	var committed_wait := INF
	for i in 25 * Traffic.TICK_HZ:
		p.step(t)
		for c in _queue(t, N):
			waited_behind = waited_behind or c.wait > 0.0
		if turner.committed:
			committed_wait = turner.wait
			break
	if not check(p.matches(), "spawns kept to the plan (else pick another seed)"):
		return
	check(honked_holding[0], "the Turner Honked while it held")
	check(not waited_behind, "no car queued behind the Turner at its Green spent Patience")
	check_eq(committed_wait, 0.0, "the Turner's wait once it has its gap")


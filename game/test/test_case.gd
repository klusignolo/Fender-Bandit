class_name TestCase
extends RefCounted
## Base for test_*.gd files. Each test_* method gets a fresh instance; a failed check is recorded,
## and the test carries on so one run reports every broken check.

var failures: PackedStringArray = []


func check(ok: bool, what: String) -> bool:
	if not ok:
		failures.append(what)
	return ok


func check_eq(got: Variant, want: Variant, what: String) -> bool:
	return check(got == want, "%s: got %s, want %s" % [what, got, want])


func check_near(got: float, want: float, tolerance: float, what: String) -> bool:
	return check(absf(got - want) <= tolerance, "%s: got %s, want %s ± %s" % [what, got, want, tolerance])


const NO_QUOTA := 1 << 30  # a Quota no test meets, for tests of a stage in full flow


## A Traffic with straight traffic only (no right turns or Turners), cars only, no Swells, no Quota and every driver a
## hothead, as before any of those existed.
## It's stage 1's map and knobs, or `stage`'s.
func straight_traffic(seed_value: int, stage := 1) -> Traffic:
	var t := Traffic.new(seed_value, 0, Stages.def(stage, seed_value))
	t.quota = NO_QUOTA
	t.k_right = 0.0
	t.k_turners = 0.0
	t.k_swell = false
	t.k_motorcycles = 0.0
	t.k_semis = 0.0
	t.k_hotheads = 1.0  # every driver out of Patience may Blow the red, as before hotheads (#45)
	return t


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

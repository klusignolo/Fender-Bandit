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


## A Traffic with straight traffic only (no right turns or Turners), as before turns existed.
func straight_traffic(seed_value: int) -> Traffic:
	var t := Traffic.new(seed_value)
	t.k_right = 0.0
	t.k_turners = 0.0
	return t

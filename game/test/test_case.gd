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

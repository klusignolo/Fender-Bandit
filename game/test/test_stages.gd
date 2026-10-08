extends TestCase
## Stages (#29): the fixed Opening for stages 1–9, and the seeded generator from stage 10. Pure: a stage
## number and a seed in, a StageDef out.

const F := Stages.Feature


func test_the_opening_debuts_one_thing_at_a_time() -> void:
	# Story 62: 1–2 plain 4-way, 3 Turners, 4 second crossing, 5 motorcycles, 6 no Debut, 7 Blowing the red,
	# 8 semis, 9 T-junction/5-way plus third crossing.
	var debuts := {3: F.TURNERS, 5: F.MOTORCYCLES, 7: F.BLOWING, 8: F.SEMIS, 9: F.ODD_JUNCTIONS}
	var crossings := [1, 1, 1, 2, 2, 2, 2, 2, 3]
	var on: Array[Stages.Feature] = []
	for n in range(1, 10):
		var d := Stages.def(n, 1)
		check_eq(d.number, n, "stage %d's number" % n)
		check_eq(d.debut, debuts.get(n, -1), "stage %d's Debut" % n)
		if debuts.has(n):
			on.append(debuts[n])
			on.sort()  # features come in enum order
		check_eq(d.features, on, "stage %d's features" % n)
		check_eq(d.crossings, crossings[n - 1], "stage %d's crossings" % n)
		check_eq(d.grows, n == 4 or n == 9, "a crossing attaches at stage %d" % n)


func test_opening_knobs_step_up_and_debuts_hold_the_previous_stage() -> void:
	# docs/tuning.md: linear from stage 1 to 9. Debuts (3, 4, 5, 7, 8, 9) take stage n-1's values; the
	# Turner share starts at its first value on its own Debut (stage 3), as 10% at 3 → 20% at 9.
	var gap := [3.2, 2.925, 2.925, 2.65, 2.375, 1.825, 1.825, 1.55, 1.275]
	var speed := [1.0, 1.05, 1.05, 1.1, 1.15, 1.25, 1.25, 1.3, 1.35]
	var patience := [15.0, 14.625, 14.625, 14.25, 13.875, 13.125, 13.125, 12.75, 12.375]
	var turners := [0.0, 0.0, 0.1, 0.1, 0.11667, 0.15, 0.15, 0.16667, 0.18333]
	for n in range(1, 10):
		var d := Stages.def(n, 1)
		check_near(d.gap, gap[n - 1], 0.0001, "stage %d's spawn gap" % n)
		check_near(d.speed, speed[n - 1], 0.0001, "stage %d's car speed" % n)
		check_near(d.patience, patience[n - 1], 0.0001, "stage %d's Patience" % n)
		check_near(d.turners, turners[n - 1], 0.0001, "stage %d's Turner share" % n)


func test_every_stage_lasts_24s_of_flowing_traffic() -> void:
	# Story 56, #45: the dev wants short stages. The new mechanics bring the challenge, so stage length stays flat, and
	# the Quota grows only as cars come faster and from more roads.
	for n: int in [1, 2, 6, 9, 10, 25]:
		check_near(Stages.def(n, 1).target_len, 24.0, 0.0001, "stage %d's target length" % n)


func test_knobs_never_get_easier() -> void:
	# The knobs only: from stage 10 a generated stage may turn a feature off for variety (the dev's call, #29).
	var was := Stages.def(1, 7)
	for n in range(2, 41):
		var d := Stages.def(n, 7)
		check(d.gap <= was.gap, "stage %d's spawn gap %.3f is no longer than stage %d's %.3f" % [n, d.gap, n - 1, was.gap])
		check(d.speed >= was.speed, "stage %d's car speed %.3f is no slower than stage %d's" % [n, d.speed, n - 1])
		check(d.patience <= was.patience, "stage %d's Patience %.3f is no longer than stage %d's" % [n, d.patience, n - 1])
		check(d.turners >= was.turners, "stage %d's Turner share %.3f is no lower than stage %d's" % [n, d.turners, n - 1])
		was = d


func test_past_the_opening_knobs_ease_toward_their_far_limit() -> void:
	# 15% of the way from stage 9's value toward the far limit each stage: 1.0 → 0.6 is 0.94 at 10.
	check_near(Stages.def(10, 1).gap, 0.94, 0.0001, "stage 10's spawn gap")
	check_near(Stages.def(11, 1).gap, 0.889, 0.0001, "stage 11's spawn gap")
	check_near(Stages.def(10, 1).speed, 1.49, 0.0001, "stage 10's car speed")
	check_near(Stages.def(10, 1).patience, 11.25, 0.0001, "stage 10's Patience")
	check_near(Stages.def(10, 1).turners, 0.2075, 0.0001, "stage 10's Turner share")
	check(Stages.def(200, 1).gap > 0.6, "the far limit is never reached")


func test_a_crossing_attaches_every_four_stages_after_nine_up_to_six() -> void:
	# Story 66: about 13, 17 and 21.
	for n in range(10, 41):
		var d := Stages.def(n, 3)
		var want := mini(3 + (n - 9) / 4, 6)
		check_eq(d.crossings, want, "stage %d's crossings" % n)
		check_eq(d.grows, n == 13 or n == 17 or n == 21, "a crossing attaches at stage %d" % n)


func test_generated_stages_turn_on_at_least_the_feature_floor() -> void:
	# 2 at stages 10–13, 3 at 14–17, 4 at 18–21, all five from 22; only features the Opening unlocked.
	var floors := {10: 2, 13: 2, 14: 3, 17: 3, 18: 4, 21: 4, 22: 5, 30: 5}
	var counts := {}
	for n: int in floors:
		for seed_value in 40:
			var d := Stages.def(n, seed_value)
			check(d.features.size() >= floors[n], "stage %d (seed %d) has %d features, the floor is %d" % [n, seed_value, d.features.size(), floors[n]])
			check_eq(d.debut, -1, "stage %d (seed %d) is past the Opening, so it debuts nothing" % [n, seed_value])
			for f in d.features:
				check(Stages.def(Stages.OPENING, 0).features.has(f), "stage %d's feature %d was unlocked in the Opening" % [n, f])
			counts[d.features.size()] = true
	check(counts.size() > 1, "the generator draws more than one feature count: %s" % [counts.keys()])


func test_the_same_seed_gives_the_same_generated_stage() -> void:
	var differs := false
	for n in range(10, 30):
		var a := Stages.def(n, 42)
		var b := Stages.def(n, 42)
		check_eq(a.features, b.features, "stage %d's features with the same seed" % n)
		differs = differs or Stages.def(n, 43).features != a.features
	check(differs, "another seed gives other features somewhere in stages 10–29")


func test_news_names_what_a_stage_debuts_and_grows() -> void:
	check_eq(Stages.news(Stages.def(2, 1)), PackedStringArray(), "stage 2 brings nothing new")
	check_eq(Stages.news(Stages.def(3, 1)), PackedStringArray(["Left turns"]), "stage 3: right turns run from stage 1, so the news is the left ones")
	check_eq(Stages.news(Stages.def(4, 1)), PackedStringArray(["Another crossing"]), "stage 4")
	check_eq(Stages.news(Stages.def(9, 1)), PackedStringArray(["T-junctions and 5-ways", "Another crossing"]), "stage 9")
	check_eq(Stages.news(Stages.def(13, 1)), PackedStringArray(["Another crossing"]), "stage 13")


func test_the_opening_is_the_same_every_run() -> void:
	for n in range(1, 10):
		var a := Stages.def(n, 1)
		var b := Stages.def(n, 999)
		check_eq([a.gap, a.speed, a.patience, a.turners, a.features, a.debut, a.crossings], [b.gap, b.speed, b.patience, b.turners, b.features, b.debut, b.crossings], "stage %d with two seeds" % n)

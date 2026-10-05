extends TestCase
## The Gridlock beat (#43, #19 story 54): its timeline, and the pre-made glass shards the frozen frame is cut
## into. The shards must tile the whole screen at any window shape, and fall clear of it before the beat ends.

const VIEWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1600, 720), Vector2(1280, 960)]  # "expand" only ever widens or heightens


func test_the_beat_runs_slow_mo_pile_up_crack_banner_then_falls_away_to_the_results() -> void:
	var order: Array[int] = []
	var t := 0.0
	while t < Tuning.GRIDLOCK_HOLD + Tuning.GRIDLOCK_FALL_TIME + 0.5:
		var p := GridlockBeat.phase_at(t)
		if order.is_empty() or order.back() != p:
			order.append(p)
		t += 1.0 / 60.0
	var P := GridlockBeat.Phase
	check_eq(order, [P.SLOWMO, P.PILEUP, P.CRACKED, P.BANNER, P.FALLING, P.DONE] as Array[int], "every phase, in order")
	check_eq(GridlockBeat.phase_at(Tuning.GRIDLOCK_HOLD - 0.01), P.BANNER, "the banner holds until the results...")
	check_eq(GridlockBeat.phase_at(Tuning.GRIDLOCK_HOLD), P.FALLING, "...and the shards fall as they show")
	check_eq(GridlockBeat.phase_at(Tuning.GRIDLOCK_HOLD + Tuning.GRIDLOCK_FALL_TIME), P.DONE, "gone after the fall")


func test_the_shards_tile_the_screen() -> void:
	for view in VIEWS:
		var pieces := GridlockBeat.shards(view)
		check(pieces.size() >= 10 and pieces.size() <= 16, "about a dozen shards at %s: %d" % [view, pieces.size()])
		var total := 0.0
		for piece in pieces:
			var a := _area(piece)
			check(a > view.x * view.y * 0.005, "no sliver at %s: %.0f px²" % [view, a])
			total += a
			for p in piece:
				check(Rect2(Vector2.ZERO, view).grow(0.01).has_point(p), "%s inside the screen %s" % [p, view])
		check_near(total, view.x * view.y, 1.0, "they cover %s exactly, with no overlap" % view)


func test_the_shards_start_in_place() -> void:
	for piece_i in GridlockBeat.shards(VIEWS[0]).size():
		check_eq(GridlockBeat.fall(GridlockBeat.shards(VIEWS[0])[piece_i], piece_i, 0.0, VIEWS[0]), Transform2D.IDENTITY, "shard %d" % piece_i)


func test_every_shard_falls_clear_of_the_screen() -> void:
	for view in VIEWS:
		var pieces := GridlockBeat.shards(view)
		for i in pieces.size():
			var moved := GridlockBeat.fall(pieces[i], i, Tuning.GRIDLOCK_FALL_TIME, view) * pieces[i]
			var top := INF
			for p in moved:
				top = minf(top, p.y)
			check(top > view.y, "shard %d at %s is off the bottom: its top at %.0f" % [i, view, top])


func test_the_shards_fall_downward_from_the_start() -> void:
	var pieces := GridlockBeat.shards(VIEWS[0])
	for i in pieces.size():
		var centre := Vector2.ZERO
		for p in pieces[i]:
			centre += p / pieces[i].size()
		var before := centre.y
		for k in range(1, 11):
			var y := (GridlockBeat.fall(pieces[i], i, Tuning.GRIDLOCK_FALL_TIME * k / 10.0, VIEWS[0]) * centre).y
			check(y >= before - 0.01, "shard %d never rises: %.1f after %.1f" % [i, y, before])
			before = y


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		s += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(s) / 2.0

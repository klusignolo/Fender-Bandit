extends TestCase
## The camera (#33): Framing fits the map with a slight drift toward the Raccoon, follows the Raccoon at the
## readability floor once fitting would go below it, and pulls back over REVEAL_TIME when a crossing attaches.
## Plus the Raccoon's constant on-screen speed at any zoom.

const VIEW := Vector2(1280, 720)  # the base viewport, 16:9
const WIDE := Vector2(1680, 720)  # a wider browser window: the "expand" stretch only widens the view
const TICK := 1.0 / 60.0


func _map(stage: int) -> Rect2:
	return RoadNet.new(Stages.def(stage, 1).crossings).bounds


func _settle(f: Framing, view: Vector2, raccoon: Vector2, seconds := 10.0) -> void:
	for i in roundi(seconds / TICK):
		f.step(TICK, view, raccoon)


## The map rect the camera shows, in world px.
func _shown(f: Framing, view: Vector2) -> Rect2:
	var size := view / f.zoom
	return Rect2(f.centre - size / 2.0, size)


# --- fit and follow -------------------------------------------------------------

func test_every_opening_and_plan_map_fits_at_16_9_above_the_floor() -> void:
	for stage: int in [1, 4, 9, 13, 17, 21]:
		var map := _map(stage)
		var f := Framing.new(map, VIEW, map.get_center())
		check(not f.following, "stage %d fits instead of following" % stage)
		check(f.zoom >= Tuning.READ_FLOOR, "stage %d: zoom %s is at or above the floor" % [stage, f.zoom])
		check_near(f.zoom, Framing.fit_zoom(map, VIEW), 0.0001, "stage %d zoom is the fit" % stage)
		check_near(f.centre.distance_to(map.get_center()), 0.0, 0.01, "stage %d is centred on the map" % stage)


func test_the_fit_frames_nearly_the_whole_map() -> void:
	var map := _map(4)
	var f := Framing.new(map, VIEW, map.get_center())
	var shown := _shown(f, VIEW)
	check(map.encloses(shown), "the edges bleed off a little: %s inside %s" % [shown, map])
	check(shown.get_area() > map.get_area() * 0.9, "but most of the map shows: %s of %s" % [shown.get_area(), map.get_area()])


func test_the_view_drifts_slightly_toward_the_raccoon() -> void:
	var map := _map(9)
	var spot := map.get_center() + Vector2(200, 100)
	var f := Framing.new(map, VIEW, map.get_center())
	_settle(f, VIEW, spot)
	var want := map.get_center() + (spot - map.get_center()) * Tuning.DRIFT
	check_near(f.centre.distance_to(want), 0.0, 0.5, "settles drifted toward the Raccoon")
	check_near(f.zoom, Framing.fit_zoom(map, VIEW), 0.0001, "drift leaves the zoom alone")


func test_the_drift_never_shows_past_the_map_edge() -> void:
	for stage: int in [1, 9, 21]:
		var map := _map(stage)
		for corner: Vector2 in [map.position, map.end, Vector2(map.position.x, map.end.y), Vector2(map.end.x, map.position.y)]:
			var f := Framing.new(map, VIEW, corner)
			_settle(f, VIEW, corner)
			var shown := _shown(f, VIEW).grow(-0.01)
			check(map.encloses(shown), "stage %d, Raccoon at %s: %s inside %s" % [stage, corner, shown, map])
			check(f.centre.distance_to(corner) < map.get_center().distance_to(corner), "stage %d: still drifts toward %s" % [stage, corner])


func test_the_drift_eases_in_instead_of_jumping() -> void:
	var map := _map(9)
	var f := Framing.new(map, VIEW, map.get_center())
	f.step(TICK, VIEW, map.end)
	var full := (map.end - map.get_center()) * Tuning.DRIFT
	var moved := f.centre - map.get_center()
	check(moved.length() > 0.0 and moved.length() < full.length() * 0.2, "one tick moves a little of the way: %s of %s" % [moved, full])


func test_a_map_too_big_to_read_is_followed_at_the_floor() -> void:
	var map := Rect2(0, 0, 6000, 3375)  # past the plan: fitting it would go below the floor
	var f := Framing.new(map, VIEW, map.get_center())
	check(Framing.fit_zoom(map, VIEW) < Tuning.READ_FLOOR, "the fit would go below the floor")
	check(f.following, "so the camera follows")
	check_eq(f.zoom, Tuning.READ_FLOOR, "at the floor")
	var spot := map.get_center() + Vector2(700, -300)
	_settle(f, VIEW, spot)
	check_near(f.centre.distance_to(spot), 0.0, 1.0, "follows the Raccoon")


func test_following_stops_at_the_map_edge() -> void:
	var map := Rect2(0, 0, 6000, 3375)
	var f := Framing.new(map, VIEW, Vector2(10, 10))
	_settle(f, VIEW, Vector2(10, 10))
	var shown := _shown(f, VIEW)
	check_near(shown.position.x, 0.0, 1.0, "the view's left edge sits on the map's")
	check_near(shown.position.y, 0.0, 1.0, "the view's top edge sits on the map's")


# --- aspect ---------------------------------------------------------------------

func test_a_wider_window_still_shows_the_whole_map_height() -> void:
	for stage: int in [1, 21]:
		var map := _map(stage)
		var f := Framing.new(map, WIDE, map.get_center())
		var shown := _shown(f, WIDE)
		check_near(shown.size.y, map.size.y / Tuning.FIT, 0.5, "stage %d: the height fits as at 16:9" % stage)
		check(shown.size.x > map.size.x, "stage %d: the extra width shows grass past the side edges" % stage)
		check(not f.following, "stage %d still fits" % stage)


func test_the_framing_follows_a_window_resize() -> void:
	var map := _map(4)
	var f := Framing.new(map, VIEW, map.get_center())
	f.step(TICK, WIDE, map.get_center())
	check_near(f.zoom, Framing.fit_zoom(map, WIDE), 0.0001, "the zoom refits on the next tick")


# --- the reveal -----------------------------------------------------------------

func test_a_crossing_attaching_pulls_back_over_the_reveal_time() -> void:
	var old := _map(3)
	var map := _map(4)
	var f := Framing.new(map, VIEW, old.get_center(), old)
	check_near(f.zoom, Framing.fit_zoom(old, VIEW), 0.0001, "starts framing the old map")
	check_near(f.centre.distance_to(old.get_center()), 0.0, 0.01, "centred on it")
	var last := f.zoom
	var steps := roundi(Tuning.REVEAL_TIME / TICK)
	for i in steps - 1:
		f.step(TICK, VIEW, old.get_center())
		if not check(f.zoom <= last + 0.00001, "the pull-back only zooms out (tick %d)" % i):
			break
		last = f.zoom
	check(f.zoom > Framing.fit_zoom(map, VIEW) + 0.00001, "still pulling back just before REVEAL_TIME")
	f.step(TICK, VIEW, old.get_center())
	check_near(f.zoom, Framing.fit_zoom(map, VIEW), 0.0001, "framing the new map at REVEAL_TIME")


func test_the_pull_back_eases_out_of_and_into_its_ends() -> void:
	var old := _map(8)
	var map := _map(9)
	var f := Framing.new(map, VIEW, old.get_center(), old)
	var z0 := f.zoom
	f.step(TICK, VIEW, old.get_center())
	var first := z0 - f.zoom
	_settle(f, VIEW, old.get_center(), Tuning.REVEAL_TIME / 2.0 - TICK)
	var mid := f.zoom
	f.step(TICK, VIEW, old.get_center())
	check(mid - f.zoom > first * 5.0, "slow at the start, fastest in the middle: %s vs %s" % [first, mid - f.zoom])


func test_no_reveal_without_an_old_map() -> void:
	var map := _map(4)
	var f := Framing.new(map, VIEW, map.get_center())
	check_near(f.zoom, Framing.fit_zoom(map, VIEW), 0.0001, "frames the map straight away")


# --- constant on-screen speed ---------------------------------------------------

## How far the Raccoon walks right in half a second, in on-screen px, at camera zoom `zoom`.
func _screen_walk(zoom: float) -> float:
	var t := straight_traffic(1, 21)
	var r := Raccoon.new(t)
	r.cam_zoom = zoom
	r.position = City.centre(0) + Vector2(-300, -150)  # well inside the map, so its edge never clamps the walk
	var start := r.position
	Input.action_press(&"move_right")
	for i in 30:
		r.step(TICK)
	Input.action_release(&"move_right")
	var moved := (r.position - start).length() * zoom
	r.free()
	return moved


func test_the_raccoon_crosses_the_screen_in_the_same_time_at_every_zoom() -> void:
	var near := _screen_walk(1.0)
	check_near(near, Tuning.RACCOON_SPEED * 0.5, 1.0, "walks RACCOON_SPEED on-screen px/s at zoom 1")
	for z: float in [Tuning.READ_FLOOR, 0.6, 0.8]:
		check_near(_screen_walk(z), near, 0.5, "the same on screen at zoom %s" % z)

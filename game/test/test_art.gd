extends TestCase
## First-pass sprites (#39, docs/sprites.md): every vehicle kind's layers match its footprint, bodies wear one
## of the six safe tints, shadows fall down-right however a vehicle turns, Wreckage swaps in crumpled details,
## the Raccoon picks its view from its facing, and rooftops stay off the roads.


# --- vehicles ---------------------------------------------------------------------

func test_every_vehicle_kind_has_layers_at_its_footprint_plus_the_outline() -> void:
	var footprints := {
		Car.Kind.CAR: Vector2(Tuning.CAR_L, Tuning.CAR_W),
		Car.Kind.MOTORCYCLE: Vector2(Tuning.MOTO_L, Tuning.MOTO_W),
		Car.Kind.SEMI: Vector2(Tuning.SEMI_L, Tuning.SEMI_W),
	}
	for kind: Car.Kind in footprints:
		var layers := Art.vehicle(kind)
		for layer: String in ["body", "details", "wreck", "shadow"]:
			var tex: Texture2D = layers.get(layer)
			if not check(tex != null, "kind %d has a %s layer" % [kind, layer]):
				continue
			var world := tex.get_size() / Art.AUTHORED - Vector2.ONE * Art.MARGIN * 2.0
			check_eq(world, footprints[kind], "kind %d %s: the art inside its margin is the footprint" % [kind, layer])


func test_spawned_vehicles_wear_one_of_the_six_safe_tints() -> void:
	check_eq(Car.TINTS.size(), 6, "six safe tints")
	var t := Traffic.new(3, 0, Stages.def(9, 3))
	t.quota = NO_QUOTA
	var seen := {}
	for i in 60 * 20:
		t.step()
	for c in t.cars:
		check(c.tint in Car.TINTS, "car %d's tint %s is a safe one" % [c.id, c.tint])
		seen[c.tint] = true
	check(seen.size() >= 4, "and they vary: %d tints seen" % seen.size())


func _vehicle(kind := Car.Kind.CAR) -> Array:
	var t := Traffic.new(1, 0, Stages.def(9, 1))
	var a := t.net.approaches[0]
	var c := Car.new(99, a.routes[0], t.lights[0], kind)
	c.tint = Car.TINTS[2]
	c.transform = Transform2D(0.0, Vector2(500, 300))
	var v := Vehicle.new(t)
	v.show_car(c)
	return [v, c]


func test_the_body_takes_the_tint_and_the_details_stay_untinted() -> void:
	var vc := _vehicle()
	var v: Vehicle = vc[0]
	check_eq(v.body.modulate, Car.TINTS[2], "the body is tinted")
	check_eq(v.details.modulate, Color.WHITE, "the details are not")
	check_eq(v.details.texture, Art.vehicle(Car.Kind.CAR).details, "intact details")
	v.free()


func test_a_shadow_falls_down_right_however_the_vehicle_turns() -> void:
	var vc := _vehicle()
	var v: Vehicle = vc[0]
	var c: Car = vc[1]
	for angle: float in [0.0, PI / 2.0, 2.4, -1.0]:
		c.transform = Transform2D(angle, Vector2(500, 300))
		v._sync()
		var fall := v.transform.basis_xform(v.shadow.position)
		check(fall.distance_to(Art.SHADOW_FALL) < 0.01, "at %s rad the shadow falls %s" % [angle, fall])
	v.free()


func test_wreckage_swaps_in_crumpled_details_and_keeps_its_tint() -> void:
	for kind: Car.Kind in [Car.Kind.CAR, Car.Kind.MOTORCYCLE, Car.Kind.SEMI]:
		var vc := _vehicle(kind)
		var v: Vehicle = vc[0]
		var c: Car = vc[1]
		c.wreckage = true
		v._sync()
		check_eq(v.details.texture, Art.vehicle(kind).wreck, "kind %d: crumpled details" % kind)
		check_eq(v.body.modulate, Car.TINTS[2], "kind %d: same tint" % kind)
		v.free()


# --- the Raccoon ----------------------------------------------------------------

func test_the_raccoon_view_follows_its_facing() -> void:
	check_eq(Raccoon.view_of(Vector2.DOWN), Raccoon.View.FRONT, "moving down shows the front")
	check_eq(Raccoon.view_of(Vector2.UP), Raccoon.View.BACK, "moving up shows the back")
	check_eq(Raccoon.view_of(Vector2.RIGHT), Raccoon.View.RIGHT, "right shows the side")
	check_eq(Raccoon.view_of(Vector2.LEFT), Raccoon.View.LEFT, "left shows the side, mirrored")
	check_eq(Raccoon.view_of(Vector2(1, 1).normalized()), Raccoon.View.RIGHT, "a diagonal shows the side")
	check_eq(Raccoon.view_of(Vector2(-1, -1).normalized()), Raccoon.View.LEFT, "either diagonal")
	check_eq(Raccoon.view_of(Vector2(0.2, -0.98).normalized()), Raccoon.View.BACK, "nearly straight up is still the back")


# --- the ground -----------------------------------------------------------------

func test_rooftops_fill_the_blocks_and_stay_off_the_roads() -> void:
	for stage: int in [1, 4, 9, 21]:
		var net := RoadNet.new(Stages.def(stage, 1).crossings)
		var roofs := Ground.roofs(net, 7)
		check(roofs.size() >= 8, "stage %d has a scatter of roofs: %d" % [stage, roofs.size()])
		check_eq(Ground.roofs(net, 7), roofs, "stage %d: the same seed scatters the same roofs" % stage)
		for r: Rect2 in roofs:
			var clear := true
			for seg in net.segments:
				for p: Vector2 in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]:
					clear = clear and seg.curve.get_closest_point(p).distance_to(p) >= Tuning.LW / 2.0 + Ground.ROOF_GAP - 0.01  # off the road, past a gap of pavement
			for x in net.crossings.size():
				clear = clear and not Geometry2D.intersect_polygons(net.box(x), _corners(r)).size() > 0
			if not check(clear, "stage %d: roof %s stays off the road" % [stage, r]):
				break


func test_roads_run_on_past_the_map_edge_clear_of_roofs() -> void:
	var net := RoadNet.new(Stages.def(9, 1).crossings)
	var roofs := Ground.roofs(net, 7)
	var far := net.bounds.grow(Ground.ROOF_SPREAD)
	for lane in Ground.lanes(net):
		var start := lane[0]
		var end := lane[lane.size() - 1]
		if net.bounds.has_point(start) and net.bounds.has_point(end):
			continue  # a road between two crossings
		check(not far.has_point(start) or not far.has_point(end), "a road at the edge runs on past the scatter: %s to %s" % [start, end])
		for r: Rect2 in roofs:
			for ends: Array in [[lane[0], lane[1]], [lane[lane.size() - 2], end]]:  # where it runs on
				var p := Geometry2D.get_closest_point_to_segment(r.get_center(), ends[0], ends[1])
				if not check(not r.grow(Tuning.LW / 2.0).has_point(p), "roof %s is off the road near %s" % [r, p]):
					return


func _corners(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

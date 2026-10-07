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
		for layer: String in ["body", "details", "wreck", "shadow", "brake", "blink"]:
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


func _vehicle(kind := Car.Kind.CAR, movement := RoadNet.Movement.STRAIGHT) -> Array:
	var t := Traffic.new(1, 0, Stages.def(9, 1))
	var route: RoadNet.Route = null
	for a in t.net.approaches:
		for r in a.routes:
			if route == null and r.movement == movement:
				route = r
	check(route != null, "stage 9 has a route of movement %d" % movement)
	var c := Car.new(99, route, t.lights[0], kind)
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


func test_brake_lamps_light_while_the_vehicle_brakes_or_waits() -> void:
	for kind: Car.Kind in [Car.Kind.CAR, Car.Kind.MOTORCYCLE, Car.Kind.SEMI]:
		var vc := _vehicle(kind)
		var v: Vehicle = vc[0]
		var c: Car = vc[1]
		check_eq(v.brake.texture, Art.vehicle(kind).brake, "kind %d: its own brake lamps" % kind)
		check(not v.brake.visible, "kind %d: dark while it drives on" % kind)
		c.braking = true
		v._sync()
		check(v.brake.visible, "kind %d: lit while it brakes" % kind)
		c.wreckage = true
		v._sync()
		check(not v.brake.visible, "kind %d: Wreckage shows no lamps" % kind)
		v.free()


func test_blinkers_flash_on_the_side_the_vehicle_turns() -> void:
	for m: RoadNet.Movement in [RoadNet.Movement.RIGHT, RoadNet.Movement.LEFT, RoadNet.Movement.STRAIGHT]:
		var vc := _vehicle(Car.Kind.CAR, m)
		var v: Vehicle = vc[0]
		var t: Traffic = v._traffic
		var lit := []
		for at: float in [0.1, 0.35, 0.6, 0.85]:
			t.time = at
			v._sync()
			lit.append(v.blink.visible)
		if m == RoadNet.Movement.STRAIGHT:
			check_eq(lit, [false, false, false, false], "going straight, no blinker")
		else:
			check_eq(lit, [true, false, true, false], "movement %d: the blinker flashes" % m)
			# +y is the driver's right: the lamps are drawn on the right and mirrored for a left turn.
			check_eq(signf(v.blink.scale.y), 1.0 if m == RoadNet.Movement.RIGHT else -1.0, "movement %d: on the turning side" % m)
		v.free()


func test_wreckage_smokes_until_it_is_towed() -> void:
	var vc := _vehicle()
	var v: Vehicle = vc[0]
	var c: Car = vc[1]
	check(not v.smoke.visible, "an intact car doesn't smoke")
	c.wreckage = true
	v._sync()
	check(v.smoke.visible, "Wreckage smokes")
	c.towed = true
	v._sync()
	check(not v.smoke.visible, "until the Raccoon Tows it")
	c.towed = false
	v._sync()
	check(v.smoke.visible, "dropped on the road, it smokes again")
	v.free()


func test_the_gridlock_pile_up_crumples_the_view_but_not_the_car() -> void:
	var vc := _vehicle(Car.Kind.CAR, RoadNet.Movement.LEFT)
	var v: Vehicle = vc[0]
	var c: Car = vc[1]
	c.speed = 100.0
	v.coast = true
	v._process(0.5)
	check_near(v.position.distance_to(c.transform.origin), 50.0, 0.01, "it coasts on at its speed")
	c.speed = 0.0
	v._process(0.5)
	check_near(v.position.distance_to(c.transform.origin), 50.0 + Tuning.GRIDLOCK_LURCH * 0.5, 0.01, "a stopped car lurches on")
	v.pile_up()
	v._sync()
	check_eq(v.details.texture, Art.vehicle(c.kind).wreck, "crumpled")
	check(v.smoke.visible, "smoking")
	check(not v._arrow_shown(), "its cues go")
	var at := v.position
	v._process(0.5)
	check_eq(v.position, at, "it stops where it piled up")
	check(not c.wreckage, "the Car itself is untouched: the Run is already over")
	v.show_car(c)
	check_eq(v.details.texture, Art.vehicle(c.kind).details, "a pooled Vehicle starts clean")
	v.free()


# --- floating cues ----------------------------------------------------------------

func test_cues_hold_a_floor_size_as_the_camera_zooms_out() -> void:
	check_eq(Art.cue_scale(1.0), 1.0, "at 1× a cue is drawn at world size")
	check_eq(Art.cue_scale(Tuning.CUE_MIN_ZOOM), 1.0, "down to the cue floor")
	check_near(Art.cue_scale(Tuning.READ_FLOOR), Tuning.CUE_MIN_ZOOM / Tuning.READ_FLOOR, 0.001,
			"past it, cues grow to look as they do at the floor")


func test_cues_stay_upright_however_the_vehicle_turns() -> void:
	var vc := _vehicle(Car.Kind.CAR, RoadNet.Movement.LEFT)
	var v: Vehicle = vc[0]
	var c: Car = vc[1]
	for angle: float in [0.0, PI / 2.0, 2.4, -1.0]:
		c.transform = Transform2D(angle, Vector2(500, 300))
		v._sync()
		check(v._cues.top_level, "the cues don't inherit the vehicle's turn")
		check_eq(v._cues.rotation, 0.0, "at %s rad they stay upright" % angle)
		check_eq(v._cues.position, c.transform.origin, "over the car")
		check_eq(v._cues.scale, Vector2.ONE * Art.cue_scale(1.0), "at the cue scale")
	v.free()


# --- Crashes ---------------------------------------------------------------------

func test_each_crash_throws_debris_seeded_by_where_it_happened() -> void:
	var m := CrashMarker.new(Vector2(320, 180))
	var bits := m.find_children("*", "CPUParticles2D", false, false)
	check_eq(bits.size(), Art.DEBRIS.size(), "one burst of each kind of debris")
	for p: CPUParticles2D in bits:
		check(Art.DEBRIS.has(p.texture), "a debris_bits texture")
		check(p.one_shot and p.emitting, "one burst, now")
		check_eq(p.gravity, Vector2.ZERO, "seen from above: no fall")
		check(p.use_fixed_seed, "repeatable")
	var again := CrashMarker.new(Vector2(320, 180))
	check_eq((again.get_child(0) as CPUParticles2D).seed, (bits[0] as CPUParticles2D).seed, "the same Crash throws the same bits")
	m.free()
	again.free()


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


func test_manholes_sit_in_the_lanes_clear_of_the_crossings() -> void:
	for stage: int in [1, 9, 21]:
		var net := RoadNet.new(Stages.def(stage, 1).crossings)
		var holes := Ground.manholes(net, 7)
		check(holes.size() >= 2, "stage %d has manholes: %d" % [stage, holes.size()])
		check_eq(Ground.manholes(net, 7), holes, "stage %d: the same seed places the same manholes" % stage)
		var lanes: Array[Curve2D] = []
		for lane in Ground.lanes(net):
			var c := Curve2D.new()
			for q in lane:
				c.add_point(q)
			lanes.append(c)
		for p: Vector2 in holes:
			var in_lane := false
			for c in lanes:
				in_lane = in_lane or c.get_closest_point(p).distance_to(p) <= Tuning.LW / 2.0 - Ground.MANHOLE_R
			check(in_lane, "stage %d: manhole %s lies inside a lane" % [stage, p])
			for x in net.crossings.size():
				var box := Geometry2D.offset_polygon(net.box(x), Ground.MANHOLE_CLEAR)[0]
				check(not Geometry2D.is_point_in_polygon(p, box), "stage %d: manhole %s is clear of box %d and its crosswalks" % [stage, p, x])


func _corners(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

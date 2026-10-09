extends TestCase
## Overpasses (#44): while a crossing's neighbours are on the map but it isn't, two of their map-edge roads cross
## where it will go. RoadNet makes that an overpass: the more north–south road bridges over the other, whose cars
## drive underneath, so the two never meet.


func test_an_overpass_stands_where_a_later_crossing_will_attach() -> void:
	var want := {1: -1, 2: -1, 3: 3, 4: -1, 5: 5, 6: -1}  # crossings on the map: the crossing whose spot it's at, or none
	for n: int in want:
		var net := RoadNet.new(n)
		if want[n] < 0:
			check_eq(net.overpasses.size(), 0, "%d crossings: no overpass" % n)
			continue
		if not check_eq(net.overpasses.size(), 1, "%d crossings: one overpass" % n):
			continue
		var o: RoadNet.Overpass = net.overpasses[0]
		check(o.centre.distance_to(City.centre(want[n])) < Tuning.LW, "%d crossings: it's at crossing %d's spot, %s" % [n, want[n], o.centre])
		check(absf(o.over_dir.y) > absf(o.over_dir.x), "%d crossings: the north–south road goes over" % n)
		check_eq(o.under.size(), 2, "%d crossings: both lanes of the other road go under" % n)
		for seg in o.under:
			var s := net.segments[seg]
			var d := s.curve.get_point_position(s.curve.point_count - 1) - s.curve.get_point_position(0)
			check(absf(d.x) > absf(d.y), "%d crossings: segment %d under it runs east–west" % [n, seg])


func test_cars_under_the_bridge_know_it_and_cars_on_it_dont() -> void:
	var t := Traffic.new(1, 0, Stages.def(9, 1))
	t.quota = NO_QUOTA
	var o: RoadNet.Overpass = t.net.overpasses[0]
	var under := 0
	var over := 0
	for i in 120 * Traffic.TICK_HZ:
		t.step()
		for c in t.cars:
			if c.transform.origin.distance_to(o.centre) > Tuning.LW:
				continue
			var on_under: bool = o.under.has(c.route.segment_at(c.s))
			check_eq(c.underpass, on_under, "car %d at the overpass: underpass is whether it's on the road beneath" % c.id)
			if on_under:
				under += 1
			else:
				over += 1
		if i % (8 * Traffic.TICK_HZ) == 0:  # keep every road moving, so cars reach the overpass both ways
			for l in t.lights:
				t.switch(l)
	check(under > 0 and over > 0, "cars passed under (%d ticks) and over (%d ticks)" % [under, over])


func test_wreckage_under_the_bridge_never_crashes_a_car_on_it() -> void:
	var t := Traffic.new(1, 0, Stages.def(9, 1))
	t.quota = NO_QUOTA
	var o: RoadNet.Overpass = t.net.overpasses[0]
	var crashes := [0]
	t.crashed.connect(func(_a: Car, _b: Car, _at: Vector2) -> void: crashes[0] += 1)
	var wreck := _car_at(t, o, true)
	var car := _car_at(t, o, false)
	check(wreck != null and car != null, "a route under and a route over the bridge")
	if wreck == null or car == null:
		return
	wreck.wreckage = true
	t.cars.append(wreck)
	t.cars.append(car)
	t._check_crashes()
	check_eq(crashes[0], 0, "a car on the bridge drives over the wreck beneath it")


# A car parked at the overpass, on the road beneath it (`under`) or on the bridge.
func _car_at(t: Traffic, o: RoadNet.Overpass, under: bool) -> Car:
	for r in t.net.routes:
		for i in r.segments.size():
			var seg := r.segments[i]
			if o.under.has(seg) != under or t.net.segments[seg].kind == RoadNet.Segment.Kind.CONNECTOR:
				continue
			var curve := t.net.segments[seg].curve
			var off := curve.get_closest_offset(o.centre)
			if curve.sample_baked(off).distance_to(o.centre) > Tuning.LW:
				continue
			var c := Car.new(9000 + int(under), r, t.lights[t.net.segments[seg].approach])
			c.s = r.starts[i] + off
			t._place(c)
			return c
	return null

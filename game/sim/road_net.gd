class_name RoadNet
extends RefCounted
## The road geometry, as Curve2D segments (#13 §5): for each approach, the incoming lane up to its
## stop line, one connector per movement through the crossing box, and the outgoing lane to the map
## edge. Cars hold a Route of segments and a distance along it. Road drawing uses the same curves.
## Crossings come from the City plan, built from its arms at any angle (#32): a 4-way, a T or a 5-way. Each arm is a
## road of two lanes, one in and one out; an approach is an arm's lane in, and it has a route out along every other arm.
## A road linking two crossings is one lane each way, shared: one crossing's outgoing lane is the next one's incoming
## lane, so a car's Route ends on it and Traffic hands the car on to the next crossing's Route.

## The order a crossing's approaches (and Lights) come in, by the angle of their arm: N, S, W, E, then any other.
const ARM_ORDER: Array[int] = [270, 90, 180, 0]
## Compass names for arms, every 45° from east: an approach is named for the compass point its cars come in from.
const COMPASS: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

## The movements a car can make through a crossing. On a 4-way an approach has one route of each; a T leaves some
## out, and a 5-way adds a second right or left turn.
enum Movement { STRAIGHT, RIGHT, LEFT }
## A turn sharper than this many degrees is a right or left turn; any gentler, it's straight on.
const STRAIGHT_WITHIN := 1.0


## One stretch of lane.
class Segment:
	enum Kind { INCOMING, CONNECTOR, OUTGOING }
	var kind: Kind
	var curve: Curve2D
	var length: float
	var approach: int  # the approach whose lane or movement this is

	func _init(k: Kind, a: int, c: Curve2D) -> void:
		kind = k
		approach = a
		curve = c
		length = curve.get_baked_length()


## The segments a car drives, end to end, and where each starts along the whole route.
class Route:
	var segments: PackedInt32Array
	var starts: PackedFloat32Array
	var length := 0.0
	var stop_s := 0.0  # where the stop line is: the end of the first stretch, the incoming lane
	var id: int  # index into RoadNet.routes
	var movement: Movement
	var heading_out: Vector2  # the way it leaves the crossing, along the arm it takes
	var next := -1  # the approach whose incoming lane this route ends on, at the next crossing; -1 if it leaves the map
	var sharing: PackedInt32Array  # ids of the routes with a segment in common with this one, itself included
	var _curves: Array[Curve2D] = []  # not the RoadNet itself: it holds this Route, so that would be a cycle

	func _init(net: RoadNet, ids: PackedInt32Array) -> void:
		segments = ids
		for seg in ids:
			starts.append(length)
			length += net.segments[seg].length
			_curves.append(net.segments[seg].curve)
		stop_s = net.segments[ids[0]].length

	## Where its last stretch starts: the outgoing lane, or the road linked to the next crossing.
	func last_start() -> float:
		return starts[starts.size() - 1]

	## Index into `segments` of the stretch that distance s along the route is on.
	func index_at(s: float) -> int:
		var i := starts.size() - 1
		while i > 0 and s < starts[i]:
			i -= 1
		return i

	## The segment id that distance s along the route is on.
	func segment_at(s: float) -> int:
		return segments[index_at(s)]

	## Distance s along the route, measured from the start of the segment it's on.
	func local_at(s: float) -> float:
		return s - starts[index_at(s)]

	## Position and heading at distance s along the route.
	func pose(s: float) -> Transform2D:
		var i := index_at(s)
		var end := length if i == starts.size() - 1 else starts[i + 1]
		return _curves[i].sample_baked_with_rotation(clampf(s - starts[i], 0.0, end - starts[i]))


## One arm's incoming lane into a crossing. It has its own Light, with the same index.
class Approach:
	var label: String  # the compass point its cars come in from: "N", "NW", ...
	var crossing: int
	var arm: int  # the angle its arm leaves the crossing at, in degrees: 0 is east, 90 south
	var direction: Vector2  # the way its cars travel, in along the arm
	var stop_point: Vector2  # the middle of its stop line
	var pole: Vector2  # where its Light hangs, at the kerb by the stop line
	var entry := true  # fed from the map edge
	var incoming: int  # segment id
	var outgoing: int  # segment id of the lane leaving the crossing along its arm, the other way
	var opposite := -1  # index of the approach facing it across the crossing, or -1
	var routes: Array[Route] = []  # one per other arm of its crossing

	## Whether it has a route making movement m.
	func has(m: Movement) -> bool:
		return routes.any(func(r: Route) -> bool: return r.movement == m)


var crossings: PackedVector2Array = []
var approaches: Array[Approach] = []
var segments: Array[Segment] = []
var routes: Array[Route] = []  # every route, by id
var bounds := Rect2()  # the map; entries start just outside it
## For each connector, the other connectors in its box whose paths come close enough for two cars to
## touch: these are the only pairs of moving cars that can Crash.
var conflicts: Dictionary[int, PackedInt32Array] = {}


func _init(crossing_count := 1) -> void:
	for k in crossing_count:
		crossings.append(City.centre(k))
	bounds = _map_bounds()
	for x in crossing_count:
		for arm in _arms_in_order(x):
			_add_approach(x, arm)
	for a in approaches:
		_add_outgoing(a)
	for a in approaches:
		_add_routes(a)
		var o := _approach_toward(a.crossing, -a.direction)
		if o != null:
			a.opposite = approaches.find(o)
	_find_conflicts()
	_find_sharing()


## The driver's right and left, for a car travelling `d`.
static func right_of(d: Vector2) -> Vector2:
	return Vector2(-d.y, d.x)


static func left_of(d: Vector2) -> Vector2:
	return Vector2(d.y, -d.x)


## The unit vector along an arm at `angle` degrees, snapped so the axis arms are exact.
static func arm_dir(angle: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(angle)).snapped(Vector2.ONE * 1e-9)


## How far from crossing x's centre the stop line on its arm at `angle` sits: STOP_D, pushed out where a neighbouring
## arm is less than a quarter turn away, so the two roads have parted by the stop line as they have on a 4-way.
static func stop_distance(x: int, angle: int) -> float:
	var nearest := 180.0
	for other: int in City.ARMS[x]:
		if other != angle:
			nearest = minf(nearest, absf(wrapf(other - angle, -180.0, 180.0)))
	if nearest >= 90.0:
		return Tuning.STOP_D
	# Two roads' kerbs, each LW off its arm, meet LW / tan(half the angle between the arms) out from the centre.
	return Tuning.STOP_D - Tuning.LW + Tuning.LW / tan(deg_to_rad(nearest) / 2.0)


## The index of crossing x's approach whose cars come in from compass point `from` ("N", "NW", ...), or -1.
func approach_at(x: int, from: String) -> int:
	for i in approaches.size():
		if approaches[i].crossing == x and approaches[i].label == from:
			return i
	return -1


## Crossing x's box: the paved outline joining each of its roads' kerbs at the stop line, at whatever angles its arms meet.
func box(x: int) -> PackedVector2Array:
	var kerbs := PackedVector2Array()
	for a in approaches:
		if a.crossing == x:
			var line := crossings[x] - a.direction * stop_distance(x, a.arm)
			kerbs.append(line + right_of(a.direction) * Tuning.LW)
			kerbs.append(line - right_of(a.direction) * Tuning.LW)
	var hull := Geometry2D.convex_hull(kerbs)
	hull.resize(hull.size() - 1)  # the hull ends on its first point again
	return hull


## Whether point p is on a road: within a lane, or ON_ROAD_MARGIN past the kerb.
func on_road(p: Vector2) -> bool:
	for seg in segments:
		if seg.curve.get_closest_point(p).distance_to(p) < Tuning.LW / 2.0 + Tuning.ON_ROAD_MARGIN:
			return true
	return false


func _find_conflicts() -> void:
	var connectors: Array[int] = []
	for i in segments.size():
		if segments[i].kind == Segment.Kind.CONNECTOR:
			connectors.append(i)
			conflicts[i] = PackedInt32Array()
	for i in connectors:
		for j in connectors:
			if i < j and _crossing_of(i) == _crossing_of(j) and _paths_touch(segments[i].curve, segments[j].curve):
				conflicts[i].append(j)
				conflicts[j].append(i)


func _crossing_of(segment: int) -> int:
	return approaches[segments[segment].approach].crossing


# Two cars, one on each path, could touch: the paths come within a car's width of each other.
func _paths_touch(a: Curve2D, b: Curve2D) -> bool:
	for p in a.get_baked_points():
		if b.get_closest_point(p).distance_to(p) < Tuning.CAR_W:
			return true
	return false


# The map: an arm's length of road around every crossing, its short side widened to MAP_ASPECT.
func _map_bounds() -> Rect2:
	var r := Rect2(crossings[0], Vector2.ZERO)
	for c in crossings:
		r = r.expand(c)
	r = r.grow_individual(Tuning.ARM_X, Tuning.ARM_Y, Tuning.ARM_X, Tuning.ARM_Y)
	if r.size.x / r.size.y > Tuning.MAP_ASPECT:
		var pad_y := (r.size.x / Tuning.MAP_ASPECT - r.size.y) / 2.0
		return r.grow_individual(0.0, pad_y, 0.0, pad_y)
	var pad_x := (r.size.y * Tuning.MAP_ASPECT - r.size.x) / 2.0
	return r.grow_individual(pad_x, 0.0, pad_x, 0.0)


# How far it is from point p to the map edge, going the way `dir` points.
func _reach(p: Vector2, dir: Vector2) -> float:
	var t := INF
	if dir.x > 0.001:
		t = minf(t, (bounds.end.x - p.x) / dir.x)
	elif dir.x < -0.001:
		t = minf(t, (bounds.position.x - p.x) / dir.x)
	if dir.y > 0.001:
		t = minf(t, (bounds.end.y - p.y) / dir.y)
	elif dir.y < -0.001:
		t = minf(t, (bounds.position.y - p.y) / dir.y)
	return t


# Crossing x's arm angles, in approach order: ARM_ORDER's first, then the rest as the plan lists them.
static func _arms_in_order(x: int) -> Array[int]:
	var out: Array[int] = []
	for arm in ARM_ORDER:
		if City.ARMS[x].has(arm):
			out.append(arm)
	for arm: int in City.ARMS[x]:
		if not out.has(arm):
			out.append(arm)
	return out


# An approach and its incoming lane, along crossing x's arm at `arm` degrees: from the map edge, or from the far side
# of the crossing linked along that arm.
func _add_approach(x: int, arm: int) -> void:
	var c := crossings[x]
	var u := arm_dir(arm)
	var d := -u
	var right := right_of(d)
	var off := right * Tuning.LW * 0.5
	var a := Approach.new()
	var i := approaches.size()
	a.label = COMPASS[posmod(roundi(arm / 45.0), COMPASS.size())]
	a.crossing = x
	a.arm = arm
	a.direction = d
	a.stop_point = c + u * stop_distance(x, arm) + off
	a.pole = a.stop_point - d * Tuning.POLE_BACK + right * (Tuning.LW / 2.0 + Tuning.POLE_OUT)
	var behind := City.linked(x, u, crossings.size())
	a.entry = behind < 0
	var start := c - d * (_reach(c, -d) + Tuning.SPAWN_BACK) + off
	if not a.entry:
		start = crossings[behind] + d * stop_distance(behind, posmod(arm + 180, 360)) + off
	a.incoming = _add_segment(Segment.Kind.INCOMING, i, _line(start, a.stop_point))
	approaches.append(a)


# The lane leaving the crossing along the approach's arm: the next crossing's incoming lane where a road links them,
# otherwise a lane out past the map edge. Needs every approach added first.
func _add_outgoing(a: Approach) -> void:
	var c := crossings[a.crossing]
	var u := -a.direction
	var off := right_of(u) * Tuning.LW * 0.5
	var ahead := City.linked(a.crossing, u, crossings.size())
	if ahead >= 0:
		a.outgoing = _approach_toward(ahead, u).incoming
	else:
		var far_line := c + u * stop_distance(a.crossing, a.arm) + off
		var gone := c + u * (_reach(c, u) + Tuning.EXIT_MARGIN) + off
		a.outgoing = _add_segment(Segment.Kind.OUTGOING, approaches.find(a), _line(far_line, gone))


# A route out along every other arm of the crossing, in approach order: straight across, or a turn from the stop line
# onto that arm's outgoing lane. Needs every outgoing lane added first.
func _add_routes(a: Approach) -> void:
	var i := approaches.find(a)
	for b in approaches:
		if b.crossing != a.crossing or b == a:
			continue
		var to := -b.direction
		var turn := rad_to_deg(a.direction.angle_to(to))  # positive is to the driver's right
		var end := segments[b.outgoing].curve.get_point_position(0)
		var m := Movement.STRAIGHT
		var path := _line(a.stop_point, end)
		if absf(turn) > STRAIGHT_WITHIN:
			m = Movement.RIGHT if turn > 0.0 else Movement.LEFT
			path = _turn(a.stop_point, a.direction, end, to)
		var connector := _add_segment(Segment.Kind.CONNECTOR, i, path)
		_add_route(a, m, to, PackedInt32Array([a.incoming, connector, b.outgoing]))


# The approach into crossing x whose cars travel the way `dir` points, or null.
func _approach_toward(x: int, dir: Vector2) -> Approach:
	for a in approaches:
		if a.crossing == x and a.direction.is_equal_approx(dir):
			return a
	return null


static func _line(from: Vector2, to: Vector2) -> Curve2D:
	var c := Curve2D.new()
	c.add_point(from)
	c.add_point(to)
	return c


# A turn from `from`, heading `d_from`, to `to`, heading `d_to`, as one cubic Bézier through any angle. Each handle runs
# part of the way to the corner where the two headings' lines meet: the share that traces a circular arc through
# that angle (0.5523 for a quarter turn).
static func _turn(from: Vector2, d_from: Vector2, to: Vector2, d_to: Vector2) -> Curve2D:
	var angle := absf(d_from.angle_to(d_to))
	var share := 4.0 / 3.0 * tan(angle / 4.0) / tan(angle / 2.0)
	var w := to - from
	var across := d_from.cross(d_to)
	var c := Curve2D.new()
	c.add_point(from, Vector2.ZERO, d_from * share * w.cross(d_to) / across)
	c.add_point(to, d_to * share * w.cross(d_from) / across, Vector2.ZERO)
	return c


func _add_segment(kind: Segment.Kind, approach: int, curve: Curve2D) -> int:
	segments.append(Segment.new(kind, approach, curve))
	return segments.size() - 1


func _find_sharing() -> void:
	for r in routes:
		for o in routes:
			for seg in r.segments:
				if o.segments.has(seg):
					r.sharing.append(o.id)
					break


func _add_route(a: Approach, m: Movement, heading_out: Vector2, ids: PackedInt32Array) -> void:
	var r := Route.new(self, ids)
	r.id = routes.size()
	r.movement = m
	r.heading_out = heading_out
	for k in approaches.size():
		if approaches[k].incoming == ids[ids.size() - 1]:
			r.next = k
	routes.append(r)
	a.routes.append(r)

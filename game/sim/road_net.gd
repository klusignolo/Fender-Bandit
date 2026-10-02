class_name RoadNet
extends RefCounted
## The road geometry, as Curve2D segments (#13 §5): for each approach, the incoming lane up to its
## stop line, one connector per movement through the crossing box, and the outgoing lane to the map
## edge. Cars hold a Route of segments and a distance along it. Road drawing uses the same curves.
## For now: one plain 4-way crossing at the origin.

## Sides of a crossing, and the way cars on that side's incoming lane travel.
const SIDE_NAMES: Array[String] = ["N", "S", "W", "E"]
const SIDE_DIR: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT]

## The movements a car can make through a crossing; an approach's `routes` are indexed by them.
enum Movement { STRAIGHT, RIGHT, LEFT }
## A cubic Bézier handle this many radii long traces a quarter circle closely.
const QUARTER_HANDLE := 0.5523


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
	var sharing: PackedInt32Array  # ids of the routes with a segment in common with this one, itself included
	var _curves: Array[Curve2D] = []  # not the RoadNet itself: it holds this Route, so that would be a cycle

	func _init(net: RoadNet, ids: PackedInt32Array) -> void:
		segments = ids
		for seg in ids:
			starts.append(length)
			length += net.segments[seg].length
			_curves.append(net.segments[seg].curve)
		stop_s = net.segments[ids[0]].length

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


## One incoming lane into a crossing. It has its own Light, with the same index.
class Approach:
	var label: String
	var crossing: int
	var direction: Vector2  # the way its cars travel
	var stop_point: Vector2  # the middle of its stop line
	var pole: Vector2  # where its Light hangs, at the kerb by the stop line
	var entry := true  # fed from the map edge
	var incoming: int  # segment id
	var outgoing: int  # segment id of the lane leaving the crossing the way its cars travel
	var opposite := -1  # index of the approach facing it across the crossing, or -1
	var routes: Array[Route] = []  # one per movement, indexed by Movement


var crossings: PackedVector2Array = []
var approaches: Array[Approach] = []
var segments: Array[Segment] = []
var routes: Array[Route] = []  # every route, by id
var bounds := Rect2()  # the map; entries start just outside it
## For each connector, the other connectors in its box whose paths come close enough for two cars to
## touch: these are the only pairs of moving cars that can Crash.
var conflicts: Dictionary[int, PackedInt32Array] = {}


func _init() -> void:
	crossings.append(Vector2.ZERO)
	bounds = Rect2(-Tuning.ARM_X, -Tuning.ARM_Y, Tuning.ARM_X * 2.0, Tuning.ARM_Y * 2.0)
	for side in 4:
		_add_approach(0, side)
	for a in approaches:
		_add_turns(a)
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


func _add_approach(x: int, side: int) -> void:
	var c := crossings[x]
	var d := SIDE_DIR[side]
	var right := right_of(d)
	var off := right * Tuning.LW * 0.5
	var reach := Tuning.ARM_Y if absf(d.y) > 0.5 else Tuning.ARM_X
	var a := Approach.new()
	var i := approaches.size()
	a.label = SIDE_NAMES[side]
	a.crossing = x
	a.direction = d
	a.stop_point = c - d * Tuning.STOP_D + off
	a.pole = a.stop_point - d * Tuning.POLE_BACK + right * (Tuning.LW / 2.0 + Tuning.POLE_OUT)
	var spawn := c - d * (reach + Tuning.SPAWN_BACK) + off
	var far_line := c + d * Tuning.STOP_D + off
	var gone := c + d * (reach + Tuning.EXIT_MARGIN) + off
	a.incoming = _add_segment(Segment.Kind.INCOMING, i, _line(spawn, a.stop_point))
	var straight := _add_segment(Segment.Kind.CONNECTOR, i, _line(a.stop_point, far_line))
	a.outgoing = _add_segment(Segment.Kind.OUTGOING, i, _line(far_line, gone))
	_add_route(a, Movement.STRAIGHT, PackedInt32Array([a.incoming, straight, a.outgoing]))
	approaches.append(a)


# The right and left turns: a quarter circle from the stop line onto the outgoing lane that leaves
# the crossing the way the car turns. Needs every approach of the crossing added first.
func _add_turns(a: Approach) -> void:
	var i := approaches.find(a)
	var d := a.direction
	for m: Movement in [Movement.RIGHT, Movement.LEFT]:
		var to := right_of(d) if m == Movement.RIGHT else left_of(d)
		var out := _approach_toward(a.crossing, to).outgoing
		var end := segments[out].curve.get_point_position(0)
		var connector := _add_segment(Segment.Kind.CONNECTOR, i, _arc(a.stop_point, d, end, to))
		_add_route(a, m, PackedInt32Array([a.incoming, connector, out]))


# The approach into crossing x whose cars travel the way `dir` points, or null. Its outgoing lane leaves the
# crossing that way too.
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


# A quarter circle from `from`, heading `d_from`, to `to`, heading `d_to`, as one cubic Bézier.
static func _arc(from: Vector2, d_from: Vector2, to: Vector2, d_to: Vector2) -> Curve2D:
	var handle := (to - from).dot(d_from) * QUARTER_HANDLE  # the radius is how far the turn reaches ahead
	var c := Curve2D.new()
	c.add_point(from, Vector2.ZERO, d_from * handle)
	c.add_point(to, -d_to * handle, Vector2.ZERO)
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


func _add_route(a: Approach, m: Movement, ids: PackedInt32Array) -> void:
	var r := Route.new(self, ids)
	r.id = routes.size()
	r.movement = m
	routes.append(r)
	a.routes.append(r)

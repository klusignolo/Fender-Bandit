class_name Car
extends RefCounted
## One vehicle. Traffic moves it along its Route by distance; the view reads its pose.

var id: int
var route: RoadNet.Route
var movement: RoadNet.Movement:  # straight, right, or left (a Turner)
	get: return route.movement
var light: Light  # the Light it obeys at its crossing
var s := 0.0  # distance of its centre along the route
var speed := 0.0
var length := Tuning.CAR_L
var width := Tuning.CAR_W
var tint := Color.WHITE
var boosted := false  # waved through on green: drives at GO_BOOST
var passed_line := false  # over the stop line, or committed to crossing it
var line_distance := 0.0  # from its front bumper to the stop line; negative once over it
var transform := Transform2D()  # pose: origin is the centre, x points the way it drives
var wreckage := false  # Crashed: Wreckage, stopped for good. Once towed, its pose no longer follows s.
var towed := false  # Wreckage the Raccoon is towing: it never Crashes, but cars still brake for it
var holding := false  # a Turner stopped at its line, waiting for a gap in oncoming traffic
var hold_time := 0.0  # seconds it has spent holding; the opposing Turner that has waited longer goes first
var turn_gap := 0.0  # a Turner's Turner gap, seconds
var committed := false  # a Turner that has had its gap and gone: it doesn't stop for oncoming traffic again
var wait := 0.0  # seconds this driver has spent waiting with Patience: only the front driver at a red, or a holding Turner
var patience := 0.0  # seconds it will wait with Patience, drawn per driver
var honks := 0  # Honks so far: 0, 1 or 2
var blowing := false  # out of Patience: Blowing the red, it drives through its red Light regardless of cross traffic
var blow_warning := false  # its last BLOW_WARN seconds of Patience, once Blowing the red has debuted: it flashes "!!"


func _init(car_id: int, r: RoadNet.Route, l: Light) -> void:
	id = car_id
	route = r
	light = l


## Whether its centre is past the box, off the connector it takes through the crossing.
func past_box() -> bool:
	return route.index_at(s) > 1


## Whether its back is past the box too.
func out_of_box() -> bool:
	return route.index_at(s - length / 2.0) > 1


## The corners of its footprint, shrunk by `inset` on every side (a negative inset grows it).
func corners(inset := 0.0) -> PackedVector2Array:
	var hx := length / 2.0 - inset
	var hy := width / 2.0 - inset
	return transform * PackedVector2Array([Vector2(hx, hy), Vector2(-hx, hy), Vector2(-hx, -hy), Vector2(hx, -hy)])


## How far its footprint's corners are from its centre.
func radius() -> float:
	return Vector2(length, width).length() / 2.0


## Whether its footprint and another's overlap, both shrunk by `inset`: oriented rectangles.
func overlaps(o: Car, inset := 0.0) -> bool:
	return not _apart(corners(inset), o.corners(inset), [transform.x, transform.y, o.transform.x, o.transform.y])


## Whether the line from a to b touches its footprint.
func crosses(a: Vector2, b: Vector2) -> bool:
	var along := (b - a).orthogonal()
	return not _apart(corners(), PackedVector2Array([a, b]), [transform.x, transform.y, along])


## Whether point p is within `reach` of its footprint (measured square to its sides).
func reaches(p: Vector2, reach: float) -> bool:
	var local := transform.affine_inverse() * p
	return absf(local.x) <= length / 2.0 + reach and absf(local.y) <= width / 2.0 + reach


# Separating axis test: true if some axis has the two point sets' projections apart.
static func _apart(a: PackedVector2Array, b: PackedVector2Array, axes: Array[Vector2]) -> bool:
	for axis in axes:
		if axis == Vector2.ZERO:
			continue
		var a_lo := INF
		var a_hi := -INF
		for p in a:
			var d := p.dot(axis)
			a_lo = minf(a_lo, d)
			a_hi = maxf(a_hi, d)
		var b_lo := INF
		var b_hi := -INF
		for p in b:
			var d := p.dot(axis)
			b_lo = minf(b_lo, d)
			b_hi = maxf(b_hi, d)
		if a_hi < b_lo or b_hi < a_lo:
			return true
	return false

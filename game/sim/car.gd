class_name Car
extends RefCounted
## One vehicle. Traffic moves it along its Route by distance; the view reads its pose.

var id: int
var route: RoadNet.Route
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


func _init(car_id: int, r: RoadNet.Route, l: Light) -> void:
	id = car_id
	route = r
	light = l


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

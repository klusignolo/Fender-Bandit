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


func _init(car_id: int, r: RoadNet.Route, l: Light) -> void:
	id = car_id
	route = r
	light = l

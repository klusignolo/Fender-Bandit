class_name Framing
extends RefCounted
## Where the camera looks (#33), as numbers World's Camera2D copies each tick. It fits nearly the whole map,
## drifting slightly toward the Raccoon. Once fitting would take the zoom below the readability floor, it follows
## the Raccoon at the floor instead. Either way the view stops at the map's edges, where cars appear. When a
## crossing attaches it starts on the old map and pulls back to the new one over REVEAL_TIME. `view` is the
## visible size in on-screen px, which the "expand" stretch only ever widens or heightens past 1280×720.

var zoom := 1.0
var centre := Vector2.ZERO
var following := false  # the map would shrink below READ_FLOOR, so the camera follows the Raccoon

var _map: Rect2
var _tracked := Vector2.ZERO  # the smoothed resting centre, easing toward the target
var _from_zoom := 1.0  # the reveal's start: the old map's framing
var _from_centre := Vector2.ZERO
var _reveal_left := 0.0  # seconds of the pull-back left


## `reveal_from` is the map before a crossing attached, or an empty rect for no reveal.
func _init(map: Rect2, view: Vector2, raccoon: Vector2, reveal_from := Rect2()) -> void:
	_map = map
	zoom = _target_zoom(view)
	_tracked = _target_centre(view, raccoon)
	centre = _tracked
	if reveal_from.has_area():
		_from_zoom = fit_zoom(reveal_from, view)
		_from_centre = reveal_from.get_center()
		_reveal_left = Tuning.REVEAL_TIME
		zoom = _from_zoom
		centre = _from_centre


func step(delta: float, view: Vector2, raccoon: Vector2) -> void:
	var z := _target_zoom(view)
	_tracked = _tracked.lerp(_target_centre(view, raccoon), 1.0 - exp(-Tuning.CAM_RATE * delta))
	if _reveal_left > 0.0:
		_reveal_left = maxf(_reveal_left - delta, 0.0)
		var k := smoothstep(0.0, 1.0, 1.0 - _reveal_left / Tuning.REVEAL_TIME)
		zoom = lerpf(_from_zoom, z, k)
		centre = _from_centre.lerp(_tracked, k)
	else:
		zoom = z
		centre = _tracked


## The zoom that fits `map` in `view`, a touch past it (FIT) so the edges bleed off.
static func fit_zoom(map: Rect2, view: Vector2) -> float:
	return minf(view.x / map.size.x, view.y / map.size.y) * Tuning.FIT


## Fits the map, or holds at the floor; sets `following` to match.
func _target_zoom(view: Vector2) -> float:
	var z := fit_zoom(_map, view)
	following = z < Tuning.READ_FLOOR
	return Tuning.READ_FLOOR if following else z


func _target_centre(view: Vector2, raccoon: Vector2) -> Vector2:
	var half := view / _target_zoom(view) / 2.0  # in world px; this also sets `following`
	var mid := _map.get_center()
	var want := raccoon if following else mid + (raccoon - mid) * Tuning.DRIFT
	# Keep the view inside the map on each axis it's smaller than, so no edge where cars appear shows.
	var c := mid
	if half.x < _map.size.x / 2.0:
		c.x = clampf(want.x, _map.position.x + half.x, _map.end.x - half.x)
	if half.y < _map.size.y / 2.0:
		c.y = clampf(want.y, _map.position.y + half.y, _map.end.y - half.y)
	return c

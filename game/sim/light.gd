class_name Light
extends RefCounted
## The traffic signal for one approach. Drivers obey it; the Raccoon Switches it.

enum State { RED, GREEN, YELLOW }

var id: int
var state := State.RED
var yellow_left := 0.0  # seconds until Yellow falls to Red
var stop_point: Vector2  # the middle of the stop line it guards
var direction: Vector2  # the way its traffic travels
var pole: Vector2  # where it hangs; the Raccoon targets this


func _init(i: int, approach: RoadNet.Approach) -> void:
	id = i
	stop_point = approach.stop_point
	direction = approach.direction
	pole = approach.pole

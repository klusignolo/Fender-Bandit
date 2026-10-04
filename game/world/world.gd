class_name World
extends Node2D
## One stage's world (#13 §2, #29): builds the stage's Traffic simulation for the Run, steps it at a fixed 60 Hz, and
## draws it. Main builds a fresh World for each stage.
## Greybox: roads are drawn here from the RoadNet curves; cars are pooled Vehicle nodes keyed by
## car id; each Light has a LightPole; each Crash gets a CrashMarker; the HudStrip sits on a HUD
## layer; EntryCues marks the Swell and backlog at each entry. The camera copies Framing (#33) each tick,
## and hands its zoom to the Raccoon. Nothing here decides a rule.

const GRASS := Color(0.2, 0.36, 0.2)
const GRASS_FAR := Color(0.12, 0.2, 0.12)
const ROAD := Color(0.28, 0.28, 0.3)
const CENTRE_LINE := Color(0.9, 0.8, 0.2)
const DASH_STEP := 16.0  # px between samples when offsetting a curve for a marking

var run: Run
var traffic: Traffic
var raccoon: Raccoon
var framing: Framing  # where the camera looks (#33)

var _vehicles: Dictionary[int, Vehicle] = {}
var _pool: Array[Vehicle] = []
var _vehicle_layer := Node2D.new()
var _cam := Camera2D.new()
var _reveal_from := Rect2()  # the map before this stage's crossing attached, or empty when none did


func _init(r: Run, stage: StageDef, seed_value: int) -> void:
	run = r
	if stage.grows:
		_reveal_from = RoadNet.new(stage.crossings - 1).bounds
	traffic = Traffic.new(seed_value, run.dents, stage)  # before attach: run.dents is the last stage's until then
	run.attach(traffic)


func _ready() -> void:
	Engine.physics_ticks_per_second = Traffic.TICK_HZ
	traffic.car_spawned.connect(_on_car_spawned)
	traffic.car_exited.connect(_on_car_exited)
	traffic.crashed.connect(_on_crashed)
	traffic.towed.connect(_on_towed)
	for l in traffic.lights:
		add_child(LightPole.new(l))
	add_child(_vehicle_layer)
	add_child(EntryCues.new(traffic))
	raccoon = Raccoon.new(traffic)
	raccoon.position = traffic.raccoon_position  # its start
	add_child(raccoon)
	framing = Framing.new(traffic.net.bounds, get_viewport_rect().size, raccoon.position, _reveal_from)
	_aim_camera()
	add_child(_cam)
	_cam.make_current()
	var hud := CanvasLayer.new()
	hud.add_child(HudStrip.new(run, traffic))
	add_child(hud)


func _physics_process(delta: float) -> void:
	traffic.step()
	framing.step(delta, get_viewport_rect().size, raccoon.position)
	_aim_camera()


func _aim_camera() -> void:
	_cam.position = framing.centre
	_cam.zoom = Vector2(framing.zoom, framing.zoom)
	raccoon.cam_zoom = framing.zoom


func _on_car_spawned(car: Car) -> void:
	var v: Vehicle = _pool.pop_back() if not _pool.is_empty() else null
	if v == null:
		v = Vehicle.new(traffic)
		_vehicle_layer.add_child(v)
	v.show_car(car)
	_vehicles[car.id] = v


func _on_crashed(_a: Car, _b: Car, at: Vector2) -> void:
	add_child(CrashMarker.new(at))


## Wreckage towed off the road is gone: same as a car leaving the map.
func _on_towed(car: Car, off_road: bool) -> void:
	if off_road:
		_on_car_exited(car)


func _on_car_exited(car: Car) -> void:
	var v: Vehicle = _vehicles[car.id]
	_vehicles.erase(car.id)
	v.show_car(null)
	_pool.append(v)


func _draw() -> void:
	var b := traffic.net.bounds
	draw_rect(b.grow(3000.0), GRASS_FAR)
	draw_rect(b.grow(Tuning.EXIT_MARGIN), GRASS)
	for seg in traffic.net.segments:
		draw_polyline(seg.curve.get_baked_points(), ROAD, Tuning.LW)
	for x in traffic.net.crossings.size():
		draw_colored_polygon(traffic.net.box(x), ROAD)
	# The double centre line runs down the driver's left of every incoming lane.
	for a in traffic.net.approaches:
		var lane := traffic.net.segments[a.incoming].curve
		for off: float in [-Tuning.LW / 2.0 - 2.0, -Tuning.LW / 2.0 + 2.0]:
			draw_polyline(_offset(lane, off), CENTRE_LINE, 2.0)


## Points along a curve, shifted sideways: positive is the driver's right.
func _offset(curve: Curve2D, off: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var length := curve.get_baked_length()
	var s := 0.0
	while true:
		var t := curve.sample_baked_with_rotation(minf(s, length))
		out.append(t.origin + t.y * off)
		if s >= length:
			break
		s += DASH_STEP
	return out

class_name Ground
extends Node2D
## The ground under one stage (#39, docs/sprites.md "Roads and ground"), drawn in code from the RoadNet curves so any
## crossing angle works: pavement blocks with a scatter of rooftops, kerbed asphalt roads and crossing boxes worn with
## tar patches and manholes, a white dashed centre line down every road, and crosswalks across each approach just past
## its stop line. No green: it's reserved for the Lights.

const PAVEMENT := Color("#5E6A80")  # `pavement`
const KERB := Color("#8691A6")  # the kerb's light top edge
const ASPHALT := Color("#3B4252")  # `asphalt`
const MARKING := Color("#EEF1F6")  # white road markings
const KERB_W := 3.0  # world px of kerb along each road edge
const DASH := 10.0  # world px of each centre dash, and of each gap
const CROSSWALK := Vector2(3.0, 11.0)  # world px past the stop line where the crosswalk starts and ends
const STRIPE := 5.0  # world px across each crosswalk stripe
const STRIPE_STEP := 8.5  # world px from one stripe's middle to the next
const ROOF_STEP := 104.0  # world px between rooftop grid points: more than the widest roof plus twice the jitter
const ROOF_JITTER := 5.0  # world px each roof wanders off its grid point, either way
const ROOF_SKIP := 0.25  # share of grid points left as open lots, so the blocks don't read as a grid
const ROOF_GAP := 12.0  # world px of pavement kept between a roof and the kerb
const ROOF_SPREAD := 480.0  # world px past the map edge the scatter reaches, for wide windows
const RUN_ON := ROOF_SPREAD + 200.0  # world px a road at the map edge is drawn on past its lane's end, out of sight
const WEAR_STEP := 90.0  # world px between the spots along a lane where a tar patch or manhole may go
const PATCH_ODDS := 0.3  # share of those spots with a tar patch...
const MANHOLE_ODDS := 0.12  # ...and with a manhole
const PATCH_SIZE := Vector2(16.0, 44.0)  # world px: a patch's shortest and longest run along its lane
const PATCH_WIDTH := Vector2(0.35, 0.75)  # its narrowest and widest, as shares of a lane
const PATCH_TILT := 0.08  # radians a patch may lie off its lane's line, either way: laid by hand
const PATCH := Color("#343A48")  # tar: a shade darker than `asphalt`
const MANHOLE_R := 7.0  # world px: a manhole's radius on the road
const MANHOLE_SPREAD := 0.5  # how far off its lane's centre a manhole may sit, as a share of the room to the kerb
const MANHOLE_CLEAR := 36.0  # world px of road kept bare around each crossing box: its stop lines and crosswalks

var _net: RoadNet
var _lanes: Array[PackedVector2Array]
var _roofs: Array  # of [Rect2, Texture2D]
var _patches: Array[Transform2D]  # each maps a unit square onto a tar patch, along its lane
var _manholes: Array[Vector2]


func _init(net: RoadNet, seed_value: int) -> void:
	_net = net
	_lanes = lanes(net)
	_roofs = _scatter(net, seed_value)
	var wear := _wear(net, seed_value)
	_patches.assign(wear[0])
	_manholes.assign(wear[1])
	z_as_relative = false
	z_index = Art.Z_GROUND


## Every lane's centre line as points, in driving order. A lane at the map edge runs on RUN_ON further out, so in a wide
## window the road carries on past the edge instead of stopping.
static func lanes(net: RoadNet) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for seg in net.segments:
		var pts := seg.curve.get_baked_points()
		var run := _run_on(net, seg)
		if seg.kind == RoadNet.Segment.Kind.INCOMING and not run.is_empty():
			pts.insert(0, run[1])
		elif not run.is_empty():
			pts.append(run[1])
		out.append(pts)
	return out


# Where a lane at the map edge runs on: its outer end and the point RUN_ON past it; empty for any other lane.
static func _run_on(net: RoadNet, seg: RoadNet.Segment) -> PackedVector2Array:
	var c := seg.curve
	var last := c.point_count - 1
	if seg.kind == RoadNet.Segment.Kind.INCOMING and net.approaches[seg.approach].entry:
		var start := c.get_point_position(0)
		return PackedVector2Array([start, start - net.approaches[seg.approach].direction * RUN_ON])
	if seg.kind == RoadNet.Segment.Kind.OUTGOING:
		var end := c.get_point_position(last)
		return PackedVector2Array([end, end + (end - c.get_point_position(last - 1)).normalized() * RUN_ON])
	return PackedVector2Array()


## The rooftops' world rects for a map: on a jittered grid over the map and past its edge, wherever a roof stays
## ROOF_GAP clear of every road and crossing box. The same seed scatters the same roofs.
static func roofs(net: RoadNet, seed_value: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Array in _scatter(net, seed_value):
		out.append(r[0])
	return out


static func _scatter(net: RoadNet, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var boxes: Array[PackedVector2Array] = []
	for x in net.crossings.size():
		boxes.append(Geometry2D.offset_polygon(net.box(x), ROOF_GAP)[0])
	var area := net.bounds.grow(ROOF_SPREAD)
	var out := []
	var y := area.position.y
	while y < area.end.y:
		var x := area.position.x
		while x < area.end.x:
			var tex: Texture2D = Art.ROOFS[rng.randi() % Art.ROOFS.size()]
			var size := tex.get_size() * Art.SCALE
			var centre := Vector2(x + rng.randf_range(-ROOF_JITTER, ROOF_JITTER), y + rng.randf_range(-ROOF_JITTER, ROOF_JITTER))
			var r := Rect2(centre - size / 2.0, size)
			if rng.randf() >= ROOF_SKIP and _clear(net, boxes, r):
				out.append([r, tex])
			x += ROOF_STEP
		y += ROOF_STEP
	return out


# Whether a roof at r stays clear of every lane (by its half-diagonal, so any corner) and every box.
static func _clear(net: RoadNet, boxes: Array[PackedVector2Array], r: Rect2) -> bool:
	var centre := r.get_center()
	var reach := Tuning.LW / 2.0 + ROOF_GAP + r.size.length() / 2.0
	for seg in net.segments:
		if seg.curve.get_closest_point(centre).distance_to(centre) < reach:
			return false
		var run := _run_on(net, seg)
		if not run.is_empty() and Geometry2D.get_closest_point_to_segment(centre, run[0], run[1]).distance_to(centre) < reach:
			return false
	var corners := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for b in boxes:
		if not Geometry2D.intersect_polygons(b, corners).is_empty():
			return false
	return true


## The manholes' world centres for a map: in the lanes, clear of every crossing box by MANHOLE_CLEAR. The same seed
## places the same manholes.
static func manholes(net: RoadNet, seed_value: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.assign(_wear(net, seed_value)[1])
	return out


# The road wear: [the tar patches' transforms, the manholes' centres], at spots WEAR_STEP apart along every lane and
# clear of every box. Its own RNG, so the roofs' scatter doesn't shift.
static func _wear(net: RoadNet, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, "wear"])
	var bare: Array[PackedVector2Array] = []
	for x in net.crossings.size():
		bare.append(Geometry2D.offset_polygon(net.box(x), MANHOLE_CLEAR)[0])
	var patches: Array[Transform2D] = []
	var holes: Array[Vector2] = []
	for points in lanes(net):
		var lane := Curve2D.new()
		for p in points:
			lane.add_point(p)
		var s := rng.randf_range(0.0, WEAR_STEP)
		while s < lane.get_baked_length():
			var at := lane.sample_baked_with_rotation(s)
			var roll := rng.randf()
			var size := Vector2(rng.randf_range(PATCH_SIZE.x, PATCH_SIZE.y), rng.randf_range(PATCH_WIDTH.x, PATCH_WIDTH.y) * Tuning.LW)
			var across := rng.randf_range(-1.0, 1.0)
			var tilt := rng.randf_range(-PATCH_TILT, PATCH_TILT)
			s += WEAR_STEP
			if roll < MANHOLE_ODDS:
				var p := at.origin + at.y * across * (Tuning.LW / 2.0 - MANHOLE_R - 2.0) * MANHOLE_SPREAD
				if _bare(bare, p, MANHOLE_R):
					holes.append(p)
			elif roll < MANHOLE_ODDS + PATCH_ODDS:
				var centre := at.origin + at.y * across * (Tuning.LW - size.y) / 2.0
				if _bare(bare, centre, size.length() / 2.0):
					patches.append(Transform2D(at.get_rotation() + tilt, size, 0.0, centre))
	return [patches, holes]


# Whether a circle at p of radius r stays off every bare zone around the boxes.
static func _bare(bare: Array[PackedVector2Array], p: Vector2, r: float) -> bool:
	for b in bare:
		if Geometry2D.is_point_in_polygon(p, b):
			return false
		for i in b.size():
			if Geometry2D.get_closest_point_to_segment(p, b[i], b[(i + 1) % b.size()]).distance_to(p) < r:
				return false
	return true


func _draw() -> void:
	draw_rect(_net.bounds.grow(3000.0), PAVEMENT)
	for r: Array in _roofs:
		var rect: Rect2 = r[0]
		draw_rect(Rect2(rect.position + Art.SHADOW_FALL, rect.size).grow(-Art.MARGIN), Art.SHADOW)  # roofs have the same outline margin as vehicles
		draw_texture_rect(r[1], rect, false)
	for lane in _lanes:
		draw_polyline(lane, KERB, Tuning.LW + KERB_W * 2.0)
	for x in _net.crossings.size():
		draw_colored_polygon(Geometry2D.offset_polygon(_net.box(x), KERB_W)[0], KERB)
	for lane in _lanes:
		draw_polyline(lane, ASPHALT, Tuning.LW)
	for x in _net.crossings.size():
		draw_colored_polygon(_net.box(x), ASPHALT)
	for xf in _patches:
		draw_set_transform_matrix(xf)
		draw_rect(Rect2(-0.5, -0.5, 1.0, 1.0), PATCH)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var hole := Art.MANHOLE.get_size() * Art.SCALE  # 16 world px, the rim MANHOLE_R out
	for p in _manholes:
		draw_texture_rect(Art.MANHOLE, Rect2(p - hole / 2.0, hole), false)
	for a in _net.approaches:
		_crosswalk(a)
		var d := a.direction
		# A road linking two crossings is two approaches' lanes: dash it once, from the lane heading east (or south).
		if a.entry or d.x > 0.001 or (absf(d.x) <= 0.001 and d.y > 0.0):
			_dashes(_lanes[a.incoming])


# White stripes across the whole road, both lanes, just past the approach's stop line.
func _crosswalk(a: RoadNet.Approach) -> void:
	var d := a.direction
	var right := RoadNet.right_of(d)
	var centre := a.stop_point - right * Tuning.LW / 2.0  # the road's centre at the stop line
	var t := -Tuning.LW + STRIPE_STEP / 2.0
	while t + STRIPE / 2.0 <= Tuning.LW:
		var mid := centre + right * t
		var half := right * STRIPE / 2.0
		var near := mid + d * CROSSWALK.x
		var far := mid + d * CROSSWALK.y
		draw_colored_polygon(PackedVector2Array([near - half, far - half, far + half, near + half]), Color(MARKING, 0.85))
		t += STRIPE_STEP


# The dashed centre line down the driver's left of an incoming lane: the middle of its road.
func _dashes(points: PackedVector2Array) -> void:
	var lane := Curve2D.new()
	for p in points:
		lane.add_point(p)
	var length := lane.get_baked_length()
	var s := DASH / 2.0
	while s + DASH <= length:
		var a := lane.sample_baked_with_rotation(s)
		var b := lane.sample_baked_with_rotation(s + DASH)
		draw_line(a.origin - a.y * Tuning.LW / 2.0, b.origin - b.y * Tuning.LW / 2.0, MARKING, 2.0)
		s += DASH * 2.0

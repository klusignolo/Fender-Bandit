class_name GridlockBeat
extends CanvasLayer
## The Gridlock beat (#43, #19 story 54), on real time from the Gridlock: traffic coasts on in slow-mo, then
## every car crashes at once; the frame freezes, washes out and cracks like glass; a GRIDLOCK banner slams in; then
## the shards and the banner fall away to the results, which Flow shows under them at GRIDLOCK_HOLD. Input stays
## locked until then (Flow). It sits over the UI layer, so the results card is there as the shards fall.
## The crack is a capture of the screen cut into 14 pre-made shards (shards(), each a Polygon2D), so it needs nothing the
## Compatibility renderer lacks. A headless run has nothing to capture: its shards are flat grey.
## It nods to a game-over freeze-frame but copies no one's type or look: a tilted full-red road-sign band with the word
## in outlined white, over cracked glass.

enum Phase { SLOWMO, PILEUP, CRACKED, BANNER, FALLING, DONE }

const RAYS: Array[float] = [10.0, 58.0, 112.0, 157.0, 203.0, 251.0, 304.0]  # degrees of the cracks out of the impact, clockwise
const RING: Array[float] = [0.24, 0.31, 0.20, 0.28, 0.22, 0.33, 0.26]  # where each crack meets the ring crack, × screen height
const IMPACT := Vector2(0.64, 0.36)  # the impact point, as a share of the screen: above the banner, so the star shows
const NUDGE := 3.0  # px each shard is knocked away from the impact as it cracks, so the cracks show
const FLASH_TIME := 0.25  # seconds the white flash of the crack fades over...
const FLASH_ALPHA := 0.7  # ...from this
const FALL_DELAY := 0.05  # seconds between each of the five waves of falling shards
const FALL_V := 180.0  # px/s each shard falls from the start, at a screen 720 tall...
const FALL_G := 4200.0  # ...gaining this much per second...
const FALL_SPREAD := 220.0  # ...and drifting sideways away from the impact up to this fast
const FALL_SPIN := 1.2  # radians per second a shard turns at most
const BANNER_H := 150.0  # px: the banner band's height...
const BANNER_TILT := -0.07  # ...its tilt, radians...
const BANNER_TEXT := 112  # ...the word's size...
const BANNER_SLAM := 0.14  # ...and the seconds it takes to slam down from SLAM_FROM× its size
const SLAM_FROM := 2.4
const JOLT_PX := 10.0  # px the glass jolts as the banner lands...
const JOLT_TIME := 0.3  # ...settling over this long
const BANNER_LAG := 0.12  # seconds the banner hangs on as the shards start to fall...
const BANNER_TIP := 0.5  # ...then tips over at this many radians per second
const SIGNAL_RED := Color("#E8322B")  # the banner: the one full-red UI element (docs/sprites.md)
const WASH := preload("res://main/wash.gdshader")

var _world: World
var _t := 0.0  # real seconds since the Gridlock
var _phase := Phase.SLOWMO
var _view := Vector2.ZERO
var _shards: Array[Polygon2D] = []
var _pieces: Array[PackedVector2Array] = []
var _nudges: Array[Vector2] = []
var _shards_layer := Node2D.new()
var _flash := Node2D.new()
var _banner := Node2D.new()


## The phase `t` real seconds into the beat.
static func phase_at(t: float) -> Phase:
	if t >= Tuning.GRIDLOCK_HOLD + Tuning.GRIDLOCK_FALL_TIME:
		return Phase.DONE
	if t >= Tuning.GRIDLOCK_HOLD:
		return Phase.FALLING
	if t >= Tuning.GRIDLOCK_BANNER_AT:
		return Phase.BANNER
	if t >= Tuning.GRIDLOCK_CRACK_AT:
		return Phase.CRACKED
	if t >= Tuning.GRIDLOCK_PILEUP_AT:
		return Phase.PILEUP
	return Phase.SLOWMO


## Where the glass is struck, on a `view` screen.
static func impact(view: Vector2) -> Vector2:
	return view * IMPACT


## The pre-made shards for a `view` screen: an inner piece and an outer piece between each pair of cracks, cut where
## the cracks meet the ring. They tile the screen exactly, at any window shape.
static func shards(view: Vector2) -> Array[PackedVector2Array]:
	var p := impact(view)
	var n := RAYS.size()
	var rings: Array[Vector2] = []
	var edges: Array[Vector2] = []
	for i in n:
		var d := Vector2.from_angle(deg_to_rad(RAYS[i]))
		rings.append(p + d * RING[i] * view.y)
		edges.append(_to_edge(p, d, view))
	var screen: Array[Vector2] = [Vector2.ZERO, Vector2(view.x, 0), view, Vector2(0, view.y)]
	var out: Array[PackedVector2Array] = []
	for i in n:
		var j := (i + 1) % n
		var a0 := deg_to_rad(RAYS[i])
		var a1 := deg_to_rad(RAYS[j]) + (TAU if j == 0 else 0.0)
		out.append(PackedVector2Array([p, rings[i], rings[j]]))
		var corners: Array[Vector2] = []  # (angle from the impact, index into screen) of each corner inside this wedge
		for k in screen.size():
			var a := fposmod((screen[k] - p).angle(), TAU)
			if a <= a0:
				a += TAU
			if a < a1:
				corners.append(Vector2(a, k))
		corners.sort()
		var outer := PackedVector2Array([rings[i], edges[i]])
		for c in corners:
			outer.append(screen[int(c.y)])
		outer.append_array([edges[j], rings[j]])
		out.append(outer)
	return out


## How shard `i` (its points `piece`) has moved `t` seconds into the fall: in waves, down and away from the impact,
## turning about its centre.
static func fall(piece: PackedVector2Array, i: int, t: float, view: Vector2) -> Transform2D:
	var s := maxf(t - (i % 5) * FALL_DELAY, 0.0)
	var c := _centre(piece)
	var k := view.y / 720.0
	var away := clampf((c.x - impact(view).x) / (view.x / 2.0), -1.0, 1.0)
	var moved := Vector2(away * FALL_SPREAD * s, FALL_V * s + 0.5 * FALL_G * s * s) * k
	var spin := FALL_SPIN * (0.4 + 0.6 * fposmod(i * 0.618, 1.0)) * (1.0 if away >= 0.0 else -1.0) * s
	return Transform2D(spin, c + moved) * Transform2D(0.0, -c)


static func _centre(piece: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for q in piece:
		c += q / piece.size()
	return c


# Where a crack from `p` going `d` leaves the screen.
static func _to_edge(p: Vector2, d: Vector2, view: Vector2) -> Vector2:
	var t := INF
	if d.x > 0.0:
		t = minf(t, (view.x - p.x) / d.x)
	elif d.x < 0.0:
		t = minf(t, -p.x / d.x)
	if d.y > 0.0:
		t = minf(t, (view.y - p.y) / d.y)
	elif d.y < 0.0:
		t = minf(t, -p.y / d.y)
	return p + d * t


## `world` is the board that gridlocked: it coasts in slow-mo until the pile-up.
func _init(world: World) -> void:
	_world = world
	layer = 4  # over the UI layer, so the results show under the falling shards
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_view = get_viewport().get_visible_rect().size
	_flash.draw.connect(func() -> void:
		var k := (_t - Tuning.GRIDLOCK_CRACK_AT) / FLASH_TIME
		_flash.draw_rect(Rect2(Vector2.ZERO, _view), Color(1, 1, 1, FLASH_ALPHA * (1.0 - k))))
	_banner.draw.connect(_draw_banner)
	_banner.position = _view / 2.0
	_flash.visible = false
	_banner.visible = false
	_shards_layer.z_index = -1  # the shards go under the flash and the banner
	add_child(_shards_layer)
	add_child(_flash)
	add_child(_banner)
	_world.gridlock()


func _physics_process(_delta: float) -> void:
	_t += 1.0 / Engine.physics_ticks_per_second  # real time: the beat runs on through the slow-mo
	var p := phase_at(_t)
	while _phase < p:
		_phase = (_phase + 1) as Phase
		_enter(_phase)
	if _phase == Phase.DONE:
		return
	_flash.visible = not _shards.is_empty() and _t - Tuning.GRIDLOCK_CRACK_AT < FLASH_TIME  # never in the capture
	if _flash.visible:
		_flash.queue_redraw()
	if _phase == Phase.BANNER:
		var since := _t - Tuning.GRIDLOCK_BANNER_AT
		_banner.scale = Vector2.ONE * lerpf(SLAM_FROM, 1.0, minf(since / BANNER_SLAM, 1.0))
		var jolt := since - BANNER_SLAM
		offset = Vector2.ZERO if jolt < 0.0 or jolt > JOLT_TIME else \
				Vector2(sin(jolt * 70.0), cos(jolt * 55.0)) * JOLT_PX * (1.0 - jolt / JOLT_TIME)
	elif _phase == Phase.FALLING:
		var t := _t - Tuning.GRIDLOCK_HOLD
		for i in _shards.size():
			_shards[i].transform = fall(_pieces[i], i, t, _view).translated(_nudges[i])
		var s := maxf(t - BANNER_LAG, 0.0)
		_banner.position = _view / 2.0 + Vector2(0.0, 0.5 * FALL_G * _view.y / 720.0 * s * s)
		_banner.rotation = BANNER_TILT - BANNER_TIP * s


func _enter(p: Phase) -> void:
	match p:
		Phase.PILEUP:
			if is_instance_valid(_world):
				_world.pile_up()
			for i in 3:
				Audio.play(StringName("crash_%d" % (i + 1)), 0.85 + 0.15 * i)
		Phase.CRACKED:
			_crack()
		Phase.BANNER:
			_banner.visible = true
		Phase.FALLING:
			offset = Vector2.ZERO
		Phase.DONE:
			queue_free()


# Freeze the frame: capture the screen as it was last drawn, cut it into the shards, wash it out, and crack it.
func _crack() -> void:
	Audio.play(&"gridlock_shatter")
	var tex: Texture2D = null
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
		else:
			push_warning("Gridlock: no screen capture to crack; the shards are flat grey")
	if not is_inside_tree():
		return
	if is_instance_valid(_world):
		_world.process_mode = Node.PROCESS_MODE_DISABLED  # covered from now on
	var wash := ShaderMaterial.new()
	wash.shader = WASH
	var uv := tex.get_size() / _view if tex != null else Vector2.ONE  # the capture is in window px, the screen in canvas px
	var p := impact(_view)
	_pieces = shards(_view)
	for piece in _pieces:
		var s := Polygon2D.new()
		s.polygon = piece
		if tex != null:
			s.texture = tex
			s.uv = Transform2D.IDENTITY.scaled(uv) * piece
			s.material = wash
		else:
			s.color = Color(0.62, 0.64, 0.68)
		var edge := Line2D.new()
		edge.points = piece
		edge.closed = true
		edge.width = 2.0
		edge.default_color = Color(1, 1, 1, 0.9)
		s.add_child(edge)
		_nudges.append((_centre(piece) - p).normalized() * NUDGE)
		s.position = _nudges[-1]
		_shards.append(s)
		_shards_layer.add_child(s)


# The banner, about its centre: a tilted full-red band with white rules and the word in white over ink.
func _draw_banner() -> void:
	_banner.draw_set_transform(Vector2.ZERO, BANNER_TILT)
	var w := _view.length() * 1.2  # past both sides at any tilt
	var band := Rect2(-w / 2.0, -BANNER_H / 2.0, w, BANNER_H)
	_banner.draw_rect(band.grow(6.0), Card.INK)
	_banner.draw_rect(band, SIGNAL_RED)
	for y in [-BANNER_H / 2.0 + 12.0, BANNER_H / 2.0 - 15.0]:
		_banner.draw_rect(Rect2(-w / 2.0, y, w, 3.0), Color.WHITE)
	var font := Sign.FONT
	var word := "GRIDLOCK!"
	var at := Vector2(-font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_TEXT).x / 2.0, BANNER_TEXT * 0.36)
	_banner.draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_TEXT, 10, Card.INK)
	_banner.draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_TEXT, Color.WHITE)

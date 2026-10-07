extends SceneTree
## The sprite proof (#18): every sprite the proof judges, drawn by the game's own nodes (Vehicle, LightPole and the
## RaccoonRig), shot in a 960×540 window at on-screen zooms 1× and 0.45×, each with mipmaps (the game's Linear
## Mipmap filter) and without (Linear), in the Compatibility renderer. A fifth shot is the 0.45 floor seen in a
## 960×540 window, where the canvas_items stretch shrinks the 1280×720 base by a further 0.75. Each zoomed-out shot
## also gets a crop of the lineup, enlarged 3× nearest-neighbour, to show its pixels. Content stretch is off
## here, so a world px at zoom 1 is one window px. Writes docs/art/proof/*.png. Needs a window:
##   godot --path game --resolution 960x540 -s tools/sprite_proof.gd
## (game/tools/sprite_proof.sh does that.)

const SIZE := Vector2i(960, 540)
const OUT := "res://../docs/art/proof/"
const MIP := CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
const NO_MIP := CanvasItem.TEXTURE_FILTER_LINEAR
const STRETCH := 960.0 / 1280.0  # what the canvas_items stretch makes of the 1280×720 base in a 960×540 window
## [file, on-screen zoom, filter, label]
const SHOTS: Array[Array] = [
	["sprites-1x-mipmaps", 1.0, MIP, "1× · mipmaps"],
	["sprites-1x-no-mipmaps", 1.0, NO_MIP, "1× · no mipmaps"],
	["sprites-045x-mipmaps", Tuning.READ_FLOOR, MIP, "0.45× · mipmaps"],
	["sprites-045x-no-mipmaps", Tuning.READ_FLOOR, NO_MIP, "0.45× · no mipmaps"],
	["sprites-034x-mipmaps", Tuning.READ_FLOOR * STRETCH, MIP, "0.45× in a 960×540 window (0.34×) · mipmaps"],
]
const ASPHALT := Color("#3B4252")
const PAVEMENT := Color("#5E6A80")
const PITCH := 56.0  # world px between vehicle centres in a row
const EXTENT := Rect2(-230, -140, 480, 345)  # world px round the lineup: the crop of a zoomed-out shot
const CROP_SCALE := 3  # its crop is enlarged this many times, nearest-neighbour, to show the pixels
const ROWS: Array[float] = [-110.0, -50.0, 20.0, 95.0, 160.0]  # world px: tints, specials, Raccoons, Light poles, the Honk
const RACCOON_PITCH := 46.0  # world px between the Raccoons: room for them at their floor size
## The Raccoon poses: [name, view, animation, seconds in, direction]. Its four views, then a moment of each animation.
const RACCOON_POSES: Array[Array] = [
	["Front", Raccoon.View.FRONT, RaccoonRig.Anim.IDLE, 0.0, Vector2.ZERO],
	["Back", Raccoon.View.BACK, RaccoonRig.Anim.IDLE, 0.0, Vector2.ZERO],
	["Side", Raccoon.View.RIGHT, RaccoonRig.Anim.IDLE, 0.0, Vector2.ZERO],
	["SideLeft", Raccoon.View.LEFT, RaccoonRig.Anim.IDLE, 0.0, Vector2.ZERO],
	["Blink", Raccoon.View.FRONT, RaccoonRig.Anim.IDLE, RaccoonRig.BLINK_EVERY - 0.05, Vector2.ZERO],
	["Walk", Raccoon.View.RIGHT, RaccoonRig.Anim.WALK, RaccoonRig.WALK_CYCLE / 4.0, Vector2.RIGHT],
	["Dash", Raccoon.View.RIGHT, RaccoonRig.Anim.DASH, Tuning.DASH_TIME * 0.5, Vector2.RIGHT],
	["Switch", Raccoon.View.FRONT, RaccoonRig.Anim.SWITCH, 0.0, Vector2(1, -1)],
	["Tow", Raccoon.View.RIGHT, RaccoonRig.Anim.TOW, RaccoonRig.WALK_CYCLE / 4.0, Vector2.RIGHT],
	["Bonk", Raccoon.View.FRONT, RaccoonRig.Anim.BONK, Tuning.STUN_TIME * 0.6, Vector2.ZERO],
]

var _traffic := Traffic.new(1, 0, Stages.def(9, 1))
var _lineup: Node2D
var _camera := Camera2D.new()
var _label := Node2D.new()
var _shot := 0
var _frames := 0


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = SIZE
	_lineup = lineup(_traffic)
	root.add_child(_lineup)
	root.add_child(_camera)
	var hud := CanvasLayer.new()
	hud.add_child(_label)
	root.add_child(hud)
	_label.draw.connect(func() -> void: Sign.text(_label, SHOTS[_shot][3], Vector2(16, 40), 20))
	_set_shot()


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:  # let the window settle and draw
		return false
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + SHOTS[_shot][0] + ".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	print("wrote %s: %s" % [path, error_string(img.save_png(path))])
	if SHOTS[_shot][1] < 1.0:
		var z: float = SHOTS[_shot][1]
		var r := Rect2i(Rect2(Vector2(SIZE) / 2.0 + EXTENT.position * z, EXTENT.size * z))
		var crop := img.get_region(r)
		crop.resize(r.size.x * CROP_SCALE, r.size.y * CROP_SCALE, Image.INTERPOLATE_NEAREST)
		var crop_path := path.get_basename() + "-crop.png"
		print("wrote %s: %s" % [crop_path, error_string(crop.save_png(crop_path))])
	_shot += 1
	if _shot == SHOTS.size():
		return true
	_set_shot()
	return false


func _set_shot() -> void:
	_frames = 0
	_camera.zoom = Vector2.ONE * SHOTS[_shot][1]
	for rig in _lineup.find_children("*", "RaccoonRig", true, false):
		show_rig(rig, maxf(SHOTS[_shot][1], Tuning.READ_FLOOR))  # the game's camera never zooms out past the floor
	set_filter(_lineup, SHOTS[_shot][2])
	_label.queue_redraw()


## The proof's lineup, centred on the origin, on asphalt between strips of pavement:
## a car in each safe tint, then a motorcycle and a semi; a braking car and Wreckage of each kind; the Raccoon's front,
## back, side and mirrored side; a pole lit red, yellow and green with its stop line; a blinking Turner with its
## arrow, Patience ring and a HONK; and the Raccoon rig (#41) in each view and in a pose from each animation.
static func lineup(t: Traffic) -> Node2D:
	var root := Node2D.new()
	root.name = "Lineup"
	var ground := Node2D.new()
	ground.name = "Ground"
	ground.z_as_relative = false
	ground.z_index = Art.Z_GROUND  # under the stop lines and shadows, as in the game
	ground.draw.connect(func() -> void:
		ground.draw_rect(Rect2(-3000, -2000, 6000, 4000), PAVEMENT)  # past the window at any zoom
		ground.draw_rect(Rect2(-3000, ROWS[0] - 30.0, 6000, ROWS[4] - ROWS[0] + 60.0), ASPHALT))
	root.add_child(ground)
	var light := t.lights[0]  # every vehicle obeys it; it only matters to the sim
	var straight := _route(t, RoadNet.Movement.STRAIGHT)
	var turner := _route(t, RoadNet.Movement.LEFT)
	var id := 0
	var x := -3.5 * PITCH
	for tint in Car.TINTS:
		_vehicle(root, t, Car.new(id, straight, light), tint, Vector2(x, ROWS[0]))
		id += 1
		x += PITCH
	_vehicle(root, t, Car.new(id, straight, light, Car.Kind.MOTORCYCLE), Car.TINTS[3], Vector2(x - 10.0, ROWS[0]))
	_vehicle(root, t, Car.new(id + 1, straight, light, Car.Kind.SEMI), Car.TINTS[1], Vector2(x + 60.0, ROWS[0]))
	id += 2
	var braking := Car.new(id, straight, light)
	braking.braking = true
	_vehicle(root, t, braking, Car.TINTS[0], Vector2(-3.5 * PITCH, ROWS[1]))
	var honker := Car.new(id + 1, turner, light)
	_vehicle(root, t, honker, Car.TINTS[4], Vector2(-3.5 * PITCH, ROWS[4]))  # its HONK is on-screen size: in a row of its own
	honker.patience = 12.0  # a half-spent second Patience stage: its ring shows part-filled
	honker.wait = 6.0
	honker.honks = 1  # Vehicle sees a new Honk on its next sync
	id += 2
	x = -0.5 * PITCH
	for kind: Car.Kind in [Car.Kind.CAR, Car.Kind.MOTORCYCLE, Car.Kind.SEMI]:
		var wreck := Car.new(id, straight, light, kind)
		wreck.wreckage = true
		_vehicle(root, t, wreck, Car.TINTS[2 + kind], Vector2(x, ROWS[1]))
		id += 1
		x += PITCH * (1.0 if kind == Car.Kind.CAR else 1.6)
	x = -3.5 * PITCH
	for pose: Array in RACCOON_POSES:
		var rig := RaccoonRig.new()
		rig.name = "Raccoon" + pose[0]
		rig.z_index = Art.Z_UPRIGHT
		rig.position = Vector2(x, ROWS[2] + 19.0)
		rig.set_meta(&"pose", pose.slice(1))
		show_rig(rig, 1.0)
		root.add_child(rig)
		x += RACCOON_PITCH
	var south := t.net.approaches.filter(func(a: RoadNet.Approach) -> bool: return a.direction.y > 0.9)
	x = 0.5 * PITCH
	for state: Light.State in [Light.State.RED, Light.State.YELLOW, Light.State.GREEN]:
		var l := Light.new(0, south[0])
		l.state = state
		var holder := Node2D.new()
		holder.position = Vector2(x, ROWS[3]) - l.pole
		holder.add_child(LightPole.new(l))
		root.add_child(holder)
		x += 70.0
	return root


## Sets `filter` on every canvas item under `node`: the top-level cues and smoke don't inherit it.
static func set_filter(node: Node, filter: CanvasItem.TextureFilter) -> void:
	if node is CanvasItem:
		(node as CanvasItem).texture_filter = filter
	for c in node.get_children():
		set_filter(c, filter)


static func _route(t: Traffic, movement: RoadNet.Movement) -> RoadNet.Route:
	for a in t.net.approaches:
		for r in a.routes:
			if r.movement == movement:
				return r
	return null


static func _vehicle(root: Node2D, t: Traffic, c: Car, tint: Color, at: Vector2) -> void:
	c.tint = tint
	c.transform = Transform2D(0.0, at)
	var v := Vehicle.new(t)
	root.add_child(v)
	v.show_car(c)


## Poses a lineup Raccoon as its "pose" meta says, at the size the game draws it at camera zoom `zoom`.
static func show_rig(rig: RaccoonRig, zoom: float) -> void:
	var p: Array = rig.get_meta(&"pose")
	rig.zoom = zoom
	rig.show_pose(p[0], p[1], p[2], p[3])

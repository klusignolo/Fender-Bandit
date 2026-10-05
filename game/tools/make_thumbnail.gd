extends SceneTree
## Renders the itch.io cover (#42) to docs/art/itch-thumbnail.png at itch's 630×500: the Raccoon Crossing diamond
## (res://icon.svg) over asphalt, and the name and tagline on a striped lockup, as the title's logo. Needs a window:
##   godot --path game --resolution 630x500 -s tools/make_thumbnail.gd
## (game/tools/make_thumbnail.sh does that.)

const SIZE := Vector2i(630, 500)
const OUT := "res://../docs/art/itch-thumbnail.png"
const ASPHALT := Color("#3B4252")
const DIAMOND := 300  # px
const NAME_SIZE := 54
const TAG_SIZE := 24

var _frames := 0
var _icon: ImageTexture  # held, so it lives until the frame is drawn


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = SIZE
	var cover := Node2D.new()
	cover.draw.connect(_draw_cover.bind(cover))
	root.add_child(cover)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:  # let the window settle and draw
		return false
	var img := root.get_texture().get_image()
	img.crop(SIZE.x, SIZE.y)
	var path := ProjectSettings.globalize_path(OUT)
	var err := img.save_png(path)
	print("wrote %s: %s" % [path, error_string(err)])
	return true


func _draw_cover(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, SIZE), ASPHALT)
	for i in 9:  # a crosswalk behind the sign
		c.draw_rect(Rect2(i * 76 - 10, 150, 40, 120), Color(1, 1, 1, 0.08))
	var icon := Image.new()
	icon.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"), DIAMOND / 128.0)
	_icon = ImageTexture.create_from_image(icon)
	c.draw_texture(_icon, Vector2((SIZE.x - DIAMOND) / 2.0, 14))
	var board := Rect2(40, 324, SIZE.x - 80, 150)
	Sign.stripes(c, board)
	var plate := board.grow(-14)
	Sign.plate(c, plate, Sign.INK)
	var name := "FENDER BANDIT"
	Sign.text(c, name, Vector2((SIZE.x - Sign.width(name, NAME_SIZE)) / 2.0, plate.position.y + 66), NAME_SIZE)
	var tag := "STOP. GO. OOPS."
	Sign.text(c, tag, Vector2((SIZE.x - Sign.width(tag, TAG_SIZE)) / 2.0, plate.end.y - 18), TAG_SIZE, Sign.ORANGE)

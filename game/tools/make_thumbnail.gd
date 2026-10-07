extends SceneTree
## Renders the itch.io art from the Raccoon Crossing diamond (res://icon.svg) over asphalt and the name and tagline
## on a striped lockup, as the title's logo:
## - the cover (#42), docs/art/itch-thumbnail.png at itch's 630×500: the diamond above the lockup;
## - the page banner, docs/art/itch-banner.png at 960×240, the width of itch's page column: the diamond beside the
##   lockup, on a road between kerbs.
## Needs a window:
##   godot --path game --resolution 630x500 -s tools/make_thumbnail.gd
##   godot --path game --resolution 960x240 -s tools/make_thumbnail.gd -- --banner
## (game/tools/make_thumbnail.sh does both.)

const COVER := Vector2i(630, 500)
const BANNER := Vector2i(960, 240)
const COVER_OUT := "res://../docs/art/itch-thumbnail.png"
const BANNER_OUT := "res://../docs/art/itch-banner.png"
const ASPHALT := Color("#3B4252")
const PAVEMENT := Color("#5E6A80")
const KERB := Color("#8691A6")
const DIAMOND := 300  # px, on the cover
const BANNER_DIAMOND := 210  # px
const NAME_SIZE := 54
const TAG_SIZE := 24
const BANNER_NAME_SIZE := 60
const BANNER_TAG_SIZE := 28

var _banner := "--banner" in OS.get_cmdline_user_args()
var _size := BANNER if _banner else COVER
var _frames := 0
var _icon: ImageTexture  # held, so it lives until the frame is drawn


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = _size
	var art := Node2D.new()
	art.draw.connect((_draw_banner if _banner else _draw_cover).bind(art))
	root.add_child(art)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:  # let the window settle and draw
		return false
	var img := root.get_texture().get_image()
	img.crop(_size.x, _size.y)
	var path := ProjectSettings.globalize_path(BANNER_OUT if _banner else COVER_OUT)
	var err := img.save_png(path)
	print("wrote %s: %s" % [path, error_string(err)])
	return true


func _diamond(px: int) -> ImageTexture:
	var icon := Image.new()
	icon.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"), px / 128.0)
	_icon = ImageTexture.create_from_image(icon)
	return _icon


## The striped lockup: the name above the tagline, centred in `board`.
func _lockup(c: Node2D, board: Rect2, name_size: int, tag_size: int, name_drop: float) -> void:
	Sign.stripes(c, board)
	var plate := board.grow(-14)
	Sign.plate(c, plate, Sign.INK)
	var mid := plate.get_center().x
	var name := "FENDER BANDIT"
	Sign.text(c, name, Vector2(mid - Sign.width(name, name_size) / 2.0, plate.position.y + name_drop), name_size)
	var tag := "STOP. GO. OOPS."
	Sign.text(c, tag, Vector2(mid - Sign.width(tag, tag_size) / 2.0, plate.end.y - 18), tag_size, Sign.ORANGE)


func _draw_cover(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, COVER), ASPHALT)
	for i in 9:  # a crosswalk behind the sign
		c.draw_rect(Rect2(i * 76 - 10, 150, 40, 120), Color(1, 1, 1, 0.08))
	c.draw_texture(_diamond(DIAMOND), Vector2((COVER.x - DIAMOND) / 2.0, 14))
	_lockup(c, Rect2(40, 324, COVER.x - 80, 150), NAME_SIZE, TAG_SIZE, 66)


func _draw_banner(c: Node2D) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, BANNER), ASPHALT)
	for y in [0.0, BANNER.y - 14.0]:  # pavement along both edges, kerbed on the road side
		c.draw_rect(Rect2(0, y, BANNER.x, 14), PAVEMENT)
	c.draw_rect(Rect2(0, 14, BANNER.x, 3), KERB)
	c.draw_rect(Rect2(0, BANNER.y - 17, BANNER.x, 3), KERB)
	c.draw_texture(_diamond(BANNER_DIAMOND), Vector2(36, (BANNER.y - BANNER_DIAMOND) / 2.0))
	_lockup(c, Rect2(282, 42, BANNER.x - 282 - 36, 156), BANNER_NAME_SIZE, BANNER_TAG_SIZE, 74)

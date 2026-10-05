class_name Sign
extends RefCounted
## The road-sign kit (#42, docs/sprites.md "Type and UI"): Bungee, the blue sign panel and the orange-and-navy
## construction stripes, drawn on any CanvasItem. Panels are drawn as StyleBoxFlats, not a 9-patch texture, so they
## stay crisp however far the window stretches the 1280×720 base.

const FONT := preload("res://art/fonts/Bungee-Regular.ttf")
const BLUE := Color("#1F5FAF")  # `sign_blue`
const INK := Color("#1B2340")  # `ink`
const ORANGE := Color("#FF7A1A")  # `raccoon_orange`: Raccoon moments only
const SHADOW := Color("#0E1424", 0.45)  # `shadow`
const RADIUS := 16  # px: a sign's corner
const EDGE := 3  # px of ink around a sign
const INSET := 7.0  # px from a sign's edge to its white rule...
const RULE := 3  # ...and the rule's width
const DROP := Vector2(5, 5)  # px a sign's shadow falls down-right, light from the top-left
const STRIPE := 26.0  # px across one construction stripe
const OUTLINE := 4  # px of ink around white text
const CAP := 0.75  # Bungee's cap height, in ems
const TAIL := 0.15  # how far a comma or Q drops below the baseline, in ems

static var _face := _box(BLUE, INK, EDGE, RADIUS)
static var _rule := _box(Color.TRANSPARENT, Color.WHITE, RULE, RADIUS - int(INSET))
static var _drop := _box(SHADOW, Color.TRANSPARENT, 0, RADIUS)
static var _plate := _box(Color.WHITE, Color.TRANSPARENT, 0, 8)


static func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.draw_center = fill.a > 0.0
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	return s


## A blue road sign filling `box`: drop shadow, ink edge, white inset rule.
static func panel(ci: CanvasItem, box: Rect2) -> void:
	ci.draw_style_box(_drop, Rect2(box.position + DROP, box.size))
	ci.draw_style_box(_face, box)
	ci.draw_style_box(_rule, box.grow(-INSET))


## The part of a sign at `box` inside its white rule: where its words go.
static func inner(box: Rect2) -> Rect2:
	return box.grow(-INSET - RULE)


## A plain rounded plate of `colour`, e.g. a white sign-within-a-sign behind a chosen row.
static func plate(ci: CanvasItem, box: Rect2, colour: Color) -> void:
	_plate.bg_color = colour
	ci.draw_style_box(_plate, box)


## Orange-and-navy construction stripes filling `box`, slanting up to the right, with an ink edge.
static func stripes(ci: CanvasItem, box: Rect2) -> void:
	ci.draw_style_box(_drop, Rect2(box.position + DROP, box.size))
	ci.draw_rect(box, INK)
	var clip := PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)])
	var h := box.size.y
	var x := box.position.x - h
	while x < box.end.x:
		var band := PackedVector2Array([Vector2(x, box.end.y), Vector2(x + h, box.position.y),
			Vector2(x + h + STRIPE, box.position.y), Vector2(x + STRIPE, box.end.y)])
		for piece in Geometry2D.intersect_polygons(band, clip):
			ci.draw_colored_polygon(piece, ORANGE)
		x += STRIPE * 2.0
	ci.draw_rect(box.grow(-EDGE / 2.0), INK, false, EDGE)


## Bungee with an ink outline, starting at `at` on its baseline.
static func text(ci: CanvasItem, s: String, at: Vector2, size: int, colour := Color.WHITE, outline := OUTLINE) -> void:
	if outline > 0:
		ci.draw_string_outline(FONT, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, INK)
	ci.draw_string(FONT, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


static func width(s: String, size: int) -> float:
	return FONT.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## The box `s` inks with its baseline at `at`: Bungee is all capitals, so from cap height to a comma's tail.
static func text_rect(s: String, at: Vector2, size: int) -> Rect2:
	return Rect2(at.x, at.y - CAP * size, width(s, size), (CAP + TAIL) * size)

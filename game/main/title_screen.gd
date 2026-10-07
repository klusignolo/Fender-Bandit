class_name TitleScreen
extends Card
## The Attract title (#35, #42, #19 story 1) over the autopilot's Run: the logo lockup, then a blinking "PRESS ANY
## BUTTON" on its own sign. The logo is FENDER over BANDIT on a navy plate framed in construction stripes (a Raccoon
## moment), the Raccoon peeking over its top edge. The tagline stays off it: the itch banner carries it (#45).
## Attract's one crossing sits mid-screen, so the title keeps to the city blocks either side of it (#45): the logo in
## the top-left block, the prompt in the bottom-right one, leaving the crossing and its four roads in view.

const BLINK := 1.2  # seconds per blink of the prompt: on for the first two thirds

const ROAD_CLEAR := 60.0  # px either side of the mid-screen lines that the title keeps clear: Attract's roads
const MARGIN := 24.0  # px from the screen edges
const BOARD := Vector2(560, 250)  # px: the striped board, at full size
const FRAME := 20.0  # px of stripes around the navy plate, at full size
const WORD_SIZE := 92  # at full size
const PEEK := 2.25  # the peeking Raccoon's scale over its texture, at full size
const PEEK_UP := 92.0  # px of it above the board, at full size
const FUR := Color("#8C93A3")  # the Raccoon's fur, from its sprite

var _clock := 0.0  # seconds shown


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var v := view()
	var c := v / 2.0
	var block := Rect2(Vector2(MARGIN, MARGIN), c - Vector2(ROAD_CLEAR + MARGIN, ROAD_CLEAR + MARGIN))
	_logo(block)
	var corner := Rect2(c + Vector2(ROAD_CLEAR, ROAD_CLEAR), c - Vector2(ROAD_CLEAR + MARGIN, ROAD_CLEAR + MARGIN))
	prompt(corner.get_center(), blink(_clock, BLINK))


## The logo, as big as fits `block` up to full size, the peeking Raccoon included, centred in it.
func _logo(block: Rect2) -> void:
	var s := minf(1.0, minf(block.size.x / BOARD.x, block.size.y / (BOARD.y + PEEK_UP)))
	var size := BOARD * s
	var board := Rect2(block.get_center() - Vector2(size.x / 2.0, (size.y - PEEK_UP * s) / 2.0), size)
	var raccoon := Art.RACCOON_FRONT.get_size() * PEEK * s
	var peek := Vector2(board.end.x - 190.0 * s, board.position.y - PEEK_UP * s)
	texture(Art.RACCOON_FRONT, Rect2(peek, raccoon))  # behind the board: only its head shows
	stripe(board)
	var plate_box := board.grow(-FRAME * s)
	plate(plate_box, INK)
	var mid := board.get_center().x
	var word := roundi(WORD_SIZE * s)
	text("FENDER", Vector2(mid, plate_box.position.y + 92.0 * s), word, Color.WHITE, true)
	text("BANDIT", Vector2(mid, plate_box.end.y - 22.0 * s), word, Color.WHITE, true)
	for dx: float in [52.0, 112.0]:  # its paws, gripping the top edge
		var paw := Vector2(peek.x + dx * s, board.position.y + 2.0 * s)
		circle(paw, 13.0 * s, INK)
		circle(paw, 10.0 * s, FUR)

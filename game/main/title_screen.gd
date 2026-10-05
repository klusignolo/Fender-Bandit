class_name TitleScreen
extends Card
## The Attract title (#35, #42, #19 story 1) over the autopilot's Run: the logo lockup, then a blinking
## "PRESS ANY BUTTON". The logo is FENDER over BANDIT on a navy plate framed in construction stripes (a Raccoon
## moment), the Raccoon peeking over its top edge, and "STOP. GO. OOPS." on a little blue sign hung under it.

const BLINK := 1.2  # seconds per blink of the prompt: on for the first two thirds

const BOARD := Vector2(560, 250)  # px: the striped board
const BOARD_TOP := 0.17  # × screen height
const FRAME := 20.0  # px of stripes around the navy plate
const WORD_SIZE := 92
const TAG := Vector2(380, 58)  # px: the tagline's sign
const TAG_SIZE := 28
const PEEK := 2.25  # the peeking Raccoon's scale over its texture
const PEEK_UP := 92.0  # px of it above the board
const FUR := Color("#8C93A3")  # the Raccoon's fur, from its sprite

var _clock := 0.0  # seconds shown


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var v := view()
	var board := Rect2(Vector2((v.x - BOARD.x) / 2.0, v.y * BOARD_TOP), BOARD)
	var size := Art.RACCOON_FRONT.get_size() * PEEK
	var peek := Vector2(board.end.x - 190.0, board.position.y - PEEK_UP)
	texture(Art.RACCOON_FRONT, Rect2(peek, size))  # behind the board: only its head shows
	stripe(board)
	var plate_box := board.grow(-FRAME)
	plate(plate_box, INK)
	var mid := board.get_center().x
	text("FENDER", Vector2(mid, plate_box.position.y + 92.0), WORD_SIZE, Color.WHITE, true)
	text("BANDIT", Vector2(mid, plate_box.end.y - 22.0), WORD_SIZE, Color.WHITE, true)
	for dx: float in [52.0, 112.0]:  # its paws, gripping the top edge
		var paw := Vector2(peek.x + dx, board.position.y + 2.0)
		circle(paw, 13.0, INK)
		circle(paw, 10.0, FUR)
	var tag := Rect2(Vector2(mid - TAG.x / 2.0, board.end.y + 14.0), TAG)
	frame(tag)
	text("STOP. GO. OOPS.", Vector2(mid, tag.get_center().y + TAG_SIZE * Sign.CAP / 2.0), TAG_SIZE)
	if blink(_clock, BLINK):
		text("PRESS ANY BUTTON", Vector2(v.x / 2.0, v.y * 0.8), 40, Color.WHITE, true)

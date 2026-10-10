class_name TitleScreen
extends Card
## The Attract title (#35, #42, #19 story 1) over the autopilot's Run: the logo lockup, and the title menu on its own
## sign. The logo is FENDER over BANDIT on a navy plate framed in construction stripes (a Raccoon moment), the Raccoon
## peeking over its top edge in the chosen skin. The tagline stays off it: the itch banner carries it (#45).
## The menu (#45) is START, CONTROLS and OPTIONS; Options holds the Raccoon's skin, Music On/Off and Back. A stray press
## no longer starts a Run: only choosing START does. Main moves the choice and acts on it, as on Pause.
## Attract's one crossing sits mid-screen, so the title keeps to the city blocks either side of it (#45): the logo in
## the top-left block, the menu in the bottom-right one, leaving the crossing and its four roads in view.

enum Page { MENU, OPTIONS }
enum Choice { START, CONTROLS, OPTIONS, SKIN, MUSIC, BACK }

const PAGES := {Page.MENU: [Choice.START, Choice.CONTROLS, Choice.OPTIONS], Page.OPTIONS: [Choice.SKIN, Choice.MUSIC, Choice.BACK]}
const LABELS := {Choice.START: "START", Choice.CONTROLS: "CONTROLS", Choice.OPTIONS: "OPTIONS", Choice.BACK: "BACK"}

const ROAD_CLEAR := 60.0  # px either side of the mid-screen lines that the title keeps clear: Attract's roads
const MARGIN := 24.0  # px from the screen edges
const BOARD := Vector2(560, 250)  # px: the striped board, at full size
const FRAME := 20.0  # px of stripes around the navy plate, at full size
const WORD_SIZE := 92  # at full size
const PEEK := 2.25  # the peeking Raccoon's scale over its texture, at full size
const PEEK_UP := 92.0  # px of it above the board, at full size
const ROW_SIZE := 26  # the menu's rows
const ROW_GAP := 46.0  # px between rows
const NOTE_SIZE := 16  # Options' line on the next skin

var page := Page.MENU
var row := 0
var music := true
var skin := Skins.GUARD
var best_stage := 0  # the furthest stage cleared: which skins Options offers
var _peek_tex: Texture2D  # the peeking Raccoon in the skin chosen, held here: a draw call doesn't keep its texture alive


func _init(music_on := true, skin_now := Skins.GUARD, best := 0) -> void:
	music = music_on
	skin = skin_now
	best_stage = best


## What the chosen row does.
func choice() -> Choice:
	return PAGES[page][row]


## Move the choice up (-1) or down (+1), stopping at the ends, as on Pause.
func move(by: int) -> void:
	row = clampi(row + by, 0, PAGES[page].size() - 1)
	queue_redraw()


func open_options() -> void:
	page = Page.OPTIONS
	row = 0
	queue_redraw()


## Back from Options, to OPTIONS on the menu.
func close_options() -> void:
	page = Page.MENU
	row = PAGES[Page.MENU].find(Choice.OPTIONS)
	queue_redraw()


## Step through the unlocked skins, round and round; returns the one now chosen.
func next_skin(by: int) -> StringName:
	var open := Skins.unlocked(best_stage)
	skin = open[posmod(maxi(open.find(skin), 0) + by, open.size())]
	queue_redraw()
	return skin


func set_music(on: bool) -> void:
	music = on
	queue_redraw()


## Row `i` of the page showing, as it reads.
func row_text(i: int) -> String:
	var c: Choice = PAGES[page][i]
	if c == Choice.SKIN:
		return "SKIN: < %s >" % Skins.NAMES[skin].to_upper()
	if c == Choice.MUSIC:
		return "MUSIC: %s" % ("ON" if music else "OFF")
	return LABELS[c]


func _draw() -> void:
	var v := view()
	var c := v / 2.0
	var block := Rect2(Vector2(MARGIN, MARGIN), c - Vector2(ROAD_CLEAR + MARGIN, ROAD_CLEAR + MARGIN))
	_logo(block)
	var corner := Rect2(c + Vector2(ROAD_CLEAR, ROAD_CLEAR), c - Vector2(ROAD_CLEAR + MARGIN, ROAD_CLEAR + MARGIN))
	_menu(corner)


## The menu, or Options, on a sign centred in `corner`.
func _menu(corner: Rect2) -> void:
	var rows: Array = PAGES[page]
	var widest := 0.0
	for i in rows.size():
		widest = maxf(widest, text_width(row_text(i), ROW_SIZE))
	var note := _note()
	var size := Vector2(maxf(widest + 100.0, 340.0), 40.0 + rows.size() * ROW_GAP + (28.0 if note != "" else 0.0) + 30.0)
	var box := Rect2(corner.get_center() - size / 2.0, size)
	frame(box)
	var mid := box.get_center().x
	var y := box.position.y + 30.0 + ROW_SIZE * Sign.CAP
	for i in rows.size():
		var s := row_text(i)
		if i == row:  # the chosen row: a white sign within the sign, in sign blue, as on Pause
			plate(Rect2(box.position.x + 30, y - ROW_SIZE * Sign.CAP - 10, box.size.x - 60, ROW_SIZE * Sign.CAP + 20), Color.WHITE)
			text(s, Vector2(mid, y), ROW_SIZE, Sign.BLUE, false, 0)
		else:
			text(s, Vector2(mid, y), ROW_SIZE, MUTED)
		y += ROW_GAP
	if note != "":
		text(note, Vector2(mid, y - 6.0), NOTE_SIZE, MUTED)
	hint(box, "%s: choose" % ("A" if pad else "ENTER"))


## Options' line on skins: what clearing unlocks the next one.
func _note() -> String:
	if page != Page.OPTIONS:
		return ""
	var open := Skins.unlocked(best_stage).size()
	if open >= Skins.ALL.size():
		return "EVERY SKIN UNLOCKED"
	return "CLEAR STAGE %d FOR A NEW SKIN" % Skins.unlock_stage(Skins.ALL[open])


## The logo, as big as fits `block` up to full size, the peeking Raccoon included, centred in it.
func _logo(block: Rect2) -> void:
	var s := minf(1.0, minf(block.size.x / BOARD.x, block.size.y / (BOARD.y + PEEK_UP)))
	var size := BOARD * s
	var board := Rect2(block.get_center() - Vector2(size.x / 2.0, (size.y - PEEK_UP * s) / 2.0), size)
	var raccoon := Art.RACCOON_FRONT.get_size() * PEEK * s
	var peek := Vector2(board.end.x - 190.0 * s, board.position.y - PEEK_UP * s)
	_peek_tex = Skins.texture(Art.RACCOON_FRONT, skin)
	texture(_peek_tex, Rect2(peek, raccoon))  # behind the board: only its head shows
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
		circle(paw, 10.0 * s, Skins.fur(skin))

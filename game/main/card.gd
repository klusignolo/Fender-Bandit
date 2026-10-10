class_name Card
extends Node2D
## Base for the flow screens (#29, #35, #42): road signs (Sign) over a dimmed board, set in Bungee. Lives on a
## CanvasLayer, so it ignores the camera. Screens draw only through these helpers, so measure() can lay one out
## without a canvas: it records where each sign, stripe and word would go, for the readability tests.

const DIM := Color(0, 0, 0, 0.45)
const INK := Sign.INK
const MUTED := Color(1, 1, 1, 0.6)
const HINT_SIZE := 16
const MIN_TEXT := 16  # px: the smallest words on any screen, readable at 1280×720 on the cabinet

## A word or line of text measure() found: its box, size, and whether it may sit off the signs.
class Words:
	var text: String
	var rect: Rect2
	var size: int
	var loose: bool

	func _init(s: String, r: Rect2, px: int, off_sign: bool) -> void:
		text = s
		rect = r
		size = px
		loose = off_sign


## Whether the last press came from a pad: the hints then name its button, else the keyboard key (#45). Main sets it.
static var pad := false

var signs: Array[Rect2] = []  # measure()'s findings
var stripes: Array[Rect2] = []
var words: Array[Words] = []

var _measuring := false
var _view := Vector2.ZERO


## Lays the card out at `view` without drawing, filling `signs`, `stripes` and `words`.
func measure(view: Vector2) -> void:
	signs.clear()
	stripes.clear()
	words.clear()
	_measuring = true
	_view = view
	_draw()
	_measuring = false


## Each screen draws itself here, through the helpers below. Declared so measure() can call it in an exported build.
func _draw() -> void:
	pass


## The screen's size: the viewport's, or measure()'s.
func view() -> Vector2:
	return _view if _measuring else get_viewport_rect().size


## Dims the board and draws a `size` sign in the middle of the screen; returns the sign's rect.
func panel(size: Vector2) -> Rect2:
	dim()
	var box := Rect2((view() - size) / 2.0, size)
	frame(box)
	return box


## Darkens the whole board under the card.
func dim() -> void:
	if not _measuring:
		draw_rect(Rect2(Vector2.ZERO, view()), DIM)


## A blue road sign filling `box`.
func frame(box: Rect2) -> void:
	signs.append(box)
	if not _measuring:
		Sign.panel(self, box)


## Construction stripes filling `box`: Raccoon moments only.
func stripe(box: Rect2) -> void:
	stripes.append(box)
	if not _measuring:
		Sign.stripes(self, box)


## The small prompt in the bottom-right corner of `box`, inside its rule, e.g. "J: skip".
func hint(box: Rect2, s: String) -> void:
	var inner := Sign.inner(box)
	text_at(s, inner.end - Vector2(text_width(s, HINT_SIZE) + 10, 10), HINT_SIZE, MUTED)


## Outlined text with its baseline centred on `centre`. A `loose` line may sit off the signs.
func text(s: String, centre: Vector2, size: int, colour := Color.WHITE, loose := false, outline := Sign.OUTLINE) -> void:
	text_at(s, centre - Vector2(text_width(s, size) / 2.0, 0), size, colour, loose, outline)


## Outlined text starting at `at`, on its baseline.
func text_at(s: String, at: Vector2, size: int, colour := Color.WHITE, loose := false, outline := Sign.OUTLINE) -> void:
	words.append(Words.new(s, Sign.text_rect(s, at, size), size, loose))
	if not _measuring:
		Sign.text(self, s, at, size, colour, outline)


func text_width(s: String, size: int) -> float:
	return Sign.width(s, size)


## A filled rect, e.g. an initials slot's underline.
func bar(r: Rect2, colour: Color) -> void:
	if not _measuring:
		draw_rect(r, colour)


## A plain rounded plate, e.g. the chosen row of a menu.
func plate(r: Rect2, colour: Color) -> void:
	if not _measuring:
		Sign.plate(self, r, colour)


func circle(centre: Vector2, radius: float, colour: Color) -> void:
	if not _measuring:
		draw_circle(centre, radius, colour)


func line(from: Vector2, to: Vector2, colour: Color, width: float) -> void:
	if not _measuring:
		draw_line(from, to, colour, width)


func texture(tex: Texture2D, r: Rect2) -> void:
	if not _measuring:
		draw_texture_rect(tex, r, false)


## Whether a blink of `period` seconds is lit `clock` seconds in: on for the first two thirds of each.
static func blink(clock: float, period: float) -> bool:
	return fmod(clock, period) < period * 2.0 / 3.0


## The key that confirms a screen, for its hint: A on a pad, else Switch's first keyboard key. Hints name a key,
## not the Switch, so a keyboard player needn't know which key Switch is (#45).
static func confirm_key() -> String:
	return "A" if pad else ControlsCard.keys(&"switch").get_slice(" / ", 0)

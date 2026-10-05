class_name Card
extends Node2D
## Base for the greybox flow screens (#29, #35): a dimmed board under a sign_blue panel, with outlined white text.
## Lives on a CanvasLayer, so it ignores the camera. The art pass (#42) restyles them as road signs.

const DIM := Color(0, 0, 0, 0.45)
const PANEL := Color("#1F5FAF", 0.95)  # sign_blue from docs/sprites.md
const INK := Color("#1B2340")
const MUTED := Color(1, 1, 1, 0.55)
const OUTLINE := 4  # px of INK around the text
const HINT_SIZE := 16


## Dims the board and draws a `size` panel in the middle of the screen; returns the panel's rect.
func panel(size: Vector2) -> Rect2:
	dim()
	var box := Rect2((get_viewport_rect().size - size) / 2.0, size)
	frame(box)
	return box


## Darkens the whole board under the card.
func dim() -> void:
	draw_rect(get_viewport_rect(), DIM)


## A sign_blue panel with a white border, filling `box`.
func frame(box: Rect2) -> void:
	draw_rect(box, PANEL)
	draw_rect(box, Color.WHITE, false, 3.0)


## The small prompt in the bottom-right corner of `box`, e.g. "SWITCH: skip".
func hint(box: Rect2, s: String) -> void:
	text_at(s, box.end - Vector2(text_width(s, HINT_SIZE) + 16, 14), HINT_SIZE)


## Outlined text with its baseline centred on `centre`.
func text(s: String, centre: Vector2, size: int, colour := Color.WHITE) -> void:
	text_at(s, centre - Vector2(text_width(s, size) / 2.0, 0), size, colour)


## Outlined text starting at `at`, on its baseline.
func text_at(s: String, at: Vector2, size: int, colour := Color.WHITE) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, OUTLINE, INK)
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


func text_width(s: String, size: int) -> float:
	return ThemeDB.fallback_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Whether a blink of `period` seconds is lit `clock` seconds in: on for the first two thirds of each.
static func blink(clock: float, period: float) -> bool:
	return fmod(clock, period) < period * 2.0 / 3.0

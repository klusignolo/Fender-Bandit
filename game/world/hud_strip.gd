class_name HudStrip
extends Node2D
## The HUD strip along the top of the screen (#28, #19 story 73): stage and score on the left, the Jam
## meter in the middle, Combo and its multiplier on the right. Greybox drawing on a sign_blue band.
## Lives on a CanvasLayer, so it ignores the camera.

const HEIGHT := 66.0  # px down from the top: room for the Jam meter and its caption
const SIDE := 24.0  # px in from each screen edge to the text
const TEXT_SIZE := 24
const BAND := Color("#1F5FAF", 0.85)  # sign_blue from docs/sprites.md, see-through a little
const INK := Color("#1B2340")

var run: Run


func _init(r: Run, t: Traffic) -> void:
	run = r
	add_child(JamMeter.new(t))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := get_viewport_rect().size.x
	draw_rect(Rect2(0, 0, w, HEIGHT), BAND)
	var y := HEIGHT / 2.0 + TEXT_SIZE / 3.0
	_text("STAGE %d    SCORE %d" % [run.stage, run.score], Vector2(SIDE, y), false)
	_text("COMBO %d  ×%d" % [run.combo, run.multiplier()], Vector2(w - SIDE, y), true)


func _text(s: String, at: Vector2, right: bool) -> void:
	var font := ThemeDB.fallback_font
	if right:
		at.x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, 4, INK)
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, Color.WHITE)

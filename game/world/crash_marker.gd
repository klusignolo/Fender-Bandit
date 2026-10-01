class_name CrashMarker
extends Node2D
## A plain "CRASH!" where a Crash happened, rising and fading. Greybox: the juice pass (#19 story 47)
## replaces it with the starburst, flying bits and shake.

const LIFE := 1.2  # seconds on screen
const RISE := 30.0  # px it drifts up over its life
const SIZE := 28
const COLOR := Color("#E8322B")  # signal_red, from the palette in docs/sprites.md

var _age := 0.0


func _init(at: Vector2) -> void:
	position = at
	z_index = 10


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var k := _age / LIFE
	var text := "CRASH!"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	var at := Vector2(-w / 2.0, -RISE * k)
	var col := Color(COLOR, 1.0 - k * k)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, 6, Color(0, 0, 0, col.a))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, col)

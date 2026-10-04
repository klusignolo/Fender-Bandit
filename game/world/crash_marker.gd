class_name CrashMarker
extends Node2D
## A comic starburst with one word where a Crash happened, popping in, rising and fading (first-pass sprite, #39).
## The juice pass (#43) adds the flying bits, smoke, freeze and shake.

const LIFE := 1.2  # seconds on screen
const RISE := 30.0  # on-screen px it drifts up over its life
const WIDE := 110.0  # on-screen px across, at any zoom
const POP := 0.12  # seconds it takes to pop up to full size
const SIZE := 22  # on-screen px of the word, at most...
const FILL := 0.6  # ...and at most this share of the burst's width, so a long word stays inside it
## The burst words (docs/sprites.md), in ink: never in signal colours.
const WORDS: Array[String] = ["KRUNCH!", "BONK!", "SKRRT-BAM!", "WHAM!", "KA-CHUNK!"]

var word: String
var _age := 0.0


func _init(at: Vector2) -> void:
	position = at
	z_as_relative = false
	z_index = Art.Z_BURST
	word = WORDS[posmod(hash(Vector2i(at.round())), WORDS.size())]  # the same Crash always says the same word


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var per_px := 1.0 / (cam.zoom.x if cam else 1.0)  # world px per on-screen px
	var k := _age / LIFE
	var alpha := 1.0 - k * k
	var tex := Art.CRASH_BURST
	var pop := minf(_age / POP, 1.0)
	var size := tex.get_size() * WIDE * per_px * (0.6 + 0.4 * pop) / tex.get_size().x
	var centre := Vector2(0.0, -RISE * k * per_px)
	draw_texture_rect(tex, Rect2(centre - size / 2.0, size), false, Color(1, 1, 1, alpha))
	var font := ThemeDB.fallback_font
	var px := SIZE * per_px * (0.6 + 0.4 * pop)
	var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px)).x
	if w > size.x * FILL:
		px *= size.x * FILL / w
		w = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px)).x
	draw_string(font, centre + Vector2(-w / 2.0, px * 0.35), word, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px), Color(Art.INK, alpha))

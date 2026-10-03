class_name TallyCard
extends Node2D
## The Tally card (#29, #19 stories 59–60): after a stage's drain, over the frozen board, it shows the stage
## cleared, the cars through, the score gained and what's new next stage. It's done after TALLY_TIME, or on A
## (Switch) once TALLY_LOCK has gone by. Greybox drawing; lives on a CanvasLayer, so it ignores the camera.

signal done

const WIDTH := 460.0
const GAP := 22.0  # px between lines
const DIM := Color(0, 0, 0, 0.45)
const PANEL := Color("#1F5FAF", 0.95)  # sign_blue from docs/sprites.md
const INK := Color("#1B2340")

var _lines: Array[Array] = []  # [text, font size]
var _shown := 0.0


func _init(stage: int, cars_through: int, score_gained: int, news: PackedStringArray) -> void:
	_lines.append(["STAGE %d CLEARED" % stage, 34])
	_lines.append(["Cars through   %d" % cars_through, 24])
	_lines.append(["Score   +%d" % score_gained, 24])
	for n in news:
		_lines.append(["NEW: %s!" % n, 28])


func _physics_process(delta: float) -> void:  # in ticks, like the simulation, so a seeded run repeats exactly
	_shown += delta
	if _shown >= Tuning.TALLY_TIME or (_shown >= Tuning.TALLY_LOCK and Input.is_action_just_pressed(&"switch")):
		set_physics_process(false)
		done.emit()


func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), DIM)
	var h := 70.0
	for l in _lines:
		h += l[1] + GAP
	var size := Vector2(WIDTH, h)
	var box := Rect2((view - size) / 2.0, size)
	draw_rect(box, PANEL)
	draw_rect(box, Color.WHITE, false, 3.0)
	var y := box.position.y + 56.0
	for l in _lines:
		_text(l[0], Vector2(view.x / 2.0, y), l[1])
		y += l[1] + GAP
	_text("A: skip", box.end - Vector2(50, 14), 16)


func _text(s: String, centre: Vector2, size: int) -> void:
	var font := ThemeDB.fallback_font
	var at := centre - Vector2(font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0, 0)
	draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, INK)
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)

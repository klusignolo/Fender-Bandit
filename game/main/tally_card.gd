class_name TallyCard
extends Card
## The Tally card (#29, #19 stories 59–60): after a stage's drain, over the frozen board, it shows the stage
## cleared, the cars through, the score gained and what's new next stage. It's done after TALLY_TIME, or on A
## (Switch) once TALLY_LOCK has gone by.

signal done

const WIDTH := 460.0
const GAP := 22.0  # px between lines

var _lines: Array[Array] = []  # [text, font size]
var _shown := 0.0
var _skip := false  # A was pressed since the last tick


func _init(stage: int, cars_through: int, score_gained: int, news: PackedStringArray) -> void:
	_lines.append(["STAGE %d CLEARED" % stage, 34])
	_lines.append(["Cars through   %d" % cars_through, 24])
	_lines.append(["Score   +%d" % score_gained, 24])
	for n in news:
		_lines.append(["NEW: %s!" % n, 28])


func _physics_process(delta: float) -> void:  # in ticks, like the simulation, so a seeded run repeats exactly
	_shown += delta
	if _shown >= Tuning.TALLY_TIME or (_shown >= Tuning.TALLY_LOCK and _skip):
		set_physics_process(false)
		done.emit()
	_skip = false


## A as an event, not polled, so the press that resumes from Pause (which this sat out, paused) can't skip it (#35).
func _unhandled_input(event: InputEvent) -> void:
	_skip = _skip or (event.is_action_pressed(&"switch") and not event.is_echo())


func _draw() -> void:
	var h := 70.0
	for l in _lines:
		h += l[1] + GAP
	var box := panel(Vector2(WIDTH, h))
	var y := box.position.y + 56.0
	for l in _lines:
		text(l[0], Vector2(box.get_center().x, y), l[1])
		y += l[1] + GAP
	hint(box, "SWITCH: skip")

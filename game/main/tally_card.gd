class_name TallyCard
extends Card
## The Tally card (#29, #42, #19 stories 59–60): after a stage's drain, over the frozen board, it shows the stage
## cleared, the cars through, the score gained and what's new next stage. It's done after TALLY_TIME, or on A
## (Switch) once TALLY_LOCK has gone by.

signal done

const WIDTH := 600.0
const GAP := 26.0  # px between lines
const BADGE_PAD := 10.0  # px round a NEW line, to its navy plate's edge...
const BADGE_CAP := 44.0  # ...and px of striped barricade cap at each end

var _lines: Array[Array] = []  # [text, font size, whether it's a NEW badge]
var _shown := 0.0
var _skip := false  # A was pressed since the last tick


func _init(stage: int, cars_through: int, score_gained: int, news: PackedStringArray) -> void:
	_lines.append(["STAGE %d CLEARED" % stage, 34, false])
	_lines.append(["Cars through   %d" % cars_through, 24, false])
	_lines.append(["Score   +%d" % score_gained, 24, false])
	for n in news:
		_lines.append(["NEW: %s!" % n, 24, true])


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
	var h := 76.0
	for l in _lines:
		h += l[1] + GAP
	var box := panel(Vector2(WIDTH, h))
	var mid := box.get_center().x
	var y := box.position.y + 58.0
	for l in _lines:
		var s: String = l[0]
		if l[2]:  # a Raccoon moment: the "NEW: …" badge in construction stripes
			var w := text_width(s, l[1]) + 2.0 * (BADGE_PAD + BADGE_CAP)
			var badge := Rect2(mid - w / 2.0, y - l[1] * Sign.CAP - BADGE_PAD, w, l[1] * Sign.CAP + 2.0 * BADGE_PAD)
			stripe(badge)
			bar(badge.grow_individual(-BADGE_CAP, -3.0, -BADGE_CAP, -3.0), INK)  # square, so the caps end clean
		text(s, Vector2(mid, y), l[1])
		y += l[1] + GAP
	hint(box, "SWITCH: skip")

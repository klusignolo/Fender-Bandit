class_name ScoresScreen
extends Card
## The High-score table (#36, #42, #19 stories 3 and 16): rank, initials and score for the top ScoreTable.SIZE, empty
## places as dashes. After a Run it shows over the frozen board with the new entry flashing, and A skips it once
## Flow's lock is over. In Attract it takes turns with the title, over the autopilot's Run.

const SIZE := Vector2(460, 540)
const ROW := 38.0  # px between rows
const FLASH := 0.5  # seconds per flash of the new entry: on for the first two thirds

var _entries: Array[Dictionary]
var _new := -1  # the new entry's rank, or -1
var _attract := false
var _clock := 0.0  # seconds shown


## `new_rank` flashes that row; `attract` shows the title's prompt in place of the hint.
func _init(entries: Array[Dictionary], new_rank := -1, attract := false) -> void:
	_entries = entries.duplicate(true)
	_new = new_rank
	_attract = attract


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var box := panel(SIZE)
	var mid := box.get_center().x
	text("HIGH SCORES", Vector2(mid, box.position.y + 62), 40)
	var y := box.position.y + 120
	var flash_on := blink(_clock, FLASH)
	for i in ScoreTable.SIZE:
		var rank := "%d." % (i + 1)
		text_at(rank, Vector2(box.position.x + 90 - text_width(rank, 28), y), 28)
		if i < _entries.size():
			if i != _new or flash_on:
				text_at(_entries[i].initials, Vector2(box.position.x + 120, y), 28)
				var score := str(_entries[i].score)
				text_at(score, Vector2(box.end.x - 60 - text_width(score, 28), y), 28)
		else:
			text_at("---", Vector2(box.position.x + 120, y), 28, MUTED)
		y += ROW
	if not _attract:
		hint(box, "SWITCH: continue")
	elif blink(_clock, TitleScreen.BLINK):
		text("PRESS ANY BUTTON", Vector2(mid, minf(box.end.y + 60, view().y - 20)), 40, Color.WHITE, true)

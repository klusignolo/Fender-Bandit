class_name InitialsScreen
extends Card
## Initials entry (#36, #42, #19 stories 14–15), over the frozen Gridlock board: the score, its place in the table and
## three letters, the slot being entered blinking. It feeds InitialsEntry the stick each frame; Main passes on A
## (confirm()) once Flow's lock is over. `entered` fires once the last slot is done. If nobody finishes, Flow moves
## on after INITIALS_TIME and Main saves InitialsEntry.DEFAULT.

signal entered
signal blip(sound: StringName)  # ui_move as a letter or slot moves, ui_confirm as a letter is set (#37)

const SIZE := Vector2(560, 400)
const LETTER_SIZE := 72
const SPACING := 96.0  # px between letters
const BLINK := 0.5  # seconds per blink of the slot being entered: on for the first two thirds

var entry: InitialsEntry

var _score := 0
var _rank := 0
var _clock := 0.0  # seconds shown
var _sent := false


func _init(e: InitialsEntry, score: int, rank: int) -> void:
	entry = e
	_score = score
	_rank = rank


## A: the next slot, or done.
func confirm() -> void:
	_blip_on(entry.next)
	_check()


func _process(delta: float) -> void:
	_clock += delta
	_blip_on(entry.step.bind(delta, _dir(&"move_down", &"move_up"), _dir(&"move_left", &"move_right")))
	_check()
	queue_redraw()


## Call `change` on the entry, and blip for what it did: a letter set (the slot moved on, or the last one done)
## confirms; a letter cycled or a step back moves.
func _blip_on(change: Callable) -> void:
	var slot := entry.slot
	var letters := entry.letters.duplicate()
	var done := entry.done
	change.call()
	if entry.slot > slot or entry.done != done:
		blip.emit(&"ui_confirm")
	elif entry.slot < slot or entry.letters != letters:
		blip.emit(&"ui_move")


static func _dir(neg: StringName, pos: StringName) -> int:
	return int(Input.is_action_pressed(pos)) - int(Input.is_action_pressed(neg))


func _check() -> void:
	if entry.done and not _sent:
		_sent = true
		entered.emit()


func _draw() -> void:
	var box := panel(SIZE)
	var mid := box.get_center().x
	text("NEW HIGH SCORE!", Vector2(mid, box.position.y + 62), 40)
	text("#%d   %d" % [_rank + 1, _score], Vector2(mid, box.position.y + 112), 32)
	var left := ceili(maxf(Tuning.INITIALS_TIME - _clock, 0.0))
	var t := str(left)
	text_at(t, Vector2(box.end.x - 34 - text_width(t, 24), box.position.y + 48), 24, MUTED)
	var base := box.position.y + 250
	var blink_on := blink(_clock, BLINK)
	for i in InitialsEntry.SLOTS:
		var x := mid + (i - 1) * SPACING
		var current := i == entry.slot and not entry.done
		if not current or blink_on:
			text(InitialsEntry.ALPHABET[entry.letters[i]], Vector2(x, base), LETTER_SIZE)
		var line := Rect2(x - 32, base + 14, 64, 6)
		bar(line, Color.WHITE if current else MUTED)
	text("UP/DOWN: letter   RIGHT: next   LEFT: back", Vector2(mid, box.position.y + 320), 18)
	hint(box, "SWITCH: next")

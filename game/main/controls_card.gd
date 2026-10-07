class_name ControlsCard
extends Card
## The controls card (#35, #42, #19 stories 4–7), between Attract and the Run: the goal, then the pad by position
## (the cabinet's button grid, #4, each bound button wearing its letter) or the keyboard keys. Flow closes it on A,
## or after CONTROLS_TIME.

const SIZE := Vector2(760, 500)
const GOAL: Array[String] = ["Keep the traffic flowing.", "Don't let the Jam fill up!"]
const BUTTON_R := 22.0
const BUTTON_GAP := 92.0  # px between button centres, room for a job under each
## The cabinet's 8 face buttons, by grid position (column, row), as both stations share them (#4).
const GRID: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)]
## What the game's buttons do, by grid position: A top-left, X top-right, Y middle-left. The rest stay unbound.
const JOBS := {Vector2i(0, 0): "SWITCH", Vector2i(2, 0): "DASH", Vector2i(0, 1): "TOW"}
## The letter on each bound button: the pad's names for them (#10, #17).
const LETTERS := {Vector2i(0, 0): "A", Vector2i(2, 0): "X", Vector2i(0, 1): "Y"}
const LETTER_SIZE := 22
const BUTTON := Color("#E8ECF2")
const IDLE_BUTTON := Color(1, 1, 1, 0.18)

var _pad := false


func _init(pad: bool) -> void:
	_pad = pad


## The keyboard keys bound to `action`, as "J / Z", in InputMap order.
static func keys(action: StringName) -> String:
	var names: PackedStringArray = []
	for e in InputMap.action_get_events(action):
		var k := e as InputEventKey
		if k != null:
			names.append(OS.get_keycode_string(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode))
	return " / ".join(names)


func _draw() -> void:
	var box := panel(SIZE)
	var mid := box.get_center().x
	text("HOW TO PLAY", Vector2(mid, box.position.y + 58), 36)
	for i in GOAL.size():
		text(GOAL[i], Vector2(mid, box.position.y + 104 + i * 32), 22)
	if _pad:
		_draw_pad(box)
	else:
		_draw_keys(box)
	hint(box, "SWITCH: start")


func _draw_pad(box: Rect2) -> void:
	var top := box.position + Vector2(0, 186)
	# The joystick, on the left.
	var stick := Vector2(box.position.x + 150, top.y + BUTTON_GAP)
	circle(stick, 44.0, IDLE_BUTTON)
	line(stick, stick - Vector2(0, 50), BUTTON, 8.0)
	circle(stick - Vector2(0, 54), 21.0, INK)
	circle(stick - Vector2(0, 54), 18.0, BUTTON)
	text("MOVE", stick + Vector2(0, 80), 22)
	# The button grid, on the right, each bound button's letter on it and its job under it.
	var grid := Vector2(box.get_center().x + 10, top.y)
	for at in GRID:
		var c := grid + Vector2(at) * BUTTON_GAP
		var job: String = JOBS.get(at, "")
		if job == "":
			circle(c, BUTTON_R, IDLE_BUTTON)
			continue
		circle(c, BUTTON_R + 3.0, INK)
		circle(c, BUTTON_R, BUTTON)
		text(LETTERS[at], Vector2(c.x, Sign.baseline(c.y, LETTER_SIZE)), LETTER_SIZE, INK, false, 0)
		text(job, c + Vector2(0, BUTTON_R + 24), 18)
	text("START: pause", Vector2(box.position.x + 150, box.end.y - 34), 20)


func _draw_keys(box: Rect2) -> void:
	var rows := [["MOVE", "WASD / Arrows"], ["SWITCH", keys(&"switch")], ["DASH", keys(&"dash")],
		["TOW", keys(&"tow")], ["PAUSE", keys(&"pause")]]
	var y := box.position.y + 192
	for r: Array in rows:
		text_at(r[0], Vector2(box.position.x + 110, y), 24)
		text_at(r[1], Vector2(box.position.x + 300, y), 24)
		y += 50

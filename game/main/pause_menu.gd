class_name PauseMenu
extends Card
## Pause (#35, #19 story 9), over the frozen Run: Resume or Quit to title. Main moves the choice and acts on
## it. There's no quit-to-desktop: the cabinet launcher owns quitting. Music On/Off joins it with the music (#37).

enum Row { RESUME, QUIT }

const ROWS := ["RESUME", "QUIT TO TITLE"]
const SIZE := Vector2(440, 260)

var row := Row.RESUME


## Move the choice up (-1) or down (+1), stopping at the ends: a held stick can't spin it.
func move(by: int) -> void:
	row = clampi(row + by, 0, ROWS.size() - 1) as Row
	queue_redraw()


func _draw() -> void:
	var box := panel(SIZE)
	var mid := box.get_center().x
	text("PAUSED", Vector2(mid, box.position.y + 58), 40)
	for i in ROWS.size():
		var y := box.position.y + 125 + i * 50
		var s: String = ROWS[i]
		text(("> %s <" % s) if i == row else s, Vector2(mid, y), 28, Color.WHITE if i == row else MUTED)
	text("SWITCH: choose   START: resume", Vector2(mid, box.end.y - 18), 16)

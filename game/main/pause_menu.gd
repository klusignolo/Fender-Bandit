class_name PauseMenu
extends Card
## Pause (#35, #19 story 9), over the frozen Run: Resume, Music On/Off (#38, story 78) or Quit to title. Main moves
## the choice and acts on it; Switch flips the Music row. There's no quit-to-desktop: the cabinet launcher owns
## quitting.

enum Row { RESUME, MUSIC, QUIT }

const ROWS := ["RESUME", "MUSIC", "QUIT TO TITLE"]
const SIZE := Vector2(440, 310)

var row := Row.RESUME
var music := true  # what the Music row shows


func _init(music_on: bool) -> void:
	music = music_on


## Move the choice up (-1) or down (+1), stopping at the ends: a held stick can't spin it.
func move(by: int) -> void:
	row = clampi(row + by, 0, ROWS.size() - 1) as Row
	queue_redraw()


func set_music(on: bool) -> void:
	music = on
	queue_redraw()


func row_text(r: Row) -> String:
	if r == Row.MUSIC:
		return "MUSIC: %s" % ("ON" if music else "OFF")
	return ROWS[r]


func _draw() -> void:
	var box := panel(SIZE)
	var mid := box.get_center().x
	text("PAUSED", Vector2(mid, box.position.y + 58), 40)
	for i in ROWS.size():
		var y := box.position.y + 125 + i * 50
		var s := row_text(i as Row)
		text(("> %s <" % s) if i == row else s, Vector2(mid, y), 28, Color.WHITE if i == row else MUTED)
	text("SWITCH: choose   START: resume", Vector2(mid, box.end.y - 18), 16)

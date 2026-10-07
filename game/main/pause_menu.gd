class_name PauseMenu
extends Card
## Pause (#35, #42, #19 story 9), over the frozen Run: Resume, Music On/Off (#38, story 78) or Quit to title. Main moves
## the choice and acts on it; Switch flips the Music row. Its hint names only the choose key: everyone knows how to move a menu. There's no quit-to-desktop: the cabinet launcher owns
## quitting.

enum Row { RESUME, MUSIC, QUIT }

const ROWS := ["RESUME", "MUSIC", "QUIT TO TITLE"]
const SIZE := Vector2(500, 330)

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
	text("PAUSED", Vector2(mid, box.position.y + 62), 40)
	for i in ROWS.size():
		var y := box.position.y + 132 + i * 52
		var s := row_text(i as Row)
		if i == row:  # the chosen row: a white sign within the sign, in sign blue
			plate(Rect2(box.position.x + 40, y - 36, box.size.x - 80, 48), Color.WHITE)
			text(s, Vector2(mid, y), 28, Sign.BLUE, false, 0)
		else:
			text(s, Vector2(mid, y), 28, MUTED)
	text("%s: choose" % confirm_key(), Vector2(mid, box.end.y - 22), HINT_SIZE, MUTED)

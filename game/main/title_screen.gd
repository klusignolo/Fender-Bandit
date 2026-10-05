class_name TitleScreen
extends Card
## The Attract title (#35, #19 story 1): the FENDER BANDIT logo and "Stop. Go. Oops." over the autopilot's
## Run, and a blinking "PRESS ANY BUTTON". The logo is greybox type until the art pass (#42).

const BLINK := 1.2  # seconds per blink of the prompt: on for the first two thirds

var _clock := 0.0  # seconds shown


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var box := Rect2(Vector2(view.x / 2.0 - 380, view.y * 0.18), Vector2(760, 190))
	frame(box)
	text("FENDER BANDIT", Vector2(box.get_center().x, box.position.y + 110), 84)
	text("Stop. Go. Oops.", Vector2(box.get_center().x, box.position.y + 160), 30)
	if blink(_clock, BLINK):
		text("PRESS ANY BUTTON", Vector2(view.x / 2.0, view.y * 0.8), 40)

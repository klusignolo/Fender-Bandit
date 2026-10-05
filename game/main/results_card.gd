class_name ResultsCard
extends Card
## The Run's results (#35, #42, #19 story 13), over the frozen Gridlock board: stage reached, cars through, best
## Combo, most Crashes in one stage, Dents and the final score. Flow moves on after RESULTS_TIME, or on A
## once RESULTS_LOCK has gone by.

const SIZE := Vector2(520, 440)

var _lines: Array[Array] = []  # [label, value]
var _score := 0


func _init(run: Run) -> void:
	_lines.append(["Stage reached", run.stage])
	_lines.append(["Cars through", run.cars_through])
	_lines.append(["Best Combo", run.top_combo])
	_lines.append(["Most crashes in a stage", run.most_crashes])
	_lines.append(["Dents", run.dents])
	_score = run.score


func _draw() -> void:
	var box := panel(SIZE)
	var mid := box.get_center().x
	text("THE DAMAGE", Vector2(mid, box.position.y + 58), 40)
	var y := box.position.y + 115
	for l in _lines:
		text_at(l[0], Vector2(box.position.x + 50, y), 24)
		var v := str(l[1])
		text_at(v, Vector2(box.end.x - 50 - text_width(v, 24), y), 24)
		y += 42
	text("SCORE  %d" % _score, Vector2(mid, y + 40), 40)
	hint(box, "SWITCH: continue")

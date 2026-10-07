class_name HudStrip
extends Node2D
## The HUD strip along the top of the screen (#28, #29, #42, #19 story 73): a blue road sign hung from the top edge,
## with stage and Quota on the left, the Jam meter in the middle, score, Combo and its multiplier on the right.
## Lives on a CanvasLayer, so it ignores the camera.

const HEIGHT := 66.0  # px down from the top: room for the Jam meter and its caption
const SIDE := 26.0  # px in from each screen edge to the text
const TEXT_SIZE := 22

var run: Run
var traffic: Traffic


func _init(r: Run, t: Traffic) -> void:
	run = r
	traffic = t
	add_child(JamMeter.new(t))
	t.stage_cleared.connect(queue_redraw)  # the board stops on that tick: show the met Quota under the Tally


static func left_text(stage: int, through: int, quota: int) -> String:
	return "STAGE %d   QUOTA %d/%d" % [stage, mini(through, quota), quota]


static func right_text(score: int, combo: int, multiplier: int) -> String:
	return "COMBO %d ×%d   SCORE %d" % [combo, multiplier, score]


## Where the left and right texts ink on a strip `w` px wide.
static func layout(w: float, left: String, right: String) -> Array[Rect2]:
	var y := _baseline()
	return [Sign.text_rect(left, Vector2(SIDE, y), TEXT_SIZE),
		Sign.text_rect(right, Vector2(w - SIDE - Sign.width(right, TEXT_SIZE), y), TEXT_SIZE)]


static func _baseline() -> float:
	return Sign.baseline((HEIGHT - Sign.INSET) / 2.0, TEXT_SIZE)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w := get_viewport_rect().size.x
	var over := Sign.RADIUS + Sign.INSET + Sign.RULE  # px the sign runs past the top and sides, so only its bottom edge shows
	Sign.panel(self, Rect2(-over, -over, w + 2.0 * over, HEIGHT + over))
	var left := left_text(run.stage, traffic.cars_through, traffic.quota)
	var right := right_text(run.score, run.combo, run.multiplier())
	var parts := layout(w, left, right)
	var y := _baseline()
	Sign.text(self, left, Vector2(parts[0].position.x, y), TEXT_SIZE)
	Sign.text(self, right, Vector2(parts[1].position.x, y), TEXT_SIZE)

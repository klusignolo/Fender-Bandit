class_name JamMeter
extends Node2D
## The Jam meter, top centre of the screen: filled in its Jam-level's colour (Heavy flashes), with the
## capacity lost to Dents as a hatched dark red tail and ticks where Busy and Heavy start. It sits in the
## middle of the HudStrip, which is its backing.

const WIDTH := 440.0  # px across, at 100 Jam capacity before Dents
const HEIGHT := 22.0
const TOP := 12.0
const TEXT_SIZE := 18
const FLASH_HZ := 4.0  # Heavy flashes this many times a second
# signal_green, signal_yellow, signal_red from the palette in docs/sprites.md
const LEVEL_COLORS := {
	Jam.Level.CLEAR: Color("#2ECC40"),
	Jam.Level.BUSY: Color("#F5C518"),
	Jam.Level.HEAVY: Color("#E8322B"),
	Jam.Level.GRIDLOCK: Color("#E8322B"),
}
const EMPTY := Color(0.16, 0.16, 0.16)
const DENTED := Color(0.3, 0.04, 0.04)
const HATCH := Color(0.6, 0.1, 0.1)
const INK := Color("#1B2340")

var traffic: Traffic
var _clock := 0.0


func _init(t: Traffic) -> void:
	traffic = t


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var jam := traffic.jam
	var x := (get_viewport_rect().size.x - WIDTH) / 2.0
	var cap_w := WIDTH * jam.capacity() / Tuning.JAM_CAP
	var level := jam.level()
	var col: Color = LEVEL_COLORS[level]
	if level == Jam.Level.HEAVY and fmod(_clock * FLASH_HZ, 1.0) < 0.5:
		col = col.lightened(0.45)
	draw_rect(Rect2(x, TOP, cap_w, HEIGHT), EMPTY)
	draw_rect(Rect2(x + cap_w, TOP, WIDTH - cap_w, HEIGHT), DENTED)
	var hx := x + cap_w + 4.0
	while hx < x + WIDTH:
		draw_line(Vector2(hx, TOP + HEIGHT), Vector2(minf(hx + HEIGHT, x + WIDTH), TOP), HATCH, 2.0)
		hx += 8.0
	draw_rect(Rect2(x, TOP, cap_w * jam.share(), HEIGHT), col)
	for f: float in [Tuning.JAM_BUSY, Tuning.JAM_HEAVY]:
		draw_line(Vector2(x + cap_w * f, TOP - 3.0), Vector2(x + cap_w * f, TOP + HEIGHT + 3.0), Color.WHITE, 2.0)
	var font := ThemeDB.fallback_font
	var at := Vector2(x, TOP + HEIGHT + 20.0)
	var text := "JAM  %s  %d%%" % [Jam.Level.keys()[level], int(100.0 * jam.share())]
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, 4, INK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, col)
	var dents := "Dents %d" % jam.dents
	var w := font.get_string_size(dents, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x
	draw_string_outline(font, at + Vector2(WIDTH - w, 0), dents, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, 4, INK)
	draw_string(font, at + Vector2(WIDTH - w, 0), dents, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE, Color(1, 0.5, 0.45))

class_name CrashMarker
extends Node2D
## A comic starburst with one word where a Crash happened, popping in, rising and fading (first-pass sprite, #39),
## over a ring of smoke puffs billowing out and the debris_bits flying off (#43). World adds the freeze and the shake.
## It runs on scaled delta, so it holds through the Crash's freeze and pops after it.

const LIFE := 1.2  # seconds on screen
const RISE := 30.0  # on-screen px it drifts up over its life
const WIDE := 110.0  # on-screen px across, at any zoom
const POP := 0.12  # seconds it takes to pop up to full size
const SIZE := 22  # on-screen px of the word, at most...
const FILL := 0.6  # ...and at most this share of the burst's width, so a long word stays inside it
## The burst words (docs/sprites.md), in ink: never in signal colours.
const WORDS: Array[String] = ["KRUNCH!", "BONK!", "SKRRT-BAM!", "WHAM!", "KA-CHUNK!"]
const PUFFS := 5  # smoke puffs billowing out from the Crash...
const PUFF_OUT := 66.0  # ...this many on-screen px, easing out past the burst...
const PUFF_SIZE := Vector2(30.0, 64.0)  # ...growing from and to these on-screen widths...
const PUFF_ALPHA := 0.85  # ...and fading from this
const BITS: Array[int] = [2, 2, 7]  # bumpers, hubcaps and glass shards (Art.DEBRIS) thrown off
const BITS_LIFE := 0.8  # seconds they fly...
const BITS_SPEED: Array[float] = [170.0, 380.0]  # ...leaving at this many on-screen px/s, so they clear the burst...
const BITS_DAMPING: Array[float] = [260.0, 420.0]  # ...and skidding to a stop at this many px/s²...
const BITS_SPIN := 600.0  # ...spinning up to this many degrees per second

var word: String
var _age := 0.0
var _phase := 0.0  # turns the ring of puffs, so neighbouring Crashes don't puff alike


func _init(at: Vector2) -> void:
	position = at
	z_as_relative = false
	z_index = Art.Z_BURST
	var h := hash(Vector2i(at.round()))  # the same Crash always says the same word and throws the same bits
	word = WORDS[posmod(h, WORDS.size())]
	_phase = posmod(h, 997) / 997.0
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.7, Color.WHITE)
	for i in Art.DEBRIS.size():
		var p := CPUParticles2D.new()
		p.texture = Art.DEBRIS[i]
		p.amount = BITS[i]
		p.lifetime = BITS_LIFE
		p.one_shot = true
		p.explosiveness = 1.0
		p.spread = 180.0
		p.gravity = Vector2.ZERO
		p.initial_velocity_min = BITS_SPEED[0]
		p.initial_velocity_max = BITS_SPEED[1]
		p.damping_min = BITS_DAMPING[0]
		p.damping_max = BITS_DAMPING[1]
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.angular_velocity_min = -BITS_SPIN
		p.angular_velocity_max = BITS_SPIN
		p.scale_amount_min = 0.45  # on-screen px: the bumper is 16 across
		p.scale_amount_max = 0.6
		p.color_ramp = fade
		p.local_coords = true  # its scale (_ready) sets the whole flight in on-screen px
		p.use_fixed_seed = true
		p.seed = posmod(h + i, 1 << 30)
		p.z_as_relative = false
		p.z_index = Art.Z_DEBRIS
		p.emitting = true
		add_child(p)


## The debris flies in on-screen px, like the burst, so it reads at any zoom.
func _ready() -> void:
	var cam := get_viewport().get_camera_2d()
	for p in get_children():
		(p as Node2D).scale = Vector2.ONE / (cam.zoom.x if cam else 1.0)


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var per_px := 1.0 / (cam.zoom.x if cam else 1.0)  # world px per on-screen px
	var k := _age / LIFE
	var alpha := 1.0 - k * k
	var out := 1.0 - (1.0 - k) * (1.0 - k)  # eases out
	for i in PUFFS:
		var w := lerpf(PUFF_SIZE.x, PUFF_SIZE.y, out) * per_px
		var at := Vector2.from_angle(TAU * (i + _phase) / PUFFS) * PUFF_OUT * out * per_px
		draw_texture_rect(Art.SMOKE_PUFF, Rect2(at - Vector2(w, w) / 2.0, Vector2(w, w)), false, Color(1, 1, 1, PUFF_ALPHA * (1.0 - k)))
	var tex := Art.CRASH_BURST
	var pop := minf(_age / POP, 1.0)
	var size := tex.get_size() * WIDE * per_px * (0.6 + 0.4 * pop) / tex.get_size().x
	var centre := Vector2(0.0, -RISE * k * per_px)
	draw_texture_rect(tex, Rect2(centre - size / 2.0, size), false, Color(1, 1, 1, alpha))
	var font := ThemeDB.fallback_font
	var px := SIZE * per_px * (0.6 + 0.4 * pop)
	var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px)).x
	if w > size.x * FILL:
		px *= size.x * FILL / w
		w = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px)).x
	draw_string(font, centre + Vector2(-w / 2.0, px * 0.35), word, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(px), Color(Art.INK, alpha))

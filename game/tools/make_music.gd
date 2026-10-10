extends "res://tools/make_sfx.gd"
## Writes the Theme and groove (#38) as WAVs to audio_src/ at the repo root, outside the Godot project, for
## tools/make_music.sh to encode to res://audio/music/*.ogg. Each is a one-bar intro, then an 8-bar loop the file ends
## on, so loop_offset is the intro's length (docs/audio.md "The music"). Procedural and seeded, like the SFX, with make_sfx.gd's building blocks: cartoon-caper
## jazz-funk in D minor (Dm Dm Gm Gm Dm Dm A7 A7), a walking bass, drums, brass stabs and a sneaky lead.
##   godot --headless --path game -s tools/make_music.gd [-- theme groove]
## Each tempo gives a whole number of samples per beat, so the loop is exactly 32 beats long.

const OUT_DIR := "../audio_src/"
const INTRO_BARS := 1
const LOOP_BARS := 8
const ROOTS: Array[int] = [38, 38, 43, 43, 38, 38, 45, 45]  # each bar's chord root, MIDI (D2, G2, A2)
const MAJOR: Array[int] = [45]  # roots whose chord has a major third (A7)

## The lead, one bar per row: [beat, MIDI note, beats held].
const MELODY: Array = [
	[[1.5, 62, 0.4], [2.0, 65, 0.4], [2.5, 69, 1.2]],
	[[0.5, 68, 0.4], [1.0, 67, 0.4], [1.5, 65, 0.4], [2.0, 62, 1.6]],
	[[1.5, 67, 0.4], [2.0, 70, 0.4], [2.5, 74, 1.2]],
	[[0.5, 73, 0.4], [1.0, 72, 0.4], [1.5, 70, 0.4], [2.0, 67, 1.6]],
	[[0.0, 74, 0.4], [0.5, 72, 0.4], [1.0, 69, 0.4], [1.5, 65, 0.4], [2.0, 69, 0.4], [2.5, 72, 1.2]],
	[[0.5, 74, 0.4], [1.0, 77, 2.0]],
	[[0.0, 73, 0.4], [0.5, 76, 0.4], [1.0, 79, 0.4], [1.5, 76, 0.4], [2.0, 73, 0.4], [2.5, 69, 0.4], [3.0, 67, 0.4], [3.5, 61, 0.4]],
	[[0.0, 62, 0.6]],
]

var bpm := 120.0
var loop_start := 0  # samples: where the loop begins (the intro's end)
var loop_len := 0  # samples


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://").path_join(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var names := OS.get_cmdline_user_args()
	for name: String in names if not names.is_empty() else PackedStringArray(["theme", "groove"]):
		rng.seed = hash([SEED, name])
		var b: PackedFloat32Array = _groove() if name == "groove" else _theme()
		_normalize(b, 0.85)
		var err := _save(dir.path_join(name + ".wav"), b)
		print("%s: %.1f BPM, loop_offset %.6fs, loop end %.6fs%s" % [name, bpm, loop_start / float(RATE),
				b.size() / float(RATE), "" if err == OK else " FAILED %d" % err])
	quit()


# --- the tracks --------------------------------------------------------------------

## The gameplay groove: 112 BPM, busy. A drum-fill intro, then four-on-the-floor funk with a walking bass, brass
## stabs on the chord changes and the lead on a muted square.
func _groove() -> PackedFloat32Array:
	var out := _start(112.0)
	var b0 := INTRO_BARS * 4.0
	# Intro: hats, and a snare pickup into the loop.
	for i in 8:
		_put(out, _hat(false), i * 0.5, 0.25)
	for beat in [2.0, 2.5, 3.0, 3.25, 3.5, 3.75]:
		_put(out, _snare(), beat, 0.35 + 0.1 * (beat - 2.0))
	for bar in LOOP_BARS:
		var at := b0 + bar * 4.0
		for beat in 4:
			_put(out, _kick(), at + beat, 0.9)
			if beat % 2 == 1:
				_put(out, _snare(), at + beat, 0.55)
		_put(out, _kick(), at + 2.5, 0.5)
		for i in 8:
			_put(out, _hat(i == 7), at + _swing(i * 0.5), 0.22 if i % 2 == 0 else 0.15)
		_walk(out, bar, at, 1, 0.5)
		for n: Array in MELODY[bar]:
			_put(out, _lead(n[1], n[2]), at + _swing(n[0]), 0.28)
		if bar in [2, 4, 6]:
			_stab(out, bar, at, 0.3, 0.32)
		if bar % 2 == 0:
			_stab(out, bar, at + 3.5, 0.15, 0.22)
	_stab(out, 7, b0 + 30.5, 0.2, 0.3)  # the turnaround, back to the top
	_stab(out, 7, b0 + 31.5, 0.2, 0.34)
	return out


## The Theme: 100 BPM, laid back. A bass pickup intro, then a half-time walk under finger snaps and brushed hats,
## the lead on vibes, the brass answering at the chord changes.
func _theme() -> PackedFloat32Array:
	var out := _start(100.0)
	var b0 := INTRO_BARS * 4.0
	for i in 4:  # the bass creeps up to the loop
		_put(out, _bass(ROOTS[0] - 4 + i, 0.9), i, 0.5 + 0.1 * i)
	_put(out, _snap(), 1.0, 0.3)
	_put(out, _snap(), 3.0, 0.3)
	for bar in LOOP_BARS:
		var at := b0 + bar * 4.0
		_walk(out, bar, at, 2, 0.6)
		for beat in [1, 3]:
			_put(out, _snap(), at + beat, 0.35)
		for i in 4:
			_put(out, _hat(false), at + _swing(i + 0.5), 0.12)
		for n: Array in MELODY[bar]:
			_put(out, _vibes(n[1], n[2]), at + _swing(n[0]), 0.3)
		if bar % 2 == 0:
			_stab(out, bar, at + 3.5, 0.2, 0.2)
	_stab(out, 7, b0 + 31.0, 0.3, 0.3)
	return out


# --- arranging ---------------------------------------------------------------------

## An empty track at `tempo`: the intro, then the loop.
func _start(tempo: float) -> PackedFloat32Array:
	bpm = tempo
	var beat := roundi(RATE * 60.0 / bpm)
	loop_start = INTRO_BARS * 4 * beat
	loop_len = LOOP_BARS * 4 * beat
	var b := PackedFloat32Array()
	b.resize(loop_start + loop_len)
	return b


func _beats(beats: float) -> float:
	return beats * 60.0 / bpm


## A light swing: the off-beat eighths land late.
func _swing(beat: float) -> float:
	return beat + (0.08 if fmod(beat, 1.0) == 0.5 else 0.0)


## Mix `b` in at `beat`. Whatever runs past the file's end wraps to the loop's start, as it will sound when it loops.
func _put(out: PackedFloat32Array, b: PackedFloat32Array, beat: float, gain: float) -> void:
	var start := roundi(_beats(beat) * RATE)
	for i in b.size():
		var j := start + i
		if j >= out.size():
			j = loop_start + (j - loop_start) % loop_len
		out[j] += b[i] * gain


## The bass walks bar `bar` in `steps` steps (1: four quarters; 2: two halves): root, third, fifth, then the
## semitone under the next bar's root.
func _walk(out: PackedFloat32Array, bar: int, at: float, steps: int, gain: float) -> void:
	var root := ROOTS[bar]
	var next := ROOTS[(bar + 1) % ROOTS.size()]
	var third := root + (4 if root in MAJOR else 3)
	var line: Array[int] = [root, root + 7]
	if steps == 1:
		line = [root, third, root + 7, next - 1]
	for i in line.size():
		_put(out, _bass(line[i], steps * 0.9), at + i * steps, gain)


## A brass chord on bar `bar`'s chord, `beats` long.
func _stab(out: PackedFloat32Array, bar: int, beat: float, beats: float, gain: float) -> void:
	var root := ROOTS[bar] + 24
	for n in [root, root + (4 if ROOTS[bar] in MAJOR else 3), root + 7]:
		_put(out, _brass(_beats(beats) + 0.05, _hz(n)), beat, gain)


# --- the instruments ---------------------------------------------------------------

static func _hz(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## An upright bass pluck: a soft triangle and its sine, a quick thump, ringing `beats` long.
func _bass(midi: int, beats: float) -> PackedFloat32Array:
	var secs := _beats(beats)
	var b := _tone(secs, _hz(midi), 0.0, Wave.TRIANGLE)
	_mix(b, _tone(secs, _hz(midi), 0.0, Wave.SINE), 0.0, 0.8)
	b = _lowpass(b, func(t: float) -> float: return 300.0 + 1500.0 * exp(-t / 0.05))
	_env(b, 0.004, 0.45)
	_hold(b, 0.001, minf(0.05, secs * 0.3))
	return b


func _kick() -> PackedFloat32Array:
	var b := _tone(0.22, 130.0, 45.0, Wave.SINE, 0.25)
	_env(b, 0.001, 0.07)
	return b


func _snare() -> PackedFloat32Array:
	var b := _bandpass(_noise(0.18), 1900.0, 1900.0, 0.8)
	_env(b, 0.001, 0.05)
	var body := _tone(0.08, 210.0, 170.0, Wave.SINE)
	_env(body, 0.001, 0.025)
	_mix(b, body, 0.0, 0.7)
	return b


func _hat(open: bool) -> PackedFloat32Array:
	var b := _highpass(_noise(0.2 if open else 0.05), 7000.0)
	_env(b, 0.0005, 0.07 if open else 0.012)
	return b


func _snap() -> PackedFloat32Array:
	var b := _bandpass(_noise(0.06), 2600.0, 2600.0, 2.0)
	_env(b, 0.0005, 0.012)
	return b


## The groove's lead: a muted square, plucked short.
func _lead(midi: int, beats: float) -> PackedFloat32Array:
	var secs := _beats(beats)
	var b := _tone(secs, _hz(midi), 0.0, Wave.SQUARE, 1.0, 5.0, 0.004)
	b = _lowpass(b, func(t: float) -> float: return 900.0 + 2600.0 * exp(-t / 0.06))
	_env(b, 0.004, 0.25)
	_hold(b, 0.001, minf(0.04, secs * 0.3))
	return b


## The Theme's lead: a vibraphone, a sine and its bell partial, with a slow tremolo.
func _vibes(midi: int, beats: float) -> PackedFloat32Array:
	var secs := _beats(beats) + 0.4
	var b := _tone(secs, _hz(midi), 0.0, Wave.SINE)
	var bell := _tone(secs, _hz(midi) * 4.0, 0.0, Wave.SINE)
	_env(bell, 0.001, 0.05)
	_mix(b, bell, 0.0, 0.25)
	for i in b.size():
		b[i] *= 0.85 + 0.15 * sin(TAU * 5.5 * i / RATE)
	_env(b, 0.002, 0.6)
	_hold(b, 0.001, 0.1)
	return b


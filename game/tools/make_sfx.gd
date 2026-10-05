extends SceneTree
## Writes every SFX in docs/audio.md's sound list to res://audio/sfx/<name>.wav (#37). Procedural and seeded: each
## sound draws from its own RNG, seeded by SEED and its name, so a rebuild is byte-for-byte the same and changing one
## recipe leaves the others alone. Run it from the repo root, then let Godot import the files:
##   godot --headless --path game -s tools/make_sfx.gd
##   godot --headless --path game --import
## The sounds docs/audio.md lists as jsfxr (UI blips, Combo, Jam beeps, the Swell whistle, the bonk) are made here
## too, the jsfxr way: square and sine blips with pitch slides. The recipe for each is its function below.
## The import settings (PCM; Forward loop on tow_scrape) are kept in each .wav.import.

const RATE := 44100
const SEED := 37
const OUT := "res://audio/sfx/"

enum Wave { SINE, SQUARE, SAW, TRIANGLE }

var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var recipes: Dictionary[String, Callable] = {
		"switch_green": _relay.bind(1.0, 1.0),
		"switch_yellow": _relay.bind(0.82, 1.0),
		"light_red": _relay.bind(0.62, 0.0),
		"dash": _dash,
		"tow_grab": _clunk.bind(1.0),
		"tow_scrape": _scrape,
		"raccoon_hit": _bonk,
		"honk_1": _honk.bind([[0.0, 0.2]]),
		"honk_2": _honk.bind([[0.0, 0.55], [0.62, 0.2]]),
		"blow_red": _blow_red,
		"yield": _brake_squeal,
		"crash_1": _crash,
		"crash_2": _crash,
		"crash_3": _crash,
		"gridlock_scratch": _scratch,
		"gridlock_horns": _horns,
		"gridlock_shatter": _shatter,
		"combo_up": _arpeggio.bind([880.0, 1175.0, 1760.0], 0.05),
		"combo_break": _wah_wah,
		"jam_busy": _beeps.bind(880.0, 1, 0.16),
		"jam_heavy": _beeps.bind(1040.0, 2, 0.1),
		"swell": _whistle,
		"reveal": _reveal,
		"ui_move": _blip.bind(660.0, 720.0, 0.045),
		"ui_confirm": _arpeggio.bind([880.0, 1320.0], 0.06),
		"stinger": _ta_da,
	}
	for name in recipes:
		rng.seed = hash([SEED, name])
		var b: PackedFloat32Array = recipes[name].call()
		_fade_ends(b, name == "tow_scrape")
		_normalize(b, 0.9)
		var err := _save(OUT + name + ".wav", b)
		print("%s: %.2fs%s" % [name, b.size() / float(RATE), "" if err == OK else " FAILED %d" % err])
	quit()


# --- the sounds -------------------------------------------------------------------

## A relay clack: a bright tok and a click, then the contact bouncing. `pitch` scales it; `bright` 0 is the softer,
## muffled clack of a Light falling to red by itself.
func _relay(pitch: float, bright: float) -> PackedFloat32Array:
	var out := _silence(0.12)
	for hit: Array in [[0.0, 1.0], [0.017, 0.45]]:
		var tok := _tone(0.05, 2400.0 * pitch, 1900.0 * pitch, Wave.SINE)
		_env(tok, 0.0005, 0.008)
		var body := _tone(0.05, 900.0 * pitch, 780.0 * pitch, Wave.SQUARE)
		_env(body, 0.0005, 0.006)
		var click := _highpass(_noise(0.012), 3000.0)
		_env(click, 0.0, 0.002)
		_mix(out, tok, hit[0], hit[1])
		_mix(out, body, hit[0], 0.35 * hit[1])
		_mix(out, click, hit[0], (0.3 + 0.4 * bright) * hit[1])
	if bright < 0.5:
		out = _lowpass(out, 2200.0)
	return out


## A short whoosh: noise through a band sweeping up, swelling and falling away.
func _dash() -> PackedFloat32Array:
	var b := _bandpass(_noise(0.3), 500.0, 3200.0, 1.2)
	_swell_env(b, 0.07)
	return b


## A grab clunk: a dropping thump, a short metal ring and a click. `weight` lowers and lengthens it.
func _clunk(weight: float) -> PackedFloat32Array:
	var out := _silence(0.3 * weight)
	var thump := _tone(0.2 * weight, 150.0 / weight, 60.0 / weight, Wave.SINE)
	_env(thump, 0.002, 0.06 * weight)
	_mix(out, thump, 0.0, 1.0)
	for f in [520.0, 830.0, 1370.0]:
		var ring := _tone(0.25, f / weight * rng.randf_range(0.97, 1.03), f / weight, Wave.SINE)
		_env(ring, 0.001, 0.09)
		_mix(out, ring, 0.0, 0.18)
	var click := _lowpass(_noise(0.015), 2500.0)
	_env(click, 0.0, 0.004)
	_mix(out, click, 0.0, 0.5)
	return out


## A metal scrape that loops: rough noise in two narrow bands, its grit gated at random. One second, the end
## crossfaded into the start (_fade_ends) so the loop has no seam.
func _scrape() -> PackedFloat32Array:
	var secs := 1.25
	var b := _bandpass(_noise(secs), 2600.0, 2600.0, 4.0)
	_mix(b, _bandpass(_noise(secs), 4300.0, 4300.0, 6.0), 0.0, 0.6)
	var grit := 0.7
	for i in b.size():
		if i % 300 == 0:
			grit = rng.randf_range(0.45, 1.0)
		b[i] *= grit
	return b


## A cartoon bonk: a sine dropping fast, with a hollow triangle under it.
func _bonk() -> PackedFloat32Array:
	var out := _tone(0.32, 760.0, 170.0, Wave.SINE)
	_env(out, 0.001, 0.1)
	var hollow := _tone(0.32, 1140.0, 260.0, Wave.TRIANGLE)
	_env(hollow, 0.001, 0.05)
	_mix(out, hollow, 0.0, 0.35)
	var click := _noise(0.01)
	_env(click, 0.0, 0.002)
	_mix(out, click, 0.0, 0.4)
	return out


## A car horn: two saws a major third apart, muffled, sounding for each [start, length] in `beeps`.
func _honk(beeps: Array) -> PackedFloat32Array:
	var last: Array = beeps[-1]
	var out := _silence(last[0] + last[1] + 0.03)
	for beep: Array in beeps:
		var horn := _horn(beep[1], 420.0)
		_mix(out, horn, beep[0], 1.0)
	return out


func _horn(length: float, f: float) -> PackedFloat32Array:
	var h := _tone(length, f * 0.96, f, Wave.SAW, 0.02)
	_mix(h, _tone(length, f * 1.26 * 0.96, f * 1.26, Wave.SAW, 0.02), 0.0, 0.8)
	h = _lowpass(h, 1800.0)
	_hold(h, 0.01, 0.03)
	return h


## Blowing the red: an engine revving up under a tyre squeal.
func _blow_red() -> PackedFloat32Array:
	var secs := 1.0
	var engine := _tone(secs, 55.0, 150.0, Wave.SAW, 0.7)
	_mix(engine, _tone(secs, 27.5, 75.0, Wave.SQUARE, 0.7), 0.0, 0.5)
	for i in engine.size():
		engine[i] *= 0.75 + 0.25 * sin(TAU * 24.0 * i / RATE)  # the chug of the cylinders
	engine = _lowpass(engine, 900.0)
	_hold(engine, 0.05, 0.25)
	var squeal := _squeal(0.75, 1250.0, 1180.0, 9.0, 0.02)
	var out := _silence(secs)
	_mix(out, engine, 0.0, 0.8)
	_mix(out, squeal, 0.2, 0.45)
	return out


## A brake squeal: a high whine sagging a little, wavering, with grit.
func _brake_squeal() -> PackedFloat32Array:
	return _squeal(0.55, 2300.0, 2050.0, 7.0, 0.015)


func _squeal(length: float, f0: float, f1: float, vib_hz: float, vib: float) -> PackedFloat32Array:
	var s := _tone(length, f0, f1, Wave.SINE, 1.0, vib_hz, vib)
	_mix(s, _tone(length, f0 * 2.0, f1 * 2.0, Wave.SINE, 1.0, vib_hz, vib), 0.0, 0.25)
	_mix(s, _bandpass(_noise(length), f0, f1, 10.0), 0.0, 0.6)
	_hold(s, 0.03, 0.15)
	return s


## A cartoon crunch: a thump, crumpling grit, a clank, then glass tinkling down. Each of the three draws its own.
func _crash() -> PackedFloat32Array:
	var out := _silence(1.0)
	var thump := _tone(0.3, rng.randf_range(100.0, 130.0), 40.0, Wave.SINE)
	_env(thump, 0.002, 0.08)
	_mix(out, thump, 0.0, 1.0)
	var crunch := _lowpass(_noise(0.45), 3000.0, 700.0)
	var gate := 1.0
	for i in crunch.size():
		if i % rng.randi_range(300, 900) == 0:
			gate = rng.randf_range(0.3, 1.0)
		crunch[i] *= gate
	_env(crunch, 0.002, 0.14)
	_mix(out, crunch, 0.0, 0.9)
	for k in 3:
		var f := rng.randf_range(300.0, 900.0)
		var clank := _tone(0.3, f, f * 0.98, Wave.SINE)
		_env(clank, 0.001, 0.12)
		_mix(out, clank, rng.randf_range(0.0, 0.04), 0.25)
	_tinkle(out, rng.randi_range(10, 16), 0.06, 0.75, 0.25)
	return out


## Glass: `count` pings scattered from `from` to `to` seconds, thinning out.
func _tinkle(out: PackedFloat32Array, count: int, from: float, to: float, gain: float) -> void:
	for k in count:
		var r := rng.randf()
		var at := from + (to - from) * r * r
		var ping := _tone(0.12, rng.randf_range(3000.0, 8000.0), 0.0, Wave.SINE)
		_env(ping, 0.0005, rng.randf_range(0.02, 0.07))
		_mix(out, ping, at, gain * rng.randf_range(0.5, 1.0) * (1.0 - 0.6 * r))


## A record scratch: a band of noise and a zip dragged up fast, then back down slower.
func _scratch() -> PackedFloat32Array:
	var secs := 0.7
	var contour := func(t: float) -> float:
		if t < 0.18:
			return lerpf(300.0, 3200.0, t / 0.18)
		return lerpf(3200.0, 180.0, pow(minf((t - 0.18) / 0.45, 1.0), 0.6))
	var b := _bandpass(_noise(secs), contour, contour, 3.0)
	var zip := _silence(secs)
	var phase := 0.0
	for i in zip.size():
		phase = fmod(phase + contour.call(float(i) / RATE) / 6.0 / RATE, 1.0)
		zip[i] = _wave(Wave.SAW, phase)
	_mix(b, _lowpass(zip, 2500.0), 0.0, 0.5)
	_hold(b, 0.005, 0.08)
	return b


## Gridlock: a chorus of horns leaning on it, out of tune with each other.
func _horns() -> PackedFloat32Array:
	var out := _silence(2.3)
	for f in [330.0, 370.0, 415.0, 440.0, 494.0, 554.0]:
		var at := rng.randf_range(0.0, 0.3)
		_mix(out, _horn(2.2 - at, f * rng.randf_range(0.98, 1.02)), at, 0.3)
	return out


## Gridlock's big glass shatter: a thump, a hiss of breaking and a shower of pings.
func _shatter() -> PackedFloat32Array:
	var out := _silence(1.6)
	var thump := _tone(0.4, 90.0, 35.0, Wave.SINE)
	_env(thump, 0.002, 0.12)
	_mix(out, thump, 0.0, 0.9)
	var hiss := _highpass(_noise(0.9), 2500.0)
	_env(hiss, 0.001, 0.22)
	_mix(out, hiss, 0.0, 0.7)
	_tinkle(out, 45, 0.02, 1.4, 0.35)
	return out


## A jsfxr-style square blip on each note in `notes`, `step` seconds apart.
func _arpeggio(notes: Array, step: float) -> PackedFloat32Array:
	var out := _silence(step * notes.size() + 0.06)
	for k in notes.size():
		var n := _tone(step + 0.05, notes[k], notes[k], Wave.SQUARE)
		_env(n, 0.001, step * 0.6)
		_mix(out, n, k * step, 1.0)
	return _lowpass(out, 6000.0)


## A sad trombone: three notes sliding down, then a long wobbling one, each opening and closing its wah.
func _wah_wah() -> PackedFloat32Array:
	var notes := [[392.0, 0.24], [370.0, 0.24], [349.0, 0.24], [330.0, 0.7]]
	var out := _silence(1.5)
	var at := 0.0
	for k in notes.size():
		var f: float = notes[k][0]
		var length: float = notes[k][1]
		var last: bool = k == notes.size() - 1
		var n := _tone(length, f, f * (0.97 if last else 1.0), Wave.SAW, 1.0, 6.0 if last else 0.0, 0.03 if last else 0.0)
		var wah := func(t: float) -> float: return 400.0 + 1600.0 * sin(PI * minf(t / length, 1.0))
		n = _lowpass(n, wah)
		_hold(n, 0.02, 0.06)
		_mix(out, n, at, 1.0)
		at += length
	return out


## Warning beeps: `count` square beeps of `length` seconds.
func _beeps(f: float, count: int, length: float) -> PackedFloat32Array:
	var gap := 0.06
	var out := _silence(count * (length + gap))
	for k in count:
		var b := _tone(length, f, f, Wave.SQUARE)
		_mix(b, _tone(length, f * 2.0, f * 2.0, Wave.TRIANGLE), 0.0, 0.3)
		_hold(b, 0.003, 0.02)
		_mix(out, b, k * (length + gap), 1.0)
	return _lowpass(out, 5000.0)


## A traffic cop's pea whistle: a high tone trilled fast, with breath.
func _whistle() -> PackedFloat32Array:
	var secs := 0.45
	var b := _tone(secs, 2900.0, 2850.0, Wave.SINE, 1.0, 28.0, 0.06)
	_mix(b, _bandpass(_noise(secs), 3000.0, 3000.0, 3.0), 0.0, 0.25)
	_hold(b, 0.015, 0.06)
	return b


## A crossing attaching: a whoosh, then a construction "ka-chunk".
func _reveal() -> PackedFloat32Array:
	var out := _silence(1.15)
	var whoosh := _bandpass(_noise(0.6), 300.0, 2500.0, 1.0)
	_swell_env(whoosh, 0.3)
	_mix(out, whoosh, 0.0, 0.8)
	_mix(out, _clunk(0.8), 0.6, 0.7)
	_mix(out, _clunk(1.4), 0.76, 1.0)
	return out


## One jsfxr-style blip sliding from `f0` to `f1`.
func _blip(f0: float, f1: float, length: float) -> PackedFloat32Array:
	var b := _tone(length, f0, f1, Wave.SQUARE)
	_env(b, 0.001, length * 0.5)
	return _lowpass(b, 6000.0)


## Stage cleared: a brass "ta-da!", a short pickup then a held chord. A placeholder until #38's Lyria stinger.
func _ta_da() -> PackedFloat32Array:
	var out := _silence(1.9)
	_mix(out, _brass(0.13, 523.25), 0.0, 0.8)
	for f in [523.25, 659.25, 783.99, 1046.5]:
		_mix(out, _brass(1.6, f), 0.17, 0.4)
	return out


func _brass(length: float, f: float) -> PackedFloat32Array:
	var b := _tone(length, f * 0.98, f, Wave.SAW, 0.03, 5.5, 0.008)
	var bite := func(t: float) -> float: return 1400.0 + 2400.0 * exp(-t / 0.08)
	b = _lowpass(b, bite)
	_hold(b, 0.02, minf(0.3, length * 0.4))
	return b


# --- building blocks -------------------------------------------------------------

func _silence(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(roundi(seconds * RATE))
	return b


func _noise(seconds: float) -> PackedFloat32Array:
	var b := _silence(seconds)
	for i in b.size():
		b[i] = rng.randf_range(-1.0, 1.0)
	return b


func _wave(w: Wave, phase: float) -> float:
	match w:
		Wave.SQUARE:
			return 1.0 if phase < 0.5 else -1.0
		Wave.SAW:
			return 2.0 * phase - 1.0
		Wave.TRIANGLE:
			return 1.0 - 4.0 * absf(phase - 0.5)
	return sin(TAU * phase)


## A tone gliding from `f0` to `f1` Hz (exponentially, over `glide` of its length; 0 for f1 means f0), with
## vibrato of `vib` (a share of the pitch) at `vib_hz`.
func _tone(seconds: float, f0: float, f1: float, w: Wave, glide := 1.0, vib_hz := 0.0, vib := 0.0) -> PackedFloat32Array:
	var b := _silence(seconds)
	if f1 <= 0.0:
		f1 = f0
	var phase := 0.0
	var glide_n := maxf(glide * b.size(), 1.0)
	for i in b.size():
		var f := f0 * pow(f1 / f0, minf(i / glide_n, 1.0))
		f *= 1.0 + vib * sin(TAU * vib_hz * i / RATE)
		phase = fmod(phase + f / RATE, 1.0)
		b[i] = _wave(w, phase)
	return b


## A cutoff in Hz: a number, a glide from `fc` to `fc_end` across the buffer, or a Callable of seconds.
func _cutoff(fc: Variant, fc_end: Variant, i: int, n: int) -> float:
	if fc is Callable:
		return (fc as Callable).call(float(i) / RATE)
	if fc_end is float and fc_end > 0.0:
		return fc * pow(fc_end / fc, float(i) / maxi(n - 1, 1))
	return fc


func _lowpass(b: PackedFloat32Array, fc: Variant, fc_end: Variant = 0.0) -> PackedFloat32Array:
	var out := b.duplicate()
	var y := 0.0
	for i in b.size():
		var a := 1.0 - exp(-TAU * _cutoff(fc, fc_end, i, b.size()) / RATE)
		y += a * (b[i] - y)
		out[i] = y
	return out


func _highpass(b: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var low := _lowpass(b, fc)
	var out := b.duplicate()
	for i in b.size():
		out[i] = b[i] - low[i]
	return out


## A state-variable band-pass, its centre gliding from `fc0` to `fc1` (or following a Callable), at resonance `q`.
func _bandpass(b: PackedFloat32Array, fc0: Variant, fc1: Variant, q: float) -> PackedFloat32Array:
	var out := b.duplicate()
	var low := 0.0
	var band := 0.0
	var damp := 1.0 / q
	for i in b.size():
		var fc := _cutoff(fc0, fc1, i, b.size()) if fc0 is Callable or fc0 != fc1 else float(fc0)
		var f := 2.0 * sin(PI * minf(fc, RATE / 6.0) / RATE)
		low += f * band
		var high := b[i] - low - damp * band
		band += f * high
		out[i] = band
	return out


## A sharp attack over `attack` seconds, then an exponential decay with time constant `decay`.
func _env(b: PackedFloat32Array, attack: float, decay: float) -> void:
	var a := attack * RATE
	for i in b.size():
		var g := minf(i / a, 1.0) if a > 0.0 else 1.0
		b[i] *= g * exp(-maxf(i - a, 0.0) / (decay * RATE))


## Held: a fade in over `attack` and out over `release` seconds.
func _hold(b: PackedFloat32Array, attack: float, release: float) -> void:
	var n := b.size()
	for i in n:
		b[i] *= minf(minf(i / (attack * RATE), 1.0), minf((n - 1 - i) / (release * RATE), 1.0))


## Swells up to its peak at `peak` seconds, then falls away to the end.
func _swell_env(b: PackedFloat32Array, peak: float) -> void:
	var p := peak * RATE
	var n := b.size()
	for i in n:
		var g := i / p if i < p else 1.0 - (i - p) / (n - p)
		b[i] *= g * g


func _mix(into: PackedFloat32Array, b: PackedFloat32Array, at: float, gain: float) -> void:
	var start := roundi(at * RATE)
	for i in mini(b.size(), into.size() - start):
		into[start + i] += b[i] * gain


## A few ms of fade at each end, so no clip clicks. A loop instead keeps its first second, its end crossfaded in
## (equal power) under the start, so playing on from the last sample into the first is seamless.
func _fade_ends(b: PackedFloat32Array, loop: bool) -> void:
	if loop:
		var n := RATE  # one second
		var fade := b.size() - n
		for i in fade:
			var k := float(i) / fade
			b[i] = b[i] * sqrt(k) + b[n + i] * sqrt(1.0 - k)
		b.resize(n)
		return
	var edge := mini(roundi(0.003 * RATE), b.size() / 2)
	for i in edge:
		var k := float(i) / edge
		b[i] *= k
		b[b.size() - 1 - i] *= k


func _normalize(b: PackedFloat32Array, peak: float) -> void:
	var top := 0.0
	for v in b:
		top = maxf(top, absf(v))
	if top > 0.0:
		for i in b.size():
			b[i] *= peak / top


func _save(path: String, b: PackedFloat32Array) -> Error:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, clampi(roundi(b[i] * 32767.0), -32768, 32767))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s.save_to_wav(ProjectSettings.globalize_path(path))

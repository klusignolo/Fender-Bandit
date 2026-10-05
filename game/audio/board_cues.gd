class_name BoardCues
extends RefCounted
## What a stage's board sounds like (#37, docs/audio.md "Sound list"): it listens to the stage's Traffic, the Run and
## the Raccoon, and cues Audio by sound name. Audio keeps one per stage and drops it for the next; dropping it
## disconnects it. The reveal and Gridlock aren't board signals: Audio plays them itself.

signal cue(sound: StringName, pitch: float)
signal scrape(on: bool)  # the Tow scrape loops while Wreckage is towed

const GOLDEN := 0.618034
const CRASHES: Array[StringName] = [&"crash_1", &"crash_2", &"crash_3"]

var _level := Jam.Level.CLEAR  # the Jam-level last heard
var _rng := RandomNumberGenerator.new()  # Crash picks and pitches: its own, so it never shifts Traffic's draws


## `raccoon` is null where there's none, as in tests.
func _init(traffic: Traffic, run: Run, raccoon: Raccoon = null) -> void:
	traffic.light_changed.connect(_on_light_changed)
	traffic.honked.connect(_on_honked)
	traffic.blew_red.connect(_cue.bind(&"blow_red").unbind(1))
	traffic.yielded.connect(_cue.bind(&"yield").unbind(1))
	traffic.raccoon_hit.connect(_cue.bind(&"raccoon_hit").unbind(1))
	traffic.swell_flagged.connect(_cue.bind(&"swell").unbind(1))
	traffic.crashed.connect(_on_crashed)
	traffic.jam_level_changed.connect(_on_jam_level_changed)
	traffic.tow_grabbed.connect(_on_tow_grabbed)
	traffic.towed.connect(_on_towed)
	traffic.stage_cleared.connect(_cue.bind(&"stinger"))
	run.combo_stepped.connect(_cue.bind(&"combo_up").unbind(1))
	run.combo_broken.connect(_cue.bind(&"combo_break").unbind(1))
	if raccoon != null:
		raccoon.dashed.connect(_cue.bind(&"dash"))


func _cue(sound: StringName, pitch := 1.0) -> void:
	cue.emit(sound, pitch)


func _on_light_changed(light: Light) -> void:
	match light.state:
		Light.State.GREEN:
			_cue(&"switch_green")
		Light.State.YELLOW:
			_cue(&"switch_yellow")
		Light.State.RED:
			_cue(&"light_red")


## Each car keeps its own horn: a pitch from its id, within SFX_JITTER. Stepping ids by the golden ratio spreads
## neighbouring cars' horns far apart.
func _on_honked(car: Car) -> void:
	var spread := fposmod(car.id * GOLDEN, 1.0) * 2.0 - 1.0
	_cue(&"honk_2" if car.honks >= 2 else &"honk_1", 1.0 + Tuning.SFX_JITTER * spread)


func _on_crashed(_a: Car, _b: Car, _at: Vector2) -> void:
	_cue(CRASHES[_rng.randi_range(0, CRASHES.size() - 1)], 1.0 + _rng.randf_range(-Tuning.SFX_JITTER, Tuning.SFX_JITTER))


## A beep on each rise to Busy or Heavy; falling is quiet, and Gridlock is Audio's.
func _on_jam_level_changed(level: Jam.Level) -> void:
	if level > _level:
		if level == Jam.Level.BUSY:
			_cue(&"jam_busy")
		elif level == Jam.Level.HEAVY:
			_cue(&"jam_heavy")
	_level = level


func _on_tow_grabbed(_car: Car) -> void:
	_cue(&"tow_grab")
	scrape.emit(true)


func _on_towed(_car: Car, _off_road: bool) -> void:
	scrape.emit(false)

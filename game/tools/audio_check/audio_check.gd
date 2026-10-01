extends Node
## Throwaway week-1 audio check (#20). Answers two questions in a real browser:
## 1. Does a live pitch_scale change on a looping MP3 work in Sample mode?
## 2. Does the MP3 loop seam click?
## The loop is 120 BPM, 16 beats (8 s), looped by its import settings the way Lyria tracks will be.
## Its pad is seamless as PCM, so a click or gap at the seam comes from the MP3 itself.
## Remove this folder once the outcomes are recorded in docs/audio.md.

const JAM_LEVEL_NAMES: Array[String] = ["Clear", "Busy", "Heavy"]
const LOOP_SECONDS := 8.0
const MAIN := "res://main/main.tscn"

var _player: AudioStreamPlayer
var _label: Label
var _jam_level := 0
var _tween: Tween
var _started := false
var _elapsed := 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.stream = preload("res://tools/audio_check/loop_check.mp3")
	_player.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE
	add_child(_player)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 26)
	_label.position = Vector2(48, 40)
	add_child(_label)


func _process(delta: float) -> void:
	if _started:
		_elapsed += delta * _player.pitch_scale
	var seam_in := LOOP_SECONDS - fmod(_elapsed, LOOP_SECONDS)
	_label.text = "\n".join([
		"AUDIO CHECK  (week-1 smoke export, #20)",
		"",
		"Press Switch (J / Z / A) to start." if not _started else "Playing (Sample mode requested).",
		"pitch_scale: %.3f   target: %s %.2f" % [_player.pitch_scale, JAM_LEVEL_NAMES[_jam_level], Tuning.MUSIC_PITCH[_jam_level]],
		"Loop seam in ~%.1f s (every %d s, on the kick)" % [seam_in, LOOP_SECONDS],
		"",
		"Switch (J / Z / A): glide to the next Jam-level's pitch over %.1f s" % Tuning.MUSIC_GLIDE,
		"Dash (X / Space / K / Shift): jump straight back to Clear",
		"Pause (Esc / P / Enter / Start): back to the title",
		"",
		"Check 1: the tempo and pitch rise smoothly, live, with no restart or dropout.",
		"Check 2: no click, gap or double kick at the seam, at 1.0 and at 1.12.",
	])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"switch"):
		if not _started:
			_started = true
			_player.play()
		else:
			_glide_to((_jam_level + 1) % Tuning.MUSIC_PITCH.size(), Tuning.MUSIC_GLIDE)
	elif event.is_action_pressed(&"dash"):
		_glide_to(0, 0.0)
	elif event.is_action_pressed(&"pause"):
		get_tree().change_scene_to_file(MAIN)


func _glide_to(jam_level: int, seconds: float) -> void:
	_jam_level = jam_level
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, ^"pitch_scale", Tuning.MUSIC_PITCH[jam_level], seconds)

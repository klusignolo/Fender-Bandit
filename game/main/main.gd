extends Node
## Placeholder Main for the week-1 smoke export (#20). The real flow state machine lands in #35.
## Shows which actions are held, so the InputMap can be checked on the cabinet and in a browser.

const AUDIO_CHECK := "res://tools/audio_check/audio_check.tscn"
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"switch", &"dash", &"tow", &"pause"]

var _label: Label


func _ready() -> void:
	# Exported Windows builds run exclusive fullscreen; the web build stays windowed (#13 §8).
	# Keep this when #35 replaces this placeholder.
	if OS.has_feature("template") and not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	print("Fender Bandit booted, window mode %d" % DisplayServer.window_get_mode())
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 28)
	_label.position = Vector2(64, 64)
	add_child(_label)


func _process(_delta: float) -> void:
	var held: PackedStringArray = []
	for action in ACTIONS:
		if Input.is_action_pressed(action):
			held.append(action)
	_label.text = "FENDER BANDIT\nStop. Go. Oops.\n\nHeld: %s\n\nTow (Y / L / C) opens the audio check." % ", ".join(held)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tow"):
		get_tree().change_scene_to_file(AUDIO_CHECK)

extends Node
## Main. For now it just builds one World; the flow state machine replaces this in #35.
## Agent flags, after `--` on the command line (#13 §10):
##   --seed=N       seed the simulation, so a run repeats exactly (default: random)
##   --shot=<path>  save a PNG of the screen after --at seconds of simulated time, then quit
##   --at=S         when --shot fires, in seconds of simulated time (default 15, as in the greybox)
##   --turners=X    Turner share, 0 to 1 (default: the stage-1 value, none), until Stages (#29) sets it

var _shot_path := ""
var _shot_at := 15.0
var _turners := -1.0  # from --turners; negative leaves the stage value
var _world: World


func _ready() -> void:
	# Exported Windows builds run exclusive fullscreen; the web build stays windowed (#13 §8).
	# Keep this when #35 replaces this placeholder.
	if OS.has_feature("template") and not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	var seed_value := randi()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.substr(7))
		elif a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--at="):
			_shot_at = float(a.substr(5))
		elif a.begins_with("--turners="):
			_turners = float(a.substr(10))
	print("Fender Bandit booted, window mode %d, seed %d" % [DisplayServer.window_get_mode(), seed_value])
	_world = World.new(seed_value)
	if _turners >= 0.0:
		_world.traffic.k_turners = _turners
	add_child(_world)


func _physics_process(_delta: float) -> void:
	if _shot_path != "" and _world.traffic.time >= _shot_at:
		var path := _shot_path
		_shot_path = ""
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
		print("Saved shot to %s" % path)
		get_tree().quit()

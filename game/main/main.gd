extends Node
## Main. For now it builds one World per Run, and a fresh one when the Run ends in Gridlock (the death
## beat comes in #34); the flow state machine replaces this in #35.
## Agent flags, after `--` on the command line (#13 §10):
##   --seed=N       seed the simulation, so a run repeats exactly (default: random)
##   --shot=<path>  save a PNG of the screen after --at seconds of simulated time, then quit
##   --at=S         when --shot fires, in seconds of simulated time (default 15, as in the greybox)
##   --turners=X    Turner share, 0 to 1 (default: the stage-1 value, none), until Stages (#29) sets it
##   --blowing      unlock Blowing the red (its Debut is stage 7), until Stages (#29) sets it

var _shot_path := ""
var _shot_at := 15.0
var _turners := -1.0  # from --turners; negative leaves the stage value
var _blowing := false  # from --blowing
var _world: World
var _seed := 0  # this Run's; the next Run takes the next one, so a seeded session repeats exactly


func _ready() -> void:
	# Exported Windows builds run exclusive fullscreen; the web build stays windowed (#13 §8).
	# Keep this when #35 replaces this placeholder.
	if OS.has_feature("template") and not OS.has_feature("web"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	_seed = randi()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			_seed = int(a.substr(7))
		elif a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--at="):
			_shot_at = float(a.substr(5))
		elif a.begins_with("--turners="):
			_turners = float(a.substr(10))
		elif a == "--blowing":
			_blowing = true
	print("Fender Bandit booted, window mode %d, seed %d" % [DisplayServer.window_get_mode(), _seed])
	_start_run()


func _start_run() -> void:
	_world = World.new(_seed)
	if _turners >= 0.0:
		_world.traffic.k_turners = _turners
	_world.traffic.blowing_unlocked = _blowing
	_world.traffic.gridlocked.connect(_on_gridlocked, CONNECT_DEFERRED)
	add_child(_world)


# A bare Gridlock: the Run is over, and a fresh one starts.
func _on_gridlocked() -> void:
	_seed += 1
	print("Gridlock: a fresh Run, seed %d" % _seed)
	_world.queue_free()
	_start_run()


func _physics_process(_delta: float) -> void:
	if _shot_path != "" and _world.traffic.time >= _shot_at:
		var path := _shot_path
		_shot_path = ""
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
		print("Saved shot to %s" % path)
		get_tree().quit()

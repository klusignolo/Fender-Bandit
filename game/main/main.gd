extends Node
## Main. It owns the Run and steps it through its Stages (#29): a fresh World for each stage, the Tally card
## between them over the frozen board, and a fresh Run when one ends in Gridlock (the death beat comes in #34);
## the flow state machine replaces this in #35.
## Agent flags, after `--` on the command line (#13 §10, #19 story 87):
##   --seed=N        seed the simulation, so a run repeats exactly (default: random)
##   --stage=N       start the Run at stage N (default 1)
##   --shot=<path>   save a PNG of the screen after --at seconds of simulated time, then quit
##   --at=S          when --shot fires, in seconds of simulated time across stages (default 15, as in the greybox)
##   --quota-at=S    meet the current stage's Quota at S seconds of simulated time, to see the drain and Tally

var run: Run

var _shot_path := ""
var _shot_at := 15.0
var _quota_at := -1.0  # from --quota-at; negative never
var _start_stage := 1
var _clock := 0.0  # seconds simulated since boot, across stages and Runs
var _world: World
var _tally: CanvasLayer  # the Tally card's layer, while it shows
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
		elif a.begins_with("--stage="):
			_start_stage = maxi(int(a.substr(8)), 1)
		elif a.begins_with("--shot="):
			_shot_path = a.substr(7)
		elif a.begins_with("--at="):
			_shot_at = float(a.substr(5))
		elif a.begins_with("--quota-at="):
			_quota_at = float(a.substr(11))
	print("Fender Bandit booted, window mode %d, seed %d" % [DisplayServer.window_get_mode(), _seed])
	_start_run()


func _start_run() -> void:
	run = Run.new()
	run.stage = _start_stage
	_start_stage_world()


func _start_stage_world() -> void:
	var stage := Stages.def(run.stage, _seed)
	_world = World.new(run, stage, hash([_seed, run.stage]))
	_world.traffic.gridlocked.connect(_on_gridlocked, CONNECT_DEFERRED)
	_world.traffic.stage_cleared.connect(_on_stage_cleared)  # not deferred: the Tally starts on this tick, so a seeded run repeats exactly
	add_child(_world)


# The stage is cleared: freeze the board and show the Tally card over it.
func _on_stage_cleared() -> void:
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	var card := TallyCard.new(run.stage, _world.traffic.cars_through, run.stage_score(), Stages.news(Stages.def(run.stage + 1, _seed)))
	card.done.connect(_on_tally_done)
	_tally = CanvasLayer.new()
	_tally.layer = 2  # over the HUD strip
	_tally.add_child(card)
	add_child(_tally)


# On to the next stage, on a clean board.
func _on_tally_done() -> void:
	_tally.queue_free()
	_tally = null
	_world.queue_free()
	run.next_stage()
	_start_stage_world()


# A bare Gridlock: the Run is over, and a fresh one starts.
func _on_gridlocked() -> void:
	_seed += 1
	print("Gridlock: a fresh Run, seed %d" % _seed)
	_world.queue_free()
	_start_run()


func _physics_process(delta: float) -> void:
	var was := _clock
	_clock += delta
	if was < _quota_at and _clock >= _quota_at:
		_world.traffic.meet_quota()
	if _shot_path != "" and _clock >= _shot_at:
		var path := _shot_path
		_shot_path = ""
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
		print("Saved shot to %s" % path)
		get_tree().quit()

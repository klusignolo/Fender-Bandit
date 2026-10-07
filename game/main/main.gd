extends Node
## Main (#35, #36): the one persistent scene. Flow runs the arcade loop (Attract → Controls → Run → Gridlock → Results
## → Initials → Scores → Attract, with Pause over the Run); Main builds what each state shows and turns presses into
## Flow's inputs.
## A Run steps through its Stages (#29): a fresh World for each stage, the Tally card between them over the frozen
## board. Attract is a World on stage 1 that the autopilot plays (#34), with no HUD and no score; the Gridlock beat
## (#43) plays over a Run's Gridlock. Attract takes turns between its title and the High-score table, which the
## Scores autoload keeps. Attract is muted (#19 story 80): Main has Audio (#37) watch each board, and an Attract board plays no SFX.
## Main cues the music (#38): the Theme on Attract and the screens after a Run, the groove through the Run.
## Agent flags, after `--` on the command line (#13 §10, #19 story 87). Any but --seed skips Attract and the card:
##   --seed=N        seed the simulation, so a run repeats exactly (default: random)
##   --stage=N       start the Run at stage N (default 1)
##   --shot=<path>   save a PNG of the screen after --at seconds of simulated time, then quit
##   --at=S          when --shot fires, in seconds of simulated time across stages (default 15, as in the greybox)
##   --quota-at=S    meet the current stage's Quota at S seconds of simulated time, to see the stage clear and the Tally
##   --switch=S:L,M  Switch Lights L, M, ... (indices into Traffic.lights) at S seconds of simulated time, as the Raccoon
##                   would; repeat it for more. It stages a scene, e.g. the stage-9 art reference (game/tools/reference_shot.sh)
##   --autopilot     the Attract autopilot (#34) plays the Raccoon, every stage of every Run

signal run_over(run: Run)  # a Gridlock ended `run`; the results follow. The smoke test (test/smoke.gd) listens.

const NO_QUOTA := 1 << 30  # Attract's Quota: it stays on stage 1 until it restarts
const RUN_FLAGS: Array[String] = ["--stage=", "--shot=", "--at=", "--quota-at=", "--switch=", "--autopilot"]  # each skips Attract

var flow := Flow.new()
var run: Run  # the Run being played, or Attract's
var autopilot := false  # from --autopilot: each stage's Raccoon gets an Autopilot. Change it with set_autopilot().

var _shot_path := ""
var _shot_at := 15.0
var _quota_at := -1.0  # from --quota-at; negative never
var _switches: Array[Array] = []  # from --switch: [seconds, PackedInt32Array of Light indices]
var _start_stage := 1
var _direct := false  # an agent flag asked for a Run straight away
var _clock := 0.0  # seconds simulated since boot, across stages and Runs, not counting Pause
var _world: World
var _tally: CanvasLayer  # the Tally card's layer, while it shows
var _beat: GridlockBeat  # the Gridlock beat, until it's done or the board goes
var _ui := UI.new()
var _entry: InitialsEntry  # the initials being entered, until the table shows
var _seed := 0  # the next Run's or Attract's; each takes the next one, so a seeded session repeats exactly
var _run_seed := 0  # this Run's


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Flow and the UI run on through Pause; each World and Tally is pausable
	# Exported Windows builds run exclusive fullscreen; the web build stays windowed until the title press (#13 §8).
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
		elif a == "--autopilot":
			autopilot = true
		elif a.begins_with("--switch="):
			var parts := a.substr(9).split(":")
			_switches.append([float(parts[0]), PackedInt32Array(Array(parts[1].split(",")).map(func(s: String) -> int: return int(s)))])
		_direct = _direct or RUN_FLAGS.any(func(f: String) -> bool: return a.begins_with(f))
	print("Fender Bandit booted, window mode %d, seed %d" % [DisplayServer.window_get_mode(), _seed])
	Audio.set_music_on(Scores.table.music)
	add_child(_ui)
	get_window().focus_exited.connect(flow.focus_lost)  # the web build's blur and a desktop window's
	get_window().focus_entered.connect(flow.focus_gained)
	flow.changed.connect(_on_flow_changed)
	flow.paused_changed.connect(_on_paused_changed)
	if _direct:
		flow.play_now()
	else:
		_on_flow_changed(flow.state)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		flow.focus_lost()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		flow.focus_gained()


## Presses become Flow's inputs: any button leaves Attract, A closes the cards, Start pauses.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or flow.input_locked():
		return
	match flow.state:
		Flow.State.ATTRACT:
			if _is_button(event):
				if OS.has_feature("web"):  # only from an input handler: the browser wants a user gesture
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				Audio.unlock()
				flow.press_start(not (event is InputEventKey))
				Audio.play(&"ui_confirm")  # in the browser, the first sound: this press unlocks audio
		Flow.State.CONTROLS, Flow.State.RESULTS, Flow.State.SCORES:
			if _is_confirm(event):
				var was := flow.state
				flow.confirm()
				if flow.state != was:
					Audio.play(&"ui_confirm")
		Flow.State.INITIALS:
			if _is_confirm(event) and flow.initials_unlocked():
				(_ui.screen as InitialsScreen).confirm()
		Flow.State.PLAY:
			if flow.paused:
				_pause_input(event)
			elif event.is_action_pressed(&"pause"):
				flow.pause_or_resume()


## Any key, or any pad button but Select and the guide: the cabinet launcher keeps those (#19 story 11). LT and RT
## count too: they arrive as trigger axes (#4), and RT is a button on the cabinet's grid.
static func _is_button(event: InputEvent) -> bool:
	var b := event as InputEventJoypadButton
	if b != null:
		return b.button_index != JOY_BUTTON_BACK and b.button_index != JOY_BUTTON_GUIDE
	var m := event as InputEventJoypadMotion
	if m != null:
		return m.axis == JOY_AXIS_TRIGGER_LEFT or m.axis == JOY_AXIS_TRIGGER_RIGHT
	return event is InputEventKey


static func _is_confirm(event: InputEvent) -> bool:
	return event.is_action_pressed(&"switch") or event.is_action_pressed(&"ui_accept")


func _pause_input(event: InputEvent) -> void:
	var menu := _ui.screen as PauseMenu
	var row := menu.row
	if event.is_action_pressed(&"move_up"):
		menu.move(-1)
	elif event.is_action_pressed(&"move_down"):
		menu.move(1)
	elif _is_confirm(event):  # before Pause: Enter is both, and on the menu it chooses
		Audio.play(&"ui_confirm")
		if menu.row == PauseMenu.Row.QUIT:
			flow.quit_to_title()
		elif menu.row == PauseMenu.Row.MUSIC:
			Scores.table.set_music(not Scores.table.music)
			Audio.set_music_on(Scores.table.music)
			menu.set_music(Scores.table.music)
		else:
			flow.pause_or_resume()
	elif event.is_action_pressed(&"pause"):
		flow.pause_or_resume()
	if menu.row != row:
		Audio.play(&"ui_move")


func _on_flow_changed(state: Flow.State) -> void:
	match state:
		Flow.State.ATTRACT:
			_clear_board()
			_start_attract()
			_ui.show_screen(TitleScreen.new())
			Audio.music(MusicMix.Track.THEME, true)
		Flow.State.CONTROLS:
			Audio.music(MusicMix.Track.THEME, true)  # over Attract; in the browser, the Theme's first chance to start
			_ui.show_screen(ControlsCard.new(flow.pad))  # over Attract, which plays on behind it
		Flow.State.PLAY:
			_clear_board()
			_ui.clear()
			_start_run()
			Audio.music(MusicMix.Track.GROOVE)
		Flow.State.GRIDLOCK:
			_ui.clear()
			_beat = GridlockBeat.new(_world)  # it stops the board, and the Raccoon with it
			add_child(_beat)
			Audio.gridlock()
			print("Gridlock at stage %d, score %d" % [run.stage, run.score])
			run_over.emit(run)
		Flow.State.RESULTS:
			Audio.music(MusicMix.Track.THEME)
			_ui.show_screen(ResultsCard.new(run))
		Flow.State.INITIALS:
			_entry = InitialsEntry.new()
			var screen := InitialsScreen.new(_entry, run.score, Scores.table.rank_of(run.score))
			screen.entered.connect(flow.initials_entered)
			screen.blip.connect(Audio.play)
			_ui.show_screen(screen)
		Flow.State.SCORES:
			_ui.show_screen(ScoresScreen.new(Scores.table.entries, _record()))


## Put the Run in the table under the initials entered, or the default if nobody finished them; returns its rank.
## A Run that skipped Initials has no entry, and isn't recorded.
func _record() -> int:
	if _entry == null:
		return -1
	var initials := _entry.text() if _entry.done else InitialsEntry.DEFAULT
	_entry = null
	var rank := Scores.table.add(initials, run.score)
	print("High score: %s %d, rank %d" % [initials, run.score, rank + 1])
	return rank


func _on_paused_changed(paused: bool) -> void:
	get_tree().paused = paused
	if paused:
		_ui.show_screen(PauseMenu.new(Scores.table.music))
	else:
		_ui.clear()


## Free the board: the World, the Tally card and the Gridlock beat.
func _clear_board() -> void:
	if is_instance_valid(_beat):
		_beat.queue_free()
	_beat = null
	if _tally != null:
		_tally.queue_free()
		_tally = null
	if _world != null:
		_world.queue_free()
		_world = null


func _take_seed() -> int:
	_seed += 1
	return _seed - 1


## A fresh Attract: the autopilot plays stage 1 on a fresh seed, with no HUD, and never clears it.
func _start_attract() -> void:
	run = Run.new()
	_run_seed = _take_seed()
	_add_world(Stages.def(1, _run_seed))
	_world.traffic.quota = NO_QUOTA
	_world.hud.visible = false
	_world.raccoon.pilot = Autopilot.new(_world.traffic)


func _start_run() -> void:
	run = Run.new()
	run.stage = _start_stage
	_run_seed = _take_seed()
	_start_stage_world()


func _start_stage_world() -> void:
	_add_world(Stages.def(run.stage, _run_seed))
	_world.traffic.stage_cleared.connect(_on_stage_cleared.bind(_world))  # not deferred: the Tally starts on this tick, so a seeded run repeats exactly
	if autopilot:
		_world.raccoon.pilot = Autopilot.new(_world.traffic)


func _add_world(stage: StageDef) -> void:
	_world = World.new(run, stage, hash([_run_seed, run.stage]))
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE  # not Main's ALWAYS
	_world.traffic.gridlocked.connect(_on_gridlocked.bind(_world), CONNECT_DEFERRED)
	add_child(_world)
	Audio.watch(_world, flow.state == Flow.State.ATTRACT)  # Attract is muted (#19 story 80), the controls card over it too


## Hand the Raccoon to the autopilot, or take it back, from now on: this stage of the Run too.
func set_autopilot(on: bool) -> void:
	autopilot = on
	if flow.state == Flow.State.PLAY and on != (_world.raccoon.pilot != null):  # keep a pilot already flying: it remembers the Greens it turned on
		_world.raccoon.pilot = Autopilot.new(_world.traffic) if on else null


# The stage is cleared: freeze the board and show the Tally card over it. A World being freed may still tick once.
func _on_stage_cleared(world: World) -> void:
	if world != _world:
		return
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	var card := TallyCard.new(run.stage, _world.traffic.cars_through, run.stage_score(), Stages.news(Stages.def(run.stage + 1, _run_seed)))
	card.done.connect(_on_tally_done.bind(card))
	_tally = CanvasLayer.new()
	_tally.layer = 2  # over the HUD strip
	_tally.process_mode = Node.PROCESS_MODE_PAUSABLE
	_tally.add_child(card)
	add_child(_tally)


# On to the next stage, on a clean board.
func _on_tally_done(card: TallyCard) -> void:
	if _tally == null or card.get_parent() != _tally:
		return  # quit to title while it showed
	_clear_board()
	run.next_stage()
	_start_stage_world()


# The Jam is full. A stale World's Gridlock (deferred past a change of board) is ignored.
func _on_gridlocked(world: World) -> void:
	if world == _world:
		flow.gridlocked(Scores.table.ranks(run.score))


func _physics_process(delta: float) -> void:
	flow.step(1.0 / Engine.physics_ticks_per_second)  # real time: Flow's clock runs on through a freeze or slow-mo
	if get_tree().paused or _world == null:
		return
	var was := _clock
	_clock += delta
	if was < _quota_at and _clock >= _quota_at:
		_world.traffic.meet_quota()
	for s: Array in _switches:
		if was < s[0] and _clock >= s[0]:
			for i: int in s[1]:
				if i < _world.traffic.lights.size():  # a later stage may have more Lights, an earlier one fewer
					_world.traffic.switch(_world.traffic.lights[i])
	if _shot_path != "" and _clock >= _shot_at:
		var path := _shot_path
		_shot_path = ""
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(path)
		print("Saved shot to %s" % path)
		get_tree().quit()

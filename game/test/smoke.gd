extends SceneTree
## The headless whole-game smoke test (#34, #35, seam 3 in #19). Run it with game/tools/smoke.sh, or:
##   godot --headless --fixed-fps 60 --path game -s test/smoke.gd [-- --seed=N]
## Boots Main into Attract and walks the whole arcade loop with one press: a pad's A leaves Attract, the controls
## card closes by itself, and the Attract autopilot plays the Run until it reaches stage STAGES (or AUTO_FOR seconds
## pass), so stages clear and the Tally card runs. On the way it pauses and resumes once with Start. Then the Raccoon
## goes idle, and the Run must end in Gridlock within IDLE_FOR seconds: an idle Raccoon gridlocks in about 30s (#34).
## A Gridlock while the autopilot plays counts too. The results must then give way to Initials (a fresh table always
## ranks a Run that scored), which must save "RAC" by themselves, then the High-score table, then Attract, which must
## stay on its title for TITLE_FOR seconds (#45: the table shows only after a Run). It keeps its table in a scratch
## file, never the real one.
## By ear (#37): Attract and the controls card over it play no SFX but the UI's, and the Run plays HEARD.
## The music (#38) starts as MUSIC says: the Theme on Attract, the groove for the Run, the Theme again at the results,
## playing on through the table into the next Attract.
## It exits non-zero at the first engine or script error logged, or if any step doesn't come. Main prints the seed
## it booted with; pass it back with --seed to repeat a run exactly.

const Runner := preload("res://test/run.gd")
const STAGES := 3
const PRESS_AT := 2.0  # simulated seconds into Attract
const PAUSE_AT := 5.0  # ...into the Run: Start pauses...
const PAUSE_FOR := 1.0  # ...for this long
const AUTO_FOR := 300.0  # simulated seconds
const IDLE_FOR := 45.0  # simulated seconds
const STEP_LIMIT := 5.0  # simulated seconds each other step may take, beyond its own time
const TITLE_FOR := 12.0  # simulated seconds the next Attract must stay on its title
const HEARD: Array[StringName] = [&"switch_green", &"honk_1", &"stinger", &"gridlock_scratch", &"gridlock_shatter"]
const MUSIC := [[Flow.State.ATTRACT, MusicMix.Track.THEME], [Flow.State.PLAY, MusicMix.Track.GROOVE],
		[Flow.State.RESULTS, MusicMix.Track.THEME]]  # [the state, the track started there], in order
const SCORES_PATH := "user://smoke_scores.cfg"

enum Step { ATTRACT, CONTROLS, RUN, PAUSED, IDLE, OVER, INITIALS, TABLE, BACK }

var _errors := Runner.ErrorCounter.new()
var _main: Node
var _clock := 0.0  # seconds simulated
var _step := Step.ATTRACT
var _step_at := 0.0  # when this step began
var _gridlock := ""  # what the Gridlock was, once it came
var _paused_once := false
var _start_ms := 0
var _done := false
var _scores: Node  # the Scores autoload
var _heard: Dictionary[StringName, bool] = {}  # sounds played outside Attract
var _attract_sfx: Array[StringName] = []  # SFX played in Attract or over it, but the UI's
var _music: Array = []  # [the state, the track] for each start of the music


func _initialize() -> void:
	OS.add_logger(_errors)
	_start_ms = Time.get_ticks_msec()
	DirAccess.remove_absolute(SCORES_PATH)
	_scores = root.get_node("Scores")
	_scores.use(SCORES_PATH)
	_main = load("res://main/main.tscn").instantiate()
	_main.autopilot = true  # every Run's Raccoon gets the autopilot: Main isn't ready until the first frame
	root.add_child(_main)
	_main.run_over.connect(_on_run_over)
	root.get_node("Audio").played.connect(_on_played)
	root.get_node("Audio").music_started.connect(func(t: MusicMix.Track) -> void: _music.append([_main.flow.state, t]))


func _physics_process(delta: float) -> bool:
	if _done:
		return false
	_clock += delta
	if _errors.count > 0:
		_finish("FAIL: an error was logged")
		return false
	var flow: Flow = _main.flow
	var since := _clock - _step_at
	match _step:
		Step.ATTRACT:
			if since >= PRESS_AT:
				_expect(flow.state == Flow.State.ATTRACT, "Main boots into Attract")
				_press(JOY_BUTTON_A)
				_expect(flow.state == Flow.State.CONTROLS and flow.pad, "a pad press shows the pad's controls card")
				_go(Step.CONTROLS)
		Step.CONTROLS:
			if flow.state == Flow.State.PLAY:
				print("Smoke: the card closed by itself at %.1fs" % _clock)
				_go(Step.RUN)
			elif since > Tuning.CONTROLS_TIME + STEP_LIMIT:
				_finish("FAIL: the controls card never closed")
		Step.RUN:
			if _gridlock != "":
				_go(Step.OVER)
			elif since >= PAUSE_AT and not _paused_once:
				_paused_once = true
				_press(JOY_BUTTON_START)
				_expect(paused and flow.paused, "Start pauses the Run")
				_go(Step.PAUSED)
			elif _main.run.stage >= STAGES or _clock >= AUTO_FOR:
				print("Smoke: the Raccoon goes idle at stage %d, %.1fs" % [_main.run.stage, _clock])
				_main.set_autopilot(false)
				_go(Step.IDLE)
		Step.PAUSED:
			if since >= PAUSE_FOR:
				_press(JOY_BUTTON_START)
				_expect(not paused and not flow.paused, "Start resumes the Run")
				_go(Step.RUN)
		Step.IDLE:
			if _gridlock != "":
				_go(Step.OVER)
			elif since > IDLE_FOR:
				_finish("FAIL: no Gridlock within %.0fs of the Raccoon going idle" % IDLE_FOR)
		Step.OVER:
			if flow.state == Flow.State.INITIALS:
				print("Smoke: %s; Initials %.1fs later" % [_gridlock, since])
				_go(Step.INITIALS)
			elif flow.state in [Flow.State.SCORES, Flow.State.ATTRACT]:
				_finish("FAIL: %s, but the Run that scored skipped Initials" % _gridlock)
			elif since > Tuning.GRIDLOCK_HOLD + Tuning.RESULTS_TIME + STEP_LIMIT:
				_finish("FAIL: %s, but the results never gave way to Initials" % _gridlock)
		Step.INITIALS:
			if flow.state == Flow.State.SCORES:
				var top: Dictionary = _scores.table.entries[0] if not _scores.table.entries.is_empty() else {}
				_expect(top.get("initials") == "RAC" and top.get("score") == _main.run.score, "the Run saved as RAC at the top of the table")
				_go(Step.TABLE)
			elif since > Tuning.INITIALS_TIME + STEP_LIMIT:
				_finish("FAIL: the initials never saved by themselves")
		Step.TABLE:
			if flow.state == Flow.State.ATTRACT:
				_go(Step.BACK)
			elif since > Tuning.SCORES_TIME + STEP_LIMIT:
				_finish("FAIL: the High-score table never gave way to Attract")
		Step.BACK:
			if not _main._ui.screen is TitleScreen:
				_finish("FAIL: Attract left its title %.1fs in" % since)
			elif since >= TITLE_FOR:
				_expect(_attract_sfx.is_empty(), "Attract plays no SFX: it played %s" % [_attract_sfx])
				for sound in HEARD:
					_expect(_heard.has(sound), "the Run played %s" % sound)
				_expect(_music == MUSIC, "the music started as %s: it went %s" % [MUSIC, _music])
				_finish("%s; the table showed, then Attract stayed on its title" % _gridlock)
	return false


## A pad button's press and release, as the cabinet sends them.
func _press(button: JoyButton) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = down
		root.push_input(e)


func _go(s: Step) -> void:
	_step = s
	_step_at = _clock


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_finish("FAIL: expected: %s" % what)


func _on_run_over(run: Run) -> void:
	var idle := "%.1fs after the Raccoon went idle" % (_clock - _step_at) if _step == Step.IDLE else "while the autopilot played"
	_gridlock = "Gridlock at stage %d, %.1fs in, %s; score %d" % [run.stage, _clock, idle, run.score]


func _on_played(sound: StringName) -> void:
	if _main.flow.state in [Flow.State.ATTRACT, Flow.State.CONTROLS] and not String(sound).begins_with("ui_"):
		_attract_sfx.append(sound)
	else:
		_heard[sound] = true


func _finish(what: String) -> void:
	if _done:
		return
	_done = true
	DirAccess.remove_absolute(SCORES_PATH)
	var ok := not what.begins_with("FAIL") and _errors.count == 0
	if _errors.count > 0:
		printerr("FAIL: %d error(s) logged; the last: %s" % [_errors.count, _errors.last])
	print("Smoke: %s. %s in %.1fs of real time" % [what, "PASS" if ok else "FAIL", (Time.get_ticks_msec() - _start_ms) / 1000.0])
	root.get_node("Audio").silence()
	OS.delay_msec(100)  # real time, which --fixed-fps doesn't give: the audio thread lets go of the stopped clips...
	await process_frame  # ...and the main thread frees them
	await process_frame
	quit(0 if ok else 1)

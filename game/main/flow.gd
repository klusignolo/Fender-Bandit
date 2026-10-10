class_name Flow
extends RefCounted
## The arcade loop (#35, #36, #19 "Flow"): Attract → Controls → Play (the Run's stages, with the Tally between) →
## Gridlock → Results → Initials (top 10 only) → Scores → Attract, with Pause over Play. Attract shows only the title:
## the High-score table follows a Run (#45). It keeps the state, its clock and which inputs each state takes; Main
## builds what each state shows and feeds it semantic inputs. The timings are Tuning's.

enum State { ATTRACT, CONTROLS, PLAY, GRIDLOCK, RESULTS, INITIALS, SCORES }

signal changed(state: State)  # entered `state`; ATTRACT again means a fresh Attract, on its title
signal paused_changed(paused: bool)

var state := State.ATTRACT
var paused := false  # Pause, over Play only
var pad := false  # the press that left Attract came from a pad: the controls card shows the pad, else the keys
var ranked := false  # the Run that gridlocked made the top 10, so Initials follow the results

var _in_state := 0.0  # seconds in this state, not counting Pause
var _away := false  # the window or tab has lost focus and not got it back


## One tick of `dt` seconds: a state with a time limit moves on when it's up.
func step(dt: float) -> void:
	if paused:
		return
	_in_state += dt
	match state:
		State.ATTRACT:
			if _in_state >= Tuning.ATTRACT_TIME:
				_go(State.ATTRACT)
		State.CONTROLS:
			if _in_state >= Tuning.CONTROLS_TIME:
				_go(State.PLAY)
		State.GRIDLOCK:
			if _in_state >= Tuning.GRIDLOCK_HOLD:
				_go(State.RESULTS)
		State.RESULTS:
			if _in_state >= Tuning.RESULTS_TIME:
				_after_results()
		State.INITIALS:
			if _in_state >= Tuning.INITIALS_TIME:
				_go(State.SCORES)
		State.SCORES:
			if _in_state >= Tuning.SCORES_TIME:
				_go(State.ATTRACT)


## START on the title menu: on to the controls card, or straight into the Run once `card` is false (the player has
## seen it, #45). `from_pad` says which card it shows.
func press_start(from_pad: bool, card := true) -> void:
	if state == State.ATTRACT:
		pad = from_pad
		_go(State.CONTROLS if card else State.PLAY)


## A press on the title menu (#45): Attract starts over only ATTRACT_TIME after the last one, so it never pulls the
## menu out from under the player.
func touch() -> void:
	if state == State.ATTRACT:
		_in_state = 0.0


## A: closes the controls card, the results or the table, once their lock is over.
func confirm() -> void:
	if state == State.CONTROLS and _in_state >= Tuning.CONTROLS_LOCK:
		_go(State.PLAY)
	elif state == State.RESULTS and _in_state >= Tuning.RESULTS_LOCK:
		_after_results()
	elif state == State.SCORES and _in_state >= Tuning.SCORES_LOCK:
		_go(State.ATTRACT)


## Whether A may enter a letter of the initials: not until INITIALS_LOCK has gone by.
func initials_unlocked() -> bool:
	return state == State.INITIALS and _in_state >= Tuning.INITIALS_LOCK


## The initials are in: on to the table.
func initials_entered() -> void:
	if state == State.INITIALS:
		_go(State.SCORES)


## Start: Pause a Run, or resume it.
func pause_or_resume() -> void:
	if state == State.PLAY:
		_set_paused(not paused)


## The window or tab lost focus: Pause a Run, or the one the controls card is about to start.
func focus_lost() -> void:
	_away = true
	if state == State.PLAY:
		_set_paused(true)


## The window or tab has focus again. A paused Run stays paused.
func focus_gained() -> void:
	_away = false


## Pause's Quit to title: the Run is dropped, with no results.
func quit_to_title() -> void:
	if paused:
		_set_paused(false)
		_go(State.ATTRACT)


## The Jam is full: a Run is over, and `top_ten` says whether its score made the table; an Attract starts afresh.
func gridlocked(top_ten := false) -> void:
	if state == State.ATTRACT:
		_go(State.ATTRACT)
	elif state == State.PLAY:
		ranked = top_ten
		_go(State.GRIDLOCK)


## Straight into a Run, skipping Attract and the card: for the agent flags.
func play_now() -> void:
	_go(State.PLAY)


## Presses are ignored from Gridlock until the results show (#19 story 55).
func input_locked() -> bool:
	return state == State.GRIDLOCK


func _after_results() -> void:
	_go(State.INITIALS if ranked else State.SCORES)


func _go(s: State) -> void:
	state = s
	_in_state = 0.0
	changed.emit(s)
	if s == State.PLAY and _away:
		_set_paused(true)


func _set_paused(p: bool) -> void:
	if p != paused:
		paused = p
		paused_changed.emit(p)

extends TestCase
## The arcade loop (#35): Flow's states, its clock and the inputs each state takes. Main builds what each
## state shows; these tests drive Flow alone.

const A := Flow.State.ATTRACT
const C := Flow.State.CONTROLS
const P := Flow.State.PLAY
const G := Flow.State.GRIDLOCK
const R := Flow.State.RESULTS
const I := Flow.State.INITIALS
const S := Flow.State.SCORES


## Records what Flow emits. Holds no reference to the Flow, so nothing leaks.
class Log:
	var states: Array[int] = []
	var pauses: Array[bool] = []
	var tables: Array[bool] = []

	func _init(f: Flow) -> void:
		f.changed.connect(func(s: Flow.State) -> void: states.append(s))
		f.paused_changed.connect(func(p: bool) -> void: pauses.append(p))
		f.attract_table_changed.connect(func(on: bool) -> void: tables.append(on))


## Step `f` for `seconds` of 60 Hz ticks.
func _wait(f: Flow, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		f.step(1.0 / 60.0)


func test_the_full_loop_runs_untouched_after_one_press() -> void:
	var f := Flow.new()
	var log := Log.new(f)
	check_eq(f.state, A, "it boots into Attract")
	_wait(f, 2.0)
	f.press_start(true)
	check_eq(f.state, C, "a press leaves Attract for the controls card")
	check(f.pad, "the card shows the pad the press came from")
	_wait(f, Tuning.CONTROLS_TIME + 0.1)
	check_eq(f.state, P, "the card closes by itself")
	f.gridlocked(true)
	check_eq(f.state, G, "Gridlock ends the Run")
	_wait(f, Tuning.GRIDLOCK_HOLD + 0.1)
	check_eq(f.state, R, "the results show after the Gridlock beat")
	_wait(f, Tuning.RESULTS_TIME + 0.1)
	check_eq(f.state, I, "a top-10 Run moves on to Initials by itself")
	_wait(f, Tuning.INITIALS_TIME + 0.1)
	check_eq(f.state, S, "Initials save by themselves after their time")
	_wait(f, Tuning.SCORES_TIME + 0.1)
	check_eq(f.state, A, "the table moves on to Attract by itself")
	check_eq(log.states, [C, P, G, R, I, S, A] as Array[int], "every state, once")


func test_a_run_outside_the_top_ten_skips_initials() -> void:
	var f := _playing()
	var log := Log.new(f)
	f.gridlocked(false)
	_wait(f, Tuning.GRIDLOCK_HOLD + Tuning.RESULTS_TIME + 0.2)
	check_eq(f.state, S, "straight to the table")
	_wait(f, Tuning.SCORES_TIME + 0.1)
	check_eq(log.states, [G, R, S, A] as Array[int], "no Initials")


func test_entering_initials_moves_on_but_only_from_initials() -> void:
	var f := _playing()
	f.initials_entered()
	check_eq(f.state, P, "not in a Run")
	f.gridlocked(true)
	_wait(f, Tuning.GRIDLOCK_HOLD + Tuning.RESULTS_TIME + 0.2)
	check_eq(f.state, I, "Initials")
	f.initials_entered()
	check_eq(f.state, S, "on to the table")


func test_initials_take_a_only_after_their_lock() -> void:
	var f := _playing()
	f.gridlocked(true)
	_wait(f, Tuning.GRIDLOCK_HOLD + 0.1)
	_wait(f, Tuning.RESULTS_LOCK + 0.1)
	check(not f.initials_unlocked(), "not on the results")
	f.confirm()
	check_eq(f.state, I, "A skips the results to Initials")
	check(not f.initials_unlocked(), "a mashed A can't enter a letter yet")
	_wait(f, Tuning.INITIALS_LOCK + 0.1)
	check(f.initials_unlocked(), "it can once the lock is over")


func test_the_table_skips_on_a_press_only_after_its_lock() -> void:
	var f := _playing()
	f.gridlocked(false)
	_wait(f, Tuning.GRIDLOCK_HOLD + Tuning.RESULTS_TIME + 0.2)
	f.confirm()
	check_eq(f.state, S, "a mashed press can't skip it")
	_wait(f, Tuning.SCORES_LOCK + 0.1)
	f.confirm()
	check_eq(f.state, A, "A moves on once the lock is over")


func test_attract_cycles_to_the_table_and_back() -> void:
	var f := Flow.new()
	var log := Log.new(f)
	_wait(f, Tuning.ATTRACT_TITLE - 0.1)
	check_eq(log.tables, [] as Array[bool], "the title first")
	_wait(f, 0.2)
	check_eq(log.tables, [true] as Array[bool], "then the table")
	check(f.attract_table, "showing")
	_wait(f, Tuning.ATTRACT_TABLE)
	check_eq(log.tables, [true, false] as Array[bool], "then the title again")
	_wait(f, Tuning.ATTRACT_TITLE)
	check_eq(log.tables, [true, false, true] as Array[bool], "every cycle")
	f.press_start(false)
	check(not f.attract_table, "leaving Attract drops the table")
	_wait(f, Tuning.ATTRACT_TITLE + 0.2)
	check_eq(log.tables.size(), 3, "only Attract cycles")


func test_a_fresh_attract_starts_on_the_title() -> void:
	var f := Flow.new()
	_wait(f, Tuning.ATTRACT_TITLE + 0.2)
	f.gridlocked()
	check_eq(f.state, A, "a fresh Attract")
	check(not f.attract_table, "on the title")


func test_a_keyboard_press_shows_the_keyboard_card() -> void:
	var f := Flow.new()
	f.press_start(false)
	check(not f.pad, "the keyboard card")


func test_attract_restarts_after_its_time_or_at_gridlock_and_never_shows_results() -> void:
	var f := Flow.new()
	var log := Log.new(f)
	_wait(f, Tuning.ATTRACT_TIME - 0.5)
	check_eq(log.states, [] as Array[int], "still the first Attract")
	_wait(f, 1.0)
	check_eq(log.states, [A] as Array[int], "a fresh Attract after ATTRACT_TIME")
	_wait(f, 5.0)
	f.gridlocked()
	check_eq(log.states, [A, A] as Array[int], "a fresh Attract at Gridlock, not the results")
	_wait(f, Tuning.ATTRACT_TIME - 0.5)
	check_eq(log.states, [A, A] as Array[int], "the clock started over")


func test_the_controls_card_closes_on_a_press_only_after_its_lock() -> void:
	var f := Flow.new()
	f.press_start(true)
	f.confirm()
	check_eq(f.state, C, "the press that left Attract can't close the card too")
	_wait(f, Tuning.CONTROLS_LOCK + 0.1)
	f.confirm()
	check_eq(f.state, P, "A closes it once the lock is over")


func test_the_results_skip_on_a_press_only_after_their_lock() -> void:
	var f := _playing()
	f.gridlocked()
	_wait(f, Tuning.GRIDLOCK_HOLD + 0.1)
	f.confirm()
	check_eq(f.state, R, "a press mashed through the Gridlock can't skip the results")
	_wait(f, Tuning.RESULTS_LOCK + 0.1)
	f.confirm()
	check_eq(f.state, S, "A moves on once the lock is over")


func test_input_is_locked_from_gridlock_until_the_results_show() -> void:
	var f := _playing()
	f.gridlocked()
	check(f.input_locked(), "locked at Gridlock")
	f.confirm()
	f.pause_or_resume()
	f.press_start(true)
	f.focus_lost()
	check_eq(f.state, G, "no press moves it on")
	check(not f.paused, "nor pauses it")
	_wait(f, Tuning.GRIDLOCK_HOLD + 0.1)
	check(not f.input_locked(), "unlocked once the results show")


func test_pause_toggles_only_in_a_run() -> void:
	var f := Flow.new()
	var log := Log.new(f)
	f.pause_or_resume()
	check(not f.paused, "not in Attract")
	f.press_start(false)
	f.pause_or_resume()
	check(not f.paused, "not on the controls card")
	_wait(f, Tuning.CONTROLS_TIME + 0.1)
	f.pause_or_resume()
	check(f.paused, "Pause in a Run")
	f.pause_or_resume()
	check(not f.paused, "and again to resume")
	check_eq(log.pauses, [true, false] as Array[bool], "each change signalled")


func test_losing_focus_pauses_a_run() -> void:
	var f := _playing()
	f.focus_lost()
	check(f.paused, "paused")
	f.focus_lost()
	check(f.paused, "and stays paused")
	var a := Flow.new()
	a.focus_lost()
	check(not a.paused, "Attract plays on")


func test_quit_to_title_goes_back_to_attract_unpaused() -> void:
	var f := _playing()
	var log := Log.new(f)
	f.quit_to_title()
	check_eq(f.state, P, "only from Pause")
	f.pause_or_resume()
	f.quit_to_title()
	check_eq(f.state, A, "Attract")
	check(not f.paused, "unpaused")
	check_eq(log.states, [A] as Array[int], "no results for a Run quit")


func test_a_paused_run_has_no_clock() -> void:
	var f := _playing()
	f.pause_or_resume()
	_wait(f, Tuning.ATTRACT_TIME + Tuning.RESULTS_TIME)
	check_eq(f.state, P, "still the Run")
	check(f.paused, "still paused")


func test_play_now_skips_attract_and_the_card() -> void:
	var f := Flow.new()
	var log := Log.new(f)
	f.play_now()
	check_eq(f.state, P, "straight into a Run, as the agent flags want")
	check_eq(log.states, [P] as Array[int], "signalled")


## A Flow in a Run, past the controls card.
func _playing() -> Flow:
	var f := Flow.new()
	f.press_start(true)
	_wait(f, Tuning.CONTROLS_TIME + 0.1)
	return f


func test_focus_lost_on_the_controls_card_pauses_the_run_it_starts() -> void:
	var f := Flow.new()
	f.press_start(false)
	f.focus_lost()
	check(not f.paused, "nothing to pause on the card")
	_wait(f, Tuning.CONTROLS_TIME + 0.1)
	check_eq(f.state, P, "the card still closes by itself")
	check(f.paused, "and the Run starts paused, with nobody watching")


func test_focus_back_before_the_run_starts_it_unpaused() -> void:
	var f := Flow.new()
	f.press_start(false)
	f.focus_lost()
	f.focus_gained()
	_wait(f, Tuning.CONTROLS_TIME + 0.1)
	check(not f.paused, "the player is back")

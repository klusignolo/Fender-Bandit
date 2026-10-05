extends TestCase
## Initials entry (#36, #19 story 14): up/down cycles A–Z, space and period with wrap-around and auto-repeat;
## A or right moves on, left goes back. InitialsEntry is fed the stick's held directions each tick.

const DT := 1.0 / 60.0


## Hold vertical `v` and horizontal `h` for `seconds` of 60 Hz ticks.
func _hold(e: InitialsEntry, v: int, h: int, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		e.step(DT, v, h)


## A fresh entry that has seen the stick at rest.
func _entry() -> InitialsEntry:
	var e := InitialsEntry.new()
	e.step(DT, 0, 0)
	return e


func test_it_starts_on_a_in_the_first_slot() -> void:
	var e := InitialsEntry.new()
	check_eq(e.text(), "AAA", "every slot on A")
	check_eq(e.slot, 0, "the first slot")
	check(not e.done, "not done")


func test_up_and_down_cycle_with_wrap_around() -> void:
	var e := _entry()
	_hold(e, 1, 0, DT)
	_hold(e, 0, 0, DT)
	check_eq(e.text(), "BAA", "up: the next letter")
	for i in 2:
		_hold(e, -1, 0, DT)
		_hold(e, 0, 0, DT)
	check_eq(e.text().substr(0, 1), ".", "down past A wraps to the period")
	_hold(e, -1, 0, DT)
	check_eq(e.text().substr(0, 1), " ", "then the space")
	_hold(e, 0, 0, DT)
	_hold(e, 1, 0, DT)
	_hold(e, 0, 0, DT)
	_hold(e, 1, 0, DT)
	check_eq(e.text().substr(0, 1), "A", "up past the period wraps to A")


func test_holding_auto_repeats() -> void:
	var e := _entry()
	_hold(e, 1, 0, Tuning.REPEAT_DELAY - 0.05)
	check_eq(e.letters[0], 1, "one step until the repeat delay")
	_hold(e, 1, 0, 0.1 + Tuning.REPEAT_EVERY * 4)
	check_eq(e.letters[0], 6, "then one every REPEAT_EVERY: B, then C to G")
	_hold(e, 0, 0, DT)
	_hold(e, 1, 0, Tuning.REPEAT_DELAY - 0.05)
	check_eq(e.letters[0], 7, "letting go starts the delay over")


func test_a_stick_held_as_it_opens_does_not_step_at_once() -> void:
	var e := InitialsEntry.new()
	_hold(e, 0, 1, 0.5)
	check_eq(e.slot, 0, "a right held over from before doesn't move on")
	e = InitialsEntry.new()
	e.step(DT, 1, 0)
	check_eq(e.letters[0], 0, "nor an up")


func test_right_and_confirm_move_on_left_goes_back() -> void:
	var e := _entry()
	_hold(e, 0, 1, 0.5)
	check_eq(e.slot, 1, "right moves on once, however long it's held")
	_hold(e, 0, 0, DT)
	_hold(e, 1, 0, DT)
	check_eq(e.text(), "ABA", "the second slot's letter")
	_hold(e, 0, -1, DT)
	check_eq(e.slot, 0, "left goes back")
	_hold(e, 0, 0, DT)
	_hold(e, 0, -1, DT)
	check_eq(e.slot, 0, "and stops at the first slot")
	_hold(e, 0, 0, DT)
	e.next()
	e.next()
	check_eq(e.slot, 2, "A moves on too")
	check(not e.done, "not done on the last slot")
	e.next()
	check(e.done, "moving on from the last slot finishes")
	check_eq(e.text(), "ABA", "the initials entered")


func test_a_finished_entry_takes_no_more_input() -> void:
	var e := _entry()
	e.next()
	e.next()
	_hold(e, 0, 1, DT)
	check(e.done, "right on the last slot finishes too")
	_hold(e, 0, 0, DT)
	_hold(e, 1, 0, 1.0)
	_hold(e, 0, -1, DT)
	e.back()
	e.next()
	check_eq(e.text(), "AAA", "no letter changes")
	check_eq(e.slot, 2, "no slot changes")

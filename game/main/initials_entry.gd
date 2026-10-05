class_name InitialsEntry
extends RefCounted
## Three-letter initials, entered the classic way (#36, #19 story 14). Each tick it's fed the stick's held
## directions: up or down steps the slot's letter through ALPHABET, wrapping, and repeats while held; right moves
## on and left goes back, once per push. A (next()) moves on too; moving on from the last slot finishes.
## It reads the stick as held directions, not as events, because a stick sends a stream of motion events.

const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ ."
const SLOTS := 3
const DEFAULT := "RAC"  # saved instead when nobody finishes in time (#19 story 15)

var letters := PackedInt32Array([0, 0, 0])  # indices into ALPHABET
var slot := 0
var done := false

var _seen := false  # step() has seen the stick once: what's held then was held before the entry opened
var _v := 0  # the vertical direction held last tick: 1 up, -1 down
var _h := 0  # ...and the horizontal: 1 right, -1 left
var _held := 0.0  # seconds _v has been held, less the repeats taken


func text() -> String:
	var s := ""
	for l in letters:
		s += ALPHABET[l]
	return s


## One tick of `dt` seconds with the stick held `v` (1 up, -1 down, 0) and `h` (1 right, -1 left, 0).
func step(dt: float, v: int, h: int) -> void:
	if not _seen:
		_seen = true
		_v = v
		_h = h
		return
	if h != _h:
		_h = h
		if h > 0:
			next()
		elif h < 0:
			back()
	if v != _v:
		_v = v
		_held = 0.0
		if v != 0:
			_cycle(v)
	elif v != 0:
		_held += dt
		while _held >= Tuning.REPEAT_DELAY:
			_cycle(v)
			_held -= Tuning.REPEAT_EVERY


## On to the next slot, or finish from the last.
func next() -> void:
	if done:
		return
	if slot == SLOTS - 1:
		done = true
	else:
		slot += 1


func back() -> void:
	if not done:
		slot = maxi(slot - 1, 0)


func _cycle(d: int) -> void:
	if not done:
		letters[slot] = posmod(letters[slot] + d, ALPHABET.length())

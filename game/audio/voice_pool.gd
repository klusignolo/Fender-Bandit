class_name VoicePool
extends RefCounted
## Which SFX voice a new sound gets (#37, docs/audio.md "Playback rules"). Audio owns the players; this only books
## them, by clip length, so it can be tested without any. A sound is dropped if it started within SFX_RETRIGGER, or
## if it's a Honk and HONK_MAX are already sounding. When every voice is busy, it cuts the oldest voice of the lowest
## priority, if that's no higher than its own; otherwise it's dropped.

## Highest last. Ties don't cut each other, but the player's own actions (PLAYER) do: they must always be heard.
enum Priority { OTHER, HONK, PLAYER, BLOW, HIT, CRASH, GRIDLOCK }

var size := 0

var _priority: Array[int] = []  # per voice: its sound's
var _start: Array[float] = []
var _end: Array[float] = []  # when its sound ends; at or before now, it's free
var _last_start: Dictionary[StringName, float] = {}


func _init(voices: int) -> void:
	size = voices
	for i in voices:
		_priority.append(0)
		_start.append(-INF)
		_end.append(-INF)


## Book a voice for `sound`, `length` seconds long, starting at `now` (seconds): its index, or -1 if it's dropped.
func request(sound: StringName, priority: Priority, length: float, now: float) -> int:
	if now - _last_start.get(sound, -INF) < Tuning.SFX_RETRIGGER:
		return -1
	if priority == Priority.HONK and playing(Priority.HONK, now) >= Tuning.HONK_MAX:
		return -1
	var voice := -1
	for i in size:
		if _end[i] <= now:
			voice = i
			break
	if voice < 0:
		for i in size:  # the oldest of the lowest priority
			if voice < 0 or _priority[i] < _priority[voice] or (_priority[i] == _priority[voice] and _start[i] < _start[voice]):
				voice = i
		var may_cut := _priority[voice] < priority or (_priority[voice] == priority and priority == Priority.PLAYER)
		if not may_cut:
			return -1
	_priority[voice] = priority
	_start[voice] = now
	_end[voice] = now + length
	_last_start[sound] = now
	return voice


## Voices of `priority` sounding at `now`.
func playing(priority: Priority, now: float) -> int:
	var n := 0
	for i in size:
		if _end[i] > now and _priority[i] == priority:
			n += 1
	return n


class_name Jam
extends RefCounted
## The city-wide Jam (#26): one meter for the whole map, filled by Honking drivers and entry backlog (#27) and
## drained always (more per crossing) and per car that leaves. Each Crash leaves a Dent, a permanent loss of capacity;
## the Run hands its Dents to the next stage's Jam. Full is Gridlock.

enum Level { CLEAR, BUSY, HEAVY, GRIDLOCK }

var fill := 0.0  # 0 up to capacity()
var dents := 0  # Crashes this Run, earlier stages included
var crossings := 1  # on the map: the drain scales with them


func _init(crossing_count: int, dent_count := 0) -> void:
	crossings = crossing_count
	dents = dent_count


## The capacity left after Dents.
func capacity() -> float:
	return maxf(Tuning.JAM_CAP - dents * Tuning.DENT, Tuning.JAM_FLOOR)


## How full the Jam is, as a share of the capacity left after Dents: 0 to 1.
func share() -> float:
	return fill / capacity()


## Clear, Busy or Heavy by share(); full is Gridlock.
func level() -> Level:
	var f := share()
	if f >= 1.0:
		return Level.GRIDLOCK
	if f >= Tuning.JAM_HEAVY:
		return Level.HEAVY
	if f >= Tuning.JAM_BUSY:
		return Level.BUSY
	return Level.CLEAR


## One tick of `dt` seconds, filling at `fill_per_s` (Honking drivers and entry backlog): fill less the drain.
## Once full, it stays full: Gridlock ends the Run.
func step(fill_per_s: float, dt: float) -> void:
	if level() == Level.GRIDLOCK:
		return
	fill = clampf(fill + (fill_per_s - Tuning.JAM_DRAIN * crossings) * dt, 0.0, capacity())


## A car left the map.
func exit() -> void:
	if level() == Level.GRIDLOCK:
		return
	fill = maxf(fill - Tuning.JAM_EXIT, 0.0)


## A Crash: a Dent, for good. A full Jam stays full.
func dent() -> void:
	dents += 1
	fill = minf(fill, capacity())

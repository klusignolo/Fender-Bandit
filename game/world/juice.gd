class_name Juice
extends RefCounted
## A board's hit-stop and camera shake (#43, docs/sprites.md "Crashes and Wreckage"). Each Crash freezes the board
## for CRASH_FREEZE physics ticks and kicks the shake's trauma. World ticks it once per physics tick, steps Traffic
## as many times as it owes, and hands time_scale() to the engine, so everything run on scaled delta (the Raccoon,
## the camera, bursts and debris) freezes and slows with the board. It counts ticks, never seconds, so a freeze only
## delays the fixed-step simulation, and a seeded run still repeats exactly.

var slowmo := 1.0  # the time scale outside a freeze: the Gridlock beat's slow-mo
var trauma := 0.0  # 0 to 1; the shake goes as its square

var _freeze := 0  # ticks of freeze left
var _owed := 0.0  # Traffic steps owed, toward the next whole one
var _ticks := 0  # the shake's clock


## A Crash: freeze (crashes on the same tick don't add up) and shake.
func crash() -> void:
	_freeze = maxi(_freeze, Tuning.CRASH_FREEZE)
	kick(Tuning.SHAKE_CRASH)


## Add `amount` of trauma to the shake.
func kick(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


## One physics tick: returns the Traffic steps it owes, none while frozen.
func tick() -> int:
	_ticks += 1
	trauma = maxf(trauma - Tuning.SHAKE_DECAY / Traffic.TICK_HZ, 0.0)
	if _freeze > 0:
		_freeze -= 1
		return 0
	_owed += slowmo
	var n := floori(_owed)
	_owed -= n
	return n


## The engine time scale for the next tick: 0 while frozen.
func time_scale() -> float:
	return 0.0 if _freeze > 0 else slowmo


## The camera's offset now, in on-screen px.
func shake() -> Vector2:
	if trauma <= 0.0:
		return Vector2.ZERO
	var t := _ticks / float(Traffic.TICK_HZ) * TAU * Tuning.SHAKE_HZ
	return Vector2(sin(t), sin(t * 1.37 + 1.0)) * Tuning.SHAKE_PX * trauma * trauma

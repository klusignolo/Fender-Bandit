class_name Autopilot
extends RefCounted
## The Attract autopilot (#34, #19 "Attract"): it plays the real Raccoon by producing the same intents a player's
## input does. It tows nearby Wreckage off the road; otherwise it heads for the red Light with the most waiting
## cars and Switches it, first Switching to Yellow any Green that would cross it, and waiting for that crossing's
## box to clear. It reads Traffic and never changes it. Its feel is Tuning's AUTO_* knobs (docs/tuning.md); the
## constants below are mechanics that don't change how it plays.

const TOW_REACH_SHARE := 0.8  # it Tows from this share of TOW_RANGE, so a tick of drift can't put the Wreckage out of reach
const AT_POST := 2.0  # on-screen px: this close to a post, it's there
const TURN_NUDGE := 0.3  # how hard it steps toward a pole to face it, as an input length
const SEARCH_STEP := 20.0  # on-screen px between the rings it searches for a clear spot...
const SEARCH_MAX := 400.0  # ...out to this far
const SEARCH_DIRS := 16  # points on each ring
const CLEAR_DIRS := 8  # directions it checks for road around a spot

var traffic: Traffic

var _goal: Light  # the red Light it's working to turn Green, or null
var _greened: Dictionary[Light, float] = {}  # Light → when it turned it Green, in Traffic.time
var _towing_since := -1.0  # Traffic.time when its current Tow started; negative while not towing
var _posts: Array[Vector2] = []  # per Light: where it stands to Switch it, off the road so its cars needn't Yield


func _init(t: Traffic) -> void:
	traffic = t
	for l in t.lights:
		_posts.append(_clear_spot_near(l.pole, Tuning.RACCOON_R + Tuning.YIELD_MARGIN, 1.0))


## This tick's intent for a Raccoon at `position` with `target` as its Switch target (null if none), at
## `world_per_px` world px per on-screen px: ranges and speeds scale with it.
func decide(position: Vector2, target: Light, world_per_px: float) -> Raccoon.Intent:
	var out := Raccoon.Intent.new()
	if traffic.raccoon_stun > 0.0:
		return out
	if traffic.towing != null:
		if _towing_since < 0.0:
			_towing_since = traffic.time
		if traffic.time - _towing_since > Tuning.AUTO_TOW_GIVE_UP:
			out.tow = true  # stuck: drop it where it is
		else:
			out.move = _toward(position, _clear_spot_near(position, Tuning.TOW_HOLD + Tuning.CAR_L, world_per_px))
		return out
	_towing_since = -1.0
	var wreck := _nearest_wreckage(position, Tuning.AUTO_WRECK_REACH * world_per_px)
	if wreck != null:
		if wreck.reaches(position, Tuning.TOW_RANGE * TOW_REACH_SHARE * world_per_px):
			out.tow = true
		else:
			out.move = _toward(position, wreck.transform.origin)
		return out
	if _goal == null or _goal.state != Light.State.RED:
		if _goal != null and _goal.state == Light.State.GREEN:
			_greened[_goal] = traffic.time
		_goal = _pick_goal(position)
	if _goal == null:  # wait off the road, at the nearest post
		var near: Vector2 = _posts.reduce(func(a: Vector2, b: Vector2) -> Vector2: return a if position.distance_to(a) <= position.distance_to(b) else b)
		out.move = _toward(position, near)
		return out
	var next := _next_switch(_goal)  # null while it waits for Yellow to fall or the box to clear
	var l := next if next != null else _goal
	out.move = _toward(position, _posts[l.id])
	if next != null and target == next:
		out.switch = true
	elif next != null and position.distance_to(_posts[l.id]) < AT_POST * world_per_px:
		out.move = (l.pole - position).normalized() * TURN_NUDGE  # another pole is its target: turn toward this one
	return out


## Walk toward `to`, slowing over the last few px so it settles instead of jittering.
func _toward(from: Vector2, to: Vector2) -> Vector2:
	var d := to - from
	return d.normalized() * clampf(d.length() / Tuning.AUTO_SETTLE, 0.0, 1.0)


func _nearest_wreckage(position: Vector2, reach: float) -> Car:
	var best: Car = null
	var best_d := reach
	for c in traffic.cars:
		if c.wreckage and not c.towed:
			var d := position.distance_to(c.transform.origin)
			if d < best_d:
				best_d = d
				best = c
	return best


## The red Light worth turning Green: the most demand, less a little for the walk; null if no car wants it.
## A Green it turned on isn't cut short for it while it's young, or while it's busier and not yet long.
func _pick_goal(position: Vector2) -> Light:
	var best: Light = null
	var best_score := 0.0
	for l in traffic.lights:
		var demand := _demand(l)
		if l.state != Light.State.RED or demand == 0 or _holds_green(l, demand):
			continue
		var score := demand - position.distance_to(l.pole) / Tuning.AUTO_WALK_COST
		if best == null or score > best_score:
			best_score = score
			best = l
	return best


## The Light it must Switch next on the way to turning `goal` Green: a crossing Green first, then the goal once
## nothing crossing it is Green or Yellow and the box is clear of crossing traffic. Null while it waits.
func _next_switch(goal: Light) -> Light:
	var crossing := _crossing_lights(goal)
	for l in crossing:
		if l.state == Light.State.GREEN:
			return l
	for l in crossing:
		if l.state == Light.State.YELLOW:
			return null
	var box := traffic.net.box(_crossing_of(goal))
	for c in traffic.cars:
		if not c.wreckage and crossing.has(c.light) and Geometry2D.is_point_in_polygon(c.transform.origin, box):
			return null
	return goal


## The Lights at `goal`'s crossing whose traffic crosses its own: all but it and the one facing it.
func _crossing_lights(goal: Light) -> Array[Light]:
	var opposite := traffic.net.approaches[goal.id].opposite
	var out: Array[Light] = []
	for l in traffic.lights:
		if l != goal and l.id != opposite and _crossing_of(l) == _crossing_of(goal):
			out.append(l)
	return out


## The crossing a Light stands at.
func _crossing_of(l: Light) -> int:
	return traffic.net.approaches[l.id].crossing


## Whether `goal`, wanted by `demand` cars, can't go Green yet without cutting short a crossing Green: one that has
## run less than AUTO_MIN_GREEN, or less than AUTO_MAX_GREEN with at least as many cars wanting it.
func _holds_green(goal: Light, demand: int) -> bool:
	for l in _crossing_lights(goal):
		if l.state != Light.State.GREEN:
			continue
		var ran: float = traffic.time - _greened.get(l, -INF)
		if ran < Tuning.AUTO_MIN_GREEN or (ran < Tuning.AUTO_MAX_GREEN and _demand(l) >= demand):
			return true
	return false


## Cars wanting a Light: those on its approach short of the line, and its entry's backlog.
func _demand(l: Light) -> int:
	var n := traffic.backlog(l.id)
	for c in traffic.cars:
		if c.light == l and not c.passed_line and not c.wreckage:
			n += 1
	return n


## A spot near `from` with the road at least `clear` world px away, from the nearest ring of a search out from it;
## `from` if there's none. Standing there, towed Wreckage trailing behind is off the road too, and drops by itself.
func _clear_spot_near(from: Vector2, clear: float, world_per_px: float) -> Vector2:
	var radius := 0.0
	while radius < SEARCH_MAX:
		for i in SEARCH_DIRS:
			var p := from + Vector2.from_angle(TAU * i / SEARCH_DIRS) * radius * world_per_px
			if traffic.net.bounds.has_point(p) and _off_road_around(p, clear):
				return p
		radius += SEARCH_STEP
	return from


func _off_road_around(p: Vector2, r: float) -> bool:
	if traffic.net.on_road(p):
		return false
	for i in CLEAR_DIRS:
		if traffic.net.on_road(p + Vector2.from_angle(TAU * i / CLEAR_DIRS) * r):
			return false
	return true

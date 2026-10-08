class_name Stages
## The Stages of a Run (#29): the fixed Opening for stages 1–9, then a generator seeded by the Run.

enum Feature { TURNERS, MOTORCYCLES, SEMIS, BLOWING, ODD_JUNCTIONS, GARBAGE }

const OPENING := 9  # the last stage of the Opening
const DEBUTS := {3: Feature.TURNERS, 5: Feature.MOTORCYCLES, 6: Feature.GARBAGE, 7: Feature.BLOWING, 8: Feature.SEMIS, 9: Feature.ODD_JUNCTIONS}
const GROWS := [4, 9]  # Opening stages where a crossing attaches
const NAMES := {Feature.TURNERS: "Left turns", Feature.MOTORCYCLES: "Motorcycles", Feature.SEMIS: "Semis", Feature.BLOWING: "Blowing the red", Feature.ODD_JUNCTIONS: "T-junctions and 5-ways", Feature.GARBAGE: "Garbage trucks"}
const GROW_NAME := "Another crossing"


## Stage `n`'s setup. The Opening ignores the seed; from stage 10 the same seed gives the same StageDef.
static func def(n: int, seed_value: int) -> StageDef:
	var d := StageDef.new()
	d.number = n
	d.crossings = _crossings(n)
	d.grows = d.crossings > _crossings(n - 1)
	if n <= OPENING:
		d.debut = DEBUTS.get(n, -1)
		d.features = _unlocked(n)
	else:
		# A random draw of the unlocked features: at least the floor, which rises every FLOOR_EVERY stages.
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, n])
		var pool := _unlocked(OPENING)
		@warning_ignore("integer_division")
		var floor_n := mini(Tuning.FLOOR_START + (n - OPENING - 1) / Tuning.FLOOR_EVERY, pool.size())
		var count := rng.randi_range(floor_n, pool.size())
		while pool.size() > count:
			pool.remove_at(rng.randi_range(0, pool.size() - 1))
		d.features = pool
	# A Debut holds the knobs at the stage before's, but the feature it debuts starts at its own first value.
	var k_stage := n - 1 if n <= OPENING and (d.debut != -1 or d.grows) else n
	d.gap = _curve(Tuning.K_GAP, k_stage, 1)
	d.speed = _curve(Tuning.K_SPEED, k_stage, 1)
	d.patience = _curve(Tuning.K_PATIENCE, k_stage, 1)
	var turner_stage: int = DEBUTS.find_key(Feature.TURNERS)  # the Turner share's first value is its Debut's
	if n >= turner_stage:
		d.turners = _curve(Tuning.K_TURNERS, maxi(k_stage, turner_stage), turner_stage)
	if d.features.has(Feature.MOTORCYCLES):
		d.motorcycles = Tuning.MOTO_SHARE
	if d.features.has(Feature.SEMIS):
		d.semis = Tuning.SEMI_SHARE
	if d.features.has(Feature.GARBAGE):
		d.garbage = Tuning.GARBAGE_SHARE
	d.target_len = Tuning.TARGET_LEN
	return d


## What's new at a stage, for the Tally card before it: its Debut, then a crossing attaching.
static func news(d: StageDef) -> PackedStringArray:
	var out := PackedStringArray()
	if d.debut != -1:
		out.append(NAMES[d.debut])
	if d.grows:
		out.append(GROW_NAME)
	return out


## A knob's value at stage `s`: linear from stage `first` to stage 9, then easing toward its far limit.
static func _curve(k: Array[float], s: int, first: int) -> float:
	if s <= OPENING:
		return lerpf(k[0], k[1], float(s - first) / (OPENING - first))
	return k[2] + (k[1] - k[2]) * pow(Tuning.K_EASE, s - OPENING)


## The features the Opening has debuted by stage `n`, in enum order.
static func _unlocked(n: int) -> Array[Feature]:
	var out: Array[Feature] = []
	for s: int in DEBUTS:
		if s <= n:
			out.append(DEBUTS[s])
	out.sort()
	return out


## How many crossings the map has at stage `n`: the Opening's, then one more every CROSSING_EVERY stages.
static func _crossings(n: int) -> int:
	var c := 1
	for s: int in GROWS:
		if s <= n:
			c += 1
	if n > OPENING:
		@warning_ignore("integer_division")
		c = mini(c + (n - OPENING) / Tuning.CROSSING_EVERY, Tuning.CROSSINGS_MAX)
	return c

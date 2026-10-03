class_name StageDef
extends RefCounted
## One Stage's setup (#29), from Stages: its knobs, which features are on, its Debut, and how many crossings.
## Traffic takes it, and works out the Quota from target_len and the entries its map really has.

var number := 1
var gap := 0.0  # spawn gap per entry, seconds
var speed := 1.0  # car speed multiplier
var patience := 0.0  # seconds a front driver waits at red before it's out of Patience
var turners := 0.0  # Turner share, while Turners are on
var target_len := 0.0  # seconds the stage should last if traffic flows; the Quota is derived from it
var features: Array[Stages.Feature] = []  # on this stage
var debut := -1  # the Stages.Feature this stage introduces, or -1
var crossings := 1  # how many crossings the map should have (built in the City tickets)
var grows := false  # a crossing attaches this stage

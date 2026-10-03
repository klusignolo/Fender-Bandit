class_name Run
extends RefCounted
## One Run (#28): the score, Combo, stage and Dents that outlive any one stage's Traffic, and the stage's
## stats for the results card. It listens to each stage's Traffic, handed to it by attach().

signal combo_stepped(multiplier: int)  # Combo reached a new multiplier step: combo_up (docs/audio.md)
signal combo_broken(lost: int)  # a Crash reset a Combo above 0: combo_break (docs/audio.md)

var score := 0
var combo := 0  # cars out since the last Crash
var stage := 1
var dents: int:  # Crashes this Run, earlier stages included. The stage's Jam keeps the count; hand it to the next stage's Traffic.
	get:
		return _traffic.jam.dents if _traffic != null else 0
var crashes := 0  # this stage's Crashes: one per crashed signal, so a car into Wreckage is one more
var best_combo := 0  # this stage's highest Combo

var _stage_start_score := 0

var _traffic: Traffic  # the current stage's


## Listen to a stage's Traffic, and keep it as the current stage's.
func attach(traffic: Traffic) -> void:
	_traffic = traffic
	traffic.car_exited.connect(_on_car_exited)
	traffic.crashed.connect(_on_crashed)
	traffic.towed.connect(_on_towed)


## On to the next stage: its stats start over, and the score, Combo and Dents carry on. Attach its Traffic next.
func next_stage() -> void:
	stage += 1
	crashes = 0
	best_combo = combo
	_stage_start_score = score


## Points scored this stage.
func stage_score() -> int:
	return score - _stage_start_score


## What each exit's score is multiplied by: 1, and 1 more each COMBO_STEP of Combo.
func multiplier() -> int:
	@warning_ignore("integer_division")
	return 1 + combo / Tuning.COMBO_STEP


func _on_car_exited(_car: Car) -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	score += Tuning.EXIT_SCORE * multiplier()
	if combo % Tuning.COMBO_STEP == 0:
		combo_stepped.emit(multiplier())


func _on_crashed(_a: Car, _b: Car, _at: Vector2) -> void:
	crashes += 1
	var lost := combo
	combo = 0
	if lost > 0:
		combo_broken.emit(lost)


func _on_towed(_car: Car, off_road: bool) -> void:
	if off_road:
		score += Tuning.TOW_BONUS

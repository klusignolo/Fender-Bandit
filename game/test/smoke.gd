extends SceneTree
## The headless whole-game smoke test (#34, seam 3 in #19). Run it with game/tools/smoke.sh, or:
##   godot --headless --fixed-fps 60 --path game -s test/smoke.gd [-- --seed=N]
## Boots Main with the Attract autopilot playing the Raccoon until the Run reaches stage STAGES (or AUTO_FOR
## seconds pass), so stages clear and the Tally card runs. Then the Raccoon goes idle, and the Run must end in
## Gridlock within IDLE_FOR seconds: an idle Raccoon gridlocks in about 30s (#34). A Gridlock while the autopilot
## plays passes too. It exits non-zero at the first engine or script error logged, or if no Gridlock came. Main prints the seed it booted with; pass it back with --seed to repeat a run exactly.

const Runner := preload("res://test/run.gd")
const STAGES := 3
const AUTO_FOR := 300.0  # simulated seconds
const IDLE_FOR := 45.0  # simulated seconds

var _errors := Runner.ErrorCounter.new()
var _main: Node
var _clock := 0.0  # seconds simulated
var _idle_at := -1.0  # when the Raccoon went idle; negative while the autopilot plays
var _start_ms := 0
var _done := false


func _initialize() -> void:
	OS.add_logger(_errors)
	_start_ms = Time.get_ticks_msec()
	_main = load("res://main/main.tscn").instantiate()
	_main.autopilot = true  # as --autopilot: Main isn't ready until the first frame
	root.add_child(_main)
	_main.run_over.connect(_on_run_over)


func _physics_process(delta: float) -> bool:
	if _done:
		return false
	_clock += delta
	if _errors.count > 0:
		_finish("FAIL: an error was logged")
		return false
	if _idle_at < 0.0 and (_main.run.stage >= STAGES or _clock >= AUTO_FOR):
		_idle_at = _clock
		print("Smoke: the Raccoon goes idle at stage %d, %.1fs" % [_main.run.stage, _clock])
		_main.set_autopilot(false)
	elif _idle_at >= 0.0 and _clock - _idle_at > IDLE_FOR:
		_finish("FAIL: no Gridlock within %.0fs of the Raccoon going idle" % IDLE_FOR)
	return false


func _on_run_over(run: Run) -> void:
	var idle := "%.1fs after the Raccoon went idle" % (_clock - _idle_at) if _idle_at >= 0.0 else "while the autopilot played"
	_finish("Gridlock at stage %d, %.1fs in, %s; score %d" % [run.stage, _clock, idle, run.score])


func _finish(what: String) -> void:
	if _done:
		return
	_done = true
	var ok := not what.begins_with("FAIL") and _errors.count == 0
	if _errors.count > 0:
		printerr("FAIL: %d error(s) logged; the last: %s" % [_errors.count, _errors.last])
	print("Smoke: %s. %s in %.1fs of real time" % [what, "PASS" if ok else "FAIL", (Time.get_ticks_msec() - _start_ms) / 1000.0])
	quit(0 if ok else 1)

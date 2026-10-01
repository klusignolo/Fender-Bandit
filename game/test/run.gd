extends SceneTree
## The headless test runner (#13 §10, #19 Testing Decisions). Run it with game/tools/test.sh, or:
##   godot --headless --path game -s test/run.gd [-- --only=<file or test name part>]
## Runs every test_* method of every res://test/test_*.gd (each extends TestCase) and exits non-zero
## if any assertion fails or any engine or script error is logged while a test runs.


## Counts the errors the engine logs, so a test that hits a script error fails instead of passing quietly.
class ErrorCounter extends Logger:
	var count := 0
	var last := ""
	var _lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		count += 1
		last = "%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function]
		_lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var passed := 0
	var failed: PackedStringArray = []
	for path in _test_files():
		var test_script := load(path) as GDScript
		if test_script == null or not test_script.can_instantiate():
			failed.append("%s: doesn't load" % path)
			continue
		for m in test_script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_") or (only != "" and not (path + ":" + name).contains(only)):
				continue
			var t: TestCase = test_script.new()
			var before := errors.count
			t.call(name)
			var label := "%s:%s" % [path.get_file(), name]
			if not t.failures.is_empty():
				failed.append("%s\n    %s" % [label, "\n    ".join(t.failures)])
			elif errors.count > before:
				failed.append("%s\n    logged an error: %s" % [label, errors.last])
			else:
				passed += 1
	for f in failed:
		printerr("FAIL ", f)
	print("%d passed, %d failed" % [passed, failed.size()])
	quit(1 if failed.size() > 0 or passed == 0 else 0)


func _test_files() -> PackedStringArray:
	var out: PackedStringArray = []
	for f in DirAccess.get_files_at("res://test"):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append("res://test/" + f)
	out.sort()
	return out

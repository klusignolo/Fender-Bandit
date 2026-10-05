extends Node
## The Scores autoload (#36, #19 "Autoloads"): the game's High-score table and Music On/Off setting, kept in user
## storage. That's a file beside the Windows exe's user data, and IndexedDB in the browser, best effort.

const PATH := "user://scores.cfg"

var table := ScoreTable.new(PATH)


## Keep the table at `path` instead, from now on: the smoke test's, so it never touches the real one.
func use(path: String) -> void:
	table = ScoreTable.new(path)

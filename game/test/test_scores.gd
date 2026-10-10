extends TestCase
## The High-score table (#36, #19 stories 17–18): ScoreTable's ranking and its save file. The Scores autoload
## only holds one of these on user://scores.cfg.

const PATH := "user://test_scores.cfg"


func _fresh() -> ScoreTable:
	DirAccess.remove_absolute(PATH)
	return ScoreTable.new(PATH)


func _scores(t: ScoreTable) -> Array:
	return t.entries.map(func(e: Dictionary) -> int: return e.score)


func test_an_empty_table_ranks_any_score_but_zero() -> void:
	var t := _fresh()
	check_eq(t.rank_of(1), 0, "a point is enough on an empty table")
	check_eq(t.rank_of(0), -1, "a Run that scored nothing doesn't rank")
	check(not t.ranks(0), "nor qualify")
	DirAccess.remove_absolute(PATH)


func test_entries_keep_best_first_and_a_tie_goes_below() -> void:
	var t := _fresh()
	check_eq(t.add("AAA", 500), 0, "first")
	check_eq(t.add("BBB", 900), 0, "a better score goes on top")
	check_eq(t.add("CCC", 500), 2, "a tie goes below the score already there")
	check_eq(t.add("DDD", 700), 1, "between")
	check_eq(_scores(t), [900, 700, 500, 500], "best first")
	check_eq(t.entries[3].initials, "CCC", "the tie is the newer one")
	DirAccess.remove_absolute(PATH)


func test_only_the_top_ten_are_kept() -> void:
	var t := _fresh()
	for i in 10:
		t.add("AAA", (i + 1) * 100)
	check_eq(t.entries.size(), 10, "ten")
	check_eq(t.rank_of(100), -1, "a tie with tenth place doesn't get in")
	check(not t.ranks(50), "nor anything lower")
	check_eq(t.add("ZZZ", 50), -1, "and isn't added")
	check_eq(t.add("NEW", 150), 9, "a better score takes tenth place...")
	check_eq(t.entries.size(), 10, "...and pushes the last one out")
	check_eq(t.entries[9].score, 150, "the old tenth is gone")
	DirAccess.remove_absolute(PATH)


func test_the_table_and_music_survive_a_reload() -> void:
	var t := _fresh()
	t.add("K.L", 1200)
	t.add("A B", 300)
	t.set_music(false)
	var again := ScoreTable.new(PATH)
	check_eq(again.entries, t.entries, "the same table from the file")
	check(not again.music, "and the Music setting")
	DirAccess.remove_absolute(PATH)


func test_ties_keep_their_order_through_a_reload() -> void:
	var t := _fresh()
	for i in 8:
		t.add("T%d" % i, 100)
	var again := ScoreTable.new(PATH)
	check_eq(again.entries.map(func(e: Dictionary) -> String: return e.initials), ["T0", "T1", "T2", "T3", "T4", "T5", "T6", "T7"], "oldest tie first, as saved")
	DirAccess.remove_absolute(PATH)


func test_no_file_means_an_empty_table_with_music_on() -> void:
	var t := _fresh()
	check_eq(t.entries.size(), 0, "empty")
	check(t.music, "music on")


func test_a_mangled_file_keeps_only_valid_entries() -> void:
	DirAccess.remove_absolute(PATH)
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "format", ScoreTable.FORMAT)
	cfg.set_value("scores", "table", [
		{"initials": "OK", "score": 10},
		{"initials": 5, "score": 20},
		"nonsense",
		{"initials": "TOOLONG", "score": 30},
		{"initials": "NEG", "score": -4},
	])
	cfg.set_value("settings", "music", "loud")
	cfg.save(PATH)
	var t := ScoreTable.new(PATH)
	check_eq(t.entries, [{"initials": "TOO", "score": 30}, {"initials": "OK", "score": 10}] as Array[Dictionary], "valid ones, trimmed and sorted")
	check(t.music, "a bad setting falls back to on")
	cfg.set_value("scores", "table", "not a list")
	cfg.save(PATH)
	check_eq(ScoreTable.new(PATH).entries.size(), 0, "a table that isn't a list is empty")
	DirAccess.remove_absolute(PATH)


func test_scores_from_before_honk_scoring_are_dropped_but_the_music_setting_stays() -> void:
	# #45 changed what an exit scores, so older scores can't be compared: a table saved without FORMAT starts empty.
	DirAccess.remove_absolute(PATH)
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "table", [{"initials": "OLD", "score": 9000}])
	cfg.set_value("settings", "music", false)
	cfg.save(PATH)
	var t := ScoreTable.new(PATH)
	check_eq(t.entries.size(), 0, "the old scores are gone")
	check(not t.music, "the Music setting is kept")
	t.add("NEW", 100)
	check_eq(ScoreTable.new(PATH).entries.size(), 1, "a new score saves with the format and reloads")
	DirAccess.remove_absolute(PATH)


func test_the_controls_card_is_remembered_as_seen() -> void:
	DirAccess.remove_absolute(PATH)
	var t := ScoreTable.new(PATH)
	check(not t.controls_seen, "a fresh save hasn't seen the controls card")
	t.saw_controls()
	check(ScoreTable.new(PATH).controls_seen, "seen, through a reload")
	DirAccess.remove_absolute(PATH)

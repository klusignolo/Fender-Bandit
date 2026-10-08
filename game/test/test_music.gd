extends TestCase
## The music (#38, docs/audio.md "Music cues"): MusicMix picks the track, glides the groove's tempo with the Jam,
## and mixes its level from the ducks, Pause and Music On/Off. Also the music files, BoardCues' jam cue and the
## Pause menu's Music row.


func _glide(m: MusicMix, seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		m.step(1.0 / 60.0)


# --- tracks -------------------------------------------------------------------------

func test_a_new_track_starts_but_the_same_one_plays_on() -> void:
	var m := MusicMix.new()
	check(m.play(MusicMix.Track.THEME), "the Theme starts")
	check(not m.play(MusicMix.Track.THEME), "asked again, it plays on: Results to the table to Attract")
	check(m.play(MusicMix.Track.GROOVE), "the groove takes over")
	check(not m.play(MusicMix.Track.GROOVE), "and runs on across the stages")
	m.stop()
	check(m.play(MusicMix.Track.GROOVE), "after a stop, it starts again")


# --- tempo --------------------------------------------------------------------------

func test_the_groove_glides_up_at_busy_and_heavy_and_back_down() -> void:
	var m := MusicMix.new()
	m.play(MusicMix.Track.GROOVE)
	check_eq(m.pitch, 1.0, "the groove starts at Clear's tempo")
	m.set_level(Jam.Level.BUSY)
	_glide(m, Tuning.MUSIC_GLIDE / 2.0)
	check(m.pitch > Tuning.MUSIC_PITCH[0] and m.pitch < Tuning.MUSIC_PITCH[1], "halfway up to Busy: %s" % m.pitch)
	_glide(m, Tuning.MUSIC_GLIDE / 2.0 + 0.05)
	check_near(m.pitch, Tuning.MUSIC_PITCH[1], 0.0001, "at Busy after MUSIC_GLIDE")
	m.set_level(Jam.Level.HEAVY)
	_glide(m, Tuning.MUSIC_GLIDE + 0.05)
	check_near(m.pitch, Tuning.MUSIC_PITCH[2], 0.0001, "at Heavy")
	m.set_level(Jam.Level.CLEAR)
	_glide(m, Tuning.MUSIC_GLIDE + 0.05)
	check_near(m.pitch, Tuning.MUSIC_PITCH[0], 0.0001, "back to Clear as the Jam clears")


func test_gridlock_holds_heavys_tempo() -> void:
	var m := MusicMix.new()
	m.play(MusicMix.Track.GROOVE)
	m.set_level(Jam.Level.GRIDLOCK)
	_glide(m, Tuning.MUSIC_GLIDE + 0.05)
	check_near(m.pitch, Tuning.MUSIC_PITCH[2], 0.0001, "no step past Heavy")


func test_the_theme_keeps_its_own_tempo() -> void:
	var m := MusicMix.new()
	m.play(MusicMix.Track.GROOVE)
	m.set_level(Jam.Level.HEAVY)
	_glide(m, Tuning.MUSIC_GLIDE + 0.05)
	m.play(MusicMix.Track.THEME)
	check_eq(m.pitch, 1.0, "the Theme plays at 1.0")
	m.set_level(Jam.Level.BUSY)
	_glide(m, Tuning.MUSIC_GLIDE)
	check_eq(m.pitch, 1.0, "and an Attract board's Jam doesn't move it")
	m.play(MusicMix.Track.GROOVE)
	check_eq(m.pitch, 1.0, "a new Run's groove starts at Clear's tempo")


# --- level --------------------------------------------------------------------------

func test_the_level_takes_the_deepest_duck() -> void:
	var m := MusicMix.new()
	m.play(MusicMix.Track.GROOVE)
	check_eq(m.volume_db(0.0, false), 0.0, "the groove at full level")
	check_eq(m.volume_db(Tuning.DUCK_STINGER, false), Tuning.DUCK_STINGER, "ducked under the stinger")
	check_eq(m.volume_db(0.0, true), Tuning.DUCK_PAUSE, "ducked under Pause")
	check_eq(m.volume_db(Tuning.DUCK_CRASH[0], true), minf(Tuning.DUCK_PAUSE, Tuning.DUCK_CRASH[0]), "the deeper of the two")


func test_attract_plays_the_theme_at_its_own_level() -> void:
	var m := MusicMix.new()
	m.play(MusicMix.Track.THEME, true)
	check_eq(m.volume_db(0.0, false), Tuning.ATTRACT_MUSIC_DB, "Attract's level")
	m.play(MusicMix.Track.THEME)
	check_eq(m.volume_db(0.0, false), 0.0, "the Theme over the Results at full level")


func test_music_off_is_silent_and_on_brings_it_back() -> void:
	var m := MusicMix.new()
	m.play(MusicMix.Track.GROOVE)
	m.on = false
	check(m.volume_db(0.0, false) <= MusicMix.SILENT, "off is silent")
	m.on = true
	check_eq(m.volume_db(0.0, false), 0.0, "on again, back at full level")
	m.stop()
	check(m.volume_db(0.0, false) <= MusicMix.SILENT, "no track is silent")


# --- files --------------------------------------------------------------------------

func test_both_tracks_are_ogg_loops_that_skip_their_intro() -> void:
	for track: MusicMix.Track in MusicMix.FILES:
		var path := MusicMix.path(track)
		var s := load(path) as AudioStreamOggVorbis
		if not check(s != null, "%s loads as an OGG" % path):
			continue
		check(s.loop, "%s loops" % path)
		check(s.loop_offset > 0.0, "%s loops back past its start (never 0: docs/audio.md)" % path)
		check(s.loop_offset < s.get_length() - 4.0, "%s has a loop of some length" % path)
		check_eq(s.bpm, 0.0, "%s leaves bpm at 0: the file ends at its loop end" % path)


# --- the board's jam cue -------------------------------------------------------------

func test_board_cues_report_each_jam_level_and_clear_at_the_tally() -> void:
	var t := straight_traffic(1)
	var cues := BoardCues.new(t, Run.new())
	var heard: Array[Jam.Level] = []
	cues.jam.connect(func(l: Jam.Level) -> void: heard.append(l))
	t.jam_level_changed.emit(Jam.Level.BUSY)
	t.jam_level_changed.emit(Jam.Level.CLEAR)
	t.stage_cleared.emit()
	check_eq(heard, [Jam.Level.BUSY, Jam.Level.CLEAR, Jam.Level.CLEAR] as Array[Jam.Level], "every change, then Clear at the Tally")


# --- the Pause menu ------------------------------------------------------------------

func test_the_pause_menu_has_the_music_row_between_resume_and_quit() -> void:
	var menu := PauseMenu.new(true)
	check_eq(menu.ROWS.size(), 3, "three rows")
	check_eq(menu.row_text(PauseMenu.Row.MUSIC), "MUSIC: ON", "on")
	menu.set_music(false)
	check_eq(menu.row_text(PauseMenu.Row.MUSIC), "MUSIC: OFF", "off")
	menu.move(1)
	check_eq(menu.row, PauseMenu.Row.MUSIC, "down from Resume")
	menu.move(1)
	check_eq(menu.row, PauseMenu.Row.QUIT, "then Quit to title")
	menu.free()


# --- web autoplay ---------------------------------------------------------------------

func test_the_autoplay_probe_reads_any_true_answer_from_the_browser() -> void:
	# On itch the browser said yes, but the bridge handed back 1, not true, so the Theme waited for a press (#45).
	var audio := load("res://audio/audio.gd")
	for yes: Variant in [true, 1, 1.0]:
		check(audio.js_true(yes), "%s (%s) counts as yes" % [yes, type_string(typeof(yes))])
	for no: Variant in [false, 0, 0.0, null, ""]:
		check(not audio.js_true(no), "%s (%s) counts as no" % [no, type_string(typeof(no))])

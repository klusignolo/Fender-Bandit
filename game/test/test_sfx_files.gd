extends TestCase
## The sound list (#37, docs/audio.md): every sound Audio knows is a WAV that tools/make_sfx.gd wrote, short, and
## looping only where the register says so (the Tow scrape).


func test_every_sound_is_a_clip() -> void:
	for sound: StringName in Sfx.SOUNDS:
		var path := Sfx.path(sound)
		var s := load(path) as AudioStreamWAV
		if not check(s != null, "%s loads from %s" % [sound, path]):
			continue
		var length := s.get_length()
		check(length > 0.02 and length < 3.0, "%s lasts %.2fs" % [sound, length])
		var loops := s.loop_mode != AudioStreamWAV.LOOP_DISABLED
		check_eq(loops, sound == &"tow_scrape", "%s loops" % sound)


func test_the_register_and_audio_agree_on_the_sounds() -> void:
	var doc := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../docs/audio.md"))
	if not check(doc != "", "docs/audio.md reads"):
		return
	for sound: StringName in Sfx.SOUNDS:
		check(doc.contains("`%s`" % sound) or (sound.begins_with("crash_") and doc.contains("`crash_1`, `crash_2`, `crash_3`")),
				"%s is in docs/audio.md's sound list" % sound)


func test_every_sound_has_a_priority_and_a_level() -> void:
	for sound: StringName in Sfx.SOUNDS:
		var row: Array = Sfx.SOUNDS[sound]
		check(row.size() == 2 and row[0] is int and (row[1] is float or row[1] is int), "%s: [priority, dB]" % sound)

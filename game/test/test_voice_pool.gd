extends TestCase
## The SFX voice pool (#37, docs/audio.md "Playback rules"): SFX_VOICES voices, a Honk cap, a retrigger guard, and
## priority when it's full, so a busy stage 9 stays readable and the player's own actions are always heard.

const P := VoicePool.Priority


func _full_of(pool: VoicePool, priority: P, length: float) -> void:
	for i in pool.size:
		check(pool.request(StringName("filler_%d" % i), priority, length, i * 0.001) >= 0, "filler %d gets a voice" % i)


func test_each_sound_gets_its_own_free_voice() -> void:
	var pool := VoicePool.new(4)
	var got := []
	for i in 4:
		got.append(pool.request(StringName("s%d" % i), P.OTHER, 1.0, 0.0))
	got.sort()
	check_eq(got, [0, 1, 2, 3], "four voices, one each")


func test_a_voice_frees_when_its_sound_ends() -> void:
	var pool := VoicePool.new(1)
	check_eq(pool.request(&"a", P.OTHER, 0.5, 0.0), 0, "the one voice")
	check_eq(pool.request(&"b", P.OTHER, 0.5, 0.2), -1, "busy with as important a sound: an Other doesn't cut an Other")
	check_eq(pool.request(&"b", P.OTHER, 0.5, 0.6), 0, "free again once the first ended")


func test_the_same_sound_cant_start_again_within_the_retrigger_guard() -> void:
	var pool := VoicePool.new(4)
	check(pool.request(&"crash", P.CRASH, 1.0, 0.0) >= 0, "the first crunch")
	check_eq(pool.request(&"crash", P.CRASH, 1.0, Tuning.SFX_RETRIGGER * 0.5), -1, "a second within the guard is dropped")
	check(pool.request(&"other", P.OTHER, 1.0, Tuning.SFX_RETRIGGER * 0.5) >= 0, "another sound isn't held up")
	check(pool.request(&"crash", P.CRASH, 1.0, Tuning.SFX_RETRIGGER * 1.5) >= 0, "past the guard it plays again")


func test_honks_are_capped() -> void:
	var pool := VoicePool.new(16)
	for i in Tuning.HONK_MAX:
		check(pool.request(StringName("honk_%d" % i), P.HONK, 1.0, i * 0.1) >= 0, "Honk %d sounds" % i)
	check_eq(pool.request(&"honk_x", P.HONK, 1.0, 0.5), -1, "one more Honk at once carries no news: dropped")
	check(pool.request(&"honk_y", P.HONK, 1.0, 1.05) >= 0, "once the first has ended, a Honk sounds again")


func test_a_full_pool_cuts_the_oldest_of_the_lowest_priority() -> void:
	var pool := VoicePool.new(3)
	var other_old := pool.request(&"a", P.OTHER, 5.0, 0.0)
	pool.request(&"b", P.HONK, 5.0, 0.1)
	pool.request(&"c", P.OTHER, 5.0, 0.2)
	check_eq(pool.request(&"crash", P.CRASH, 1.0, 0.3), other_old, "a Crash takes the oldest Other's voice")
	check_eq(pool.request(&"hit", P.HIT, 1.0, 0.4), 2, "then the other Other's")
	check_eq(pool.request(&"switch", P.PLAYER, 1.0, 0.5), 1, "then the Honk's")
	check_eq(pool.request(&"late", P.OTHER, 1.0, 0.6), -1, "an Other can't cut anything left: dropped")


func test_the_players_own_actions_are_heard_on_a_busy_stage() -> void:
	var pool := VoicePool.new(Tuning.SFX_VOICES)
	_full_of(pool, P.OTHER, 30.0)
	var now := 1.0
	for i in 80:  # stage 9 at its worst: Honks every 50 ms, a Crash every half second, Blowing the red every second
		now += 0.05
		pool.request(StringName("honk_%d" % (i % 2)), P.HONK, 0.8, now)
		if i % 20 == 0:
			pool.request(&"blow_red", P.BLOW, 1.0, now)
		if i % 10 == 0:
			pool.request(StringName("crash_%d" % (i % 3)), P.CRASH, 1.2, now)
		check(pool.request(StringName("switch_%d" % (i % 2)), P.PLAYER, 0.2, now + 0.01) >= 0, "Switch %d is heard" % i)
		check(pool.request(&"dash", P.PLAYER, 0.3, now + 0.02) >= 0 or i % 2 == 1, "Dash %d is heard" % i)
		check(pool.playing(P.HONK, now + 0.02) <= Tuning.HONK_MAX, "Honks stay capped")

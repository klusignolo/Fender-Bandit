extends Node
## The Audio autoload (#37, docs/audio.md "Playback rules"): a music player (#38 gives it the Theme and groove), a
## stinger player, a Tow-scrape loop and a pool of SFX_VOICES SFX players booked by VoicePool. Main has it watch each
## stage's World: a BoardCues turns the board's signals into cues. An Attract board is muted (#19 story 80), so
## Attract has no SFX; the UI's own sounds still play. Ducking is done with player volume, never bus effects, and
## every clip plays in the default playback mode (Sample on the web): see docs/audio.md "Web limits". In the browser
## nothing sounds until the first press, which is also the press that leaves Attract.

signal played(sound: StringName)  # a sound started: the smoke test listens

var _pool := VoicePool.new(Tuning.SFX_VOICES)
var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary[StringName, AudioStream] = {}
var _music := AudioStreamPlayer.new()
var _stinger := AudioStreamPlayer.new()
var _scrape := AudioStreamPlayer.new()
var _cues: BoardCues  # the watched board's
var _board_muted := false
var _clock := 0.0  # seconds since boot, Pause included: VoicePool's time
var _duck_db := 0.0  # how far the music is ducked, until _duck_until
var _duck_until := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sounds finish over Pause and the frozen boards
	for sound: StringName in Sfx.SOUNDS:
		_streams[sound] = load(Sfx.path(sound))
	for i in Tuning.SFX_VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	add_child(_music)
	_stinger.stream = _streams[&"stinger"]
	_stinger.volume_db = Sfx.db(&"stinger")
	add_child(_stinger)
	_scrape.stream = _streams[&"tow_scrape"]
	_scrape.volume_db = Sfx.db(&"tow_scrape")
	add_child(_scrape)


## Stop every sound. The audio server lets go of a stopped clip on its next mix, so quitting straight after it
## still leaks the clips that were playing: give it a moment first (test/smoke.gd does).
func silence() -> void:
	for p: AudioStreamPlayer in _voices + [_music, _stinger, _scrape]:
		p.stop()


func _process(delta: float) -> void:
	_clock += delta
	_scrape.stream_paused = get_tree().paused
	_music.volume_db = _duck_db if _clock < _duck_until else 0.0


## Play SFX `sound` (a name from Sfx.SOUNDS) at `pitch`, if VoicePool gives it a voice. Returns whether it plays.
func play(sound: StringName, pitch := 1.0) -> bool:
	if sound == &"stinger":
		_scrape.stop()  # the board has frozen under the Tally card
		_stinger.play()
		_duck(Tuning.DUCK_STINGER, _stinger.stream.get_length())
		played.emit(sound)
		return true
	var stream := _streams[sound]
	var v := _pool.request(sound, Sfx.priority(sound), stream.get_length() / pitch, _clock)
	if v < 0:
		return false
	var p := _voices[v]
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = Sfx.db(sound)
	p.play()
	if Sfx.priority(sound) == VoicePool.Priority.CRASH:
		_duck(Tuning.DUCK_CRASH[0], Tuning.DUCK_CRASH[1])
	played.emit(sound)
	return true


## Listen to `world`'s board from now on, and drop the last one's. `muted` (an Attract board) plays none of its SFX.
## Call it once the World is in the tree: its Raccoon is built in _ready. A stage whose crossing attached plays the Reveal.
func watch(world: World, muted: bool) -> void:
	_scrape.stop()
	_board_muted = muted
	_cues = BoardCues.new(world.traffic, world.run, world.raccoon)
	_cues.cue.connect(_on_cue)
	_cues.scrape.connect(_on_scrape)
	if world.reveals():
		_on_cue(&"reveal", 1.0)


## Gridlock: the record scratch cuts the music dead under a chorus of horns, then the glass shatters.
func gridlock() -> void:
	_scrape.stop()
	_music.stop()
	play(&"gridlock_scratch")
	play(&"gridlock_horns")
	get_tree().create_timer(Tuning.SHATTER_DELAY, true, false, true).timeout.connect(play.bind(&"gridlock_shatter"))


func _duck(db: float, seconds: float) -> void:
	_duck_db = minf(db, _duck_db) if _clock < _duck_until else db
	_duck_until = maxf(_duck_until, _clock + seconds)


func _on_cue(sound: StringName, pitch: float) -> void:
	if not _board_muted:
		play(sound, pitch)


func _on_scrape(on: bool) -> void:
	if on and not _board_muted:
		_scrape.play()
	else:
		_scrape.stop()

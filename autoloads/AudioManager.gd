extends Node
## Central sound-effect and music player. Preloads procedurally-generated WAV
## SFX (see tools/gen_audio.py) and looping ambient music tracks (see
## tools/gen_music.py) and plays them through dedicated voice pools so
## overlapping sounds don't cut each other off.
##
## Defensive by design: if a sound file is missing (e.g. assets not yet
## imported by the editor), play() and play_music() are silent no-ops.

const SOUND_NAMES: Array[String] = [
	"hit", "crit", "kill", "hurt", "move", "select", "ability",
	"fire", "frost", "heal", "enrage", "levelup", "victory",
	"defeat", "descend", "lava",
]

const MUSIC_NAMES: Array[String] = [
	"music_title", "music_stone", "music_obsidian", "music_void",
]

const VOICE_COUNT: int = 8           # simultaneous SFX channels
const AUDIO_DIR: String = "res://assets/audio/"

var _streams: Dictionary = {}        # name -> AudioStream
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0

# Two music players so we can crossfade between them cleanly. The "active"
# one is whichever is currently playing the foreground track; the other is
# idle until the next swap.
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _music_active: AudioStreamPlayer = null
var _music_fade_tween: Tween = null
var _current_music: String = ""

var sfx_enabled: bool = true
var music_enabled: bool = true
var master_volume_db: float = -6.0   # slight headroom
var music_volume_db: float = -12.0   # background — well under SFX

func _ready() -> void:
	# Preload available streams (SFX + music)
	for name: String in SOUND_NAMES:
		_try_load_stream(name)
	for name: String in MUSIC_NAMES:
		_try_load_stream(name)
	# Build the SFX voice pool
	for i: int in range(VOICE_COUNT):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_voices.append(p)
	# Dedicated music players (two, for crossfade)
	_music_a = _make_music_player()
	_music_b = _make_music_player()

func _try_load_stream(name: String) -> void:
	var path: String = AUDIO_DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		return
	# Looping streams for music — Godot's AudioStreamWAV has a `loop_mode`
	# property. We only force-loop the music files; SFX stay one-shot.
	if name.begins_with("music_") and stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(stream as AudioStreamWAV).loop_begin = 0
	_streams[name] = stream

func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Master"
	p.volume_db = -80.0
	add_child(p)
	return p

func play(sound_name: String, pitch_variation: float = 0.0, volume_db: float = 0.0) -> void:
	## Play a one-shot SFX by name. pitch_variation adds ± randomness so
	## repeated sounds (hits, footsteps) don't feel robotic.
	if not sfx_enabled:
		return
	var stream: AudioStream = _streams.get(sound_name)
	if stream == null:
		return  # silent no-op for missing sounds
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = master_volume_db + volume_db
	if pitch_variation > 0.0:
		voice.pitch_scale = 1.0 + GameRng.randf_range(-pitch_variation, pitch_variation)
	else:
		voice.pitch_scale = 1.0
	voice.play()

func play_music(music_name: String, fade_s: float = 1.5) -> void:
	## Crossfade to a looping music track. If the same track is already
	## playing, do nothing. Safe to call from scene _ready().
	if _current_music == music_name and _music_active != null and _music_active.playing:
		return
	_current_music = music_name
	if not music_enabled:
		return
	var stream: AudioStream = _streams.get(music_name)
	if stream == null:
		return  # silent no-op
	# Pick the idle player as the new active one
	var new_player: AudioStreamPlayer = _music_b if _music_active == _music_a else _music_a
	var old_player: AudioStreamPlayer = _music_active
	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()
	_music_active = new_player
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.set_parallel(true)
	_music_fade_tween.tween_property(new_player, "volume_db", music_volume_db, fade_s)
	if old_player != null and old_player.playing:
		_music_fade_tween.tween_property(old_player, "volume_db", -80.0, fade_s)
		_music_fade_tween.chain().tween_callback(old_player.stop)

func stop_music(fade_s: float = 0.8) -> void:
	## Fade-out and stop any currently playing music track.
	_current_music = ""
	if _music_active == null or not _music_active.playing:
		return
	if _music_fade_tween != null and _music_fade_tween.is_valid():
		_music_fade_tween.kill()
	var p: AudioStreamPlayer = _music_active
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(p, "volume_db", -80.0, fade_s)
	_music_fade_tween.tween_callback(p.stop)

func music_for_floor(floor_num: int) -> String:
	## Map floor number to the matching tier music track.
	if floor_num <= 6:
		return "music_stone"
	if floor_num <= 12:
		return "music_obsidian"
	return "music_void"

func set_enabled(on: bool) -> void:
	sfx_enabled = on
	if not on:
		for v: AudioStreamPlayer in _voices:
			v.stop()

func toggle_enabled() -> bool:
	set_enabled(not sfx_enabled)
	return sfx_enabled

func set_music_enabled(on: bool) -> void:
	music_enabled = on
	if not on:
		if _music_fade_tween != null and _music_fade_tween.is_valid():
			_music_fade_tween.kill()
		if _music_a != null: _music_a.stop()
		if _music_b != null: _music_b.stop()
	elif _current_music != "":
		# Re-arm the same track when toggled back on mid-game
		var name: String = _current_music
		_current_music = ""  # force play_music to actually play it
		play_music(name)

func toggle_music_enabled() -> bool:
	set_music_enabled(not music_enabled)
	return music_enabled

func set_music_volume_db(db: float) -> void:
	## Adjust music volume. Range typically -40 .. 0. Active player is
	## ramped to the new level immediately.
	music_volume_db = clamp(db, -40.0, 0.0)
	if _music_active != null and _music_active.playing and music_enabled:
		if _music_fade_tween != null and _music_fade_tween.is_valid():
			_music_fade_tween.kill()
		_music_fade_tween = create_tween()
		_music_fade_tween.tween_property(_music_active, "volume_db", music_volume_db, 0.25)

func set_sfx_volume_db(db: float) -> void:
	## Adjust master SFX volume (-40..0). Applied to the next play() call.
	master_volume_db = clamp(db, -40.0, 0.0)

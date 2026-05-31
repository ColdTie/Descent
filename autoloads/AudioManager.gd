extends Node
## Central sound-effect player. Preloads procedurally-generated WAV SFX
## (see tools/gen_audio.py) and plays them through a small voice pool so
## overlapping sounds don't cut each other off.
##
## Defensive by design: if a sound file is missing (e.g. assets not yet
## imported by the editor), play() is a silent no-op — never crashes.

const SOUND_NAMES: Array[String] = [
	"hit", "crit", "kill", "hurt", "move", "select", "ability",
	"fire", "frost", "heal", "enrage", "levelup", "victory",
	"defeat", "descend", "lava",
]

const VOICE_COUNT: int = 8           # simultaneous SFX channels
const AUDIO_DIR: String = "res://assets/audio/"

var _streams: Dictionary = {}        # name -> AudioStream
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0

var sfx_enabled: bool = true
var master_volume_db: float = -6.0   # slight headroom

func _ready() -> void:
	# Preload available streams
	for name: String in SOUND_NAMES:
		var path: String = AUDIO_DIR + name + ".wav"
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path) as AudioStream
			if stream != null:
				_streams[name] = stream
	# Build the voice pool
	for i: int in range(VOICE_COUNT):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_voices.append(p)

func play(sound_name: String, pitch_variation: float = 0.0, volume_db: float = 0.0) -> void:
	## Play a sound by name. pitch_variation adds ± randomness so repeated
	## sounds (hits, footsteps) don't feel robotic.
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

func set_enabled(on: bool) -> void:
	sfx_enabled = on
	if not on:
		for v: AudioStreamPlayer in _voices:
			v.stop()

func toggle_enabled() -> bool:
	set_enabled(not sfx_enabled)
	return sfx_enabled

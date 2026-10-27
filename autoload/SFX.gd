## SFX.gd (autoload singleton, registered in project.godot as "SFX")
##
## Small procedural sound-effect player, ported conceptually from the
## Web Audio `tone(freq, dur, opts)` helper in the HTML prototype. Instead of
## shipping audio files for a prototype pass, each effect is a short
## synthesized tone (or a couple of tones in sequence) generated on the fly
## through an AudioStreamGenerator. Swap in real SFX files later by replacing
## the bodies of these functions with `AudioStreamPlayer.stream = preload(...)`.
extends Node

const SAMPLE_RATE := 44100.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	# The browser build plays sounds as Web Audio "samples" by default, which a
	# generated stream can't be; stream it instead (no effect on desktop).
	_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 0.3
	_player.stream = gen
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


## Lets go of the generator playback before the engine shuts down — holding
## it through exit was reported as a leaked instance.
func _exit_tree() -> void:
	_playback = null
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null


func _enabled() -> bool:
	return GameState.settings.get("sound", true)


func _tone(freq: float, duration: float, volume: float = 0.15, wave: String = "sine", delay: float = 0.0) -> void:
	if not _enabled():
		return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if not _playback:
		return
	var frames := int(SAMPLE_RATE * duration)
	var phase := 0.0
	var increment := freq / SAMPLE_RATE
	for i in range(frames):
		# Simple linear fade-out envelope so tones don't click at the end.
		var env: float = 1.0 - (float(i) / float(frames))
		var sample: float
		match wave:
			"square":
				sample = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"triangle":
				sample = 4.0 * abs(fmod(phase + 0.75, 1.0) - 0.5) - 1.0
			_:
				sample = sin(phase * TAU)
		sample *= volume * env
		if _playback.get_frames_available() > 0:
			_playback.push_frame(Vector2(sample, sample))
		phase += increment


func match_() -> void:
	_tone(520.0, 0.09, 0.14)


func combo(n: int) -> void:
	_tone(520.0 + 40.0 * n, 0.1, 0.16)


func special_() -> void:
	_tone(660.0, 0.12, 0.18)
	_tone(880.0, 0.14, 0.16, "sine", 0.06)


func invalid() -> void:
	_tone(180.0, 0.12, 0.12, "square")


func win() -> void:
	_tone(660.0, 0.15, 0.16)
	_tone(880.0, 0.2, 0.16, "sine", 0.12)


func lose() -> void:
	_tone(360.0, 0.18, 0.1)
	_tone(260.0, 0.24, 0.1, "sine", 0.14)


func purchase() -> void:
	_tone(880.0, 0.07, 0.12)
	_tone(1180.0, 0.1, 0.12, "sine", 0.07)


func nav() -> void:
	_tone(400.0, 0.05, 0.07, "triangle")

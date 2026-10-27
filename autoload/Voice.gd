## Voice.gd (autoload singleton, registered in project.godot as "Voice")
##
## Voice acting, drop-in like the music: a spoken line plays the moment its
## clip exists at res://audio/voice/<char id>/<line id>.ogg (.wav and .mp3
## work too), where <line id> is the line's "id" in characters.json (e.g.
## "amara_intro_01"). Lines without a clip simply stay silent.
##
## One line at a time: a new line cuts off the one still playing, and
## narration (or a line with no clip) stops it, so her voice never runs on
## under text she isn't saying. Music dips a little while she talks.
## Settings: "Voice Acting" turns it off; the Voice slider sets how loud.
extends Node

const DIR := "res://audio/voice/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const DEFAULT_VOLUME := 1.0

var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.finished.connect(func(): Music.set_duck(false))
	add_child(_player)
	apply_volume()


func _exit_tree() -> void:
	_player.stop()
	_player.stream = null


func enabled() -> bool:
	return bool(GameState.settings.get("voice", true))


## The clip for a line id, or "" if there isn't one.
static func clip_path(char_id: String, line_id: String) -> String:
	if char_id == "" or line_id == "":
		return ""
	for ext in EXTENSIONS:
		var path: String = DIR + char_id + "/" + line_id + "." + ext
		if ResourceLoader.exists(path):
			return path
	return ""


## True when any line of hers has a clip (Settings only shows the voice
## options then).
static func any_clips() -> bool:
	for ch in CharacterData.all():
		if DirAccess.dir_exists_absolute(DIR + String(ch.id)):
			return true
	return false


## Plays a line (a characters.json line or quip dictionary); stops whatever
## was playing if this one is narration or has no clip.
func play_line(char_id: String, line) -> void:
	var id := ""
	if typeof(line) == TYPE_DICTIONARY and String(line.get("k", "s")) != "n":
		id = String(line.get("id", ""))
	play(char_id, id)


func play(char_id: String, line_id: String) -> void:
	stop()
	if not enabled():
		return
	var path := clip_path(char_id, line_id)
	if path == "":
		return
	var stream = load(path)
	if not (stream is AudioStream):
		return
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = false
	_player.stream = stream
	_player.play()
	Music.set_duck(true)


func stop() -> void:
	if _player.playing:
		_player.stop()
	Music.set_duck(false)


func is_playing() -> bool:
	return _player.playing


## Re-reads the Voice volume setting (the Settings slider).
func apply_volume() -> void:
	var vol: float = clampf(float(GameState.settings.get("voice_volume", DEFAULT_VOLUME)), 0.0, 1.0)
	_player.volume_db = linear_to_db(maxf(vol, 0.0001))

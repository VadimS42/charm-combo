## Music.gd (autoload singleton, registered in project.godot as "Music")
##
## Background music, drop-in like the art (round 15): a track plays the
## moment its file exists at res://audio/music/<track>.ogg (.mp3 and .wav work
## too) — until then there's simply no music, exactly as before. Tracks:
##   "menu"        main menu, roster, gallery, store, credits
##   "<char id>"   her story — dialogue and chapters ("succubus", "mermaid",
##                 "slime", "dryad")
##   "night"       her night scene (round 22), else her own track
##   "ending"      her epilogue: its dialogue, art beats and final CG
## A missing track falls back to the next one in the list each screen asks
## for (see Main.gd), so a single menu theme already covers the whole game.
## Switching tracks crossfades; the Music slider in Settings scales it, and the
## Master Volume slider scales everything.
extends Node

const DIR := "res://audio/music/"
const EXTENSIONS := ["ogg", "mp3", "wav"]
const FADE_SEC := 1.2
const DEFAULT_VOLUME := 0.7
## How loud the music stays while a voice line plays (Voice.gd).
const DUCK_LEVEL := 0.45
const DUCK_SEC := 0.25

var _players: Array[AudioStreamPlayer] = []
var _levels: Array[float] = [0.0, 0.0]
var _tweens: Array = [null, null]
var _active := 0
## res:// path of the track playing (or fading in); "" when silent.
var current_path := ""
var _duck := 1.0
var _duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		# WAVs without loop points: start again from the top.
		p.finished.connect(_on_finished.bind(i))
		add_child(p)
		_players.append(p)


func _exit_tree() -> void:
	for p in _players:
		p.stop()
		p.stream = null


## The file for a track name, or "" if it doesn't exist.
static func track_path(track: String) -> String:
	if track == "":
		return ""
	for ext in EXTENSIONS:
		var path: String = DIR + track + "." + ext
		if ResourceLoader.exists(path):
			return path
	return ""


## True when at least one of the game's tracks exists (Settings only shows
## its Music slider then).
static func any_tracks() -> bool:
	var names: Array = ["menu", "ending"]
	for ch in CharacterData.all():
		names.append(String(ch.id))
	for n in names:
		if track_path(n) != "":
			return true
	return false


## Plays the first of `tracks` that exists, crossfading from whatever was
## playing; fades to silence when none of them do. Asking for the track that's
## already playing changes nothing (so it carries on across screens).
func play(tracks: Array) -> void:
	var path := ""
	for t in tracks:
		path = track_path(String(t))
		if path != "":
			break
	if path == current_path:
		return
	current_path = path
	_fade(_active, 0.0)
	if path == "":
		return
	var stream = load(path)
	if not (stream is AudioStream):
		current_path = ""
		return
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	_active = 1 - _active
	var p := _players[_active]
	if _tweens[_active] is Tween and (_tweens[_active] as Tween).is_valid():
		(_tweens[_active] as Tween).kill()
	p.stop()
	p.stream = stream
	_levels[_active] = 0.0
	_apply(_active)
	p.play()
	_fade(_active, 1.0)


func stop() -> void:
	current_path = ""
	_fade(_active, 0.0)


## Dips the music under a voice line (on), or brings it back (off).
func set_duck(on: bool) -> void:
	var to := DUCK_LEVEL if on else 1.0
	if is_equal_approx(_duck, to):
		return
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(func(v: float):
		_duck = v
		apply_volume(), _duck, to, DUCK_SEC)


## Re-reads the Music volume setting (the Settings slider).
func apply_volume() -> void:
	for i in range(_players.size()):
		_apply(i)


func _fade(i: int, to: float) -> void:
	if _tweens[i] is Tween and (_tweens[i] as Tween).is_valid():
		(_tweens[i] as Tween).kill()
	var p := _players[i]
	if not p.playing:
		_levels[i] = to
		_apply(i)
		return
	var tw := create_tween()
	tw.tween_method(_set_level.bind(i), _levels[i], to, FADE_SEC)
	if to <= 0.0:
		tw.tween_callback(p.stop)
	_tweens[i] = tw


func _set_level(v: float, i: int) -> void:
	_levels[i] = v
	_apply(i)


func _apply(i: int) -> void:
	var vol: float = clampf(float(GameState.settings.get("music_volume", DEFAULT_VOLUME)), 0.0, 1.0)
	_players[i].volume_db = linear_to_db(maxf(vol * _levels[i] * _duck, 0.0001))


func _on_finished(i: int) -> void:
	# Only the track that's meant to be playing restarts; one that finished
	# while fading out stays stopped.
	if i == _active and current_path != "" and _levels[i] > 0.0:
		_players[i].play()

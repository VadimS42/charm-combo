## GameState.gd (autoload singleton, registered in project.godot as "GameState")
##
## Holds everything that needs to survive between screens and between play
## sessions: stars, settings, per-character progress, unlocked endings, and
## item counts. This is the Godot equivalent of the `state` object + the
## localStorage save/load code from the original HTML prototype.
##
## Autosave: connect to SceneTree "quit"/focus-lost notifications so progress
## is written even if the player closes the game mid-level, matching the
## HTML version's pagehide/beforeunload/visibilitychange autosave.
extends Node

const SAVE_PATH := "user://save.json"

const DEFAULT_ITEMS := {
	"moves": 0, "hammer": 0, "shuffle": 0,
	# One-chapter-use consumables (Item Shop "Gem Tuning" / "Power-ups"
	# section) — consumed the moment the next chapter starts, see
	# CharacterData.compute_weights() and PuzzleScreen.setup().
	"colorBomb": 0, "favorCharm": 0, "heartMender": 0,
}

var stars: int = 0

var settings: Dictionary = {
	"sound": true,
	"reduce_motion": false,
	"theme": "system",  # "system" | "light" | "dark"
	"test_mode": false,
}

## Per-character save data, keyed by character id, e.g.:
## { "succubus": { "level_index": 0, "endings_unlocked": ["warmth"], "gifts_given": ["stagePin"] } }
var characters_progress: Dictionary = {}

var items: Dictionary = DEFAULT_ITEMS.duplicate()

## In-memory only (not persisted): the pending start-of-chapter score bonus
## set by a dialogue choice just before a puzzle chapter begins. Mirrors the
## HTML prototype's `pendingStartBonus` variable.
var pending_start_bonus: int = 0

var _dirty: bool = false


func _ready() -> void:
	load_state()
	# Autosave on every path the OS might use to end the process, mirroring
	# the HTML version's pagehide/beforeunload/visibilitychange listeners.
	get_tree().auto_accept_quit = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _notification(what: int) -> void:
	# Mirrors the HTML prototype's pagehide/beforeunload/visibilitychange
	# autosave listeners: write progress on every path the OS might use to
	# end or background the process, not just a clean menu-driven exit.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_state()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func progress_for(char_id: String) -> Dictionary:
	if not characters_progress.has(char_id):
		characters_progress[char_id] = {
			"level_index": 0,
			"endings_unlocked": [],
			"gifts_given": [],
		}
	return characters_progress[char_id]


func mark_dirty() -> void:
	_dirty = true


func save_state() -> void:
	var data := {
		"stars": stars,
		"settings": settings,
		"characters_progress": characters_progress,
		"items": items,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
	_dirty = false


func load_state() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	stars = int(parsed.get("stars", 0))
	if typeof(parsed.get("settings")) == TYPE_DICTIONARY:
		for k in parsed.settings.keys():
			settings[k] = parsed.settings[k]
	if typeof(parsed.get("characters_progress")) == TYPE_DICTIONARY:
		characters_progress = parsed.characters_progress
	if typeof(parsed.get("items")) == TYPE_DICTIONARY:
		items = parsed.items


func reset_progress() -> void:
	stars = 0
	characters_progress = {}
	items = DEFAULT_ITEMS.duplicate()
	save_state()


func set_test_mode(on: bool) -> void:
	settings.test_mode = on
	if on:
		stars = max(stars, 99)
	save_state()

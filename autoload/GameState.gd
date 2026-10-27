## GameState.gd (autoload singleton, registered in project.godot as "GameState")
##
## Holds everything that needs to survive between screens and between play
## sessions: stars, settings, per-character progress, the gallery of endings
## found, and item counts. This is the Godot equivalent of the `state` object +
## the localStorage save/load code from the original HTML prototype.
##
## Autosave: writes on every path the OS might use to end or background the
## process, not just a clean menu-driven exit (the HTML version's
## pagehide/beforeunload/visibilitychange listeners).
##
## Saving is crash-safe (round 15): the new save is written to a temp file and
## renamed over the old one, and the previous save is kept as a backup — a
## crash or power cut mid-write used to leave a truncated save.json that then
## loaded as a brand-new game (and got overwritten by the next autosave).
extends Node

const SAVE_PATH := "user://save.json"
const TEMP_PATH := "user://save.json.tmp"
const BACKUP_PATH := "user://save.backup.json"
## Bumped when the save's shape changes; older saves are migrated on load.
## 2 = round 15: per-chapter choices, won chapters, persisted chapter bonus,
## the gallery collection, fullscreen.
const SAVE_VERSION := 2

## The QA "Testing Mode" toggle in Settings (instant chapter clears, free
## stars). Set to false before release: the toggle disappears and any save
## with it on is switched off at load.
const ALLOW_TESTING_MODE := true

const DEFAULT_ITEMS := {
	"moves": 0, "hammer": 0, "shuffle": 0,
	# One-chapter-use consumables (Item Shop "Gem Tuning" / "Power-ups"
	# section) — consumed the moment the next chapter starts, see
	# CharacterData.compute_weights() and PuzzleScreen.setup().
	"colorBomb": 0, "favorCharm": 0, "heartMender": 0,
}

const DEFAULT_SETTINGS := {
	"sound": true,
	"volume": 0.8,  # 0..1, the Master bus (see apply_volume())
	"music_volume": 0.7,  # 0..1, background music only (Music.gd)
	"voice": true,  # voice acting on/off (Voice.gd)
	"voice_volume": 1.0,  # 0..1, voice lines only (Voice.gd)
	# Dialogue (VNScreen): how fast text types out ("slow" | "normal" | "fast"
	# | "instant"), whether Skip also skips lines you haven't read, and how
	# long Auto waits after a line (0..1: quick .. slow).
	"text_speed": "normal",
	"skip_unseen": false,
	"auto_delay": 0.5,
	"reduce_motion": false,
	"theme": "system",  # "system" | "light" | "dark" (not ported yet)
	"test_mode": false,
	"fullscreen": false,
	# The one-time 18+ notice was confirmed on this computer (AgeGateScreen).
	"age_confirmed": false,
}

var stars: int = 0

var settings: Dictionary = DEFAULT_SETTINGS.duplicate()

## Per-character save data, keyed by character id. See progress_for() for the
## full set of keys; normalized on load by _normalize_progress().
var characters_progress: Dictionary = {}

var items: Dictionary = DEFAULT_ITEMS.duplicate()

## Every ending the player has reached, across replays — what the Gallery
## shows. Entries are "char_id|ending_key|finale_key" (finale_key is "" for an
## ending without an epilogue choice). Kept separately from each character's
## current progress so replaying her story never loses a finale you found.
var gallery: Array = []

## Achievement ids unlocked (Achievements.gd). Like the gallery, kept through
## Reset Progress — Steam never takes an achievement back either.
var achievements: Array = []

## Dialogue lines already read (VNScreen.line_key() -> true), for Skip; and
## the How to Play tips already shown once (HowToPlay.gd). Both survive Reset
## Progress: you've still read those lines and learned those rules.
var seen_lines: Dictionary = {}
## Scenes the Gallery can replay (round 25): "<char id>|night" once her
## night scene has played through. Kept through Reset Progress like the
## gallery.
var replays: Array = []
var tips_seen: Array = []

## In-memory only (not persisted): the "key" of whichever option was just
## picked in a character's epilogue choice (see StoryFlow's _play_epilogue()/
## _resolve_epilogue_finale() and apply_choice()). Set the instant the choice
## button is pressed and read right back once VNScreen's on_done fires.
var pending_epilogue_key: String = ""


func _ready() -> void:
	_migrate_old_save_location()
	load_state()
	apply_volume()
	# Autosave on every path the OS might use to end the process.
	get_tree().auto_accept_quit = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_window_mode()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_state()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


## Save and quit — the menu's Quit button.
func quit_game() -> void:
	save_state()
	get_tree().quit()


func progress_for(char_id: String) -> Dictionary:
	if not characters_progress.has(char_id):
		characters_progress[char_id] = _new_progress()
	return characters_progress[char_id]


static func _new_progress() -> Dictionary:
	return {
		"level_index": 0,
		"endings_unlocked": [],
		"gifts_given": [],
		# slot ("intro", "L0".."L2") -> "warmth"/"spark": one entry per choice,
		# so re-making a choice (a replayed scene) replaces it, never adds.
		"choices": {},
		# chapter indices already won this playthrough (stars paid once each).
		"won_levels": [],
		# the conversation choice's starting-score bonus for the next chapter,
		# kept until that chapter is won (see PuzzleScreen.setup()).
		"next_bonus": 0,
		# chapter index (as text) -> times lost in a row; after 3 the loss
		# screen offers "Continue the story" (round 25).
		"losses": {},
		# chapters passed that way: no stars, no chapter achievement.
		"skipped_levels": [],
	}


func add_to_gallery(char_id: String, ending_key: String, finale_key: String) -> void:
	var entry := "%s|%s|%s" % [char_id, ending_key, finale_key]
	if not gallery.has(entry):
		gallery.append(entry)


func save_state() -> void:
	var data := {
		"version": SAVE_VERSION,
		"stars": stars,
		"settings": settings,
		"characters_progress": characters_progress,
		"items": items,
		"gallery": gallery,
		"achievements": achievements,
		"seen_lines": seen_lines.keys(),
		"tips_seen": tips_seen,
		"replays": replays,
	}
	var f := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("GameState: couldn't write %s (%s)" % [TEMP_PATH, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.flush()
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	# Keep the previous good save as a backup before replacing it.
	if FileAccess.file_exists(SAVE_PATH) and _read_json(SAVE_PATH) != null:
		dir.copy(SAVE_PATH, BACKUP_PATH)
	# DirAccess.rename() replaces an existing destination on every platform.
	var err := dir.rename(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_warning("GameState: couldn't replace the save (%s); writing it directly" % error_string(err))
		var direct := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if direct:
			direct.store_string(JSON.stringify(data, "\t"))
			direct.close()


func load_state() -> void:
	var parsed = _read_json(SAVE_PATH)
	if parsed == null and FileAccess.file_exists(SAVE_PATH):
		# Unreadable (e.g. cut off by a crash): don't let the next autosave
		# destroy it — set it aside — and fall back to the backup.
		var dir := DirAccess.open("user://")
		if dir:
			dir.rename(SAVE_PATH, "user://save.unreadable.%d.json" % int(Time.get_unix_time_from_system()))
		push_warning("GameState: save.json was unreadable; trying the backup")
	if parsed == null:
		parsed = _read_json(BACKUP_PATH)
	if parsed == null:
		return

	stars = maxi(0, int(parsed.get("stars", 0)))
	if typeof(parsed.get("settings")) == TYPE_DICTIONARY:
		for k in DEFAULT_SETTINGS.keys():
			if parsed.settings.has(k):
				var v = parsed.settings[k]
				match typeof(DEFAULT_SETTINGS[k]):
					TYPE_STRING:
						settings[k] = String(v)
					TYPE_FLOAT:
						settings[k] = clampf(float(v), 0.0, 1.0)
					_:
						settings[k] = bool(v)
	if not ALLOW_TESTING_MODE:
		settings.test_mode = false

	items = DEFAULT_ITEMS.duplicate()
	if typeof(parsed.get("items")) == TYPE_DICTIONARY:
		for k in parsed.items.keys():
			items[k] = maxi(0, int(parsed.items[k]))

	characters_progress = {}
	if typeof(parsed.get("characters_progress")) == TYPE_DICTIONARY:
		for id in parsed.characters_progress.keys():
			var p = parsed.characters_progress[id]
			if typeof(p) == TYPE_DICTIONARY:
				characters_progress[String(id)] = _normalize_progress(String(id), p)

	achievements = []
	if typeof(parsed.get("achievements")) == TYPE_ARRAY:
		for a in parsed.achievements:
			if not achievements.has(String(a)):
				achievements.append(String(a))

	seen_lines = {}
	if typeof(parsed.get("seen_lines")) == TYPE_ARRAY:
		for k in parsed.seen_lines:
			seen_lines[String(k)] = true
	replays = []
	if typeof(parsed.get("replays")) == TYPE_ARRAY:
		for k in parsed.replays:
			replays.append(String(k))
	tips_seen = []
	if typeof(parsed.get("tips_seen")) == TYPE_ARRAY:
		for k in parsed.tips_seen:
			tips_seen.append(String(k))

	gallery = []
	if typeof(parsed.get("gallery")) == TYPE_ARRAY:
		for e in parsed.gallery:
			if not gallery.has(String(e)):
				gallery.append(String(e))
	# Saves from before the gallery existed: seed it from what each character
	# has currently reached — but only once her epilogue was actually seen
	# through (quitting halfway used to count the ending on the next launch).
	for id in characters_progress.keys():
		var p: Dictionary = characters_progress[id]
		if not p.endings_unlocked.is_empty() and not StoryFlow.epilogue_unfinished(id):
			var ek: String = p.endings_unlocked[0]
			var fin: Dictionary = p.get("epilogue_finale", {})
			add_to_gallery(id, ek, String(fin.get("key", "")) if String(fin.get("ending", "")) == ek else "")


## Fills in every key a character's progress needs, fixes types that JSON
## round-trips change (ints come back as floats), and drops anything that no
## longer matches the story data — a partial or older save used to break her
## roster card and her story (missing endings_unlocked, for example).
static func _normalize_progress(char_id: String, raw: Dictionary) -> Dictionary:
	var p := _new_progress()
	var ch := CharacterData.by_id(char_id)
	var level_count: int = ch.story.levels.size() if not ch.is_empty() else 99
	p.level_index = clampi(int(raw.get("level_index", 0)), 0, maxi(0, level_count - 1))
	for key in ["endings_unlocked", "gifts_given", "won_levels", "skipped_levels"]:
		if typeof(raw.get(key)) == TYPE_ARRAY:
			for v in raw[key]:
				p[key].append(int(v) if key.ends_with("_levels") else String(v))
	if typeof(raw.get("losses")) == TYPE_DICTIONARY:
		for k in raw.losses.keys():
			p.losses[String(k)] = maxi(0, int(raw.losses[k]))
	if not ch.is_empty():
		p.endings_unlocked = p.endings_unlocked.filter(func(k): return ch.story.endings.has(k))
	if typeof(raw.get("choices")) == TYPE_DICTIONARY:
		for slot in raw.choices.keys():
			var stat := String(raw.choices[slot])
			if stat == "warmth" or stat == "spark":
				p.choices[String(slot)] = stat
	# Saves from before per-slot choices only have a running tally: carry it
	# over as placeholder slots, so choices made from now on add to it (and
	# replace only their own slot) instead of silently replacing all of it.
	if p.choices.is_empty() and typeof(raw.get("stat_tally")) == TYPE_DICTIONARY:
		var n := 0
		for stat in ["warmth", "spark"]:
			for i in range(maxi(0, int(raw.stat_tally.get(stat, 0)))):
				p.choices["legacy%d" % n] = stat
				n += 1
	p.next_bonus = int(raw.get("next_bonus", 0))
	if raw.has("scene_pending"):
		var sp := int(raw.scene_pending)
		if sp >= 0 and sp < level_count:
			p["scene_pending"] = sp
	if bool(raw.get("_intro_done", false)):
		p["_intro_done"] = true
	if typeof(raw.get("epilogue_finale")) == TYPE_DICTIONARY:
		p["epilogue_finale"] = {
			"ending": String(raw.epilogue_finale.get("ending", "")),
			"key": String(raw.epilogue_finale.get("key", "")),
		}
	return p


static func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	# A JSON instance rather than JSON.parse_string(), which prints an engine
	# ERROR for a damaged file — here that's an expected, handled case.
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var parsed = json.data
	return parsed if typeof(parsed) == TYPE_DICTIONARY else null


func reset_progress() -> void:
	stars = 0
	characters_progress = {}
	items = DEFAULT_ITEMS.duplicate()
	gallery = []
	pending_epilogue_key = ""
	save_state()


func set_test_mode(on: bool) -> void:
	settings.test_mode = on and ALLOW_TESTING_MODE
	if settings.test_mode:
		stars = max(stars, 99)
	save_state()


## Applies the Fullscreen setting to the game window (no-op headless). In a
## browser, fullscreen may only start from a click, so it isn't restored at
## startup there.
func apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless" or (OS.has_feature("web") and not _web_user_gesture):
		return
	var want_full: bool = settings.get("fullscreen", false)
	var mode := DisplayServer.window_get_mode()
	var is_full: bool = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if want_full and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not want_full and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Sets the Master bus from the Volume setting (0 = silent).
func apply_volume() -> void:
	var vol: float = clampf(float(settings.get("volume", 0.8)), 0.0, 1.0)
	AudioServer.set_bus_mute(0, vol <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol, 0.001)))


func set_volume(vol: float) -> void:
	settings.volume = clampf(vol, 0.0, 1.0)
	apply_volume()
	save_state()


var _web_user_gesture := false

func set_fullscreen(on: bool) -> void:
	settings.fullscreen = on
	_web_user_gesture = true  # only ever called from a click or key press
	apply_window_mode()
	_web_user_gesture = false
	save_state()


## Round 16 moved saves to their own folder (project.godot
## application/config/custom_user_dir_name = "CharmCombo": %APPDATA%\CharmCombo on
## Windows, ~/.local/share/CharmCombo on Linux, ~/Library/Application
## Support/CharmCombo on macOS) instead of Godot's shared
## "Godot/app_userdata/Charm Combo" — a stable path for Steam Cloud. A save
## left in the old place is copied over once, the first time.
func _migrate_old_save_location() -> void:
	if OS.has_feature("web") or FileAccess.file_exists(SAVE_PATH):
		return
	var user_dir := OS.get_user_data_dir()
	for base in ["Godot/app_userdata/Charm Combo", "godot/app_userdata/Charm Combo"]:
		var old_dir := OS.get_data_dir().path_join(base)
		if old_dir == user_dir or not FileAccess.file_exists(old_dir.path_join("save.json")):
			continue
		for f in ["save.json", "save.backup.json"]:
			var src := old_dir.path_join(f)
			if FileAccess.file_exists(src):
				DirAccess.copy_absolute(src, user_dir.path_join(f))
		print("GameState: moved the save from ", old_dir)
		return

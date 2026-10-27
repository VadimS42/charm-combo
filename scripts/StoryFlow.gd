## StoryFlow.gd
##
## Orchestrates the intro -> chapter -> win-scene -> next-chapter -> ending
## chain for a character, the same overall shape as enterCharacter() /
## finishCharacter() / the choice handlers in the HTML prototype. Puzzle and
## VN screens call back into this rather than knowing about each other
## directly, so each screen stays a dumb "renderer" for its one job.
##
## Round 15 made the flow safe to quit out of at any point:
## - a chapter's win (its stars, and that its scene is still owed) is saved
##   BEFORE its win scene plays, and the scene is replayed on the next visit
##   if the game closed mid-scene (it used to replay the whole chapter and pay
##   its stars twice);
## - each conversation choice is stored per slot ("intro", "L0".."L2"), so a
##   replayed scene replaces its choice instead of counting it twice (which
##   could flip her ending);
## - an ending whose epilogue was never finished (game closed mid-epilogue)
##   replays the epilogue on the next visit instead of skipping to a flat CG.
class_name StoryFlow
extends RefCounted


## Entry point from the roster: decide whether this character needs their
## intro scene, an owed win scene, is mid-story, or is already finished.
static func enter_character(main: Node, char_id: String) -> void:
	var ch := CharacterData.by_id(char_id)
	if ch.is_empty():
		return
	var progress := GameState.progress_for(char_id)

	if not progress.endings_unlocked.is_empty():
		reopen_ending(main, char_id)
		return

	if progress.has("scene_pending"):
		_play_win_scene(main, ch, int(progress.scene_pending))
		return

	if int(progress.get("level_index", 0)) == 0 and not progress.get("_intro_done", false):
		play_intro(main, ch)
	else:
		main.show_puzzle(char_id)


static func play_intro(main: Node, ch: Dictionary) -> void:
	var intro: Array = ch.story.intro
	# Pass the intro lines AND her introChoice into ONE show_vn_scene call
	# (the same shape a chapter's win+choice already uses), so VNScreen can
	# keep her last line on screen behind the reply buttons.
	main.show_vn_scene(ch.id, intro, _with_slot(ch.story.get("introChoice"), "intro"), func():
		var progress := GameState.progress_for(ch.id)
		progress["_intro_done"] = true
		GameState.save_state()
		Achievements.check_story()
		main.show_puzzle(ch.id)
	)


## Called by PuzzleScreen once a chapter's target score is reached. The win is
## recorded (stars paid once, this chapter's bonus spent, its scene marked as
## owed) and saved before the scene starts.
static func on_chapter_won(main: Node, char_id: String) -> void:
	var ch := CharacterData.by_id(char_id)
	var progress := GameState.progress_for(char_id)
	var level_index: int = int(progress.get("level_index", 0))

	var won: Array = progress.get("won_levels", [])
	if not won.has(level_index):
		GameState.stars += 15 + level_index * 5
		won.append(level_index)
		progress["won_levels"] = won
	progress["next_bonus"] = 0
	progress["scene_pending"] = level_index
	GameState.save_state()
	main.refresh_topbar()
	Achievements.check_story()

	_play_win_scene(main, ch, level_index)


static func _play_win_scene(main: Node, ch: Dictionary, level_index: int) -> void:
	var levels: Array = ch.story.levels
	level_index = clampi(level_index, 0, levels.size() - 1)
	var level: Dictionary = levels[level_index]
	main.show_vn_scene(ch.id, level.win, _with_slot(level.get("choice"), "L%d" % level_index), func():
		var progress := GameState.progress_for(ch.id)
		var is_last: bool = level_index >= levels.size() - 1
		if is_last:
			# Her night scene, then her ending. The win scene stays owed until
			# the night is over, so quitting halfway replays both next time.
			_play_night(main, ch, func():
				GameState.progress_for(ch.id).erase("scene_pending")
				_finish_character(main, ch)
			)
		else:
			progress.erase("scene_pending")
			progress["level_index"] = level_index + 1
			GameState.save_state()
			main.show_puzzle(ch.id)
	)


## Her night scene (round 22): story.night in characters.json, played over
## her full-screen "night" CG right after her last chapter's scene, before
## her ending's morning after. {"cg": "night", "lines": [...]}; "slot" lines
## mark where the writer's own lines go and are skipped. Music: a "night"
## track if there is one, else hers. No night block = straight on.
static func _play_night(main: Node, ch: Dictionary, then: Callable) -> void:
	var night = ch.story.get("night")
	if typeof(night) != TYPE_DICTIONARY or (night.get("lines", []) as Array).is_empty():
		then.call()
		return
	main.story_music = "night"
	main.show_vn_scene(ch.id, night.lines, null, then, String(night.get("cg", "night")))


## A shallow copy of a choice block tagged with which story slot it belongs
## to, so apply_choice() can store it per slot. null stays null (a chapter
## with no choice, e.g. the last one).
static func _with_slot(choice, slot: String):
	if typeof(choice) != TYPE_DICTIONARY:
		return null
	var c: Dictionary = choice.duplicate()
	c["slot"] = slot
	return c


## Records a dialogue choice. Story choices (slot "intro"/"L#") store their
## warmth/spark lean for that slot and set the starting-score bonus for her
## next chapter; an epilogue choice (no slot) carries a "key" instead.
static func apply_choice(char_id: String, option: Dictionary, slot: String = "") -> void:
	var progress := GameState.progress_for(char_id)
	var stat: String = String(option.get("stat", ""))
	if slot != "":
		var choices: Dictionary = progress.get("choices", {})
		if stat == "warmth" or stat == "spark":
			choices[slot] = stat
		else:
			choices.erase(slot)
		progress["choices"] = choices
		progress["next_bonus"] = int(option.get("bonus", 0))
	GameState.pending_epilogue_key = String(option.get("key", ""))
	GameState.save_state()


## Her warmth/spark lean so far: counted from the per-slot choices, or from
## the old running tally for saves made before choices were stored per slot.
static func tally_for(progress: Dictionary) -> Dictionary:
	var choices: Dictionary = progress.get("choices", {})
	if choices.is_empty() and typeof(progress.get("stat_tally")) == TYPE_DICTIONARY:
		return {"warmth": int(progress.stat_tally.get("warmth", 0)), "spark": int(progress.stat_tally.get("spark", 0))}
	var t := {"warmth": 0, "spark": 0}
	for slot in choices.keys():
		var s := String(choices[slot])
		if t.has(s):
			t[s] += 1
	return t


static func _finish_character(main: Node, ch: Dictionary) -> void:
	var progress := GameState.progress_for(ch.id)
	var tally := tally_for(progress)
	var warmth := int(tally.warmth)
	var spark := int(tally.spark)
	var key := "balanced"
	if warmth > spark:
		key = "warmth"
	elif spark > warmth:
		key = "spark"
	elif not ch.story.endings.has("balanced"):
		# No "balanced" ending defined: a tie leans warmth.
		key = "warmth"
	# A route with no ending written for it (right now every girl only has
	# "warmth") falls back to one she has, instead of crashing the epilogue
	# and leaving her stuck replaying chapter 4 forever.
	if not ch.story.endings.has(key):
		key = "warmth" if ch.story.endings.has("warmth") else String(ch.story.endings.keys()[0])

	progress["endings_unlocked"] = [key]
	progress.erase("epilogue_finale")
	GameState.save_state()

	SFX.win()
	_play_epilogue(main, ch, key)


## Plays the character's full post-story epilogue beat by beat: dialogue ->
## a big art reveal -> more dialogue -> a second art reveal -> a 2-option
## choice -> a final CG whose title/text depends on which option was picked.
## Falls back to the flat single-CG ending for any ending without an
## "epilogue" block in data/characters.json.
static func _play_epilogue(main: Node, ch: Dictionary, key: String) -> void:
	# The whole epilogue shares the "ending" track (see Main.story_music).
	main.story_music = "ending"
	var ending: Dictionary = ch.story.endings[key]
	var epilogue = ending.get("epilogue")
	if typeof(epilogue) != TYPE_DICTIONARY or epilogue.is_empty():
		GameState.add_to_gallery(ch.id, key, "")
		GameState.save_state()
		Achievements.check_story()
		main.show_ending_cg(ch.id, _with_cg(ending, key), func(): main.show_roster())
		return

	var intro: Array = epilogue.get("intro", [])
	var middle: Array = epilogue.get("middle", [])
	var choice_lines: Array = epilogue.get("choice_lines", [])
	var choice = epilogue.get("choice")
	# An epilogue without a real choice must pass null, not {}: an empty dict
	# would show "Choose your reply:" with no buttons and strand the player.
	if typeof(choice) != TYPE_DICTIONARY or (choice.get("options", []) as Array).is_empty():
		choice = null
	# The beats as named steps, defined last-to-first so each one captures an
	# already-assigned next step (GDScript lambdas capture by value).
	var finish := func(): _resolve_epilogue_finale(main, ch, key, epilogue)
	var ask := func(): main.show_vn_scene(ch.id, choice_lines, choice, finish)
	var beat2 := func(): main.show_ending_art_beat(ch.id, String(epilogue.get("beat2_caption", "")), ask, key + "_beat2")
	var talk := func(): main.show_vn_scene(ch.id, middle, null, beat2)
	var beat1 := func(): main.show_ending_art_beat(ch.id, String(epilogue.get("beat1_caption", "")), talk, key + "_beat1")
	main.show_vn_scene(ch.id, intro, null, beat1)


## Called once the epilogue's choice resolves. The picked option is
## recovered from GameState.pending_epilogue_key (set by apply_choice()).
static func _resolve_epilogue_finale(main: Node, ch: Dictionary, ending_key: String, epilogue: Dictionary) -> void:
	var finales: Dictionary = epilogue.get("finales", {})
	var finale_key: String = GameState.pending_epilogue_key
	GameState.pending_epilogue_key = ""
	var finale: Dictionary = finales.get(finale_key, {})
	var shown: Dictionary
	if finale.is_empty():
		# Bad/missing data, or an epilogue with no choice: her flat ending.
		finale_key = ""
		shown = _with_cg(ch.story.endings[ending_key], ending_key)
	else:
		shown = _with_cg(finale, ending_key + "_" + finale_key)

	var progress := GameState.progress_for(ch.id)
	progress["epilogue_finale"] = {"ending": ending_key, "key": finale_key}
	GameState.add_to_gallery(ch.id, ending_key, finale_key)
	GameState.save_state()
	Achievements.check_story()

	main.show_ending_cg(ch.id, shown, func(): main.show_roster())


## A copy of an ending/finale dict tagged with which CG image goes with it
## (ArtAssets.cg(): art/characters/<id>/cg/<cg_key>.png).
static func _with_cg(d: Dictionary, cg_key: String) -> Dictionary:
	var out := d.duplicate()
	out["cg"] = cg_key
	return out


## The ending dict to DISPLAY for a gallery entry "char|ending|finale".
static func ending_for_entry(char_id: String, ending_key: String, finale_key: String) -> Dictionary:
	var ch := CharacterData.by_id(char_id)
	if ch.is_empty() or not ch.story.endings.has(ending_key):
		return {}
	var ending: Dictionary = ch.story.endings[ending_key]
	if finale_key != "" and typeof(ending.get("epilogue")) == TYPE_DICTIONARY:
		var f: Dictionary = ending.epilogue.get("finales", {}).get(finale_key, {})
		if not f.is_empty():
			return _with_cg(f, ending_key + "_" + finale_key)
	return _with_cg(ending, ending_key)


## Whichever ending dict should be DISPLAYED for an already-finished
## character: the finale she reached via her epilogue choice, if recorded,
## otherwise her flat ending.
static func display_ending_for(char_id: String) -> Dictionary:
	var progress := GameState.progress_for(char_id)
	if progress.endings_unlocked.is_empty():
		return {}
	var key: String = progress.endings_unlocked[0]
	var finale_info: Dictionary = progress.get("epilogue_finale", {})
	var finale_key := ""
	if String(finale_info.get("ending", "")) == key:
		finale_key = String(finale_info.get("key", ""))
	return ending_for_entry(char_id, key, finale_key)


## True when her ending has an epilogue she never got to the end of (the game
## closed mid-epilogue) — revisiting her replays it instead of skipping it.
static func epilogue_unfinished(char_id: String) -> bool:
	var ch := CharacterData.by_id(char_id)
	var progress := GameState.progress_for(char_id)
	if ch.is_empty() or progress.endings_unlocked.is_empty():
		return false
	var key: String = progress.endings_unlocked[0]
	var ep = ch.story.endings.get(key, {}).get("epilogue")
	if typeof(ep) != TYPE_DICTIONARY or ep.is_empty():
		return false
	return String(progress.get("epilogue_finale", {}).get("ending", "")) != key


## Revisiting a finished character shows the finale she reached (not the
## whole epilogue again) — unless the epilogue was never finished, in which
## case it plays from the start.
static func reopen_ending(main: Node, char_id: String) -> void:
	if epilogue_unfinished(char_id):
		var ch := CharacterData.by_id(char_id)
		_play_epilogue(main, ch, String(GameState.progress_for(char_id).endings_unlocked[0]))
		return
	var ending := display_ending_for(char_id)
	main.show_ending_cg(char_id, ending, func():
		main.show_roster()
	)


## Starts her story over from the intro (roster "Replay"). Keeps her gifts and
## everything already in the gallery; only her route progress resets.
static func restart_character(char_id: String) -> void:
	var old := GameState.progress_for(char_id)
	var fresh := GameState._new_progress()
	fresh.gifts_given = old.get("gifts_given", []).duplicate()
	GameState.characters_progress[char_id] = fresh
	GameState.save_state()

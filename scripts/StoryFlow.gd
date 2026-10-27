## StoryFlow.gd
##
## Orchestrates the intro -> chapter -> win-scene -> next-chapter -> ending
## chain for a character, the same overall shape as enterCharacter() /
## finishCharacter() / the choice handlers in the HTML prototype. Puzzle and
## VN screens call back into this rather than knowing about each other
## directly, so each screen stays a dumb "renderer" for its one job.
class_name StoryFlow
extends RefCounted

## Entry point from the roster: decide whether this character needs their
## intro scene, is mid-story, or is already finished (reopen their ending CG).
static func enter_character(main: Node, char_id: String) -> void:
	var ch := CharacterData.by_id(char_id)
	if ch.is_empty():
		return
	var progress := GameState.progress_for(char_id)

	if not progress.endings_unlocked.is_empty():
		reopen_ending(main, char_id)
		return

	if int(progress.get("level_index", 0)) == 0 and not progress.get("_intro_done", false):
		play_intro(main, ch)
	else:
		main.show_puzzle(char_id)


static func play_intro(main: Node, ch: Dictionary) -> void:
	var intro: Array = ch.story.intro
	var intro_choice = ch.story.get("introChoice")
	# Pass the intro lines AND her introChoice into ONE show_vn_scene call
	# (the same shape a chapter's win+choice already uses), rather than two
	# separate calls. That matters for more than tidiness: VNScreen shows
	# whatever line was last on screen behind the reply buttons so the
	# player can see what they're actually responding to, and that only
	# works within a single screen build — a second, separate call starts
	# from a blank dialogue box with no prior line to show.
	main.show_vn_scene(intro, intro_choice, func():
		var progress := GameState.progress_for(ch.id)
		progress["_intro_done"] = true
		GameState.save_state()
		main.show_puzzle(ch.id)
	)


## Called by PuzzleScreen once a chapter's target score is reached.
static func on_chapter_won(main: Node, char_id: String) -> void:
	var ch := CharacterData.by_id(char_id)
	var progress := GameState.progress_for(char_id)
	var level_index: int = int(progress.get("level_index", 0))
	var level: Dictionary = ch.story.levels[level_index]

	GameState.stars += 15 + level_index * 5
	GameState.save_state()

	main.show_vn_scene(level.win, level.get("choice"), func():
		var is_last: bool = level_index >= ch.story.levels.size() - 1
		if is_last:
			_finish_character(main, ch)
		else:
			progress["level_index"] = level_index + 1
			GameState.save_state()
			main.show_puzzle(char_id)
	)


## Records a dialogue choice's stat lean (warmth/spark) toward the running
## tally that decides the character's ending, and its point bonus (applied
## by PuzzleScreen as the next chapter's starting score). Mirrors the HTML
## prototype's per-option `stat` and `bonus` fields.
static func apply_choice(char_id: String, option: Dictionary) -> void:
	var progress := GameState.progress_for(char_id)
	if not progress.has("stat_tally"):
		progress["stat_tally"] = {"warmth": 0, "spark": 0}
	var stat: String = option.get("stat", "")
	if stat == "warmth" or stat == "spark":
		progress.stat_tally[stat] = int(progress.stat_tally.get(stat, 0)) + 1
	GameState.pending_start_bonus = int(option.get("bonus", 0))
	GameState.save_state()


static func _finish_character(main: Node, ch: Dictionary) -> void:
	var progress := GameState.progress_for(ch.id)
	var tally: Dictionary = progress.get("stat_tally", {"warmth": 0, "spark": 0})
	var warmth := int(tally.get("warmth", 0))
	var spark := int(tally.get("spark", 0))
	var key := "balanced"
	if warmth > spark:
		key = "warmth"
	elif spark > warmth:
		key = "spark"
	elif not ch.story.endings.has("balanced"):
		# Some characters may not define a "balanced" ending; fall back to
		# whichever side is (barely) ahead, defaulting to warmth on a tie.
		key = "warmth"

	progress["endings_unlocked"] = [key]
	GameState.save_state()

	SFX.win()
	var ending: Dictionary = ch.story.endings[key]
	main.show_ending_cg(ch.id, ending, func():
		main.show_roster()
	)


static func reopen_ending(main: Node, char_id: String) -> void:
	var ch := CharacterData.by_id(char_id)
	var progress := GameState.progress_for(char_id)
	var key: String = progress.endings_unlocked[0]
	var ending: Dictionary = ch.story.endings[key]
	main.show_ending_cg(char_id, ending, func():
		main.show_roster()
	)

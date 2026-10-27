## smoke_test.gd — plays every girl's story from the intro to the end of her
## epilogue, headless, then replays each night scene from the Gallery and
## checks the "Continue the story" path (round 25). Puzzles are won by
## setting the score (the bot in balance_bot.gd covers the puzzle itself);
## dialogue is clicked through with Enter, replies alternate warm / teasing.
## Any script error shows up in the output; the summary says what was reached.
##
## Run (from the project folder):
##   godot --headless --path . -s tools/smoke_test.gd
## It plays on a throwaway save: point HOME / XDG_DATA_HOME / APPDATA at an
## empty folder first if you don't want it to touch yours.
extends SceneTree

var main: Node
var gs: Node
var steps := 0
var picks := 0


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	gs = root.get_node("GameState")
	gs.reset_progress()
	gs.settings.age_confirmed = true
	gs.settings.text_speed = "instant"
	gs.settings.reduce_motion = true
	gs.settings.voice = false
	for t in HowToPlay.TOPICS:
		if not gs.tips_seen.has(t.key):
			gs.tips_seen.append(t.key)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	var ok := true
	for ch in CharacterData.all():
		var id := String(ch.id)
		StoryFlow.enter_character(main, id)
		await process_frame
		var done := await _drive(func(): return not gs.progress_for(id).endings_unlocked.is_empty() and not StoryFlow.epilogue_unfinished(id), 4000)
		print("%-9s ending reached: %s  (gallery %s, night replay unlocked %s)" % [id, done,
			gs.gallery.any(func(e): return String(e).begins_with(id + "|")), gs.replays.has(id + "|night")])
		if not done:
			var scr = main._screen_obj
			print("   stuck: screen=%s progress=%s modal=%s settings=%s" % [scr, gs.progress_for(id), main.modal_open(), main.is_settings_open()])
			_dump(main.screen_host, 0)
		ok = ok and done
	# The gallery and each night replay.
	main.show_gallery()
	await create_timer(0.2).timeout
	for ch in CharacterData.all():
		var n := [0]
		StoryFlow.replay_night(main, String(ch.id))
		var done := await _drive(func():
			n[0] += 1
			return n[0] > 5 and _gallery_open(), 600)
		print("%-9s night replay back in gallery: %s" % [ch.id, done])
		ok = ok and done
	# Three losses -> "Continue the story".
	gs.reset_progress()
	var p = gs.progress_for("dryad")
	p["_intro_done"] = true
	p["losses"] = {"0": 2}
	main.show_puzzle("dryad")
	await create_timer(0.3).timeout
	var pz = main._screen_obj
	pz.moves_left = 0
	pz._check_outcome()
	await create_timer(0.2).timeout
	var cont := _find_button(main.screen_host, "Continue the story")
	print("continue-the-story offered after 3 losses: %s" % (cont != null))
	if cont:
		cont.pressed.emit()
		var moved := await _drive(func(): return int(gs.progress_for("dryad").level_index) == 1, 400)
		print("continue-the-story moved on to chapter 2: %s, stars for it: %s" % [moved, (gs.progress_for("dryad").won_levels as Array).has(0)])
		ok = ok and moved
	print("SMOKE TEST %s" % ("PASSED" if ok else "FAILED"))
	quit()


func _gallery_open() -> bool:
	return _find_label(main.screen_host, "Ending Gallery")


## Clicks through whatever is on screen until `until` is true (or gives up).
func _drive(until: Callable, max_steps: int) -> bool:
	for i in range(max_steps):
		if until.call():
			return true
		if main.modal_open():
			main.close_modal()
		var scr = main._screen_obj
		if scr is PuzzleScreen:
			if not scr.busy and not scr._torn_down:
				scr.score = int(scr.level.target)
				scr._check_outcome()
		else:
			var choice := _find_choice(main.screen_host)
			if choice:
				# Alternate warm / teasing across the whole run.
				var opts: Array = choice.get_parent().get_children().filter(func(c): return c is Button)
				(opts[picks % opts.size()] as Button).pressed.emit()
				picks += 1
			else:
				var cont := _find_button(main.screen_host, "Continue")
				if cont:
					cont.pressed.emit()
				else:
					var e := InputEventAction.new()
					e.action = "ui_accept"
					e.pressed = true
					Input.parse_input_event(e)
					var u := InputEventAction.new()
					u.action = "ui_accept"
					u.pressed = false
					Input.parse_input_event(u)
		await create_timer(0.03).timeout
	return until.call()


func _find_choice(n: Node) -> Button:
	if n.is_queued_for_deletion():
		return null
	if n is Button and (n as Button).custom_minimum_size == Vector2(560, 54) and n.is_visible_in_tree():
		return n
	for c in n.get_children():
		var b := _find_choice(c)
		if b:
			return b
	return null


func _find_button(n: Node, text: String) -> Button:
	if n.is_queued_for_deletion():
		return null
	if n is Button and String((n as Button).text).begins_with(text) and n.is_visible_in_tree():
		return n
	for c in n.get_children():
		var b := _find_button(c, text)
		if b:
			return b
	return null


func _find_label(n: Node, text: String) -> bool:
	if n.is_queued_for_deletion():
		return false
	if n is Label and (n as Label).text == text:
		return true
	for c in n.get_children():
		if _find_label(c, text):
			return true
	return false


func _dump(n: Node, depth: int) -> void:
	if depth > 9:
		return
	if (n is Button or n is Label) and n.is_visible_in_tree():
		print("   ", "  ".repeat(depth), n.get_class(), ": ", String(n.text).left(60))
	for c in n.get_children():
		_dump(c, depth + 1)

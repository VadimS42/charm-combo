## pad_test.gd — controller / Steam Deck check (round 45). Opens every screen
## in pad mode and walks it with the D-pad the way a player would (real
## ui_up/down/left/right presses through the GUI), from the screen's default
## focus. Lists every visible button the D-pad can't reach, a screen with no
## default focus, and any focus that lands somewhere invisible.
##
##   godot --headless --path . -s tools/pad_test.gd
## (Throwaway save: point HOME / XDG_DATA_HOME / APPDATA elsewhere first.)
extends SceneTree

var main: Node
var gs: Node
var nav: Node
var problems := 0


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	gs = root.get_node("GameState")
	nav = root.get_node("Nav")
	gs.reset_progress()
	gs.settings.age_confirmed = true
	gs.settings.reduce_motion = true
	gs.settings.voice = false
	gs.settings.voice_notice_seen = true
	gs.settings.text_speed = "instant"
	for t in HowToPlay.TOPICS:
		if not gs.tips_seen.has(t.key):
			gs.tips_seen.append(t.key)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(0.4).timeout
	nav._set_mode(true, true)
	# Some progress, so the roster, gallery and picker have things in them.
	var p = gs.progress_for("dryad")
	p["_intro_done"] = true
	p["level_index"] = 2
	p["won_levels"] = [0, 1]
	gs.stars = 40
	gs.items = {"moves": 1, "hammer": 1, "shuffle": 1}

	await _check("Main menu", func(): main.show_menu())
	await _check("Roster", func():
		main.roster_selected_id = "dryad"
		main.show_roster())
	await _check("Roster: chapter picker", func():
		RosterScreen._chapter_picker(main, CharacterData.by_id("dryad"), [0, 1]))
	main.close_modal()
	await _check("Item Shop", func(): main.show_store())
	await _check("Gallery", func(): main.show_gallery())
	await _check("Achievements", func(): main.show_achievements())
	await _check("Credits", func(): main.show_credits())
	await _check("How to Play", func(): main.show_how_to_play())
	main.close_modal()
	await _check("Settings", func():
		main.show_menu()
		main.show_settings())
	if main.is_settings_open():
		main.close_settings()
	await _check("Dialogue", func():
		var ch := CharacterData.by_id("dryad")
		main.show_vn_scene("dryad", ch.story.intro, null, func(): pass))
	await _check("Dialogue: reply choice", func():
		var ch := CharacterData.by_id("dryad")
		main.show_vn_scene("dryad", [ch.story.intro[0]], ch.story.introChoice, func(): pass)
		await create_timer(0.3).timeout
		_press("ui_accept"), 1.0)
	for id in ["succubus", "mermaid", "slime", "dryad"]:
		var pr = gs.progress_for(id)
		pr["_intro_done"] = true
		pr["level_index"] = 2
		await _check("Chapter 3 (%s)" % id, func(): main.show_puzzle(id))
	await _check("Chapter: out of moves", func():
		main.show_puzzle("dryad")
		await create_timer(0.3).timeout
		var pz = main._screen_obj
		pz.moves_left = 0
		pz._check_outcome())
	if main.modal_open():
		main.close_modal()
	await _round49()
	print("PAD TEST %s (%d problems)" % ["PASSED" if problems == 0 else "FAILED", problems])
	quit()


## Round 49's screens: daily challenge, free dates, Gallery tabs and picture
## viewer, the score card after a free date, Story difficulty's skip button.
func _round49() -> void:
	# Opal's story finished, so Free date, the daily and the extras show.
	var p = gs.progress_for("slime")
	p["_intro_done"] = true
	p["won_levels"] = [0, 1, 2, 3]
	p["level_index"] = 3
	p["endings_unlocked"] = ["warmth"]
	gs.add_stat("chapters_won", 4)
	gs.stats.erase("daily_" + PuzzleScreen.daily_key())
	await _check("Main menu (daily on)", func(): main.show_menu())
	await _check("Roster (Free date)", func():
		main.roster_selected_id = "slime"
		main.show_roster())
	for page in GalleryScreen.PAGES:
		await _check("Gallery: %s" % page[0], func(): main.show_gallery(String(page[0])))
	var pics: Array = ExtrasScreen.unlocked_pictures()
	if not pics.is_empty():
		var tex = pics[0][1]
		if tex is Texture2D:
			await _check("Picture viewer", func():
				main.show_gallery("pictures")
				await create_timer(0.2).timeout
				ExtrasScreen.view(main, tex))
			main.close_modal()
	await _check("Free date", func(): main.show_puzzle("slime", -1, "free"))
	await _check("Free date: score card", func():
		main.show_puzzle("slime", -1, "free")
		await create_timer(0.3).timeout
		main._screen_obj.score = 2400
		main._screen_obj._show_mode_result())
	await _check("Daily challenge", func(): main.show_daily())
	gs.settings.difficulty = "story"
	await _check("Chapter, Story difficulty", func(): main.show_puzzle("dryad"))
	gs.settings.difficulty = "easy"


## Opens a screen, then walks it with the D-pad and reports what's unreachable.
func _check(title: String, open: Callable, wait := 0.4) -> void:
	await open.call()
	await create_timer(wait).timeout
	nav._set_mode(true, true)
	var vp := root.get_viewport()
	if vp.gui_get_focus_owner() == null:
		nav.focus_default()
	await process_frame
	var start: Control = vp.gui_get_focus_owner()
	var all := _focusables(main)
	if start == null:
		print("%-28s NO DEFAULT FOCUS (%d buttons)" % [title, all.size()])
		problems += 1
		return
	var seen := {start: true}
	var todo: Array = [start]
	var bad_land := []
	while not todo.is_empty():
		var c: Control = todo.pop_front()
		for a in ["ui_up", "ui_down", "ui_left", "ui_right"]:
			if not is_instance_valid(c) or not c.is_visible_in_tree():
				break
			c.grab_focus()
			await process_frame
			_press(a)
			await process_frame
			var n: Control = vp.gui_get_focus_owner()
			if n == null or seen.has(n):
				continue
			if not n.is_visible_in_tree():
				bad_land.append(n)
				continue
			seen[n] = true
			todo.append(n)
	var missed := all.filter(func(c): return not seen.has(c))
	var line := "%-28s %2d / %2d reachable from \"%s\"" % [title, all.size() - missed.size(), all.size(), _name(start)]
	print(line)
	for m in missed:
		print("    can't reach: %s" % _name(m))
	for b in bad_land:
		print("    focus lands on hidden: %s" % _name(b))
	problems += missed.size() + bad_land.size()


func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	root.get_viewport().push_input(e)
	var u := InputEventAction.new()
	u.action = action
	u.pressed = false
	root.get_viewport().push_input(u)


## Every control a player could want to reach: visible, focusable, and not
## covered by a modal/overlay it sits under.
func _focusables(n: Node) -> Array:
	var out: Array = []
	# Buttons, sliders and scroll areas; a screen's plain click-catcher
	# Control (the dialogue's "click to continue") isn't something to reach.
	var kind_ok: bool = n is BaseButton or n is Range or n is ScrollContainer
	if kind_ok and (n as Control).focus_mode == Control.FOCUS_ALL and (n as Control).is_visible_in_tree() \
			and not (n is Button and (n as Button).disabled) and _on_top(n):
		out.append(n)
	for c in n.get_children():
		out.append_array(_focusables(c))
	return out


## False for controls under an open modal or Settings (those are meant to be
## out of reach until it closes).
func _on_top(c: Control) -> bool:
	if main.is_settings_open():
		return main._settings_overlay.is_ancestor_of(c)
	if main.modal_open():
		return main._confirm_box.is_ancestor_of(c)
	return true


func _name(c: Control) -> String:
	var t := ""
	if c is Button:
		t = String((c as Button).text)
	if t == "" and c.tooltip_text != "":
		t = c.tooltip_text.left(40)
	if t == "" and c is Button and (c as Button).icon:
		t = "icon " + (c as Button).icon.resource_path.get_file()
	return "%s %s" % [c.get_class(), t.left(40).replace("\n", " ")]

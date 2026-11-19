## monetize_test.gd — the Google Play build's ads, purchases and hearts
## (round 50), with the test stand-ins finishing instantly.
##
##   godot --headless --path . -s tools/monetize_test.gd -- --ads
## (Throwaway save: point HOME / XDG_DATA_HOME / APPDATA elsewhere first.)
extends SceneTree

var main: Node
var gs: Node
var mz: Node
var problems := 0


func _initialize() -> void:
	call_deferred("_go")


func _ok(what: String, cond: bool) -> void:
	print("%-58s %s" % [what, "ok" if cond else "FAIL"])
	if not cond:
		problems += 1


func _go() -> void:
	gs = root.get_node("GameState")
	mz = root.get_node("Monetize")
	if not root.get_node("Platform").ads:
		print("run with -- --ads")
		quit(1)
		return
	gs.reset_progress()
	gs.shop = {}
	gs.settings.age_confirmed = true
	gs.settings.text_speed = "instant"
	gs.settings.reduce_motion = true
	gs.settings.voice = false
	gs.settings.voice_notice_seen = true
	for t in HowToPlay.TOPICS:
		if not gs.tips_seen.has(t.key):
			gs.tips_seen.append(t.key)
	mz.test_instant = true
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(0.4).timeout

	# Hardest tuning.
	_ok("Hazel's last chapters get a little more (20 -> %d, %d)" % [mz.moves(20, 2, "dryad"), mz.moves(20, 3, "dryad")],
		mz.moves(20, 2, "dryad") == 12 and mz.moves(20, 3, "dryad") == 12)
	_ok("moves per chapter 75/65/55/45%% (20 -> %d, %d, %d, %d)" % [mz.moves(20, 0), mz.moves(20, 1), mz.moves(20, 2), mz.moves(20, 3)],
		mz.moves(20, 0) == 15 and mz.moves(20, 1) == 13 and mz.moves(20, 2) == 11 and mz.moves(20, 3) == 9)
	_ok("item prices up 50%% (12 -> %d)" % mz.item_price(12), mz.item_price(12) == 18)
	gs.settings.difficulty = "story"
	_ok("Story difficulty needs the Story Pass", not PuzzleScreen.story_mode())
	gs.settings.difficulty = "easy"

	# Hearts.
	_ok("starts with 5 hearts", mz.hearts() == 5)
	mz.spend_heart()
	_ok("losing costs a heart (4)", mz.hearts() == 4)
	_ok("next heart on a clock", mz.next_heart_in() > 0 and mz.next_heart_in() <= mz.HEART_MINUTES * 60)
	gs.shop.heart_t = float(gs.shop.heart_t) - mz.HEART_MINUTES * 60.0 - 1.0
	_ok("a heart comes back after %d minutes" % mz.HEART_MINUTES, mz.hearts() == 5)
	for i in 5:
		mz.spend_heart()
	_ok("0 hearts: can't play", not mz.can_play())
	var pr = gs.progress_for("dryad")
	pr["_intro_done"] = true
	main.show_puzzle("dryad")
	await create_timer(0.3).timeout
	_ok("a chapter with 0 hearts opens Out of hearts instead", main.modal_open() and main._screen_obj == null)
	main.close_modal()
	gs.stars = 100
	_ok("refill with stars", mz.refill_with_stars() and mz.hearts() == 5 and gs.stars == 100 - mz.REFILL_STARS)
	mz.spend_heart()
	mz.watch("heart", func(): mz.add_hearts(1))
	_ok("video: +1 heart", mz.hearts() == 5)

	# A chapter: fewer moves, a video for more, a heart lost.
	main.show_puzzle("dryad")
	await create_timer(0.4).timeout
	var pz = main._screen_obj
	var lvl: Dictionary = CharacterData.by_id("dryad").story.levels[0]
	_ok("chapter 1: %d of its %d moves" % [pz.moves_left, int(lvl.moves)], pz.moves_left == mz.moves(int(lvl.moves), 0))
	pz.moves_left = 0
	pz._check_outcome()
	await create_timer(0.3).timeout
	_ok("out of moves cost a heart (4)", mz.hearts() == 4)
	var vid: Button = null
	for b in pz.overlay.find_children("*", "Button", true, false):
		if String((b as Button).text).begins_with("Watch a video"):
			vid = b
	_ok("Out of Moves offers a video for +%d moves" % mz.VIDEO_MOVES, vid != null)
	if vid:
		vid.pressed.emit()
		await process_frame
		_ok("the video gives the moves and reopens the board", pz.moves_left == mz.VIDEO_MOVES and not pz.overlay.visible)
	pz.moves_left = 0
	pz._check_outcome()
	await create_timer(0.2).timeout
	_ok("running out again is the same attempt (still 4)", mz.hearts() == 4)
	var again := false
	for b in pz.overlay.find_children("*", "Button", true, false):
		if String((b as Button).text).begins_with("Watch a video"):
			again = true
	_ok("only one moves video per attempt", not again)

	# Every 3rd loss in a row on a chapter: a free Time Scroll.
	var pp = gs.progress_for("dryad")
	pp["losses"] = {str(int(pp.get("level_index", 0))): 1}
	var scrolls0 := int(gs.items.get("moves", 0))
	main.show_puzzle("dryad")
	await create_timer(0.4).timeout
	main._screen_obj.moves_left = 0
	main._screen_obj._check_outcome()
	await create_timer(0.3).timeout
	_ok("2nd loss in a row: no gift yet", int(gs.items.get("moves", 0)) == scrolls0)
	main.show_puzzle("dryad")
	await create_timer(0.4).timeout
	main._screen_obj.moves_left = 0
	main._screen_obj._check_outcome()
	await create_timer(0.3).timeout
	_ok("3rd loss in a row: a free Time Scroll", int(gs.items.get("moves", 0)) == scrolls0 + 1)
	mz.add_hearts(2)

	# Leaving a started chapter costs a heart (after a warning).
	main.show_puzzle("dryad")
	await create_timer(0.4).timeout
	pz = main._screen_obj
	pz.moves_left -= 1
	pz._leave_to_roster()
	await process_frame
	_ok("leaving a started chapter asks first", main.modal_open() and mz.hearts() == 4)
	var leave_btn: Button = null
	for b in main._confirm_box.find_children("*", "Button", true, false):
		if String((b as Button).text) == "Leave":
			leave_btn = b
	if leave_btn:
		leave_btn.pressed.emit()
	await create_timer(0.3).timeout
	_ok("...and leaving costs a heart (3)", mz.hearts() == 3)
	main.show_puzzle("dryad")
	await create_timer(0.4).timeout
	main._screen_obj._leave_to_roster()
	await create_timer(0.3).timeout
	_ok("leaving before a move is free", not main.modal_open() and mz.hearts() == 3)
	mz.add_hearts(1)

	# Winning: double the stars for a video.
	main.show_puzzle("dryad")
	await create_timer(0.4).timeout
	pz = main._screen_obj
	var before: int = gs.stars
	pz.score = 999999
	pz._check_outcome()
	await create_timer(0.3).timeout
	_ok("a cleared chapter offers to double its stars", main.modal_open())
	var dbl: Button = null
	for b in main._confirm_box.find_children("*", "Button", true, false):
		if String((b as Button).text).begins_with("Watch a video"):
			dbl = b
	if dbl:
		dbl.pressed.emit()
	await create_timer(0.5).timeout
	var clear := StoryFlow.clear_stars(0)
	_ok("doubled: +%d stars (got +%d)" % [clear * 2, gs.stars - before], gs.stars - before == clear * 2)
	_ok("then her scene plays", (gs.progress_for("dryad").get("won_levels", []) as Array).has(0))

	# Back / Esc on that popup still carries the story on.
	await create_timer(0.5).timeout
	if main.modal_open():
		main.close_modal()
	var pr2 = gs.progress_for("dryad")
	pr2.erase("scene_pending")
	pr2["level_index"] = 1
	main.show_puzzle("dryad")
	await create_timer(0.4).timeout
	pz = main._screen_obj
	pz.score = 999999
	pz._check_outcome()
	await create_timer(0.3).timeout
	var had_popup: bool = main.modal_open()
	main.close_modal()
	await create_timer(0.5).timeout
	_ok("closing the popup with Back still moves the story on", had_popup and (gs.progress_for("dryad").get("won_levels", []) as Array).has(1))

	# Daily caps.
	var left: int = mz.videos_left("stars")
	for i in left + 2:
		mz.watch("stars", func(): pass)
	_ok("free-stars videos stop at %d a day" % mz.DAILY_CAPS.stars, mz.videos_left("stars") == 0 and not mz.can_watch("stars"))

	# Between-chapter ads: grace, then every other chapter, spaced out.
	gs.shop.chapter_ends = 0
	gs.shop.last_ad_end = 0
	gs.shop.last_ad_t = 0.0
	var shown := 0
	for i in 6:
		var t0: float = float(gs.shop.get("last_ad_t", 0.0))
		mz.between_chapters(func(): pass)
		if float(gs.shop.get("last_ad_t", 0.0)) != t0:
			shown += 1
			gs.shop.last_ad_t = 1.0  # pretend the gap has passed
	_ok("between-chapter ads: none before chapter %d, then every %d (%d in 6)" % [mz.GRACE, mz.EVERY, shown], shown == 2)

	# Purchases.
	before = gs.stars
	ShopUI.buy(main, "stars_150")
	_ok("stars_150 gives 150 stars", gs.stars - before == 150)
	var h0: int = mz.hearts()
	ShopUI.buy(main, "hearts_5")
	_ok("5 extra hearts, past the maximum (%d -> %d)" % [h0, mz.hearts()], mz.hearts() == h0 + 5 and mz.hearts() > mz.max_hearts())
	gs.shop.hearts = mz.max_hearts()
	ShopUI.buy(main, "starter_pack")
	_ok("starter pack: stars, items, unlimited hearts", mz.owns("starter_pack") and mz.unlimited() and int(gs.items.get("hammer", 0)) >= 2)
	var s2: int = gs.stars
	ShopUI.buy(main, "starter_pack")
	await process_frame
	_ok("starter pack only once", gs.stars == s2)
	if main.modal_open():
		main.close_modal()
	_ok("unlimited hearts: losing costs nothing", (func(): var h: int = mz.hearts(); mz.spend_heart(); return mz.hearts() == h).call())
	ShopUI.buy(main, "story_pass")
	gs.settings.difficulty = "story"
	_ok("Story Pass: 8 hearts and Story difficulty", mz.max_hearts() == 8 and PuzzleScreen.story_mode())
	gs.settings.difficulty = "easy"
	ShopUI.buy(main, "remove_ads")
	_ok("No Ads: no banner room", mz.no_ads() and mz.banner_space() == 0.0)
	gs.shop.chapter_ends = 100
	gs.shop.last_ad_end = 0
	gs.shop.last_ad_t = 0.0
	mz.between_chapters(func(): pass)
	_ok("No Ads: no ads between chapters", float(gs.shop.last_ad_t) == 0.0)
	var dl: int = mz.videos_left("double")
	var got := [false]
	mz.watch("double", func(): got[0] = true)
	_ok("No Ads: rewards with one tap", got[0] and mz.videos_left("double") == dl - 1)

	# Purchases survive Reset progress and a reload.
	gs.reset_progress()
	gs.save_state()
	gs.shop = {}
	gs.load_state()
	_ok("purchases survive Reset progress and a reload", mz.owns("remove_ads") and mz.owns("story_pass"))

	# The phone shop and More page build.
	main.show_mobile("shop")
	await create_timer(0.3).timeout
	_ok("the Shop lists every offer", main.screen_host.find_children("*", "Button", true, false).size() > mz.PRODUCTS.size())
	main.show_mobile("more")
	await create_timer(0.2).timeout
	_ok("the More page builds", main.screen_host.get_child_count() > 0)

	print("MONETIZE TEST %s (%d problems)" % ["PASSED" if problems == 0 else "FAILED", problems])
	quit()

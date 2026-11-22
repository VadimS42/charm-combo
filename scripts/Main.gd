## Main.gd
##
## Root controller for the whole game. Plays the same role as the single-page
## "screen" switcher in the HTML prototype (div#screen-menu, #screen-puzzle,
## etc. with a .active class) — except here each "screen" is a chunk of UI
## built entirely in code by a small static builder class, and switching
## screens means clearing screen_host and calling the next builder.
##
## This keeps the whole game to one lightweight .tscn (this one) plus plain
## GDScript files, which is easy to review, diff, and hand-edit without the
## editor GUI.
extends Control

var screen_host: Control
## Sits above screen_host in the same area. Holds the Settings overlay, which
## opens OVER whatever screen you're on instead of replacing it — so closing
## it (Back, or the gear again) puts you right back where you were, mid-
## chapter or mid-conversation included, with nothing rebuilt or lost.
var overlay_host: Control
var star_label: Label
## Google Play build: the hearts pill next to the stars (round 50).
var heart_label: Label = null
var heart_panel: Control = null
var test_badge: Label

## Whichever character the current/last screen was about (set by show_puzzle()
## and show_vn_scene()). The roster also uses it to open on her.
var current_char_id: String = ""

## Which girl the roster's flying-camera backdrop was last showing, so coming
## back to the roster (or it being rebuilt) keeps her selected.
var roster_selected_id: String = ""

## Which music a dialogue scene plays: "" = her own theme; "ending" while her
## epilogue runs (StoryFlow sets it), so the epilogue's dialogue, art beats and
## final CG all share one track instead of flipping back and forth.
var story_music: String = ""
## True while a story scene (dialogue, CG, epilogue art) is on screen:
## Settings then offers "Leave to Roster" (round 25), since those screens have
## no back button of their own. Leaving is safe: an unfinished scene plays
## again next time.
var story_scene := false

## The current screen's controller object, when it has one that needs a
## teardown() before its nodes are freed (PuzzleScreen). See clear_screen().
var _screen_obj: Object = null
## How to rebuild the current screen from scratch, for screens that are pure
## functions of saved state (menu/roster/gallery/store). Invalid for screens
## holding live state that can't be rebuilt (puzzle, dialogue, endings).
var _rebuild_route: Callable = Callable()

var _settings_overlay: Control = null
## Set when something toggled in Settings could change what the screen
## underneath shows (stars from Testing Mode, Reduce Motion...), so it gets
## rebuilt on close — only if it's a rebuildable screen, see _rebuild_route.
var _settings_dirty := false
var _settings_btn: Button
var _settings_btn_normal: StyleBox
var _settings_btn_active: StyleBoxFlat

# ---- keyboard / controller (round 16, see Nav.gd) ----
## The control the current screen wants focused first, what Back (B /
## Backspace) does there, extra actions it handles (e.g. the chapter's item
## shortcuts) and the hints shown in the top bar. Set by each screen through
## nav_setup(), reset by clear_screen().
var _focus_default: Control = null
var _back_action: Callable = Callable()
var _screen_actions: Dictionary = {}
var _screen_hints: Array = []
## Top-bar hint row ("A Select · B Back · Start Settings"), nav mode only.
var _hint_row: HBoxContainer
var _hint_bar: PanelContainer
var _root_v: VBoxContainer
## Which main-menu button you last left the menu through ("play", "store",
## "gallery", "achievements", "credits"), so coming back with B / Backspace
## puts the focus back on it instead of always on Play.
var menu_focus := "play"
## Where focus was before Settings or a confirm box opened, to return to it.
var _focus_before_overlay: Control = null
var _settings_default: Control = null
var _confirm_default: Control = null
## Achievement toasts (only when Steam isn't there to show its own popup).
var _toast_host: Control


func _ready() -> void:
	# The desktop layout is built for at least 1280 x 800; phones (round 47)
	# lay out for whatever shape the screen is.
	if not Platform.mobile:
		custom_minimum_size = Vector2(1280, 800)
	UITheme.install_fonts()
	_build_chrome()
	Nav.mode_changed.connect(func(_on): _refresh_hints())
	Achievements.unlocked.connect(_on_achievement_unlocked)
	if CharacterData.load_error() != "":
		show_data_error()
	elif String(GameState.settings.get("language", "")) == "":
		show_language_picker()
	else:
		after_language()


func _build_chrome() -> void:
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_v := VBoxContainer.new()
	root_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_v.add_theme_constant_override("separation", 0)
	add_child(root_v)
	_root_v = root_v
	if Platform.mobile:
		_apply_mobile_scale()
		_fit_safe_area.call_deferred()

	# ---- top bar ----
	# Round 42: no bar any more (the user asked for the purple bar gone). Its
	# stars and Settings button float in the top-right corner over the
	# screen, which now has the whole window; the name is gone. It's added
	# to the window after the screen area (below), so it draws on top.
	var topbar := PanelContainer.new()
	var bar_style := StyleBoxEmpty.new()
	bar_style.content_margin_left = 16
	bar_style.content_margin_right = 14
	bar_style.content_margin_top = 12
	topbar.add_theme_stylebox_override("panel", bar_style)
	topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topbar.anchor_left = 1.0
	topbar.anchor_right = 1.0
	topbar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	topbar.visible = not Platform.trailer
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 10)
	topbar.add_child(top_h)

	# (The name on the bar, "Charm Combo", went with the bar in round 42.)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(top_spacer)

	# Button hints for keyboard/controller play — only shown in nav mode. On
	# their own dark pill at the top centre (round 45): next to Settings they
	# overlapped each screen's own top-right buttons once the bar was gone.
	_hint_bar = PanelContainer.new()
	var hb_style := StyleBoxFlat.new()
	hb_style.bg_color = Color(0.1, 0.05, 0.13, 0.78)
	hb_style.set_corner_radius_all(999)
	hb_style.content_margin_left = 12
	hb_style.content_margin_right = 12
	hb_style.content_margin_top = 4
	hb_style.content_margin_bottom = 4
	_hint_bar.add_theme_stylebox_override("panel", hb_style)
	_hint_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_bar.anchor_left = 0.5
	_hint_bar.anchor_right = 0.5
	_hint_bar.offset_top = 16.0
	_hint_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_bar.visible = false
	_hint_row = HBoxContainer.new()
	_hint_row.add_theme_constant_override("separation", 6)
	_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_bar.add_child(_hint_row)

	test_badge = Label.new()
	test_badge.text = "TEST MODE"
	test_badge.add_theme_font_size_override("font_size", 10)
	test_badge.add_theme_color_override("font_color", Color.WHITE)
	var badge_bg := PanelContainer.new()
	badge_bg.add_theme_stylebox_override("panel", UITheme.button_style(UITheme.SPECIAL_PINK, 999))
	badge_bg.add_child(test_badge)
	badge_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_h.add_child(badge_bg)
	badge_bg.visible = GameState.settings.test_mode

	var star_panel := PanelContainer.new()
	var star_style := UITheme.glass_style(999, 0.0)
	star_style.bg_color = Color(1, 1, 1, 0.14)
	star_style.border_color = Color(1, 1, 1, 0.32)
	star_style.content_margin_left = 12
	star_style.content_margin_right = 14
	star_style.content_margin_top = 6
	star_style.content_margin_bottom = 6
	star_panel.add_theme_stylebox_override("panel", star_style)
	star_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	star_panel.tooltip_text = "Stars — earned by clearing chapters, spent in the Item Shop and on gifts."
	var star_row := HBoxContainer.new()
	star_row.add_theme_constant_override("separation", 6)
	star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_row.add_child(UITheme.icon_or_emoji("star", "⭐", 18))
	star_label = Label.new()
	star_label.add_theme_font_size_override("font_size", 14)
	star_label.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	star_row.add_child(star_label)
	star_panel.add_child(star_row)
	top_h.add_child(star_panel)
	# Google Play build (round 50): hearts; tap for the out-of-hearts popup
	# or the Shop.
	if Monetize.active():
		var hb := Button.new()
		hb.flat = true
		hb.focus_mode = Control.FOCUS_NONE
		hb.add_theme_stylebox_override("normal", star_style)
		hb.add_theme_stylebox_override("hover", star_style)
		hb.add_theme_stylebox_override("pressed", star_style)
		hb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.tooltip_text = "Hearts: losing a chapter costs one, and they come back over time."
		var hr := HBoxContainer.new()
		hr.add_theme_constant_override("separation", 6)
		hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hr.set_anchors_preset(Control.PRESET_FULL_RECT)
		hr.alignment = BoxContainer.ALIGNMENT_CENTER
		hr.add_child(UITheme.icon_or_emoji("heart", "♥", 18))
		heart_label = Label.new()
		heart_label.add_theme_font_size_override("font_size", 14)
		heart_label.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
		hr.add_child(heart_label)
		hb.add_child(hr)
		hb.custom_minimum_size = Vector2(68, 34)
		hb.pressed.connect(func():
			if Monetize.can_play():
				show_mobile("shop")
			else:
				ShopUI.out_of_hearts(self))
		top_h.add_child(hb)
		top_h.move_child(hb, star_panel.get_index())
		heart_panel = hb
		Monetize.changed.connect(refresh_topbar)
		var ht := Timer.new()
		ht.wait_time = 5.0
		ht.autostart = true
		ht.timeout.connect(refresh_topbar)
		add_child(ht)

	# A toggle: opens Settings, and pressing it again while Settings is open
	# does exactly what Settings' own "← Back" does (close_settings()). It
	# stays lit in the accent color while Settings is open, so it reads as
	# the thing to press to get back out. Esc does the same (_unhandled_input).
	# A word, not a gear icon (round 28: words wherever a word works).
	var settings_btn := UITheme.make_glass_button("Settings")
	UITheme.add_icon(settings_btn, "settings")
	settings_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings_btn.tooltip_text = "Settings"
	# Start / Esc open Settings with keys or a pad, so focus navigation stays
	# on the screen itself instead of wandering up into the top bar.
	settings_btn.focus_mode = Control.FOCUS_NONE
	settings_btn.pressed.connect(toggle_settings)
	top_h.add_child(settings_btn)
	_settings_btn = settings_btn
	_settings_btn_normal = settings_btn.get_theme_stylebox("normal")
	_settings_btn_active = StyleBoxFlat.new()
	_settings_btn_active.bg_color = UITheme.ACCENT
	_settings_btn_active.set_corner_radius_all(14)
	_settings_btn_active.content_margin_left = 16
	_settings_btn_active.content_margin_right = 16
	_settings_btn_active.content_margin_top = 9
	_settings_btn_active.content_margin_bottom = 9

	badge_bg.set_meta("is_test_badge", true)
	_test_badge_container = badge_bg

	# A thin rose-gold-violet seam under the bar.
	var seam := TextureRect.new()
	seam.custom_minimum_size = Vector2(0, 3)
	seam.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seam.stretch_mode = TextureRect.STRETCH_SCALE
	seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seam.texture = UITheme.gradient_texture([UITheme.ACCENT, UITheme.ACCENT_2, UITheme.VIOLET], Vector2(0, 0.5), Vector2(1, 0.5))
	root_v.add_child(seam)
	# Off since round 42 (the user asked for it gone); kept so it's one line
	# to bring back.
	seam.visible = false

	# ---- screen area: the current screen, with the overlay layer above it ----
	var screen_area := Control.new()
	screen_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_v.add_child(screen_area)

	screen_host = Control.new()
	screen_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_area.add_child(screen_host)

	overlay_host = Control.new()
	overlay_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_area.add_child(overlay_host)
	# The stars and Settings, over the screen (see "top bar" above).
	add_child(topbar)
	# Screens keep their top rows clear of this corner; a long translated
	# "Settings" widens it (round 52), so tell them its real width.
	topbar.resized.connect(func(): UITheme.set_corner_width(get_tree(), topbar.size.x - 16.0))
	add_child(_hint_bar)

	_toast_host = Control.new()
	_toast_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_area.add_child(_toast_host)

	refresh_topbar()


var _test_badge_container: Control


func refresh_topbar() -> void:
	star_label.text = "%d" % GameState.stars
	if heart_label:
		heart_label.text = ShopUI.hearts_text()
	if _test_badge_container:
		_test_badge_container.visible = GameState.settings.test_mode


func clear_screen() -> void:
	# Every way off a screen comes through here, so this is the one place
	# that can guarantee a screen with in-flight work gets to stop it before
	# its nodes are freed — PuzzleScreen's mid-match animations (see its
	# _torn_down) used to only be stopped by its own "← Roster" button, so
	# leaving any other way (the Settings gear used to be one) let a half-
	# finished match resume on freed nodes and even open a chapter-won
	# scene on top of wherever you'd gone.
	if _screen_obj != null and _screen_obj.has_method("teardown"):
		_screen_obj.teardown()
	_screen_obj = null
	# Banners only under the phone menus, which turn it back on (round 50).
	Monetize.show_banner(false)
	story_scene = false
	_rebuild_route = Callable()
	_focus_default = null
	_back_action = Callable()
	_screen_actions = {}
	_screen_hints = []
	for child in screen_host.get_children():
		child.queue_free()
	_refresh_hints()


# ---- keyboard / controller (Nav.gd) ----

## Called by each screen once it's built: which control to focus first with
## keys or a pad, what Back does there, extra actions it handles
## ({action name: Callable}) and its top-bar hints ([[glyph key, label], ...],
## glyph keys as in Nav.glyph()). In nav mode the default is focused right away.
func nav_setup(default_focus: Control, back_action: Callable = Callable(), actions: Dictionary = {}, hints: Array = []) -> void:
	_focus_default = default_focus
	_back_action = back_action
	_screen_actions = actions
	_screen_hints = hints
	_refresh_hints()
	if Nav.nav_mode:
		_focus_now.call_deferred()


func _focus_now() -> void:
	Nav.focus_default()


## Nav.gd asks this which control should get focus when there's none: an open
## confirm box's Cancel, then Settings, then the screen's own choice (or its
## first focusable control).
func default_focus_control() -> Control:
	if is_instance_valid(_confirm_box) and is_instance_valid(_confirm_default):
		return _confirm_default
	if is_settings_open():
		return _settings_default if is_instance_valid(_settings_default) else _first_focusable(_settings_overlay)
	if is_instance_valid(_focus_default) and _focus_default.is_visible_in_tree():
		return _focus_default
	return _first_focusable(screen_host)


static func _first_focusable(n: Node) -> Control:
	if n is Control and (n as Control).focus_mode == Control.FOCUS_ALL \
			and (n as Control).is_visible_in_tree() and not n.is_queued_for_deletion():
		return n
	for c in n.get_children():
		var f := _first_focusable(c)
		if f != null:
			return f
	return null


func _refresh_hints() -> void:
	if _hint_row == null:
		return
	for c in _hint_row.get_children():
		# Out of the row right away, so its width is the new hints' only.
		_hint_row.remove_child(c)
		c.queue_free()
	_hint_bar.visible = Nav.nav_mode and not Platform.trailer
	if not Nav.nav_mode:
		return
	var hints: Array
	if is_instance_valid(_confirm_box):
		hints = [["move", "Move"], ["accept", "Choose"], ["back", "Cancel"]]
	elif is_settings_open():
		hints = [["move", "Move"], ["accept", "Toggle"], ["back", "Close"]]
	elif not _screen_hints.is_empty():
		hints = _screen_hints
	else:
		hints = [["move", "Move"], ["accept", "Select"]]
		if _back_action.is_valid():
			hints.append(["back", "Back"])
		hints.append(["pause", "Settings"])
	for h in hints:
		_hint_row.add_child(UITheme.keycap(Nav.glyph(String(h[0])), true))
		var l := UITheme.body(String(h[1]), 11, UITheme.INK_ON_DARK_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hint_row.add_child(l)
	# Re-centred on its new width.
	_center_hint_bar.call_deferred()


func _center_hint_bar() -> void:
	if _hint_bar == null:
		return
	var w := _hint_bar.get_combined_minimum_size().x
	_hint_bar.offset_left = -w / 2.0
	_hint_bar.offset_right = w / 2.0


## First launch only: the 18+ notice (round 21). Confirming it leads on to
## the menu; it isn't shown again on this computer.
func show_age_gate() -> void:
	clear_screen()
	_rebuild_route = show_age_gate
	refresh_topbar()
	_menu_music()
	AgeGateScreen.build(self, screen_host)


## First launch: the language picker (round 30), before the age notice.
func show_language_picker() -> void:
	clear_screen()
	_rebuild_route = show_language_picker
	refresh_topbar()
	_menu_music()
	AgeGateScreen.build_language_picker(self, screen_host)


## After the language: the age notice once, then the voice notice / menu.
## The safe-for-work build has no 18+ notice (round 46).
func after_language() -> void:
	if not GameState.settings.get("age_confirmed", false) and not Platform.sfw:
		show_age_gate()
	else:
		show_start()


## After the age notice: the one-time voice notice (when the game has voice
## clips and it hasn't been shown yet), else the main menu.
func show_start() -> void:
	if Voice.any_clips() and not GameState.settings.get("voice_notice_seen", false):
		clear_screen()
		_rebuild_route = show_start
		refresh_topbar()
		_menu_music()
		AgeGateScreen.build_voice_notice(self, screen_host)
	else:
		show_menu()


## data/characters.json didn't load (most likely a typo made while editing the
## dialogue, see docs/EDITING_DIALOGUE.md): say where, instead of opening a
## game with nobody in it.
func show_data_error() -> void:
	clear_screen()
	_rebuild_route = show_data_error
	refresh_topbar()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_host.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.window_style())
	center.add_child(card)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 28)
	card.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	pad.add_child(col)
	col.add_child(UITheme.heading("The dialogue file has a mistake in it", 22))
	var msg := UITheme.body(CharacterData.load_error(), 14, UITheme.INK)
	msg.custom_minimum_size = Vector2(fit_w(620.0), 0)
	col.add_child(msg)
	var hint := UITheme.body("Open that file, fix the line (usually a missing comma, quote mark or bracket, often at the end of the line before), save, and start the game again. docs/EDITING_DIALOGUE.md has the rules.", 13, UITheme.INK_SOFT)
	hint.custom_minimum_size = Vector2(fit_w(620.0), 0)
	col.add_child(hint)


## Phones and tablets (round 47): the menus are MobileShell's tabs instead.
func show_mobile(tab: String, sub: String = "") -> void:
	clear_screen()
	_rebuild_route = func(): show_mobile(tab, sub)
	refresh_topbar()
	_menu_music(tab == "gallery")
	MobileShell.show(self, tab, sub)


func show_menu() -> void:
	store_return_char = ""
	if Platform.mobile:
		show_mobile("home")
		return
	clear_screen()
	_rebuild_route = show_menu
	refresh_topbar()
	_menu_music()
	MenuScreen.build(self, screen_host)


## Menu-type screens (menu, roster, gallery, store, credits, achievements)
## share the menu theme (and tell Steam friends you're in the menus).
## The track picked in the Gallery's Music page (round 49): it keeps playing
## while you stay in the Gallery, and the menu theme comes back after.
var music_pick := ""


func _menu_music(in_gallery: bool = false) -> void:
	story_music = ""
	if not in_gallery:
		music_pick = ""
	Music.play([music_pick] if music_pick != "" else ["menu"])
	Platform.set_presence("menu")


## Rebuilds the Gallery page on screen (the Music page, after picking a track).
func refresh_extras() -> void:
	if _rebuild_route.is_valid():
		_rebuild_route.call()


static func _girl_name(char_id: String) -> String:
	return String(CharacterData.by_id(char_id).get("name", "")).get_slice(" ", 0)


func show_roster() -> void:
	if Platform.mobile:
		show_mobile("girls")
		return
	clear_screen()
	_rebuild_route = show_roster
	refresh_topbar()
	_menu_music()
	RosterScreen.build(self, screen_host)


## replay >= 0 replays that already-cleared chapter for stars instead of
## playing her current one (round 33, see PuzzleScreen.replay).
## mode (round 49): "" her story, "free" a free date, "daily" today's challenge.
func show_puzzle(char_id: String, replay: int = -1, mode: String = "") -> void:
	# Google Play build (round 50): story chapters and replays need a heart.
	if mode == "" and not Monetize.can_play():
		ShopUI.out_of_hearts(self)
		return
	current_char_id = char_id
	clear_screen()
	refresh_topbar()
	story_music = ""
	Music.play([char_id, "menu"])
	Platform.set_presence("chapter", _girl_name(char_id),
		(replay if replay >= 0 else int(GameState.progress_for(char_id).get("level_index", 0))) + 1)
	# PuzzleScreen (unlike the other screens) is instantiated rather than a
	# static builder, since it owns a lot of mutable per-chapter state
	# (board, score, moves, selection...) referenced across many button
	# callbacks. Keeping it as a RefCounted instance means all that state
	# lives in one place instead of getting smuggled through node metadata —
	# and holding it here lets clear_screen() tear it down on ANY exit.
	var puzzle := PuzzleScreen.new()
	_screen_obj = puzzle
	puzzle.setup(self, screen_host, char_id, replay, mode)


## Today's daily challenge (round 49): one scored try a day. Unlocked once any
## chapter has been cleared (the boards use her last chapter's piece).
static func daily_available() -> bool:
	return GameState.stat("chapters_won") > 0 or CharacterData.all().any(func(c):
		return not (GameState.progress_for(String(c.id)).get("won_levels", []) as Array).is_empty())


static func daily_done_today() -> bool:
	return GameState.stats.has("daily_" + PuzzleScreen.daily_key())


func show_daily() -> void:
	if daily_done_today():
		return
	GameState.stats["daily_" + PuzzleScreen.daily_key()] = 0
	GameState.save_state()
	show_puzzle(PuzzleScreen.daily_girl(), -1, "daily")


## A button for the menu / Home: today's challenge, or today's score.
func daily_button() -> Button:
	var done := daily_done_today()
	var b := UITheme.make_ghost_button(UITheme.t("Daily challenge: %d pts") % GameState.stat("daily_" + PuzzleScreen.daily_key())
		if done else UITheme.t("Daily challenge"))
	UITheme.add_icon(b, "star")
	b.disabled = done or not daily_available()
	# Google Play build: one more try at today's board for a video.
	if done and Monetize.can_watch("daily"):
		b.text = Monetize.watch_label(UITheme.t("one more daily try"))
		b.disabled = false
		b.pressed.connect(func():
			Monetize.watch("daily", func():
				GameState.stats.erase("daily_" + PuzzleScreen.daily_key())
				show_daily()))
		return b
	b.tooltip_text = UITheme.t("A new board every day, the same for everyone: %d moves, one try. Come back tomorrow for the next.") % PuzzleScreen.DAILY_MOVES \
		if daily_available() else UITheme.t("Clear any chapter to unlock the daily challenge.")
	b.pressed.connect(func():
		SFX.nav()
		show_daily())
	return b


# ---- Settings (an overlay, not a screen — see overlay_host) ----

func is_settings_open() -> bool:
	return _settings_overlay != null and is_instance_valid(_settings_overlay)


func show_settings() -> void:
	if is_settings_open():
		return
	_settings_dirty = false
	var overlay := Control.new()
	overlay.name = "SettingsOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Swallows every click so nothing on the screen underneath can be poked
	# while Settings covers it.
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var base := ColorRect.new()
	base.color = UITheme.BG
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(base)
	overlay_host.add_child(overlay)
	_settings_overlay = overlay
	_focus_before_overlay = get_viewport().gui_get_focus_owner()
	_settings_default = null
	SettingsScreen.build(self, overlay)
	_set_settings_btn_active(true)
	_refresh_hints()
	if Nav.nav_mode:
		_focus_now.call_deferred()
	if not GameState.settings.get("reduce_motion", false):
		overlay.modulate.a = 0.0
		overlay.create_tween().tween_property(overlay, "modulate:a", 1.0, 0.14)


## What Settings' "← Back" does, and what the gear does while Settings is
## open: drop the overlay and reveal the screen underneath exactly as it was.
func close_settings() -> void:
	if not is_settings_open():
		return
	_settings_overlay.queue_free()
	_settings_overlay = null
	_set_settings_btn_active(false)
	refresh_topbar()
	if _settings_dirty and _rebuild_route.is_valid():
		_rebuild_route.call()
	_settings_dirty = false
	_refresh_hints()
	_restore_focus_after_overlay()


## Focus was on something inside Settings or a confirm box that's now gone:
## hand it back to where it was (or the screen's default in nav mode; with the
## mouse, to the screen's top-level focusable control — e.g. the dialogue
## screen, whose Space/Enter-to-continue needs focus).
func _restore_focus_after_overlay() -> void:
	var prev := _focus_before_overlay
	_focus_before_overlay = null
	if is_instance_valid(prev) and prev.is_visible_in_tree() and not prev.is_queued_for_deletion():
		prev.grab_focus()
		return
	if Nav.nav_mode:
		_focus_now.call_deferred()
		return
	for c in screen_host.get_children():
		if c is Control and not c.is_queued_for_deletion() and (c as Control).focus_mode != Control.FOCUS_NONE:
			(c as Control).grab_focus()
			break


## SettingsScreen names its first row's control as the focus default.
func set_settings_focus(c: Control) -> void:
	_settings_default = c


func toggle_settings() -> void:
	SFX.nav()
	if is_settings_open():
		close_settings()
	else:
		show_settings()


## Called by SettingsScreen whenever a toggle changes something the screen
## underneath might be showing.
func mark_settings_dirty() -> void:
	_settings_dirty = true


func _set_settings_btn_active(on: bool) -> void:
	if _settings_btn == null:
		return
	_settings_btn.add_theme_stylebox_override("normal", _settings_btn_active if on else _settings_btn_normal)
	_settings_btn.add_theme_color_override("font_color", Color.WHITE)
	_settings_btn.tooltip_text = "Close settings" if on else "Settings"


## char_id is REQUIRED here (not implicitly read off current_char_id) — this
## used to just read current_char_id, which is only ever written by
## show_puzzle(). That made every dialogue scene reached WITHOUT first opening
## that exact character's puzzle screen this session — her intro (played
## before her first chapter even starts), a gift "thank you" line from the
## roster, or a chapter-win scene for anyone other than whoever's puzzle was
## last opened — silently render as the WRONG character (or a blank one, on
## the very first scene of a session): wrong name, wrong accent, wrong
## portrait/background, while still showing that character's actual dialogue
## text. Taking char_id as a real parameter (like show_puzzle/show_ending_cg
## already do) and setting current_char_id from it fixes this at the root.
func show_vn_scene(char_id: String, lines: Array, choice_data, on_done: Callable, cg_key: String = "") -> void:
	current_char_id = char_id
	# The safe-for-work build's version of each line (round 46).
	lines = StoryFlow.sfw_lines(lines)
	if Platform.sfw and cg_key.begins_with("night"):
		cg_key = ""
	clear_screen()
	if story_music != "":
		Music.play([story_music, char_id, "menu"])
	else:
		Music.play([char_id, "menu"])
	Platform.set_presence("ending" if story_music == "ending" else "story", _girl_name(char_id))
	story_scene = true
	VNScreen.build(self, screen_host, char_id, lines, choice_data, on_done, cg_key)


func show_ending_cg(char_id: String, ending: Dictionary, on_continue: Callable) -> void:
	clear_screen()
	Music.play(["ending", char_id, "menu"])
	Platform.set_presence("ending", _girl_name(char_id))
	story_scene = true
	EndingCGScreen.build(self, screen_host, char_id, StoryFlow.ending_card_for(ending), on_continue)


## One "big art reveal" beat of a character's post-story epilogue — see
## StoryFlow._play_epilogue(). caption is an optional short line shown under
## the picture ("" for none); cg_key picks its image (ArtAssets.cg()).
func show_ending_art_beat(char_id: String, caption: String, on_continue: Callable, cg_key: String = "") -> void:
	clear_screen()
	Music.play(["ending", char_id, "menu"])
	Platform.set_presence("ending", _girl_name(char_id))
	story_scene = true
	EndingArtBeatScreen.build(self, screen_host, char_id, caption, on_continue, cg_key)


## Where the Gallery's "← Back" returns to: whichever screen opened it (the
## menu or the roster). Viewing an ending from the Gallery and coming back
## keeps the original.
var _gallery_return: Callable = Callable()

## page (round 49): "endings", "pictures", "music" or "stats".
func show_gallery(page: String = "endings") -> void:
	if Platform.mobile:
		show_mobile("gallery", "" if page == "endings" else page)
		return
	if _rebuild_route.is_valid() and not GalleryScreen.is_route(_rebuild_route):
		_gallery_return = _rebuild_route
	clear_screen()
	_rebuild_route = func(): show_gallery(page)
	GalleryScreen.route_tag = _rebuild_route
	_menu_music(true)
	GalleryScreen.build(self, screen_host, page)


func leave_gallery() -> void:
	if _gallery_return.is_valid():
		_gallery_return.call()
	else:
		show_roster()


## Set while the Item Shop was opened from a chapter's Out of Moves screen:
## the shop's Back then goes straight back into that chapter for a fresh try
## (round 17). Cleared whenever the main menu opens.
var store_return_char := ""
## ...and which cleared chapter, when that was a replay (-1: her current one).
var store_return_replay := -1

func show_store() -> void:
	if Platform.mobile:
		show_mobile("shop")
		return
	clear_screen()
	_rebuild_route = show_store
	refresh_topbar()
	_menu_music()
	StoreScreen.build(self, screen_host)


func open_store_from_chapter(char_id: String, replay: int = -1) -> void:
	store_return_char = char_id
	store_return_replay = replay
	show_store()


## The Item Shop's Back: into the chapter it was opened from, else the menu.
func leave_store() -> void:
	var cid := store_return_char
	store_return_char = ""
	if cid != "":
		show_puzzle(cid, store_return_replay)
	else:
		show_menu()


func show_credits() -> void:
	if Platform.mobile:
		show_mobile("more", "credits")
		return
	clear_screen()
	_rebuild_route = show_credits
	_menu_music()
	CreditsScreen.build(self, screen_host)


func show_achievements() -> void:
	if Platform.mobile:
		show_mobile("gallery", "achievements")
		return
	clear_screen()
	_rebuild_route = show_achievements
	_menu_music()
	AchievementsScreen.build(self, screen_host)


# ---- keyboard ----

## Esc / Start opens or closes Settings (same as the gear; or dismisses an
## open confirm box). Backspace / B goes back: confirm box, then Settings, then
## the screen's own Back. F11 toggles fullscreen. Screen actions (the
## chapter's item shortcuts) come last.
## Back: the open confirm box, then Settings, then the screen's own Back.
## Returns false if there was nothing to go back from.
func go_back() -> bool:
	if is_instance_valid(_confirm_box):
		SFX.nav()
		_close_confirm()
	elif is_settings_open():
		toggle_settings()
	elif _back_action.is_valid():
		_back_action.call()
	else:
		return false
	return true


## Android's Back button / gesture (round 46; project setting
## quit_on_go_back is off): same as B. With nothing to go back from (the main
## menu), it leaves the game the way Android apps do.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not go_back() and Platform.mobile:
			GameState.quit_game()
	elif what == NOTIFICATION_WM_SIZE_CHANGED and Platform.mobile:
		_apply_mobile_scale()
		_fit_safe_area.call_deferred()


## A fixed width for a dialog or message, narrowed to fit a phone's screen
## (round 47; on the desktop it's always the width asked for).
func fit_w(w: float) -> float:
	if not Platform.mobile:
		return w
	return minf(w, get_viewport().get_visible_rect().size.x - 40.0)


## Phones and tablets (round 47): the screen's short side is always
## MOBILE_SHORT game units, whichever way it's held, so text and buttons come
## out phone-sized (the desktop's 800 units tall made them tiny). Turning the
## phone rebuilds the current screen for the new shape.
const MOBILE_SHORT := 480.0
var _mobile_portrait := -1


func _apply_mobile_scale() -> void:
	var win := get_window()
	var sz := Vector2(win.size)
	if sz.x <= 0 or sz.y <= 0:
		return
	var k := MOBILE_SHORT / minf(sz.x, sz.y)
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(roundi(sz.x * k), roundi(sz.y * k))
	var up := 1 if sz.y > sz.x else 0
	if _mobile_portrait != -1 and up != _mobile_portrait:
		_relayout.call_deferred()
	_mobile_portrait = up


## The phone turned: the same screen, laid out again.
func _relayout() -> void:
	if _screen_obj != null and _screen_obj.has_method("relayout"):
		_screen_obj.relayout()
	elif _rebuild_route.is_valid():
		_rebuild_route.call()
	_refresh_hints()


## Phones: keep everything inside the display's safe area (camera notch,
## rounded corners), as margins in game units.
func _fit_safe_area() -> void:
	if _root_v == null or not Platform.mobile:
		return
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0:
		return
	var k: float = get_viewport().get_visible_rect().size.x / float(screen.x)
	_root_v.offset_left = safe.position.x * k
	_root_v.offset_top = safe.position.y * k
	_root_v.offset_right = -(screen.x - safe.end.x) * k
	_root_v.offset_bottom = -(screen.y - safe.end.y) * k


# ---- long-press tooltips on phones (round 47) ----
# Touch screens have no hover, so the tooltips (what an item does, her
# power, the goal...) never showed. Holding a finger still on anything that
# has one for half a second shows it in a bubble; lifting the finger then
# closes it without also pressing the button underneath.
const LONG_PRESS_S := 0.5
var _lp_pos := Vector2.ZERO
var _lp_token := 0
var _lp_bubble: Control = null


func _input(event: InputEvent) -> void:
	if not Platform.mobile:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_lp_token += 1
		if event.pressed:
			_lp_pos = (event as InputEventMouseButton).position
			var tok := _lp_token
			get_tree().create_timer(LONG_PRESS_S).timeout.connect(func():
				if tok == _lp_token:
					_long_press())
		elif is_instance_valid(_lp_bubble):
			_lp_bubble.queue_free()
			_lp_bubble = null
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and ((event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT):
		if (event as InputEventMouseMotion).position.distance_to(_lp_pos) > 12.0:
			_lp_token += 1


func _long_press() -> void:
	var tip := ""
	for c in find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.tooltip_text != "" and ctl.is_visible_in_tree() and ctl.get_global_rect().has_point(_lp_pos):
			tip = ctl.tooltip_text  # the last match is the one drawn on top
	if tip == "":
		return
	var vs := get_viewport().get_visible_rect().size
	var bubble := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.06, 0.15, 0.94)
	st.set_corner_radius_all(12)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	bubble.add_theme_stylebox_override("panel", st)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.body(UITheme.t(tip), 13, Color.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(300.0, vs.x - 40.0), 0)
	bubble.add_child(l)
	_toast_host.add_child(bubble)
	bubble.reset_size()
	var sz := bubble.get_combined_minimum_size()
	bubble.position = Vector2(clampf(_lp_pos.x - sz.x / 2.0, 12.0, vs.x - sz.x - 12.0),
		clampf(_lp_pos.y - sz.y - 40.0, 12.0, vs.y - sz.y - 12.0))
	_lp_bubble = bubble
	SFX.buzz(20)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event.echo or not event.pressed):
		return
	if event.is_action_pressed("cc_pause"):
		if is_instance_valid(_confirm_box):
			_close_confirm()
		else:
			toggle_settings()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cc_back"):
		go_back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.keycode == KEY_F11:
		GameState.set_fullscreen(not bool(GameState.settings.get("fullscreen", false)))
		if is_settings_open():
			close_settings()
			show_settings()
		get_viewport().set_input_as_handled()
	elif not is_settings_open() and not is_instance_valid(_confirm_box):
		for action in _screen_actions.keys():
			if event.is_action_pressed(action):
				(_screen_actions[action] as Callable).call()
				get_viewport().set_input_as_handled()
				return


# ---- confirm box ----

var _confirm_box: Control = null

## A small modal "are you sure?" box over everything (screens and Settings).
## on_confirm runs only on the confirm button; Cancel, a click outside, or Esc
## dismiss it.
func confirm(title: String, message: String, confirm_label: String, on_confirm: Callable) -> void:
	_close_confirm()
	var shade := ColorRect.new()
	shade.name = "ConfirmBox"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.1, 0.07, 0.12, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_close_confirm()
	)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.window_style())
	card.custom_minimum_size = Vector2(fit_w(420.0), 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(UITheme.heading(title, 18))
	var msg := UITheme.body(message, 13, UITheme.INK_SOFT)
	msg.custom_minimum_size = Vector2(fit_w(390.0), 0)
	v.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var cancel := UITheme.make_ghost_button("Cancel")
	cancel.pressed.connect(func():
		SFX.nav()
		_close_confirm()
	)
	row.add_child(cancel)
	# The safe choice is where focus lands with keys or a pad.
	_confirm_default = cancel
	var ok := UITheme.make_primary_button(confirm_label)
	ok.pressed.connect(func():
		SFX.nav()
		_close_confirm()
		on_confirm.call()
	)
	row.add_child(ok)
	if not is_instance_valid(_confirm_box):
		_focus_before_overlay = get_viewport().gui_get_focus_owner()
	overlay_host.add_child(shade)
	_confirm_box = shade
	_refresh_hints()
	if Nav.nav_mode:
		_focus_now.call_deferred()


## A popup of the caller's own making (HowToPlay's page and tips) in the same
## slot as confirm(): one at a time, Esc / Backspace / B close it, and focus
## goes back where it was afterwards.
func open_modal(shade: Control, default_focus: Control) -> void:
	_close_confirm()
	_focus_before_overlay = get_viewport().gui_get_focus_owner()
	overlay_host.add_child(shade)
	_confirm_box = shade
	_confirm_default = default_focus
	_refresh_hints()
	if Nav.nav_mode:
		_focus_now.call_deferred()
	elif default_focus:
		default_focus.grab_focus.call_deferred()


func close_modal() -> void:
	_close_confirm()


func modal_open() -> bool:
	return is_instance_valid(_confirm_box)


## The end of the demo (Platform.demo): thanks, and a wishlist button.
func show_demo_end() -> void:
	clear_screen()
	Music.play(["menu"])
	screen_host.add_child(UITheme.make_screen_backdrop(UITheme.ACCENT, UITheme.VIOLET))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_host.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.window_style())
	card.custom_minimum_size = Vector2(fit_w(560.0), 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	v.add_child(UITheme.heading("Thanks for playing the demo!", 24))
	var t := UITheme.body("The full game has four stories: Hazel's, and three more women of Millbrook to meet in the worst way possible. Each has four chapters, her night scene and her ending.", 14, UITheme.INK_SOFT)
	t.custom_minimum_size = Vector2(fit_w(500.0), 0)
	v.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var menu_btn := UITheme.make_ghost_button("Main menu")
	UITheme.add_icon(menu_btn, "menu")
	menu_btn.pressed.connect(func():
		SFX.nav()
		show_menu()
	)
	row.add_child(menu_btn)
	var url := Platform.wishlist_url()
	var wish := UITheme.make_primary_button("Wishlist on Steam")
	UITheme.add_icon(wish, "heart", 20)
	wish.disabled = url == ""
	wish.tooltip_text = "" if url != "" else "Store page address not set yet (Platform.STORE_URL)."
	wish.pressed.connect(func():
		SFX.nav()
		OS.shell_open(url)
	)
	# Epic and Android builds don't point at Steam at all (round 46).
	if Platform.links_to_steam():
		row.add_child(wish)
	else:
		wish.queue_free()
		url = ""
	nav_setup(wish if url != "" else menu_btn, func(): show_menu())


func show_how_to_play() -> void:
	HowToPlay.show_page(self)


func _close_confirm() -> void:
	var had := is_instance_valid(_confirm_box)
	if had:
		_confirm_box.queue_free()
	_confirm_box = null
	_confirm_default = null
	if had:
		_refresh_hints()
		_restore_focus_after_overlay()


# ---- achievement toasts ----

func _on_achievement_unlocked(id: String) -> void:
	# On Steam the overlay shows its own popup; everywhere else, ours.
	if Platform.steam_active():
		return
	show_achievement_toast(id)


## "Achievement unlocked" banner at the top of the screen for ~3 seconds.
func show_achievement_toast(id: String) -> void:
	var a := Achievements.info(id)
	if a.is_empty():
		return
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := UITheme.glass_style(16, 0.82)
	st.border_color = UITheme.ACCENT_2
	st.set_border_width_all(2)
	st.content_margin_left = 12
	st.content_margin_right = 18
	p.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var tex := Achievements.icon(id)
	if tex:
		var t := TextureRect.new()
		t.texture = tex
		t.custom_minimum_size = Vector2(40, 40)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(t)
	else:
		var trophy_tex := ArtAssets.ui_icon("achievements")
		if trophy_tex:
			var tr := UITheme.picture(trophy_tex, 34)
			tr.modulate = UITheme.ACCENT_2
			h.add_child(tr)
		else:
			var trophy := Label.new()
			trophy.text = "🏆"
			trophy.add_theme_font_size_override("font_size", 26)
			trophy.add_theme_color_override("font_color", UITheme.ACCENT_2)
			h.add_child(trophy)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var cap := Label.new()
	cap.text = "ACHIEVEMENT UNLOCKED"
	cap.add_theme_font_size_override("font_size", 10)
	cap.add_theme_color_override("font_color", UITheme.ACCENT_2)
	cap.add_theme_font_override("font", UITheme.tracked_font(2))
	v.add_child(cap)
	var nm := Label.new()
	nm.text = String(a.name)
	nm.add_theme_font_size_override("font_size", 15)
	nm.add_theme_color_override("font_color", Color.WHITE)
	v.add_child(nm)
	var stack := _toast_host.get_child_count()
	_toast_host.add_child(p)
	var sz := p.get_combined_minimum_size()
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.offset_left = -sz.x / 2.0
	p.offset_right = sz.x / 2.0
	p.offset_top = 10.0 + stack * (sz.y + 8.0)
	p.offset_bottom = p.offset_top + sz.y
	SFX.purchase()
	if GameState.settings.get("reduce_motion", false):
		get_tree().create_timer(3.2).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free()
		)
		return
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)

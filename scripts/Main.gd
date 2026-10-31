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

	# ---- top bar ----
	var topbar := PanelContainer.new()
	# Round 19: plum-to-berry, with light text and glass pills on it.
	topbar.add_theme_stylebox_override("panel", UITheme.topbar_style())
	root_v.add_child(topbar)
	topbar.visible = not Platform.trailer
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 10)
	topbar.add_child(top_h)

	# The game's logo (art/ui/logo.png) when it exists, else the text brand.
	var logo_tex := ArtAssets.ui_icon("logo")
	if logo_tex:
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.custom_minimum_size = Vector2(0, 36)
		logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top_h.add_child(logo)
	else:
		# The heart picture before the name, where the 💞 emoji was.
		var heart := UITheme.emoji_art("💞")
		if heart:
			top_h.add_child(UITheme.picture(heart, 24))
		var brand := UITheme.heading("Charm Combo" if heart else "💞 Charm Combo", 18)
		brand.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
		brand.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
		brand.add_theme_constant_override("shadow_offset_y", 1)
		# heading() word-wraps by default, and a wrapping Label only asks an
		# HBoxContainer for the width of its longest word — so the brand was
		# squeezed into three stacked lines, stretching the whole top bar.
		brand.autowrap_mode = TextServer.AUTOWRAP_OFF
		brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top_h.add_child(brand)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(top_spacer)

	# Button hints for keyboard/controller play — only shown in nav mode.
	_hint_row = HBoxContainer.new()
	_hint_row.add_theme_constant_override("separation", 6)
	_hint_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_row.visible = false
	top_h.add_child(_hint_row)

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
	seam.visible = not Platform.trailer

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

	_toast_host = Control.new()
	_toast_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_area.add_child(_toast_host)

	refresh_topbar()


var _test_badge_container: Control


func refresh_topbar() -> void:
	star_label.text = "%d" % GameState.stars
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
		c.queue_free()
	_hint_row.visible = Nav.nav_mode
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
func after_language() -> void:
	if not GameState.settings.get("age_confirmed", false):
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
	msg.custom_minimum_size = Vector2(620, 0)
	col.add_child(msg)
	var hint := UITheme.body("Open that file, fix the line (usually a missing comma, quote mark or bracket, often at the end of the line before), save, and start the game again. docs/EDITING_DIALOGUE.md has the rules.", 13, UITheme.INK_SOFT)
	hint.custom_minimum_size = Vector2(620, 0)
	col.add_child(hint)


func show_menu() -> void:
	store_return_char = ""
	clear_screen()
	_rebuild_route = show_menu
	refresh_topbar()
	_menu_music()
	MenuScreen.build(self, screen_host)


## Menu-type screens (menu, roster, gallery, store, credits, achievements)
## share the menu theme (and tell Steam friends you're in the menus).
func _menu_music() -> void:
	story_music = ""
	Music.play(["menu"])
	Platform.set_presence("menu")


static func _girl_name(char_id: String) -> String:
	return String(CharacterData.by_id(char_id).get("name", "")).get_slice(" ", 0)


func show_roster() -> void:
	clear_screen()
	_rebuild_route = show_roster
	refresh_topbar()
	_menu_music()
	RosterScreen.build(self, screen_host)


## replay >= 0 replays that already-cleared chapter for stars instead of
## playing her current one (round 33, see PuzzleScreen.replay).
func show_puzzle(char_id: String, replay: int = -1) -> void:
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
	puzzle.setup(self, screen_host, char_id, replay)


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
	EndingCGScreen.build(self, screen_host, char_id, ending, on_continue)


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

func show_gallery() -> void:
	if _rebuild_route.is_valid() and _rebuild_route != show_gallery:
		_gallery_return = _rebuild_route
	clear_screen()
	_rebuild_route = show_gallery
	_menu_music()
	GalleryScreen.build(self, screen_host)


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
	clear_screen()
	_rebuild_route = show_credits
	_menu_music()
	CreditsScreen.build(self, screen_host)


func show_achievements() -> void:
	clear_screen()
	_rebuild_route = show_achievements
	_menu_music()
	AchievementsScreen.build(self, screen_host)


# ---- keyboard ----

## Esc / Start opens or closes Settings (same as the gear; or dismisses an
## open confirm box). Backspace / B goes back: confirm box, then Settings, then
## the screen's own Back. F11 toggles fullscreen. Screen actions (the
## chapter's item shortcuts) come last.
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
		if is_instance_valid(_confirm_box):
			SFX.nav()
			_close_confirm()
		elif is_settings_open():
			toggle_settings()
		elif _back_action.is_valid():
			_back_action.call()
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
	card.custom_minimum_size = Vector2(420, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(UITheme.heading(title, 18))
	var msg := UITheme.body(message, 13, UITheme.INK_SOFT)
	msg.custom_minimum_size = Vector2(390, 0)
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
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	v.add_child(UITheme.heading("Thanks for playing the demo!", 24))
	var t := UITheme.body("The full game has four stories: Hazel's, and three more women of Millbrook to meet in the worst way possible. Each has four chapters, her night scene and her ending.", 14, UITheme.INK_SOFT)
	t.custom_minimum_size = Vector2(500, 0)
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
	row.add_child(wish)
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

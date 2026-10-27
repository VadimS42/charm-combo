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
var star_label: Label
var test_badge: Label

## Set by a dialogue choice just before a puzzle chapter starts; consumed by
## PuzzleScreen when it builds the chapter. Mirrors GameState.pending_start_bonus.
var current_char_id: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(1280, 800)
	_build_chrome()
	show_menu()


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
	topbar.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.SURFACE_2, 0, UITheme.LINE, 0))
	root_v.add_child(topbar)
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 10)
	topbar.add_child(top_h)

	var brand := UITheme.heading("💞 Charm Combo", 18)
	top_h.add_child(brand)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(top_spacer)

	test_badge = Label.new()
	test_badge.text = "TEST MODE"
	test_badge.add_theme_font_size_override("font_size", 10)
	test_badge.add_theme_color_override("font_color", Color.WHITE)
	var badge_bg := PanelContainer.new()
	badge_bg.add_theme_stylebox_override("panel", UITheme.button_style(UITheme.SPECIAL_PINK, 999))
	badge_bg.add_child(test_badge)
	top_h.add_child(badge_bg)
	badge_bg.visible = GameState.settings.test_mode

	var star_panel := PanelContainer.new()
	star_panel.add_theme_stylebox_override("panel", UITheme.panel_style(UITheme.SURFACE, 999, UITheme.LINE))
	star_label = Label.new()
	star_label.add_theme_font_size_override("font_size", 14)
	star_label.add_theme_color_override("font_color", UITheme.INK)
	star_panel.add_child(star_label)
	top_h.add_child(star_panel)

	var settings_btn := UITheme.make_ghost_button("⚙")
	settings_btn.pressed.connect(func(): show_settings())
	top_h.add_child(settings_btn)

	badge_bg.set_meta("is_test_badge", true)
	_test_badge_container = badge_bg

	# ---- screen host ----
	screen_host = Control.new()
	screen_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_v.add_child(screen_host)

	refresh_topbar()


var _test_badge_container: Control


func refresh_topbar() -> void:
	star_label.text = "⭐ %d" % GameState.stars
	if _test_badge_container:
		_test_badge_container.visible = GameState.settings.test_mode


func clear_screen() -> void:
	for child in screen_host.get_children():
		child.queue_free()


func show_menu() -> void:
	clear_screen()
	refresh_topbar()
	MenuScreen.build(self, screen_host)


func show_settings() -> void:
	clear_screen()
	SettingsScreen.build(self, screen_host)


func show_roster() -> void:
	clear_screen()
	refresh_topbar()
	RosterScreen.build(self, screen_host)


func show_puzzle(char_id: String) -> void:
	current_char_id = char_id
	clear_screen()
	refresh_topbar()
	# PuzzleScreen (unlike the other screens) is instantiated rather than a
	# static builder, since it owns a lot of mutable per-chapter state
	# (board, score, moves, selection...) referenced across many button
	# callbacks. Keeping it as a RefCounted instance means all that state
	# lives in one place instead of getting smuggled through node metadata.
	var puzzle := PuzzleScreen.new()
	puzzle.setup(self, screen_host, char_id)


func show_vn_scene(lines: Array, choice_data, on_done: Callable) -> void:
	clear_screen()
	VNScreen.build(self, screen_host, current_char_id, lines, choice_data, on_done)


func show_ending_cg(char_id: String, ending: Dictionary, on_continue: Callable) -> void:
	clear_screen()
	EndingCGScreen.build(self, screen_host, char_id, ending, on_continue)


func show_gallery() -> void:
	clear_screen()
	GalleryScreen.build(self, screen_host)


func show_store() -> void:
	clear_screen()
	refresh_topbar()
	StoreScreen.build(self, screen_host)

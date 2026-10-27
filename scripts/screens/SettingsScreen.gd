## SettingsScreen.gd — sound / volume / reduce motion / fullscreen / test
## mode / reset, equivalent to #screen-settings in the HTML prototype.
## Toggling Testing Mode also grants 99 stars, same as the HTML version's
## toggleTest handler (the row is hidden once GameState.ALLOW_TESTING_MODE is
## off for release).
##
## Since round 13 this is built into Main's settings OVERLAY (see
## Main.show_settings()), on top of whatever screen was open — "← Back" and
## the top bar's gear both call Main.close_settings(), which simply removes
## the overlay and puts you back exactly where you were.
class_name SettingsScreen
extends RefCounted

## Settings is a short list of rows — a centered column reads better than
## rows stretched edge to edge across a 1280px window.
const COLUMN_W := 720.0

static func build(main: Node, host: Control) -> void:
	host.add_child(UITheme.make_screen_backdrop(UITheme.SPECIAL_PINK, UITheme.ACCENT_2))

	# Side/top margins: this screen used to run flush against the window
	# edges, with the "Settings" heading starting at x = 0.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	host.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	var top_row := HBoxContainer.new()
	var back := UITheme.make_ghost_button("←  Back")
	back.pressed.connect(func():
		SFX.nav()
		main.close_settings()
	)
	top_row.add_child(back)
	outer.add_child(top_row)

	# Scrolls once the rows outgrow the window (round 25 added several).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	UITheme.make_scroll_navigable(scroll)
	outer.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(COLUMN_W, 0)
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)

	v.add_child(UITheme.heading("Settings", 22))

	var sound_row := _row(
		"Sound Effects", "Chimes for matches, combos, and menus.",
		GameState.settings.sound,
		func(on: bool):
			GameState.settings.sound = on
			GameState.save_state()
	)
	v.add_child(sound_row)
	# Keys / a pad land on the first toggle when Settings opens.
	main.set_settings_focus(sound_row.get_meta("control"))

	v.add_child(_slider_row(
		"Master Volume", "Everything — music and sound effects.",
		float(GameState.settings.get("volume", 0.8)),
		func(val: float):
			GameState.set_volume(val)
			# A tick at the new level, so you can hear what you picked.
			SFX.nav()
	))

	# Only once the game actually has music (tracks are drop-in files, see
	# Music.gd) — a slider that does nothing would just be confusing.
	if Music.any_tracks():
		v.add_child(_slider_row(
			"Music", "How loud the background music plays.",
			float(GameState.settings.get("music_volume", Music.DEFAULT_VOLUME)),
			func(val: float):
				GameState.settings.music_volume = val
				Music.apply_volume()
				GameState.save_state()
		))

	# Same idea for voice acting: only once some lines are recorded.
	if Voice.any_clips():
		v.add_child(_row(
			"Voice Acting", "Hear the girls speak their lines.",
			GameState.settings.get("voice", true),
			func(on: bool):
				GameState.settings.voice = on
				if not on:
					Voice.stop()
				GameState.save_state()
		))
		v.add_child(_slider_row(
			"Voice Volume", "How loud their voices play.",
			float(GameState.settings.get("voice_volume", Voice.DEFAULT_VOLUME)),
			func(val: float):
				GameState.settings.voice_volume = val
				Voice.apply_volume()
				GameState.save_state()
		))

	# Dialogue (round 25): how text appears, Auto's pace, what Skip skips.
	v.add_child(_choice_row(
		"Text Speed", "How fast dialogue types out.",
		[["slow", "Slow"], ["normal", "Normal"], ["fast", "Fast"], ["instant", "Instant"]],
		String(GameState.settings.get("text_speed", "normal")),
		func(key: String):
			GameState.settings.text_speed = key
			GameState.save_state()
	))
	v.add_child(_slider_row(
		"Auto Speed", "How long Auto waits after each line (left = quicker).",
		float(GameState.settings.get("auto_delay", 0.5)),
		func(val: float):
			GameState.settings.auto_delay = val
			GameState.save_state()
	))
	v.add_child(_row(
		"Skip Unread Lines", "Let Skip race through lines you haven't read yet, too.",
		bool(GameState.settings.get("skip_unseen", false)),
		func(on: bool):
			GameState.settings.skip_unseen = on
			GameState.save_state()
	))

	v.add_child(_row(
		"Reduce Motion", "Shorter animations, calmer feedback.",
		GameState.settings.reduce_motion,
		func(on: bool):
			GameState.settings.reduce_motion = on
			GameState.save_state()
			# e.g. the roster's drifting camera underneath should hold still.
			main.mark_settings_dirty()
	))

	v.add_child(_row(
		"Fullscreen", "Fill the whole screen. F11 toggles it anywhere.",
		GameState.settings.get("fullscreen", false),
		func(on: bool):
			GameState.set_fullscreen(on)
	))

	# QA only — hidden entirely once GameState.ALLOW_TESTING_MODE is switched
	# off for release.
	if GameState.ALLOW_TESTING_MODE:
		v.add_child(_row(
			"Testing Mode",
			"Any valid match instantly clears the chapter goal, and grants 99 stars — for QA, not for actually playing.",
			GameState.settings.test_mode,
			func(on: bool):
				GameState.set_test_mode(on)
				main.refresh_topbar()
				# The star count changed — e.g. the roster's gift buttons
				# underneath need re-checking against it.
				main.mark_settings_dirty()
		))

	v.add_child(UITheme.spacer(6))

	# How to Play, and the log folder for bug reports (Godot writes
	# user://logs/godot.log on desktop; the newest few are kept).
	var extra_row := HBoxContainer.new()
	extra_row.add_theme_constant_override("separation", 10)
	v.add_child(extra_row)
	var howto := UITheme.make_ghost_button("How to Play")
	howto.pressed.connect(func():
		SFX.nav()
		HowToPlay.show_page(main)
	)
	extra_row.add_child(howto)
	# Story scenes have no back button of their own (round 25).
	if main.story_scene:
		var leave := UITheme.make_ghost_button("Leave to Roster")
		leave.tooltip_text = "Stop here. This scene plays again next time you visit her."
		leave.pressed.connect(func():
			SFX.nav()
			Voice.stop()
			main.close_settings()
			main.show_roster()
		)
		extra_row.add_child(leave)
	if not OS.has_feature("web"):
		var logs := UITheme.make_ghost_button("Open log folder")
		logs.tooltip_text = "For bug reports: send the newest godot.log from this folder."
		logs.pressed.connect(func():
			SFX.nav()
			var dir := ProjectSettings.globalize_path("user://logs")
			DirAccess.make_dir_recursive_absolute(dir)
			OS.shell_open(dir)
		)
		extra_row.add_child(logs)

	var reset_btn := Button.new()
	reset_btn.text = "Reset Progress"
	reset_btn.add_theme_color_override("font_color", Color("#E0576F"))
	var reset_style := StyleBoxFlat.new()
	reset_style.bg_color = Color(0, 0, 0, 0)
	reset_style.border_color = Color("#E0576F")
	reset_style.set_border_width_all(1)
	reset_style.set_corner_radius_all(14)
	reset_style.content_margin_left = 18
	reset_style.content_margin_right = 18
	reset_style.content_margin_top = 10
	reset_style.content_margin_bottom = 10
	reset_btn.add_theme_stylebox_override("normal", reset_style)
	reset_btn.add_theme_stylebox_override("hover", reset_style)
	reset_btn.add_theme_stylebox_override("focus", UITheme.focus_ring(14))
	reset_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# One click used to wipe everything with no warning.
	reset_btn.pressed.connect(func():
		main.confirm("Reset all progress?",
			"This erases every girl's story progress, your stars, items, gifts and the whole Gallery. Your settings and achievements are kept. This can't be undone.",
			"Reset everything", func():
				GameState.reset_progress()
				main.refresh_topbar()
				main.roster_selected_id = ""
				main.current_char_id = ""
				# Whatever was open underneath (a chapter, her roster card...) is
				# now showing progress that no longer exists — swap it for the
				# main menu (tearing it down properly) and stay here in Settings.
				main.show_menu()
		)
	)
	v.add_child(reset_btn)


## A row of options to pick one from (segmented buttons).
static func _choice_row(title: String, desc: String, options: Array, current: String, on_pick: Callable) -> PanelContainer:
	var p := UITheme.panel(UITheme.SURFACE_2, 16, UITheme.LINE)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var text_v := VBoxContainer.new()
	text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_v.add_child(UITheme.body(title, 14))
	var d := UITheme.soft_label(desc, 11)
	d.custom_minimum_size = Vector2(260, 0)
	text_v.add_child(d)
	h.add_child(text_v)
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 4)
	seg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(seg)
	var group := ButtonGroup.new()
	var on_style := UITheme.button_style(UITheme.ACCENT, 999)
	on_style.content_margin_left = 12
	on_style.content_margin_right = 12
	on_style.content_margin_top = 6
	on_style.content_margin_bottom = 6
	var off_style := on_style.duplicate() as StyleBoxFlat
	off_style.bg_color = UITheme.SURFACE
	off_style.border_color = UITheme.LINE
	off_style.set_border_width_all(1)
	var first: Button = null
	for o in options:
		var b := Button.new()
		b.text = String(o[1])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = String(o[0]) == current
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_stylebox_override("normal", off_style)
		b.add_theme_stylebox_override("hover", off_style)
		b.add_theme_stylebox_override("pressed", on_style)
		b.add_theme_stylebox_override("hover_pressed", on_style)
		b.add_theme_stylebox_override("focus", UITheme.focus_ring(999))
		b.add_theme_color_override("font_color", UITheme.INK)
		b.add_theme_color_override("font_hover_color", UITheme.INK)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var key := String(o[0])
		b.pressed.connect(func():
			SFX.nav()
			on_pick.call(key)
		)
		seg.add_child(b)
		if first == null:
			first = b
	p.set_meta("control", first)
	return p


static func _slider_row(title: String, desc: String, initial: float, on_change: Callable) -> PanelContainer:
	var p := UITheme.panel(UITheme.SURFACE_2, 16, UITheme.LINE)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)

	var text_v := VBoxContainer.new()
	text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_v.add_child(UITheme.body(title, 14))
	var d := UITheme.soft_label(desc, 11)
	d.custom_minimum_size = Vector2(360, 0)
	text_v.add_child(d)
	h.add_child(text_v)

	var pct := UITheme.soft_label("", 12)
	pct.autowrap_mode = TextServer.AUTOWRAP_OFF
	pct.custom_minimum_size = Vector2(40, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pct.text = "%d%%" % int(round(initial * 100.0))
	h.add_child(pct)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(200, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Themed track: a soft rail with the filled part in the accent color.
	var rail := StyleBoxFlat.new()
	rail.bg_color = UITheme.LINE.darkened(0.08)
	rail.set_corner_radius_all(999)
	rail.content_margin_top = 3
	rail.content_margin_bottom = 3
	var fill := rail.duplicate() as StyleBoxFlat
	fill.bg_color = UITheme.ACCENT
	var fill_hover := rail.duplicate() as StyleBoxFlat
	fill_hover.bg_color = UITheme.ACCENT.lightened(0.1)
	slider.add_theme_stylebox_override("slider", rail)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hover)
	slider.value_changed.connect(func(val: float):
		pct.text = "%d%%" % int(round(val * 100.0))
		on_change.call(val)
	)
	slider.add_theme_stylebox_override("focus", UITheme.focus_ring(8))
	h.add_child(slider)
	p.set_meta("control", slider)
	return p


static func _row(title: String, desc: String, initial: bool, on_toggle: Callable) -> PanelContainer:
	var p := UITheme.panel(UITheme.SURFACE_2, 16, UITheme.LINE)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)

	var text_v := VBoxContainer.new()
	text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_v.add_child(UITheme.body(title, 14))
	var d := UITheme.soft_label(desc, 11)
	d.custom_minimum_size = Vector2(360, 0)
	text_v.add_child(d)
	h.add_child(text_v)

	var toggle := CheckButton.new()
	toggle.button_pressed = initial
	toggle.toggled.connect(on_toggle)
	toggle.add_theme_stylebox_override("focus", UITheme.focus_ring(10))
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	h.add_child(toggle)
	p.set_meta("control", toggle)

	return p

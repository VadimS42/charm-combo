## SettingsScreen.gd — sound / reduce motion / theme / test mode / reset,
## equivalent to #screen-settings in the HTML prototype. Toggling Testing
## Mode also grants 99 stars, same as the HTML version's toggleTest handler.
class_name SettingsScreen
extends RefCounted

static func build(main: Node, host: Control) -> void:
	host.add_child(UITheme.make_screen_backdrop(UITheme.SPECIAL_PINK, UITheme.ACCENT_2))

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)
	host.add_child(v)

	var back := UITheme.make_ghost_button("←  Back")
	back.pressed.connect(func():
		SFX.nav()
		main.show_menu()
	)
	v.add_child(back)

	v.add_child(UITheme.heading("Settings", 22))

	v.add_child(_row(
		"Sound Effects", "Chimes for matches, combos, and menus.",
		GameState.settings.sound,
		func(on: bool):
			GameState.settings.sound = on
			GameState.save_state()
	))

	v.add_child(_row(
		"Reduce Motion", "Shorter animations, calmer feedback.",
		GameState.settings.reduce_motion,
		func(on: bool):
			GameState.settings.reduce_motion = on
			GameState.save_state()
	))

	v.add_child(_row(
		"Testing Mode",
		"Any valid match instantly clears the chapter goal, and grants 99 stars — for QA, not for actually playing.",
		GameState.settings.test_mode,
		func(on: bool):
			GameState.set_test_mode(on)
			main.refresh_topbar()
	))

	v.add_child(UITheme.spacer(6))

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
	reset_btn.pressed.connect(func():
		GameState.reset_progress()
		main.refresh_topbar()
		main.show_settings()
	)
	v.add_child(reset_btn)


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
	h.add_child(toggle)

	return p

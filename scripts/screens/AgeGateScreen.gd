## AgeGateScreen.gd — the one-time "this game is for adults" notice shown on
## first launch (round 21, when Charm Combo became 18+). Confirming sets
## GameState.settings.age_confirmed and saves, so it never shows again on that
## computer; Leave quits (in the browser build, where a game can't close its
## own tab, it says to close the tab instead).
class_name AgeGateScreen
extends RefCounted


static func build(main: Node, host: Control) -> void:
	host.add_child(UITheme.make_screen_backdrop(UITheme.ACCENT, UITheme.VIOLET))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.window_style())
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)

	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 36)
	pad.add_theme_constant_override("margin_top", 30)
	pad.add_theme_constant_override("margin_bottom", 28)
	card.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	pad.add_child(col)

	var badge := UITheme.accent_label("18+", UITheme.BERRY, 30)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(badge)

	var title := UITheme.heading("Charm Combo is for adults", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var text := UITheme.body(
		"It has sexual content, including intimate scenes, and suggestive art. All characters are adults.\n\nPlease only continue if you're 18 or older, or the age of majority where you live.",
		15, UITheme.INK)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size = Vector2(480, 0)
	col.add_child(text)

	col.add_child(UITheme.spacer(4))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)

	var web := OS.has_feature("web")
	var leave := UITheme.make_ghost_button("Leave")
	var note := UITheme.soft_label("You can close this tab now.", 12)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.visible = false
	leave.pressed.connect(func():
		SFX.nav()
		if web:
			note.visible = true
		else:
			GameState.quit_game()
	)
	row.add_child(leave)

	var ok := UITheme.make_primary_button("I'm 18 or older")
	ok.pressed.connect(func():
		SFX.nav()
		GameState.settings["age_confirmed"] = true
		GameState.save_state()
		main.show_start()
	)
	row.add_child(ok)
	col.add_child(note)

	main.nav_setup(ok, Callable(), {}, [["move", "Move"], ["accept", "Select"]])


## Shown once, right after the age notice (round 28): the voices are amateur
## recordings, and here's the switch. Either button records that it was seen.
static func build_voice_notice(main: Node, host: Control) -> void:
	host.add_child(UITheme.make_screen_backdrop(UITheme.ACCENT, UITheme.VIOLET))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.window_style())
	card.custom_minimum_size = Vector2(560, 0)
	center.add_child(card)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 36)
	pad.add_theme_constant_override("margin_top", 30)
	pad.add_theme_constant_override("margin_bottom", 28)
	card.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	pad.add_child(col)
	var title := UITheme.heading("About the voices", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var text := UITheme.body(
		"The girls are voiced by amateur voice actresses, recorded at home. We love how they turned out, but they aren't studio recordings, and not every line is voiced yet.\n\nIf you'd rather read in your own head, turn the voices off. You can change this any time in Settings.",
		15, UITheme.INK)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size = Vector2(480, 0)
	col.add_child(text)
	col.add_child(UITheme.spacer(4))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var done := func(voice_on: bool):
		SFX.nav()
		GameState.settings["voice"] = voice_on
		GameState.settings["voice_notice_seen"] = true
		GameState.save_state()
		main.show_menu()
	var off := UITheme.make_ghost_button("Turn voices off")
	off.pressed.connect(func(): done.call(false))
	row.add_child(off)
	var on := UITheme.make_primary_button("Keep voices on")
	on.pressed.connect(func(): done.call(true))
	row.add_child(on)
	main.nav_setup(on, Callable(), {}, [["move", "Move"], ["accept", "Select"]])


## First launch, before anything else (round 30): pick a language. Each
## button is written in its own language. Settings can change it later.
static func build_language_picker(main: Node, host: Control) -> void:
	host.add_child(UITheme.make_screen_backdrop(UITheme.ACCENT, UITheme.VIOLET))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.window_style())
	card.custom_minimum_size = Vector2(420, 0)
	center.add_child(card)
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 36)
	pad.add_theme_constant_override("margin_top", 30)
	pad.add_theme_constant_override("margin_bottom", 30)
	card.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	pad.add_child(col)
	# The title in all three, since nothing is chosen yet.
	var title := UITheme.heading("Language · 语言 · Язык", 22)
	title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var first: Button = null
	for pair in GameState.LANGUAGES:
		var code := String(pair[0])
		var b := UITheme.make_primary_button(String(pair[1]))
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(320, 48)
		b.pressed.connect(func():
			SFX.nav()
			GameState.set_language(code)
			main.after_language()
		)
		col.add_child(b)
		if first == null:
			first = b
	main.nav_setup(first, Callable(), {}, [["move", "Move"], ["accept", "Select"]])

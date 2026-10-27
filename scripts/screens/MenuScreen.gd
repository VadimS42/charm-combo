## MenuScreen.gd — the main menu (Play / Store / Gallery), equivalent to
## #screen-menu in the HTML prototype.
class_name MenuScreen
extends RefCounted

static func build(main: Node, host: Control) -> void:
	# Real hero art the moment res://art/menu_illustration.png exists (see
	# ArtAssets.gd); until then (round 28) a slideshow of the girls' places,
	# each slowly zooming and drifting, crossfading to the next, under the
	# same light scrim the illustration gets.
	var illo := ArtAssets.menu_illustration()
	if illo:
		var img := TextureRect.new()
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		img.texture = illo
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		host.add_child(img)
		var scrim := ColorRect.new()
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		scrim.color = Color(UITheme.BG.r, UITheme.BG.g, UITheme.BG.b, 0.55)
		host.add_child(scrim)
	else:
		var shows := RosterBackdrop.new()
		host.add_child(shows)
		shows.cycle(CharacterData.all())
		var scrim := ColorRect.new()
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		scrim.color = Color(UITheme.BG.r, UITheme.BG.g, UITheme.BG.b, 0.55)
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(scrim)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	host.add_child(v)

	# The game's logo (art/ui/logo.png) when it exists, else the text title.
	var logo_tex := ArtAssets.ui_icon("logo")
	if logo_tex:
		var logo := TextureRect.new()
		logo.texture = logo_tex
		logo.custom_minimum_size = Vector2(480, 150)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(logo)
	else:
		var title := UITheme.heading("Charm Combo", 44)
		title.add_theme_color_override("font_color", UITheme.BERRY)
		title.add_theme_color_override("font_shadow_color", Color(UITheme.PLUM.r, UITheme.PLUM.g, UITheme.PLUM.b, 0.22))
		title.add_theme_constant_override("shadow_offset_y", 3)
		title.add_theme_constant_override("shadow_offset_x", 0)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(title)

	var tag := UITheme.body(
		"A match-3 romance for adults, set in Millbrook, a twilight town where fantastical folk make their home. Meet four women in the worst way possible, help them with what they need, and see where the night goes.",
		14, UITheme.INK_SOFT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(460, 0)
	var tag_center := CenterContainer.new()
	tag_center.add_child(tag)
	v.add_child(tag_center)

	v.add_child(UITheme.spacer(6))

	var play_btn := UITheme.make_primary_button("Play")
	play_btn.custom_minimum_size = Vector2(280, 52)
	play_btn.pressed.connect(func():
		SFX.nav()
		main.menu_focus = "play"
		main.show_roster()
	)
	var play_center := CenterContainer.new()
	play_center.add_child(play_btn)
	v.add_child(play_center)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)

	var store_btn := UITheme.make_ghost_button("Store")
	store_btn.pressed.connect(func():
		SFX.nav()
		main.menu_focus = "store"
		main.show_store()
	)
	row.add_child(store_btn)

	var gallery_btn := UITheme.make_ghost_button("Gallery")
	gallery_btn.pressed.connect(func():
		SFX.nav()
		main.menu_focus = "gallery"
		main.show_gallery()
	)
	row.add_child(gallery_btn)

	var ach_btn := UITheme.make_ghost_button("Achievements")
	ach_btn.pressed.connect(func():
		SFX.nav()
		main.menu_focus = "achievements"
		main.show_achievements()
	)
	row.add_child(ach_btn)

	var howto_btn := UITheme.make_ghost_button("How to Play")
	howto_btn.pressed.connect(func():
		SFX.nav()
		main.menu_focus = "howto"
		HowToPlay.show_page(main)
	)
	row.add_child(howto_btn)

	var credits_btn := UITheme.make_ghost_button("Credits")
	credits_btn.pressed.connect(func():
		SFX.nav()
		main.menu_focus = "credits"
		main.show_credits()
	)
	row.add_child(credits_btn)

	# Desktop builds need a way out besides the window's close button (and
	# fullscreen has none). Not in the browser build, where the tab is the way
	# out and "quitting" would just freeze the page.
	if not OS.has_feature("web"):
		var quit_btn := UITheme.make_ghost_button("Quit")
		quit_btn.pressed.connect(func():
			SFX.nav()
			GameState.quit_game()
		)
		row.add_child(quit_btn)

	v.add_child(UITheme.spacer(10))
	var foot_text := "18+ · original characters · all characters are adults."
	if CharacterData.using_override():
		foot_text += "\nTest build: using your edited characters.json from the game's folder."
	var footnote := UITheme.soft_label(foot_text, 11)
	footnote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# NOTE: without an explicit width, a word-wrapped Label reports a
	# near-zero minimum width (just its longest word) and gets crushed down
	# to one word per line by the CenterContainer around it — the same class
	# of bug fixed earlier on the roster cards. `tag` above already has this;
	# footnote was missing it, which is what made the menu look "clumped".
	footnote.custom_minimum_size = Vector2(480, 0)
	var foot_center := CenterContainer.new()
	foot_center.add_child(footnote)
	v.add_child(foot_center)

	# Keys / a pad land on the button you left the menu through (Play at first).
	var by_name := {"play": play_btn, "store": store_btn, "gallery": gallery_btn,
		"achievements": ach_btn, "howto": howto_btn, "credits": credits_btn}
	main.nav_setup(by_name.get(main.menu_focus, play_btn))

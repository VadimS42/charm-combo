## MenuScreen.gd — the main menu (Play / Store / Gallery), equivalent to
## #screen-menu in the HTML prototype.
class_name MenuScreen
extends RefCounted

static func build(main: Node, host: Control) -> void:
	# Real hero art the moment res://art/menu_illustration.png exists (see
	# ArtAssets.gd); until then, the same soft accent-blob placeholder as
	# every other screen.
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
		host.add_child(UITheme.make_screen_backdrop())

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	host.add_child(v)

	var title := UITheme.heading("Charm Combo", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var tag := UITheme.body(
		"A cozy match-3 story set in Duskhaven, a twilight town where fantastical folk make their home. Clear the board, win over its guildmasters, and see where the friendship goes.",
		14, UITheme.INK_SOFT)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.custom_minimum_size = Vector2(460, 0)
	var tag_center := CenterContainer.new()
	tag_center.add_child(tag)
	v.add_child(tag_center)

	v.add_child(UITheme.spacer(6))

	var play_btn := UITheme.make_primary_button("▶  Play")
	play_btn.custom_minimum_size = Vector2(280, 52)
	play_btn.pressed.connect(func():
		SFX.nav()
		main.show_roster()
	)
	var play_center := CenterContainer.new()
	play_center.add_child(play_btn)
	v.add_child(play_center)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)

	var store_btn := UITheme.make_ghost_button("🛍  Store")
	store_btn.pressed.connect(func():
		SFX.nav()
		main.show_store()
	)
	row.add_child(store_btn)

	var gallery_btn := UITheme.make_ghost_button("🖼  Gallery")
	gallery_btn.pressed.connect(func():
		SFX.nav()
		main.show_gallery()
	)
	row.add_child(gallery_btn)

	v.add_child(UITheme.spacer(10))
	var footnote := UITheme.soft_label(
		"4 guildmasters of Duskhaven · original characters · no explicit content — just puzzles & wholesome fireside banter.", 11)
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

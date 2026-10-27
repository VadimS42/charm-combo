## RosterScreen.gd — the character-select grid (the "Duskhaven Circle" of
## guildmasters), equivalent to #screen-select in the HTML prototype. Each
## card shows her favorite and least-favorite gem (task: "girls page should
## say which her favorites are"), chapter progress dots, and — once
## unlocked — her ending title.
class_name RosterScreen
extends RefCounted

static func build(main: Node, host: Control) -> void:
	host.add_child(UITheme.make_screen_backdrop())

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)
	host.add_child(v)

	var top_row := HBoxContainer.new()
	var back := UITheme.make_ghost_button("←  Menu")
	back.pressed.connect(func():
		SFX.nav()
		main.show_menu()
	)
	top_row.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var gallery_btn := UITheme.make_ghost_button("Gallery")
	gallery_btn.pressed.connect(func():
		SFX.nav()
		main.show_gallery()
	)
	top_row.add_child(gallery_btn)
	v.add_child(top_row)

	v.add_child(UITheme.heading("Duskhaven Circle", 22))

	# Scrollable so the roster keeps working as more girls get added (or on
	# a shorter window) instead of clipping cards off the bottom of the
	# screen with no way to reach them.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	# Centered inside the scroll viewport — a bare GridContainer dropped
	# straight into a ScrollContainer sits at its natural (left-aligned)
	# size instead of spreading across the available width, which is what
	# made the whole roster hug the left edge with empty space on the right.
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	center.add_child(grid)

	for ch in CharacterData.all():
		grid.add_child(_card(main, ch))


static func _card(main: Node, ch: Dictionary) -> PanelContainer:
	var accent := Color(ch.c)
	var card := UITheme.panel(UITheme.SURFACE_2, 18, UITheme.LINE)
	card.custom_minimum_size = Vector2(340, 0)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	# Portrait: real art the moment res://art/characters/<id>/neutral.png
	# exists (see ArtAssets.gd); until then, the same colored-circle-with-
	# her-initial placeholder as before, clearly tagged so it reads as an
	# honest stand-in rather than a missing asset.
	var portrait_wrap := PanelContainer.new()
	portrait_wrap.custom_minimum_size = Vector2(0, 128)
	var portrait_style := UITheme.panel_style(accent.lightened(0.72), 16, accent.lightened(0.45))
	portrait_wrap.add_theme_stylebox_override("panel", portrait_style)
	var portrait_stack := Control.new()
	portrait_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_wrap.add_child(portrait_stack)

	var art_tex := ArtAssets.character_portrait(String(ch.id), "neutral")
	if art_tex:
		var art := TextureRect.new()
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.texture = art_tex
		art.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_stack.add_child(art)
	else:
		var glow := UITheme._blob(accent, Vector2(140, 140), 0.28)
		glow.set_anchors_preset(Control.PRESET_CENTER)
		glow.position = Vector2(-70, -78)
		portrait_stack.add_child(glow)

		var portrait_center := CenterContainer.new()
		portrait_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		var initial := Label.new()
		initial.text = ch.name.substr(0, 1)
		initial.add_theme_font_size_override("font_size", 48)
		initial.add_theme_color_override("font_color", accent)
		portrait_center.add_child(initial)
		portrait_stack.add_child(portrait_center)

		var tag_wrap := UITheme.placeholder_tag()
		tag_wrap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		portrait_stack.add_child(tag_wrap)

	v.add_child(portrait_wrap)

	var name_lbl := UITheme.body(ch.name, 16)
	v.add_child(name_lbl)
	var role_lbl := UITheme.accent_label(String(ch.role).to_upper(), accent, 11)
	v.add_child(role_lbl)

	# Stacked vertically (not side-by-side in an HBox) — a Label with
	# word-wrap enabled reports a tiny minimum width (just enough for its
	# longest single word), so two of them packed into an HBoxContainer with
	# no expand flag were overlapping instead of sitting side by side. A
	# VBoxContainer sidesteps the whole problem: each line gets the full
	# card width to itself.
	var prefs := VBoxContainer.new()
	prefs.add_theme_constant_override("separation", 2)
	var love_lbl := UITheme.soft_label("💚 Loves " + CharacterData.gem_label(ch.fav), 10)
	love_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	prefs.add_child(love_lbl)
	var dislike_lbl := UITheme.soft_label("🚫 Dislikes " + CharacterData.gem_label(ch.least), 10)
	dislike_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	prefs.add_child(dislike_lbl)
	v.add_child(prefs)

	var progress: Dictionary = GameState.progress_for(ch.id)
	var levels: Array = ch.story.levels
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 5)
	for i in range(levels.size()):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(18, 6)
		var done: bool = i < int(progress.get("level_index", 0)) or not progress.endings_unlocked.is_empty()
		dot.color = accent if done else UITheme.LINE
		dots.add_child(dot)
	v.add_child(dots)

	var status_text := "Not started"
	if not progress.endings_unlocked.is_empty():
		var key: String = progress.endings_unlocked[0]
		status_text = "Ending: " + String(ch.story.endings[key].title)
	elif int(progress.get("level_index", 0)) > 0:
		status_text = "Chapter %d / %d" % [int(progress.level_index) + 1, levels.size()]
	var status_lbl := UITheme.soft_label(status_text, 11)
	if not progress.endings_unlocked.is_empty():
		status_lbl.add_theme_color_override("font_color", accent)
	v.add_child(status_lbl)

	var open_btn := UITheme.make_primary_button("Open" if progress.endings_unlocked.is_empty() else "Revisit")
	open_btn.pressed.connect(func():
		SFX.nav()
		StoryFlow.enter_character(main, ch.id)
	)
	v.add_child(open_btn)

	var gifts_given: Array = progress.get("gifts_given", [])
	if not gifts_given.has(ch.gift.id):
		var gift_btn := UITheme.make_card_button("🎁  Give " + String(ch.gift.name) + "  ·  " + str(ch.gift.price) + "⭐", accent)
		gift_btn.disabled = GameState.stars < int(ch.gift.price)
		gift_btn.pressed.connect(func():
			if GameState.stars < int(ch.gift.price):
				return
			GameState.stars -= int(ch.gift.price)
			gifts_given.append(ch.gift.id)
			progress["gifts_given"] = gifts_given
			GameState.save_state()
			SFX.purchase()
			main.refresh_topbar()
			main.show_vn_scene(ch.giftLine, null, func():
				main.show_roster()
			)
		)
		v.add_child(gift_btn)

	return card

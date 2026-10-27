## GalleryScreen.gd — lists unlocked endings; clicking one reopens its CG,
## equivalent to #screen-gallery in the HTML prototype.
class_name GalleryScreen
extends RefCounted

static func build(main: Node, host: Control) -> void:
	host.add_child(UITheme.make_screen_backdrop(UITheme.SPECIAL_PINK, UITheme.ACCENT))

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)
	host.add_child(v)

	var back := UITheme.make_ghost_button("←  Back")
	back.pressed.connect(func():
		SFX.nav()
		main.show_roster()
	)
	v.add_child(back)

	v.add_child(UITheme.heading("Ending Gallery", 22))

	var any_found := false
	for ch in CharacterData.all():
		var progress: Dictionary = GameState.progress_for(ch.id)
		if progress.endings_unlocked.is_empty():
			continue
		any_found = true
		var key: String = progress.endings_unlocked[0]
		var ending: Dictionary = ch.story.endings[key]
		var accent := Color(String(ch.c))

		var row := UITheme.make_card_button("", accent)
		row.custom_minimum_size = Vector2(0, 64)
		var row_h := HBoxContainer.new()
		row_h.add_theme_constant_override("separation", 12)
		row_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := Label.new()
		icon.text = "💞"
		icon.add_theme_font_size_override("font_size", 28)
		row_h.add_child(icon)
		var text_v := VBoxContainer.new()
		text_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UITheme.body(String(ch.name) + " — \"" + String(ending.title) + "\"", 14)
		t.autowrap_mode = TextServer.AUTOWRAP_OFF
		t.clip_text = true
		text_v.add_child(t)
		var d := UITheme.soft_label(String(ending.text).left(90) + "...", 11)
		d.custom_minimum_size = Vector2(300, 0)
		text_v.add_child(d)
		row_h.add_child(text_v)
		row.add_child(row_h)

		row.pressed.connect(func():
			SFX.nav()
			main.show_ending_cg(ch.id, ending, func(): main.show_gallery())
		)
		v.add_child(row)

	if not any_found:
		v.add_child(UITheme.soft_label("No endings unlocked yet — finish a character's story to add her here.", 13))

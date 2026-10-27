## AchievementsScreen.gd — every achievement, unlocked or not (round 16).
## The same list Steam shows (Achievements.gd), inside the game, so builds
## without Steam (itch.io) have them too. Icons come from
## art/achievements/<id in lowercase>.png when they exist; locked ones are
## shown dimmed and grey.
class_name AchievementsScreen
extends RefCounted

const ROW_W := 560.0


static func build(main: Node, host: Control) -> void:
	host.add_child(UITheme.make_screen_backdrop(UITheme.ACCENT_2, UITheme.SPECIAL_PINK))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	host.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	var back := UITheme.make_ghost_button("←  Back")
	var go_back := func():
		SFX.nav()
		main.show_menu()
	back.pressed.connect(go_back)
	top_row.add_child(back)
	var title := UITheme.heading("Achievements", 22)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var count := UITheme.body("%d / %d unlocked" % [Achievements.count_unlocked(), Achievements.LIST.size()], 13, UITheme.INK_SOFT)
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(count)
	outer.add_child(top_row)

	if Platform.steam_active():
		outer.add_child(UITheme.soft_label("These unlock on Steam too.", 12))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.make_scroll_navigable(scroll)
	outer.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	center.add_child(grid)
	for a in Achievements.LIST:
		grid.add_child(_row(a))

	main.nav_setup(scroll, go_back, {}, [["move", "Scroll"], ["back", "Back"], ["pause", "Settings"]])


static func _row(a: Dictionary) -> Control:
	var got := Achievements.is_unlocked(String(a.id))
	var p := UITheme.panel(UITheme.SURFACE if got else UITheme.SURFACE_2, 16,
		UITheme.ACCENT_2 if got else UITheme.LINE)
	p.custom_minimum_size = Vector2(ROW_W, 0)
	p.tooltip_text = String(a.name) + " — " + String(a.desc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)

	var tex := Achievements.icon(String(a.id))
	if tex:
		var t := TextureRect.new()
		t.texture = tex
		t.custom_minimum_size = Vector2(56, 56)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not got:
			t.modulate = Color(0.45, 0.42, 0.48, 0.6)
		h.add_child(t)
	else:
		# Stand-in medal until the icon art exists.
		var medal := Panel.new()
		medal.custom_minimum_size = Vector2(56, 56)
		var ms := StyleBoxFlat.new()
		ms.bg_color = UITheme.ACCENT_2 if got else UITheme.LINE
		ms.set_corner_radius_all(28)
		medal.add_theme_stylebox_override("panel", ms)
		var glyph := Label.new()
		glyph.text = "🏆" if got else "?"
		glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.add_theme_font_size_override("font_size", 24)
		glyph.add_theme_color_override("font_color", Color.WHITE if got else UITheme.INK_SOFT)
		medal.add_child(glyph)
		h.add_child(medal)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var name_lbl := UITheme.body(String(a.name), 15, UITheme.INK if got else UITheme.INK_SOFT)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(name_lbl)
	var desc := UITheme.soft_label(String(a.desc), 12)
	desc.custom_minimum_size = Vector2(ROW_W - 120.0, 0)
	v.add_child(desc)
	if got:
		var chip := UITheme.accent_label("UNLOCKED", UITheme.ACCENT_2.darkened(0.25), 10)
		chip.add_theme_font_override("font", UITheme.tracked_font(2))
		v.add_child(chip)
	return p

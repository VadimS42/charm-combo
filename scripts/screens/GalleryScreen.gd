## GalleryScreen.gd — every ending the player has found, grouped by girl
## (equivalent to #screen-gallery in the HTML prototype). Clicking a found one
## reopens its final CG; slots not found yet show as locked, with a hint of
## which route they're on, so there's something to go back for.
##
## Round 15: reads GameState.gallery — every finale reached across ALL
## playthroughs — instead of each girl's current progress, so replaying her
## story (roster "Replay") and picking the other reply never costs you the
## finale you already found. Back returns to whichever screen opened it (menu
## or roster, see Main.leave_gallery()).
class_name GalleryScreen
extends RefCounted

## Thumbnail picture size (16:9, like the CGs themselves).
const THUMB := Vector2(252, 142)
const CARD_PAD := 10.0

const ROUTE_NAMES := {"warmth": "Her ending", "spark": "Spark route", "balanced": "Balanced route", "night": "Night scene"}


static func build(main: Node, host: Control) -> void:
	host.add_child(UITheme.make_screen_backdrop(UITheme.SPECIAL_PINK, UITheme.ACCENT))

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

	var slots := all_slots()
	var found := 0
	for s in slots:
		if GameState.gallery.has(s.entry):
			found += 1

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	var back := UITheme.make_ghost_button("←  Back")
	back.pressed.connect(func():
		SFX.nav()
		main.leave_gallery()
	)
	top_row.add_child(back)
	var title := UITheme.heading("Ending Gallery", 22)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var counter := UITheme.body(UITheme.t("%d / %d endings found") % [found, slots.size()], 13, UITheme.INK_SOFT)
	counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	counter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(counter)
	outer.add_child(top_row)

	if found == 0:
		var hint := UITheme.soft_label(
			"Nothing here yet — finish a girl's story to add her ending.", 13)
		hint.custom_minimum_size = Vector2(640, 0)
		outer.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Keeps the focused card in view when moving with keys or a pad.
	scroll.follow_focus = true
	outer.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 20)
	scroll.add_child(col)

	for ch in CharacterData.all():
		var id := String(ch.id)
		var mine: Array = slots.filter(func(s): return s.char_id == id)
		if not mine.is_empty():
			col.add_child(_section(main, ch, mine))

	# Keys / a pad start on the first ending found (or Back if none yet).
	var first_card := _first_button(col)
	main.nav_setup(first_card if first_card != null else back, func():
		SFX.nav()
		main.leave_gallery()
	)


static func _first_button(n: Node) -> Button:
	if n is Button:
		return n
	for c in n.get_children():
		var b := _first_button(c)
		if b != null:
			return b
	return null


## Every ending that can be found, in story order: one per finale for an
## ending with an epilogue choice, else one for the ending itself. Each is
## {char_id, ending, finale, entry} — `entry` in GameState.gallery's
## "char|ending|finale" form.
static func all_slots() -> Array:
	var out: Array = []
	for ch in CharacterData.all():
		var id := String(ch.id)
		var endings: Dictionary = ch.story.endings
		for ek in endings.keys():
			var ep = endings[ek].get("epilogue")
			var finales: Dictionary = {}
			if typeof(ep) == TYPE_DICTIONARY and typeof(ep.get("finales")) == TYPE_DICTIONARY:
				finales = ep.finales
			if finales.is_empty():
				out.append({"char_id": id, "ending": String(ek), "finale": "", "entry": "%s|%s|" % [id, ek]})
			else:
				for fk in finales.keys():
					out.append({"char_id": id, "ending": String(ek), "finale": String(fk),
						"entry": "%s|%s|%s" % [id, ek, fk]})
	return out


static func _section(main: Node, ch: Dictionary, slots: Array) -> Control:
	var accent := Color(String(ch.get("c", "#FF6F91")))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)

	var found := 0
	for s in slots:
		if GameState.gallery.has(s.entry):
			found += 1
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var name_lbl := UITheme.heading(String(ch.name), 18)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(name_lbl)
	var role_lbl := UITheme.accent_label(UITheme.t(String(ch.get("role", ""))).to_upper(), accent.darkened(0.2), 10)
	role_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	role_lbl.add_theme_font_override("font", UITheme.tracked_font(1))
	role_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(role_lbl)
	var count_lbl := UITheme.soft_label("%d / %d" % [found, slots.size()], 11)
	count_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	count_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(count_lbl)
	v.add_child(head)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 14)
	for s in slots:
		if GameState.gallery.has(s.entry):
			flow.add_child(_found_card(main, ch, s, accent))
		else:
			flow.add_child(_locked_card(s, accent))
	# Her night scene, replayable once seen (round 25).
	if typeof(ch.story.get("night")) == TYPE_DICTIONARY:
		if GameState.replays.has("%s|night" % ch.id):
			flow.add_child(_night_card(main, ch, accent))
		else:
			flow.add_child(_locked_card({"ending": "night"}, accent))
	v.add_child(flow)
	return v


static func _night_card(main: Node, ch: Dictionary, accent: Color) -> Button:
	var char_id := String(ch.id)
	var b := UITheme.make_card_button("", accent)
	b.custom_minimum_size = _card_size()
	b.tooltip_text = "Replay her night scene."
	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = CARD_PAD
	inner.offset_top = CARD_PAD
	inner.offset_right = -CARD_PAD
	inner.offset_bottom = -CARD_PAD
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)
	inner.add_child(EndingCGScreen.art_frame(char_id, String(ch.story.night.get("cg", "night")), THUMB, "", "🌙"))
	var t := UITheme.body("Her night scene", 13)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(t)
	var sub := UITheme.accent_label("Replay", accent.darkened(0.2), 10)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(sub)
	b.pressed.connect(func():
		SFX.nav()
		StoryFlow.replay_night(main, char_id)
	)
	return b


static func _card_size() -> Vector2:
	return Vector2(THUMB.x + CARD_PAD * 2.0, THUMB.y + CARD_PAD * 2.0 + 44.0)


static func _found_card(main: Node, ch: Dictionary, slot: Dictionary, accent: Color) -> Button:
	var char_id := String(ch.id)
	var ending := StoryFlow.ending_for_entry(char_id, slot.ending, slot.finale)
	var b := UITheme.make_card_button("", accent)
	b.custom_minimum_size = _card_size()
	b.tooltip_text = UITheme.t(String(ending.get("title", ""))) + " — " + UITheme.t("Click to view.")

	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = CARD_PAD
	inner.offset_top = CARD_PAD
	inner.offset_right = -CARD_PAD
	inner.offset_bottom = -CARD_PAD
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(inner)

	inner.add_child(EndingCGScreen.art_frame(char_id, String(ending.get("cg", "")), THUMB, "", "💞"))
	var t := UITheme.body(String(ending.get("title", "")), 13)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.custom_minimum_size = Vector2(THUMB.x, 0)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(t)
	var sub := UITheme.accent_label(String(ROUTE_NAMES.get(slot.ending, "")), accent.darkened(0.2), 10)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(sub)

	b.pressed.connect(func():
		SFX.nav()
		main.show_ending_cg(char_id, ending, func(): main.show_gallery())
	)
	return b


static func _locked_card(slot: Dictionary, accent: Color) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = _card_size()
	var ps := UITheme.panel_style(Color(UITheme.SURFACE_2, 0.6), 18, UITheme.LINE)
	p.add_theme_stylebox_override("panel", ps)
	p.tooltip_text = "Not found yet: finish her story to unlock it."

	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = CARD_PAD
	inner.offset_top = CARD_PAD
	inner.offset_right = -CARD_PAD
	inner.offset_bottom = -CARD_PAD
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inner)

	var pic := Panel.new()
	pic.custom_minimum_size = THUMB
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic_style := StyleBoxFlat.new()
	pic_style.bg_color = accent.lightened(0.8)
	pic_style.bg_color.a = 0.55
	pic_style.border_color = accent.lightened(0.55)
	pic_style.set_border_width_all(2)
	pic.add_theme_stylebox_override("panel", pic_style)
	var q := Label.new()
	q.text = "?"
	q.set_anchors_preset(Control.PRESET_FULL_RECT)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	q.add_theme_font_size_override("font_size", 52)
	q.add_theme_color_override("font_color", accent.lightened(0.35))
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.add_child(q)
	inner.add_child(pic)

	var t := UITheme.body("Not found yet", 13, UITheme.INK_SOFT)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(t)
	var sub := UITheme.soft_label(String(ROUTE_NAMES.get(slot.ending, "")), 10)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(sub)
	return p

## RosterScreen.gd — the character-select screen (the "Millbrook Circle" of
## love interests), equivalent to #screen-select in the HTML prototype. Each
## card shows her favorite and least-favorite gem (task: "girls page should
## say which her favorites are"), chapter progress dots, and — once
## unlocked — her ending title.
##
## Round 13: girl selection is now animated. Whoever is selected (hover a
## card, or tap it) fills the whole screen behind the cards — her location,
## zoomed in, with the camera slowly drifting across it (RosterBackdrop) —
## and her name, title and tagline sit over the scene in a caption. Opening
## her plays a short zoom-in before handing off to her story. The cards are
## now one row along the bottom (so the scene above them is actually
## visible), and each card's portrait + nameplate sits in a stylized frame
## (OrnateFrame).
class_name RosterScreen
extends RefCounted

## Card width — four across fits the 1280px window with the side margins.
## CARD_CONTENT_W is the usable width inside the card panel's own 14px
## left/right padding (UITheme.panel_style()), used to size her zoomed
## portrait art without depending on a not-yet-laid-out control's `.size`.
const CARD_W := 292.0
const CARD_CONTENT_W := CARD_W - 28.0
const PORTRAIT_STRIP_H := 150.0
const NAMEPLATE_H := 60.0
const CARD_GAP := 14.0
## Width available to the card row: the 1280px window minus the screen's
## 24px side margins.
const ROW_MAX_W := 1280.0 - 48.0

## Where a face typically sits on a bust-shot portrait, as a fraction of the
## FULL scaled image height (0 = very top of the image, 1 = very bottom).
## The strip only shows a 150px-tall window of the (much taller) full-width
## portrait, and this fraction decides which slice of it that window centers
## on. A plain top-anchored crop (fraction 0) showed mostly hair and cut the
## eyes off at the very bottom edge — real character art tends to have some
## headroom above the hair before the face starts, so the face itself centers
## noticeably lower than "the top" of the image.
const PORTRAIT_FACE_FOCUS := 0.32

## Full-body art (ArtAssets.is_full_body(): head to toe, at least 1.5x as tall
## as wide) fitted to the card's width would show a tiny whole figure, so it's
## zoomed in first and cropped around the face, which sits much higher up in
## a full-body picture. Tweak these two if her face lands off-center.
const FULL_BODY_ZOOM := 1.6
const FULL_BODY_FACE_FOCUS := 0.09

## Sweeping the mouse across the row shouldn't fire a crossfade for every
## card it passes over — the scene only follows once the pointer settles.
const HOVER_SETTLE_SEC := 0.12


static func build(main: Node, host: Control) -> void:
	var chars: Array = CharacterData.all()
	# Screen state, boxed in a Dictionary so every closure below shares (and
	# can mutate) the same values — see the closure note in VNScreen.gd.
	var state := {
		"main": main,
		"selected": "",
		"pending": "",
		"leaving": false,
		"cards": {},
	}

	var backdrop := RosterBackdrop.new()
	host.add_child(backdrop)
	state.backdrop = backdrop
	host.add_child(_make_scrim())

	var ui := MarginContainer.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_theme_constant_override("margin_left", 24)
	ui.add_theme_constant_override("margin_right", 24)
	ui.add_theme_constant_override("margin_top", 16)
	ui.add_theme_constant_override("margin_bottom", 18)
	host.add_child(ui)
	state.ui = ui

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	ui.add_child(v)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	var back := UITheme.make_glass_button("←  Menu")
	back.pressed.connect(func():
		SFX.nav()
		main.show_menu()
	)
	top_row.add_child(back)
	var title := UITheme.glass_label("Millbrook Circle", 16)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(spacer)
	var gallery_btn := UITheme.make_glass_button("Gallery")
	gallery_btn.pressed.connect(func():
		SFX.nav()
		main.show_gallery()
	)
	top_row.add_child(gallery_btn)
	v.add_child(top_row)

	# The open "hero" area between the top row and the cards: this is where
	# the scene is actually on show, with her caption in the lower-left.
	var hero := Control.new()
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(hero)
	hero.add_child(_make_caption(state))

	# One row of cards, centered. Only wrapped in a (horizontal) ScrollContainer
	# if the cast ever outgrows the window — a ScrollContainer clips its
	# content, which would shave off the selected card's glow and lift for no
	# reason while four cards fit comfortably.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_GAP)
	for ch in chars:
		row.add_child(_card(main, ch, state))
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(row)
	var row_w := chars.size() * CARD_W + maxf(0.0, chars.size() - 1.0) * CARD_GAP
	if row_w > ROW_MAX_W:
		var scroll := ScrollContainer.new()
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.add_child(center)
		v.add_child(scroll)
		state.scroll = scroll
	else:
		v.add_child(center)

	var settle := Timer.new()
	settle.one_shot = true
	settle.wait_time = HOVER_SETTLE_SEC
	settle.timeout.connect(func(): _commit(state, String(state.pending)))
	host.add_child(settle)
	state.settle = settle

	# Swallows clicks during the short zoom-in hand-off, so a second click
	# can't start a second navigation from a screen that's already leaving.
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	host.add_child(blocker)
	state.blocker = blocker

	var initial := _initial_selection(main, chars)
	_highlight(state, initial, true)
	_commit(state, initial, true)

	# Keys / a pad: start on the selected girl's main button; moving the focus
	# ring onto another card selects her, like hovering does. Back = the menu.
	var first: Control = state.cards[initial].open_btn if state.cards.has(initial) else back
	main.nav_setup(first, func():
		SFX.nav()
		main.show_menu()
	)


## Last girl the roster showed this session, else whoever you last played,
## else the first card.
static func _initial_selection(main: Node, chars: Array) -> String:
	for candidate in [String(main.roster_selected_id), String(main.current_char_id)]:
		if candidate != "" and not CharacterData.by_id(candidate).is_empty():
			return candidate
	return String(chars[0].id) if not chars.is_empty() else ""


## Darkens the top edge (behind the nav row) and the bottom (behind the card
## row) while leaving the middle of the scene clear.
static func _make_scrim() -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 1.0])
	g.colors = PackedColorArray([
		Color(0, 0, 0, 0.38), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.04), Color(0, 0, 0, 0.5)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var scrim := TextureRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.texture = gt
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return scrim


## Her name, title and tagline, on glass over the scene (lower-left of the
## hero area). Text is filled in by _update_caption().
static func _make_caption(state: Dictionary) -> PanelContainer:
	var caption := PanelContainer.new()
	caption.add_theme_stylebox_override("panel", UITheme.glass_style(18, 0.52))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Pinned to the hero area's bottom-left, growing upward as text changes.
	caption.anchor_left = 0.0
	caption.anchor_right = 0.0
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	caption.offset_top = -4.0
	caption.offset_bottom = -4.0

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 3)
	caption.add_child(cv)

	var tag := UITheme.placeholder_tag("Location art · placeholder")
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cv.add_child(tag)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.3))
	name_lbl.add_theme_constant_override("outline_size", 3)
	cv.add_child(name_lbl)

	var role_lbl := Label.new()
	role_lbl.add_theme_font_size_override("font_size", 12)
	role_lbl.add_theme_font_override("font", UITheme.tracked_font(2))
	cv.add_child(role_lbl)

	var tagline_lbl := Label.new()
	tagline_lbl.add_theme_font_size_override("font_size", 14)
	tagline_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	tagline_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tagline_lbl.custom_minimum_size = Vector2(520, 0)
	cv.add_child(tagline_lbl)

	state.caption = caption
	state.caption_tag = tag
	state.caption_name = name_lbl
	state.caption_role = role_lbl
	state.caption_tagline = tagline_lbl
	return caption


static func _update_caption(state: Dictionary, ch: Dictionary, instant: bool) -> void:
	var accent := Color(String(ch.get("c", "#FF6F91")))
	state.caption_name.text = String(ch.get("name", ""))
	state.caption_role.text = UITheme.t(String(ch.get("role", ""))).to_upper()
	state.caption_role.add_theme_color_override("font_color", accent.lightened(0.45))
	state.caption_tagline.text = UITheme.unquote(String(ch.get("tagline", "")))
	state.caption_tag.visible = ArtAssets.background_for(String(ch.get("bg", ""))) == null
	var caption: Control = state.caption
	if instant or GameState.settings.get("reduce_motion", false):
		caption.modulate.a = 1.0
		return
	caption.modulate.a = 0.0
	caption.create_tween().tween_property(caption, "modulate:a", 1.0, 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Pointer is over one of her card's controls — light up her card now,
## move the camera once the pointer settles.
static func _hover(state: Dictionary, id: String) -> void:
	if state.leaving or id == state.pending:
		return
	state.pending = id
	_highlight(state, id)
	state.settle.start()


## Make `id` the selected girl: her shot on the backdrop, her caption.
static func _commit(state: Dictionary, id: String, instant: bool = false) -> void:
	if id == "" or state.leaving:
		return
	state.pending = id
	_highlight(state, id, instant)
	if state.selected == id:
		return
	state.selected = id
	state.main.roster_selected_id = id
	# With more girls than fit across, bring her card into view.
	if state.has("scroll") and state.cards.has(id):
		(state.scroll as ScrollContainer).ensure_control_visible.call_deferred(state.cards[id].card)
	var ch := CharacterData.by_id(id)
	state.backdrop.show_character(ch, instant)
	_update_caption(state, ch, instant)


static func _highlight(state: Dictionary, id: String, instant: bool = false) -> void:
	var still: bool = instant or GameState.settings.get("reduce_motion", false)
	for cid in state.cards.keys():
		var entry: Dictionary = state.cards[cid]
		var on: bool = cid == id
		var card: PanelContainer = entry.card
		if bool(entry.get("on", false)) == on and not instant:
			continue
		entry.on = on
		card.add_theme_stylebox_override("panel", _card_style(entry.accent, on))
		entry.frame.selected = on
		var target := Vector2(1.03, 1.03) if on else Vector2.ONE
		if still:
			card.scale = target
		else:
			card.create_tween().tween_property(card, "scale", target, 0.22) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _card_style(accent: Color, on: bool) -> StyleBoxFlat:
	var s := UITheme.panel_style(UITheme.SURFACE_2, 18,
		accent.lightened(0.15) if on else accent.lightened(0.62), 2 if on else 1)
	if on:
		s.shadow_color = Color(accent.r, accent.g, accent.b, 0.55)
		s.shadow_size = 20
		s.shadow_offset = Vector2(0, 4)
	else:
		s.shadow_color = Color(0, 0, 0, 0.3)
		s.shadow_size = 10
		s.shadow_offset = Vector2(0, 5)
	return s


## Opening her: settle the camera on HER shot, play the zoom-in while the UI
## fades out, then hand off to StoryFlow. The hand-off is a tween_callback on
## a tween bound to the backdrop's own camera node — if the roster is freed
## mid-zoom for any reason, the tween dies with it and the callback never
## fires, so no navigation can come from a screen that's already gone.
static func _enter(state: Dictionary, id: String) -> void:
	if state.leaving:
		return
	var main: Node = state.main
	_commit(state, id, true)
	state.leaving = true
	var tw: Tween = state.backdrop.zoom_in(0.5)
	if tw == null:
		StoryFlow.enter_character(main, id)
		return
	state.blocker.visible = true
	tw.parallel().tween_property(state.ui, "modulate:a", 0.0, 0.32).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): StoryFlow.enter_character(main, id))


static func _card(main: Node, ch: Dictionary, state: Dictionary) -> PanelContainer:
	var id := String(ch.id)
	var accent := Color(String(ch.c))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", _card_style(accent, false))
	card.resized.connect(func(): card.pivot_offset = card.size * 0.5)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	card.add_child(v)

	var plate := _plate(ch, accent)
	v.add_child(plate)

	# Stacked vertically (not side-by-side in an HBox) — a Label with
	# word-wrap enabled reports a tiny minimum width (just enough for its
	# longest single word), so two of them packed into an HBoxContainer with
	# no expand flag were overlapping instead of sitting side by side. A
	# VBoxContainer sidesteps the whole problem: each line gets the full
	# card width to itself.
	var prefs := VBoxContainer.new()
	prefs.add_theme_constant_override("separation", 2)
	prefs.add_child(_pref_row("💚", "Loves", String(ch.fav)))
	prefs.add_child(_pref_row("🚫", "Dislikes", String(ch.least)))
	v.add_child(prefs)

	var progress: Dictionary = GameState.progress_for(id)
	var levels: Array = ch.story.levels
	var finished: bool = not progress.endings_unlocked.is_empty()
	var level_idx: int = int(progress.get("level_index", 0))
	var won: Array = progress.get("won_levels", [])
	# Met her = her intro has been seen (or she's further along than that).
	var met: bool = finished or level_idx > 0 or bool(progress.get("_intro_done", false)) \
		or progress.has("scene_pending")
	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 5)
	dots.mouse_filter = Control.MOUSE_FILTER_PASS
	for i in range(levels.size()):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(18, 6)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var done: bool = finished or i < level_idx or won.has(i)
		dot.color = accent if done else UITheme.LINE
		dots.add_child(dot)
	v.add_child(dots)

	var status_text := "Not met yet"
	if finished:
		# Whichever finale she actually reached (round 12's epilogue choice),
		# same as the Gallery and the reopened CG — not just the flat ending.
		status_text = UITheme.t("Ending: %s") % UITheme.t(String(StoryFlow.display_ending_for(id).get("title", "")))
	elif met:
		# (It used to say "Not started" until chapter 1 was WON, even after
		# her whole introduction.)
		status_text = UITheme.t("Chapter %d / %d") % [level_idx + 1, levels.size()]
	var status_lbl := UITheme.soft_label(status_text, 11)
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	status_lbl.clip_text = true
	status_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_lbl.tooltip_text = status_text
	status_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	if finished:
		status_lbl.add_theme_color_override("font_color", accent.darkened(0.15))
	v.add_child(status_lbl)

	var open_label := "Meet her"
	if finished:
		open_label = "Revisit"
	elif met:
		open_label = "Continue"
	var open_btn := UITheme.make_primary_button(open_label)
	open_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_btn.pressed.connect(func():
		SFX.nav()
		_enter(state, id)
	)
	if finished:
		# Play her story again from the start — e.g. to find her other ending.
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)
		btn_row.add_child(open_btn)
		var replay_btn := UITheme.make_ghost_button("Replay")
		replay_btn.tooltip_text = "Start her story over from the beginning"
		replay_btn.pressed.connect(func():
			SFX.nav()
			main.confirm(UITheme.t("Replay %s's story?") % UITheme.t(String(ch.name)),
				"Her story starts over from your first meeting, so you can make different choices. Endings you've found stay in the Gallery, your gift stays given, and her chapters pay out stars again.",
				"Replay story", func():
					StoryFlow.restart_character(id)
					main.roster_selected_id = id
					main.show_roster()
			)
		)
		btn_row.add_child(replay_btn)
		v.add_child(btn_row)
	else:
		v.add_child(open_btn)

	# Gifts come after you've met her — her thank-you scene talks about things
	# you only know once you have (it used to be offered before her intro).
	var gifts_given: Array = progress.get("gifts_given", [])
	if met and not gifts_given.has(ch.gift.id):
		v.add_child(_gift_button(main, ch, accent, progress, gifts_given))

	state.cards[id] = {"card": card, "frame": plate.get_node("Frame"), "accent": accent, "on": false, "open_btn": open_btn}

	# Any control on her card counts as "pointing at her" — mouse_entered only
	# fires on whichever control is actually under the pointer, and that's
	# usually a child (a button, the portrait window...), not the card itself.
	_connect_hover(card, func(): _hover(state, id))
	_connect_focus(card, func(): _hover(state, id))
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_commit(state, id)
	)
	return card


## "💚 Loves [gem] Rune" — the gem's own icon (art/gems/<gem>.png) between
## the words when it exists, so the player learns which piece to look for.
static func _pref_row(emoji: String, verb: String, gem_id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var lead := UITheme.soft_label(emoji + " " + UITheme.t(verb), 10)
	lead.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(lead)
	var tex := ArtAssets.gem_icon(gem_id)
	if tex:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.custom_minimum_size = Vector2(14, 14)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var gem := UITheme.soft_label(CharacterData.gem_label(gem_id), 10)
	gem.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(gem)
	return row


## Same as _connect_hover(), for the keyboard/controller focus ring.
static func _connect_focus(node: Node, cb: Callable) -> void:
	if node is Control and (node as Control).focus_mode != Control.FOCUS_NONE:
		(node as Control).focus_entered.connect(cb)
	for c in node.get_children():
		_connect_focus(c, cb)


static func _connect_hover(node: Node, cb: Callable) -> void:
	if node is Control:
		node.mouse_entered.connect(cb)
	for c in node.get_children():
		_connect_hover(c, cb)


## Portrait window + nameplate, inside the ornate frame.
static func _plate(ch: Dictionary, accent: Color) -> Control:
	var id := String(ch.id)
	var plate := Control.new()
	plate.custom_minimum_size = Vector2(CARD_CONTENT_W, PORTRAIT_STRIP_H + NAMEPLATE_H)
	plate.mouse_filter = Control.MOUSE_FILTER_PASS

	# ---- portrait window: exactly the strip, clipped to it ----
	var window := Control.new()
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_PASS
	window.anchor_right = 1.0
	window.offset_bottom = PORTRAIT_STRIP_H
	plate.add_child(window)

	var bg_tex := ArtAssets.background_for(String(ch.get("bg", "")))
	if bg_tex:
		var bg_img := TextureRect.new()
		bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_img.texture = bg_tex
		bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		window.add_child(bg_img)
	else:
		# Same stand-in scene the backdrop flies over, just card-sized.
		var scene := PlaceholderScene.new().setup(accent, hash(id))
		scene.set_anchors_preset(Control.PRESET_FULL_RECT)
		window.add_child(scene)

	var art_tex := ArtAssets.character_portrait(id, "neutral")
	if art_tex:
		var art := TextureRect.new()
		art.texture = art_tex
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Fit to the card's full content width, then show only a
		# PORTRAIT_STRIP_H-tall window of that (much taller) scaled image,
		# anchored so PORTRAIT_FACE_FOCUS (as a fraction down the full image)
		# lands at the window's vertical CENTER — a deliberate close-up crop
		# on her face. `window` clips it to exactly the strip (it used to be
		# clipped by a padded panel instead, so her hair and hands poked out
		# past the strip over the border).
		art.anchor_left = 0.0
		art.anchor_right = 1.0
		art.anchor_top = 0.0
		art.anchor_bottom = 0.0
		var aspect: float = float(art_tex.get_height()) / float(max(1, art_tex.get_width()))
		# Full-body art: zoomed in (centered sideways) and focused higher up.
		var tall := ArtAssets.is_full_body(art_tex)
		var art_w: float = CARD_CONTENT_W * (FULL_BODY_ZOOM if tall else 1.0)
		art.offset_left = -(art_w - CARD_CONTENT_W) / 2.0
		art.offset_right = (art_w - CARD_CONTENT_W) / 2.0
		var full_h: float = art_w * aspect
		var focus: float = FULL_BODY_FACE_FOCUS if tall else PORTRAIT_FACE_FOCUS
		# Her own art can frame the face higher or lower than these defaults:
		# characters.json "portraitFocus" (how far down the picture her face
		# is, 0-1) overrides them (round 18: Hazel's busts, face at ~0.45).
		if ch.has("portraitFocus"):
			focus = clampf(float(ch.portraitFocus), 0.0, 1.0)
		var top_crop: float = clamp(
			focus * full_h - PORTRAIT_STRIP_H / 2.0,
			0.0, max(0.0, full_h - PORTRAIT_STRIP_H))
		art.offset_top = -top_crop
		art.offset_bottom = full_h - top_crop
		window.add_child(art)
	else:
		var portrait_center := CenterContainer.new()
		portrait_center.set_anchors_preset(Control.PRESET_FULL_RECT)
		portrait_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var initial := Label.new()
		initial.text = String(ch.name).substr(0, 1)
		initial.add_theme_font_size_override("font_size", 58)
		initial.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
		initial.add_theme_color_override("font_outline_color", accent.darkened(0.55))
		initial.add_theme_constant_override("outline_size", 6)
		portrait_center.add_child(initial)
		window.add_child(portrait_center)

		# Tucked inside the window's top-right, clear of the frame's corner
		# stud (it used to be anchored so it hung off the strip's right edge
		# and got clipped down to a single letter).
		var tag_box := MarginContainer.new()
		tag_box.set_anchors_preset(Control.PRESET_FULL_RECT)
		tag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag_box.add_theme_constant_override("margin_top", 13)
		tag_box.add_theme_constant_override("margin_right", 24)
		var tag_row := HBoxContainer.new()
		tag_row.alignment = BoxContainer.ALIGNMENT_END
		tag_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag_row.add_child(UITheme.placeholder_tag())
		tag_box.add_child(tag_row)
		window.add_child(tag_box)

	# ---- nameplate ----
	var nameplate := Panel.new()
	var np_style := StyleBoxFlat.new()
	np_style.bg_color = accent.lightened(0.87)
	nameplate.add_theme_stylebox_override("panel", np_style)
	nameplate.mouse_filter = Control.MOUSE_FILTER_PASS
	nameplate.anchor_right = 1.0
	nameplate.anchor_bottom = 1.0
	nameplate.offset_top = PORTRAIT_STRIP_H
	plate.add_child(nameplate)

	var nv := VBoxContainer.new()
	nv.anchor_right = 1.0
	nv.anchor_bottom = 1.0
	# Clear of the divider gems above and the frame's molding below.
	nv.offset_top = 6.0
	nv.offset_bottom = -13.0
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nv.add_theme_constant_override("separation", 0)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nameplate.add_child(nv)
	# Ellipsized rather than overflowing if a name/title is ever too long for
	# the plate; the full text is in the plate's tooltip.
	plate.tooltip_text = String(ch.name) + " — " + String(ch.role)
	var name_lbl := UITheme.body(String(ch.name), 17)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.add_child(name_lbl)
	var role_lbl := UITheme.accent_label(UITheme.t(String(ch.role)).to_upper(), accent.darkened(0.22), 10)
	role_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	role_lbl.clip_text = true
	role_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_override("font", UITheme.tracked_font(1))
	nv.add_child(role_lbl)

	# ---- the frame itself, over everything ----
	var frame := OrnateFrame.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.accent = accent
	frame.mask_color = UITheme.SURFACE_2
	frame.divider_y = PORTRAIT_STRIP_H
	plate.add_child(frame)
	return plate


## "Give her a gift" button. The price is its own right-hand label and the
## gift's name ellipsizes before it, so a long name can never push the price
## out of sight (or force the card wider than its column); the full name and
## description are in the tooltip.
static func _gift_button(main: Node, ch: Dictionary, accent: Color, progress: Dictionary, gifts_given: Array) -> Button:
	var price := int(ch.gift.price)
	var gift_btn := UITheme.make_card_button("", accent)
	gift_btn.custom_minimum_size = Vector2(0, 40)
	gift_btn.tooltip_text = UITheme.t("Give her the %s") % UITheme.t(String(ch.gift.name)) + " — " + UITheme.t(String(ch.gift.get("desc", "")))
	gift_btn.disabled = GameState.stars < price
	if gift_btn.disabled:
		gift_btn.tooltip_text += "\n" + UITheme.t("(You need %d more stars.)") % (price - GameState.stars)

	var gh := HBoxContainer.new()
	gh.set_anchors_preset(Control.PRESET_FULL_RECT)
	gh.offset_left = 14.0
	gh.offset_right = -14.0
	gh.add_theme_constant_override("separation", 8)
	gh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if gift_btn.disabled:
		gh.modulate.a = 0.55
	# Her gift's own icon (art/gifts/<gift id>.png) when it exists, else 🎁.
	var gift_tex := ArtAssets.gift_icon(String(ch.gift.id))
	if gift_tex:
		var gicon := TextureRect.new()
		gicon.texture = gift_tex
		gicon.custom_minimum_size = Vector2(24, 24)
		gicon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gicon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gicon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gh.add_child(gicon)
	var gname := UITheme.body(("" if gift_tex else "🎁  ") + String(ch.gift.name), 13)
	gname.autowrap_mode = TextServer.AUTOWRAP_OFF
	gname.clip_text = true
	gname.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	gname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gname.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gname.size_flags_vertical = Control.SIZE_FILL
	gh.add_child(gname)
	var gprice := UITheme.body(str(price), 13, accent.darkened(0.25))
	gprice.autowrap_mode = TextServer.AUTOWRAP_OFF
	gprice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gprice.size_flags_vertical = Control.SIZE_FILL
	gh.add_child(gprice)
	gh.add_child(UITheme.icon_or_emoji("star", "⭐", 16))
	gift_btn.add_child(gh)

	gift_btn.pressed.connect(func():
		if GameState.stars < price:
			return
		GameState.stars -= price
		gifts_given.append(ch.gift.id)
		progress["gifts_given"] = gifts_given
		GameState.save_state()
		Achievements.check_gifts()
		SFX.purchase()
		main.refresh_topbar()
		main.show_vn_scene(ch.id, ch.giftLine, null, func():
			main.show_roster()
		)
	)
	return gift_btn

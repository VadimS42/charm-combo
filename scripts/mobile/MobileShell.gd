## MobileShell.gd — the phone and tablet menus (round 47).
##
## On Android (Platform.mobile; `-- --mobile` to try it on PC) the menu
## screens aren't the desktop ones squeezed down: they're one shell with a tab
## bar — Home, Girls, Shop, Gallery, More — along the bottom when the phone is
## upright and down the left side when it's turned sideways, and each tab is
## a single scrolling column of big, thumb-sized cards (two columns of girls
## when there's room). Main turns its show_menu / show_roster / show_store /
## show_gallery / show_achievements / show_credits into show(main, tab) on
## mobile, and rebuilds the screen when the phone rotates.
##
## The desktop (Windows / Steam) screens are untouched by any of this.
class_name MobileShell
extends RefCounted

const TABS := [
	{"id": "home", "name": "Home", "icon": "menu"},
	{"id": "girls", "name": "Girls", "icon": "heart"},
	{"id": "shop", "name": "Shop", "icon": "store"},
	{"id": "gallery", "name": "Gallery", "icon": "gallery"},
	{"id": "more", "name": "More", "icon": "settings"},
]
## Thumb-sized: about 48 dp on a phone at Main's mobile scale.
const TAP_H := 52.0
const BAR := 64.0
const PAD := 16.0


static func portrait(main: Node) -> bool:
	var s: Vector2 = main.get_viewport().get_visible_rect().size
	return s.y > s.x


## Builds the shell with `tab` open (sub: a page inside More, e.g. "credits").
static func show(main: Node, tab: String, sub: String = "") -> void:
	var host: Control = main.screen_host
	host.add_child(UITheme.make_screen_backdrop(UITheme.ACCENT, UITheme.ACCENT_2))
	var up := portrait(main)
	var box: BoxContainer = VBoxContainer.new() if up else HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 0)
	host.add_child(box)
	var content := MarginContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var bar := _tab_bar(main, tab, up)
	if up:
		box.add_child(content)
		box.add_child(bar)
	else:
		box.add_child(bar)
		box.add_child(content)
	var first: Control = null
	match tab:
		"home": first = _home(main, content)
		"girls": first = _girls(main, content, up)
		"shop": first = _shop(main, content)
		"gallery": first = _gallery(main, content, sub)
		"more": first = _more(main, content, sub)
	var back := func():
		if sub != "":
			main.show_mobile("more")
		elif tab != "home":
			main.show_menu()
	main.nav_setup(first if first else _first_tab(bar), back if (tab != "home" or sub != "") else Callable())


static func _first_tab(bar: Control) -> Control:
	for c in bar.find_children("*", "Button", true, false):
		return c
	return null


# ---------------------------------------------------------------- the tab bar

static func _tab_bar(main: Node, current: String, up: bool) -> Control:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.13, 0.06, 0.16, 0.9)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)
	if up:
		p.custom_minimum_size = Vector2(0, BAR)
	else:
		p.custom_minimum_size = Vector2(BAR + 12, 0)
	var box: BoxContainer = HBoxContainer.new() if up else VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	p.add_child(box)
	for t in TABS:
		var on: bool = String(t.id) == current
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if up else Control.SIZE_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL if not up else Control.SIZE_FILL
		b.custom_minimum_size = Vector2(0, BAR - 8) if up else Vector2(BAR, 0)
		b.add_theme_stylebox_override("focus", UITheme.focus_ring(12))
		var col := UITheme.ACCENT.lightened(0.25) if on else Color(1, 1, 1, 0.6)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic := UITheme.picture(ArtAssets.ui_icon(String(t.icon)), 24)
		ic.modulate = col
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var l := UITheme.body(String(t.name), 11, col)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		v.add_child(l)
		b.add_child(v)
		var id := String(t.id)
		b.pressed.connect(func():
			SFX.nav()
			main.show_mobile(id)
		)
		box.add_child(b)
	return p


# ---------------------------------------------------------------- shared bits

## The scrolling column every tab lives in. Returns the VBox to fill.
static func _column(content: Control, title: String, max_w: float = 620.0) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Lists of text stay a readable width on a sideways phone or a tablet.
	var side_pad := PAD
	var w: float = content.get_viewport().get_visible_rect().size.x - BAR
	if max_w > 0.0 and w > max_w + 2.0 * PAD:
		side_pad = (w - max_w) / 2.0
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, int(side_pad))
	m.add_theme_constant_override("margin_top", 58)  # under the floating stars / Settings
	m.add_theme_constant_override("margin_bottom", int(PAD))
	scroll.add_child(m)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	if title != "":
		var h := UITheme.heading(title, 24)
		h.add_theme_color_override("font_color", Color.WHITE)
		h.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
		h.add_theme_constant_override("outline_size", 4)
		v.add_child(h)
	return v


static func _card(accent: Color = UITheme.LINE) -> Array:
	var p := UITheme.panel(UITheme.SURFACE, 18, accent)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return [p, v]


static func _big(btn: Button) -> Button:
	btn.custom_minimum_size = Vector2(0, TAP_H)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return btn


static func _wrap(text: String, size: int = 14, color: Color = UITheme.INK) -> Label:
	var l := UITheme.body(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


# ---------------------------------------------------------------- Home

static func _home(main: Node, content: Control) -> Control:
	var v := _column(content, "")
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	v.add_child(spacer)
	var title := UITheme.heading("Charm Combo", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", UITheme.ACCENT.darkened(0.3))
	title.add_theme_constant_override("outline_size", 8)
	v.add_child(title)
	var tag := _wrap(UITheme.t("A match-3 romance in Millbrook. Meet four women in the worst way possible, help them with what they need, and see where it goes."), 14, Color.WHITE)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	tag.add_theme_constant_override("outline_size", 3)
	v.add_child(tag)
	# Play: straight back into whoever you were with last, else the girls.
	var last := String(main.roster_selected_id)
	var cont: bool = last != "" and not CharacterData.by_id(last).is_empty() and _met(last) \
		and GameState.progress_for(last).endings_unlocked.is_empty()
	var play := _big(UITheme.make_primary_button(
		(UITheme.t("Continue with %s") % UITheme.first_name(String(CharacterData.by_id(last).name))) if cont else UITheme.t("Play")))
	play.custom_minimum_size.y = 60
	play.pressed.connect(func():
		SFX.nav()
		if cont:
			StoryFlow.enter_character(main, last)
		else:
			main.show_mobile("girls")
	)
	v.add_child(play)
	if cont:
		var all := _big(UITheme.make_ghost_button("All the girls"))
		all.pressed.connect(func():
			SFX.nav()
			main.show_mobile("girls"))
		v.add_child(all)
	v.add_child(_big(main.daily_button()))
	var how := _big(UITheme.make_ghost_button("How to Play"))
	UITheme.add_icon(how, "help")
	how.pressed.connect(func():
		SFX.nav()
		HowToPlay.show_page(main))
	v.add_child(how)
	var foot := _wrap(UITheme.t("Original characters · all characters are adults.") if Platform.sfw
		else UITheme.t("18+ · original characters · all characters are adults."), 11, Color(1, 1, 1, 0.8))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)
	return play


static func _met(id: String) -> bool:
	var p := GameState.progress_for(id)
	return not p.endings_unlocked.is_empty() or int(p.get("level_index", 0)) > 0 \
		or bool(p.get("_intro_done", false)) or p.has("scene_pending")


# ---------------------------------------------------------------- Girls

static func _girls(main: Node, content: Control, up: bool) -> Control:
	var v := _column(content, UITheme.t("Millbrook Circle"), 0.0)
	var grid := GridContainer.new()
	var w: float = main.get_viewport().get_visible_rect().size.x
	grid.columns = 1 if up or w < 760 else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(grid)
	var first: Control = null
	for ch in CharacterData.all():
		var btn := _girl_card(main, ch, grid)
		if first == null:
			first = btn
	return first


## One girl: her picture beside her name, likes, progress and buttons.
static func _girl_card(main: Node, ch: Dictionary, parent: Control) -> Button:
	var id := String(ch.id)
	var accent := Color(String(ch.c))
	var pv := _card(accent)
	var card: PanelContainer = pv[0]
	var v: VBoxContainer = pv[1]
	parent.add_child(card)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	v.add_child(top)
	# Her face, cropped like the roster card (cardCrop), or the placeholder.
	var pic_box := PanelContainer.new()
	pic_box.custom_minimum_size = Vector2(96, 112)
	pic_box.clip_contents = true
	var pst := StyleBoxFlat.new()
	pst.bg_color = accent.darkened(0.35)
	pst.set_corner_radius_all(12)
	pic_box.add_theme_stylebox_override("panel", pst)
	var tex := ArtAssets.character_portrait(id, "neutral")
	if tex:
		pic_box.add_child(face_rect(ch, tex, Vector2(96, 112)))
	else:
		var c := CenterContainer.new()
		c.add_child(UITheme.placeholder_portrait(id, String(ch.name).substr(0, 1), 80.0))
		pic_box.add_child(c)
	top.add_child(pic_box)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	top.add_child(info)
	info.add_child(UITheme.heading(String(ch.name), 18))
	var role := _wrap(UITheme.t(String(ch.get("role", ""))), 11, accent.darkened(0.25))
	info.add_child(role)
	info.add_child(RosterScreen._pref_row("💚", "Loves", String(ch.fav)))
	info.add_child(RosterScreen._pref_row("🚫", "Dislikes", String(ch.least)))
	var progress: Dictionary = GameState.progress_for(id)
	var levels: Array = ch.story.levels
	var finished: bool = not progress.endings_unlocked.is_empty()
	var level_idx: int = int(progress.get("level_index", 0))
	var won: Array = progress.get("won_levels", [])
	var met := _met(id)
	var status := UITheme.t("Not met yet")
	if finished:
		status = UITheme.t("Ending: %s") % UITheme.t(String(StoryFlow.display_ending_for(id).get("title", "")))
	elif met:
		status = UITheme.t("Chapter %d / %d") % [level_idx + 1, levels.size()]
	info.add_child(_wrap(status, 12, UITheme.INK_SOFT))
	var open := _big(UITheme.make_primary_button("Revisit" if finished else ("Continue" if met else "Meet her")))
	open.pressed.connect(func():
		SFX.nav()
		main.roster_selected_id = id
		StoryFlow.enter_character(main, id))
	v.add_child(open)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if not won.is_empty():
		var again := _big(UITheme.make_ghost_button("Replay a chapter"))
		again.pressed.connect(func():
			SFX.nav()
			RosterScreen._chapter_picker(main, ch, won))
		row.add_child(again)
	if finished:
		var date := _big(UITheme.make_ghost_button("Free date"))
		date.tooltip_text = UITheme.t("Her board with no move limit, just for fun and a high score.")
		date.pressed.connect(func():
			SFX.nav()
			main.show_puzzle(id, -1, "free"))
		row.add_child(date)
		var restart := _big(UITheme.make_ghost_button("Replay"))
		restart.pressed.connect(func():
			SFX.nav()
			main.confirm(UITheme.t("Replay %s's story?") % UITheme.t(String(ch.name)),
				"Her story starts over from your first meeting, so you can make different choices. Endings you've found stay in the Gallery, your gift stays given, and her chapters pay out stars again.",
				"Replay story", func():
					StoryFlow.restart_character(id)
					main.show_mobile("girls")))
		row.add_child(restart)
	if row.get_child_count() > 0:
		v.add_child(row)
	var gifts_given: Array = progress.get("gifts_given", [])
	var past_first: bool = finished or level_idx > 0 or won.has(0)
	if past_first and not gifts_given.has(ch.gift.id):
		var g := RosterScreen._gift_button(main, ch, accent, progress, gifts_given)
		g.custom_minimum_size.y = TAP_H
		v.add_child(g)
	return open


## Her picture filling a box of `box` size: zoomed in on her face the way her
## roster card is (characters.json "cardCrop"), else the whole picture
## covering the box. Used by the Girls tab and the mobile chapter screen.
static func face_rect(ch: Dictionary, tex: Texture2D, box: Vector2, zoom_scale: float = 1.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	var crop: Dictionary = ch.get("cardCrop", {})
	if not crop.is_empty():
		# zoom_scale < 1 shows more of her (the chapter's bigger frame).
		var z := maxf(1.0, float(crop.get("zoom", 1.0)) * zoom_scale)
		var cw := tex.get_width() / z
		var chh := cw * box.y / box.x
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(clampf(float(crop.get("x", 0.5)) * tex.get_width() - cw / 2.0, 0, tex.get_width() - cw),
			clampf(float(crop.get("y", 0.0)) * tex.get_height(), 0, maxf(0.0, tex.get_height() - chh)), cw, chh)
		t.texture = at
	elif ArtAssets.is_full_body(tex):
		# A full figure: the top of it (her face), not the middle.
		var at2 := AtlasTexture.new()
		at2.atlas = tex
		var w2 := float(tex.get_width())
		at2.region = Rect2(0, 0, w2, minf(float(tex.get_height()), w2 * box.y / box.x))
		t.texture = at2
	return t


# ---------------------------------------------------------------- Shop

static func _shop(main: Node, content: Control) -> Control:
	var v := _column(content, UITheme.t("Item Shop"))
	v.add_child(_wrap(UITheme.t("Stars come from clearing chapters: 15 for a girl's first and 5 more for each one after it."), 12, Color.WHITE))
	var first: Control = null
	for item in StoreScreen.ITEMS:
		var pv := _card()
		var card: PanelContainer = pv[0]
		var cv: VBoxContainer = pv[1]
		v.add_child(card)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		cv.add_child(h)
		h.add_child(UITheme.picture(ArtAssets.store_icon(String(item.id)), 56))
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		tv.add_child(UITheme.heading(UITheme.t(String(item.name)), 17))
		tv.add_child(_wrap(UITheme.t(String(item.desc)), 12, UITheme.INK_SOFT))
		var owned := int(GameState.items.get(item.id, 0))
		tv.add_child(UITheme.body(UITheme.t("You have %d") % owned, 12, UITheme.INK))
		var price := int(item.price)
		var buy := _big(UITheme.make_primary_button(UITheme.t("Buy · %d ⭐") % price))
		UITheme.apply_icon(buy, "star", UITheme.t("Buy · %d") % price)
		buy.disabled = GameState.stars < price
		var iid := String(item.id)
		buy.pressed.connect(func():
			if GameState.stars < price:
				return
			GameState.stars -= price
			GameState.items[iid] = int(GameState.items.get(iid, 0)) + 1
			GameState.save_state()
			Achievements.unlock("FIRST_PURCHASE")
			SFX.purchase()
			main.refresh_topbar()
			main.show_mobile("shop"))
		cv.add_child(buy)
		if first == null and not buy.disabled:
			first = buy
	# Opened from a chapter's Out of Moves: a way straight back into it.
	if String(main.store_return_char) != "":
		var back := _big(UITheme.make_ghost_button("Back to the chapter"))
		back.pressed.connect(func():
			SFX.nav()
			main.leave_store())
		v.add_child(back)
		if first == null:
			first = back
	return first


# ---------------------------------------------------------------- Gallery

static func _gallery(main: Node, content: Control, sub: String) -> Control:
	var v := _column(content, UITheme.t("Gallery") if sub != "achievements" else UITheme.t("Achievements"),
		620.0 if sub in ["achievements", "stats", "music"] else 0.0)
	# Endings, Achievements, Pictures, Music, Stats (round 49): wraps onto
	# two rows on an upright phone.
	var seg := HFlowContainer.new()
	seg.add_theme_constant_override("h_separation", 8)
	seg.add_theme_constant_override("v_separation", 8)
	var e_btn: Button = null
	for pg in [["", "Endings"], ["achievements", "Achievements"], ["pictures", "Pictures"], ["music", "Music"], ["stats", "Stats"]]:
		var key := String(pg[0])
		var sb := UITheme.make_primary_button(String(pg[1])) if key == sub else UITheme.make_ghost_button(String(pg[1]))
		sb.custom_minimum_size = Vector2(0, 44)
		sb.pressed.connect(func(): main.show_mobile("gallery", key))
		seg.add_child(sb)
		if e_btn == null:
			e_btn = sb
	v.add_child(seg)
	if sub == "pictures":
		v.add_child(ExtrasScreen.pictures_page(main))
		return e_btn
	if sub == "music":
		v.add_child(ExtrasScreen.music_page(main))
		return e_btn
	if sub == "stats":
		v.add_child(ExtrasScreen.stats_page(main))
		return e_btn
	if sub == "achievements":
		v.add_child(_wrap(UITheme.t("%d / %d unlocked") % [Achievements.count_unlocked(), Achievements.LIST.size()], 13, Color.WHITE))
		for a in Achievements.LIST:
			var row := AchievementsScreen._row(a)
			row.custom_minimum_size.x = 0
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for l in row.find_children("*", "Label", true, false):
				(l as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(row)
		return e_btn
	var slots := GalleryScreen.all_slots()
	for ch in CharacterData.all():
		var mine := slots.filter(func(s): return s.char_id == String(ch.id))
		var pv := _card(Color(String(ch.c)))
		(pv[1] as VBoxContainer).add_child(GalleryScreen._section(main, ch, mine))
		v.add_child(pv[0])
	return e_btn


# ---------------------------------------------------------------- More

static func _more(main: Node, content: Control, sub: String) -> Control:
	if sub == "credits":
		var cv := _column(content, UITheme.t("Credits"))
		var txt := FileAccess.get_file_as_string(CreditsScreen.CREDITS_PATH)
		var pv := _card()
		(pv[1] as VBoxContainer).add_child(_wrap(txt, 13))
		cv.add_child(pv[0])
		var back := _big(UITheme.make_ghost_button("←  Back"))
		back.pressed.connect(func(): main.show_mobile("more"))
		cv.add_child(back)
		return back
	var v := _column(content, UITheme.t("More"))
	var settings := _big(UITheme.make_primary_button("Settings"))
	UITheme.add_icon(settings, "settings")
	settings.pressed.connect(func():
		SFX.nav()
		main.show_settings())
	v.add_child(settings)
	var how := _big(UITheme.make_ghost_button("How to Play"))
	UITheme.add_icon(how, "help")
	how.pressed.connect(func():
		SFX.nav()
		HowToPlay.show_page(main))
	v.add_child(how)
	var credits := _big(UITheme.make_ghost_button("Credits"))
	UITheme.add_icon(credits, "credits")
	credits.pressed.connect(func():
		SFX.nav()
		main.show_mobile("more", "credits"))
	v.add_child(credits)
	return settings

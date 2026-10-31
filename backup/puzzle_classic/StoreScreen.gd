## StoreScreen.gd — buy consumable puzzle items with stars, equivalent to
## #screen-store in the HTML prototype.
class_name StoreScreen
extends RefCounted

const ITEMS := [
	{"id": "moves", "name": "Time Scroll", "desc": "Read it for three more moves in the chapter you're playing. Use it from the item row under the board — it also gets you out of an Out of Moves screen.", "price": 15, "icon": "⏱"},
	{"id": "hammer", "name": "Hammer", "desc": "Pop any one gem, no match needed. Arm it from the item row, then tap a gem.", "price": 12, "icon": "🔨"},
	{"id": "shuffle", "name": "Shuffle Wand", "desc": "One wave and the whole board is dealt again, always with a move to make.", "price": 8, "icon": "🔀"},
	{"id": "colorBomb", "name": "Starburst Starter", "desc": "Your next chapter begins with a free Starburst gem already on the board.", "price": 15, "icon": "✨"},
	{"id": "favorCharm", "name": "Love Potion", "desc": "Your next chapter: her favorite gem shows up more often, her least favorite less.", "price": 22, "icon": "💗"},
	{"id": "heartMender", "name": "Mending Potion", "desc": "Your next chapter: far fewer cursed shards appear on the board.", "price": 20, "icon": "💚"},
]

const CARD_W := 330.0


static func build(main: Node, host: Control) -> void:
	host.add_child(UITheme.make_screen_backdrop(UITheme.ACCENT_2, UITheme.ACCENT))

	# Side/top margins — this screen used to sit flush against the window edges.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	host.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)

	var top_row := HBoxContainer.new()
	var back := UITheme.make_ghost_button("←  Back to the chapter" if main.store_return_char != "" else "←  Back")
	back.pressed.connect(func():
		SFX.nav()
		main.leave_store()
	)
	top_row.add_child(back)
	outer.add_child(top_row)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	center.add_child(v)

	v.add_child(UITheme.heading("Item Shop", 22))
	var sub := UITheme.soft_label(
		UITheme.t("Stars come from clearing chapters: 15 for a girl's first and 5 more for each one after it.") + " " +
		UITheme.t("Running out of moves still pays 1 star for every 200 points you scored (at least 3).") + " " +
		UITheme.t("Short on stars? Replay a chapter you've cleared, from her card on the roster: it pays half.") + " " +
		UITheme.t("The top row is used during a chapter; the bottom row kicks in on its own when your next chapter starts."), 12)
	sub.custom_minimum_size = Vector2(CARD_W * 3.0 + 24.0, 0)
	v.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)

	var first_buy: Button = null
	for item in ITEMS:
		var card := _card(main, item)
		grid.add_child(card)
		var b: Button = card.get_meta("buy_btn")
		if first_buy == null and not b.disabled:
			first_buy = b
	main.nav_setup(first_buy if first_buy != null else back, func():
		SFX.nav()
		main.leave_store()
	)


static func _card(main: Node, item: Dictionary) -> PanelContainer:
	var card := UITheme.panel(UITheme.SURFACE_2, 16, UITheme.LINE)
	card.custom_minimum_size = Vector2(CARD_W, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var icon_tex := ArtAssets.store_icon(String(item.id))
	if icon_tex:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.custom_minimum_size = Vector2(40, 40)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.add_child(icon_rect)
	else:
		var icon := Label.new()
		icon.text = String(item.icon)
		icon.add_theme_font_size_override("font_size", 28)
		head.add_child(icon)
	var name_lbl := UITheme.body(String(item.name), 15)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(name_lbl)
	v.add_child(head)

	var d := UITheme.soft_label(String(item.desc), 11)
	d.custom_minimum_size = Vector2(CARD_W - 28.0, 0)
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)

	var owned := int(GameState.items.get(item.id, 0))
	v.add_child(UITheme.soft_label(UITheme.t("Owned: %d") % owned, 11))

	var price := int(item.price)
	var buy_btn := UITheme.make_primary_button(UITheme.t("Buy · %d ⭐") % price)
	# art/ui/star.png after the price when it exists, in place of the emoji.
	UITheme.apply_icon(buy_btn, "star", UITheme.t("Buy · %d") % price)
	if buy_btn.icon != null:
		buy_btn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buy_btn.disabled = GameState.stars < price
	if buy_btn.disabled:
		buy_btn.tooltip_text = UITheme.t("You need %d more stars.") % (price - GameState.stars)
	buy_btn.pressed.connect(func():
		if GameState.stars < price:
			return
		GameState.stars -= price
		GameState.items[item.id] = int(GameState.items.get(item.id, 0)) + 1
		GameState.save_state()
		Achievements.unlock("FIRST_PURCHASE")
		SFX.purchase()
		main.refresh_topbar()
		main.show_store()
	)
	v.add_child(buy_btn)
	card.set_meta("buy_btn", buy_btn)

	return card

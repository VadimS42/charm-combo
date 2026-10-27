## StoreScreen.gd — buy consumable puzzle items with stars, equivalent to
## #screen-store in the HTML prototype.
class_name StoreScreen
extends RefCounted

const ITEMS := [
	{"id": "moves", "name": "+3 Moves", "desc": "Adds three moves to your current chapter.", "price": 12, "icon": "⏱"},
	{"id": "hammer", "name": "Hammer", "desc": "Pop one gem free, no match needed.", "price": 18, "icon": "🔨"},
	{"id": "shuffle", "name": "Shuffle", "desc": "Reshuffle the whole board.", "price": 15, "icon": "🔀"},
	{"id": "colorBomb", "name": "Starburst Starter", "desc": "Your next chapter begins with a free Starburst gem already on the board.", "price": 25, "icon": "✨"},
	{"id": "favorCharm", "name": "Favor Charm", "desc": "Your next chapter: her favorite gem shows up more often, her least favorite less.", "price": 18, "icon": "💗"},
	{"id": "heartMender", "name": "Heart Mender", "desc": "Your next chapter: far fewer cursed shards appear on the board.", "price": 20, "icon": "💚"},
]

static func build(main: Node, host: Control) -> void:
	host.add_child(UITheme.make_screen_backdrop(UITheme.ACCENT_2, UITheme.ACCENT))

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)
	host.add_child(v)

	var back := UITheme.make_ghost_button("←  Back")
	back.pressed.connect(func():
		SFX.nav()
		main.show_menu()
	)
	v.add_child(back)

	v.add_child(UITheme.heading("Item Shop", 22))
	v.add_child(UITheme.soft_label("Earn stars by clearing chapters & matching star gems.", 12))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)

	for item in ITEMS:
		grid.add_child(_card(main, item))


static func _card(main: Node, item: Dictionary) -> PanelContainer:
	var card := UITheme.panel(UITheme.SURFACE_2, 16, UITheme.LINE)
	card.custom_minimum_size = Vector2(220, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	var icon_tex := ArtAssets.store_icon(String(item.id))
	if icon_tex:
		var icon_rect := TextureRect.new()
		icon_rect.texture = icon_tex
		icon_rect.custom_minimum_size = Vector2(32, 32)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		v.add_child(icon_rect)
	else:
		var icon := Label.new()
		icon.text = String(item.icon)
		icon.add_theme_font_size_override("font_size", 28)
		v.add_child(icon)
	v.add_child(UITheme.body(String(item.name), 14))
	var d := UITheme.soft_label(String(item.desc), 11)
	d.custom_minimum_size = Vector2(190, 0)
	v.add_child(d)

	var owned := int(GameState.items.get(item.id, 0))
	var owned_lbl := UITheme.soft_label("Owned: %d" % owned, 11)
	v.add_child(owned_lbl)

	var buy_btn := UITheme.make_primary_button("Buy · %d ⭐" % int(item.price))
	buy_btn.disabled = GameState.stars < int(item.price)
	buy_btn.pressed.connect(func():
		if GameState.stars < int(item.price):
			return
		GameState.stars -= int(item.price)
		GameState.items[item.id] = int(GameState.items.get(item.id, 0)) + 1
		GameState.save_state()
		SFX.purchase()
		main.refresh_topbar()
		main.show_store()
	)
	v.add_child(buy_btn)

	return card

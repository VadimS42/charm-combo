## HowToPlay.gd — the rules, in two forms (round 25):
##   show_page(main)   every topic on one scrolling card (main menu, the
##                     chapter's "? How to Play" button, Settings)
##   tip(main, key)    one topic as a small popup, the first time it comes up
##                     in play; shown once per save (GameState.tips_seen),
##                     skippable with a click, Enter or Esc
## Both open as Main's modal (Main.open_modal()), so Esc / B close them.
class_name HowToPlay
extends RefCounted

## key, title, text, picture: "icon" names a gem (art/gems), "pic" an
## interface picture (art/ui, or "store:<item>" for art/store, round 40); the
## emoji only shows if neither file exists.
const TOPICS := [
	{"key": "swap", "title": "Swap and match", "icon": "petal", "emoji": "🔄",
		"text": "Swap two gems next to each other to line up three or more of the same kind. Matched gems pop and score points; new ones fall in from the top."},
	{"key": "goal", "title": "Reach her goal", "icon": "", "emoji": "🎯", "pic": "star",
		"text": "Each chapter has a goal and a number of moves. At first it's points; from her third chapter it's something of hers to do on the board, and in her last both. Reach it before your moves run out and the story carries on. There's no timer: take as long as you like."},
	{"key": "favorite", "title": "What she likes", "icon": "", "emoji": "💚", "pic": "heart",
		"text": "Every girl has a favourite gem and one she dislikes (on her card in the roster, and at the top of her side in a chapter). Her favourite scores double and fills the Charm ring faster; the one she dislikes scores half."},
	{"key": "gift", "title": "Her gift", "icon": "", "emoji": "🎁", "pic": "gift",
		"text": "Once you've cleared her first chapter, her card on the roster has a gift for her. Give it and her favourite gem shows up more often in all her chapters, for good."},
	{"key": "charm", "title": "Charm Burst", "icon": "", "emoji": "💗", "pic": "heart",
		"text": "Every match fills the Charm ring. In a girl's first chapter a full ring is a Charm Burst: +150 points. From her second chapter it's one use of her own power instead: its button lights up next to the ring, use it when you like. The ring fills again after."},
	{"key": "specials", "title": "Special gems", "icon": "starburst", "emoji": "✦",
		"text": "Match 4 in a row to make a Rocket, which clears its row or column. Match 5, or an L or T shape, to make a Starburst. Swap a special gem to set it off; swap two together for a Mega Blast."},
	{"key": "combos", "title": "Combos", "icon": "", "emoji": "✨", "pic": "combo",
		"text": "When falling gems make new matches on their own, that's a combo. Each link in the chain scores more than the last."},
	{"key": "cursed", "title": "Cursed shards", "icon": "cursed", "emoji": "💔",
		"text": "Dark, cracked shards cost you points when they're part of a match. The Hammer smashes one for free."},
	{"key": "items", "title": "Items", "icon": "", "emoji": "🔨", "pic": "store:hammer",
		"text": "The Time Scroll (three more moves), the Hammer (smash any one gem) and the Shuffle Wand (a new board) sit under the board. Buy them, and potions that help a whole chapter, in the Item Shop with the stars you earn."},
	{"key": "date_events", "title": "Hard: things happen on your date", "icon": "", "emoji": "⏳", "pic": "guard",
		"text": "Every few moves something happens around you: the panel on her side says what and when. It might raise what it takes to win her over, turn gems into cursed shards, cost you a move or halve your Charm ring. Matching her favourite gem holds it off a move; a Charm Burst clears it."},
	# Round 44: each girl's piece (her chapter 2 on), goal (3 and 4) and power.
	{"key": "piece_seal", "title": "Amara: sealed pages", "icon": "", "emoji": "🔏", "pic": "piece:seal",
		"text": "Some gems carry her ink seal. A sealed gem can't be picked up, but it still counts in a match you make by moving the gems beside it. The first match, blast or Hammer breaks the seal and the gem stays."},
	{"key": "goal_seals", "title": "Amara: break every seal", "icon": "", "emoji": "🔏", "pic": "piece:seal",
		"text": "To find the book, break every seal on the board. The counter under the board shows how many are done."},
	{"key": "power_lines", "title": "Amara's power: Correct Lines", "icon": "", "emoji": "🖋", "pic": "power_lines",
		"text": "Press her power button (or 4), then pick a gem: its whole row and column clear. Seals in them break."},
	{"key": "piece_tide", "title": "Marina: the tide", "icon": "", "emoji": "🌊", "pic": "piece:comb",
		"text": "In her chapters everything floats: gems rise, and new ones come up from the bottom."},
	{"key": "goal_combs", "title": "Marina: the pearl comb", "icon": "", "emoji": "🌊", "pic": "piece:comb",
		"text": "Pieces of Gran's comb start near the bottom. They can't be matched or moved: clear the gems above them and they rise. One that reaches the top row is yours."},
	{"key": "power_tide", "title": "Marina's power: High Tide", "icon": "", "emoji": "🌊", "pic": "power_tide",
		"text": "Press her power button (or 4): the two rows nearest the surface clear, and everything rises two rows."},
	{"key": "piece_moss", "title": "Opal: moss", "icon": "", "emoji": "🌿", "pic": "piece:moss",
		"text": "Moss grows under some cells. A match, blast or Hammer on the cell clears it, and some moss hides one of her lost things."},
	{"key": "goal_items", "title": "Opal: her lost collection", "icon": "", "emoji": "🌿", "pic": "piece:item_button",
		"text": "Clear the moss to find her things: buttons, marbles, keys, the glass eye. Find enough of them to win."},
	{"key": "power_absorb", "title": "Opal's power: Absorb", "icon": "", "emoji": "💧", "pic": "power_absorb",
		"text": "Press her power button (or 4), then pick a gem: every gem of that colour is cleared, and the moss under them."},
	{"key": "piece_seed", "title": "Hazel: seeds", "icon": "", "emoji": "🌱", "pic": "piece:seed",
		"text": "Seeds sit on the board and fall like gems, but can't be moved or matched. Every match right next to one grows it: seed, sprout, blossom. A blossom pops: +100 and the cells around it clear. Ember matches don't count: she dislikes ember."},
	{"key": "goal_blossoms", "title": "Hazel: grow blossoms", "icon": "", "emoji": "🌸", "pic": "piece:blossom",
		"text": "Grow enough seeds into blossoms to win. A new seed drops in every few moves."},
	{"key": "power_summer", "title": "Hazel's power: Summer", "icon": "", "emoji": "☀", "pic": "power_summer",
		"text": "Press her power button (or 4): every seed and sprout on the board grows one stage."},
	{"key": "replies", "title": "Your replies", "icon": "", "emoji": "💬", "pic": "letter",
		"text": "After each chapter you pick a reply. A warm one starts her next chapter with bonus points (two extra moves when the chapter is only her goal); a teasing one costs a few points, but she likes those too."},
	{"key": "out_of_moves", "title": "Out of moves", "icon": "", "emoji": "⏳", "pic": "scroll",
		"text": "Running out still pays you a few stars. Try again, read a Time Scroll, or visit the shop. Later chapters are hard without power-ups: short on stars, replay a chapter you've cleared from her card on the roster. Lose three times in a row and you can carry on with the story anyway."},
	{"key": "dialogue", "title": "Dialogue controls", "icon": "", "emoji": "📜", "pic": "book",
		"text": "Click, Space or Enter: next line. Hold Ctrl or press Skip: skip lines you've read. A or Auto: lines play on by themselves. L, Log or scroll up: read back. H: hide the text on full-screen pictures. Text speed is in Settings."},
]


static func topic(key: String) -> Dictionary:
	for t in TOPICS:
		if t.key == key:
			return t
	return {}


static func _picture(t: Dictionary, px: int) -> Control:
	var tex: Texture2D = ArtAssets.gem_icon(String(t.icon)) if String(t.icon) != "" else null
	var pic := String(t.get("pic", ""))
	if tex == null and pic.begins_with("store:"):
		tex = ArtAssets.store_icon(pic.substr(6))
	elif tex == null and pic.begins_with("piece:"):
		tex = ArtAssets.piece_icon(pic.substr(6))
	elif tex == null and pic != "":
		tex = ArtAssets.ui_icon(pic)
	if tex:
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = Vector2(px, px)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		return r
	var l := Label.new()
	l.text = String(t.emoji)
	l.custom_minimum_size = Vector2(px, px)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", int(px * 0.7))
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return l


static func _row(t: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.add_child(_picture(t, 40))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.add_child(UITheme.body(String(t.title), 15))
	var txt := UITheme.body(String(t.text), 13, UITheme.INK_SOFT)
	txt.custom_minimum_size = Vector2(520, 0)
	v.add_child(txt)
	h.add_child(v)
	return h


## The shade + centred card every popup here uses; returns [shade, card's VBox].
static func _shell(main: Node, width: float) -> Array:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.1, 0.05, 0.12, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.window_style())
	card.custom_minimum_size = Vector2(width, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	return [shade, v]


static func show_page(main: Node) -> void:
	var parts := _shell(main, 680)
	var shade: Control = parts[0]
	var v: VBoxContainer = parts[1]
	v.add_child(UITheme.heading("How to Play", 22))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.make_scroll_navigable(scroll)
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 16)
	scroll.add_child(list)
	for t in TOPICS:
		list.add_child(_row(t))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var close := UITheme.make_primary_button("Got it")
	close.pressed.connect(func():
		SFX.nav()
		main.close_modal()
	)
	row.add_child(close)
	main.open_modal(shade, close)


## Tips waiting for the one on screen to close.
static var _queue: Array = []


## Shows topic `key` as a one-time tip, unless it's been shown before. If
## another popup is open, it waits its turn.
static func tip(main: Node, key: String) -> void:
	if GameState.tips_seen.has(key) or topic(key).is_empty():
		return
	if main.modal_open():
		if not _queue.has(key):
			_queue.append(key)
		return
	_open_tip(main, key)


## Next queued tip, once the current popup has closed.
static func _next(main) -> void:
	# Untyped: by the time this deferred call runs, the game may be closing.
	if not is_instance_valid(main) or not (main as Node).is_inside_tree():
		return
	while not _queue.is_empty():
		var key: String = _queue.pop_front()
		if not GameState.tips_seen.has(key):
			_open_tip(main, key)
			return


## Forgets queued tips (the screen they were for has gone).
static func clear_queue() -> void:
	_queue.clear()


static func _open_tip(main: Node, key: String) -> void:
	var t := topic(key)
	GameState.tips_seen.append(key)
	GameState.save_state()
	var parts := _shell(main, 460)
	var shade: Control = parts[0]
	var v: VBoxContainer = parts[1]
	var tag := UITheme.accent_label("TIP", UITheme.ACCENT, 11)
	tag.add_theme_font_override("font", UITheme.tracked_font(2))
	v.add_child(tag)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.add_child(_picture(t, 48))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UITheme.heading(String(t.title), 18))
	var txt := UITheme.body(String(t.text), 13, UITheme.INK_SOFT)
	txt.custom_minimum_size = Vector2(340, 0)
	tv.add_child(txt)
	h.add_child(tv)
	v.add_child(h)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var all := UITheme.make_ghost_button("All rules")
	all.pressed.connect(func():
		SFX.nav()
		main.close_modal()
		show_page(main)
	)
	row.add_child(all)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	var ok := UITheme.make_primary_button("Got it")
	ok.pressed.connect(func():
		SFX.nav()
		main.close_modal()
	)
	row.add_child(ok)
	# A click anywhere outside the card closes it too.
	shade.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			main.close_modal()
	)
	# However it closes (button, click, Esc), the next queued tip follows.
	shade.tree_exited.connect(func(): _next.call_deferred(main))
	main.open_modal(shade, ok)

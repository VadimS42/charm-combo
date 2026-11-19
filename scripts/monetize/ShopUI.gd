## ShopUI.gd — the Google Play build's popups and shop sections (round 50):
## out of hearts, the "double your stars" offer after a chapter, the real-money
## offers and the free-stars video in the Shop, and the hearts pill.
## Everything else (rules, providers, saving) is Monetize.gd.
class_name ShopUI
extends RefCounted


## A popup card in Main's modal slot. Returns [shade, column].
static func _popup(main: Node, title: String, body: String) -> Array:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.1, 0.07, 0.12, 0.55)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.window_style())
	card.custom_minimum_size = Vector2(UITheme.fit_w(420.0), 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	var h := UITheme.heading(title, 20)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	if body != "":
		var b := UITheme.body(body, 13, UITheme.INK_SOFT)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(UITheme.fit_w(380.0), 0)
		v.add_child(b)
	return [shade, v]


static func _wide(b: Button) -> Button:
	b.custom_minimum_size = Vector2(0, 48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


## A one-button message (a purchase that didn't go through, and so on).
static func message(main: Node, title: String, body: String) -> void:
	var pv := _popup(main, title, body)
	var ok := _wide(UITheme.make_primary_button("OK"))
	ok.pressed.connect(func(): main.close_modal())
	(pv[1] as VBoxContainer).add_child(ok)
	main.open_modal(pv[0], ok)


## Buys a product, then redraws whatever asked (or explains why not).
static func buy(main: Node, product_id: String, after: Callable = Callable()) -> void:
	Monetize.buy(product_id, main, func(ok: bool, why: String):
		if ok:
			main.refresh_topbar()
			if after.is_valid():
				after.call()
		elif why != "":
			message(main, UITheme.t("Not bought"), why))


## The "♥ 4" / "♥ ∞" pill next to the stars.
static func hearts_text() -> String:
	if Monetize.unlimited():
		return "∞"
	return "%d" % Monetize.hearts()


# ---------------------------------------------------------------- out of hearts

static func out_of_hearts(main: Node) -> void:
	var pv := _popup(main, UITheme.t("Out of hearts"),
		UITheme.t("Losing a chapter costs a heart, and one comes back every %d minutes.") % Monetize.HEART_MINUTES)
	var v: VBoxContainer = pv[1]
	var timer_l := UITheme.body("", 15, UITheme.INK)
	timer_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(timer_l)
	var tick := func():
		if Monetize.can_play():
			main.close_modal()
			return
		timer_l.text = UITheme.t("Next heart in %s") % Monetize.clock(Monetize.next_heart_in())
	tick.call()
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(tick)
	v.add_child(t)
	var first: Control = null
	if Monetize.can_watch("heart"):
		var vid := _wide(UITheme.make_primary_button(Monetize.watch_label(UITheme.t("+1 heart"))))
		UITheme.add_icon(vid, "play")
		vid.pressed.connect(func():
			Monetize.watch("heart", func():
				Monetize.add_hearts(1)
				main.close_modal()
				main.refresh_topbar()))
		v.add_child(vid)
		first = vid
	var refill := _wide(UITheme.make_ghost_button(UITheme.t("Refill all · %d ⭐") % Monetize.REFILL_STARS))
	refill.disabled = GameState.stars < Monetize.REFILL_STARS
	refill.pressed.connect(func():
		if Monetize.refill_with_stars():
			SFX.purchase()
			main.close_modal()
			main.refresh_topbar())
	v.add_child(refill)
	if Monetize.store_available():
		var five := _wide(UITheme.make_ghost_button(UITheme.t("+5 hearts · %s") % Monetize.price("hearts_5")))
		five.pressed.connect(func(): buy(main, "hearts_5", func():
			main.close_modal()
			main.refresh_topbar()))
		v.add_child(five)
		var unl := _wide(UITheme.make_ghost_button(UITheme.t("Unlimited for 24 hours · %s") % Monetize.price("hearts_24h")))
		unl.pressed.connect(func(): buy(main, "hearts_24h", func(): main.close_modal()))
		v.add_child(unl)
		if not Monetize.has_pass():
			var sp := _wide(UITheme.make_ghost_button(UITheme.t("Story Pass: 8 hearts and free skips · %s") % Monetize.price("story_pass")))
			sp.pressed.connect(func(): buy(main, "story_pass", func(): main.close_modal()))
			v.add_child(sp)
		if first == null:
			first = unl
	var close := _wide(UITheme.make_ghost_button("Not now"))
	close.pressed.connect(func(): main.close_modal())
	v.add_child(close)
	main.open_modal(pv[0], first if first else close)


# ---------------------------------------------------------------- after a chapter

## Chapter cleared: offer to double its stars for a video, then `then`.
## (Straight on when there's nothing to double or no video to show.)
static func win_bonus(main: Node, stars: int, then: Callable) -> void:
	if stars <= 0 or not Monetize.can_watch("double"):
		then.call()
		return
	SFX.win()
	var pv := _popup(main, UITheme.t("Chapter cleared!"), "")
	var v: VBoxContainer = pv[1]
	var r := UITheme.rich_icons(UITheme.t("+%d ⭐") % stars, 22, UITheme.INK)
	v.add_child(r)
	var done := [false]
	var shade: Control = pv[0]
	# However the popup goes (a button, Back / Esc, a tap outside), the story
	# carries on, exactly once.
	var go := func():
		if done[0]:
			return
		done[0] = true
		if main._confirm_box == shade:
			main.close_modal()
		then.call_deferred()
	shade.tree_exiting.connect(go)
	var dbl := _wide(UITheme.make_primary_button(Monetize.watch_label(UITheme.t("double it to %d ⭐") % (stars * 2))))
	UITheme.add_icon(dbl, "play")
	dbl.pressed.connect(func():
		Monetize.watch("double", func():
			# The chapter's own stars are paid by StoryFlow.on_chapter_won().
			GameState.stars += stars
			GameState.save_state()
			main.refresh_topbar()
			go.call()))
	v.add_child(dbl)
	var cont := _wide(UITheme.make_ghost_button("Continue"))
	cont.pressed.connect(go)
	v.add_child(cont)
	main.open_modal(pv[0], dbl)


# ---------------------------------------------------------------- the Shop

## The Google Play build's part of the Shop: hearts, a free-stars video and
## the offers. `refresh` redraws the Shop after a purchase.
static func shop_section(main: Node, refresh: Callable) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Hearts.
	var hc := _card()
	var hv: VBoxContainer = hc[1]
	var status := UITheme.t("Unlimited hearts: %s left") % Monetize.clock(Monetize.unlimited_left()) if Monetize.unlimited() \
		else UITheme.t("Hearts: %d / %d") % [Monetize.hearts(), Monetize.max_hearts()]
	hv.add_child(UITheme.heading(status, 17))
	if not Monetize.unlimited() and Monetize.next_heart_in() > 0:
		hv.add_child(_wrap(UITheme.t("Next heart in %s") % Monetize.clock(Monetize.next_heart_in())))
	if not Monetize.unlimited() and Monetize.hearts() < Monetize.max_hearts():
		var refill := _wide(UITheme.make_primary_button(UITheme.t("Refill all · %d ⭐") % Monetize.REFILL_STARS))
		refill.disabled = GameState.stars < Monetize.REFILL_STARS
		refill.pressed.connect(func():
			if Monetize.refill_with_stars():
				SFX.purchase()
				main.refresh_topbar()
				refresh.call())
		hv.add_child(refill)
	if Monetize.store_available() and not Monetize.unlimited():
		var five := _wide(UITheme.make_ghost_button(UITheme.t("+5 hearts · %s") % Monetize.price("hearts_5")))
		five.pressed.connect(func(): buy(main, "hearts_5", refresh))
		hv.add_child(five)
	v.add_child(hc[0])
	# Free stars for a video.
	if Monetize.can_watch("stars"):
		var fc := _card(UITheme.ACCENT)
		var fv: VBoxContainer = fc[1]
		fv.add_child(UITheme.heading(UITheme.t("Free stars"), 17))
		fv.add_child(_wrap(UITheme.t("%d left today.") % Monetize.videos_left("stars")))
		var b := _wide(UITheme.make_primary_button(Monetize.watch_label(UITheme.t("+%d ⭐") % Monetize.VIDEO_STARS)))
		UITheme.add_icon(b, "play")
		b.pressed.connect(func():
			Monetize.watch("stars", func():
				GameState.stars += Monetize.VIDEO_STARS
				GameState.save_state()
				main.refresh_topbar()
				refresh.call()))
		fv.add_child(b)
		v.add_child(fc[0])
	# Offers.
	if not Monetize.store_available():
		v.add_child(_wrap(UITheme.t("Offers appear here once Google Play is reachable."), 12, Color.WHITE))
		return v
	for p in Monetize.PRODUCTS:
		var id := String(p.id)
		var owned: bool = String(p.kind) == "once" and Monetize.owns(id)
		var pc := _card(UITheme.ACCENT_2 if p.has("tag") else UITheme.LINE)
		var pvb: VBoxContainer = pc[1]
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		var nm := UITheme.heading(UITheme.t(String(p.name)), 17)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(nm)
		if p.has("tag") and not owned:
			var tag := UITheme.accent_label(UITheme.t(String(p.tag)), UITheme.ACCENT.darkened(0.2), 12)
			if tag is Label:
				(tag as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
			tag.custom_minimum_size.x = 0
			tag.size_flags_horizontal = Control.SIZE_SHRINK_END
			tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			head.add_child(tag)
		pvb.add_child(head)
		pvb.add_child(_wrap(UITheme.t(String(p.desc)), 12, UITheme.INK_SOFT))
		var b := _wide(UITheme.make_primary_button(UITheme.t("Owned") if owned else Monetize.price(id)))
		b.disabled = owned
		b.pressed.connect(func(): buy(main, id, refresh))
		pvb.add_child(b)
		v.add_child(pc[0])
	return v


static func _card(accent: Color = UITheme.LINE) -> Array:
	var p := UITheme.panel(UITheme.SURFACE, 18, accent)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return [p, v]


static func _wrap(text: String, size: int = 13, color: Color = UITheme.INK) -> Label:
	var l := UITheme.body(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

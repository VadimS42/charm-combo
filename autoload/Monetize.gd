## Monetize.gd — the free Google Play build's ads, in-app purchases, hearts and
## harder tuning (round 50). Everything here is off unless Platform.ads (the
## "ads" export feature, or `-- --ads` on PC): Steam, Epic, itch.io and the
## itch.io Android build never see any of it.
##
## Providers, picked at start-up:
##   ads      AdMob, through Poing Studios' Godot AdMob plugin (3.x for Godot
##            4.3; scripts/monetize/AdMobBridge.gd talks to it), else the
##            test stand-in in debug builds (or `-- --ads-test`), else none.
##   billing  Google Play Billing, through the GodotGooglePlayBilling plugin
##            (its "GodotGooglePlayBilling" singleton), else the test
##            stand-in in debug builds, else none.
## With "none", rewarded-video buttons hide themselves and the shop says the
## store isn't available, so a build without the plugins still plays.
## docs/GOOGLE_PLAY_SETUP.md: ad unit IDs, product IDs, the plugins, testing.
extends Node

## Hearts, purchases or prices changed: shops and the top bar redraw.
signal changed

# ---------------------------------------------------------------- tuning

## The Google Play build is rated PG-13 (Play target audience 13+): ads are
## capped at Google's "T" (teen) content rating and aren't child-directed.
## true = made for children too: child-directed, G-rated, never-personalised
## ads and no consent form (AdMobBridge._configure_requests()); Google Play's
## Families policy then applies. Every power-up can be earned with stars from
## play and free videos either way, never only with money.
const KIDS := false

## Hearts (lives), as in other mobile puzzle games: losing or leaving a started
## chapter costs one; one comes back every HEART_MINUTES up to MAX_HEARTS.
## Hearts bought or won can go over the maximum (up to HEART_CAP); they don't
## regrow past it.
const MAX_HEARTS := 5
const PASS_MAX_HEARTS := 8
const HEART_MINUTES := 30
const HEART_CAP := 99
## A full refill, paid in stars.
const REFILL_STARS := 60
## The hardest tuning: each chapter's share of its moves. The last chapter is
## out of reach without several power-ups, each one before it a step easier.
## Casual bot, % cleared (balance_bot.gd mode=girlkits, 60 runs a girl):
##   chapter          none   1 Time Scroll   2 Scrolls   2 Scrolls + both potions
##   1 (x0.75)      35-45%        72-82%       95-98%       100%
##   2 (x0.65)      12-30%        52-75%       80-95%       100%
##   3 (x0.55)       0-15%        25-48%       45-70%       88-100%
##   4 (x0.45)        0-3%         0-8%        20-28%       48-98%   (full kit 77-100%)
## (Normally, with all the moves: 59-88% with none, 95-100% with 2 Scrolls.)
const CHAPTER_MOVES := [0.75, 0.65, 0.55, 0.45]
## ...and the Item Shop's star prices go up by this much.
const PRICE_FACTOR := 1.5
## Rewarded videos: what each pays and how many a day.
const VIDEO_MOVES := 3  # once per attempt: worth one Time Scroll
const VIDEO_STARS := 15
const DAILY_CAPS := {"moves": 6, "double": 6, "stars": 5, "heart": 5, "daily": 1}
## Between-chapter ads: never before the GRACE-th chapter end, then at most
## every EVERY chapter ends and INTERSTITIAL_GAP seconds apart.
const GRACE := 3
const EVERY := 2
const INTERSTITIAL_GAP := 150.0

## AdMob ad unit IDs. These are Google's public TEST units: replace them with
## your own (AdMob > Apps > Ad units) before release, or AdMob pays nothing.
const AD_UNITS := {
	"rewarded": "ca-app-pub-3940256099942544/5224354917",
	"interstitial": "ca-app-pub-3940256099942544/1033173712",
	"banner": "ca-app-pub-3940256099942544/6300978111",
}

## Products, in shop order. The ids must match Play Console > Monetize >
## In-app products exactly. "once" = bought once and kept (acknowledged),
## "consumable" = bought any number of times (consumed). `price` is only shown
## until Google Play sends the real, local price.
const PRODUCTS := [
	{"id": "starter_pack", "kind": "once", "name": "Starter Pack", "price": "$1.99", "tag": "Best value",
		"desc": "500 stars, 3 of every item and 24 hours of unlimited hearts. Once per player.",
		"grant": {"stars": 500, "items": 3, "unlimited_h": 24}},
	{"id": "remove_ads", "kind": "once", "name": "No Ads", "price": "$3.99",
		"desc": "No ads between chapters or under the menus, ever. Reward videos become one tap: the reward, no video."},
	{"id": "story_pass", "kind": "once", "name": "Story Pass", "price": "$4.99",
		"desc": "Skip any chapter, carry on after any loss, and 8 hearts instead of 5."},
	{"id": "hearts_5", "kind": "consumable", "name": "5 Extra Hearts", "price": "$0.99",
		"desc": "5 hearts right now, on top of the ones you have.", "grant": {"hearts": 5}},
	{"id": "hearts_24h", "kind": "consumable", "name": "Unlimited Hearts", "price": "$1.99",
		"desc": "Play as much as you like for 24 hours.", "grant": {"unlimited_h": 24}},
	{"id": "item_bundle", "kind": "consumable", "name": "Item Bundle", "price": "$2.99",
		"desc": "5 of every item in the Item Shop.", "grant": {"items": 5}},
	{"id": "stars_150", "kind": "consumable", "name": "Handful of Stars", "price": "$0.99",
		"desc": "150 stars.", "grant": {"stars": 150}},
	{"id": "stars_800", "kind": "consumable", "name": "Pouch of Stars", "price": "$4.99",
		"desc": "800 stars.", "grant": {"stars": 800}},
	{"id": "stars_1800", "kind": "consumable", "name": "Chest of Stars", "price": "$9.99", "tag": "Popular",
		"desc": "1,800 stars.", "grant": {"stars": 1800}},
	{"id": "stars_5000", "kind": "consumable", "name": "Treasury of Stars", "price": "$24.99",
		"desc": "5,000 stars.", "grant": {"stars": 5000}},
]

const ADMOB_BRIDGE := "res://scripts/monetize/AdMobBridge.gd"
const BILLING_SINGLETON := "GodotGooglePlayBilling"

## "admob", "test" or "none" / "play", "test" or "none".
var ad_provider := "none"
var billing_provider := "none"
## Automated tests: test ads and purchases finish at once, no popups.
var test_instant := false

var _admob: Object = null
var _billing: Object = null
var _billing_ready := false
var _prices := {}
## purchase token -> product id, waiting for Google to confirm a consume.
var _consuming := {}
var _layer: CanvasLayer = null
var _fake_banner: Control = null
var _banner_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not active():
		return
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	var test_ok := OS.is_debug_build() or OS.get_cmdline_user_args().has("--ads-test")
	if _has_global_class("MobileAds") and ResourceLoader.exists(ADMOB_BRIDGE):
		_admob = load(ADMOB_BRIDGE).new()
		_admob.start(AD_UNITS, KIDS)
		ad_provider = "admob"
	elif test_ok:
		ad_provider = "test"
	if Engine.has_singleton(BILLING_SINGLETON):
		_start_billing(Engine.get_singleton(BILLING_SINGLETON))
		billing_provider = "play"
	elif test_ok:
		billing_provider = "test"
	print("Monetize: ads %s, billing %s" % [ad_provider, billing_provider])


func active() -> bool:
	return Platform.ads


static func _has_global_class(cls: String) -> bool:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == cls:
			return true
	return false


func _shop() -> Dictionary:
	return GameState.shop


func _now() -> float:
	return Time.get_unix_time_from_system()


func _save() -> void:
	GameState.save_state()
	changed.emit()


# ---------------------------------------------------------------- purchases owned

func owns(product_id: String) -> bool:
	return (_shop().get("owned", []) as Array).has(product_id)


func no_ads() -> bool:
	return owns("remove_ads")


func has_pass() -> bool:
	return owns("story_pass")


static func product(product_id: String) -> Dictionary:
	for p in PRODUCTS:
		if String(p.id) == product_id:
			return p
	return {}


## The price to show: Google Play's own, local one once it has answered.
func price(product_id: String) -> String:
	return String(_prices.get(product_id, product(product_id).get("price", "")))


func store_available() -> bool:
	return billing_provider == "test" or (billing_provider == "play" and _billing_ready)


# ---------------------------------------------------------------- hardest tuning

## A chapter's moves in this build (CHAPTER_MOVES).
static func moves(base: int, chapter: int = 1) -> int:
	if not Platform.ads:
		return base
	var f: float = CHAPTER_MOVES[clampi(chapter, 0, CHAPTER_MOVES.size() - 1)]
	return maxi(5, roundi(base * f))


## An Item Shop star price in this build.
static func item_price(base: int) -> int:
	if not Platform.ads:
		return base
	return roundi(base * PRICE_FACTOR)


## Story difficulty, the Skip button and "Continue the story" after losses:
## only with the Story Pass here.
func free_skips() -> bool:
	return not active() or has_pass()


# ---------------------------------------------------------------- hearts

func max_hearts() -> int:
	return PASS_MAX_HEARTS if has_pass() else MAX_HEARTS


func _regen() -> void:
	var s := _shop()
	var now := _now()
	var mx := max_hearts()
	if not s.has("hearts"):
		s.hearts = mx
		s.heart_t = now
		return
	var h := int(s.hearts)
	if h >= mx:
		s.heart_t = now
		return
	var step := HEART_MINUTES * 60.0
	var gained := floori((now - float(s.get("heart_t", now))) / step)
	if gained > 0:
		h = mini(mx, h + gained)
		s.hearts = h
		s.heart_t = now if h >= mx else float(s.heart_t) + gained * step


func hearts() -> int:
	_regen()
	return int(_shop().hearts)


func unlimited() -> bool:
	return _now() < float(_shop().get("unlimited_until", 0.0))


func unlimited_left() -> int:
	return maxi(0, int(float(_shop().get("unlimited_until", 0.0)) - _now()))


## Seconds until the next heart (0 when full).
func next_heart_in() -> int:
	_regen()
	if int(_shop().hearts) >= max_hearts():
		return 0
	return maxi(0, int(float(_shop().heart_t) + HEART_MINUTES * 60.0 - _now()))


## A story chapter (or a replay) may start.
func can_play() -> bool:
	return not active() or unlimited() or hearts() > 0


## Losing a chapter costs a heart.
func spend_heart() -> void:
	if not active() or unlimited():
		return
	_regen()
	var s := _shop()
	if int(s.hearts) >= max_hearts():
		s.heart_t = _now()  # the clock starts on the first heart lost
	s.hearts = maxi(0, int(s.hearts) - 1)
	_save()


## Adds hearts: up to the maximum, or (bought hearts) past it.
func add_hearts(n: int, past_max: bool = false) -> void:
	_regen()
	var s := _shop()
	var cap := HEART_CAP if past_max else maxi(max_hearts(), int(s.hearts))
	s.hearts = mini(cap, int(s.hearts) + n)
	if int(s.hearts) >= max_hearts():
		s.heart_t = _now()
	_save()


## Refill with stars. False if short.
func refill_with_stars() -> bool:
	if GameState.stars < REFILL_STARS:
		return false
	GameState.stars -= REFILL_STARS
	add_hearts(max_hearts())
	return true


static func clock(seconds: int) -> String:
	if seconds >= 3600:
		return "%d:%02d:%02d" % [seconds / 3600, (seconds / 60) % 60, seconds % 60]
	return "%d:%02d" % [seconds / 60, seconds % 60]


# ---------------------------------------------------------------- rewarded videos

func _today() -> Dictionary:
	var s := _shop()
	var date := Time.get_date_string_from_system()
	if typeof(s.get("today")) != TYPE_DICTIONARY or String(s.today.get("date", "")) != date:
		s.today = {"date": date}
	return s.today


func videos_left(kind: String) -> int:
	return maxi(0, int(DAILY_CAPS.get(kind, 0)) - int(_today().get(kind, 0)))


## A "watch a video for X" button may show. With No Ads it's a plain tap.
func can_watch(kind: String) -> bool:
	if not active() or videos_left(kind) <= 0:
		return false
	if no_ads():
		return true
	match ad_provider:
		"test":
			return true
		"admob":
			return _admob.rewarded_ready()
	return false


## The button's label: "Watch a video: +5 moves", or with No Ads "Free: +5 moves".
func watch_label(reward: String) -> String:
	return (UITheme.t("Free: %s") if no_ads() else UITheme.t("Watch a video: %s")) % reward


## Plays a rewarded video; on_reward runs only if it was watched to the end.
func watch(kind: String, on_reward: Callable) -> void:
	if not can_watch(kind):
		return
	var pay := func():
		var t := _today()
		t[kind] = int(t.get(kind, 0)) + 1
		_shop().video_total = int(_shop().get("video_total", 0)) + 1
		_save()
		on_reward.call()
	if no_ads():
		pay.call()
		return
	if ad_provider == "admob":
		_admob.show_rewarded(pay, func(): pass)
	else:
		_test_ad(true, pay)


# ---------------------------------------------------------------- between chapters

## Called when a chapter ends and the game moves on: maybe an ad first.
func between_chapters(then: Callable) -> void:
	if not active():
		then.call()
		return
	var s := _shop()
	s.chapter_ends = int(s.get("chapter_ends", 0)) + 1
	var due: bool = not no_ads() and int(s.chapter_ends) >= GRACE \
		and int(s.chapter_ends) - int(s.get("last_ad_end", 0)) >= EVERY \
		and _now() - float(s.get("last_ad_t", 0.0)) >= INTERSTITIAL_GAP
	if due and ad_provider == "admob" and not _admob.interstitial_ready():
		due = false
	if not due or ad_provider == "none":
		GameState.save_state()
		then.call()
		return
	s.last_ad_end = int(s.chapter_ends)
	s.last_ad_t = _now()
	GameState.save_state()
	if ad_provider == "admob":
		_admob.show_interstitial(then)
	else:
		_test_ad(false, then)


# ---------------------------------------------------------------- banner

## Banners go under the phone menus (MobileShell), never over a chapter or
## the story.
func show_banner(on: bool) -> void:
	on = on and active() and not no_ads() and ad_provider != "none"
	if on == _banner_on:
		return
	_banner_on = on
	if ad_provider == "admob":
		_admob.show_banner(on)
	elif ad_provider == "test":
		if on and _fake_banner == null:
			_fake_banner = _make_fake_banner()
			_layer.add_child(_fake_banner)
		if _fake_banner:
			_fake_banner.visible = on


## Room to leave at the bottom of the screen for the banner, in UI units.
func banner_space() -> float:
	if not active() or no_ads() or ad_provider == "none":
		return 0.0
	if ad_provider == "admob":
		var px: float = _admob.banner_height_px()
		var win := float(DisplayServer.window_get_size().y)
		var vp: float = get_viewport().get_visible_rect().size.y
		return px * vp / win if win > 0.0 and px > 0.0 else 56.0
	return 56.0


func _make_fake_banner() -> Control:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	p.offset_top = -banner_space()
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.95, 0.95, 0.9)
	p.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	l.text = "Test banner ad (320 × 50)"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	p.add_child(l)
	return p


# ---------------------------------------------------------------- privacy (AdMob UMP)

func privacy_options_required() -> bool:
	return ad_provider == "admob" and _admob.privacy_options_required()


func show_privacy_options() -> void:
	if ad_provider == "admob":
		_admob.show_privacy_options()


# ---------------------------------------------------------------- buying

## Starts a purchase. done(ok: bool, message: String) runs when it's over
## (Google Play answers later, through on_purchase_updated).
var _buy_done: Callable = Callable()

func buy(product_id: String, main: Node, done: Callable) -> void:
	var p := product(product_id)
	if p.is_empty() or (String(p.kind) == "once" and owns(product_id)):
		done.call(false, UITheme.t("You already have this."))
		return
	match billing_provider:
		"test":
			if test_instant:
				_grant(product_id)
				done.call(true, "")
				return
			main.confirm(UITheme.t("Test purchase"),
				UITheme.t("This is a test build: no money changes hands. Buy %s for %s?") % [UITheme.t(String(p.name)), price(product_id)],
				UITheme.t("Buy"), func():
					_grant(product_id)
					done.call(true, ""))
		"play":
			if not _billing_ready:
				done.call(false, UITheme.t("Google Play isn't reachable right now. Try again in a moment."))
				return
			_buy_done = done
			var r = _billing.purchase(product_id, "", "", false)
			if typeof(r) == TYPE_DICTIONARY and int(r.get("response_code", 0)) != 0:
				_buy_done = Callable()
				done.call(false, UITheme.t("The purchase couldn't start (%s).") % String(r.get("debug_message", "")))
		_:
			done.call(false, UITheme.t("The store isn't available in this build."))


## Google Play: asks again for everything bought (also runs at start-up).
func restore_purchases() -> void:
	if billing_provider == "play" and _billing_ready:
		_billing.queryPurchases("inapp", false)


func _grant(product_id: String) -> void:
	var p := product(product_id)
	if p.is_empty():
		return
	var s := _shop()
	if String(p.kind) == "once":
		var owned: Array = s.get("owned", [])
		if owned.has(product_id):
			return
		owned.append(product_id)
		s.owned = owned
	var g: Dictionary = p.get("grant", {})
	GameState.stars += int(g.get("stars", 0))
	if int(g.get("items", 0)) > 0:
		for it in StoreScreen.ITEMS:
			GameState.items[it.id] = int(GameState.items.get(it.id, 0)) + int(g.items)
	if int(g.get("hearts", 0)) > 0:
		add_hearts(int(g.hearts), true)
	if int(g.get("unlimited_h", 0)) > 0:
		s.unlimited_until = maxf(_now(), float(s.get("unlimited_until", 0.0))) + int(g.unlimited_h) * 3600.0
	if product_id == "story_pass":
		add_hearts(PASS_MAX_HEARTS)
	if product_id == "remove_ads":
		show_banner(false)
	s.spent_count = int(s.get("spent_count", 0)) + 1
	SFX.purchase()
	_save()


# ---------------------------------------------------------------- Google Play Billing

func _start_billing(plugin: Object) -> void:
	_billing = plugin
	if _billing.has_method("initPlugin"):
		_billing.initPlugin()
	_billing.connect("connected", _on_billing_connected)
	_billing.connect("disconnected", func(): _billing_ready = false)
	_billing.connect("connect_error", func(_code, _msg): _billing_ready = false)
	_billing.connect("query_product_details_response", _on_product_details)
	_billing.connect("query_purchases_response", _on_purchases)
	_billing.connect("on_purchase_updated", _on_purchase_updated)
	_billing.connect("consume_purchase_response", _on_consumed)
	_billing.connect("acknowledge_purchase_response", func(_r): pass)
	_billing.startConnection()


func _on_billing_connected() -> void:
	_billing_ready = true
	var ids := PackedStringArray()
	for p in PRODUCTS:
		ids.append(String(p.id))
	_billing.queryProductDetails(ids, "inapp")
	_billing.queryPurchases("inapp", false)


func _on_product_details(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != 0:
		return
	for d in r.get("product_details", []):
		var offers = d.get("one_time_purchase_offer_details_list")
		if typeof(offers) == TYPE_ARRAY and not offers.is_empty():
			_prices[String(d.get("product_id", ""))] = String(offers[0].get("formatted_price", ""))
	changed.emit()


func _on_purchases(r: Dictionary) -> void:
	if int(r.get("response_code", -1)) != 0:
		return
	for pur in r.get("purchases", []):
		_process_purchase(pur)


func _on_purchase_updated(r: Dictionary) -> void:
	var code := int(r.get("response_code", -1))
	if code == 0:
		for pur in r.get("purchases", []):
			_process_purchase(pur)
		return
	var done := _buy_done
	_buy_done = Callable()
	if done.is_valid():
		done.call(false, "" if code == 1 else UITheme.t("The purchase didn't go through (%s).") % String(r.get("debug_message", "")))


func _process_purchase(pur: Dictionary) -> void:
	var token := String(pur.get("purchase_token", ""))
	if int(pur.get("purchase_state", 0)) == 2:  # pending (e.g. paying cash at a shop)
		var done := _buy_done
		_buy_done = Callable()
		if done.is_valid():
			done.call(false, UITheme.t("Your purchase is pending. It arrives as soon as Google Play confirms it."))
		return
	if int(pur.get("purchase_state", 0)) != 1:
		return
	for pid in pur.get("product_ids", []):
		var p := product(String(pid))
		if p.is_empty():
			continue
		if String(p.kind) == "consumable":
			# Granted once Google confirms the consume, so it's never paid twice.
			_consuming[token] = String(pid)
			_billing.consumePurchase(token)
		else:
			_grant(String(pid))
			if not bool(pur.get("is_acknowledged", false)):
				_billing.acknowledgePurchase(token)
			_finish_buy(true)


func _on_consumed(r: Dictionary) -> void:
	var token := String(r.get("token", ""))
	if not _consuming.has(token):
		return
	var pid: String = _consuming[token]
	_consuming.erase(token)
	if int(r.get("response_code", -1)) == 0:
		_grant(pid)
		_finish_buy(true)


func _finish_buy(ok: bool) -> void:
	var done := _buy_done
	_buy_done = Callable()
	if done.is_valid():
		done.call(ok, "")


# ---------------------------------------------------------------- the test stand-in

## A full-screen pretend ad (debug builds without the AdMob plugin), so the
## whole flow can be tried on a PC or a test phone. Rewarded: 3 seconds, then
## the reward. Interstitial: closes itself after 2.
func _test_ad(rewarded: bool, then: Callable) -> void:
	if test_instant:
		then.call()
		return
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.05, 0.08, 0.97)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color.WHITE)
	shade.add_child(l)
	_layer.add_child(shade)
	var secs := 3 if rewarded else 2
	for i in range(secs, 0, -1):
		l.text = ("Test rewarded video — %d" if rewarded else "Test ad between chapters — %d") % i
		await get_tree().create_timer(1.0, true).timeout
	shade.queue_free()
	then.call()

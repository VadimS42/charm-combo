## AdMobBridge.gd — talks to Poing Studios' Godot AdMob plugin (round 50).
## Monetize.gd loads this only when the plugin is installed (its MobileAds
## class exists). The plugin's classes (MobileAds, RewardedAdLoader, AdView...)
## are looked up by name when it starts, so this file also parses and exports
## cleanly in a project without the plugin.
## Works with the plugin's 3.x releases (Godot 4.1-4.4) and 4.x (Godot 4.5+):
## the GDScript API is the same apart from the banner position and the
## privacy-options form (4.x only), handled below. docs/GOOGLE_PLAY_SETUP.md.
##
## Ads are only requested once the user has answered Google's consent
## message (UMP), as AdMob requires for players in the EEA, the UK and
## Switzerland.
extends RefCounted

var _units: Dictionary = {}
## The plugin's classes by name (their scripts).
var _c: Dictionary = {}
var _rewarded = null
var _interstitial = null
var _banner = null
var _banner_wanted := false
var _started := false
## Kid-friendly build (Monetize.KIDS): child-directed, G-rated, never
## personalised ads, and no consent form (it's never shown to children).
var _kids := true


func _cls(cls_name: String) -> Variant:
	return _c.get(cls_name)


func start(units: Dictionary, kids: bool = true) -> void:
	_units = units
	_kids = kids
	for c in ProjectSettings.get_global_class_list():
		var n := String(c.get("class", ""))
		if n in ["MobileAds", "AdRequest", "AdSize", "AdPosition", "AdView", "RewardedAdLoader",
				"RewardedAdLoadCallback", "InterstitialAdLoader", "InterstitialAdLoadCallback",
				"FullScreenContentCallback", "OnUserEarnedRewardListener", "UserMessagingPlatform",
				"ConsentInformation", "ConsentRequestParameters", "RequestConfiguration"]:
			_c[n] = load(String(c.path))
	_configure_requests()
	var ump: Variant = _cls("UserMessagingPlatform")
	var params_cls: Variant = _cls("ConsentRequestParameters")
	if ump == null or params_cls == null:
		_start_ads()
		return
	var params: Object = params_cls.new()
	# Kid-friendly build: players may be under the age of consent, so Google
	# shows them no consent form and treats their ads as non-personalised.
	params.set("tag_for_under_age_of_consent", _kids)
	var info: Object = ump.get("consent_information")
	info.call("update", params, func():
		var required: int = int(_cls("ConsentInformation").get("ConsentStatus").get("REQUIRED", 2))
		if bool(info.call("get_is_consent_form_available")) and int(info.call("get_consent_status")) == required:
			ump.call("load_consent_form", func(form):
				form.show(func(_err): _start_ads()),
				func(_err): _start_ads())
		else:
			_start_ads(),
	func(_err): _start_ads())


## Every ad request: for children, G-rated content only and child-directed
## treatment (COPPA / Google Play Families policy), so no personalised ads.
func _configure_requests() -> void:
	var rc_cls: Variant = _cls("RequestConfiguration")
	if rc_cls == null:
		return
	var rc: Object = rc_cls.new()
	if _kids:
		rc.set("tag_for_child_directed_treatment", 1)
		rc.set("tag_for_under_age_of_consent", 1)
		rc.set("max_ad_content_rating", "G")
	else:
		rc.set("max_ad_content_rating", "T")
	_cls("MobileAds").call("set_request_configuration", rc)


func _start_ads() -> void:
	if _started:
		return
	_started = true
	_cls("MobileAds").call("initialize")
	_load_rewarded()
	_load_interstitial()
	if _banner_wanted:
		show_banner(true)


func _request() -> Object:
	return _cls("AdRequest").new()


# ---------------------------------------------------------------- rewarded

func _load_rewarded() -> void:
	var cb: Object = _cls("RewardedAdLoadCallback").new()
	cb.set("on_ad_loaded", func(ad): _rewarded = ad)
	cb.set("on_ad_failed_to_load", func(_e):
		_rewarded = null
		_retry(_load_rewarded))
	_cls("RewardedAdLoader").new().call("load", String(_units.rewarded), _request(), cb)


func rewarded_ready() -> bool:
	return _rewarded != null


func show_rewarded(on_reward: Callable, on_closed: Callable) -> void:
	if _rewarded == null:
		on_closed.call()
		return
	var ad = _rewarded
	_rewarded = null
	var earned := [false]
	var fs: Object = _cls("FullScreenContentCallback").new()
	fs.set("on_ad_dismissed_full_screen_content", func():
		ad.destroy()
		_load_rewarded()
		# The reward is paid on close, back in the game, not mid-video.
		if earned[0]:
			on_reward.call()
		on_closed.call())
	fs.set("on_ad_failed_to_show_full_screen_content", func(_e):
		ad.destroy()
		_load_rewarded()
		on_closed.call())
	ad.set("full_screen_content_callback", fs)
	var listener: Object = _cls("OnUserEarnedRewardListener").new()
	listener.set("on_user_earned_reward", func(_item): earned[0] = true)
	ad.show(listener)


# ---------------------------------------------------------------- interstitial

func _load_interstitial() -> void:
	var cb: Object = _cls("InterstitialAdLoadCallback").new()
	cb.set("on_ad_loaded", func(ad): _interstitial = ad)
	cb.set("on_ad_failed_to_load", func(_e):
		_interstitial = null
		_retry(_load_interstitial))
	_cls("InterstitialAdLoader").new().call("load", String(_units.interstitial), _request(), cb)


func interstitial_ready() -> bool:
	return _interstitial != null


func show_interstitial(then: Callable) -> void:
	if _interstitial == null:
		then.call()
		return
	var ad = _interstitial
	_interstitial = null
	var fs: Object = _cls("FullScreenContentCallback").new()
	fs.set("on_ad_dismissed_full_screen_content", func():
		ad.destroy()
		_load_interstitial()
		then.call())
	fs.set("on_ad_failed_to_show_full_screen_content", func(_e):
		ad.destroy()
		_load_interstitial()
		then.call())
	ad.set("full_screen_content_callback", fs)
	ad.show()


# ---------------------------------------------------------------- banner

func show_banner(on: bool) -> void:
	_banner_wanted = on
	if not _started:
		return
	if on:
		if _banner == null:
			_banner = _cls("AdView").new(String(_units.banner), _cls("AdSize").get("BANNER"), _bottom())
			_banner.load_ad(_request())
		_banner.show()
	elif _banner != null:
		_banner.hide()


## The plugin's "bottom of the screen": a plain AdPosition.Values number in
## 3.x, an AdPosition object in 4.x.
func _bottom() -> Variant:
	var ap: Variant = _cls("AdPosition")
	var bottom: int = int(ap.get("Values").get("BOTTOM", 1))
	for m in (_cls("AdView") as Script).get_script_method_list():
		if String(m.name) == "_init" and (m.args as Array).size() >= 3 \
				and int(m.args[2].type) == TYPE_INT:
			return bottom
	return ap.new(bottom)


func banner_height_px() -> float:
	if _banner == null:
		return 0.0
	return float(_banner.get_height_in_pixels())


# ---------------------------------------------------------------- privacy
# Plugin 4.x only (3.x has no privacy options form).

func privacy_options_required() -> bool:
	var ump: Variant = _cls("UserMessagingPlatform")
	if ump == null:
		return false
	var info: Object = ump.get("consent_information")
	if info == null or not info.has_method("get_privacy_options_requirement_status"):
		return false
	return int(info.call("get_privacy_options_requirement_status")) == 2  # REQUIRED


func show_privacy_options() -> void:
	var ump: Variant = _cls("UserMessagingPlatform")
	if ump != null:
		ump.call("show_privacy_options_form", func(_err): pass)


func _retry(f: Callable) -> void:
	# No ad to show (no network, no fill): try again in a minute.
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.create_timer(60.0, true).timeout.connect(f)

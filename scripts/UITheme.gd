## UITheme.gd
##
## Small shared visual language so every screen (built entirely in code —
## see Main.gd) looks consistent without a hand-authored Theme resource.
## Colors match the original HTML prototype's CSS custom properties, so the
## Godot build reads as the same game, just re-platformed.
class_name UITheme
extends RefCounted

const BG := Color("#FBF5F1")
const SURFACE := Color("#FFFFFF")
const SURFACE_2 := Color("#FFF6F0")
const SURFACE_3 := Color("#FCEFE6")
const INK := Color("#2B2330")
const INK_SOFT := Color("#7C6B75")
const ACCENT := Color("#FF6F91")
const ACCENT_2 := Color("#FFB648")
const SPECIAL_PINK := Color("#FF4FD8")
const GOOD := Color("#4CAF7D")
const LINE := Color("#F0DEE2")
const GEM_WELL := Color("#F3E7E3")


static func panel_style(bg: Color = SURFACE_2, radius: int = 16, border: Color = LINE, border_w: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


static func button_style(bg: Color, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


## Gives a button a soft "lift" on hover (scale + a tiny upward nudge) using a
## Tween, the code-UI equivalent of the HTML prototype's
## `.primary-btn:hover{transform:translateY(-2px)}` micro-interaction. Scale
## (not position/size) is used because Control containers own position/size
## and would just fight a manual offset on their next sort pass, whereas a
## visual scale transform sits on top of layout without disturbing it.
static func _add_hover_lift(b: Button, amount: float = 1.045) -> Button:
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	var tw: Tween = null
	var hovering := false
	b.mouse_entered.connect(func():
		hovering = true
		if tw:
			tw.kill()
		tw = b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2(amount, amount), 0.14)
		tw.parallel().tween_property(b, "position:y", b.position.y - 2.0, 0.14)
	)
	b.mouse_exited.connect(func():
		hovering = false
		if tw:
			tw.kill()
		tw = b.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE, 0.14)
		tw.parallel().tween_property(b, "position:y", b.position.y + 2.0, 0.14)
	)
	# "Fun" press feedback: a quick squash-and-spring-back on click, on top
	# of the hover lift above — the code-UI equivalent of a satisfying
	# mobile-game button squish, purely a scale effect so it never disturbs
	# whatever container is actually positioning this button.
	b.button_down.connect(func():
		if tw:
			tw.kill()
		tw = b.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2(amount * 0.88, amount * 1.08), 0.06)
	)
	b.button_up.connect(func():
		if tw:
			tw.kill()
		var target := Vector2(amount, amount) if hovering else Vector2.ONE
		tw = b.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", target, 0.35)
	)
	return b


static func make_primary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.7))
	var normal := button_style(ACCENT, 18)
	normal.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	normal.shadow_size = 10
	normal.shadow_offset = Vector2(0, 5)
	var hover := button_style(ACCENT.lightened(0.08), 18)
	hover.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.45)
	hover.shadow_size = 14
	hover.shadow_offset = Vector2(0, 7)
	var pressed_style := button_style(ACCENT.darkened(0.08), 18)
	var disabled_style := button_style(ACCENT.lightened(0.35), 18)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed_style)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("disabled", disabled_style)
	return _add_hover_lift(b)


static func make_ghost_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", INK_SOFT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.set_corner_radius_all(14)
	s.border_color = LINE
	s.set_border_width_all(1)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 9
	s.content_margin_bottom = 9
	var hover := StyleBoxFlat.new()
	hover.bg_color = ACCENT
	hover.set_corner_radius_all(14)
	hover.border_color = ACCENT
	hover.set_border_width_all(1)
	hover.content_margin_left = 16
	hover.content_margin_right = 16
	hover.content_margin_top = 9
	hover.content_margin_bottom = 9
	hover.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	hover.shadow_size = 8
	hover.shadow_offset = Vector2(0, 4)
	b.add_theme_stylebox_override("normal", s)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", s)
	b.add_theme_stylebox_override("pressed", hover)
	return _add_hover_lift(b, 1.03)


static func make_card_button(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", INK)
	var normal := panel_style(SURFACE_2, 18, LINE)
	var hover := panel_style(SURFACE_2, 18, accent)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
	hover.shadow_size = 10
	hover.shadow_offset = Vector2(0, 5)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	return _add_hover_lift(b, 1.02)


static func heading(text: String, size: int = 24) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


static func body(text: String, size: int = 14, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


static func soft_label(text: String, size: int = 12) -> Label:
	return body(text, size, INK_SOFT)


static func accent_label(text: String, color: Color, size: int = 12) -> Label:
	var l := body(text, size, color)
	l.add_theme_constant_override("outline_size", 0)
	return l


static func spacer(h: float = 12.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


static func panel(bg: Color = SURFACE_2, radius: int = 16, border: Color = LINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, radius, border))
	return p


## A single soft, oversized color "blob" — a big circle at low alpha — the
## same trick as the HTML prototype's CSS `radial-gradient` corner glows
## (`--blob-1`/`--blob-2` in game.html), just built from a Panel with a huge
## corner radius instead of a gradient. Meant to sit behind a screen's real
## content, never intercept input.
static func _blob(color: Color, size: Vector2, alpha: float = 0.2) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = size
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := color
	c.a = alpha
	var style := StyleBoxFlat.new()
	style.bg_color = c
	style.set_corner_radius_all(int(max(size.x, size.y)))
	p.add_theme_stylebox_override("panel", style)
	return p


## Full-screen decorative backdrop for menu-ish screens (menu, roster,
## settings, gallery, store) that would otherwise be flat and empty — the
## Godot equivalent of the HTML prototype's `.screen-illustration` /
## page-background glow. Two off-corner blobs in the given accent colors,
## clipped to the screen and ignoring mouse input, meant to be the FIRST
## child added to a screen's host so real content draws on top of it.
static func make_screen_backdrop(color_a: Color = ACCENT, color_b: Color = ACCENT_2) -> Control:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.clip_contents = true

	var blob_a := _blob(color_a, Vector2(480, 480), 0.16)
	blob_a.position = Vector2(-190, -230)
	host.add_child(blob_a)

	var blob_b := _blob(color_b, Vector2(520, 520), 0.13)
	blob_b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	blob_b.position = Vector2(-370, -260)
	host.add_child(blob_b)

	return host


## Small rounded "Art placeholder" tag, matching the HTML prototype's
## `.art-tag` / `.scene-frame-tag` / `.cg-tag` corner labels that keep it
## honest about which visuals are stand-ins.
static func placeholder_tag(text: String = "Art placeholder") -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.4)
	style.set_corner_radius_all(999)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", style)
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color.WHITE)
	p.add_child(l)
	return p

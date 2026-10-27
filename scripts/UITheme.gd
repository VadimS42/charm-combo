## UITheme.gd
##
## Small shared visual language so every screen (built entirely in code —
## see Main.gd) looks consistent without a hand-authored Theme resource.
## Colors match the original HTML prototype's CSS custom properties, so the
## Godot build reads as the same game, just re-platformed.
class_name UITheme
extends RefCounted

## Round 19: a dusk palette — tinted rose / lavender / peach surfaces instead
## of white and cream, a plum-to-berry top bar, and gradient screen grounds.
const BG := Color("#F2E2F0")
const SURFACE := Color("#FBE6F0")      # blush: cards, dialogs
const SURFACE_2 := Color("#F1E4F8")    # lavender: rows, inner cards
const SURFACE_3 := Color("#FCE5DA")    # peach
const INK := Color("#3A2141")
const INK_SOFT := Color("#85607E")
const ACCENT := Color("#F25C8A")
const ACCENT_2 := Color("#FFB648")
const SPECIAL_PINK := Color("#FF4FD8")
const GOOD := Color("#4CAF7D")
const LINE := Color("#E5BCD4")
const GEM_WELL := Color("#F0DCEA")
## Deep colors for the top bar, dialogue box and title text, and the text
## colors that go on them.
const PLUM := Color("#3F2050")
const BERRY := Color("#B23E78")
const VIOLET := Color("#8E63D9")
const INK_ON_DARK := Color("#FBEFF6")
const INK_ON_DARK_SOFT := Color("#D9C3E2")
## Keyboard/controller focus ring color (round 16) — a deep pink that reads on
## the light cards and on the dark glass/photo screens alike.
const RING := Color("#E8336F")


static var _rings := {}


## Bundled fallback fonts (round 16) for the emoji and symbols the UI uses
## (arrows, ▶, ⚙, ⭐, 💗, the placeholder faces...). Desktop systems usually
## supply these, but a browser build can't reach system fonts at all — they
## showed as empty boxes. Small subsets of Noto Color Emoji and DejaVu Sans
## (assets/fonts/, licenses in data/font_licenses.txt), added once as
## fallbacks of the default font, so every label picks them up.
static func install_fonts() -> void:
	var base := ThemeDB.fallback_font
	if base == null or base.has_meta("cc_fonts"):
		return
	var fb: Array[Font] = []
	fb.assign(base.fallbacks)
	for path in ["res://assets/fonts/CharmComboSymbols.ttf", "res://assets/fonts/CharmComboEmoji.ttf"]:
		if ResourceLoader.exists(path):
			var f = load(path)
			if f is FontFile:
				if path.ends_with("Emoji.ttf"):
					# Color emoji are bitmaps drawn at one size; scale them to the label's.
					(f as FontFile).fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_ENABLED
				fb.append(f)
	base.fallbacks = fb
	base.set_meta("cc_fonts", true)

## The shared focus ring for controls with corner radius `radius` — drawn by
## Godot OVER a focused control's normal look. Every control uses one of these
## shared StyleBoxes, so Nav can show or hide all of them at once: visible while
## you play with keys or a gamepad, invisible while you use the mouse (see
## Nav.gd), so clicking never leaves a stuck highlight behind.
static func focus_ring(radius: int = 16) -> StyleBoxFlat:
	if _rings.has(radius):
		return _rings[radius]
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius + 4)
	s.expand_margin_left = 4
	s.expand_margin_right = 4
	s.expand_margin_top = 4
	s.expand_margin_bottom = 4
	s.anti_aliasing = true
	s.border_color = RING if Nav.nav_mode else Color(RING, 0.0)
	_rings[radius] = s
	return s


## Shows or hides every focus ring (called by Nav when the input mode flips).
static func set_rings_visible(on: bool) -> void:
	for r in _rings.values():
		(r as StyleBoxFlat).border_color = RING if on else Color(RING, 0.0)


## Lets a long ScrollContainer (Credits, Achievements) be read with keys or a
## pad: it takes focus, and up/down (arrows, D-pad, left stick), Page Up/Down
## and the right stick scroll it.
static func make_scroll_navigable(scroll: ScrollContainer) -> void:
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.gui_input.connect(func(ev: InputEvent):
		var step := 0
		if ev.is_action_pressed("ui_down") or ev.is_action_pressed("cc_scroll_down"):
			step = 90
		elif ev.is_action_pressed("ui_up") or ev.is_action_pressed("cc_scroll_up"):
			step = -90
		if step != 0:
			scroll.scroll_vertical += step
			scroll.accept_event()
	)


## A little key/button "keycap" for on-screen control hints ("A", "Esc"...).
static func keycap(text: String, dark: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.16) if dark else SURFACE
	st.border_color = Color(1, 1, 1, 0.45) if dark else INK_SOFT
	st.set_border_width_all(1)
	st.border_width_bottom = 2
	st.set_corner_radius_all(6)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color.WHITE if dark else INK)
	p.add_child(l)
	return p


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
	if radius > 0:
		s.shadow_color = Color(PLUM.r, PLUM.g, PLUM.b, 0.10)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 3)
		s.anti_aliasing = true
	return s


## A gradient texture for backgrounds and bars (`colors` spread evenly from
## `from` to `to`, both in 0-1 texture space).
static func gradient_texture(colors: Array, from: Vector2 = Vector2(0, 0), to: Vector2 = Vector2(1, 1)) -> GradientTexture2D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in range(colors.size()):
		offs.append(float(i) / float(maxi(1, colors.size() - 1)))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 128
	t.height = 128
	t.fill_from = from
	t.fill_to = to
	return t


## The top bar: plum through berry, edge to edge.
static func topbar_style() -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = gradient_texture([PLUM, Color("#6E2A6A"), BERRY], Vector2(0, 0.5), Vector2(1, 0.5))
	s.content_margin_left = 16
	s.content_margin_right = 14
	s.content_margin_top = 11
	s.content_margin_bottom = 11
	return s


## A pop-up window (confirm boxes): blush card with a rose band along the top.
static func window_style() -> StyleBoxFlat:
	var s := panel_style(SURFACE, 20, ACCENT, 2)
	s.border_width_top = 6
	s.shadow_color = Color(PLUM.r, PLUM.g, PLUM.b, 0.30)
	s.shadow_size = 18
	s.shadow_offset = Vector2(0, 6)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	return s


## The dark glass card the dialogue sits in, edged in her color.
static func dialogue_style(accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.17, 0.08, 0.21, 0.88)
	s.set_corner_radius_all(20)
	s.border_color = Color(accent.r, accent.g, accent.b, 0.85)
	s.set_border_width_all(2)
	s.border_width_top = 3
	s.shadow_color = Color(0.1, 0.03, 0.12, 0.35)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 4)
	s.anti_aliasing = true
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 14
	s.content_margin_bottom = 16
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
	# History: buttons used to map their "focus" look to the hover glow, so a
	# clicked button (which keeps focus) stayed lit — "stuck selected" — and
	# round 11 made them unfocusable to stop it. Since round 16 (keyboard and
	# controller play) they're focusable again, with the shared focus ring as
	# the focus look; the ring is invisible while the mouse is in use (Nav.gd),
	# so clicking never leaves a highlight behind.
	b.focus_mode = Control.FOCUS_ALL
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	# Shared by all four handlers (round 15): GDScript lambdas capture plain
	# locals BY VALUE, so the old `var tw` / `var hovering` reassigned inside
	# one handler were never seen by the others — tweens were never killed and
	# fought each other, a released button always dropped back to rest even
	# with the mouse still on it, and the little position nudge drifted
	# buttons that aren't inside a container. A Dictionary is shared by
	# reference. Scale only now, and nothing at all under Reduce Motion.
	var st := {"tw": null, "hover": false}
	var go := func(target: Vector2, dur: float, trans: Tween.TransitionType):
		var old = st.tw
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
		st.tw = null
		if bool(GameState.settings.get("reduce_motion", false)):
			b.scale = Vector2.ONE
			return
		var t := b.create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "scale", target, dur)
		st.tw = t
	b.mouse_entered.connect(func():
		st.hover = true
		if not b.disabled:
			go.call(Vector2(amount, amount), 0.14, Tween.TRANS_BACK)
	)
	b.mouse_exited.connect(func():
		st.hover = false
		go.call(Vector2.ONE, 0.14, Tween.TRANS_CUBIC)
	)
	# "Fun" press feedback: a quick squash-and-spring-back on click, on top
	# of the hover lift above — the code-UI equivalent of a satisfying
	# mobile-game button squish, purely a scale effect so it never disturbs
	# whatever container is actually positioning this button.
	b.button_down.connect(func():
		go.call(Vector2(amount * 0.88, amount * 1.08), 0.06, Tween.TRANS_QUAD)
	)
	b.button_up.connect(func():
		var target := Vector2(amount, amount) if (bool(st.hover) or (Nav.nav_mode and b.has_focus())) and not b.disabled else Vector2.ONE
		go.call(target, 0.35, Tween.TRANS_ELASTIC)
	)
	# With keys/a gamepad, the focused button gets the same lift as a hovered one.
	b.focus_entered.connect(func():
		if Nav.nav_mode and not b.disabled:
			go.call(Vector2(amount, amount), 0.14, Tween.TRANS_BACK)
	)
	b.focus_exited.connect(func():
		if not bool(st.hover):
			go.call(Vector2.ONE, 0.14, Tween.TRANS_CUBIC)
	)
	return b


static func make_primary_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.7))
	var normal := button_style(ACCENT, 18)
	normal.shadow_color = Color(BERRY.r, BERRY.g, BERRY.b, 0.35)
	normal.shadow_size = 10
	normal.shadow_offset = Vector2(0, 5)
	normal.border_color = BERRY
	normal.border_width_bottom = 3
	var hover := button_style(ACCENT.lightened(0.08), 18)
	hover.shadow_color = Color(BERRY.r, BERRY.g, BERRY.b, 0.45)
	hover.shadow_size = 14
	hover.shadow_offset = Vector2(0, 7)
	hover.border_color = BERRY
	hover.border_width_bottom = 3
	var pressed_style := button_style(ACCENT.darkened(0.08), 18)
	pressed_style.border_color = BERRY.darkened(0.15)
	pressed_style.border_width_top = 2
	var disabled_style := button_style(Color("#D9A7BF"), 18)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed_style)
	b.add_theme_stylebox_override("focus", focus_ring(18))
	b.add_theme_stylebox_override("disabled", disabled_style)
	return _add_hover_lift(b)


static func make_ghost_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", INK_SOFT.darkened(0.2))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", INK_SOFT.darkened(0.2))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(SURFACE.r, SURFACE.g, SURFACE.b, 0.62)
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
	b.add_theme_stylebox_override("focus", focus_ring(14))
	b.add_theme_stylebox_override("pressed", hover)
	return _add_hover_lift(b, 1.03)


static func make_card_button(text: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 14)
	# Every state gets an explicit, legible color — only "font_color" (the
	# normal state) was overridden before, so whichever button happened to
	# be focused or hovered (a dialogue choice grabs focus automatically the
	# instant it's built, and the last-clicked item button keeps focus too)
	# fell back to the engine's default theme font_focus_color/font_hover_color,
	# which is pale and nearly invisible against this button's light card
	# background. That's the "selected text not visible" bug, and it's also
	# why an enabled item button (count > 0) and a disabled one (count == 0)
	# looked identically washed-out instead of clearly different.
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", INK_SOFT)
	var normal := panel_style(SURFACE_2, 18, LINE)
	var hover := panel_style(SURFACE_2, 18, accent)
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
	hover.shadow_size = 10
	hover.shadow_offset = Vector2(0, 5)
	# No "disabled" override previously meant a disabled card button (e.g. an
	# item you have 0 of) fell back to the engine's flat default gray box —
	# the same footgun as the earlier gray-puzzle-board bug. A muted version
	# of the same card style reads clearly as "off" without looking broken.
	var disabled_style := panel_style(SURFACE_2.darkened(0.03), 18, LINE)
	disabled_style.bg_color.a = 0.55
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", focus_ring(18))
	b.add_theme_stylebox_override("disabled", disabled_style)
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

	# Round 19: a lavender -> blush -> peach ground, tinted by the screen's
	# two colors, instead of the flat cream it used to sit on.
	var ground := TextureRect.new()
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_SCALE
	ground.texture = gradient_texture([
		Color("#E6D3F5").lerp(color_a, 0.14),
		Color("#F7D5E6").lerp(color_b, 0.12),
		Color("#FDE3D1"),
	], Vector2(0, 0), Vector2(1, 1))
	host.add_child(ground)

	var blob_a := _blob(color_a, Vector2(520, 520), 0.28)
	blob_a.position = Vector2(-200, -250)
	host.add_child(blob_a)

	var blob_b := _blob(color_b, Vector2(560, 560), 0.24)
	blob_b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	blob_b.position = Vector2(-390, -280)
	host.add_child(blob_b)

	var blob_c := _blob(VIOLET, Vector2(460, 460), 0.14)
	blob_c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	blob_c.position = Vector2(-160, -230)
	host.add_child(blob_c)

	# A light scatter of soft sparkles (fixed spots, so screens don't flicker
	# when rebuilt).
	var spots := [Vector3(0.12, 0.18, 5), Vector3(0.27, 0.71, 4), Vector3(0.41, 0.09, 3),
		Vector3(0.58, 0.86, 5), Vector3(0.69, 0.22, 4), Vector3(0.83, 0.61, 6),
		Vector3(0.93, 0.13, 3), Vector3(0.07, 0.52, 3), Vector3(0.49, 0.47, 3),
		Vector3(0.76, 0.93, 4), Vector3(0.34, 0.33, 2), Vector3(0.88, 0.40, 2)]
	for sp in spots:
		var dot := _blob(Color.WHITE, Vector2(sp.z, sp.z) * 2.0, 0.55)
		dot.anchor_left = sp.x
		dot.anchor_right = sp.x
		dot.anchor_top = sp.y
		dot.anchor_bottom = sp.y
		host.add_child(dot)

	return host


## Translucent dark "glass" backdrop for text and buttons that sit directly on
## top of scene art (the roster's flying-camera backdrop) instead of an opaque
## card. Same lesson as PuzzleScreen's _glass_style() (round 9): no single
## fixed text color survives an image that's light in one spot and dark in
## another, so the text carries its own contrast with it.
static func glass_style(radius: int = 999, alpha: float = 0.5) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.09, 0.06, 0.12, alpha)
	s.set_corner_radius_all(radius)
	s.border_color = Color(1, 1, 1, 0.16)
	s.set_border_width_all(1)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


## Glass-pill counterpart to make_ghost_button() for use over scene art —
## a ghost button's transparent fill and muted text simply vanish there.
static func make_glass_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 14)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(key, Color.WHITE)
	var normal := glass_style(14)
	var hover := glass_style(14)
	hover.bg_color = ACCENT
	hover.border_color = ACCENT
	hover.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	hover.shadow_size = 8
	hover.shadow_offset = Vector2(0, 4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", focus_ring(14))
	return _add_hover_lift(b, 1.03)


## A non-interactive label on its own glass pill (see glass_style()).
static func glass_label(text: String, size: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", glass_style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	p.add_child(l)
	return p


static var _tracked_fonts := {}

## The default UI font with extra letter-spacing, for small all-caps title
## plates (roster role lines) — a little tracking is what makes tiny caps
## read as a deliberate engraved title instead of cramped shouting. Cached
## per spacing value so every card shares one FontVariation.
static func tracked_font(spacing: int = 1) -> FontVariation:
	if _tracked_fonts.has(spacing):
		return _tracked_fonts[spacing]
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.spacing_glyph = spacing
	_tracked_fonts[spacing] = fv
	return fv


## An interface icon from art/ui/<icon_name>.png at `px` square when it
## exists, else the emoji it stands in for (in `color`, which only shows where
## the system has no color-emoji font and draws a plain glyph — the default
## label color is near-white). Never intercepts the mouse.
static func icon_or_emoji(icon_name: String, emoji: String, px: int = 18, color: Color = INK) -> Control:
	var tex := ArtAssets.ui_icon(icon_name)
	if tex:
		var t := TextureRect.new()
		t.texture = tex
		t.custom_minimum_size = Vector2(px, px)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return t
	var l := Label.new()
	l.text = emoji
	l.add_theme_font_size_override("font_size", int(px * 0.8))
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Gives a button its icon from art/ui/<icon_name>.png when that exists,
## replacing its emoji-prefixed label with `plain_text` ("" = icon only).
## Without the file the button keeps its emoji text untouched.
static func apply_icon(b: Button, icon_name: String, plain_text: String = "") -> void:
	var tex := ArtAssets.ui_icon(icon_name)
	if tex == null:
		return
	b.icon = tex
	b.text = plain_text
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 20)


## A placeholder_tag() pinned inside the top-right corner of whatever it's
## added to (a full-rect, click-through wrapper). Anchoring the tag itself
## to PRESET_TOP_RIGHT without offsets leaves it hanging off the right edge,
## clipped out of sight — which is what happened on the VN screen.
static func corner_tag(text: String = "Art placeholder", margin: int = 12) -> Control:
	var box := MarginContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("margin_top", margin)
	box.add_theme_constant_override("margin_right", margin)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := placeholder_tag(text)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tag)
	box.add_child(row)
	return box


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

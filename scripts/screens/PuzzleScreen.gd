## PuzzleScreen.gd — the match-3 gameplay screen, equivalent to
## #screen-puzzle in the HTML prototype. Unlike the other screens (which are
## stateless builder functions), this one is instantiated per chapter
## because it owns a lot of mutable state across many button callbacks: the
## board array, the current selection, score/moves/charm, item counts, etc.
##
## Game rules are delegated entirely to MatchEngine (pure functions) — this
## file is "just" wiring: render the board, read clicks, call the engine,
## animate/score the result, update the HUD, and hand off to StoryFlow when
## the chapter is won or lost.
class_name PuzzleScreen
extends RefCounted

## Fallback emoji glyphs for the fantasy-themed puzzle pieces (used only
## when no real icon exists yet at res://art/gems/<name>.png — see
## ArtAssets.gd / README.md's art checklist).
## On-screen height of an idle animation (see _build_ui()). Her animation is
## full-body where the static portrait was waist-up, so rather than shrinking
## her to the 300px sidebar's width she stands taller in the lower-right,
## behind the UI, reaching a little left of the sidebar into the empty space
## beside the board.
const IDLE_ANIM_H := 575.0

## Icon tint on a gem's own-colored tile (see _render_board()).
const ICON_TINT := Color(0.6, 0.6, 0.64)
const ICON_TINT_ON_DARK := Color(1.75, 1.75, 1.75)

const GLYPH := {
	0: "🔥", 1: "🌙", 2: "🌸", 3: "💧", 4: "🌀", 5: "💎", 6: "💔",
}

## Emoji shown next to an item's label only when it has no real icon yet at
## res://art/store/<id>.png (see ArtAssets.store_icon()) — same fallback
## pattern used everywhere else real art might not exist yet.
const ITEM_GLYPH := {"moves": "⏱", "hammer": "🔨", "shuffle": "🔀"}

## Width of the sidebar column — also doubles as the width her big background
## portrait is scaled to (see _set_sprite_expr()), so bumping this makes her
## bigger too.
const SIDEBAR_W := 300.0

var main: Node
var host: Control
var ch: Dictionary
var char_id: String
var level_index: int
var level: Dictionary

var board: Array = []
var selected := Vector2i(-1, -1)
var moves_left: int = 0
var score: int = 0
## Stars already paid out for running out of moves in THIS attempt (round 17).
## A loss pays consolation_stars(); using +3 Moves and losing again only tops
## it up to the new total, so one attempt can't be paid twice.
var _consolation_paid := 0
var charm: int = 0
var busy: bool = false
var hammer_mode: bool = false

var cell_buttons: Array = []  # [r][c] -> Button
var sprite_host: Control
var score_lbl: Label
var moves_lbl: Label
var chapter_lbl: Label
var goal_bar: ProgressBar
var charm_ring: Control
var toast_layer: Control
var overlay: PanelContainer
var item_btns: Dictionary = {}
var item_count_lbls: Dictionary = {}
var _sprite_token := 0

## Her looping idle animation, when she has one (ArtAssets.idle_animation();
## round 14: Marina's swim loop), or her main sprite as a single still frame
## (round 18: Hazel on her tree) — shown in place of the static portrait, and
## in that case the sidebar's sprite_host stays empty. null otherwise.
var _anim_sprite: FrameAnimation = null
var _anim_react_tw: Tween = null

## Her main sprite brought to life (ArtAssets.live_rig(), LiveSprite.gd;
## round 20: Hazel breathing, hair swaying, blinking), which takes priority
## over both of the above. Reactions play on the rig (LiveSprite.react()).
var _live_sprite: LiveSprite = null

## Her static sprite when it's drawn full-body (ArtAssets.is_full_body()):
## too tall for the 300px sidebar, so it stands on the same layer and in the
## same spot as an idle animation would, and expression changes just swap its
## texture (see _set_sprite_expr()). null for waist-up art (which stays in the
## sidebar's sprite_host) and when she has an idle animation.
var _tall_sprite: TextureRect = null

## Set true by teardown() the instant the player navigates away (currently:
## the "← Roster" button). A match's animate-then-mutate-the-board sequence
## (_pop_out -> _score_and_clear -> collapse_and_refill -> _render_board, plus
## the settle/chain/reshuffle steps around it) spans several `await`s — a
## short but real window (well under half a second) in which the player can
## already be gone by the time execution resumes, at which point cell_buttons
## point at Button nodes clear_screen() has already freed. Checked right after
## every such await, right before anything would otherwise touch those nodes
## or call back into game-ending logic (StoryFlow.on_chapter_won can open a
## brand-new VN scene) on a screen nobody's looking at anymore.
var _torn_down := false


## A small ring "meter" for Charm, drawn directly since Godot has no built-in
## circular ProgressBar — takes the place of the old linear Charm bar buried
## in a stats card, sitting instead over the corner of her portrait. There's
## no hero-health mechanic to show alongside it (she's never in danger here,
## unlike a combat-style match-3 reference) — Charm is this game's one
## meter, so one ring is all it needs.
class CharmRing extends Control:
	var value: float = 0.0
	var max_value: float = 1.0
	var ring_color: Color = Color.WHITE
	var track_color: Color = Color(0, 0, 0, 0.18)

	func set_progress(v: float, mv: float) -> void:
		value = v
		max_value = max(1.0, mv)
		queue_redraw()

	func _draw() -> void:
		var r: float = size.x / 2.0
		if r <= 0.0:
			return
		var center := Vector2(r, r)
		var w: float = max(3.0, r * 0.22)
		draw_arc(center, r - w / 2.0, 0.0, TAU, 48, track_color, w, true)
		var frac: float = clamp(value / max_value, 0.0, 1.0)
		if frac > 0.0:
			var start := -PI / 2.0
			draw_arc(center, r - w / 2.0, start, start + TAU * frac, 48, ring_color, w, true)

## The Hammer button previously looked identical whether it was just sitting
## there or actively "armed" and waiting for you to pick a gem to pop — easy
## to lose track of, especially once the text-contrast bug (see UITheme.gd)
## made every item button look the same washed-out gray regardless of state.
## These hold the two looks so _refresh_item_button() can swap between them.
var _hammer_unarmed_style: StyleBoxFlat
var _hammer_armed_style: StyleBoxFlat

## This chapter's gem weights (baseline + difficulty ramp + any store boosts
## consumed at chapter start) — see CharacterData.compute_weights(). Held for
## the whole chapter and threaded into every board_build/collapse_and_refill
## call so a purchased Favor Charm/Heart Mender stays in effect start to
## finish, and reshuffles don't quietly reset to the easy default spread.
var weights: Array = []

## Idle-hint system (new feature, not in the original HTML prototype): after
## a few seconds without a move, nudge the player toward a real legal swap
## instead of leaving them stuck staring at the board.
const IDLE_HINT_SECONDS := 7.0
var idle_timer: Timer
var hint_tweens: Array = []
var hint_cells: Array = []


func setup(p_main: Node, p_host: Control, p_char_id: String) -> void:
	main = p_main
	host = p_host
	char_id = p_char_id
	ch = CharacterData.by_id(char_id)
	var progress := GameState.progress_for(char_id)
	level_index = int(progress.get("level_index", 0))
	level = ch.story.levels[level_index]

	moves_left = int(level.moves)
	# The conversation choice's starting-score bonus for THIS chapter. Kept in
	# her saved progress until the chapter is won (StoryFlow.on_chapter_won()),
	# so a retry, leaving mid-chapter or relaunching the game still starts with
	# the same +bonus / −penalty. It used to live only in memory and was
	# zeroed on first use, so any retry dropped it.
	score = int(progress.get("next_bonus", 0))
	charm = 0
	busy = false
	hammer_mode = false
	selected = Vector2i(-1, -1)

	# Difficulty ramp + one-chapter store boosts — computed BEFORE consuming
	# the boosts below, same order as the original HTML's startLevel() so a
	# Favor Charm/Heart Mender you just bought actually applies to the very
	# next chapter you play.
	weights = CharacterData.compute_weights(ch, level_index)
	board = MatchEngine.build_board(weights)

	# Consumed here, but the actual Starburst is seeded AFTER the no-valid-
	# move retry loop below — otherwise a retry-rebuild (rare, but possible)
	# would silently overwrite the seeded gem the player just paid for.
	var use_color_bomb: bool = int(GameState.items.get("colorBomb", 0)) > 0
	var used_favor_charm: bool = int(GameState.items.get("favorCharm", 0)) > 0
	var used_heart_mender: bool = int(GameState.items.get("heartMender", 0)) > 0
	if use_color_bomb:
		GameState.items.colorBomb = int(GameState.items.colorBomb) - 1
	if used_favor_charm:
		GameState.items.favorCharm = int(GameState.items.favorCharm) - 1
	if used_heart_mender:
		GameState.items.heartMender = int(GameState.items.heartMender) - 1
	GameState.save_state()

	# These three items are consumed silently the moment a chapter starts
	# (matching the original HTML), which gave no feedback at all that
	# buying one actually did anything — easy to mistake for a broken
	# purchase. Queue a toast per active one so the player sees confirmation
	# once the board's on screen (queued below, after _render_board()).
	var applied_msgs: Array = []
	if use_color_bomb:
		applied_msgs.append("✨ Starburst Starter active!")
	if used_favor_charm:
		applied_msgs.append("💗 Favor Charm active!")
	if used_heart_mender:
		applied_msgs.append("💚 Heart Mender active!")

	_build_ui()
	# Wait one frame so the grid has actually laid out (button .size is
	# still (0,0) the instant after add_child, before the container's first
	# sort pass) — otherwise the deal-in pop below would scale from the
	# wrong pivot on its very first frame.
	await main.get_tree().process_frame
	# Same _torn_down rule as every other await in this file: if the screen
	# was left during that one frame, don't deal a board onto freed nodes.
	if _torn_down:
		return
	# Guard against the vanishingly rare case where a freshly built board
	# happens to have no legal move at all (build_board only forbids
	# pre-existing 3-runs, it doesn't guarantee a move exists).
	if not MatchEngine.has_valid_move(board):
		board = _fresh_playable_board()
	if use_color_bomb:
		var br := 2 + randi() % 4
		var bc := 2 + randi() % 4
		board[br][bc] = MatchEngine.STARBURST
	# "Deal in" every cell on chapter start — a small, cheap bit of flair
	# (staggered pop-in, see _render_board) rather than the board just
	# snapping into existence.
	var all_cells := {}
	for r in range(MatchEngine.SIZE):
		for c in range(MatchEngine.SIZE):
			all_cells[str(r) + "," + str(c)] = true
	_render_board(all_cells)
	_update_hud()
	_reset_idle_timer()

	for msg in applied_msgs:
		_toast(String(msg))
	if score > 0:
		_toast("+%d pts — great answer!" % score)
	elif score < 0:
		_toast("%d pts — rough start..." % score)

	# Keys / a pad: the ring starts in the middle of the board. B cancels a
	# picked-up gem or an armed Hammer; the item shortcuts work anywhere.
	main.nav_setup(cell_buttons[3][3], _on_back, {
		"cc_item_moves": func(): _on_item_pressed("moves"),
		"cc_item_hammer": func(): _on_item_pressed("hammer"),
		"cc_item_shuffle": func(): _on_item_pressed("shuffle"),
	}, [["accept", "Pick up"], ["move", "Swap"], ["hammer", "Hammer"], ["shuffle", "Shuffle"],
		["moves", "+3 Moves"], ["pause", "Settings"]])


## Called before this screen is torn down by any navigation away from it —
## Main.clear_screen() calls it on every exit (round 13), and the "← Roster"
## button also calls it itself (harmless: it's idempotent). Stops the idle
## timer and kills any looping hint tween. Belt-and-suspenders alongside the
## _on_idle_timeout() fix below (hint tweens are now bound to the cell
## buttons themselves, so Godot auto-kills them when those buttons are
## freed) — calling this explicitly also stops the idle_timer from firing
## the instant before it too gets freed.
func teardown() -> void:
	_torn_down = true
	# Cancels any pending "back to neutral" expression timer (_react_sprite()),
	# which would otherwise fire on a sidebar that's already been freed.
	_sprite_token += 1
	_clear_hint()
	if idle_timer:
		idle_timer.stop()


func _accent() -> Color:
	return Color(String(ch.c))


## Reusable "glass pill" backdrop — a small rounded, translucent-dark panel —
## for any bit of text that has to sit directly on this chapter's photo
## background instead of an opaque card. A fixed text color can't survive a
## background that's light in one region and dark in another (the same
## image can have a pale sky AND a dark rock face), so instead of picking a
## color and hoping, every one of these guarantees contrast by putting its
## own backdrop behind the text. Used for the top-bar name label, the board
## legend, and each item slot's count label.
func _glass_style(radius: int = 999) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.5)
	s.set_corner_radius_all(radius)
	return s


func _glass_label(text: String, font_size: int = 12) -> PanelContainer:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	var p := PanelContainer.new()
	var style := _glass_style()
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", style)
	p.add_child(lbl)
	return p


## Same idea as _glass_label(), but for the "← Roster" nav button — a plain
## UITheme.make_ghost_button() (transparent, muted text) reads fine over an
## opaque card but disappears over this screen's photo background, so this
## gets its own always-visible dark pill instead.
func _photo_nav_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	var normal := _glass_style()
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0, 0, 0, 0.68)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", UITheme.focus_ring(14))
	return b


func _build_ui() -> void:
	# Full-bleed backdrop behind the whole screen — the puzzle "takes place"
	# somewhere, and her sprite stands over it to the side, rather than
	# everything sitting on a flat neutral panel. Uses real art the moment
	# res://art/backgrounds/<ch.bg>.png exists (see ArtAssets.gd); until
	# then falls back to the same soft accent-blob placeholder as the other
	# screens, so it never looks like a missing asset.
	var bg_tex := ArtAssets.background_for(String(ch.get("bg", "")))
	if bg_tex:
		var bg_img := TextureRect.new()
		bg_img.texture = bg_tex
		bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
		host.add_child(bg_img)
		var scrim := ColorRect.new()
		scrim.color = Color(UITheme.BG.r, UITheme.BG.g, UITheme.BG.b, 0.4)
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		host.add_child(scrim)
	else:
		var bg := ColorRect.new()
		bg.color = _accent().lightened(0.88)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		host.add_child(bg)
		host.add_child(UITheme.make_screen_backdrop(_accent(), _accent().lightened(0.4)))

	# Her looping idle animation, if she has one, on its own layer between the
	# background and the whole UI — so the board column, sidebar HUD and
	# legend all draw over it, never under it. Anchored to the same bottom-
	# right corner the sidebar portrait uses (matching `margin` below).
	var idle := ArtAssets.idle_animation(char_id)
	var rig := ArtAssets.live_rig(char_id)
	if not rig.is_empty():
		var layer := Control.new()
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(layer)
		var base_tex: Texture2D = rig.base
		var h := IDLE_ANIM_H
		var w := h * float(base_tex.get_width()) / float(maxi(1, base_tex.get_height()))
		var live := LiveSprite.new().setup(rig)
		# Flush in the corner like her still main sprite: the art runs off
		# the page at the right and bottom, and the screen edge hides the cut.
		live.anchor_left = 1.0
		live.anchor_right = 1.0
		live.anchor_top = 1.0
		live.anchor_bottom = 1.0
		live.offset_left = -w
		live.offset_top = -h
		live.offset_right = 0.0
		live.offset_bottom = 0.0
		layer.add_child(live)
		_live_sprite = live
		if String(rig.config.get("ambient", "")) == "leaves":
			var leaves := LeafDrift.new()
			leaves.anchor_left = 1.0
			leaves.anchor_right = 1.0
			leaves.anchor_top = 1.0
			leaves.anchor_bottom = 1.0
			leaves.offset_left = -w
			leaves.offset_top = -h
			var cols: Array = rig.config.get("ambient_colors", [])
			if not cols.is_empty():
				leaves.colors = cols.map(func(v): return Color(String(v)))
			layer.add_child(leaves)
	elif not idle.is_empty():
		var layer := Control.new()
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(layer)
		var first: Texture2D = idle.frames[0]
		var h := IDLE_ANIM_H
		var w := h * float(first.get_width()) / float(maxi(1, first.get_height()))
		var anim := FrameAnimation.new().setup(idle)
		anim.anchor_left = 1.0
		anim.anchor_right = 1.0
		anim.anchor_top = 1.0
		anim.anchor_bottom = 1.0
		# A main sprite (ArtAssets.main_sprite(), "still") is drawn running
		# off the page at the right and bottom (Hazel's tree), so it sits
		# flush in the corner and the screen edge hides the cut.
		var still := bool(idle.get("still", false))
		anim.offset_right = 0.0 if still else -16.0
		anim.offset_bottom = 0.0 if still else -18.0
		anim.offset_left = anim.offset_right - w
		anim.offset_top = anim.offset_bottom - h
		# Reactions (see _anim_react()) scale from her base, like a hop.
		anim.pivot_offset = Vector2(w * 0.5, h)
		layer.add_child(anim)
		_anim_sprite = anim
	else:
		# No animation, but full-body sprites: same layer, same spot, same
		# height — the sidebar is far too narrow to show a head-to-toe figure.
		var neutral_tex := ArtAssets.character_portrait(char_id, "neutral")
		if ArtAssets.is_full_body(neutral_tex):
			var layer := Control.new()
			layer.set_anchors_preset(Control.PRESET_FULL_RECT)
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			host.add_child(layer)
			var t := TextureRect.new()
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			t.anchor_left = 1.0
			t.anchor_right = 1.0
			t.anchor_top = 1.0
			t.anchor_bottom = 1.0
			t.offset_right = -16.0
			t.offset_bottom = -18.0
			layer.add_child(t)
			_tall_sprite = t
			_fit_tall_sprite(neutral_tex)

	# A MarginContainer around the whole screen so nothing — especially the
	# board's bottom legend — ever sits flush against the window's edge.
	# Without this, board_area below expands to fill all remaining vertical
	# space and pushes the legend down to wherever that happens to end, i.e.
	# right against the very last pixel row of the window with zero
	# clearance — which is what read as "can't read the text at the bottom."
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 18)
	host.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	# A plain ghost button (transparent, muted-gray text) reads fine over an
	# opaque card, but this row sits directly on top of the chapter's photo
	# background — which can be light in one spot and dark in another within
	# the SAME image (see the mermaid cove screenshot: pale cliffside behind
	# the button, dark rock elsewhere). No single text/border color survives
	# that, so this — like the moves badge and the legend/item-count labels
	# below — gets a small translucent dark "glass" backdrop instead, which
	# guarantees contrast no matter what's behind it.
	var back := _photo_nav_button("←  Roster")
	back.pressed.connect(func():
		SFX.nav()
		# Stop the idle-hint countdown and kill any looping hint tween BEFORE
		# screen_host's children (including the cell buttons a hint tween may
		# still be animating) get freed by clear_screen() — leaving that
		# behind was causing a freeze when leaving mid-hint (see teardown()).
		teardown()
		GameState.save_state()
		main.show_roster()
	)
	top_row.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	top_row.add_child(_glass_label(String(ch.name), 12))
	root.add_child(top_row)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(layout)

	# ---- board column ----
	var board_col := VBoxContainer.new()
	board_col.add_theme_constant_override("separation", 10)
	board_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(board_col)

	# ---- top bar: moves badge + score/goal bar ----
	# A normal row living in board_col's own flow, ABOVE board_area — this
	# used to float as an absolute overlay anchored INSIDE board_area, on top
	# of the CenterContainer-centered board panel, with only a few px of
	# built-in clearance from the panel's own top edge. That's exactly what
	# read as "points overlap with puzzle": depending on window size the
	# overlay could land right on — or inside — the panel. Giving it its own
	# dedicated row means it always has its own vertical space and can never
	# overlap the board again, regardless of board or window size.
	var board_top_row := HBoxContainer.new()
	board_top_row.add_theme_constant_override("separation", 10)
	board_col.add_child(board_top_row)

	var moves_badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0, 0, 0, 0.55)
	badge_style.set_corner_radius_all(999)
	badge_style.content_margin_left = 12
	badge_style.content_margin_right = 12
	badge_style.content_margin_top = 5
	badge_style.content_margin_bottom = 5
	moves_badge.add_theme_stylebox_override("panel", badge_style)
	moves_badge.tooltip_text = "Moves left this chapter"
	var moves_row := HBoxContainer.new()
	moves_row.add_theme_constant_override("separation", 5)
	moves_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# art/ui/hourglass.png when it exists, else the ⏳ emoji.
	moves_row.add_child(UITheme.icon_or_emoji("hourglass", "⏳", 16, Color.WHITE))
	moves_lbl = Label.new()
	moves_lbl.add_theme_font_size_override("font_size", 13)
	moves_lbl.add_theme_color_override("font_color", Color.WHITE)
	moves_row.add_child(moves_lbl)
	moves_badge.add_child(moves_row)
	board_top_row.add_child(moves_badge)

	var score_wrap := Control.new()
	score_wrap.custom_minimum_size = Vector2(0, 26)
	score_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_bar = ProgressBar.new()
	goal_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	goal_bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.35)
	track.set_corner_radius_all(999)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UITheme.ACCENT_2
	fill.set_corner_radius_all(999)
	goal_bar.add_theme_stylebox_override("background", track)
	goal_bar.add_theme_stylebox_override("fill", fill)
	score_wrap.add_child(goal_bar)
	score_lbl = Label.new()
	score_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 12)
	score_lbl.add_theme_color_override("font_color", Color.WHITE)
	score_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	score_lbl.add_theme_constant_override("outline_size", 3)
	score_wrap.add_child(score_lbl)
	board_top_row.add_child(score_wrap)

	var board_area := Control.new()
	board_area.custom_minimum_size = Vector2(0, 480)
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_col.add_child(board_area)

	var board_center := CenterContainer.new()
	board_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_area.add_child(board_center)

	# ---- thematic frame behind the board ----
	# CenterContainer centers EACH of its children independently around the
	# same shared center point (unlike PanelContainer, which only lays out
	# ONE direct child sanely — see the note elsewhere in this codebase), so a
	# frame Control bigger than the board, added BEFORE board_panel, sits
	# centered directly behind it — visible only in the margin around/between
	# the panel's edges and its own. Real per-character art the moment
	# res://art/frames/<char_id>.png exists; until then, a plain bordered
	# placeholder so it reads as an honest stand-in rather than a missing
	# asset (same pattern used for portraits/backgrounds elsewhere).
	var cell_size := 48.0
	var cell_gap := 4.0
	var cells_span: float = MatchEngine.SIZE * cell_size + (MatchEngine.SIZE - 1) * cell_gap
	# +28/+24 accounts for board_panel's own left+right / top+bottom content
	# margin (UITheme.panel_style()'s defaults: 14px sides, 12px top/bottom).
	var board_w: float = cells_span + 28.0
	var board_h: float = cells_span + 24.0
	var frame_margin := 36.0
	var frame_tex := ArtAssets.puzzle_frame(char_id)
	if frame_tex:
		var frame_img := TextureRect.new()
		frame_img.texture = frame_tex
		frame_img.custom_minimum_size = Vector2(board_w + frame_margin * 2.0, board_h + frame_margin * 2.0)
		frame_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board_center.add_child(frame_img)
	else:
		var frame_wrap := Control.new()
		frame_wrap.custom_minimum_size = Vector2(board_w + frame_margin * 2.0, board_h + frame_margin * 2.0)
		frame_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board_center.add_child(frame_wrap)

		var frame_border := PanelContainer.new()
		frame_border.set_anchors_preset(Control.PRESET_FULL_RECT)
		frame_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(0, 0, 0, 0)
		frame_style.border_color = _accent()
		frame_style.set_border_width_all(4)
		frame_style.set_corner_radius_all(28)
		frame_border.add_theme_stylebox_override("panel", frame_style)
		frame_wrap.add_child(frame_border)

		var frame_tag := UITheme.placeholder_tag("Frame placeholder")
		frame_tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		frame_wrap.add_child(frame_tag)

	# The board's own well used to be an opaque warm-white fill — clean, but
	# it hid the chapter's own photo background completely behind a solid
	# panel. Fully transparent now (fill and border both alpha 0) so her
	# background shows through the gaps between and around the gem cells,
	# with the frame above providing the only visible boundary.
	var board_panel_style := UITheme.panel_style(UITheme.GEM_WELL, 16, UITheme.LINE)
	board_panel_style.bg_color.a = 0.0
	board_panel_style.border_color.a = 0.0
	var board_panel := PanelContainer.new()
	board_panel.add_theme_stylebox_override("panel", board_panel_style)
	board_center.add_child(board_panel)
	var grid := GridContainer.new()
	grid.columns = MatchEngine.SIZE
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	board_panel.add_child(grid)

	cell_buttons = []
	for r in range(MatchEngine.SIZE):
		var row: Array = []
		for c in range(MatchEngine.SIZE):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(48, 48)
			btn.add_theme_font_size_override("font_size", 22)
			# Focusable for keyboard/controller play (round 16): the ring moves
			# over the gems, A/Enter picks one up, a direction then swaps it
			# (_on_cell_gui_input). Pressing a cell while the chapter is over or
			# behind an overlay is refused in _on_cell_pressed().
			btn.focus_mode = Control.FOCUS_ALL
			btn.add_theme_stylebox_override("focus", UITheme.focus_ring(13))
			btn.pressed.connect(_on_cell_pressed.bind(r, c))
			btn.gui_input.connect(_on_cell_gui_input.bind(r, c))
			grid.add_child(btn)
			row.append(btn)
		cell_buttons.append(row)

	toast_layer = Control.new()
	toast_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.add_child(toast_layer)

	# ---- item slots: a row of round icon buttons under the board, instead
	# of a vertical list of wide rectangular buttons in the sidebar ----
	var item_row := HBoxContainer.new()
	item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	item_row.add_theme_constant_override("separation", 20)
	item_row.add_child(_item_slot("moves"))
	item_row.add_child(_item_slot("hammer"))
	item_row.add_child(_item_slot("shuffle"))
	board_col.add_child(item_row)

	# On a glass bar rather than bare over the background for the same
	# reason as the top-bar name label above — a muted-gray soft_label reads
	# fine on an opaque card, but was unreadable wherever this photo
	# background happened to be light-toned too.
	var legend := UITheme.body(
		"Match 4 → Rocket · Match 5 / L·T shape → Starburst · swap a special to trigger it · cursed shards cost points (a Hammer clears one free) · 💗 Charm ring fills as you match gems (her favorite fills it fastest) — max it out for a +150 Charm Burst!",
		11, Color(1, 1, 1, 0.92))
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var legend_bar := PanelContainer.new()
	var legend_style := _glass_style(12)
	legend_style.content_margin_left = 14
	legend_style.content_margin_right = 14
	legend_style.content_margin_top = 6
	legend_style.content_margin_bottom = 6
	legend_bar.add_theme_stylebox_override("panel", legend_style)
	legend_bar.add_child(legend)
	board_col.add_child(legend_bar)

	# ---- sidebar ----
	# Her portrait used to sit boxed up in its own small ~170px-tall card
	# above the HUD. Per feedback, she now stands large behind the whole
	# sidebar instead: sidebar_root layers sprite_host (added first, so it
	# renders behind) with the actual HUD/items VBox on top of it. Since the
	# portrait art is transparent around her, nothing needs an opaque panel
	# behind it — the puzzle's own backdrop just shows through the gaps.
	var sidebar_root := Control.new()
	sidebar_root.custom_minimum_size = Vector2(SIDEBAR_W, 0)
	sidebar_root.clip_contents = true
	layout.add_child(sidebar_root)

	sprite_host = Control.new()
	sprite_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sidebar_root.add_child(sprite_host)
	_set_sprite_expr("neutral")

	var sidebar := VBoxContainer.new()
	sidebar.set_anchors_preset(Control.PRESET_FULL_RECT)
	sidebar.add_theme_constant_override("separation", 10)
	sidebar_root.add_child(sidebar)

	var name_card := UITheme.panel(UITheme.SURFACE_2, 14, UITheme.LINE)
	var name_v := VBoxContainer.new()
	name_v.add_child(UITheme.body(String(ch.name), 14))
	chapter_lbl = UITheme.accent_label("", _accent(), 11)
	name_v.add_child(chapter_lbl)
	name_card.add_child(name_v)
	sidebar.add_child(name_card)

	# Charm ring, pinned to the bottom-left corner of the sidebar so it reads
	# as sitting over her portrait's corner — moves/score live on the board
	# overlay above and items are the row of slots under the board, so this
	# is the only thing left in the sidebar besides her name.
	var charm_ring_inst := CharmRing.new()
	charm_ring_inst.custom_minimum_size = Vector2(58, 58)
	charm_ring_inst.ring_color = UITheme.SPECIAL_PINK
	charm_ring_inst.anchor_left = 0.0
	charm_ring_inst.anchor_top = 1.0
	charm_ring_inst.anchor_right = 0.0
	charm_ring_inst.anchor_bottom = 1.0
	charm_ring_inst.offset_left = 14.0
	charm_ring_inst.offset_right = 14.0 + 58.0
	charm_ring_inst.offset_top = -72.0
	charm_ring_inst.offset_bottom = -14.0
	sidebar_root.add_child(charm_ring_inst)
	charm_ring = charm_ring_inst

	charm_ring_inst.tooltip_text = "Charm — fills as you match (her favorite gem fastest). Full = +150 Charm Burst."
	# art/ui/heart.png in the middle of the ring when it exists, else 💗.
	var charm_icon_center := CenterContainer.new()
	charm_icon_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	charm_icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	charm_icon_center.add_child(UITheme.icon_or_emoji("heart", "💗", 26))
	charm_ring_inst.add_child(charm_icon_center)

	overlay = PanelContainer.new()
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_stylebox_override("panel", UITheme.panel_style(Color(UITheme.BG, 0.92), 16, UITheme.LINE))
	board_area.add_child(overlay)

	idle_timer = Timer.new()
	idle_timer.wait_time = IDLE_HINT_SECONDS
	idle_timer.one_shot = true
	idle_timer.timeout.connect(_on_idle_timeout)
	host.add_child(idle_timer)


## A round icon "slot" (icon button + a small count label underneath),
## arranged as a row under the board — replaces the old vertical list of
## wide rectangular buttons in the sidebar with something closer to the
## row-of-round-slots consumables strip a lot of match-3 UIs use (including
## the reference screenshot this round's HUD direction is drawing from).
func _item_slot(item_id: String) -> Control:
	var wrap := VBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 2)

	var b := Button.new()
	b.custom_minimum_size = Vector2(56, 56)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.expand_icon = true
	# Centering the icon explicitly matters here: Button's default alignment
	# is LEFT, and with no text to share the row with, an unset alignment
	# left the icon sitting off to one side instead of centered in the
	# circle — which is what read as "icons off-center."
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))

	# A light neutral "coin face" with a colored ring, rather than filling
	# the whole circle with the character's accent — the accent color often
	# has similar tone/brightness to the icon art itself (e.g. mermaid's
	# teal against a greenish net icon), which is part of why the icons
	# were "hard to see." A near-white face keeps every icon's own colors
	# reading clearly regardless of which character's accent it's on.
	var normal := UITheme.button_style(UITheme.SURFACE, 999)
	normal.border_color = _accent()
	normal.set_border_width_all(3)
	normal.content_margin_left = 0
	normal.content_margin_right = 0
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0
	normal.shadow_color = Color(0, 0, 0, 0.2)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 3)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = UITheme.SURFACE_2
	hover.border_color = _accent().darkened(0.1)
	# A disabled item (count 0) needs to look OFF, not just re-use the
	# engine's flat gray default — same footgun documented in UITheme.gd's
	# make_card_button() (the round-6 "everything looks the same" bug).
	var disabled_style: StyleBoxFlat = normal.duplicate()
	disabled_style.bg_color = UITheme.SURFACE.darkened(0.06)
	disabled_style.border_color = UITheme.LINE
	disabled_style.shadow_size = 0

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", UITheme.focus_ring(28))
	b.add_theme_stylebox_override("disabled", disabled_style)

	var icon_tex := ArtAssets.store_icon(item_id)
	if icon_tex:
		b.icon = icon_tex
		b.add_theme_constant_override("icon_max_width", 34)
	else:
		b.add_theme_color_override("font_color", _accent())
		b.add_theme_color_override("font_hover_color", _accent())
		b.add_theme_color_override("font_focus_color", _accent())
		b.add_theme_color_override("font_pressed_color", _accent())
		b.text = ITEM_GLYPH.get(item_id, "?")

	b.pressed.connect(_on_item_pressed.bind(item_id))
	item_btns[item_id] = b

	if item_id == "hammer":
		_hammer_unarmed_style = normal
		var armed: StyleBoxFlat = normal.duplicate()
		armed.border_color = UITheme.SPECIAL_PINK
		armed.set_border_width_all(3)
		armed.shadow_color = Color(UITheme.SPECIAL_PINK.r, UITheme.SPECIAL_PINK.g, UITheme.SPECIAL_PINK.b, 0.5)
		armed.shadow_size = 10
		_hammer_armed_style = armed

	wrap.add_child(b)

	# On its own tiny glass pill, not just outlined text directly on the
	# background — a light outline around already-light text doesn't help
	# against the lighter patches of a photo background (that's why these
	# counts were unreadable over the sandy dock), so it gets the same
	# always-visible dark backdrop as the top-bar name and the legend.
	var count_lbl := Label.new()
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.add_theme_color_override("font_color", Color.WHITE)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var count_wrap := PanelContainer.new()
	var count_style := _glass_style()
	count_style.content_margin_left = 8
	count_style.content_margin_right = 8
	count_style.content_margin_top = 2
	count_style.content_margin_bottom = 2
	count_wrap.add_theme_stylebox_override("panel", count_style)
	count_wrap.add_child(count_lbl)
	wrap.add_child(count_wrap)
	item_count_lbls[item_id] = count_lbl

	_refresh_item_button(item_id)
	return wrap


func _refresh_item_button(item_id: String) -> void:
	var count := int(GameState.items.get(item_id, 0))
	var b: Button = item_btns[item_id]
	var count_lbl: Label = item_count_lbls.get(item_id)
	if item_id == "hammer" and hammer_mode:
		if count_lbl:
			count_lbl.text = "Tap a gem!"
		if _hammer_armed_style:
			b.add_theme_stylebox_override("normal", _hammer_armed_style)
	else:
		if count_lbl:
			count_lbl.text = "×%d" % count
		if item_id == "hammer" and _hammer_unarmed_style:
			b.add_theme_stylebox_override("normal", _hammer_unarmed_style)
	# Hammer and Shuffle act on the board, so they're off while the
	# Out-of-Moves overlay covers it (they sit outside it and stayed clickable,
	# spending items on a board you can't play). +3 Moves is the way out of
	# that overlay, so it stays available.
	var board_locked: bool = overlay != null and overlay.visible and item_id != "moves"
	b.disabled = count <= 0 or busy or board_locked
	# An armed Hammer stays pressable so a second press can put it away.
	if item_id == "hammer" and hammer_mode:
		b.disabled = false


func _refresh_all_items() -> void:
	for item_id in item_btns.keys():
		_refresh_item_button(item_id)


func _on_item_pressed(item_id: String) -> void:
	# Pressing an armed Hammer again puts it away. It hasn't been charged yet
	# (that happens when it pops a gem), so there's nothing to refund.
	if item_id == "hammer" and hammer_mode:
		hammer_mode = false
		_refresh_item_button("hammer")
		_reset_idle_timer()
		return
	var count := int(GameState.items.get(item_id, 0))
	if count <= 0 or busy or _torn_down:
		return
	if overlay != null and overlay.visible and item_id != "moves":
		return
	# Picking a different item while the Hammer is armed simply disarms it
	# (again: not charged until used).
	if hammer_mode and item_id != "hammer":
		hammer_mode = false
		_refresh_item_button("hammer")
	match item_id:
		"moves":
			GameState.items.moves = count - 1
			moves_left += 3
			var was_locked := overlay.visible
			overlay.visible = false
			_update_hud()
			if was_locked and Nav.nav_mode:
				cell_buttons[3][3].grab_focus.call_deferred()
		"hammer":
			hammer_mode = true
			selected = Vector2i(-1, -1)
			_render_board()
			_toast("Pick a gem to pop.")
		"shuffle":
			GameState.items.shuffle = count - 1
			board = _fresh_playable_board()
			_render_board()
	GameState.save_state()
	_refresh_all_items()
	_reset_idle_timer()


## A new board for the current chapter that is guaranteed to have a legal
## move (build_board() only forbids ready-made matches) — used by Shuffle and
## the free no-move reshuffle, so neither can hand back another dead board.
func _fresh_playable_board() -> Array:
	var b: Array = MatchEngine.build_board(weights)
	for i in range(20):
		if MatchEngine.has_valid_move(b):
			break
		b = MatchEngine.build_board(weights)
	return b


## Swaps the sidebar sprite to a real portrait the moment
## res://art/characters/<char_id>/<expr>.png exists; until then, the same
## big reactive emoji placeholder as before.
func _set_sprite_expr(expr: String) -> void:
	if sprite_host == null or _torn_down:
		return
	# Her idle animation replaces the portrait entirely (reactions play on the
	# animation instead — see _react_sprite()); swapping in a static
	# waist-up expression portrait over a full-body animation would jump.
	if _anim_sprite != null or _live_sprite != null:
		return
	# Full-body art: same figure, same spot, just a different face.
	if _tall_sprite != null:
		var tall_tex := ArtAssets.character_portrait(char_id, expr)
		if tall_tex:
			_fit_tall_sprite(tall_tex)
		return
	for c in sprite_host.get_children():
		c.queue_free()
	var tex := ArtAssets.character_portrait(char_id, expr)
	if tex:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Pin her to the BOTTOM of the sidebar, sized from the actual
		# texture's own aspect ratio (not hardcoded to the 800x1000 spec, so
		# a differently-shaped image still lands right) — she reads as a
		# large standing figure behind the HUD, feet near the bottom edge,
		# instead of a small boxed portrait floating in the middle of a card.
		var aspect: float = float(tex.get_height()) / float(max(1, tex.get_width()))
		var h: float = SIDEBAR_W * aspect
		t.anchor_left = 0.0
		t.anchor_right = 1.0
		t.anchor_top = 1.0
		t.anchor_bottom = 1.0
		t.offset_left = 0.0
		t.offset_right = 0.0
		t.offset_top = -h
		t.offset_bottom = 0.0
		sprite_host.add_child(t)
	else:
		# No real art for this character yet (Amara and Opal, as of round
		# 18) — same emoji placeholder as before, just sized up a
		# little since it now sits in a much larger background area instead
		# of a small 170px box.
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lbl := Label.new()
		lbl.text = VNScreen.EXPR_ICON.get(expr, "🙂")
		lbl.add_theme_font_size_override("font_size", 120)
		center.add_child(lbl)
		sprite_host.add_child(center)


## Puts `tex` on the full-body sprite, IDLE_ANIM_H tall and as wide as its own
## aspect says, standing in the bottom-right corner (offsets set in _build_ui).
func _fit_tall_sprite(tex: Texture2D) -> void:
	if _tall_sprite == null or tex == null:
		return
	var h := IDLE_ANIM_H
	var w := h * float(tex.get_width()) / float(maxi(1, tex.get_height()))
	_tall_sprite.texture = tex
	_tall_sprite.offset_left = _tall_sprite.offset_right - w
	_tall_sprite.offset_top = _tall_sprite.offset_bottom - h


## Returns a real gem icon the moment res://art/gems/<name>.png exists (see
## ArtAssets.gd); null otherwise, so callers fall back to the emoji glyph.
func _icon_for(t: int) -> Texture2D:
	var icon_name: String
	if t == MatchEngine.ROCKET_H:
		icon_name = "rocket_h"
	elif t == MatchEngine.ROCKET_V:
		icon_name = "rocket_v"
	elif t == MatchEngine.STARBURST:
		icon_name = "starburst"
	else:
		icon_name = CharacterData.gem_name(t)
	return ArtAssets.gem_icon(icon_name)


func _glyph(t: int) -> String:
	if t == MatchEngine.ROCKET_H:
		return "➡"
	if t == MatchEngine.ROCKET_V:
		return "⬆"
	if t == MatchEngine.STARBURST:
		return "✨"
	return GLYPH.get(t, "?")


func _color_for(t: int) -> Color:
	if t == MatchEngine.ROCKET_H or t == MatchEngine.ROCKET_V:
		return Color("#5B7CFA")
	if t == MatchEngine.STARBURST:
		return Color("#FF4FD8")
	return CharacterData.gem_color(t)


## pop_cells (Dictionary<"r,c" -> true>) marks cells that just changed —
## newly dropped-in gems after a match, or the whole board on chapter start
## — and get a staggered scale pop-in. Cells not in pop_cells are re-styled
## in place with no animation, so an ordinary swap doesn't make the entire
## board flicker.
func _render_board(pop_cells: Dictionary = {}) -> void:
	if _torn_down:
		return
	for r in range(MatchEngine.SIZE):
		for c in range(MatchEngine.SIZE):
			var t: int = board[r][c]
			var btn: Button = cell_buttons[r][c]
			var icon_tex := _icon_for(t)
			if icon_tex:
				btn.icon = icon_tex
				btn.expand_icon = true
				btn.text = ""
				# Each gem icon is a flat silhouette in exactly its gem's color
				# — the same color as the tile it sits on — so the shapes were
				# completely invisible and the board read as plain colored
				# squares. Tinting the icon a shade darker (lighter, on the
				# dark cursed tile) shows the shape tone-on-tone, so gems can
				# be told apart by shape, not only by similar hues (pearl vs.
				# crystal, moonstone vs. rune).
				var tint := ICON_TINT_ON_DARK if t == MatchEngine.BROKEN_IDX else ICON_TINT
				for key in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
					btn.add_theme_color_override(key, tint)
			else:
				btn.icon = null
				btn.text = _glyph(t)
			var bg := _color_for(t)
			var is_sel := selected == Vector2i(r, c)
			var radius := 22 if is_sel else 13
			var style := UITheme.button_style(bg, radius)
			# button_style()'s padding (20px sides, 12px top/bottom) is sized for
			# text buttons; on a ~50px gem tile it left the expanded icon about
			# 8px wide. Tight padding lets the gem's shape fill its tile.
			style.content_margin_left = 8
			style.content_margin_right = 8
			style.content_margin_top = 8
			style.content_margin_bottom = 8
			style.shadow_color = Color(0, 0, 0, 0.18)
			style.shadow_size = 4
			style.shadow_offset = Vector2(0, 2)
			if is_sel:
				style.border_color = UITheme.INK
				style.set_border_width_all(3)
				style.shadow_color = Color(bg.r, bg.g, bg.b, 0.5)
				style.shadow_size = 8
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover", style)
			btn.add_theme_stylebox_override("pressed", style)
			# NOTE: deliberately NOT using Button.disabled to lock the board
			# while busy — that pulls in the theme's default "disabled"
			# stylebox (a flat gray), which we never override, so the whole
			# board would flash gray during every match and could get stuck
			# that way if a code path forgot to flip it back. Input is
			# already gated by the `busy` checks in _on_cell_pressed(), so
			# disabling the buttons visually is both unnecessary and risky.
			btn.disabled = false
			btn.add_theme_color_override("font_color", Color.WHITE)

	if pop_cells.is_empty() or GameState.settings.get("reduce_motion", false):
		return
	for key in pop_cells.keys():
		var parts: PackedStringArray = String(key).split(",")
		var r := int(parts[0])
		var c := int(parts[1])
		if r < 0 or r >= MatchEngine.SIZE or c < 0 or c >= MatchEngine.SIZE:
			continue
		var btn: Button = cell_buttons[r][c]
		btn.pivot_offset = btn.size / 2.0
		btn.scale = Vector2(0.1, 0.1)
		var tw := btn.create_tween()
		tw.tween_interval(randf() * 0.06)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A quick, satisfying scale-punch on one cell — used for "you just swapped
## these" tactile feedback and for a special gem's detonation flash. Scale
## (not position) is animated so it never fights the GridContainer's layout.
func _bounce(r: int, c: int, punch: float = 1.22) -> void:
	if GameState.settings.get("reduce_motion", false):
		return
	if r < 0 or r >= MatchEngine.SIZE or c < 0 or c >= MatchEngine.SIZE:
		return
	var btn: Button = cell_buttons[r][c]
	btn.pivot_offset = btn.size / 2.0
	var tw := btn.create_tween()
	tw.tween_property(btn, "scale", Vector2(punch, punch), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


## A short side-to-side wiggle for "that swap wasn't legal" — mirrors the
## HTML prototype's `.shake` keyframes. Restores the exact starting position
## at the end regardless of how it's interrupted, since GridContainer only
## reassigns a child's position on its own sort passes (not continuously),
## so a short-lived manual offset here is safe as long as we always return
## to the position we started from.
func _shake(r: int, c: int) -> void:
	if GameState.settings.get("reduce_motion", false):
		return
	if r < 0 or r >= MatchEngine.SIZE or c < 0 or c >= MatchEngine.SIZE:
		return
	var btn: Button = cell_buttons[r][c]
	var base_x := btn.position.x
	var tw := btn.create_tween()
	tw.tween_property(btn, "position:x", base_x - 5.0, 0.045)
	tw.tween_property(btn, "position:x", base_x + 5.0, 0.045)
	tw.tween_property(btn, "position:x", base_x - 3.0, 0.045)
	tw.tween_property(btn, "position:x", base_x, 0.045)


## Spawns a small burst of colored shard pieces at a matched cell's position,
## which pop outward then tumble down the screen under a simple simulated
## gravity, spinning and fading as they fall — used by _pop_out() below so a
## match reads as gems actually shattering apart, not just fading in place.
## Purely decorative and fire-and-forget: these live in toast_layer, entirely
## separate from the cell Button they came from, so they keep animating (and
## clean themselves up via queue_free) long after _pop_out()'s own await
## returns and the board underneath has already moved on.
func _spawn_shatter(r: int, c: int) -> void:
	var btn: Button = cell_buttons[r][c]
	var col := _color_for(board[r][c])
	var center: Vector2 = btn.global_position + btn.size / 2.0 - toast_layer.global_position
	# Bumped up across the board (more pieces, bigger shards, farther/faster
	# fall) per feedback that the original break was too subtle to notice —
	# this now reads as a real little explosion of debris rather than a few
	# specks drifting off the gem.
	var piece_count := 11
	for i in range(piece_count):
		var shard := ColorRect.new()
		var sz := 6.0 + randf() * 9.0
		shard.size = Vector2(sz, sz)
		shard.color = col
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shard.pivot_offset = shard.size / 2.0
		shard.position = center - shard.size / 2.0 + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0))
		shard.rotation = randf() * TAU
		toast_layer.add_child(shard)

		# A quick outward POP before the fall (a brief scale-from-1.4x settle)
		# makes the initial burst read as a sudden break rather than pieces
		# just quietly appearing already at rest.
		shard.scale = Vector2(1.5, 1.5)

		# A little outward scatter plus a big downward drop reads as gravity
		# without needing an actual physics/particle system — TRANS_QUAD +
		# EASE_IN makes the fall visibly accelerate, like a real object
		# picking up speed rather than drifting at a constant rate.
		var drift_x := randf_range(-75.0, 75.0)
		var fall_target := shard.position + Vector2(drift_x, 260.0 + randf() * 140.0)
		var tw := shard.create_tween()
		tw.set_parallel(true)
		tw.tween_property(shard, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(shard, "position", fall_target, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(shard, "rotation", shard.rotation + randf_range(-10.0, 10.0), 0.75)
		tw.tween_property(shard, "modulate:a", 0.0, 0.32).set_delay(0.38)
		tw.chain().tween_callback(func():
			if shard:
				shard.queue_free()
		)


## Animates matched cells shattering away BEFORE the board data is mutated,
## so the player sees the actual gems they matched break apart instead of
## the whole board silently snapping to its post-clear state.
func _pop_out(matched: Dictionary) -> void:
	if matched.is_empty():
		return
	if GameState.settings.get("reduce_motion", false):
		return
	var tw := main.create_tween().set_parallel(true)
	for key in matched.keys():
		var parts: PackedStringArray = String(key).split(",")
		var r := int(parts[0])
		var c := int(parts[1])
		if r < 0 or r >= MatchEngine.SIZE or c < 0 or c >= MatchEngine.SIZE:
			continue
		_spawn_shatter(r, c)
		var btn: Button = cell_buttons[r][c]
		btn.pivot_offset = btn.size / 2.0
		tw.tween_property(btn, "scale", Vector2(0.0, 0.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(btn, "modulate:a", 0.0, 0.1)
	await tw.finished
	if _torn_down:
		return
	# Reset immediately so the next _render_board() (which reuses these same
	# Button nodes for whatever gem lands there next) starts from a clean,
	# fully-visible state rather than inheriting the shrunk/faded look.
	for key in matched.keys():
		var parts: PackedStringArray = String(key).split(",")
		var r := int(parts[0])
		var c := int(parts[1])
		if r < 0 or r >= MatchEngine.SIZE or c < 0 or c >= MatchEngine.SIZE:
			continue
		var btn: Button = cell_buttons[r][c]
		btn.scale = Vector2.ONE
		btn.modulate = Color.WHITE


func _update_hud() -> void:
	# Defensive: every caller of this already sits behind an await in the
	# match-resolution chain (_attempt_swap/_on_cell_pressed/_score_and_clear),
	# each now guarded right after its own await — but a cheap extra guard
	# here means a future new call site can't reintroduce this crash class
	# by forgetting to check _torn_down itself. See _torn_down's doc comment.
	if _torn_down:
		return
	moves_lbl.text = "%d" % moves_left
	var target := int(level.target)
	score_lbl.text = "%d / %d pts" % [score, target]
	goal_bar.max_value = target
	goal_bar.value = clamp(score, 0, target)
	if charm_ring:
		charm_ring.set_progress(charm, MatchEngine.CHARM_MAX)
	chapter_lbl.text = "Chapter %d / %d" % [level_index + 1, ch.story.levels.size()]
	for item_id in item_btns.keys():
		_refresh_item_button(item_id)


## Active top-center toasts, oldest first — so a second toast that fires in
## the same instant (e.g. a "rough start" score line AND a quip both firing
## out of the same _score_and_clear() call) stacks below the first instead
## of printing exactly on top of it.
var _toast_stack: Array = []

func _toast(text: String) -> void:
	# Under Reduce Motion the text still appears (it's information — "Pick a
	# gem to pop.", "No moves left — reshuffling!", boost confirmations); it
	# just doesn't fade. It used to be skipped entirely.
	var still: bool = GameState.settings.get("reduce_motion", false)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", UITheme.ACCENT)
	lbl.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.85))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_layer.add_child(lbl)
	# Centered on its REAL width: a fixed 180px box with position -90 meant any
	# line longer than that (most of her quips) grew to the right, off-center.
	var sz := lbl.get_combined_minimum_size()
	lbl.size = sz
	lbl.position = Vector2(-sz.x / 2.0, 8 + _toast_stack.size() * 26)
	_toast_stack.append(lbl)
	if still:
		var hold := lbl.create_tween()
		hold.tween_interval(2.0)
		hold.tween_callback(func():
			_toast_stack.erase(lbl)
			lbl.queue_free()
		)
		return
	# Bound to the LABEL, not `main` — `main` is never freed, so a tween
	# created from it keeps running (and, worse, keeps trying to touch
	# `lbl`) even after clear_screen() frees this label on a screen
	# transition. Godot auto-kills a tween when the node it was created
	# from is freed, so binding here means leaving mid-fade is automatically
	# safe with no dangling animation — the same fix pattern as the round-5
	# idle-hint freeze (see _on_idle_timeout()) and _bounce()/_shake()/
	# _spawn_shatter() elsewhere in this file, all of which already bind to
	# the thing they animate rather than to `main`.
	var tw := lbl.create_tween()
	# Held noticeably longer than before (was 0.5s + a 0.5s fade — barely
	# enough time to read a short status line, let alone one of her actual
	# reaction quips). Applies to every toast, quips included, since they all
	# go through this one function.
	tw.tween_interval(1.4)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		_toast_stack.erase(lbl)
		lbl.queue_free()
	)


## Floating "Combo x2!" text (new — previously this reused the generic
## top-center _toast(), which could land right on top of the score/quip
## toast fired from the very same match). Spawns near the matched gems
## instead, with a slight random tilt, and drifts upward while fading —
## closer to how a lot of match-3 games surface combo feedback.
func _combo_popup(text: String, cells: Dictionary) -> void:
	if GameState.settings.get("reduce_motion", false):
		return
	var sum := Vector2.ZERO
	var n := 0
	for key in cells.keys():
		var parts: PackedStringArray = String(key).split(",")
		var r := int(parts[0])
		var c := int(parts[1])
		if r < 0 or r >= MatchEngine.SIZE or c < 0 or c >= MatchEngine.SIZE:
			continue
		var btn: Button = cell_buttons[r][c]
		sum += btn.global_position + btn.size / 2.0
		n += 1
	if n == 0:
		return
	var center: Vector2 = sum / float(n)
	var local_center: Vector2 = center - toast_layer.global_position

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", UITheme.SPECIAL_PINK)
	lbl.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(120, 28)
	lbl.pivot_offset = lbl.size / 2.0
	lbl.rotation_degrees = -12.0 + randf() * 10.0
	lbl.position = local_center - lbl.size / 2.0
	toast_layer.add_child(lbl)

	# Bound to the label itself, not `main` — see the matching note in
	# _toast() for why: `main` never gets freed, so a tween created from it
	# would keep running against `lbl` even after a screen transition frees
	# the label out from under it.
	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 40.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.45).set_delay(0.2)
	tw.chain().tween_callback(func():
		lbl.queue_free()
	)


## Restarts the idle countdown and clears any hint currently being shown.
## Called on every player action (a tap, an item use, a move finishing) so
## the hint only appears after a genuine stretch of inactivity.
func _reset_idle_timer() -> void:
	_clear_hint()
	if idle_timer == null:
		return
	idle_timer.stop()
	if not busy and not overlay.visible:
		idle_timer.start()


func _clear_hint() -> void:
	for tw in hint_tweens:
		if tw:
			tw.kill()
	hint_tweens = []
	for key in hint_cells:
		var r: int = key.x
		var c: int = key.y
		if r >= 0 and r < MatchEngine.SIZE and c >= 0 and c < MatchEngine.SIZE:
			var btn: Button = cell_buttons[r][c]
			btn.modulate = Color.WHITE
			btn.scale = Vector2.ONE
	hint_cells = []


## New feature (not in the original HTML prototype): after IDLE_HINT_SECONDS
## of no move, find a real legal swap via MatchEngine and gently pulse those
## two cells so a stuck player has somewhere obvious to look, instead of
## guessing at an 8x8 board with no clue where a match is available.
func _on_idle_timeout() -> void:
	if busy or overlay.visible or hammer_mode:
		return
	# avoid_broken=true: a stuck player doesn't need to be nudged toward the
	# one swap that costs them points — see MatchEngine.find_valid_swap().
	var hint: Dictionary = MatchEngine.find_valid_swap(board, true)
	if hint.is_empty():
		return
	var r1: int = hint.r1
	var c1: int = hint.c1
	var r2: int = hint.r2
	var c2: int = hint.c2
	hint_cells = [Vector2i(r1, c1), Vector2i(r2, c2)]
	var b1: Button = cell_buttons[r1][c1]
	var b2: Button = cell_buttons[r2][c2]
	hint_tweens = []
	# Two independent looping tweens (rather than one shared parallel/chain
	# tween) so each button pulses on its own clean sequential up-down cycle
	# with no risk of the chain()/parallel() bookkeeping desyncing them.
	#
	# IMPORTANT: bound to the BUTTON (btn.create_tween()), not to `main`.
	# `set_loops()` with no argument loops forever, and a tween created via
	# `main.create_tween()` lives as long as `main` does — which is the
	# entire rest of the game, since Main is never freed. If the player
	# navigated away (e.g. back to the roster) while a hint was mid-pulse,
	# that infinite tween kept right on running every frame against a cell
	# button that clear_screen() had already queue_free()'d, which is what
	# was freezing the game. Godot automatically kills a tween when the node
	# it was created from is freed, so binding it to the button itself makes
	# leaving mid-hint safe with no extra bookkeeping.
	for btn in [b1, b2]:
		btn.pivot_offset = btn.size / 2.0
		# Explicit type, not `:=` — `btn` here is Variant (loop var over an
		# untyped array literal), so the compiler can't infer create_tween()'s
		# return type from it (the same footgun documented elsewhere in this
		# file: `:=` needs a statically-known RHS type).
		var tw: Tween = btn.create_tween().set_loops()
		tw.tween_property(btn, "scale", Vector2(1.14, 1.14), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		hint_tweens.append(tw)


func _react_sprite(expr: String, hold_sec: float) -> void:
	if _live_sprite != null:
		_live_sprite.react(expr)
		return
	if _anim_sprite != null:
		_anim_react(expr)
		return
	_set_sprite_expr(expr)
	_sprite_token += 1
	var token := _sprite_token
	var timer := main.get_tree().create_timer(hold_sec)
	timer.timeout.connect(func():
		if token == _sprite_token:
			_set_sprite_expr("neutral")
	)


## Reaction on the idle animation, standing in for the expression-portrait
## swap: a little hop for good moments (happy/surprised), a slump for sad,
## and a quick flustered wobble with a red flash for angry (the cursed gem).
## Scale-only (from her base — see pivot_offset in _build_ui()) so it never
## fights the layout, and the tween is bound to the sprite so it dies with it.
func _anim_react(expr: String) -> void:
	if _anim_sprite == null or GameState.settings.get("reduce_motion", false):
		return
	if not (expr in ["happy", "surprised", "sad", "angry"]):
		return
	if _anim_react_tw and _anim_react_tw.is_valid():
		_anim_react_tw.kill()
	_anim_sprite.scale = Vector2.ONE
	_anim_sprite.modulate = Color.WHITE
	var s := _anim_sprite
	var tw := s.create_tween()
	match expr:
		"happy", "surprised":
			tw.tween_property(s, "scale", Vector2(1.04, 1.05), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(s, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		"sad":
			tw.tween_property(s, "scale", Vector2(1.01, 0.97), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(s, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		"angry":
			tw.tween_property(s, "modulate", Color(1.0, 0.78, 0.78), 0.08)
			tw.parallel().tween_property(s, "scale", Vector2(1.03, 0.97), 0.06)
			tw.tween_property(s, "scale", Vector2(0.98, 1.02), 0.06)
			tw.tween_property(s, "scale", Vector2(1.015, 0.99), 0.06)
			tw.tween_property(s, "scale", Vector2.ONE, 0.1)
			tw.parallel().tween_property(s, "modulate", Color.WHITE, 0.3)
	_anim_react_tw = tw


## Keys / a pad: with a gem picked up (A/Enter on it), a direction swaps it
## with its neighbour that way — "pick up and push" — and the ring follows
## the gem. Without one, directions just move the ring (Godot's own focus).
func _on_cell_gui_input(ev: InputEvent, r: int, c: int) -> void:
	if selected != Vector2i(r, c):
		return
	var d := Vector2i.ZERO
	if ev.is_action_pressed("ui_left"):
		d = Vector2i(0, -1)
	elif ev.is_action_pressed("ui_right"):
		d = Vector2i(0, 1)
	elif ev.is_action_pressed("ui_up"):
		d = Vector2i(-1, 0)
	elif ev.is_action_pressed("ui_down"):
		d = Vector2i(1, 0)
	if d == Vector2i.ZERO:
		return
	(cell_buttons[r][c] as Button).accept_event()
	if busy or _torn_down or moves_left <= 0 or (overlay != null and overlay.visible):
		return
	var r2 := r + d.x
	var c2 := c + d.y
	if r2 < 0 or r2 >= MatchEngine.SIZE or c2 < 0 or c2 >= MatchEngine.SIZE:
		return
	_reset_idle_timer()
	selected = Vector2i(-1, -1)
	(cell_buttons[r2][c2] as Button).grab_focus()
	call("_attempt_swap", r, c, r2, c2)


## Back (B / Backspace) in a chapter: put down a picked-up gem, or put the
## Hammer away. It never leaves the chapter by accident.
func _on_back() -> void:
	if _torn_down:
		return
	if selected != Vector2i(-1, -1):
		selected = Vector2i(-1, -1)
		_render_board()
	elif hammer_mode:
		hammer_mode = false
		_refresh_item_button("hammer")


func _on_cell_pressed(r: int, c: int) -> void:
	_reset_idle_timer()
	# The Out-of-Moves overlay only blocks the MOUSE; a keyboard/controller
	# press could still reach a cell under it (moves going negative, and a
	# swap that hit the target still "won"). Nothing on the board is playable
	# once the chapter is over or out of moves, whatever the input.
	if busy or _torn_down or moves_left <= 0 or (overlay != null and overlay.visible):
		return

	if hammer_mode:
		hammer_mode = false
		# The Hammer is charged here, when it actually pops a gem — not when
		# it's armed — so arming and then changing your mind costs nothing.
		GameState.items.hammer = maxi(0, int(GameState.items.get("hammer", 0)) - 1)
		_refresh_item_button("hammer")
		busy = true
		_refresh_all_items()
		var hit: int = board[r][c]
		var cells := {str(r) + "," + str(c): true}
		# A hammered special still goes off, same as swapping it would (it
		# used to just vanish for +25).
		if MatchEngine.is_special(hit):
			cells.merge(MatchEngine.detonation_cells(MatchEngine.special_kind(hit), r, c))
			SFX.special_()
			_react_sprite("surprised", 1.1)
			_toast("Boom!")
		await _pop_out(cells)
		if _torn_down:
			return
		if hit == MatchEngine.BROKEN_IDX:
			# Smashing a cursed shard is what the Hammer is FOR — it's cleared
			# for free instead of costing the -15 (and the angry face) a shard
			# costs when it's caught up in a match.
			SFX.match_()
			_toast("Shard smashed!")
			Achievements.unlock("SHARD_SMASH")
		else:
			_score_and_clear(cells, 1)
		var changed := MatchEngine.collapse_and_refill(board, cells, weights)
		_render_board(changed)
		await _settle_and_chain()
		if _torn_down:
			return
		GameState.save_state()
		busy = false
		_update_hud()
		_reset_idle_timer()
		_check_outcome()
		return

	if selected == Vector2i(-1, -1):
		selected = Vector2i(r, c)
		_render_board()
		return

	if selected == Vector2i(r, c):
		selected = Vector2i(-1, -1)
		_render_board()
		return

	var adjacent: bool = abs(selected.x - r) + abs(selected.y - c) == 1
	if not adjacent:
		selected = Vector2i(r, c)
		_render_board()
		return

	var r1 := selected.x
	var c1 := selected.y
	selected = Vector2i(-1, -1)
	_attempt_swap(r1, c1, r, c)


func _attempt_swap(r1: int, c1: int, r2: int, c2: int) -> void:
	busy = true
	_bounce(r1, c1)
	_bounce(r2, c2)
	var t1: int = board[r1][c1]
	var t2: int = board[r2][c2]

	if MatchEngine.is_special(t1) or MatchEngine.is_special(t2):
		var cells := {}
		if MatchEngine.is_special(t1):
			cells.merge(MatchEngine.detonation_cells(MatchEngine.special_kind(t1), r1, c1))
		if MatchEngine.is_special(t2):
			cells.merge(MatchEngine.detonation_cells(MatchEngine.special_kind(t2), r2, c2))
		cells[str(r1) + "," + str(c1)] = true
		cells[str(r2) + "," + str(c2)] = true
		moves_left -= 1
		SFX.special_()
		_react_sprite("surprised", 1.1)
		_toast("Mega Blast!" if MatchEngine.is_special(t1) and MatchEngine.is_special(t2) else "Boom!")
		if MatchEngine.is_special(t1) and MatchEngine.is_special(t2):
			Achievements.unlock("MEGA_BLAST")
		await _pop_out(cells)
		if _torn_down:
			return
		_score_and_clear(cells, 1)
		var changed := MatchEngine.collapse_and_refill(board, cells, weights)
		_render_board(changed)
		await _settle_and_chain()
		if _torn_down:
			return
		if GameState.settings.test_mode:
			score = int(level.target)
		GameState.save_state()
		busy = false
		_update_hud()
		_reset_idle_timer()
		_check_outcome()
		return

	board[r1][c1] = t2
	board[r2][c2] = t1
	var first: Dictionary = MatchEngine.analyze_matches(board, {"r": r2, "c": c2})
	if first.matched_cells.is_empty():
		board[r1][c1] = t1
		board[r2][c2] = t2
		SFX.invalid()
		_react_sprite("sad", 0.7)
		_shake(r1, c1)
		_shake(r2, c2)
		busy = false
		# Redraw: `selected` was already cleared above, but without a redraw
		# the first gem kept its selected outline, so the next tap on its
		# neighbour selected that neighbour instead of swapping.
		_render_board()
		_refresh_all_items()
		_reset_idle_timer()
		return

	# Show the swap BEFORE the matched gems shatter — the board data is
	# already swapped, but the buttons still showed the old positions, so the
	# wrong icons shrank away and the moved gem "teleported" in afterwards.
	_render_board()
	moves_left -= 1
	await _resolve_loop(first, 1)
	if _torn_down:
		return
	# Same free reshuffle the hammer and special paths get (via
	# _settle_and_chain): a normal swap whose cascades leave no legal move used
	# to leave the board stuck with moves still on the clock — no hint, no
	# lose screen, only "← Roster" out.
	if not MatchEngine.has_valid_move(board):
		await _reshuffle_no_move()
		if _torn_down:
			return
	if GameState.settings.test_mode:
		score = int(level.target)
	GameState.save_state()
	busy = false
	# After busy is cleared, not before: _refresh_item_button() disables every
	# item while busy, so refreshing earlier left all the item slots greyed out
	# for the rest of the chapter after the first move.
	_update_hud()
	_reset_idle_timer()
	_check_outcome()


func _settle_and_chain() -> void:
	if not GameState.settings.get("reduce_motion", false):
		await main.get_tree().create_timer(0.2).timeout
	if _torn_down:
		return
	var next: Dictionary = MatchEngine.analyze_matches(board)
	if not next.matched_cells.is_empty():
		await _resolve_loop(next, 2)
		if _torn_down:
			return
	# New feature (not in the original HTML prototype): once the board has
	# fully settled after a move, make sure the player isn't left stuck —
	# if there's genuinely no legal swap left anywhere, reshuffle for free
	# rather than softlocking them.
	if not MatchEngine.has_valid_move(board):
		await _reshuffle_no_move()
	# NOTE: the idle-hint countdown is armed by the caller once `busy` is
	# actually back to false (see the end of _attempt_swap()/_on_cell_pressed's
	# hammer branch) — arming it here would be a no-op, since _reset_idle_timer()
	# refuses to start the timer while busy is still true, and busy doesn't
	# flip back to false until after this coroutine returns.


## Silently reshuffles the board when no legal move remains — doesn't cost a
## move or a turn, just like the Item Shop's manual Shuffle. A few retries
## guard against the (astronomically unlikely) case where the reshuffle
## itself lands on another dead board.
func _reshuffle_no_move() -> void:
	board = _fresh_playable_board()
	_toast("No moves left — reshuffling!")
	var all_cells := {}
	for r in range(MatchEngine.SIZE):
		for c in range(MatchEngine.SIZE):
			all_cells[str(r) + "," + str(c)] = true
	_render_board(all_cells)
	if not GameState.settings.get("reduce_motion", false):
		await main.get_tree().create_timer(0.25).timeout


func _resolve_loop(match_result: Dictionary, combo_index: int) -> void:
	var matched: Dictionary = match_result.matched_cells
	if matched.is_empty():
		return
	await _pop_out(matched)
	if _torn_down:
		return
	_score_and_clear(matched, combo_index)
	var changed: Dictionary = MatchEngine.collapse_and_refill(board, matched, weights)
	# Specials spawn at their designated cell after the collapse settles —
	# a small, deliberate simplification vs. the original's pre-collapse
	# placement that keeps this port's cascade logic straightforward.
	for sp in match_result.specials:
		var rr: int = int(sp.r)
		var cc: int = int(sp.c)
		if rr >= 0 and rr < MatchEngine.SIZE and cc >= 0 and cc < MatchEngine.SIZE:
			# Never overwrite a special that has fallen into this cell (it would
			# silently vanish, a paid Starburst Starter included) — drop the new
			# one into the nearest plain gem instead.
			var spot := _special_spot(rr, cc)
			if spot.x < 0:
				continue
			board[spot.x][spot.y] = MatchEngine.special_code(String(sp.type))
			changed[str(spot.x) + "," + str(spot.y)] = true
			if board[spot.x][spot.y] == MatchEngine.STARBURST:
				Achievements.unlock("MAKE_STARBURST")
	_render_board(changed)
	if not GameState.settings.get("reduce_motion", false):
		await main.get_tree().create_timer(0.22).timeout
	if _torn_down:
		return
	var next: Dictionary = MatchEngine.analyze_matches(board)
	if not next.matched_cells.is_empty():
		await _resolve_loop(next, combo_index + 1)


## Where a newly earned special should go: its own cell, unless a special
## already sits there — then the closest cell holding a plain (non-special,
## non-cursed) gem. Vector2i(-1, -1) if the whole board is somehow specials.
func _special_spot(r: int, c: int) -> Vector2i:
	if not MatchEngine.is_special(board[r][c]):
		return Vector2i(r, c)
	var best := Vector2i(-1, -1)
	var best_d := 999
	for rr in range(MatchEngine.SIZE):
		for cc in range(MatchEngine.SIZE):
			var t: int = board[rr][cc]
			if MatchEngine.is_special(t) or t == MatchEngine.BROKEN_IDX:
				continue
			var dist: int = absi(rr - r) + absi(cc - c)
			if dist < best_d:
				best_d = dist
				best = Vector2i(rr, cc)
	return best


func _score_and_clear(matched: Dictionary, combo_index: int) -> void:
	var gain := 0
	var broken_hit := 0
	var fav_hit := false
	var least_hit := false
	for key in matched.keys():
		var parts: PackedStringArray = String(key).split(",")
		var r := int(parts[0])
		var c := int(parts[1])
		var t: int = board[r][c]
		if t == MatchEngine.BROKEN_IDX:
			broken_hit += 1
			gain -= 15
		elif MatchEngine.is_special(t):
			gain += 25
		else:
			gain += 10
			var gname := CharacterData.gem_name(t)
			if gname == String(ch.fav):
				charm = min(MatchEngine.CHARM_MAX, charm + 2)
				fav_hit = true
			else:
				charm = min(MatchEngine.CHARM_MAX, charm + 1)
				if gname == String(ch.least):
					least_hit = true

	var combo_mult := 1.0 + 0.5 * float(combo_index - 1)
	gain = int(round(float(gain) * combo_mult))
	score += gain
	if combo_index >= 3:
		Achievements.unlock("COMBO_3")
	if combo_index >= 5:
		Achievements.unlock("COMBO_5")

	if broken_hit > 0:
		_react_sprite("angry", 1.4)
		_toast(("%d pts..." % gain) if gain < 0 else "Ouch!")
	elif combo_index >= 2:
		SFX.combo(combo_index)
		# Floats up from the actual matched gems (angled, see _combo_popup)
		# instead of the generic top-center toast, which used to land right
		# on top of the score/quip toast fired from this same match.
		_combo_popup("Combo x%d!" % combo_index, matched)
		_react_sprite("happy", 1.0)
	else:
		SFX.match_()

	var fav_quips: Array = ch.get("favQuips", [])
	var least_quips: Array = ch.get("leastQuips", [])
	var chat_quips: Array = ch.get("chatQuips", [])
	if fav_hit and randf() < 0.4 and not fav_quips.is_empty():
		_toast(_quip_text(fav_quips[randi() % fav_quips.size()]))
	elif least_hit and randf() < 0.4 and not least_quips.is_empty():
		_toast(_quip_text(least_quips[randi() % least_quips.size()]))
	elif randf() < 0.12 and not chat_quips.is_empty():
		_toast(_quip_text(chat_quips[randi() % chat_quips.size()]))

	if charm >= MatchEngine.CHARM_MAX:
		charm = 0
		score += 150
		_toast("Charm Burst! +150")
		Achievements.unlock("CHARM_BURST")

	_update_hud()


## A quip is either plain text or {"t": text, "d": delivery note, "id": voice
## line id} (round 21: the voice script needs the notes and ids).
static func _quip_text(q) -> String:
	if typeof(q) == TYPE_DICTIONARY:
		return String(q.get("t", ""))
	return String(q)


func _check_outcome() -> void:
	# Highest-priority _torn_down guard in this file: this is the one call
	# site that can open a BRAND NEW screen (StoryFlow.on_chapter_won ->
	# a fresh VN scene, or an ending) on top of whatever the player has
	# already navigated to if they hit "← Roster" mid-match-animation. Every
	# caller already checks _torn_down right after its own await before
	# reaching here, but this guard is the one that actually matters if any
	# of them is ever missed.
	if _torn_down:
		return
	var target := int(level.target)
	if score >= target:
		if moves_left >= 5:
			Achievements.unlock("MOVES_LEFT_5")
		StoryFlow.on_chapter_won(main, char_id)
	elif moves_left <= 0:
		_show_lose_overlay()


## Stars for running out of moves: 1 for every 100 points scored, at least 3.
## Enough that a few tries buy a power-up (the cheapest, +3 Moves, is 12), but
## always well under what winning the chapter pays (15 to 30).
static func consolation_stars(final_score: int) -> int:
	return maxi(3, floori(float(final_score) / 100.0))


func _show_lose_overlay() -> void:
	SFX.lose()
	_clear_hint()
	# Losing still pays a little, so you can save up for power-ups and come
	# back for another go (topped up, never paid twice, if +3 Moves keeps the
	# attempt going and it runs out again).
	var earned := consolation_stars(score)
	var owed := earned - _consolation_paid
	if owed > 0:
		GameState.stars += owed
		_consolation_paid = earned
		GameState.save_state()
		main.refresh_topbar()
	if idle_timer:
		idle_timer.stop()
	for c in overlay.get_children():
		c.queue_free()
	overlay.visible = true
	hammer_mode = false
	# Hammer/Shuffle go dark under the overlay (see _refresh_item_button()).
	_refresh_all_items()
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	overlay.add_child(v)
	# Centered like the buttons (the panel stretches this column to its full
	# width, so left-aligned text sat off in the corner).
	var title := UITheme.heading("Out of Moves", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var needed := UITheme.soft_label("You needed %d more points." % max(0, int(level.target) - score), 12)
	needed.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(needed)
	var reward := UITheme.body("+%d ⭐ for trying" % earned, 15, UITheme.INK)
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(reward)
	var hint := UITheme.soft_label("1 star for every 100 points. Save up for power-ups in the Item Shop, then try again!", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = Vector2(380, 0)
	v.add_child(hint)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)

	if int(GameState.items.get("moves", 0)) > 0:
		var use_btn := UITheme.make_primary_button("Use +3 Moves")
		use_btn.pressed.connect(func():
			_on_item_pressed("moves")
		)
		row.add_child(use_btn)

	var retry_btn := UITheme.make_ghost_button("Retry Chapter")
	retry_btn.pressed.connect(func():
		# Re-enter through Main's router rather than re-running setup() in
		# place, so the screen_host is properly cleared first (a fresh
		# PuzzleScreen instance also means no stale signal connections from
		# this attempt's buttons linger around).
		main.show_puzzle(char_id)
	)
	row.add_child(retry_btn)

	# Straight to the shop; its Back button brings you back into this chapter
	# for a fresh try (Main.open_store_from_chapter()).
	var shop_btn := UITheme.make_ghost_button("🛍  Item Shop")
	UITheme.apply_icon(shop_btn, "store", "Item Shop")
	shop_btn.pressed.connect(func():
		SFX.nav()
		main.open_store_from_chapter(char_id)
	)
	row.add_child(shop_btn)
	# Keys / a pad: onto the overlay's first button (the board is locked).
	if Nav.nav_mode:
		(row.get_child(0) as Control).grab_focus.call_deferred()

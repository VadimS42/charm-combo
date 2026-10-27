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
const GLYPH := {
	0: "🔥", 1: "🌙", 2: "🌸", 3: "💧", 4: "🌀", 5: "💎", 6: "💔",
}

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
var charm: int = 0
var busy: bool = false
var hammer_mode: bool = false

var cell_buttons: Array = []  # [r][c] -> Button
var sprite_host: Control
var score_lbl: Label
var moves_lbl: Label
var chapter_lbl: Label
var goal_bar: ProgressBar
var charm_bar: ProgressBar
var toast_layer: Control
var overlay: PanelContainer
var item_btns: Dictionary = {}
var _sprite_token := 0

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
	score = GameState.pending_start_bonus
	GameState.pending_start_bonus = 0
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

	if int(GameState.items.get("colorBomb", 0)) > 0:
		GameState.items.colorBomb = int(GameState.items.colorBomb) - 1
		var br := 2 + randi() % 4
		var bc := 2 + randi() % 4
		board[br][bc] = MatchEngine.STARBURST
	if int(GameState.items.get("favorCharm", 0)) > 0:
		GameState.items.favorCharm = int(GameState.items.favorCharm) - 1
	if int(GameState.items.get("heartMender", 0)) > 0:
		GameState.items.heartMender = int(GameState.items.heartMender) - 1
	GameState.save_state()

	_build_ui()
	# Wait one frame so the grid has actually laid out (button .size is
	# still (0,0) the instant after add_child, before the container's first
	# sort pass) — otherwise the deal-in pop below would scale from the
	# wrong pivot on its very first frame.
	await main.get_tree().process_frame
	# Guard against the vanishingly rare case where a freshly built board
	# happens to have no legal move at all (build_board only forbids
	# pre-existing 3-runs, it doesn't guarantee a move exists).
	if not MatchEngine.has_valid_move(board):
		for i in range(5):
			board = MatchEngine.build_board(weights)
			if MatchEngine.has_valid_move(board):
				break
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

	if score > 0:
		_toast("+%d pts — great answer!" % score)
	elif score < 0:
		_toast("%d pts — rough start..." % score)


func _accent() -> Color:
	return Color(String(ch.c))


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

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	host.add_child(root)

	var top_row := HBoxContainer.new()
	var back := UITheme.make_ghost_button("←  Roster")
	back.pressed.connect(func():
		SFX.nav()
		GameState.save_state()
		main.show_roster()
	)
	top_row.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	top_row.add_child(UITheme.soft_label(String(ch.name), 12))
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

	var board_area := Control.new()
	board_area.custom_minimum_size = Vector2(0, 480)
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_col.add_child(board_area)

	var board_center := CenterContainer.new()
	board_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_area.add_child(board_center)

	var board_panel := UITheme.panel(UITheme.GEM_WELL, 16, UITheme.LINE)
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
			btn.pressed.connect(_on_cell_pressed.bind(r, c))
			grid.add_child(btn)
			row.append(btn)
		cell_buttons.append(row)

	toast_layer = Control.new()
	toast_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.add_child(toast_layer)

	var legend := UITheme.soft_label(
		"Match 4 → Rocket · Match 5 / L·T shape → Starburst · swap a special to trigger it · watch out for broken hearts — they cost points", 10)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_col.add_child(legend)

	# ---- sidebar ----
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size = Vector2(240, 0)
	sidebar.add_theme_constant_override("separation", 10)
	layout.add_child(sidebar)

	var sprite_panel := PanelContainer.new()
	sprite_panel.add_theme_stylebox_override("panel", UITheme.panel_style(_accent().lightened(0.8), 16, _accent().lightened(0.5)))
	sprite_panel.custom_minimum_size = Vector2(0, 170)
	sprite_host = Control.new()
	sprite_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite_panel.add_child(sprite_host)
	sidebar.add_child(sprite_panel)
	_set_sprite_expr("neutral")

	var name_card := UITheme.panel(UITheme.SURFACE_2, 14, UITheme.LINE)
	var name_v := VBoxContainer.new()
	name_v.add_child(UITheme.body(String(ch.name), 14))
	chapter_lbl = UITheme.accent_label("", _accent(), 11)
	name_v.add_child(chapter_lbl)
	name_card.add_child(name_v)
	sidebar.add_child(name_card)

	var hud_card := UITheme.panel(UITheme.SURFACE_2, 14, UITheme.LINE)
	var hud_v := VBoxContainer.new()
	hud_v.add_theme_constant_override("separation", 6)
	moves_lbl = UITheme.body("", 12)
	hud_v.add_child(moves_lbl)
	score_lbl = UITheme.body("", 12)
	hud_v.add_child(score_lbl)
	goal_bar = ProgressBar.new()
	goal_bar.show_percentage = false
	hud_v.add_child(goal_bar)
	hud_v.add_child(UITheme.soft_label("Charm", 10))
	charm_bar = ProgressBar.new()
	charm_bar.show_percentage = false
	hud_v.add_child(charm_bar)
	hud_card.add_child(hud_v)
	sidebar.add_child(hud_card)

	var items_card := UITheme.panel(UITheme.SURFACE_2, 14, UITheme.LINE)
	var items_v := VBoxContainer.new()
	items_v.add_theme_constant_override("separation", 6)
	items_v.add_child(UITheme.soft_label("Items", 10))
	items_v.add_child(_item_button("moves", "+3 Moves"))
	items_v.add_child(_item_button("hammer", "Hammer"))
	items_v.add_child(_item_button("shuffle", "Shuffle"))
	items_card.add_child(items_v)
	sidebar.add_child(items_card)

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


func _item_button(item_id: String, label: String) -> Button:
	var b := UITheme.make_card_button(label, _accent())
	item_btns[item_id] = b
	b.pressed.connect(_on_item_pressed.bind(item_id))
	_refresh_item_button(item_id)
	return b


func _refresh_item_button(item_id: String) -> void:
	var count := int(GameState.items.get(item_id, 0))
	var b: Button = item_btns[item_id]
	var base: String = {"moves": "+3 Moves", "hammer": "Hammer", "shuffle": "Shuffle"}[item_id]
	b.text = "%s  (%d)" % [base, count]
	b.disabled = count <= 0 or busy


func _on_item_pressed(item_id: String) -> void:
	var count := int(GameState.items.get(item_id, 0))
	if count <= 0 or busy:
		return
	match item_id:
		"moves":
			GameState.items.moves = count - 1
			moves_left += 3
			overlay.visible = false
			_update_hud()
		"hammer":
			GameState.items.hammer = count - 1
			hammer_mode = true
			selected = Vector2i(-1, -1)
			_render_board()
			_toast("Pick a gem to pop.")
		"shuffle":
			GameState.items.shuffle = count - 1
			board = MatchEngine.build_board(weights)
			_render_board()
	GameState.save_state()
	_refresh_item_button(item_id)
	_reset_idle_timer()


## Swaps the sidebar sprite to a real portrait the moment
## res://art/characters/<char_id>/<expr>.png exists; until then, the same
## big reactive emoji placeholder as before.
func _set_sprite_expr(expr: String) -> void:
	if sprite_host == null:
		return
	for c in sprite_host.get_children():
		c.queue_free()
	var tex := ArtAssets.character_portrait(char_id, expr)
	if tex:
		var t := TextureRect.new()
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite_host.add_child(t)
	else:
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		var lbl := Label.new()
		lbl.text = VNScreen.EXPR_ICON.get(expr, "🙂")
		lbl.add_theme_font_size_override("font_size", 84)
		center.add_child(lbl)
		sprite_host.add_child(center)


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
	for r in range(MatchEngine.SIZE):
		for c in range(MatchEngine.SIZE):
			var t: int = board[r][c]
			var btn: Button = cell_buttons[r][c]
			var icon_tex := _icon_for(t)
			if icon_tex:
				btn.icon = icon_tex
				btn.expand_icon = true
				btn.text = ""
			else:
				btn.icon = null
				btn.text = _glyph(t)
			var bg := _color_for(t)
			var is_sel := selected == Vector2i(r, c)
			var radius := 22 if is_sel else 13
			var style := UITheme.button_style(bg, radius)
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


## Animates matched cells shrinking/fading away BEFORE the board data is
## mutated, so the player sees the actual gems they matched disappear
## instead of the whole board silently snapping to its post-clear state.
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
		var btn: Button = cell_buttons[r][c]
		btn.pivot_offset = btn.size / 2.0
		tw.tween_property(btn, "scale", Vector2(0.0, 0.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(btn, "modulate:a", 0.15, 0.15)
	await tw.finished
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
	moves_lbl.text = "Moves: %d" % moves_left
	var target := int(level.target)
	score_lbl.text = "%d pts  (goal %d)" % [score, target]
	goal_bar.max_value = target
	goal_bar.value = clamp(score, 0, target)
	charm_bar.max_value = MatchEngine.CHARM_MAX
	charm_bar.value = charm
	chapter_lbl.text = "Chapter %d / %d" % [level_index + 1, ch.story.levels.size()]
	for item_id in item_btns.keys():
		_refresh_item_button(item_id)


func _toast(text: String) -> void:
	if GameState.settings.get("reduce_motion", false):
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", UITheme.ACCENT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.position = Vector2(-80, 8)
	lbl.size = Vector2(160, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_layer.add_child(lbl)
	var tw := main.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(lbl.queue_free)


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
	var hint: Dictionary = MatchEngine.find_valid_swap(board)
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
	for btn in [b1, b2]:
		btn.pivot_offset = btn.size / 2.0
		var tw := main.create_tween().set_loops()
		tw.tween_property(btn, "scale", Vector2(1.14, 1.14), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		hint_tweens.append(tw)


func _react_sprite(expr: String, hold_sec: float) -> void:
	_set_sprite_expr(expr)
	_sprite_token += 1
	var token := _sprite_token
	var timer := main.get_tree().create_timer(hold_sec)
	timer.timeout.connect(func():
		if token == _sprite_token:
			_set_sprite_expr("neutral")
	)


func _on_cell_pressed(r: int, c: int) -> void:
	_reset_idle_timer()
	if busy:
		return

	if hammer_mode:
		hammer_mode = false
		busy = true
		var cells := {str(r) + "," + str(c): true}
		await _pop_out(cells)
		_score_and_clear(cells, 1)
		var changed := MatchEngine.collapse_and_refill(board, cells, weights)
		_render_board(changed)
		await _settle_and_chain()
		GameState.save_state()
		busy = false
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
		await _pop_out(cells)
		_score_and_clear(cells, 1)
		var changed := MatchEngine.collapse_and_refill(board, cells, weights)
		_render_board(changed)
		await _settle_and_chain()
		if GameState.settings.test_mode:
			score = int(level.target)
		_update_hud()
		GameState.save_state()
		busy = false
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
		return

	moves_left -= 1
	await _resolve_loop(first, 1)
	if GameState.settings.test_mode:
		score = int(level.target)
	_update_hud()
	GameState.save_state()
	busy = false
	_check_outcome()


func _settle_and_chain() -> void:
	if not GameState.settings.get("reduce_motion", false):
		await main.get_tree().create_timer(0.2).timeout
	var next: Dictionary = MatchEngine.analyze_matches(board)
	if not next.matched_cells.is_empty():
		await _resolve_loop(next, 2)
	# New feature (not in the original HTML prototype): once the board has
	# fully settled after a move, make sure the player isn't left stuck —
	# if there's genuinely no legal swap left anywhere, reshuffle for free
	# rather than softlocking them.
	if not MatchEngine.has_valid_move(board):
		await _reshuffle_no_move()
	_reset_idle_timer()


## Silently reshuffles the board when no legal move remains — doesn't cost a
## move or a turn, just like the Item Shop's manual Shuffle. A few retries
## guard against the (astronomically unlikely) case where the reshuffle
## itself lands on another dead board.
func _reshuffle_no_move() -> void:
	for i in range(5):
		board = MatchEngine.build_board(weights)
		if MatchEngine.has_valid_move(board):
			break
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
	_score_and_clear(matched, combo_index)
	var changed: Dictionary = MatchEngine.collapse_and_refill(board, matched, weights)
	# Specials spawn at their designated cell after the collapse settles —
	# a small, deliberate simplification vs. the original's pre-collapse
	# placement that keeps this port's cascade logic straightforward.
	for sp in match_result.specials:
		var rr: int = int(sp.r)
		var cc: int = int(sp.c)
		if rr >= 0 and rr < MatchEngine.SIZE and cc >= 0 and cc < MatchEngine.SIZE:
			board[rr][cc] = MatchEngine.special_code(String(sp.type))
			changed[str(rr) + "," + str(cc)] = true
	_render_board(changed)
	if not GameState.settings.get("reduce_motion", false):
		await main.get_tree().create_timer(0.22).timeout
	var next: Dictionary = MatchEngine.analyze_matches(board)
	if not next.matched_cells.is_empty():
		await _resolve_loop(next, combo_index + 1)


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

	if broken_hit > 0:
		_react_sprite("angry", 1.4)
		_toast(("%d pts..." % gain) if gain < 0 else "Ouch!")
	elif combo_index >= 2:
		SFX.combo(combo_index)
		_toast("Combo x%d!" % combo_index)
		_react_sprite("happy", 1.0)
	else:
		SFX.match_()

	var fav_quips: Array = ch.get("favQuips", [])
	var least_quips: Array = ch.get("leastQuips", [])
	var chat_quips: Array = ch.get("chatQuips", [])
	if fav_hit and randf() < 0.4 and not fav_quips.is_empty():
		_toast(String(fav_quips[randi() % fav_quips.size()]))
	elif least_hit and randf() < 0.4 and not least_quips.is_empty():
		_toast(String(least_quips[randi() % least_quips.size()]))
	elif randf() < 0.12 and not chat_quips.is_empty():
		_toast(String(chat_quips[randi() % chat_quips.size()]))

	if charm >= MatchEngine.CHARM_MAX:
		charm = 0
		score += 150
		_toast("Charm Burst! +150")

	_update_hud()


func _check_outcome() -> void:
	var target := int(level.target)
	if score >= target:
		StoryFlow.on_chapter_won(main, char_id)
	elif moves_left <= 0:
		_show_lose_overlay()


func _show_lose_overlay() -> void:
	SFX.lose()
	_clear_hint()
	if idle_timer:
		idle_timer.stop()
	for c in overlay.get_children():
		c.queue_free()
	overlay.visible = true
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	overlay.add_child(v)
	v.add_child(UITheme.heading("Out of Moves", 20))
	v.add_child(UITheme.soft_label("You needed %d more points." % max(0, int(level.target) - score), 12))

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

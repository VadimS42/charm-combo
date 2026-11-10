## PuzzleRules.gd — each girl's own board piece, goal and Charm power (round 44).
##
## Pure game state and rules, no nodes: PuzzleScreen drives it (and animates
## what it reports) and tools/balance_bot.gd plays it headless, so the bot
## always plays exactly the rules the player gets. MatchEngine still finds the
## matches; this adds what sits on and under the gems:
##
##   Amara  "seal"  an ink seal on a gem: it can't be swapped, but still
##                  matches; the first match / blast / Hammer breaks the seal
##                  and the gem stays. Seals fall with their gem.
##   Marina "tide"  gravity is reversed (gems rise, new ones come up from the
##                  bottom); comb pieces rise with them and are collected at
##                  the top row. Combs can't be matched, swapped or hammered.
##   Opal   "moss"  moss under a cell; a match / blast / Hammer on the cell
##                  clears it, and some moss hides one of her things.
##   Hazel  "seed"  a seed sits in a cell and falls like a gem, but can't be
##                  swapped or matched; a match next to it grows it (seed ->
##                  sprout -> blossom), and a blossom pops: +100 and the 8
##                  cells around it clear. Her disliked gem doesn't grow it.
##
## A chapter's piece, goal and numbers are in data/characters.json (each
## level's "mech", "pieces", "goal" and "target"; each girl's "power").
class_name PuzzleRules
extends RefCounted

const SIZE := MatchEngine.SIZE
const SEED := 110
const SPROUT := 111
const COMB := 120
## Opal's things under the moss (art/pieces/item_<name>.png).
const ITEMS := ["button", "marble", "key", "eye"]

## Points: a gem 10, her favourite x2, her disliked one x0.5 (round 44).
const GEM_POINTS := 10
const SPECIAL_POINTS := 25
const SHARD_POINTS := -15
const BLOSSOM_POINTS := 100

var board: Array = []
## [r][c] true = sealed gem (moves with its gem).
var seal: Array = []
## [r][c] 0 = none, 1 = moss, 2 + i = moss hiding ITEMS[i] (stays put).
var moss: Array = []
var weights: Array = []
var mech := ""
var pieces: Dictionary = {}
var goal_kind := ""
var goal_n := 0
var target := 0
var gravity_up := false
var fav := -1
var least := -1
var power_id := ""

# Progress.
var seals_broken := 0
var items_found := 0
var blossoms := 0
var combs_up := 0
var moves_made := 0


func setup(ch: Dictionary, level_index: int, p_weights: Array) -> void:
	var level: Dictionary = ch.story.levels[level_index]
	weights = p_weights
	mech = String(level.get("mech", ""))
	pieces = level.get("pieces", {})
	var g: Dictionary = level.get("goal", {})
	goal_kind = String(g.get("kind", ""))
	goal_n = int(g.get("n", 0))
	target = int(level.get("target", 0))
	gravity_up = mech == "tide"
	fav = CharacterData.gem_index_from_id(String(ch.get("fav", "")))
	least = CharacterData.gem_index_from_id(String(ch.get("least", "")))
	power_id = String(ch.get("power", {}).get("id", "")) if mech != "" else ""
	seal = _grid(false)
	moss = _grid(0)
	board = _grid(-1)
	_place_pieces()
	board = fresh_board(true)


static func _grid(v) -> Array:
	var g: Array = []
	for r in range(SIZE):
		var row: Array = []
		row.resize(SIZE)
		row.fill(v)
		g.append(row)
	return g


static func key(r: int, c: int) -> String:
	return str(r) + "," + str(c)


static func unkey(k: String) -> Vector2i:
	var p := k.split(",")
	return Vector2i(int(p[0]), int(p[1]))


static func in_board(r: int, c: int) -> bool:
	return r >= 0 and r < SIZE and c >= 0 and c < SIZE


## A deep copy, for the bot to try a move on.
func copy() -> PuzzleRules:
	var o := PuzzleRules.new()
	o.board = board.duplicate(true)
	o.seal = seal.duplicate(true)
	o.moss = moss.duplicate(true)
	o.weights = weights
	o.mech = mech
	o.pieces = pieces
	o.goal_kind = goal_kind
	o.goal_n = goal_n
	o.target = target
	o.gravity_up = gravity_up
	o.fav = fav
	o.least = least
	o.power_id = power_id
	o.seals_broken = seals_broken
	o.items_found = items_found
	o.blossoms = blossoms
	o.combs_up = combs_up
	o.moves_made = moves_made
	return o


# ------------------------------------------------------------ the start

## Where the chapter's pieces start. Seals and moss only mark cells here;
## the gems under them are dealt by fresh_board().
func _place_pieces() -> void:
	var cells: Array = []
	for r in range(SIZE):
		for c in range(SIZE):
			cells.append(Vector2i(r, c))
	cells.shuffle()
	match mech:
		"seal":
			for i in range(mini(int(pieces.get("start", 0)), cells.size())):
				seal[cells[i].x][cells[i].y] = true
		"moss":
			var n := int(pieces.get("cells", 0))
			var with_items := int(pieces.get("items", 0))
			for i in range(mini(n, cells.size())):
				var v: Vector2i = cells[i]
				moss[v.x][v.y] = (2 + randi() % ITEMS.size()) if i < with_items else 1
		"tide":
			# Comb pieces start in the bottom two rows, each in its own column.
			var cols := range(SIZE)
			cols.shuffle()
			for i in range(mini(int(pieces.get("combs", 0)), SIZE)):
				board[SIZE - 1 - (i % 2)][cols[i]] = COMB
		"seed":
			var placed := 0
			for v in cells:
				if placed >= int(pieces.get("start", 0)):
					break
				if v.x >= 1 and v.x <= 5:
					board[v.x][v.y] = SEED
					placed += 1


## The board's pieces stay where they are (seeds, comb pieces, specials and
## the seals, on whatever gem sits under them); every other gem is dealt
## again with no ready-made match, until there's a legal move. Used for the
## start, Shuffle and the free no-move reshuffle.
func fresh_board(drop_specials := false) -> Array:
	var keep := _grid(-1)
	for r in range(SIZE):
		for c in range(SIZE):
			var t: int = board[r][c]
			if t == SEED or t == SPROUT or t == COMB or (MatchEngine.is_special(t) and not drop_specials):
				keep[r][c] = t
	var saved := board
	for attempt in range(60):
		var b := _grid(-1)
		for r in range(SIZE):
			for c in range(SIZE):
				if keep[r][c] != -1:
					b[r][c] = keep[r][c]
					continue
				var t := 0
				for tries in range(30):
					t = MatchEngine.weighted_rand_type(weights)
					var bad: bool = (c >= 2 and b[r][c - 1] == t and b[r][c - 2] == t) \
						or (r >= 2 and b[r - 1][c] == t and b[r - 2][c] == t)
					if not bad:
						break
				b[r][c] = t
		# Seals sit on gems only: a seal over a kept piece moves to a gem.
		board = b
		if not MatchEngine.analyze_matches(b).matched_cells.is_empty():
			continue
		if has_move():
			_fix_seals()
			return b
	board = saved
	_fix_seals()
	return MatchEngine.build_board(weights) if not has_move() else board


func _fix_seals() -> void:
	for r in range(SIZE):
		for c in range(SIZE):
			if seal[r][c] and not MatchEngine.is_normal(board[r][c]):
				seal[r][c] = false


# ------------------------------------------------------------ moves

## A cell the player can pick up and swap.
func swappable(r: int, c: int) -> bool:
	var t: int = board[r][c]
	if MatchEngine.is_special(t):
		return true
	return MatchEngine.is_normal(t) and not seal[r][c]


## MatchEngine.find_valid_swap(), but sealed gems and pieces don't move.
func find_swap(avoid_broken := false) -> Dictionary:
	var fallback := {}
	for r in range(SIZE):
		for c in range(SIZE):
			for d in [Vector2i(0, 1), Vector2i(1, 0)]:
				var r2: int = r + d.y
				var c2: int = c + d.x
				if r2 >= SIZE or c2 >= SIZE:
					continue
				var t1: int = board[r][c]
				var t2: int = board[r2][c2]
				if not (MatchEngine.is_normal(t1) and MatchEngine.is_normal(t2)):
					continue
				if seal[r][c] or seal[r2][c2]:
					continue
				board[r][c] = t2
				board[r2][c2] = t1
				var res := MatchEngine.analyze_matches(board, {"r": r2, "c": c2})
				var has_broken := false
				if avoid_broken:
					for k in res.matched_cells.keys():
						var v := unkey(k)
						if board[v.x][v.y] == MatchEngine.BROKEN_IDX:
							has_broken = true
							break
				board[r][c] = t1
				board[r2][c2] = t2
				if res.matched_cells.is_empty():
					continue
				if not has_broken:
					return {"r1": r, "c1": c, "r2": r2, "c2": c2}
				if fallback.is_empty():
					fallback = {"r1": r, "c1": c, "r2": r2, "c2": c2}
	return fallback


## Every swap that makes a match (for the bot).
func all_swaps() -> Array:
	var out: Array = []
	for r in range(SIZE):
		for c in range(SIZE):
			for d in [Vector2i(0, 1), Vector2i(1, 0)]:
				var r2: int = r + d.y
				var c2: int = c + d.x
				if r2 >= SIZE or c2 >= SIZE or not swappable(r, c) or not swappable(r2, c2):
					continue
				var t1: int = board[r][c]
				var t2: int = board[r2][c2]
				if MatchEngine.is_special(t1) or MatchEngine.is_special(t2):
					out.append({"r1": r, "c1": c, "r2": r2, "c2": c2})
					continue
				board[r][c] = t2
				board[r2][c2] = t1
				var hit: bool = not MatchEngine.analyze_matches(board, {"r": r2, "c": c2}).matched_cells.is_empty()
				board[r][c] = t1
				board[r2][c2] = t2
				if hit:
					out.append({"r1": r, "c1": c, "r2": r2, "c2": c2})
	return out


func has_move() -> bool:
	for r in range(SIZE):
		for c in range(SIZE):
			if MatchEngine.is_special(board[r][c]):
				for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
					if in_board(r + d.x, c + d.y) and swappable(r + d.x, c + d.y):
						return true
	return not find_swap().is_empty()


# ------------------------------------------------------------ clearing

## Clears `cells` (Dictionary<"r,c" -> true>): a match when is_match (then
## seeds next to it grow), else a blast (special, Hammer, her power), which
## grows a seed it covers. Comb pieces never clear; a sealed gem loses its
## seal and stays; moss under every cell hit clears. Blossoms pop on the spot
## and clear around themselves. Removes the cleared gems from the board (-1)
## and returns what happened:
##   {gain, cleared (cells now empty), hit (all cells hit), shards, fav_hit,
##    least_hit, charm, seals: [Vector2i], items: [[Vector2i, name]],
##    grown: [Vector2i], blossoms: [Vector2i]}
## Points are before the combo multiplier, except blossoms (+100 flat, in
## "bonus"); found items in chapter 2 pay pieces.itemScore each (in "bonus").
func clear_cells(cells: Dictionary, is_match: bool) -> Dictionary:
	var rep := {"gain": 0, "bonus": 0, "cleared": {}, "hit": {}, "shards": 0, "fav_hit": false,
		"least_hit": false, "charm": 0, "seals": [], "items": [], "grown": [], "blossoms": []}
	var todo: Dictionary = cells.duplicate()
	# Seeds next to a match grow once each (her disliked gem doesn't count).
	if is_match:
		var grow := {}
		for k in cells.keys():
			var v := unkey(k)
			var t: int = board[v.x][v.y]
			if t == least:
				continue
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
				var n: Vector2i = v + d
				if in_board(n.x, n.y) and (board[n.x][n.y] == SEED or board[n.x][n.y] == SPROUT):
					grow[key(n.x, n.y)] = true
		for k in grow.keys():
			_grow(unkey(k), todo, rep)
	var done := {}
	while not todo.is_empty():
		var k: String = todo.keys()[0]
		todo.erase(k)
		if done.has(k):
			continue
		done[k] = true
		var v := unkey(k)
		var t: int = board[v.x][v.y]
		if t == COMB or t == -1:
			continue
		rep.hit[k] = true
		_clear_moss(v, rep)
		if t == SEED or t == SPROUT:
			if not is_match or not cells.has(k):
				_grow(v, todo, rep)
			continue
		if seal[v.x][v.y]:
			seal[v.x][v.y] = false
			seals_broken += 1
			rep.seals.append(v)
			_score_gem(t, rep)
			continue
		_score_gem(t, rep)
		rep.cleared[k] = true
		board[v.x][v.y] = -1
	return rep


func _score_gem(t: int, rep: Dictionary) -> void:
	if t == MatchEngine.BROKEN_IDX:
		rep.shards += 1
		rep.gain += SHARD_POINTS
	elif MatchEngine.is_special(t):
		rep.gain += SPECIAL_POINTS
	elif MatchEngine.is_normal(t):
		if t == fav:
			rep.gain += GEM_POINTS * 2
			rep.charm += 2
			rep.fav_hit = true
		elif t == least:
			rep.gain += GEM_POINTS / 2
			rep.charm += 1
			rep.least_hit = true
		else:
			rep.gain += GEM_POINTS
			rep.charm += 1


func _clear_moss(v: Vector2i, rep: Dictionary) -> void:
	var m: int = moss[v.x][v.y]
	if m == 0:
		return
	moss[v.x][v.y] = 0
	if m >= 2:
		items_found += 1
		rep.items.append([v, ITEMS[m - 2]])
		rep.bonus += int(pieces.get("itemScore", 0))


## seed -> sprout; sprout -> blossom, which pops: itself and the 8 around it.
func _grow(v: Vector2i, todo: Dictionary, rep: Dictionary) -> void:
	var t: int = board[v.x][v.y]
	if t == SEED:
		board[v.x][v.y] = SPROUT
		rep.grown.append(v)
	elif t == SPROUT:
		board[v.x][v.y] = -1
		blossoms += 1
		rep.blossoms.append(v)
		rep.bonus += BLOSSOM_POINTS
		rep.cleared[key(v.x, v.y)] = true
		rep.hit[key(v.x, v.y)] = true
		_clear_moss(v, rep)
		for dr in range(-1, 2):
			for dc in range(-1, 2):
				if (dr != 0 or dc != 0) and in_board(v.x + dr, v.y + dc):
					todo[key(v.x + dr, v.y + dc)] = true


## Gravity (down, or up on the tide) and new gems for the empty cells; comb
## pieces that reach the top row are collected. Returns {changed: cells that
## moved or are new, combs: [columns collected from]}.
func collapse() -> Dictionary:
	var changed := {}
	var combs: Array = []
	while true:
		for c in range(SIZE):
			var vals: Array = []
			var seals: Array = []
			var empty := false
			# Read from the "floor" side outwards.
			for i in range(SIZE):
				var r := (SIZE - 1 - i) if not gravity_up else i
				if board[r][c] == -1:
					empty = true
				else:
					vals.append(board[r][c])
					seals.append(seal[r][c])
			if not empty:
				continue
			for i in range(SIZE):
				var r := (SIZE - 1 - i) if not gravity_up else i
				var old: int = board[r][c]
				if i < vals.size():
					board[r][c] = vals[i]
					seal[r][c] = seals[i]
				else:
					board[r][c] = MatchEngine.weighted_rand_type(weights)
					seal[r][c] = false
				if old != board[r][c] or i >= vals.size():
					changed[key(r, c)] = true
		var again := false
		if gravity_up:
			for c in range(SIZE):
				if board[0][c] == COMB:
					board[0][c] = -1
					combs_up += 1
					combs.append(c)
					again = true
		if not again:
			break
	return {"changed": changed, "combs": combs}


## Where a new special goes: its cell, or the nearest plain gem that isn't
## sealed. Vector2i(-1, -1) if there's none.
func special_spot(r: int, c: int) -> Vector2i:
	if MatchEngine.is_normal(board[r][c]) and board[r][c] != MatchEngine.BROKEN_IDX and not seal[r][c]:
		return Vector2i(r, c)
	var best := Vector2i(-1, -1)
	var best_d := 999
	for rr in range(SIZE):
		for cc in range(SIZE):
			var t: int = board[rr][cc]
			if not MatchEngine.is_normal(t) or t == MatchEngine.BROKEN_IDX or seal[rr][cc]:
				continue
			var dist: int = absi(rr - r) + absi(cc - c)
			if dist < best_d:
				best_d = dist
				best = Vector2i(rr, cc)
	return best


## Places the specials a match earned (after its collapse); returns their cells.
func place_specials(specials: Array) -> Dictionary:
	var out := {}
	for sp in specials:
		var rr := int(sp.r)
		var cc := int(sp.c)
		if not in_board(rr, cc):
			continue
		var spot := special_spot(rr, cc)
		if spot.x < 0:
			continue
		board[spot.x][spot.y] = MatchEngine.special_code(String(sp.type))
		out[key(spot.x, spot.y)] = true
	return out


## After each of the player's moves: Hazel's seeds keep coming (pieces.every
## moves, while fewer than pieces.max are on the board). Returns the cell a
## new seed dropped into, or (-1, -1).
func after_move() -> Vector2i:
	moves_made += 1
	if mech != "seed":
		return Vector2i(-1, -1)
	var every := int(pieces.get("every", 0))
	if every <= 0 or moves_made % every != 0 or count(SEED) + count(SPROUT) >= int(pieces.get("max", 3)):
		return Vector2i(-1, -1)
	var cols := range(SIZE)
	cols.shuffle()
	for c in cols:
		var t: int = board[0][c]
		if MatchEngine.is_normal(t):
			board[0][c] = SEED
			if not has_move():
				board[0][c] = t
				continue
			return Vector2i(0, c)
	return Vector2i(-1, -1)


func count(t: int) -> int:
	var n := 0
	for row in board:
		n += (row as Array).count(t)
	return n


func seals_left() -> int:
	var n := 0
	for row in seal:
		n += (row as Array).count(true)
	return n


# ------------------------------------------------------------ her power

## True if the power needs a cell picked first.
func power_needs_pick() -> bool:
	return power_id == "lines" or power_id == "absorb"


## Whether (r, c) is a fair pick for the power.
func power_can_pick(r: int, c: int) -> bool:
	if power_id == "absorb":
		var t: int = board[r][c]
		return MatchEngine.is_normal(t)
	return power_id == "lines"


## The cells her power clears ({} for Summer, which grows instead: call
## summer()). lines: the picked row and column; absorb: every gem the
## picked colour; tide: the two rows nearest the surface.
func power_cells(r: int, c: int) -> Dictionary:
	var cells := {}
	match power_id:
		"lines":
			for i in range(SIZE):
				cells[key(r, i)] = true
				cells[key(i, c)] = true
		"absorb":
			var col: int = board[r][c]
			for rr in range(SIZE):
				for cc in range(SIZE):
					if board[rr][cc] == col:
						cells[key(rr, cc)] = true
		"tide":
			var rows := [0, 1] if gravity_up else [0, 1]
			for rr in rows:
				for cc in range(SIZE):
					cells[key(rr, cc)] = true
	return cells


## Summer: every seed and sprout grows one stage (sprouts pop).
func summer() -> Dictionary:
	var cells := {}
	for r in range(SIZE):
		for c in range(SIZE):
			if board[r][c] == SEED or board[r][c] == SPROUT:
				cells[key(r, c)] = true
	return clear_cells(cells, false)


# ------------------------------------------------------------ headless play

## A whole swap with its cascades, no animation (the bot, tests). Returns
## {valid, points, charm, shards}. PuzzleScreen runs the same steps itself,
## animating between them.
func play_swap(r1: int, c1: int, r2: int, c2: int) -> Dictionary:
	var out := {"valid": true, "points": 0, "charm": 0, "shards": 0}
	var t1: int = board[r1][c1]
	var t2: int = board[r2][c2]
	if MatchEngine.is_special(t1) or MatchEngine.is_special(t2):
		var cells := {key(r1, c1): true, key(r2, c2): true}
		if MatchEngine.is_special(t1):
			cells.merge(MatchEngine.detonation_cells(MatchEngine.special_kind(t1), r1, c1))
		if MatchEngine.is_special(t2):
			cells.merge(MatchEngine.detonation_cells(MatchEngine.special_kind(t2), r2, c2))
		_tally(clear_cells(cells, false), 1, out)
		collapse()
		_chain(MatchEngine.analyze_matches(board), 2, out)
		return out
	board[r1][c1] = t2
	board[r2][c2] = t1
	var res := MatchEngine.analyze_matches(board, {"r": r2, "c": c2})
	if res.matched_cells.is_empty():
		board[r1][c1] = t1
		board[r2][c2] = t2
		out.valid = false
		return out
	_chain(res, 1, out)
	return out


## A blast (Hammer, her power) with its cascades, no animation.
func play_blast(cells: Dictionary) -> Dictionary:
	var out := {"valid": true, "points": 0, "charm": 0, "shards": 0}
	_tally(clear_cells(cells, false), 1, out)
	collapse()
	_chain(MatchEngine.analyze_matches(board), 2, out)
	return out


func _chain(res: Dictionary, combo: int, out: Dictionary) -> void:
	while not res.matched_cells.is_empty():
		_tally(clear_cells(res.matched_cells, true), combo, out)
		collapse()
		place_specials(res.specials)
		res = MatchEngine.analyze_matches(board)
		combo += 1


static func combo_points(gain: int, combo: int) -> int:
	return int(round(float(gain) * (1.0 + 0.5 * float(combo - 1))))


func _tally(rep: Dictionary, combo: int, out: Dictionary) -> void:
	out.points += combo_points(int(rep.gain), combo) + int(rep.bonus)
	out.charm += int(rep.charm)
	out.shards += int(rep.shards)


# ------------------------------------------------------------ the goal

func goal_progress() -> int:
	match goal_kind:
		"seals": return seals_broken
		"combs": return combs_up
		"items": return items_found
		"blossoms": return blossoms
	return 0


func goal_met() -> bool:
	return goal_kind == "" or goal_progress() >= goal_n


func won(score: int) -> bool:
	return goal_met() and score >= target

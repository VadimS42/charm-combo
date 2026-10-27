## MatchEngine.gd
##
## Pure, stateless match-3 grid logic — no nodes, no rendering, no game state.
## This is a direct, function-for-function port of the "ENGINE-PURE" block
## from the original HTML/JS prototype (game.html), so the rules (what counts
## as a match, how L/T shapes spawn a Starburst, how a run of 4 spawns a
## Rocket, how broken hearts never spawn specials, how gravity refills the
## board) are identical to the version that was designed and playtested there.
##
## Being pure functions with no engine-node dependencies, this file is also
## trivially unit-testable from a GUT/GdUnit test script or a throwaway
## scene — feed it a board Array and assert on the returned Dictionary.
class_name MatchEngine
extends RefCounted

const N_TYPES := 7
const HEART_IDX := 0
const STAR_IDX := 1
const BROKEN_IDX := 6
const SIZE := 8
const ROCKET_H := 100
const ROCKET_V := 101
const STARBURST := 102
const CHARM_MAX := 24
const DEFAULT_WEIGHTS := [10, 10, 10, 10, 10, 10, 2]

# Sentinel used only inside scan_line_runs() to mark "one past the last cell"
# so a run touching the edge of the board still gets flushed. Distinct from
# every real gem type (0..6) and every special code (100..102).
const _END_SENTINEL := -999


static func is_normal(t: int) -> bool:
	return t >= 0 and t < N_TYPES


static func is_special(t: int) -> bool:
	return t == ROCKET_H or t == ROCKET_V or t == STARBURST


static func special_kind(t: int) -> String:
	if t == ROCKET_H:
		return "rocket-h"
	if t == ROCKET_V:
		return "rocket-v"
	return "starburst"


static func special_code(kind: String) -> int:
	if kind == "rocket-h":
		return ROCKET_H
	if kind == "rocket-v":
		return ROCKET_V
	return STARBURST


static func weighted_rand_type(weights = null) -> int:
	var w: Array = weights if weights != null else DEFAULT_WEIGHTS
	var total := 0.0
	for x in w:
		total += x
	var roll := randf() * total
	for i in range(w.size()):
		roll -= w[i]
		if roll < 0.0:
			return i
	return w.size() - 1


## Builds a fresh SIZE x SIZE board with no pre-existing 3-in-a-row runs.
static func build_board(weights = null) -> Array:
	var b: Array = []
	for r in range(SIZE):
		b.append([])
		for c in range(SIZE):
			var t: int
			while true:
				t = weighted_rand_type(weights)
				var bad: bool = (c >= 2 and b[r][c - 1] == t and b[r][c - 2] == t) \
					or (r >= 2 and b[r - 1][c] == t and b[r - 2][c] == t)
				if not bad:
					break
			b[r].append(t)
	return b


## Scans one line (row or column) of length SIZE via get_cell(i) -> int.
## Returns an Array of Dictionaries {start, end, len, color} for every run
## of length >= 3 of a *normal* (non-special) color.
static func scan_line_runs(get_cell: Callable) -> Array:
	var runs: Array = []
	var start := 0
	var cur_type: int = get_cell.call(0)
	for i in range(1, SIZE + 1):
		var t: int = get_cell.call(i) if i < SIZE else _END_SENTINEL
		if t != cur_type:
			var len_ := i - start
			if len_ >= 3 and is_normal(cur_type):
				runs.append({"start": start, "end": i - 1, "len": len_, "color": cur_type})
			start = i
			cur_type = t
	return runs


## Analyzes the board for matches. swap_dest (optional {r,c} Dictionary) is
## preferred as the spawn location for any newly-created special gem — it's
## where the player's swap landed, which feels more intentional than the
## middle of the run.
##
## Returns { "matched_cells": Dictionary<"r,c" -> true>, "specials": Array }
## where each special is {r, c, type: "rocket-h"|"rocket-v"|"starburst"}.
static func analyze_matches(board: Array, swap_dest = null) -> Dictionary:
	var horiz: Array = []
	var vert: Array = []

	for r in range(SIZE):
		var row_runs := scan_line_runs(func(c: int): return board[r][c])
		for run in row_runs:
			run["r"] = r
			horiz.append(run)

	for c in range(SIZE):
		var col_runs := scan_line_runs(func(r: int): return board[r][c])
		for run in col_runs:
			run["c"] = c
			vert.append(run)

	var matched_cells := {}
	for h in horiz:
		for c in range(h.start, h.end + 1):
			matched_cells[str(h.r) + "," + str(c)] = true
	for v in vert:
		for r in range(v.start, v.end + 1):
			matched_cells[str(r) + "," + str(v.c)] = true

	var used_h := {}
	var used_v := {}
	var specials: Array = []

	# 1) L/T intersections -> a Starburst at the crossing cell. Each horizontal
	#    run pairs with at most one vertical run (the first unused crossing).
	for hi in range(horiz.size()):
		if used_h.has(hi):
			continue
		var h = horiz[hi]
		for vi in range(vert.size()):
			if used_v.has(vi):
				continue
			var v = vert[vi]
			var row_in_range: bool = h.r >= v.start and h.r <= v.end
			var col_in_range: bool = v.c >= h.start and v.c <= h.end
			if row_in_range and col_in_range and h.color != BROKEN_IDX:
				used_h[hi] = true
				used_v[vi] = true
				specials.append({"r": h.r, "c": v.c, "type": "starburst"})
				break

	# 2) Remaining runs of length >= 4 -> a Rocket (len 4) or Starburst (len 5+).
	#    Broken-heart runs never spawn a special, however long — a broken-heart
	#    starburst would be an unfairly harsh punishment for the player.
	for hi in range(horiz.size()):
		if used_h.has(hi):
			continue
		var h = horiz[hi]
		if h.len < 4 or h.color == BROKEN_IDX:
			continue
		var spawn_c: int = int(floor((h.start + h.end) / 2.0))
		if swap_dest != null and swap_dest.r == h.r and swap_dest.c >= h.start and swap_dest.c <= h.end:
			spawn_c = swap_dest.c
		specials.append({"r": h.r, "c": spawn_c, "type": ("starburst" if h.len >= 5 else "rocket-h")})

	for vi in range(vert.size()):
		if used_v.has(vi):
			continue
		var v = vert[vi]
		if v.len < 4 or v.color == BROKEN_IDX:
			continue
		var spawn_r: int = int(floor((v.start + v.end) / 2.0))
		if swap_dest != null and swap_dest.c == v.c and swap_dest.r >= v.start and swap_dest.r <= v.end:
			spawn_r = swap_dest.r
		specials.append({"r": spawn_r, "c": v.c, "type": ("starburst" if v.len >= 5 else "rocket-v")})

	return {"matched_cells": matched_cells, "specials": specials}


## Cells cleared by detonating a special gem of the given kind at (r, c).
## Returns Dictionary<"r,c" -> true> (used as a Set).
static func detonation_cells(kind: String, r: int, c: int) -> Dictionary:
	var cells := {}
	if kind == "rocket-h":
		for c2 in range(SIZE):
			cells[str(r) + "," + str(c2)] = true
	elif kind == "rocket-v":
		for r2 in range(SIZE):
			cells[str(r2) + "," + str(c)] = true
	else:  # starburst: 3x3 block centered on (r, c)
		for dr in range(-1, 2):
			for dc in range(-1, 2):
				var rr := r + dr
				var cc := c + dc
				if rr >= 0 and rr < SIZE and cc >= 0 and cc < SIZE:
					cells[str(rr) + "," + str(cc)] = true
	return cells


## Removes every cell in matched_set (Dictionary<"r,c" -> true>) from the
## board IN PLACE, then gravity-collapses each affected column and refills
## the gaps at the top with new normal-colored gems.
## Returns Dictionary<"r,c" -> true> of every cell that changed (for
## drop-in animation on the caller's side).
static func collapse_and_refill(board: Array, matched_set: Dictionary, weights = null) -> Dictionary:
	var changed_cols := {}
	for key in matched_set.keys():
		var parts: PackedStringArray = key.split(",")
		var r := int(parts[0])
		var c := int(parts[1])
		board[r][c] = -1
		changed_cols[c] = true

	var changed := {}
	for c in changed_cols.keys():
		var col: Array = []
		for r in range(SIZE):
			if board[r][c] != -1:
				col.append(board[r][c])
		var missing: int = SIZE - col.size()
		var new_vals: Array = []
		for i in range(missing):
			new_vals.append(weighted_rand_type(weights))
		var full: Array = new_vals + col
		for r in range(SIZE):
			board[r][c] = full[r]
			changed[str(r) + "," + str(c)] = true
	return changed


## Returns the first swap {r1,c1,r2,c2} that would produce a match, or an
## empty Dictionary if the board has no legal move at all. Used both for the
## idle "here's a move" hint and for deadlock detection (new features — the
## original HTML prototype had neither, so there's no port to match here).
## Cheap enough for an 8x8 board to just brute-force every adjacent pair.
static func find_valid_swap(board: Array) -> Dictionary:
	for r in range(SIZE):
		for c in range(SIZE):
			for d in [Vector2i(0, 1), Vector2i(1, 0)]:
				var r2: int = r + d.y
				var c2: int = c + d.x
				if r2 >= SIZE or c2 >= SIZE:
					continue
				var t1: int = board[r][c]
				var t2: int = board[r2][c2]
				# A swap involving a special is always "valid" in the sense
				# that it detonates something, but that's not a match-hint
				# in the usual sense — only consider swaps of two normal gems.
				if not (is_normal(t1) and is_normal(t2)):
					continue
				board[r][c] = t2
				board[r2][c2] = t1
				var result := analyze_matches(board, {"r": r2, "c": c2})
				board[r][c] = t1
				board[r2][c2] = t2
				if not result.matched_cells.is_empty():
					return {"r1": r, "c1": c, "r2": r2, "c2": c2}
	return {}


## True if any legal move exists anywhere on the board.
static func has_valid_move(board: Array) -> bool:
	return not find_valid_swap(board).is_empty()

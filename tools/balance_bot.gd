## balance_bot.gd — plays every chapter many times with a simple greedy bot
## (no items) and reports how often it clears each one, plus a fuzz test of
## starting boards (round 25). Uses the game's own MatchEngine and scoring
## rules (PuzzleScreen._score_and_clear: 10 a gem, -15 a cursed shard, 25 a
## special, x(1 + 0.5 per combo step), +150 Charm Burst at 24 charm).
##
## Run (from the project folder; takes a minute or two):
##   godot --headless --path . -s tools/balance_bot.gd
## Options after `--`: runs=300 fuzz=10000 seed=1
## The bot looks one move ahead: it picks the swap that clears the most (and
## makes specials when it can), the way a casual player does, not an expert.
extends SceneTree

var runs := 300
var fuzz := 10000


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() == 2:
			match kv[0]:
				"runs": runs = int(kv[1])
				"fuzz": fuzz = int(kv[1])
				"seed": seed(int(kv[1]))
	call_deferred("_main")


func _main() -> void:
	var gs = root.get_node("GameState")
	gs.items = {}  # no Favor Charm / Heart Mender: plain chapters
	_fuzz_boards()
	print("")
	print("| Girl | Ch | Target | Moves | Win % (warm reply) | Win % (teasing reply) | Avg score (warm) |")
	print("|---|---|---|---|---|---|---|")
	for ch in CharacterData.all():
		var levels: Array = ch.story.levels
		for i in range(levels.size()):
			var lv: Dictionary = levels[i]
			var target := int(lv.target)
			var moves := int(lv.moves)
			var weights := CharacterData.compute_weights(ch, i)
			var warm := _play_many(ch, weights, moves, target, _bonus(ch, i, "warmth"))
			var tease := _play_many(ch, weights, moves, target, _bonus(ch, i, "spark"))
			print("| %s | %d | %d | %d | %d%% | %d%% | %d |" % [String(ch.name).split(" ")[0], i + 1, target, moves,
				roundi(warm.win * 100.0), roundi(tease.win * 100.0), roundi(warm.avg)])
	quit()


## The starting bonus a chapter gets from the reply before it.
func _bonus(ch: Dictionary, level_i: int, stat: String) -> int:
	var choice = ch.story.get("introChoice") if level_i == 0 else ch.story.levels[level_i - 1].get("choice")
	if typeof(choice) != TYPE_DICTIONARY:
		return 0
	for o in choice.options:
		if String(o.get("stat", "")) == stat:
			return int(o.get("bonus", 0))
	return 0


func _play_many(ch: Dictionary, weights: Array, moves: int, target: int, bonus: int) -> Dictionary:
	var wins := 0
	var total := 0
	for n in range(runs):
		var s := _play(ch, weights, moves, target, bonus)
		total += s
		if s >= target:
			wins += 1
	return {"win": float(wins) / runs, "avg": float(total) / runs}


# ---------------------------------------------------------------- one chapter

var _board: Array
var _score: int
var _charm: int
var _fav: int
var _weights: Array


func _play(ch: Dictionary, weights: Array, moves: int, target: int, bonus: int) -> int:
	_weights = weights
	_board = _fresh_board()
	_score = bonus
	_charm = 0
	_fav = CharacterData.gem_index_from_id(String(ch.fav))
	for m in range(moves):
		if _score >= target:
			break
		var mv := _best_move()
		if mv.is_empty():
			_board = _fresh_board()
			continue
		_do_move(mv)
		if not MatchEngine.has_valid_move(_board):
			_board = _fresh_board()
	return _score


func _fresh_board() -> Array:
	var b := MatchEngine.build_board(_weights)
	var tries := 0
	while not MatchEngine.has_valid_move(b) and tries < 50:
		b = MatchEngine.build_board(_weights)
		tries += 1
	return b


## Greedy: every swap of two neighbours, valued by what it clears right away.
func _best_move() -> Dictionary:
	var best := {}
	var best_v := -INF
	var S := MatchEngine.SIZE
	for r in range(S):
		for c in range(S):
			for d in [Vector2i(0, 1), Vector2i(1, 0)]:
				var r2: int = r + d.x
				var c2: int = c + d.y
				if r2 >= S or c2 >= S:
					continue
				var v := _value(r, c, r2, c2)
				if v == -INF:
					continue
				v += randf() * 0.5  # break ties at random
				if v > best_v:
					best_v = v
					best = {"r1": r, "c1": c, "r2": r2, "c2": c2}
	return best


func _value(r1: int, c1: int, r2: int, c2: int) -> float:
	var t1: int = _board[r1][c1]
	var t2: int = _board[r2][c2]
	if MatchEngine.is_special(t1) or MatchEngine.is_special(t2):
		var cells := {}
		if MatchEngine.is_special(t1):
			cells.merge(MatchEngine.detonation_cells(MatchEngine.special_kind(t1), r1, c1))
		if MatchEngine.is_special(t2):
			cells.merge(MatchEngine.detonation_cells(MatchEngine.special_kind(t2), r2, c2))
		return float(_cells_value(cells))
	if t1 == t2:
		return -INF
	_board[r1][c1] = t2
	_board[r2][c2] = t1
	var v := 0.0
	for p in [[r1, c1], [r2, c2]]:
		var col: int = _board[p[0]][p[1]]
		var h := _run(p[0], p[1], 0, 1, col)
		var vv := _run(p[0], p[1], 1, 0, col)
		var n := 0
		if h >= 3:
			n += h
		if vv >= 3:
			n += vv
		if n == 0:
			continue
		var each := -15.0 if col == MatchEngine.BROKEN_IDX else (12.0 if col == _fav else 10.0)
		v += n * each
		if col != MatchEngine.BROKEN_IDX:
			if h >= 5 or vv >= 5 or (h >= 3 and vv >= 3):
				v += 80.0
			elif h >= 4 or vv >= 4:
				v += 40.0
	_board[r1][c1] = t1
	_board[r2][c2] = t2
	return v if v != 0.0 else -INF


## Length of the run of `col` through (r, c) along (dr, dc).
func _run(r: int, c: int, dr: int, dc: int, col: int) -> int:
	if not MatchEngine.is_normal(col):
		return 0
	var n := 1
	var rr := r + dr
	var cc := c + dc
	while rr < MatchEngine.SIZE and cc < MatchEngine.SIZE and _board[rr][cc] == col:
		n += 1
		rr += dr
		cc += dc
	rr = r - dr
	cc = c - dc
	while rr >= 0 and cc >= 0 and _board[rr][cc] == col:
		n += 1
		rr -= dr
		cc -= dc
	return n


func _cells_value(cells: Dictionary) -> int:
	var v := 0
	for key in cells.keys():
		var p := String(key).split(",")
		var t: int = _board[int(p[0])][int(p[1])]
		v += -15 if t == MatchEngine.BROKEN_IDX else (25 if MatchEngine.is_special(t) else 10)
	return v


## The move, exactly as PuzzleScreen plays it (minus the animation).
func _do_move(mv: Dictionary) -> void:
	var r1: int = mv.r1
	var c1: int = mv.c1
	var r2: int = mv.r2
	var c2: int = mv.c2
	var t1: int = _board[r1][c1]
	var t2: int = _board[r2][c2]
	if MatchEngine.is_special(t1) or MatchEngine.is_special(t2):
		var cells := {}
		if MatchEngine.is_special(t1):
			cells.merge(MatchEngine.detonation_cells(MatchEngine.special_kind(t1), r1, c1))
		if MatchEngine.is_special(t2):
			cells.merge(MatchEngine.detonation_cells(MatchEngine.special_kind(t2), r2, c2))
		cells[str(r1) + "," + str(c1)] = true
		cells[str(r2) + "," + str(c2)] = true
		_score_cells(cells, 1)
		MatchEngine.collapse_and_refill(_board, cells, _weights)
		var next := MatchEngine.analyze_matches(_board)
		if not next.matched_cells.is_empty():
			_resolve(next, 2)
		return
	_board[r1][c1] = t2
	_board[r2][c2] = t1
	var first := MatchEngine.analyze_matches(_board, {"r": r2, "c": c2})
	if first.matched_cells.is_empty():
		_board[r1][c1] = t1
		_board[r2][c2] = t2
		return
	_resolve(first, 1)


func _resolve(result: Dictionary, combo: int) -> void:
	while not result.matched_cells.is_empty():
		_score_cells(result.matched_cells, combo)
		MatchEngine.collapse_and_refill(_board, result.matched_cells, _weights)
		for sp in result.specials:
			var rr: int = int(sp.r)
			var cc: int = int(sp.c)
			if rr >= 0 and rr < MatchEngine.SIZE and cc >= 0 and cc < MatchEngine.SIZE \
					and MatchEngine.is_normal(_board[rr][cc]) and _board[rr][cc] != MatchEngine.BROKEN_IDX:
				_board[rr][cc] = MatchEngine.special_code(String(sp.type))
		result = MatchEngine.analyze_matches(_board)
		combo += 1


func _score_cells(cells: Dictionary, combo: int) -> void:
	var gain := 0
	for key in cells.keys():
		var p := String(key).split(",")
		var t: int = _board[int(p[0])][int(p[1])]
		if t == MatchEngine.BROKEN_IDX:
			gain -= 15
		elif MatchEngine.is_special(t):
			gain += 25
		else:
			gain += 10
			_charm = mini(MatchEngine.CHARM_MAX, _charm + (2 if t == _fav else 1))
	_score += roundi(gain * (1.0 + 0.5 * (combo - 1)))
	if _charm >= MatchEngine.CHARM_MAX:
		_charm = 0
		_score += 150


# ---------------------------------------------------------------- board fuzz

func _fuzz_boards() -> void:
	var no_move := 0
	var premade := 0
	var no_move_after_retry := 0
	for i in range(fuzz):
		var w: Array = MatchEngine.DEFAULT_WEIGHTS.duplicate()
		w[MatchEngine.BROKEN_IDX] = 2.0 + float(i % 4) * 1.2  # chapters 1-4
		var b := MatchEngine.build_board(w)
		if not MatchEngine.analyze_matches(b).matched_cells.is_empty():
			premade += 1
		if not MatchEngine.has_valid_move(b):
			no_move += 1
			# The game rebuilds until there's a move (_fresh_playable_board).
			var ok := false
			for t in range(50):
				if MatchEngine.has_valid_move(MatchEngine.build_board(w)):
					ok = true
					break
			if not ok:
				no_move_after_retry += 1
	print("Board fuzz: %d boards, cursed shard rate per chapter 1-4" % fuzz)
	print("  pre-made matches: %d" % premade)
	print("  no valid move as built: %d (rebuilt by the game)" % no_move)
	print("  no valid move even after rebuilding: %d" % no_move_after_retry)

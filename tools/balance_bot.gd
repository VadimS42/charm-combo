## balance_bot.gd — plays the chapters many times with bots and reports how
## often they clear each one, with and without power-ups, plus a whole-story
## "campaign" with the star economy and a fuzz test of starting boards.
## Uses the game's own MatchEngine and scoring rules (PuzzleScreen.
## _score_and_clear: 10 a gem, -15 a cursed shard, 25 a special,
## x(1 + 0.5 per combo step), +150 Charm Burst at 24 charm) and the Item
## Shop's power-ups exactly as PuzzleScreen applies them (round 33).
##
## Run (from the project folder; a few minutes per mode):
##   godot --headless --path . -s tools/balance_bot.gd -- mode=plain
## Options after `--`:
##   mode=plain     win % per chapter with no power-ups, both bots
##   mode=items     win % per chapter with each power-up (casual bot)
##   mode=campaign  a player going through one girl's story: losses pay
##                  consolation stars, stars buy power-ups, and when they're
##                  short they replay chapter 1 for stars (Replay Chapter)
##   mode=fuzz      starting-board fuzz only
##   mode=dist      casual bot's final score (all moves played, no reply
##                  bonus) at the 10th..90th percentile, per chapter and
##                  power-up: a target at the 70th percentile = 30% win
##   runs=300 fuzz=10000 seed=1 girl=dryad
##   targets=700,1000,1300,1500 moves=15,15,16,18   try numbers without
##                  editing data/characters.json
##
## The bots: "careful" looks one move ahead and always picks the swap that
## clears the most (and makes specials when it can). "casual" does that only
## 55% of the time and otherwise makes any match it sees, the way someone
## playing on the couch does. Real players land in between, nearer casual.
extends SceneTree

var runs := 300
var fuzz := 10000
var mode := "all"
var girl := "dryad"
var targets: Array = []
var move_counts: Array = []

const CASUAL_GREEDY := 0.55
## Stars, from StoreScreen.ITEMS.
var PRICES := {}
## The game's StoryFlow / PuzzleScreen / StoreScreen scripts. Reloaded once the
## autoloads exist: under -s they're first compiled before GameState is
## registered, and that first compile fails.
var _story
var _puzzle
const KITS := [
	["none", {}],
	["+3 Moves", {"moves": 1}],
	["Hammer", {"hammer": 1}],
	["Shuffle", {"shuffle": 1}],
	["Starburst Starter", {"colorBomb": 1}],
	["Favor Charm", {"favorCharm": 1}],
	["Heart Mender", {"heartMender": 1}],
	["+3 Moves x2", {"moves": 2}],
	["Favor + Mender", {"favorCharm": 1, "heartMender": 1}],
	["Favor + Mender + Moves", {"favorCharm": 1, "heartMender": 1, "moves": 1}],
	["Favor + Mender + Moves x2", {"favorCharm": 1, "heartMender": 1, "moves": 2}],
	["one of everything", {"moves": 1, "hammer": 1, "shuffle": 1, "colorBomb": 1, "favorCharm": 1, "heartMender": 1}],
]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=")
		if kv.size() == 2:
			match kv[0]:
				"runs": runs = int(kv[1])
				"fuzz": fuzz = int(kv[1])
				"seed": seed(int(kv[1]))
				"mode": mode = kv[1]
				"girl": girl = kv[1]
				"targets": targets = Array(kv[1].split(",")).map(func(x): return int(x))
				"moves": move_counts = Array(kv[1].split(",")).map(func(x): return int(x))
	call_deferred("_main")


func _main() -> void:
	var gs = root.get_node("GameState")
	gs.items = {}
	var store = load("res://scripts/screens/StoreScreen.gd")
	store.reload(true)
	_story = load("res://scripts/StoryFlow.gd")
	_story.reload(true)
	_puzzle = load("res://scripts/screens/PuzzleScreen.gd")
	_puzzle.reload(true)
	for it in store.ITEMS:
		PRICES[String(it.id)] = int(it.price)
	if mode in ["all", "fuzz"]:
		_fuzz_boards()
	if mode in ["all", "plain"]:
		_plain_table()
	if mode in ["all", "items"]:
		_items_table()
	if mode in ["all", "campaign"]:
		_campaign()
	if mode == "dist":
		_dist_table()
	quit()


func _target(ch: Dictionary, i: int) -> int:
	return int(targets[i]) if i < targets.size() else int(ch.story.levels[i].target)


func _moves(ch: Dictionary, i: int) -> int:
	return int(move_counts[i]) if i < move_counts.size() else int(ch.story.levels[i].moves)


## The starting bonus a chapter gets from the reply before it.
func _bonus(ch: Dictionary, level_i: int, stat: String) -> int:
	var choice = ch.story.get("introChoice") if level_i == 0 else ch.story.levels[level_i - 1].get("choice")
	if typeof(choice) != TYPE_DICTIONARY:
		return 0
	for o in choice.options:
		if String(o.get("stat", "")) == stat:
			return int(o.get("bonus", 0))
	return 0


# ---------------------------------------------------------------- tables

func _plain_table() -> void:
	print("")
	print("No power-ups. Warm reply = +bonus start, teasing reply = -40 start.")
	print("| Girl | Ch | Target | Moves | Careful warm | Careful teasing | Casual warm | Casual teasing |")
	print("|---|---|---|---|---|---|---|---|")
	for ch in CharacterData.all():
		for i in range(ch.story.levels.size()):
			var row := []
			for skill in ["careful", "casual"]:
				for stat in ["warmth", "spark"]:
					row.append("%d%%" % roundi(_win_rate(ch, i, {}, skill, _bonus(ch, i, stat)) * 100.0))
			print("| %s | %d | %d | %d | %s |" % [String(ch.name).split(" ")[0], i + 1, _target(ch, i), _moves(ch, i),
				" | ".join(row)])


func _items_table() -> void:
	var ch := CharacterData.by_id(girl)
	var levels: Array = ch.story.levels
	print("")
	print("Casual bot, %s, reply bonus picked at random. Win %% with each power-up:" % String(ch.name).split(" ")[0])
	var head := "| Power-ups | Stars |"
	var line := "|---|---|"
	for i in range(levels.size()):
		head += " Ch%d (%d / %d) |" % [i + 1, _target(ch, i), _moves(ch, i)]
		line += "---|"
	print(head)
	print(line)
	for kit in KITS:
		var cost := 0
		for k in kit[1].keys():
			cost += int(PRICES[k]) * int(kit[1][k])
		var row := "| %s | %d |" % [kit[0], cost]
		for i in range(levels.size()):
			row += " %d%% |" % roundi(_win_rate(ch, i, kit[1], "casual", -1) * 100.0)
		print(row)


func _dist_table() -> void:
	var ch := CharacterData.by_id(girl)
	print("")
	print("| Ch | Moves | Power-ups | p10 | p25 | p50 | p60 | p70 | p80 | p90 |")
	print("|---|---|---|---|---|---|---|---|---|---|")
	for i in range(ch.story.levels.size()):
		for kit in [KITS[0], KITS[1], KITS[5], KITS[6], KITS[8], KITS[9]]:
			var scores := []
			for n in range(runs):
				scores.append(_play(ch, i, kit[1], "casual", 0, 1 << 30).score)
			scores.sort()
			var row := "| %d | %d | %s |" % [i + 1, _moves(ch, i), kit[0]]
			for q in [0.1, 0.25, 0.5, 0.6, 0.7, 0.8, 0.9]:
				row += " %d |" % scores[mini(scores.size() - 1, int(q * scores.size()))]
			print(row)


## bonus -1 = pick the warm or teasing reply's bonus at random each run.
func _win_rate(ch: Dictionary, i: int, kit: Dictionary, skill: String, bonus: int) -> float:
	var wins := 0
	for n in range(runs):
		var b := bonus
		if bonus == -1:
			b = _bonus(ch, i, "warmth" if randf() < 0.5 else "spark")
		if _play(ch, i, kit, skill, b).won:
			wins += 1
	return float(wins) / runs


# ---------------------------------------------------------------- campaign

## What the player buys, best value first (from mode=items), and how many
## stars they want in hand before a chapter (Favor Charm + Heart Mender).
const SHOP_ORDER := ["favorCharm", "heartMender", "moves", "moves"]
const MAX_FARM := 6


## One player through one girl's story, using the game's own star rules
## (StoryFlow.clear_stars / replay_stars, PuzzleScreen.consolation_stars).
## From chapter 3 on they shop before every try with what they have; after
## a loss, if that's short of Favor Charm + Heart Mender, they first replay
## chapter 1 for stars (up to MAX_FARM times per chapter).
func _campaign() -> void:
	var ch := CharacterData.by_id(girl)
	var n_levels: int = ch.story.levels.size()
	var players := maxi(40, runs / 3)
	var attempts := []
	var farm := []
	var bought := []
	var skipped := []
	for i in range(n_levels):
		attempts.append(0)
		farm.append(0)
		bought.append(0)
		skipped.append(0)
	var first_try := []
	for i in range(n_levels):
		first_try.append(0)
	for p in range(players):
		var stars := 0
		var farm_n := []
		farm_n.resize(n_levels)
		farm_n.fill(0)
		for i in range(n_levels):
			var losses := 0
			var tries := 0
			while true:
				tries += 1
				var kit := {}
				var want := int(PRICES.favorCharm) + int(PRICES.heartMender)
				if i >= 2 or losses > 0:
					if losses > 0 and i >= 1:
						while stars < want and farm_n[i] < MAX_FARM:
							farm_n[i] += 1
							farm[i] += 1
							if _play(ch, 0, {}, "casual", 0).won:
								stars += _story.replay_stars(0)
							else:
								stars += _puzzle.consolation_stars(_score)
					for k in SHOP_ORDER:
						if stars >= int(PRICES[k]):
							stars -= int(PRICES[k])
							kit[k] = int(kit.get(k, 0)) + 1
							bought[i] += 1
				var bonus := _bonus(ch, i, "warmth" if randf() < 0.5 else "spark")
				var res := _play(ch, i, kit, "casual", bonus)
				if res.won:
					if tries == 1:
						first_try[i] += 1
					stars += _story.clear_stars(i)
					break
				losses += 1
				stars += _puzzle.consolation_stars(res.score)
				if losses >= 6:
					skipped[i] += 1  # "Continue the story" (offered from 3 losses)
					break
			attempts[i] += tries
	print("")
	print("Campaign: %d casual players through %s's story, starting with 0 stars. From chapter 3"
		% [players, String(ch.name).split(" ")[0]])
	print("(or after a loss) they spend what they have on power-ups; after a loss, under %d stars,"
		% (PRICES.favorCharm + PRICES.heartMender))
	print("they first replay chapter 1 (%d stars a clear, up to %d times a chapter)."
		% [_story.replay_stars(0), MAX_FARM])
	print("| Ch | Cleared first try | Avg tries | Power-ups bought per player | Ch 1 replays per player | Gave up (6 losses) |")
	print("|---|---|---|---|---|---|")
	for i in range(n_levels):
		print("| %d | %d%% | %.1f | %.1f | %.1f | %d%% |" % [i + 1, roundi(100.0 * first_try[i] / players),
			float(attempts[i]) / players, float(bought[i]) / players, float(farm[i]) / players,
			roundi(100.0 * skipped[i] / players)])


# ---------------------------------------------------------------- one chapter

var _board: Array
var _score: int
var _charm: int
var _fav: int
var _weights: Array


## Plays chapter i once. kit = power-ups bought for it (as in GameState.items).
func _play(ch: Dictionary, i: int, kit: Dictionary, skill: String, bonus: int, target := -1) -> Dictionary:
	if target < 0:
		target = _target(ch, i)
	var moves := _moves(ch, i)
	# CharacterData.compute_weights reads the one-chapter boosts from items.
	var gs = root.get_node("GameState")
	gs.items = {"favorCharm": int(kit.get("favorCharm", 0)), "heartMender": int(kit.get("heartMender", 0))}
	_weights = CharacterData.compute_weights(ch, i)
	gs.items = {}
	_board = _fresh_board()
	if int(kit.get("colorBomb", 0)) > 0:
		_board[2 + randi() % 4][2 + randi() % 4] = MatchEngine.STARBURST
	_score = bonus
	_charm = 0
	_fav = CharacterData.gem_index_from_id(String(ch.fav))
	var extra := int(kit.get("moves", 0))
	var hammers := int(kit.get("hammer", 0))
	var shuffles := int(kit.get("shuffle", 0))
	var m := 0
	while true:
		if _score >= target:
			break
		if m >= moves:
			# Out of moves: hammers first (they don't cost a move), then +3 Moves.
			while hammers > 0 and _score < target:
				hammers -= 1
				_hammer()
			if _score >= target:
				break
			if extra > 0:
				extra -= 1
				moves += 3
				continue
			break
		var mv := _pick_move(skill)
		if mv.is_empty():
			_board = _fresh_board()
			continue
		# A poor board: a Shuffle instead (free, no move spent).
		if shuffles > 0 and float(mv.v) < 25.0:
			shuffles -= 1
			_board = _fresh_board()
			continue
		_do_move(mv)
		m += 1
		if not MatchEngine.has_valid_move(_board):
			_board = _fresh_board()
	return {"won": _score >= target, "score": _score}


func _fresh_board() -> Array:
	var b := MatchEngine.build_board(_weights)
	var tries := 0
	while not MatchEngine.has_valid_move(b) and tries < 50:
		b = MatchEngine.build_board(_weights)
		tries += 1
	return b


## Every swap of two neighbours, valued by what it clears right away. The
## careful bot takes the best; the casual one sometimes takes any match.
func _pick_move(skill: String) -> Dictionary:
	var best := {}
	var best_v := -INF
	var all := []
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
				var mv := {"r1": r, "c1": c, "r2": r2, "c2": c2, "v": v}
				all.append(mv)
				v += randf() * 0.5  # break ties at random
				if v > best_v:
					best_v = v
					best = mv
	if skill == "casual" and not all.is_empty() and randf() > CASUAL_GREEDY:
		return all[randi() % all.size()]
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


## The Hammer as PuzzleScreen plays it: pops one gem (a special goes off, a
## cursed shard is smashed for free), then the board settles and chains.
## The bot tries every cell on a copy of the board and keeps the best.
func _hammer() -> void:
	var keep_board := _board.duplicate(true)
	var keep_score := _score
	var keep_charm := _charm
	var best := Vector2i(-1, -1)
	var best_gain := -INF
	for r in range(MatchEngine.SIZE):
		for c in range(MatchEngine.SIZE):
			_hammer_at(r, c)
			var gain := float(_score - keep_score) + randf() * 0.5
			if gain > best_gain:
				best_gain = gain
				best = Vector2i(r, c)
			_board = keep_board.duplicate(true)
			_score = keep_score
			_charm = keep_charm
	_hammer_at(best.x, best.y)


func _hammer_at(r: int, c: int) -> void:
	var hit: int = _board[r][c]
	var cells := {str(r) + "," + str(c): true}
	if MatchEngine.is_special(hit):
		cells.merge(MatchEngine.detonation_cells(MatchEngine.special_kind(hit), r, c))
	if hit != MatchEngine.BROKEN_IDX:
		_score_cells(cells, 1)
	MatchEngine.collapse_and_refill(_board, cells, _weights)
	var next := MatchEngine.analyze_matches(_board)
	if not next.matched_cells.is_empty():
		_resolve(next, 2)
	if not MatchEngine.has_valid_move(_board):
		_board = _fresh_board()


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

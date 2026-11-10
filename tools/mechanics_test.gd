## mechanics_test.gd — plays every girl's four chapters on the real puzzle
## screen, headless, with real swaps (round 44): each chapter a few moves,
## the Hammer on her piece, the Shuffle Wand, her Charm power, the idle hint,
## and checks her pieces survive a shuffle. Any script error shows up in the
## output; the summary says what was reached.
##
##   godot --headless --path . -s tools/mechanics_test.gd
## (Uses a throwaway save: point HOME / XDG_DATA_HOME / APPDATA elsewhere.)
extends SceneTree

var main: Node
var gs: Node
var ok := true


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	gs = root.get_node("GameState")
	gs.reset_progress()
	gs.settings.age_confirmed = true
	gs.settings.reduce_motion = true
	gs.settings.voice = false
	for t in HowToPlay.TOPICS:
		if not gs.tips_seen.has(t.key):
			gs.tips_seen.append(t.key)
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	for ch in CharacterData.all():
		var id := String(ch.id)
		for i in range(4):
			var p = gs.progress_for(id)
			p["_intro_done"] = true
			p["level_index"] = i
			gs.items = {"hammer": 2, "shuffle": 1, "moves": 1}
			main.show_puzzle(id)
			await create_timer(0.2).timeout
			var pz = main._screen_obj
			var line := "%-9s ch%d %-5s" % [id, i + 1, pz.rules.mech]
			# Her pieces survive a Shuffle.
			var before := _pieces(pz.rules)
			pz._on_item_pressed("shuffle")
			await create_timer(0.05).timeout
			var kept: bool = _pieces(pz.rules) == before
			line += " shuffle keeps pieces %s;" % kept
			ok = ok and kept
			# The Hammer on one of her pieces (or any gem).
			var spot := _piece_cell(pz.rules)
			pz._on_item_pressed("hammer")
			pz._on_cell_pressed(spot.x, spot.y)
			await _idle(pz)
			# A few real moves.
			var moves := 0
			for n in range(6):
				if pz.moves_left <= 0 or main._screen_obj != pz:
					break
				var s: Dictionary = pz.rules.find_swap()
				if s.is_empty():
					break
				pz._attempt_swap(s.r1, s.c1, s.r2, s.c2)
				await _idle(pz)
				moves += 1
			line += " %d moves;" % moves
			# Her power, charged by hand.
			if pz.rules.power_id != "" and main._screen_obj == pz:
				await _idle(pz)
				pz.charm = MatchEngine.CHARM_MAX
				pz.power_charged = true
				var why := "busy %s overlay %s cleared %s torn %s" % [pz.busy, pz.overlay.visible, pz._replay_cleared, pz._torn_down]
				pz._on_power_pressed()
				if not pz.power_mode and pz.power_charged and not pz.busy:
					print("   power refused: ", why)
				if pz.power_mode:
					var pick := Vector2i(-1, -1)
					for r in range(8):
						for c in range(8):
							if pick.x < 0 and pz.rules.power_can_pick(r, c):
								pick = Vector2i(r, c)
					pz._on_cell_pressed(pick.x, pick.y)
				await _idle(pz)
				line += " power %s used %s (busy %s mode %s moves %d);" % [pz.rules.power_id, not pz.power_charged, pz.busy, pz.power_mode, pz.moves_left]
				ok = ok and not pz.power_charged
			if main._screen_obj == pz:
				pz._on_idle_timeout()
				line += " goal %d/%d score %d" % [pz.rules.goal_progress(), pz.rules.goal_n, pz.score]
			print(line)
			main.show_roster()
			await create_timer(0.1).timeout
	print("MECHANICS TEST %s" % ("PASSED" if ok else "FAILED"))
	quit()


func _idle(pz) -> void:
	for n in range(200):
		if not pz.busy or pz._torn_down:
			return
		await create_timer(0.02).timeout


func _pieces(r) -> Array:
	var seals := 0
	for row in r.seal:
		seals += (row as Array).count(true)
	var moss := 0
	for row in r.moss:
		for m in row:
			moss += 1 if m > 0 else 0
	return [seals, moss, r.count(PuzzleRules.SEED) + r.count(PuzzleRules.SPROUT), r.count(PuzzleRules.COMB)]


func _piece_cell(r) -> Vector2i:
	for rr in range(8):
		for cc in range(8):
			if r.seal[rr][cc] or r.moss[rr][cc] > 0 or r.board[rr][cc] == PuzzleRules.SEED:
				return Vector2i(rr, cc)
	return Vector2i(3, 3)

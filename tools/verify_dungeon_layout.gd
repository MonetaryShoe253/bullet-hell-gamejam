extends SceneTree
## Measures the three reported dungeon-generation faults across many seeds,
## so they can be quantified before anything is changed and re-measured after.
##
##   1. STAIRS REACHABLE - is the level-exit cell actually connected to the
##      player's spawn by floor? A stairs cell outside the walkable region
##      strands the player with no way to finish the level.
##   2. CORRIDOR WIDTH   - how wide the non-room floor actually is. If corridors
##      approach room size the map stops reading as rooms-and-halls and becomes
##      one open rectangle.
##   3. BOSS ARENA WALLS - how much of the boss room's perimeter is solid. The
##      arena should be sealed apart from its doorways; gaps beside the demon
##      portals mean the wall never got painted there.
##
## Complements tools/verify_dungeon.gd, which checks the tile-matching
## properties the renderer relies on; this one checks layout and traversal.
##
##   godot --headless --path . --script res://tools/verify_dungeon_layout.gd
##
## Exits non-zero if any seed fails a hard check.

const SEEDS := 200
const MAP_SIZE := Vector2i(260, 180)

var _f := 0


func _process(_delta: float) -> bool:
	_f += 1
	if _f < 2:
		return false

	var unreachable := 0
	var stairs_missing := 0
	var stairs_not_floor := 0
	var width_hist: Dictionary = {}
	var corridor_frac_total := 0.0
	var widest_seen := 0
	var boss_gap_seeds := 0
	var boss_gap_cells_total := 0
	var boss_missing := 0
	var blob_seeds := 0
	var fallback_bad := 0
	var failures: Array[String] = []

	for i in SEEDS:
		var gen := DungeonGenerator.new()
		gen.map_size = MAP_SIZE
		gen.generate(9000 + i, 1)

		# --- 1. stairs reachability -------------------------------------
		var reach := _flood(gen.grid, gen.player_spawn)
		if gen.stairs_cell == Vector2i.ZERO:
			# No dedicated landing fitted, so dungeon_map.gd falls back to
			# boss_gate_cells[0]. That is the exit for ~a third of all levels,
			# so it has to be checked just as hard as the real stairs room.
			stairs_missing += 1
			if gen.boss_gate_cells.is_empty():
				fallback_bad += 1
				failures.append("seed %d: no stairs room AND no boss_gate_cells - no level exit at all"
						% [9000 + i])
			elif not gen.grid.has(gen.boss_gate_cells[0]):
				fallback_bad += 1
				failures.append("seed %d: fallback exit %s is not a floor cell"
						% [9000 + i, gen.boss_gate_cells[0]])
			elif not reach.has(gen.boss_gate_cells[0]):
				fallback_bad += 1
				failures.append("seed %d: fallback exit %s unreachable from spawn"
						% [9000 + i, gen.boss_gate_cells[0]])
		elif not gen.grid.has(gen.stairs_cell):
			stairs_not_floor += 1
			failures.append("seed %d: stairs_cell %s is not a floor cell"
					% [9000 + i, gen.stairs_cell])
		elif not reach.has(gen.stairs_cell):
			unreachable += 1
			failures.append("seed %d: stairs_cell %s is floor but unreachable from spawn"
					% [9000 + i, gen.stairs_cell])

		# --- 2. corridor width ------------------------------------------
		var in_room: Dictionary = {}
		for room: Rect2i in gen.rooms:
			for x in range(room.position.x, room.end.x):
				for y in range(room.position.y, room.end.y):
					in_room[Vector2i(x, y)] = true
		var corridor_cells := 0
		var thickest := 0
		for cell: Vector2i in gen.grid:
			if in_room.has(cell):
				continue
			corridor_cells += 1
			# Local thickness: the largest square of solid floor centred here.
			# A 5-wide hall gives 2; a merged open blob gives far more. Measured
			# instead of axis run-lengths, which get inflated by any corridor
			# cell that happens to sit in a doorway looking into a room.
			var r := 0
			while r < 24 and _square_is_floor(gen.grid, cell, r + 1):
				r += 1
			width_hist[r * 2 + 1] = int(width_hist.get(r * 2 + 1, 0)) + 1
			widest_seen = maxi(widest_seen, r * 2 + 1)
			thickest = maxi(thickest, r * 2 + 1)
		if thickest >= 15:
			blob_seeds += 1
			failures.append("seed %d: open non-room region %d tiles thick (halls should be %d)"
					% [9000 + i, thickest, 5])
		if gen.grid.size() > 0:
			corridor_frac_total += float(corridor_cells) / float(gen.grid.size())

		# --- 3. boss arena perimeter ------------------------------------
		var boss: Rect2i = gen.boss_room
		if boss.size == Vector2i.ZERO:
			boss_missing += 1
		else:
			var doorway: Dictionary = {}
			for span: Array in gen.get_room_exits(boss):
				for c in span:
					doorway[c] = true
			var gaps := 0
			for c: Vector2i in _perimeter_outside(boss):
				if gen.grid.has(c) and not doorway.has(c):
					gaps += 1
			if gaps > 0:
				boss_gap_seeds += 1
				boss_gap_cells_total += gaps

	# ------------------------------------------------------------------
	print("seeds: %d   map %dx%d" % [SEEDS, MAP_SIZE.x, MAP_SIZE.y])
	print("")
	print("1. STAIRS")
	print("   no stairs room carved : %d" % stairs_missing)
	print("   stairs cell not floor : %d" % stairs_not_floor)
	print("   floor but unreachable : %d" % unreachable)
	print("   broken fallback exits : %d  (of the %d with no stairs room)"
			% [fallback_bad, stairs_missing])
	print("")
	print("2. CORRIDORS")
	print("   corridor share of floor: %.1f%%" % (100.0 * corridor_frac_total / SEEDS))
	print("   thickest open non-room : %d tiles" % widest_seen)
	print("   seeds with a blob (>=15): %d / %d" % [blob_seeds, SEEDS])
	var keys: Array = width_hist.keys()
	keys.sort()
	var total := 0
	for k in keys:
		total += int(width_hist[k])
	var line := "   width histogram       :"
	for k in keys:
		line += " %d:%.0f%%" % [k, 100.0 * float(width_hist[k]) / float(maxi(1, total))]
	print(line)
	print("")
	print("3. BOSS ARENA")
	print("   seeds with no boss room  : %d" % boss_missing)
	print("   seeds with perimeter gaps: %d / %d" % [boss_gap_seeds, SEEDS])
	print("   total gap cells          : %d" % boss_gap_cells_total)

	if not failures.is_empty():
		print("")
		print("HARD FAILURES (%d):" % failures.size())
		for f in failures.slice(0, 12):
			print("  - " + f)

	var bad := unreachable + stairs_not_floor + fallback_bad + blob_seeds
	if bad > 0:
		quit(1)
	else:
		quit(0)
	return true


## Every floor cell connected to `start` by 4-way movement.
func _flood(grid: Dictionary, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {}
	if not grid.has(start):
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if grid.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


## True when every cell of the (2r+1) square centred on `cell` is floor.
func _square_is_floor(grid: Dictionary, cell: Vector2i, r: int) -> bool:
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if not grid.has(cell + Vector2i(dx, dy)):
				return false
	return true


## Length of the unbroken floor run through `cell` along `axis`.
func _run(grid: Dictionary, cell: Vector2i, axis: Vector2i) -> int:
	var n := 1
	var c: Vector2i = cell + axis
	while grid.has(c):
		n += 1
		c += axis
	c = cell - axis
	while grid.has(c):
		n += 1
		c -= axis
	return n


## The ring of cells one step outside a room's rect.
func _perimeter_outside(room: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(room.position.x - 1, room.end.x + 1):
		out.append(Vector2i(x, room.position.y - 1))
		out.append(Vector2i(x, room.end.y))
	for y in range(room.position.y, room.end.y):
		out.append(Vector2i(room.position.x - 1, y))
		out.append(Vector2i(room.end.x, y))
	return out

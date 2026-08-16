class_name DungeonGenerator
extends RefCounted

## Pure-logic BSP dungeon generator. Produces a floor-cell grid you hand off
## to a TileMapLayer for rendering. No Node/scene dependency, so you can
## generate on a background thread or in a headless test.
##
## The grid it hands back is guaranteed to be *drawable*, which matters because
## Dungeon_Tileset.png is a hand-drawn room rather than a complete autotile set
## and has no art for a wall or a floor that is only one cell thick, nor for a
## wall squeezed between two floor regions that pass it on opposite diagonals.
## _clean_up() carves those away, so the renderer never has to invent a tile.
## tools/verify_dungeon.gd asserts the result over a batch of seeds.
## See docs/dungeon-generator.md for the full tile map.

enum Cell { FLOOR }

## Three of the rooms get a job. Everything else is an ordinary fight room.
enum RoomKind { NORMAL, START, SHOP, BOSS }

# --- Tuning knobs (set these before calling generate()) ---
# A 16px tile at the player camera's 3x zoom on a 1920x1080 viewport shows
# ~40x23 tiles at once. min_room_size is the floor of that range - about 3/4
# of a screen - so ordinary rooms vary from "smaller than the view" up to
# whatever a big partition can hold, rather than every room being arena-sized.
var map_size := Vector2i(260, 180)
var min_partition_size := 52      # keep this >= min_room_size + padding*2 + a margin
var min_room_size := 30           # bullet-hell arenas want generous space, not tiny rooms
var room_padding := 2             # gap between a room and its partition edge
var corridor_width := 5           # wide enough to dodge while transitioning rooms

## The start room is deliberately small and cozy rather than arena-sized -
## shrunk down from whatever _create_rooms() rolled for it once its identity
## is known (see _assign_roles()).
var start_room_size := 12

## The shop is a stall, not another arena - shrunk the same way, just a
## little roomier than the start so its chest/wares layout still fits.
var shop_room_size := 18

var rng := RandomNumberGenerator.new()
var grid: Dictionary = {}         # Vector2i -> Cell.FLOOR
var rooms: Array[Rect2i] = []
var seed_used: int = 0            # the seed actually used, so a good layout can be replayed

# --- Special rooms, filled in by _assign_roles(). Zero-sized if unassigned. ---
var start_room := Rect2i()
var shop_room := Rect2i()
var boss_room := Rect2i()
var player_spawn := Vector2i.ZERO  # centre cell of start_room

## A short dead-end appended beyond the boss room once it's known where that
## room's own doorway landed - see _carve_stairs_room(). Zero-sized if the
## boss room's exit couldn't be worked out (only possible with 1 room).
var stairs_room := Rect2i()
var stairs_cell := Vector2i.ZERO

## The two doorway cells on the boss room's north wall, same spot the gate prop
## is drawn on. Filled in by _carve_stairs_room() so the renderer and the room
## gate/trigger logic don't each have to recompute where "the gate" is.
var boss_gate_cells: Array[Vector2i] = []

## Rect2i -> Array[Rect2i], which rooms a corridor directly connects. Built
## alongside the corridors themselves in _connect_rooms()/_carve_stairs_room().
## Used by the minimap to know which unexplored rooms are worth showing as
## "next room, contents unknown" versus leaving fully hidden.
var room_adjacency: Dictionary = {}

## The leaf partition each entry of `rooms` came from, same order. Needed to
## grow the boss room out to fill its partition once the roles are handed out.
var _room_nodes: Array[BSPNode] = []

## Carving one shape can expose another, so cleanup runs to a fixed point.
## The cap only exists so a pathological grid can't spin forever.
const MAX_CLEANUP_PASSES := 16

const _NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]


class BSPNode:
	var rect: Rect2i
	var left: BSPNode = null
	var right: BSPNode = null
	var room: Rect2i = Rect2i()   # zero-size until create_rooms() fills it

	func _init(r: Rect2i) -> void:
		rect = r

	func is_leaf() -> bool:
		return left == null and right == null


func generate(seed_value: int = -1) -> void:
	grid.clear()
	rooms.clear()
	_room_nodes.clear()
	start_room = Rect2i()
	shop_room = Rect2i()
	boss_room = Rect2i()
	player_spawn = Vector2i.ZERO
	stairs_room = Rect2i()
	stairs_cell = Vector2i.ZERO
	seed_used = seed_value if seed_value >= 0 else randi()
	rng.seed = seed_used

	var root: BSPNode = BSPNode.new(Rect2i(Vector2i.ZERO, map_size))
	_split(root)
	_create_rooms(root)
	# Roles before connection: the boss arena grows to fill its partition here,
	# so the corridors that follow are routed to where its centre ends up.
	_assign_roles()
	_connect_rooms(root)
	_carve_stairs_room()
	_clean_up()


## What job a room has, looked up by its rect. Room rects come from disjoint BSP
## partitions, so no two are ever equal and this can't be ambiguous.
func kind_of(room: Rect2i) -> RoomKind:
	if room.size == Vector2i.ZERO:
		return RoomKind.NORMAL
	if room == boss_room:
		return RoomKind.BOSS
	if room == start_room:
		return RoomKind.START
	if room == shop_room:
		return RoomKind.SHOP
	return RoomKind.NORMAL


## Doorway cells where a room's rect meets a corridor: floor cells one step
## outside `room`'s four edges, clustered into contiguous runs. Each run is one
## physical opening a gate can block. Used by the room-gating system to know
## where to put its colliders; has no effect on generation itself.
func get_room_exits(room: Rect2i) -> Array:
	var spans: Array = []
	spans.append_array(_edge_spans(room, Vector2i(0, -1)))
	spans.append_array(_edge_spans(room, Vector2i(0, 1)))
	spans.append_array(_edge_spans(room, Vector2i(-1, 0)))
	spans.append_array(_edge_spans(room, Vector2i(1, 0)))
	return spans


func _edge_spans(room: Rect2i, dir: Vector2i) -> Array:
	var cells: Array[Vector2i] = []
	if dir.x == 0:
		var y: int = room.position.y - 1 if dir.y < 0 else room.end.y
		for x in range(room.position.x, room.end.x):
			var c := Vector2i(x, y)
			if grid.has(c):
				cells.append(c)
	else:
		var x: int = room.position.x - 1 if dir.x < 0 else room.end.x
		for y in range(room.position.y, room.end.y):
			var c := Vector2i(x, y)
			if grid.has(c):
				cells.append(c)

	# `cells` comes out sorted along the edge, so a run breaks the moment the
	# next cell isn't adjacent to the last one.
	var spans: Array = []
	var current: Array[Vector2i] = []
	for c: Vector2i in cells:
		if not current.is_empty():
			var prev: Vector2i = current[-1]
			var adjacent: bool = (dir.x == 0 and c.x == prev.x + 1) or (dir.y == 0 and c.y == prev.y + 1)
			if not adjacent:
				spans.append(current)
				current = []
		current.append(c)
	if not current.is_empty():
		spans.append(current)
	return spans


## Every empty cell that touches a floor cell 8-directionally. This is the ring
## the renderer draws wall trim on; everything beyond it is solid rock.
func get_wall_cells() -> Array[Vector2i]:
	var wall_set: Dictionary = {}
	for cell: Vector2i in grid:
		for offset: Vector2i in _NEIGHBOURS:
			var n: Vector2i = cell + offset
			if not grid.has(n):
				wall_set[n] = true

	var result: Array[Vector2i] = []
	result.assign(wall_set.keys())
	return result


## Tight bounding box of the floor cells. Empty rect if nothing was generated.
func get_bounds() -> Rect2i:
	if grid.is_empty():
		return Rect2i()

	var min_c := Vector2i(1 << 30, 1 << 30)
	var max_c := Vector2i(-(1 << 30), -(1 << 30))
	for cell: Vector2i in grid:
		min_c = min_c.min(cell)
		max_c = max_c.max(cell)
	return Rect2i(min_c, max_c - min_c + Vector2i.ONE)


## Flood fill check - every floor cell reachable from every other. Connectivity
## is guaranteed by construction, so this is here for tests and for catching
## regressions in the carving passes rather than for use at runtime.
func is_fully_connected() -> bool:
	if grid.is_empty():
		return true

	var start: Vector2i = grid.keys()[0]
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + offset
			if grid.has(n) and not seen.has(n):
				seen[n] = true
				queue.push_back(n)
	return seen.size() == grid.size()


# --- internals ---

## Floor is kept one cell clear of the map edge so the wall ring the renderer
## draws around it always lands inside map_size.
func _interior() -> Rect2i:
	return Rect2i(Vector2i.ONE, map_size - Vector2i(2, 2))


## Returns true only when this actually turned a new cell into floor, which is
## what lets the cleanup passes detect that they have settled.
func _set_floor(cell: Vector2i) -> bool:
	if grid.has(cell) or not _interior().has_point(cell):
		return false
	grid[cell] = Cell.FLOOR
	return true


func _split(node: BSPNode) -> void:
	var w: int = node.rect.size.x
	var h: int = node.rect.size.y

	# Either axis is splittable only if both halves can still clear the minimum.
	var can_split_y: bool = h >= min_partition_size * 2
	var can_split_x: bool = w >= min_partition_size * 2
	if not can_split_y and not can_split_x:
		return  # this node is a leaf

	var split_horizontal: bool
	if can_split_y and can_split_x:
		# Free choice, but bias hard against making long thin partitions.
		split_horizontal = rng.randf() < 0.5
		if float(w) / h >= 1.25:
			split_horizontal = false
		elif float(h) / w >= 1.25:
			split_horizontal = true
	else:
		split_horizontal = can_split_y  # only one axis has the room

	var axis_size: int = h if split_horizontal else w
	var split_pos: int = rng.randi_range(min_partition_size, axis_size - min_partition_size)

	if split_horizontal:
		node.left = BSPNode.new(Rect2i(node.rect.position, Vector2i(w, split_pos)))
		node.right = BSPNode.new(Rect2i(node.rect.position + Vector2i(0, split_pos), Vector2i(w, h - split_pos)))
	else:
		node.left = BSPNode.new(Rect2i(node.rect.position, Vector2i(split_pos, h)))
		node.right = BSPNode.new(Rect2i(node.rect.position + Vector2i(split_pos, 0), Vector2i(w - split_pos, h)))

	_split(node.left)
	_split(node.right)


func _create_rooms(node: BSPNode) -> void:
	if not node.is_leaf():
		_create_rooms(node.left)
		_create_rooms(node.right)
		return

	var max_w: int = node.rect.size.x - room_padding * 2
	var max_h: int = node.rect.size.y - room_padding * 2
	if max_w < min_room_size or max_h < min_room_size:
		return  # partition too small - this leaf just stays empty, that's fine

	var rw: int = rng.randi_range(min_room_size, max_w)
	var rh: int = rng.randi_range(min_room_size, max_h)
	var x: int = node.rect.position.x + rng.randi_range(room_padding, node.rect.size.x - rw - room_padding)
	var y: int = node.rect.position.y + rng.randi_range(room_padding, node.rect.size.y - rh - room_padding)

	node.room = Rect2i(x, y, rw, rh)
	rooms.append(node.room)
	_room_nodes.append(node)
	_carve_rect(node.room)


## Hands the three jobs out to rooms that already exist, rather than generating
## dedicated ones, so a special room is never wedged somewhere the BSP had no
## space for it.
func _assign_roles() -> void:
	if rooms.size() < 2:
		push_warning("DungeonGenerator: only %d room(s), roles left unassigned (seed %d)"
				% [rooms.size(), seed_used])
		return

	# The boss goes wherever there is the most floor to be had. Picking by
	# partition and then growing the room to fill it - rather than taking
	# whichever room happened to roll big - is what makes the arena reliably the
	# largest space on the map instead of merely a likely candidate.
	var boss_index: int = 0
	for i in rooms.size():
		if _arena_for(i).get_area() > _arena_for(boss_index).get_area():
			boss_index = i
	boss_room = _arena_for(boss_index)
	rooms[boss_index] = boss_room
	_room_nodes[boss_index].room = boss_room
	_carve_rect(boss_room)

	# Start as far from the boss as the layout allows, so clearing the dungeon is
	# a trip across the map rather than a walk next door.
	var start_index: int = -1
	var best_distance: int = -1
	for i in rooms.size():
		if i == boss_index:
			continue
		var distance: int = _distance_squared(rooms[i], boss_room)
		if distance > best_distance:
			best_distance = distance
			start_index = i
	# Shrink it down from whatever size it happened to roll - the start room
	# reads as a small landing, not another fight arena.
	var rolled_start: Rect2i = rooms[start_index]
	start_room = _shrink_room(rolled_start, start_room_size)
	_erase_outside(rolled_start, start_room)
	rooms[start_index] = start_room
	_room_nodes[start_index].room = start_room
	player_spawn = _center(start_room)

	if rooms.size() < 3:
		return  # nothing left over to sell from

	# The shop wants to be somewhere you pass through, so pick whichever room is
	# furthest from *both* ends. Maximising the smaller of the two distances puts
	# it in the middle of the run instead of against the start or the boss.
	var shop_index: int = -1
	best_distance = -1
	for i in rooms.size():
		if i == boss_index or i == start_index:
			continue
		var distance: int = mini(
				_distance_squared(rooms[i], start_room),
				_distance_squared(rooms[i], boss_room))
		if distance > best_distance:
			best_distance = distance
			shop_index = i
	# Shrunk the same way the start room is - a shop is a stall, not an arena.
	var rolled_shop: Rect2i = rooms[shop_index]
	shop_room = _shrink_room(rolled_shop, shop_room_size)
	_erase_outside(rolled_shop, shop_room)
	rooms[shop_index] = shop_room
	_room_nodes[shop_index].room = shop_room


## The largest room the partition behind `rooms[index]` could possibly hold.
func _arena_for(index: int) -> Rect2i:
	return _room_nodes[index].rect.grow(-room_padding)


func _shrink_room(room: Rect2i, size: int) -> Rect2i:
	var w: int = mini(size, room.size.x)
	var h: int = mini(size, room.size.y)
	var x: int = room.position.x + (room.size.x - w) / 2
	var y: int = room.position.y + (room.size.y - h) / 2
	return Rect2i(x, y, w, h)


## Un-carves whatever `old_room` covered that `new_room` doesn't. Safe to call
## before _connect_rooms()/_clean_up() run - both only ever add floor, so
## erasing here is the only place in generation floor can shrink, and nothing
## downstream depends on this cell having been floor a moment ago.
func _erase_outside(old_room: Rect2i, new_room: Rect2i) -> void:
	for x in range(old_room.position.x, old_room.end.x):
		for y in range(old_room.position.y, old_room.end.y):
			var cell := Vector2i(x, y)
			if not new_room.has_point(cell):
				grid.erase(cell)


func _add_adjacency(a: Rect2i, b: Rect2i) -> void:
	if not room_adjacency.has(a):
		room_adjacency[a] = []
	if not room_adjacency.has(b):
		room_adjacency[b] = []
	room_adjacency[a].append(b)
	room_adjacency[b].append(a)


func _distance_squared(a: Rect2i, b: Rect2i) -> int:
	var delta: Vector2i = _center(a) - _center(b)
	return delta.x * delta.x + delta.y * delta.y


## Returns every room in this subtree, and joins the two subtrees on the way
## back up. Returning the whole list (rather than one representative room) lets
## each join pick the closest pair across the split, which keeps corridors short
## instead of always running back to the far corner of the map.
func _connect_rooms(node: BSPNode) -> Array[Rect2i]:
	if node.is_leaf():
		var leaf: Array[Rect2i] = []
		if node.room.size != Vector2i.ZERO:
			leaf.append(node.room)
		return leaf

	var left_rooms: Array[Rect2i] = _connect_rooms(node.left)
	var right_rooms: Array[Rect2i] = _connect_rooms(node.right)

	if not left_rooms.is_empty() and not right_rooms.is_empty():
		var best_a: Rect2i = left_rooms[0]
		var best_b: Rect2i = right_rooms[0]
		var best_dist: int = 1 << 30
		for a: Rect2i in left_rooms:
			for b: Rect2i in right_rooms:
				var delta: Vector2i = _center(a) - _center(b)
				var dist: int = delta.x * delta.x + delta.y * delta.y
				if dist < best_dist:
					best_dist = dist
					best_a = a
					best_b = b
		_carve_corridor(_center(best_a), _center(best_b))
		_add_adjacency(best_a, best_b)

	var all_rooms: Array[Rect2i] = []
	all_rooms.append_array(left_rooms)
	all_rooms.append_array(right_rooms)
	return all_rooms


## A small dead-end room latched onto the boss arena's north wall, at the same
## spot _decorate_boss draws its gate prop - this is the "climb to the next
## level" landing once the boss is dead. Not every seed has map space north of
## the boss room for it; when it doesn't fit, stairs_room is left zero-sized
## and the caller falls back to putting the level-up trigger at the gate itself.
func _carve_stairs_room() -> void:
	if boss_room.size == Vector2i.ZERO:
		return

	var gate_x: int = boss_room.position.x + boss_room.size.x / 2 - 1
	var top: int = boss_room.position.y
	boss_gate_cells = [Vector2i(gate_x, top), Vector2i(gate_x + 1, top)]

	var stairs_w := 10
	var stairs_h := 8
	var candidate := Rect2i(
			gate_x - stairs_w / 2 + 1, top - room_padding - 1 - stairs_h,
			stairs_w, stairs_h)
	if not _interior().encloses(candidate):
		return

	stairs_room = candidate
	_carve_rect(stairs_room)
	stairs_cell = _center(stairs_room)
	_carve_corridor(Vector2i(gate_x, top - 1), stairs_cell)


func _center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


func _carve_rect(r: Rect2i) -> void:
	for x in range(r.position.x, r.position.x + r.size.x):
		for y in range(r.position.y, r.position.y + r.size.y):
			_set_floor(Vector2i(x, y))


func _carve_corridor(from: Vector2i, to: Vector2i) -> void:
	# L-shaped: pick a random bend point so corridors aren't all uniform.
	var bend: Vector2i = Vector2i(to.x, from.y) if rng.randf() < 0.5 else Vector2i(from.x, to.y)
	_carve_line(from, bend)
	_carve_line(bend, to)


func _carve_line(a: Vector2i, b: Vector2i) -> void:
	var half: int = corridor_width / 2
	if a.x == b.x:
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for w in range(-half, corridor_width - half):
				_set_floor(Vector2i(a.x + w, y))
	else:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			for w in range(-half, corridor_width - half):
				_set_floor(Vector2i(x, a.y + w))


## Carves away the shapes Dungeon_Tileset.png cannot draw. Every pass only ever
## *adds* floor, so none of them can disconnect the dungeon, and because floor
## can only grow inside a bounded interior the loop always reaches a fixed point.
## Each pass can expose work for the others, hence the loop rather than a
## straight sequence.
func _clean_up() -> void:
	for _pass in range(MAX_CLEANUP_PASSES):
		var carved: int = _carve_pinched_walls() + _carve_diagonal_pinches() \
				+ _widen_thin_floors() + _carve_enclosed_pockets()
		if carved == 0:
			return
	push_warning("DungeonGenerator: cleanup did not settle in %d passes (seed %d)"
			% [MAX_CLEANUP_PASSES, seed_used])


## Wall cells too thin to draw:
##
##   * floor on both sides - a one-cell divider, and there is no double-sided
##     wall tile. It would be a silly thing to leave in a bullet hell anyway, so
##     it becomes floor and the two sides merge.
##   * no floor orthogonally but floor on two diagonals - two floor regions
##     squeezing past each other corner to corner. The convex-corner lookup has
##     no answer for that, since both diagonals want the tile to face them.
##     Opening the cell lets the ordinary rules take over on the next pass.
func _carve_pinched_walls() -> int:
	var doomed: Dictionary = {}
	for cell: Vector2i in get_wall_cells():
		var north: bool = grid.has(cell + Vector2i(0, -1))
		var south: bool = grid.has(cell + Vector2i(0, 1))
		var east: bool = grid.has(cell + Vector2i(1, 0))
		var west: bool = grid.has(cell + Vector2i(-1, 0))

		if (east and west) or (north and south):
			doomed[cell] = true
			continue
		if north or south or east or west:
			continue

		var diagonals: int = 0
		for offset: Vector2i in [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			if grid.has(cell + offset):
				diagonals += 1
		if diagonals > 1:
			doomed[cell] = true

	# Collected first, carved second, so the result doesn't depend on iteration order.
	var carved: int = 0
	for cell: Vector2i in doomed:
		if _set_floor(cell):
			carved += 1
	return carved


## Rock that ends up completely walled in by floor - typically a scrap left
## behind where a corridor clipped the corner of a room. The tileset has no
## freestanding pillar art, so a small pocket draws as a stray little walled box
## sitting in the middle of an arena, which reads as a rendering fault rather
## than as level design. Flooding the rock inward from outside the map and
## carving everything the flood cannot reach clears them all in one go.
func _carve_enclosed_pockets() -> int:
	var area: Rect2i = Rect2i(Vector2i.ZERO, map_size).grow(1)

	# Floor is confined to _interior(), so the whole border of `area` is rock and
	# is guaranteed to be a valid starting point.
	var reached: Dictionary = {}
	var queue: Array[Vector2i] = []
	for x in range(area.position.x, area.end.x):
		queue.append(Vector2i(x, area.position.y))
		queue.append(Vector2i(x, area.end.y - 1))
	for y in range(area.position.y, area.end.y):
		queue.append(Vector2i(area.position.x, y))
		queue.append(Vector2i(area.end.x - 1, y))
	for cell: Vector2i in queue:
		reached[cell] = true

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cell + offset
			if area.has_point(n) and not grid.has(n) and not reached.has(n):
				reached[n] = true
				queue.push_back(n)

	var carved: int = 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not grid.has(cell) and not reached.has(cell) and _set_floor(cell):
				carved += 1
	return carved


## Floor one cell thick has no tile either: the art shades a north edge or a
## south edge, never both on one tile. Merging two regions in _carve_pinched_walls
## can leave exactly this - a single-cell neck between them - so widen it to two.
func _widen_thin_floors() -> int:
	var carved: int = 0
	for cell: Vector2i in grid.keys():
		if not grid.has(cell + Vector2i(0, -1)) and not grid.has(cell + Vector2i(0, 1)):
			if _set_floor(cell + Vector2i(0, 1)) or _set_floor(cell + Vector2i(0, -1)):
				carved += 1
		if not grid.has(cell + Vector2i(-1, 0)) and not grid.has(cell + Vector2i(1, 0)):
			if _set_floor(cell + Vector2i(1, 0)) or _set_floor(cell + Vector2i(-1, 0)):
				carved += 1
	return carved


## Two floor regions meeting corner to corner. Both wall cells around the pinch
## do have tiles that fit, so this is a quality pass rather than a correctness
## one: the gap reads as an hourglass in the art, and it is an opening the player
## can sometimes squeeze through and sometimes not depending on their collider.
## Opening one of the two blocking cells turns it into a normal doorway.
func _carve_diagonal_pinches() -> int:
	var bounds: Rect2i = get_bounds()
	if bounds.size == Vector2i.ZERO:
		return 0

	var doomed: Dictionary = {}
	for y in range(bounds.position.y - 1, bounds.end.y):
		for x in range(bounds.position.x - 1, bounds.end.x):
			var nw: bool = grid.has(Vector2i(x, y))
			var ne: bool = grid.has(Vector2i(x + 1, y))
			var sw: bool = grid.has(Vector2i(x, y + 1))
			var se: bool = grid.has(Vector2i(x + 1, y + 1))
			if nw and se and not ne and not sw:
				doomed[Vector2i(x + 1, y)] = true
			elif ne and sw and not nw and not se:
				doomed[Vector2i(x, y)] = true

	var carved: int = 0
	for cell: Vector2i in doomed:
		if _set_floor(cell):
			carved += 1
	return carved

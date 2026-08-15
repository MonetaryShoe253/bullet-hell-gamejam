extends SceneTree
##
## Batch check on the generator's output: runs a spread of seeds and asserts the
## properties the tile renderer relies on. Cheaper than eyeballing screenshots,
## and it catches the tile-matching regressions that only show up on one seed in
## fifty.
##
## Usage:
##   godot --headless --path . --script res://tools/verify_dungeon.gd -- [seed_count]
##
## (--headless is fine here - this never reads pixels back, unlike
## tools/capture_dungeon.gd which needs a real renderer.)
##

const DIRECTIONS := {
	"north": Vector2i(0, -1), "south": Vector2i(0, 1),
	"east": Vector2i(1, 0), "west": Vector2i(-1, 0),
}

var _failures: Array[String] = []


func _initialize() -> void:
	var seed_count := 200
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		seed_count = int(args[0])

	var room_total := 0
	for s in range(seed_count):
		var gen := DungeonGenerator.new()
		gen.generate(s)
		room_total += gen.rooms.size()
		_check(gen, s)

	if _failures.is_empty():
		print("OK - %d seeds, %.1f rooms avg, all invariants hold"
				% [seed_count, float(room_total) / seed_count])
	else:
		printerr("FAILED - %d problems across %d seeds:" % [_failures.size(), seed_count])
		for line in _failures.slice(0, 25):
			printerr("  " + line)

	quit(0 if _failures.is_empty() else 1)


func _check(gen: DungeonGenerator, seed_value: int) -> void:
	if gen.grid.is_empty():
		_fail(seed_value, "generated an empty dungeon")
		return
	if not gen.is_fully_connected():
		_fail(seed_value, "dungeon is not fully connected")
	if gen.rooms.size() < 3:
		_fail(seed_value, "only %d room(s), too few to place start/shop/boss" % gen.rooms.size())
	_check_special_rooms(gen, seed_value)

	var bounds: Rect2i = gen.get_bounds()
	var map_bounds := Rect2i(Vector2i.ONE, gen.map_size - Vector2i(2, 2))
	if not map_bounds.encloses(bounds):
		_fail(seed_value, "floor %s escapes the interior %s, so its wall ring would fall off the map"
				% [bounds, map_bounds])

	# Every empty cell touching floor has to resolve to exactly one wall piece.
	for cell: Vector2i in gen.get_wall_cells():
		var north: bool = gen.grid.has(cell + DIRECTIONS.north)
		var south: bool = gen.grid.has(cell + DIRECTIONS.south)
		var east: bool = gen.grid.has(cell + DIRECTIONS.east)
		var west: bool = gen.grid.has(cell + DIRECTIONS.west)

		# A wall with floor on both sides is one cell thick - no double-sided art.
		if (north and south) or (east and west):
			_fail(seed_value, "one-cell-thick wall at %s" % cell)

		if north or south or east or west:
			continue

		# Otherwise it is a convex corner, and exactly one diagonal may touch
		# floor - two would mean a diagonal pinch with no tile that fits.
		var diagonals := 0
		for offset: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			if gen.grid.has(cell + offset):
				diagonals += 1
		if diagonals > 1:
			_fail(seed_value, "diagonal pinch at %s (%d floor diagonals)" % [cell, diagonals])

	# Rock islands sealed inside the floor draw as stray walled boxes.
	var enclosed := _find_enclosed_rock(gen)
	if not enclosed.is_empty():
		_fail(seed_value, "%d cells of rock sealed inside the floor, first at %s"
				% [enclosed.size(), enclosed[0]])

	# Floor thinner than two cells has no tile either: the art can only shade one
	# of a pair of opposite edges.
	for cell: Vector2i in gen.grid:
		var vertical: bool = not gen.grid.has(cell + DIRECTIONS.north) and not gen.grid.has(cell + DIRECTIONS.south)
		var horizontal: bool = not gen.grid.has(cell + DIRECTIONS.east) and not gen.grid.has(cell + DIRECTIONS.west)
		if vertical or horizontal:
			_fail(seed_value, "one-cell-thick floor at %s" % cell)


## The start, shop and boss rooms have to exist, be three different rooms, be
## fully walkable, and be reachable from the spawn. Combined with the
## is_fully_connected() check above, "every cell is floor" is what proves the
## player can actually get to each of them.
func _check_special_rooms(gen: DungeonGenerator, seed_value: int) -> void:
	var special := {
		"start": gen.start_room, "shop": gen.shop_room, "boss": gen.boss_room,
	}

	for name: String in special:
		var room: Rect2i = special[name]
		if room.size == Vector2i.ZERO:
			_fail(seed_value, "no %s room was assigned" % name)
			continue
		if not gen.rooms.has(room):
			_fail(seed_value, "%s room %s is not one of the generated rooms" % [name, room])
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				if not gen.grid.has(Vector2i(x, y)):
					_fail(seed_value, "%s room %s has a non-floor cell at %s"
							% [name, room, Vector2i(x, y)])
					return

	if gen.start_room == gen.boss_room or gen.start_room == gen.shop_room \
			or gen.shop_room == gen.boss_room:
		_fail(seed_value, "start/shop/boss are not three distinct rooms")

	if not gen.grid.has(gen.player_spawn):
		_fail(seed_value, "player spawn %s is not a floor cell" % gen.player_spawn)
	elif not gen.start_room.has_point(gen.player_spawn):
		_fail(seed_value, "player spawn %s is outside the start room %s"
				% [gen.player_spawn, gen.start_room])

	# The boss arena is meant to be the biggest space on the map, not merely a
	# likely candidate - it fills the roomiest partition available.
	for room: Rect2i in gen.rooms:
		if room != gen.boss_room and room.get_area() > gen.boss_room.get_area():
			_fail(seed_value, "room %s (%d cells) is bigger than the boss arena %s (%d cells)"
					% [room, room.get_area(), gen.boss_room, gen.boss_room.get_area()])

	# kind_of() is what the renderer reads to decide what to draw where.
	if gen.kind_of(gen.start_room) != DungeonGenerator.RoomKind.START \
			or gen.kind_of(gen.shop_room) != DungeonGenerator.RoomKind.SHOP \
			or gen.kind_of(gen.boss_room) != DungeonGenerator.RoomKind.BOSS:
		_fail(seed_value, "kind_of() disagrees with the assigned special rooms")


## Rock cells the outside world can't reach, found independently of the
## generator's own flood fill so a bug in one doesn't hide a bug in the other.
func _find_enclosed_rock(gen: DungeonGenerator) -> Array[Vector2i]:
	var area := Rect2i(Vector2i.ZERO, gen.map_size)
	var open: Dictionary = {}
	var frontier: Array[Vector2i] = [area.position]
	open[area.position] = true

	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for offset: Vector2i in DIRECTIONS.values():
			var n: Vector2i = cell + offset
			if area.has_point(n) and not gen.grid.has(n) and not open.has(n):
				open[n] = true
				frontier.push_back(n)

	var sealed_cells: Array[Vector2i] = []
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not gen.grid.has(cell) and not open.has(cell):
				sealed_cells.append(cell)
	return sealed_cells


func _fail(seed_value: int, message: String) -> void:
	_failures.append("seed %d: %s" % [seed_value, message])

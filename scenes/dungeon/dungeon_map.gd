extends Node2D

## Paints a DungeonGenerator's floor grid onto a TileMapLayer using
## Dungeon_Tileset.png.
##
## The tileset is laid out as one hand-drawn room in its top-left 6x6 block:
## row 0 is the north wall, rows 1-3 the floor, row 4 the south wall, and
## columns 0 and 5 the side walls. Both the floor art and the wall art have
## their neighbours baked in - floor tile (1,1) is drawn with shading along its
## north and west edges, (5,4) is drawn as a wall corner - so picking a tile is
## a matter of reading a cell's neighbours and looking up the matching piece.
##
## Everything outside the wall ring is filled with tile (8,7), a flat block of
## the exact same near-black the artist baked into the wall tiles. That makes
## the area beyond the dungeon read as solid rock that lines up seamlessly with
## the wall art, rather than showing the empty viewport background through it.
##
## See docs/dungeon-generator.md for the full atlas map and how it was derived.

@onready var tile_layer: TileMapLayer = $TileMapLayer
@onready var prop_layer: TileMapLayer = $PropLayer
@onready var camera: Camera2D = $Camera2D
@onready var seed_label: Label = $HUD/SeedLabel

@export var tile_source_id := 0   # the TileSetAtlasSource id for the tileset (0 if it's the only source)
@export var map_size := Vector2i(60, 40)
@export var use_random_seed := true
@export var fixed_seed := 12345   # used when use_random_seed is false, for reproducible testing

## Rings of solid rock painted beyond the map edge. Only needs to cover whatever
## the camera can see past the dungeon; it is not part of the playable area.
@export var void_margin := 16
@export var fit_camera_to_map := true
@export var show_hud := true
## Draws the ladder / wares / gate that mark out the start, shop and boss rooms.
@export var show_room_props := true

## Players and Enemies
@export var player_scene: PackedScene
var player: Node2D

@export var enemy_scene: PackedScene


# --- atlas coordinates (column, row) in the 16px grid ---

## Flat block of (37, 19, 26) - the same near-black baked into the wall tiles.
const SOLID_ROCK := Vector2i(8, 7)

## Straight wall runs, named for which way the wall faces. A north wall is the
## one drawn *above* a floor cell, so it is the piece whose full-height brick
## face you see; a south wall is drawn below the floor and only shows the wall's
## top capping, with rock below it.
const NORTH_WALL: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
const SOUTH_WALL: Array[Vector2i] = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
		Vector2i(1, 5), Vector2i(2, 5)]
const WEST_WALL: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]
const EAST_WALL: Array[Vector2i] = [Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3)]

## Convex corners - the outside of a bend, with floor only on the named diagonal.
## These double as the plain wall runs' end caps, which is why CONVEX_NW and
## WEST_WALL[0] are the same tile.
const CONVEX_NW := Vector2i(0, 0)
const CONVEX_NE := Vector2i(5, 0)
const CONVEX_SW := Vector2i(0, 4)
const CONVEX_SE := Vector2i(5, 4)

## Concave corners - the inside of a bend, with floor on two perpendicular sides.
## The artist only drew the two that sit below floor: a wall cap running east or
## west with the side wall's post attached. _wall_atlas_coords() explains what
## happens for the other two.
const CONCAVE_NW: Array[Vector2i] = [Vector2i(0, 5), Vector2i(4, 5)]  # floor to the north and west
const CONCAVE_NE: Array[Vector2i] = [Vector2i(3, 5), Vector2i(5, 5)]  # floor to the north and east

## Props marking out the special rooms, drawn on PropLayer above the floor.
## Every one of these has a transparent background in the atlas, so it sits on
## the floor instead of punching a hole in it. None of them carry a collision
## polygon either - they are scenery, not obstacles.
const PROP_LADDER := Vector2i(9, 3)          # start room: the way you came in
const PROP_GATE: Array[Vector2i] = [Vector2i(6, 6), Vector2i(7, 6)]  # two halves of one arch
const PROP_TORCH: Array[Vector2i] = [Vector2i(0, 9), Vector2i(1, 9)] # wall mounted, goes on wall cells
const PROP_CANDLE := Vector2i(5, 9)
const PROP_BONES: Array[Vector2i] = [Vector2i(4, 6), Vector2i(7, 7), Vector2i(8, 6), Vector2i(5, 6)]
const PROP_CHESTS: Array[Vector2i] = [Vector2i(0, 8), Vector2i(2, 8), Vector2i(4, 8)]
const PROP_WARES: Array[Vector2i] = [Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8), Vector2i(9, 8)]

const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)

var _generator: DungeonGenerator


func _ready() -> void:
	generate_dungeon()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			use_random_seed = true
			generate_dungeon()
			get_viewport().set_input_as_handled()

func _spawn_player() -> void:
	player = player_scene.instantiate()
	add_child(player)

	var spawn_position := tile_layer.map_to_local(_generator.player_spawn)
	player.position = spawn_position

	print("Player spawned at: ", spawn_position)

func _spawn_enemy() -> void:
	var boss_room: Rect2i = _generator.boss_room

	if boss_room.size == Vector2i.ZERO:
		push_warning("No boss room generated!")
		return

	var enemy: Enemy = enemy_scene.instantiate()

	enemy.player = player

	add_child(enemy)

	var spawn_tile := boss_room.position + boss_room.size / 2
	enemy.position = tile_layer.map_to_local(spawn_tile)

	print("Enemy spawned at: ", enemy.position)

func generate_dungeon() -> void:
	_generator = DungeonGenerator.new()
	_generator.map_size = map_size

	_generator.generate(-1 if use_random_seed else fixed_seed)

	_paint(_generator)
	
	_spawn_player()	
	_spawn_enemy()
	

	seed_label.visible = show_hud
	seed_label.text = "seed %d   ·   %d rooms   ·   boss arena %d×%d   ·   [R] regenerate" % [
			_generator.seed_used, _generator.rooms.size(),
			_generator.boss_room.size.x, _generator.boss_room.size.y]


func _paint(gen: DungeonGenerator) -> void:
	tile_layer.clear()

	# Solid rock first, then the wall ring, then floor. Later passes overwrite
	# earlier ones, so each cell ends up with the most specific piece that fits.
	var filled := Rect2i(Vector2i.ZERO, map_size).grow(void_margin)
	for y in range(filled.position.y, filled.end.y):
		for x in range(filled.position.x, filled.end.x):
			tile_layer.set_cell(Vector2i(x, y), tile_source_id, SOLID_ROCK)

	for cell: Vector2i in gen.get_wall_cells():
		tile_layer.set_cell(cell, tile_source_id, _wall_atlas_coords(cell, gen.grid))

	for cell: Vector2i in gen.grid:
		tile_layer.set_cell(cell, tile_source_id, _floor_atlas_coords(cell, gen.grid))

	_paint_props(gen)


## Marks out the three special rooms. Nothing here changes the dungeon - it only
## makes the roles the generator assigned visible at a glance, both for playing
## and for checking a screenshot.
func _paint_props(gen: DungeonGenerator) -> void:
	prop_layer.clear()
	if not show_room_props:
		return

	_decorate_start(gen)
	_decorate_shop(gen)
	_decorate_boss(gen)


func _decorate_start(gen: DungeonGenerator) -> void:
	var room: Rect2i = gen.start_room
	if room.size == Vector2i.ZERO:
		return

	# A ladder on the spawn tile: this is the way in, so this is where you land.
	_set_prop(gen, room, gen.player_spawn, PROP_LADDER)
	_set_prop(gen, room, gen.player_spawn + Vector2i(-2, 0), PROP_CANDLE)
	_set_prop(gen, room, gen.player_spawn + Vector2i(2, 0), PROP_CANDLE)


func _decorate_shop(gen: DungeonGenerator) -> void:
	var room: Rect2i = gen.shop_room
	if room.size == Vector2i.ZERO:
		return

	# A counter of chests with the wares laid out in front of it.
	var middle: Vector2i = room.position + room.size / 2
	for i in PROP_CHESTS.size():
		_set_prop(gen, room, middle + Vector2i(i * 2 - 2, -1), PROP_CHESTS[i])
	for i in PROP_WARES.size():
		_set_prop(gen, room, middle + Vector2i(i - 2, 1), PROP_WARES[i])
	# Candles against the side walls rather than at a fixed offset, so they land
	# inside the room whatever width it came out at.
	_set_prop(gen, room, Vector2i(room.position.x, middle.y), PROP_CANDLE)
	_set_prop(gen, room, Vector2i(room.end.x - 1, middle.y), PROP_CANDLE)


func _decorate_boss(gen: DungeonGenerator) -> void:
	var room: Rect2i = gen.boss_room
	if room.size == Vector2i.ZERO:
		return

	# The gate goes on the floor row against the north wall, so it reads as the
	# way out of the arena, with a torch to either side up on the wall itself.
	var gate_x: int = room.position.x + room.size.x / 2 - 1
	var top: int = room.position.y
	for i in PROP_GATE.size():
		_set_prop(gen, room, Vector2i(gate_x + i, top), PROP_GATE[i])
	_set_wall_prop(gen, Vector2i(gate_x - 2, top - 1), PROP_TORCH[0])
	_set_wall_prop(gen, Vector2i(gate_x + 3, top - 1), PROP_TORCH[1])

	# Leftovers of whoever came before, spread to the corners so they read as
	# arena dressing rather than a pile in the middle.
	var corners: Array[Vector2i] = [
		Vector2i(2, 3),
		Vector2i(room.size.x - 3, 4),
		Vector2i(3, room.size.y - 3),
		Vector2i(room.size.x - 4, room.size.y - 4),
	]
	for i in corners.size():
		_set_prop(gen, room, room.position + corners[i], PROP_BONES[i])


## Places a floor prop, but only on a cell that is both inside the room it
## belongs to and actually floor. Cleanup can reshape a room's surroundings, and
## a small room can be narrower than the arrangement asks for, so anything that
## doesn't land cleanly is simply dropped.
func _set_prop(gen: DungeonGenerator, room: Rect2i, cell: Vector2i, atlas: Vector2i) -> void:
	if room.has_point(cell) and gen.grid.has(cell):
		prop_layer.set_cell(cell, tile_source_id, atlas)


## Wall-mounted props hang on the wall ring instead, so this wants the opposite
## test: a non-floor cell with floor directly below it to hang against.
func _set_wall_prop(gen: DungeonGenerator, cell: Vector2i, atlas: Vector2i) -> void:
	if not gen.grid.has(cell) and gen.grid.has(cell + SOUTH):
		prop_layer.set_cell(cell, tile_source_id, atlas)


func _floor_atlas_coords(cell: Vector2i, grid: Dictionary) -> Vector2i:
	var wall_n: bool = not grid.has(cell + NORTH)
	var wall_s: bool = not grid.has(cell + SOUTH)
	var wall_w: bool = not grid.has(cell + WEST)
	var wall_e: bool = not grid.has(cell + EAST)

	# Rows 1/2/3 carry north-edge shading, no shading, and south-edge shading;
	# columns 1/2-3/4 do the same for west and east. A cell walled on both
	# opposite sides can only show one of them - the generator's cleanup makes
	# floor at least three cells thick, so in practice this never comes up.
	var row: int = 2
	if wall_n and not wall_s:
		row = 1
	elif wall_s and not wall_n:
		row = 3

	var col: int = 2 + _variant_index(cell, 2)  # two interchangeable interior variants
	if wall_w and not wall_e:
		col = 1
	elif wall_e and not wall_w:
		col = 4

	return Vector2i(col, row)


func _wall_atlas_coords(cell: Vector2i, grid: Dictionary) -> Vector2i:
	var n: bool = grid.has(cell + NORTH)
	var s: bool = grid.has(cell + SOUTH)
	var e: bool = grid.has(cell + EAST)
	var w: bool = grid.has(cell + WEST)

	# Concave corners before straight runs: a cell with floor on two
	# perpendicular sides needs the piece that turns, not either straight wall.
	if n and w:
		return _variant(cell, CONCAVE_NW)
	if n and e:
		return _variant(cell, CONCAVE_NE)

	# The mirrored pair (floor to the south plus floor to one side) has no art.
	# A north wall is a full-tile-tall brick face, which leaves no room to also
	# draw the side wall's post the way the south-facing corners do. Falling
	# through to the plain north wall is the right call: the face is the loud
	# part of the silhouette, and the floor beside it supplies its own edge
	# shading, so the corner still reads as a corner.
	if s:
		return _variant(cell, NORTH_WALL)
	if n:
		return _variant(cell, SOUTH_WALL)
	if e:
		return _variant(cell, WEST_WALL)
	if w:
		return _variant(cell, EAST_WALL)

	# No orthogonal floor left, so this is the outside of a bend. Cleanup
	# guarantees at most one diagonal touches floor, making the choice unambiguous.
	if grid.has(cell + Vector2i(1, 1)):
		return CONVEX_NW
	if grid.has(cell + Vector2i(-1, 1)):
		return CONVEX_NE
	if grid.has(cell + Vector2i(1, -1)):
		return CONVEX_SW
	if grid.has(cell + Vector2i(-1, -1)):
		return CONVEX_SE

	return SOLID_ROCK


## Picks between interchangeable variants of the same piece. Hashing the cell
## rather than pulling from an RNG keeps the choice stable: repainting the same
## grid gives the same picture, whatever order the cells come out of the dictionary.
func _variant(cell: Vector2i, options: Array[Vector2i]) -> Vector2i:
	return options[_variant_index(cell, options.size())]


func _variant_index(cell: Vector2i, count: int) -> int:
	var hash_value: int = (cell.x * 73856093) ^ (cell.y * 19349663)
	return (hash_value & 0x7fffffff) % count

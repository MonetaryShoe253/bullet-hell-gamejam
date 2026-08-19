class_name DungeonRenderer
extends RefCounted
## Paints generated floor/wall geometry to the dungeon TileMapLayer.

const SOLID_ROCK := Vector2i(8, 7)
const NORTH_WALL: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
const SOUTH_WALL: Array[Vector2i] = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4), Vector2i(1, 5), Vector2i(2, 5)]
const WEST_WALL: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]
const EAST_WALL: Array[Vector2i] = [Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3)]
const CONVEX_NW := Vector2i(0, 0)
const CONVEX_NE := Vector2i(5, 0)
const CONVEX_SW := Vector2i(0, 4)
const CONVEX_SE := Vector2i(5, 4)
const CONCAVE_NW: Array[Vector2i] = [Vector2i(0, 5), Vector2i(4, 5)]
const CONCAVE_NE: Array[Vector2i] = [Vector2i(3, 5), Vector2i(5, 5)]
const NORTH := Vector2i(0, -1)
const SOUTH := Vector2i(0, 1)
const EAST := Vector2i(1, 0)
const WEST := Vector2i(-1, 0)

var _tile_layer: TileMapLayer
var _tile_source_id: int
var _map_size: Vector2i
var _void_margin: int


func _init(tile_layer: TileMapLayer, tile_source_id: int, map_size: Vector2i, void_margin: int) -> void:
	_tile_layer = tile_layer
	_tile_source_id = tile_source_id
	_map_size = map_size
	_void_margin = void_margin


func paint(gen: DungeonGenerator) -> void:
	_tile_layer.clear()
	var filled := Rect2i(Vector2i.ZERO, _map_size).grow(_void_margin)
	for y in range(filled.position.y, filled.end.y):
		for x in range(filled.position.x, filled.end.x):
			_tile_layer.set_cell(Vector2i(x, y), _tile_source_id, SOLID_ROCK)
	for cell: Vector2i in gen.get_wall_cells():
		_tile_layer.set_cell(cell, _tile_source_id, _wall_atlas_coords(cell, gen.grid))
	for cell: Vector2i in gen.grid:
		_tile_layer.set_cell(cell, _tile_source_id, _floor_atlas_coords(cell, gen.grid))


func _floor_atlas_coords(cell: Vector2i, grid: Dictionary) -> Vector2i:
	var wall_n := not grid.has(cell + NORTH)
	var wall_s := not grid.has(cell + SOUTH)
	var wall_w := not grid.has(cell + WEST)
	var wall_e := not grid.has(cell + EAST)
	var row := 2
	if wall_n and not wall_s:
		row = 1
	elif wall_s and not wall_n:
		row = 3
	var col := 2 + _variant_index(cell, 2)
	if wall_w and not wall_e:
		col = 1
	elif wall_e and not wall_w:
		col = 4
	return Vector2i(col, row)


func _wall_atlas_coords(cell: Vector2i, grid: Dictionary) -> Vector2i:
	var n := grid.has(cell + NORTH)
	var s := grid.has(cell + SOUTH)
	var e := grid.has(cell + EAST)
	var w := grid.has(cell + WEST)
	if n and w:
		return _variant(cell, CONCAVE_NW)
	if n and e:
		return _variant(cell, CONCAVE_NE)
	if s:
		return _variant(cell, NORTH_WALL)
	if n:
		return _variant(cell, SOUTH_WALL)
	if e:
		return _variant(cell, WEST_WALL)
	if w:
		return _variant(cell, EAST_WALL)
	if grid.has(cell + Vector2i(1, 1)):
		return CONVEX_NW
	if grid.has(cell + Vector2i(-1, 1)):
		return CONVEX_NE
	if grid.has(cell + Vector2i(1, -1)):
		return CONVEX_SW
	if grid.has(cell + Vector2i(-1, -1)):
		return CONVEX_SE
	return SOLID_ROCK


func _variant(cell: Vector2i, options: Array[Vector2i]) -> Vector2i:
	return options[_variant_index(cell, options.size())]


func _variant_index(cell: Vector2i, count: int) -> int:
	var hash_value: int = (cell.x * 73856093) ^ (cell.y * 19349663)
	return (hash_value & 0x7fffffff) % count

class_name DungeonDecorator
extends RefCounted
## Adds cosmetic clutter, barrels and the shopkeeper after the dungeon geometry
## is painted. Permanent combat cover is now carved as real wall geometry by
## RoomGenerator, so this class no longer spawns standalone pillar obstacles.

const DECORATION_PATHS: Array[String] = [
	"res://assets/Wing/decorations/stacked_chairs.png",
	"res://assets/Wing/decorations/condiment_station.png",
	"res://assets/Wing/decorations/jukebox.png",
	"res://assets/Wing/decorations/potted_plant.png",
	"res://assets/Wing/decorations/trash_can.png",
	"res://assets/Wing/decorations/wing_crate.png",
	"res://assets/Wing/vending_machine.png",
]

const THEME_DECORATIONS: Dictionary = {
	DungeonGenerator.RoomTheme.BURGER: [
		"res://assets/Wing/decorations/burger_grill.png",
		"res://assets/Wing/decorations/burger_stack.png",
	],
	DungeonGenerator.RoomTheme.TACO: [
		"res://assets/Wing/decorations/taco_salsa.png",
		"res://assets/Wing/decorations/taco_tortillas.png",
	],
	DungeonGenerator.RoomTheme.PIZZA: [
		"res://assets/Wing/decorations/pizza_oven.png",
		"res://assets/Wing/decorations/pizza_boxes.png",
	],
}

const ShopkeeperTexture := preload("res://assets/Wing/shopkeeper.png")
const ExplodingBarrelScene := preload("res://scenes/dungeon/exploding_barrel/exploding_barrel.tscn")
const BARREL_CHANCE := 0.6

var _owner: Node2D
var _tile_layer: TileMapLayer
var _gameplay_layer: Node2D
var _rng := RandomNumberGenerator.new()
var _occupied_cells: Dictionary = {}


func _init(owner: Node2D, tile_layer: TileMapLayer, gameplay_layer: Node2D) -> void:
	_owner = owner
	_tile_layer = tile_layer
	_gameplay_layer = gameplay_layer


func scatter(gen: DungeonGenerator) -> void:
	_rng.seed = gen.seed_used
	_occupied_cells.clear()
	_scatter_decorations(gen)
	_scatter_barrels(gen)
	_spawn_shopkeeper(gen)


func _scatter_decorations(gen: DungeonGenerator) -> void:
	for room: Rect2i in gen.rooms:
		if gen.kind_of(room) == DungeonGenerator.RoomKind.NORMAL:
			_scatter_room(gen, room)


func _scatter_room(gen: DungeonGenerator, room: Rect2i) -> void:
	if room.size.x < 6 or room.size.y < 6:
		return
	var theme: DungeonGenerator.RoomTheme = gen.theme_of(room)
	var pool: Array = []
	for i in 3:
		pool.append_array(THEME_DECORATIONS.get(theme, []))
	pool.append_array(DECORATION_PATHS)
	var cells: Dictionary = _classify_room_cells(gen, room)
	_spawn_theme_cluster(gen, room, theme, cells.interior)
	for cell: Vector2i in _claim_from_candidates(room, cells.wall, 0.8, 6):
		_spawn_decoration(load(pool[_rng.randi_range(0, pool.size() - 1)]), cell)
	for cell: Vector2i in _claim_from_candidates(room, cells.interior, 0.5, 9):
		_spawn_decoration(load(pool[_rng.randi_range(0, pool.size() - 1)]), cell)


func _spawn_theme_cluster(gen: DungeonGenerator, room: Rect2i, theme: DungeonGenerator.RoomTheme, candidates: Array[Vector2i]) -> void:
	var themed: Array = THEME_DECORATIONS.get(theme, [])
	if themed.is_empty() or candidates.is_empty():
		return
	var anchor: Vector2i = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var pattern: Array[Vector2i] = [Vector2i.ZERO, Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 1)]
	var placed: Array[Vector2i] = []
	placed.assign(_occupied_cells.get(room, []))
	for i in pattern.size():
		var cell := anchor + pattern[i]
		if not room.has_point(cell) or not gen.grid.has(cell):
			continue
		if _near_any(cell, placed, 2):
			continue
		_spawn_decoration(load(themed[i % themed.size()]), cell)
		placed.append(cell)
	_occupied_cells[room] = placed


func _scatter_barrels(gen: DungeonGenerator) -> void:
	for room: Rect2i in gen.rooms:
		if gen.kind_of(room) != DungeonGenerator.RoomKind.NORMAL:
			continue
		if _rng.randf() >= BARREL_CHANCE:
			continue
		var cells: Dictionary = _classify_room_cells(gen, room)
		var candidates: Array[Vector2i] = cells.interior if not cells.interior.is_empty() else cells.wall
		var claimed: Array[Vector2i] = _claim_from_candidates(room, candidates, 1.0, 5)
		if not claimed.is_empty():
			_spawn_barrel(claimed[0])


func _classify_room_cells(gen: DungeonGenerator, room: Rect2i) -> Dictionary:
	var door_cells: Array[Vector2i] = []
	for span: Array in gen.get_room_exits(room):
		door_cells.append_array(span)
	var wall_cells: Array[Vector2i] = []
	var interior_cells: Array[Vector2i] = []
	for x in range(room.position.x, room.end.x):
		for y in range(room.position.y, room.end.y):
			var cell := Vector2i(x, y)
			if not gen.grid.has(cell) or _near_any(cell, door_cells, 2):
				continue
			var touches_wall := false
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not gen.grid.has(cell + offset):
					touches_wall = true
					break
			if touches_wall:
				wall_cells.append(cell)
			else:
				interior_cells.append(cell)
	return {"wall": wall_cells, "interior": interior_cells}


func _near_any(cell: Vector2i, others: Array[Vector2i], radius: int) -> bool:
	var radius_sq := radius * radius
	for other: Vector2i in others:
		if cell.distance_squared_to(other) <= radius_sq:
			return true
	return false


func _claim_from_candidates(room: Rect2i, candidates: Array[Vector2i], take_chance: float, min_spacing: int) -> Array[Vector2i]:
	var placed: Array[Vector2i] = []
	placed.assign(_occupied_cells.get(room, []))
	var claimed: Array[Vector2i] = []
	for cell: Vector2i in candidates:
		if _rng.randf() >= take_chance or _near_any(cell, placed, min_spacing):
			continue
		placed.append(cell)
		claimed.append(cell)
	_occupied_cells[room] = placed
	return claimed


func _spawn_shopkeeper(gen: DungeonGenerator) -> void:
	var room := gen.shop_room
	if room.size == Vector2i.ZERO:
		return
	var middle: Vector2i = room.position + room.size / 2
	var cell := middle + Vector2i(0, -2)
	if room.has_point(cell) and gen.grid.has(cell):
		_spawn_decoration(ShopkeeperTexture, cell)


func _spawn_decoration(texture: Texture2D, cell: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Decoration"
	sprite.texture = texture
	sprite.texture_filter = 1
	sprite.z_index = -1
	sprite.position = _tile_layer.map_to_local(cell)
	_owner.add_child(sprite, true)


func _spawn_barrel(cell: Vector2i) -> void:
	var barrel := ExplodingBarrelScene.instantiate()
	barrel.name = "Decoration"
	barrel.position = _tile_layer.map_to_local(cell)
	_gameplay_layer.add_child(barrel, true)

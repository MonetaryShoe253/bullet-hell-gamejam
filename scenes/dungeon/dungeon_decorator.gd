class_name DungeonDecorator
extends RefCounted
## Adds cosmetic clutter, barrels and the shopkeeper after the dungeon geometry
## is painted. Permanent combat cover is now carved as real wall geometry by
## RoomGenerator, so this class no longer spawns standalone pillar obstacles.
##
## Placement is footprint-aware. A decoration is not a point on a tile: a
## 32x48 prop covers 2x3 tiles, and the old code centred every sprite on a
## single cell, so tall props punched straight through the wall above and hung
## over the floor below. Every prop now declares nothing but its placement
## rule; its footprint is derived from the texture, and a candidate cell is
## only accepted when every tile the sprite will physically cover is verified
## floor inside the room.

## How a prop wants to meet the world.
##   FLOOR       - stands free, base resting on the bottom of its footprint.
##   WALL_BACKED - equipment that belongs against a wall (freezer door, sauce
##                 taps, ovens, vending machines). Requires wall directly above
##                 the footprint, and is drawn touching it.
enum Placement { FLOOR, WALL_BACKED }

const TILE_PX := 16

const DECORATIONS: Array[Dictionary] = [
	{"path": "res://assets/Dungeon/decorations/stacked_chairs.png", "placement": Placement.FLOOR},
	{"path": "res://assets/Dungeon/decorations/condiment_station.png", "placement": Placement.FLOOR},
	{"path": "res://assets/Dungeon/decorations/potted_plant.png", "placement": Placement.FLOOR},
	{"path": "res://assets/Dungeon/decorations/trash_can.png", "placement": Placement.FLOOR},
	{"path": "res://assets/Dungeon/decorations/wing_crate.png", "placement": Placement.FLOOR},
	{"path": "res://assets/Dungeon/decorations/mop_bucket.png", "placement": Placement.FLOOR},
	{"path": "res://assets/Dungeon/decorations/sauce_vat.png", "placement": Placement.FLOOR},
	{"path": "res://assets/Dungeon/decorations/prep_counter.png", "placement": Placement.FLOOR},
	{"path": "res://assets/Dungeon/decorations/jukebox.png", "placement": Placement.WALL_BACKED},
	{"path": "res://assets/Dungeon/vending_machine.png", "placement": Placement.WALL_BACKED},
	{"path": "res://assets/Dungeon/decorations/deep_fryer.png", "placement": Placement.WALL_BACKED},
	{"path": "res://assets/Dungeon/decorations/heat_lamp.png", "placement": Placement.WALL_BACKED},
	{"path": "res://assets/Dungeon/decorations/freezer_door.png", "placement": Placement.WALL_BACKED},
	{"path": "res://assets/Dungeon/decorations/sauce_taps.png", "placement": Placement.WALL_BACKED},
]

const THEME_DECORATIONS: Dictionary = {
	DungeonGenerator.RoomTheme.BURGER: [
		{"path": "res://assets/Dungeon/decorations/burger_grill.png", "placement": Placement.WALL_BACKED},
		{"path": "res://assets/Dungeon/decorations/burger_stack.png", "placement": Placement.FLOOR},
	],
	DungeonGenerator.RoomTheme.TACO: [
		{"path": "res://assets/Dungeon/decorations/taco_salsa.png", "placement": Placement.FLOOR},
		{"path": "res://assets/Dungeon/decorations/taco_tortillas.png", "placement": Placement.FLOOR},
	],
	DungeonGenerator.RoomTheme.PIZZA: [
		{"path": "res://assets/Dungeon/decorations/pizza_oven.png", "placement": Placement.WALL_BACKED},
		{"path": "res://assets/Dungeon/decorations/pizza_boxes.png", "placement": Placement.FLOOR},
	],
	DungeonGenerator.RoomTheme.WING: [
		{"path": "res://assets/Dungeon/decorations/wing_warmer.png", "placement": Placement.WALL_BACKED},
		{"path": "res://assets/Dungeon/decorations/wing_crate.png", "placement": Placement.FLOOR},
	],
}

const ShopkeeperTexture := preload("res://assets/Dungeon/shopkeeper.png")
const ExplodingBarrelScene := preload("res://scenes/dungeon/exploding_barrel/exploding_barrel.tscn")
const BARREL_CHANCE := 0.6
## The barrel keeps its own centred sprite, so it needs clear floor all around
## rather than a corner-anchored footprint.
const BARREL_CLEARANCE := 1

## Prop counts scale with the room rather than being a flat cap -- a flat cap
## leaves a 30x25 arena looking abandoned while over-stuffing a 6x6 closet.
## Wall props track the perimeter, floor clutter tracks the area.
const WALL_PROPS_PER_PERIMETER := 9.0
const WALL_PROPS_RANGE := Vector2i(2, 9)
const FLOOR_PROPS_PER_AREA := 70.0
const FLOOR_PROPS_RANGE := Vector2i(1, 7)

var _owner: Node2D
var _tile_layer: TileMapLayer
var _gameplay_layer: Node2D
var _rng := RandomNumberGenerator.new()
## room -> { Vector2i: true } for every tile a placed prop physically covers.
var _occupied: Dictionary = {}


func _init(owner: Node2D, tile_layer: TileMapLayer, gameplay_layer: Node2D) -> void:
	_owner = owner
	_tile_layer = tile_layer
	_gameplay_layer = gameplay_layer


func scatter(gen: DungeonGenerator) -> void:
	_rng.seed = gen.seed_used
	_occupied.clear()
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
	var themed: Array = THEME_DECORATIONS.get(theme, [])

	# The room's own theme gets weighted up so a room reads as belonging to one
	# food stand rather than as a random pile of kitchen equipment.
	var pool: Array[Dictionary] = []
	for i in 3:
		for entry: Dictionary in themed:
			pool.append(entry)
	for entry: Dictionary in DECORATIONS:
		pool.append(entry)

	var cells: Dictionary = _classify_room_cells(gen, room)
	var perimeter := 2 * (room.size.x + room.size.y)
	var area := room.size.x * room.size.y
	var wall_budget := clampi(roundi(perimeter / WALL_PROPS_PER_PERIMETER),
			WALL_PROPS_RANGE.x, WALL_PROPS_RANGE.y)
	var floor_budget := clampi(roundi(area / FLOOR_PROPS_PER_AREA),
			FLOOR_PROPS_RANGE.x, FLOOR_PROPS_RANGE.y)
	_place_batch(gen, room, pool, cells.wall, Placement.WALL_BACKED, wall_budget)
	_place_batch(gen, room, pool, cells.interior, Placement.FLOOR, floor_budget)


## Tries to seat `count` props drawn from `pool` on `candidates`. An entry whose
## placement rule does not match `want` is skipped, so the wall pass only ever
## considers wall-backed equipment and the interior pass only free-standing
## clutter.
func _place_batch(gen: DungeonGenerator, room: Rect2i, pool: Array[Dictionary],
		candidates: Array[Vector2i], want: Placement, count: int) -> void:
	if candidates.is_empty():
		return
	var shuffled: Array[Vector2i] = candidates.duplicate()
	_shuffle(shuffled)
	var placed := 0
	var attempts := 0
	var limit: int = count * 12
	while placed < count and attempts < limit:
		attempts += 1
		var entry: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
		if entry.placement != want:
			continue
		var texture: Texture2D = load(entry.path)
		var size := _footprint(texture)
		for cell: Vector2i in shuffled:
			if not _fits(gen, room, cell, size, entry.placement):
				continue
			_spawn_decoration(texture, cell, size, entry.placement)
			_occupy(room, cell, size)
			placed += 1
			break


## True when every tile the sprite will cover is free floor inside the room,
## and - for wall-backed props - the row immediately above the footprint is
## solid wall for the prop to sit against.
func _fits(gen: DungeonGenerator, room: Rect2i, cell: Vector2i, size: Vector2i,
		placement: Placement) -> bool:
	var taken: Dictionary = _occupied.get(room, {})
	var top := cell.y - size.y + 1
	for dx in size.x:
		for dy in size.y:
			var c := Vector2i(cell.x + dx, top + dy)
			if not room.has_point(c) or not gen.grid.has(c):
				return false
			if taken.has(c):
				return false
	if placement == Placement.WALL_BACKED:
		for dx in size.x:
			# Must be rock, not floor: this is the wall the prop leans on.
			if gen.grid.has(Vector2i(cell.x + dx, top - 1)):
				return false
	return true


func _occupy(room: Rect2i, cell: Vector2i, size: Vector2i) -> void:
	var taken: Dictionary = _occupied.get(room, {})
	var top := cell.y - size.y + 1
	for dx in size.x:
		for dy in size.y:
			taken[Vector2i(cell.x + dx, top + dy)] = true
	_occupied[room] = taken


## Tiles a texture covers, rounded up. A 32x40 prop claims 2x3 and simply
## leaves 8px of slack, which is cheaper than letting it overhang.
func _footprint(texture: Texture2D) -> Vector2i:
	var px := texture.get_size()
	return Vector2i(ceili(px.x / float(TILE_PX)), ceili(px.y / float(TILE_PX)))


func _scatter_barrels(gen: DungeonGenerator) -> void:
	for room: Rect2i in gen.rooms:
		if gen.kind_of(room) != DungeonGenerator.RoomKind.NORMAL:
			continue
		if _rng.randf() >= BARREL_CHANCE:
			continue
		var cells: Dictionary = _classify_room_cells(gen, room)
		var candidates: Array[Vector2i] = cells.interior if not cells.interior.is_empty() else cells.wall
		if candidates.is_empty():
			continue
		var shuffled: Array[Vector2i] = candidates.duplicate()
		_shuffle(shuffled)
		for cell: Vector2i in shuffled:
			if not _has_clearance(gen, room, cell, BARREL_CLEARANCE):
				continue
			_spawn_barrel(cell)
			_occupy(room, Vector2i(cell.x - BARREL_CLEARANCE, cell.y + BARREL_CLEARANCE),
					Vector2i.ONE * (BARREL_CLEARANCE * 2 + 1))
			break


## Free floor in every direction, for objects that draw centred on their cell.
func _has_clearance(gen: DungeonGenerator, room: Rect2i, cell: Vector2i, radius: int) -> bool:
	var taken: Dictionary = _occupied.get(room, {})
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var c := cell + Vector2i(dx, dy)
			if not room.has_point(c) or not gen.grid.has(c) or taken.has(c):
				return false
	return true


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


func _shuffle(cells: Array[Vector2i]) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp


func _spawn_shopkeeper(gen: DungeonGenerator) -> void:
	var room := gen.shop_room
	if room.size == Vector2i.ZERO:
		return
	var size := _footprint(ShopkeeperTexture)
	var middle: Vector2i = room.position + room.size / 2
	# Centre the footprint on the room's middle column rather than its corner.
	var cell := Vector2i(middle.x - size.x / 2, middle.y - 2)
	if _fits(gen, room, cell, size, Placement.FLOOR):
		_spawn_decoration(ShopkeeperTexture, cell, size, Placement.FLOOR)
		_occupy(room, cell, size)


## `cell` is the BOTTOM-LEFT tile of the footprint. The sprite is grid-aligned
## to that footprint rather than centred on the cell, so it can never bleed into
## a neighbouring tile that was not checked.
func _spawn_decoration(texture: Texture2D, cell: Vector2i, size: Vector2i,
		placement: Placement) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Decoration"
	sprite.texture = texture
	sprite.texture_filter = 1
	sprite.z_index = -1
	sprite.position = _tile_layer.map_to_local(cell)
	sprite.offset = _draw_offset(texture, size, placement)
	_owner.add_child(sprite, true)


## map_to_local() returns the tile CENTRE, so both offsets are measured from
## there. They come out independent of the cell, which is the check that the
## alignment is right: a prop's offset is a property of its art, not of where
## it lands.
##   x: left edge of the sprite on the left edge of the footprint.
##   y: FLOOR       -> bottom edge of the sprite on the floor (footprint bottom)
##      WALL_BACKED -> top edge of the sprite against the wall (footprint top)
func _draw_offset(texture: Texture2D, size: Vector2i, placement: Placement) -> Vector2:
	var px := texture.get_size()
	var half := TILE_PX / 2.0
	var x := px.x / 2.0 - half
	var y := half - px.y / 2.0
	if placement == Placement.WALL_BACKED:
		y = (1 - size.y) * TILE_PX - half + px.y / 2.0
	return Vector2(x, y)


func _spawn_barrel(cell: Vector2i) -> void:
	var barrel := ExplodingBarrelScene.instantiate()
	barrel.name = "Decoration"
	barrel.position = _tile_layer.map_to_local(cell)
	_gameplay_layer.add_child(barrel, true)

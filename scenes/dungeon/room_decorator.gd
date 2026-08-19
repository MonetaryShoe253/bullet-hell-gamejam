class_name RoomGenerator
extends RefCounted
## Designs the inside of NORMAL rooms by carving permanent cover directly out
## of DungeonGenerator.grid.
##
## Room generation is intentionally archetype-first: each room gets one strong,
## readable composition and that composition is only varied by rotation/mirroring
## and modest size changes. Patterns are carved atomically, so an irregular room
## never ends up with "half" of a layout after one or two blocks fail to fit.

# Existing enum values are preserved for compatibility with any code that stores
# or inspects room plan types. Two new archetypes are appended at the end.
enum Type {
	OPEN,
	PILLARS,
	LANES,
	RING,
	CLUSTERS,
	CROSSFIRE,
	FORTIFIED,
	KILLBOX,
	BOOTHS,
	U_SHAPE,
}

# Names are deliberately architectural rather than food-specific. The existing
# BURGER/TACO/PIZZA theme can keep driving decoration/enemies for now; these names
# give a future decorator a stable structural identity to skin as kitchen,
# dining-room, freezer, service-counter, etc.
const LAYOUT_NAMES := {
	Type.OPEN: "Open Court",
	Type.PILLARS: "Four Pillars",
	Type.LANES: "Twin Counters",
	Type.RING: "Broken Ring",
	Type.CLUSTERS: "Prep Islands",
	Type.CROSSFIRE: "Cross Kitchen",
	Type.FORTIFIED: "Service Counter",
	Type.KILLBOX: "Freezer Aisles",
	Type.BOOTHS: "Dining Booths",
	Type.U_SHAPE: "Drive-Thru U",
}

const VISUAL_ROLES := {
	Type.OPEN: "dining",
	Type.PILLARS: "prep",
	Type.LANES: "kitchen",
	Type.RING: "kitchen",
	Type.CLUSTERS: "prep",
	Type.CROSSFIRE: "service",
	Type.FORTIFIED: "service",
	Type.KILLBOX: "freezer",
	Type.BOOTHS: "dining",
	Type.U_SHAPE: "drive_thru",
}

const BASE_WEIGHTS := {
	Type.OPEN: 0.75,
	Type.PILLARS: 1.15,
	Type.LANES: 1.0,
	Type.RING: 0.9,
	Type.CLUSTERS: 1.0,
	Type.CROSSFIRE: 0.9,
	Type.FORTIFIED: 0.85,
	Type.KILLBOX: 0.7,
	Type.BOOTHS: 0.95,
	Type.U_SHAPE: 0.65,
}

const ORTHOGONAL: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

# Strongly suppress immediately repeated layouts, and suppress a layout already
# assigned to a directly adjacent room even harder. This keeps a floor's roster
# varied without making generation deterministic or exhausting a rigid bag.
const RECENT_REPEAT_MULTIPLIER := 0.08
const ADJACENT_REPEAT_MULTIPLIER := 0.03


func generate_all(gen: DungeonGenerator, rng: RandomNumberGenerator, level: int) -> void:
	gen.room_plans.clear()
	gen.room_wall_cells.clear()
	gen.enemy_spawn_zones.clear()
	gen.reserved_cells.clear()

	var assigned: Dictionary = {} # Rect2i -> Type
	var recent: Array[Type] = []

	for room: Rect2i in gen.rooms:
		if gen.kind_of(room) != DungeonGenerator.RoomKind.NORMAL:
			continue

		var room_type := _pick_type(gen, room, gen.theme_of(room), level, rng, assigned, recent)
		var data := _generate_room(gen, room, room_type, level, rng)
		gen.room_plans[room] = data
		gen.room_wall_cells[room] = data.get("wall_cells", [])
		gen.enemy_spawn_zones[room] = data.get("spawn_zones", [])
		gen.reserved_cells[room] = data.get("reserved_cells", [])

		var final_type: Type = data.get("type", room_type)
		assigned[room] = final_type
		recent.append(final_type)
		if recent.size() > 2:
			recent.pop_front()


func _available_types(level: int) -> Array[Type]:
	var result: Array[Type] = [
		Type.OPEN,
		Type.PILLARS,
		Type.LANES,
		Type.RING,
		Type.CLUSTERS,
		Type.CROSSFIRE,
	]
	if level >= 2:
		result.append(Type.FORTIFIED)
		result.append(Type.BOOTHS)
	if level >= 4:
		result.append(Type.KILLBOX)
		result.append(Type.U_SHAPE)
	return result


func _pick_type(
	gen: DungeonGenerator,
	room: Rect2i,
	theme: DungeonGenerator.RoomTheme,
	level: int,
	rng: RandomNumberGenerator,
	assigned: Dictionary,
	recent: Array[Type]
) -> Type:
	var available := _available_types(level)
	var total := 0.0
	var weights: Array[float] = []

	for room_type: Type in available:
		var weight := float(BASE_WEIGHTS.get(room_type, 1.0))

		# Keep the old food themes useful, but make them a light preference rather
		# than the main source of room identity. Structural archetypes do the heavy
		# lifting now and can later be reskinned by a dedicated restaurant-zone theme.
		match theme:
			DungeonGenerator.RoomTheme.BURGER:
				if room_type in [Type.PILLARS, Type.CLUSTERS, Type.FORTIFIED]:
					weight *= 1.18
			DungeonGenerator.RoomTheme.TACO:
				if room_type in [Type.OPEN, Type.RING, Type.BOOTHS]:
					weight *= 1.18
			DungeonGenerator.RoomTheme.PIZZA:
				if room_type in [Type.LANES, Type.CROSSFIRE, Type.KILLBOX]:
					weight *= 1.18

		if not recent.is_empty() and room_type == recent[-1]:
			weight *= RECENT_REPEAT_MULTIPLIER
		elif recent.has(room_type):
			weight *= 0.35

		for neighbour: Rect2i in gen.room_adjacency.get(room, []):
			if assigned.get(neighbour, -1) == room_type:
				weight *= ADJACENT_REPEAT_MULTIPLIER
				break

		weights.append(weight)
		total += weight

	var roll := rng.randf() * total
	for i in available.size():
		roll -= weights[i]
		if roll <= 0.0:
			return available[i]
	return available[-1]


func _generate_room(gen: DungeonGenerator, room: Rect2i, room_type: Type, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var reserved := _build_reserved_cells(gen, room)
	var data := {
		"type": room_type,
		"layout_name": LAYOUT_NAMES.get(room_type, "Unknown"),
		"visual_role": VISUAL_ROLES.get(room_type, "generic"),
		"difficulty": _base_difficulty(room_type) * (1.0 + minf(float(level - 1) * 0.025, 0.35)),
		"wall_cells": [],
		"spawn_zones": [],
		"reserved_cells": reserved,
		"orientation": "horizontal",
		"mirrored": false,
	}

	var success := true
	match room_type:
		Type.OPEN:
			success = _generate_open(gen, room, level, rng, data)
		Type.PILLARS:
			success = _generate_four_pillars(gen, room, rng, data)
		Type.LANES:
			success = _generate_twin_counters(gen, room, rng, data)
		Type.RING:
			success = _generate_broken_ring(gen, room, rng, data)
		Type.CLUSTERS:
			success = _generate_prep_islands(gen, room, rng, data)
		Type.CROSSFIRE:
			success = _generate_cross_kitchen(gen, room, rng, data)
		Type.FORTIFIED:
			success = _generate_service_counter(gen, room, rng, data)
		Type.KILLBOX:
			success = _generate_freezer_aisles(gen, room, rng, data)
		Type.BOOTHS:
			success = _generate_dining_booths(gen, room, rng, data)
		Type.U_SHAPE:
			success = _generate_drive_thru_u(gen, room, rng, data)

	# Irregular silhouettes can occasionally make a full archetype impossible.
	# Never keep a broken half-layout: fall back to a clean open room instead.
	if not success:
		data.type = Type.OPEN
		data.layout_name = LAYOUT_NAMES[Type.OPEN]
		data.visual_role = VISUAL_ROLES[Type.OPEN]
		data.difficulty = _base_difficulty(Type.OPEN)

	# room_cells was captured before corridors were carved so unrelated corridors
	# never become part of a room trigger. Remove only floor deliberately converted
	# into internal walls.
	var current_cells: Array[Vector2i] = []
	for cell: Vector2i in gen.room_cells.get(room, []):
		if gen.grid.has(cell):
			current_cells.append(cell)
	gen.room_cells[room] = current_cells

	data.spawn_zones = _make_spawn_zones(gen, room, reserved)
	return data


func _base_difficulty(room_type: Type) -> float:
	match room_type:
		Type.OPEN: return 0.9
		Type.PILLARS: return 1.0
		Type.LANES: return 1.05
		Type.RING: return 1.08
		Type.CLUSTERS: return 1.08
		Type.CROSSFIRE: return 1.15
		Type.FORTIFIED: return 1.2
		Type.KILLBOX: return 1.3
		Type.BOOTHS: return 1.08
		Type.U_SHAPE: return 1.25
	return 1.0


# --- Strong room archetypes -------------------------------------------------

func _generate_open(gen: DungeonGenerator, room: Rect2i, level: int, rng: RandomNumberGenerator, data: Dictionary) -> bool:
	# A genuine breather room. Keeping this completely open makes it read as a
	# deliberate archetype rather than "the room where some props failed".
	data.orientation = "open"
	return true


func _generate_four_pillars(gen: DungeonGenerator, room: Rect2i, rng: RandomNumberGenerator, data: Dictionary) -> bool:
	var c := _center(room)
	var ox := maxi(5, mini(8, room.size.x / 4))
	var oy := maxi(5, mini(7, room.size.y / 4))
	var blocks: Array[Dictionary] = []
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			blocks.append(_block(c + Vector2i(ox * sx, oy * sy), Vector2i(3, 3)))
	data.orientation = "symmetric"
	return _try_carve_pattern(gen, room, data, blocks)


func _generate_twin_counters(gen: DungeonGenerator, room: Rect2i, rng: RandomNumberGenerator, data: Dictionary) -> bool:
	var c := _center(room)
	var vertical := rng.randf() < 0.5
	var mirrored := rng.randf() < 0.5
	var blocks: Array[Dictionary] = []
	if vertical:
		var length := maxi(7, mini(11, room.size.y / 3))
		var offset := maxi(5, mini(8, room.size.x / 4))
		blocks = [
			_block(c + Vector2i(-offset, -2 if mirrored else 2), Vector2i(3, length)),
			_block(c + Vector2i(offset, 2 if mirrored else -2), Vector2i(3, length)),
		]
		data.orientation = "vertical"
	else:
		var length := maxi(7, mini(11, room.size.x / 3))
		var offset := maxi(5, mini(8, room.size.y / 4))
		blocks = [
			_block(c + Vector2i(-2 if mirrored else 2, -offset), Vector2i(length, 3)),
			_block(c + Vector2i(2 if mirrored else -2, offset), Vector2i(length, 3)),
		]
		data.orientation = "horizontal"
	data.mirrored = mirrored
	return _try_carve_pattern(gen, room, data, blocks)


func _generate_broken_ring(gen: DungeonGenerator, room: Rect2i, rng: RandomNumberGenerator, data: Dictionary) -> bool:
	var c := _center(room)
	var rx := maxi(6, mini(8, room.size.x / 4))
	var ry := maxi(6, mini(8, room.size.y / 4))
	var hlen := maxi(5, mini(9, room.size.x / 4))
	var vlen := maxi(5, mini(9, room.size.y / 4))
	var blocks: Array[Dictionary] = [
		_block(c + Vector2i(0, -ry), Vector2i(hlen, 3)),
		_block(c + Vector2i(0, ry), Vector2i(hlen, 3)),
		_block(c + Vector2i(-rx, 0), Vector2i(3, vlen)),
		_block(c + Vector2i(rx, 0), Vector2i(3, vlen)),
	]
	data.orientation = "symmetric"
	return _try_carve_pattern(gen, room, data, blocks)


func _generate_prep_islands(gen: DungeonGenerator, room: Rect2i, rng: RandomNumberGenerator, data: Dictionary) -> bool:
	var c := _center(room)
	var ox := maxi(5, mini(7, room.size.x / 4))
	var oy := maxi(5, mini(7, room.size.y / 4))
	var vertical := rng.randf() < 0.5
	var island_size := Vector2i(3, 5) if vertical else Vector2i(5, 3)
	var blocks: Array[Dictionary] = [
		_block(c + Vector2i(-ox, -oy), island_size),
		_block(c + Vector2i(ox, -oy), island_size),
		_block(c + Vector2i(-ox, oy), island_size),
		_block(c + Vector2i(ox, oy), island_size),
	]
	data.orientation = "vertical" if vertical else "horizontal"
	return _try_carve_pattern(gen, room, data, blocks)


func _generate_cross_kitchen(gen: DungeonGenerator, room: Rect2i, rng: RandomNumberGenerator, data: Dictionary) -> bool:
	var c := _center(room)
	var dx := maxi(6, mini(9, room.size.x / 4))
	var dy := maxi(6, mini(9, room.size.y / 4))
	var hlen := maxi(5, mini(7, room.size.x / 5))
	var vlen := maxi(5, mini(7, room.size.y / 5))
	var blocks: Array[Dictionary] = [
		_block(c + Vector2i(-dx, 0), Vector2i(hlen, 3)),
		_block(c + Vector2i(dx, 0), Vector2i(hlen, 3)),
		_block(c + Vector2i(0, -dy), Vector2i(3, vlen)),
		_block(c + Vector2i(0, dy), Vector2i(3, vlen)),
	]
	data.orientation = "symmetric"
	return _try_carve_pattern(gen, room, data, blocks)


func _generate_service_counter(gen: DungeonGenerator, room: Rect2i, rng: RandomNumberGenerator, data: Dictionary) -> bool:
	var c := _center(room)
	var vertical := rng.randf() < 0.5
	var mirrored := rng.randf() < 0.5
	var side := -1 if mirrored else 1
	var blocks: Array[Dictionary] = []
	if vertical:
		var length := maxi(9, mini(15, room.size.y / 2))
		var offset := maxi(5, mini(8, room.size.x / 4))
		blocks = [
			_block(c + Vector2i(offset * side, 0), Vector2i(3, length)),
			_block(c + Vector2i(-offset * side, -5), Vector2i(3, 3)),
			_block(c + Vector2i(-offset * side, 5), Vector2i(3, 3)),
		]
		data.orientation = "vertical"
	else:
		var length := maxi(9, mini(15, room.size.x / 2))
		var offset := maxi(5, mini(8, room.size.y / 4))
		blocks = [
			_block(c + Vector2i(0, offset * side), Vector2i(length, 3)),
			_block(c + Vector2i(-5, -offset * side), Vector2i(3, 3)),
			_block(c + Vector2i(5, -offset * side), Vector2i(3, 3)),
		]
		data.orientation = "horizontal"
	data.mirrored = mirrored
	return _try_carve_pattern(gen, room, data, blocks)


func _generate_freezer_aisles(gen: DungeonGenerator, room: Rect2i, rng: RandomNumberGenerator, data: Dictionary) -> bool:
	var c := _center(room)
	var vertical := rng.randf() < 0.5
	var blocks: Array[Dictionary] = []
	if vertical:
		var length := maxi(9, mini(13, room.size.y / 2))
		var spacing := maxi(5, mini(7, room.size.x / 5))
		for xoff in [-spacing, spacing]:
			blocks.append(_block(c + Vector2i(xoff, 0), Vector2i(3, length)))
		data.orientation = "vertical"
	else:
		var length := maxi(9, mini(13, room.size.x / 2))
		var spacing := maxi(5, mini(7, room.size.y / 5))
		for yoff in [-spacing, spacing]:
			blocks.append(_block(c + Vector2i(0, yoff), Vector2i(length, 3)))
		data.orientation = "horizontal"
	return _try_carve_pattern(gen, room, data, blocks)


func _generate_dining_booths(gen: DungeonGenerator, room: Rect2i, rng: RandomNumberGenerator, data: Dictionary) -> bool:
	var c := _center(room)
	var vertical := rng.randf() < 0.5
	var blocks: Array[Dictionary] = []
	if vertical:
		var xoff := maxi(6, mini(8, room.size.x / 4))
		var yoff := maxi(4, mini(6, room.size.y / 5))
		for sx in [-1, 1]:
			for sy in [-1, 0, 1]:
				blocks.append(_block(c + Vector2i(xoff * sx, yoff * sy), Vector2i(3, 3)))
		data.orientation = "vertical"
	else:
		var yoff := maxi(6, mini(8, room.size.y / 4))
		var xoff := maxi(4, mini(6, room.size.x / 5))
		for sy in [-1, 1]:
			for sx in [-1, 0, 1]:
				blocks.append(_block(c + Vector2i(xoff * sx, yoff * sy), Vector2i(3, 3)))
		data.orientation = "horizontal"
	return _try_carve_pattern(gen, room, data, blocks)


func _generate_drive_thru_u(gen: DungeonGenerator, room: Rect2i, rng: RandomNumberGenerator, data: Dictionary) -> bool:
	var c := _center(room)
	var rotation := rng.randi_range(0, 3)
	var arm := maxi(7, mini(11, mini(room.size.x, room.size.y) / 3))
	var half_gap := maxi(5, mini(7, mini(room.size.x, room.size.y) / 4))
	var blocks: Array[Dictionary] = []

	match rotation:
		0: # open south
			blocks = [
				_block(c + Vector2i(0, -half_gap), Vector2i(arm + 4, 3)),
				_block(c + Vector2i(-half_gap, 1), Vector2i(3, arm)),
				_block(c + Vector2i(half_gap, 1), Vector2i(3, arm)),
			]
			data.orientation = "north"
		1: # open north
			blocks = [
				_block(c + Vector2i(0, half_gap), Vector2i(arm + 4, 3)),
				_block(c + Vector2i(-half_gap, -1), Vector2i(3, arm)),
				_block(c + Vector2i(half_gap, -1), Vector2i(3, arm)),
			]
			data.orientation = "south"
		2: # open east
			blocks = [
				_block(c + Vector2i(-half_gap, 0), Vector2i(3, arm + 4)),
				_block(c + Vector2i(1, -half_gap), Vector2i(arm, 3)),
				_block(c + Vector2i(1, half_gap), Vector2i(arm, 3)),
			]
			data.orientation = "west"
		3: # open west
			blocks = [
				_block(c + Vector2i(half_gap, 0), Vector2i(3, arm + 4)),
				_block(c + Vector2i(-1, -half_gap), Vector2i(arm, 3)),
				_block(c + Vector2i(-1, half_gap), Vector2i(arm, 3)),
			]
			data.orientation = "east"

	return _try_carve_pattern(gen, room, data, blocks)


# --- Atomic pattern carving -------------------------------------------------

func _block(centre: Vector2i, size: Vector2i) -> Dictionary:
	return {"centre": centre, "size": size}


func _try_carve_pattern(gen: DungeonGenerator, room: Rect2i, data: Dictionary, blocks: Array[Dictionary]) -> bool:
	var reserved: Array = data.reserved_cells
	var removed_set: Dictionary = {}
	var removed: Array[Vector2i] = []

	# Validate the whole composition first. This is the key difference from the
	# old generator: a six-piece design is either six pieces or zero pieces.
	for block: Dictionary in blocks:
		var centre: Vector2i = block.centre
		var requested_size: Vector2i = block.size
		var safe_size := Vector2i(maxi(requested_size.x, 3), maxi(requested_size.y, 3))
		var start := centre - safe_size / 2
		var candidate := Rect2i(start, safe_size)

		for x in range(candidate.position.x, candidate.end.x):
			for y in range(candidate.position.y, candidate.end.y):
				var cell := Vector2i(x, y)
				if not room.has_point(cell) or not gen.grid.has(cell) or reserved.has(cell):
					return false
				if not removed_set.has(cell):
					removed_set[cell] = true
					removed.append(cell)

	if removed.is_empty():
		return false

	for cell: Vector2i in removed:
		gen.grid.erase(cell)

	# Reject the complete composition if it splits the playable floor. Rollback is
	# atomic, so failed patterns never leave behind messy partial structures.
	if not _room_floor_connected(gen, room):
		for cell: Vector2i in removed:
			gen.grid[cell] = DungeonGenerator.Cell.FLOOR
		return false

	var wall_cells: Array = data.wall_cells
	wall_cells.append_array(removed)
	return true


func _room_floor_connected(gen: DungeonGenerator, room: Rect2i) -> bool:
	var valid: Dictionary = {}
	for cell: Vector2i in gen.room_cells.get(room, []):
		if gen.grid.has(cell):
			valid[cell] = true
	if valid.is_empty():
		return false

	var start: Vector2i = valid.keys()[0]
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for offset: Vector2i in ORTHOGONAL:
			var next := cell + offset
			if valid.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen.size() == valid.size()


func _build_reserved_cells(gen: DungeonGenerator, room: Rect2i) -> Array[Vector2i]:
	var reserved: Array[Vector2i] = []
	var c := _center(room)

	# Keep a clean central dodge/through-route in every archetype. This is also
	# important because corridor routing still targets room centres.
	for x in range(c.x - 2, c.x + 3):
		for y in range(c.y - 2, c.y + 3):
			var cell := Vector2i(x, y)
			if gen.grid.has(cell):
				reserved.append(cell)

	# Entrances receive a generous clear throat so a strong composition never
	# compromises the doorway/gate fixes elsewhere in the dungeon system.
	for span: Array in gen.get_room_exits(room):
		for door: Vector2i in span:
			for dx in range(-4, 5):
				for dy in range(-4, 5):
					var cell := door + Vector2i(dx, dy)
					if room.has_point(cell) and gen.grid.has(cell) and not reserved.has(cell):
						reserved.append(cell)
	return reserved


func _make_spawn_zones(gen: DungeonGenerator, room: Rect2i, reserved: Array) -> Array[Dictionary]:
	var c := _center(room)
	var buckets := {"north": [], "south": [], "west": [], "east": [], "centre": []}
	for cell: Vector2i in gen.room_cells.get(room, []):
		if not gen.grid.has(cell) or reserved.has(cell):
			continue
		if cell.x < room.position.x + 3 or cell.x >= room.end.x - 3 or cell.y < room.position.y + 3 or cell.y >= room.end.y - 3:
			continue
		var dx := cell.x - c.x
		var dy := cell.y - c.y
		if abs(dx) <= 4 and abs(dy) <= 4:
			buckets.centre.append(cell)
		elif abs(dx) > abs(dy):
			if dx < 0:
				buckets.west.append(cell)
			else:
				buckets.east.append(cell)
		else:
			if dy < 0:
				buckets.north.append(cell)
			else:
				buckets.south.append(cell)

	var zones: Array[Dictionary] = []
	for name in ["north", "south", "west", "east", "centre"]:
		if not buckets[name].is_empty():
			zones.append({"name": name, "cells": buckets[name]})
	return zones


func _center(room: Rect2i) -> Vector2i:
	return room.position + room.size / 2

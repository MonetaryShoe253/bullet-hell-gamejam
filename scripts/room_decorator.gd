class_name RoomGenerator
extends RefCounted
## Designs the inside of NORMAL rooms by carving permanent cover directly out
## of DungeonGenerator.grid. The renderer then turns those missing floor cells
## into the same wall/rock tiles used by the rest of the dungeon.
##
## Adding a room type still means one enum value, one generator function and one
## match branch. No room scenes or obstacle sprites are required.

enum Type {
	OPEN,
	PILLARS,
	LANES,
	RING,
	CLUSTERS,
	CROSSFIRE,
	FORTIFIED,
	KILLBOX,
}

const BASE_WEIGHTS := {
	Type.OPEN: 0.8,
	Type.PILLARS: 1.2,
	Type.LANES: 1.0,
	Type.RING: 1.0,
	Type.CLUSTERS: 1.0,
	Type.CROSSFIRE: 0.9,
	Type.FORTIFIED: 0.75,
	Type.KILLBOX: 0.45,
}

const ORTHOGONAL: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


func generate_all(gen: DungeonGenerator, rng: RandomNumberGenerator, level: int) -> void:
	gen.room_plans.clear()
	gen.room_wall_cells.clear()
	gen.enemy_spawn_zones.clear()
	gen.reserved_cells.clear()

	for room: Rect2i in gen.rooms:
		if gen.kind_of(room) != DungeonGenerator.RoomKind.NORMAL:
			continue

		var room_type := _pick_type(gen.theme_of(room), level, rng)
		var data := _generate_room(gen, room, room_type, level, rng)
		gen.room_plans[room] = data
		gen.room_wall_cells[room] = data.get("wall_cells", [])
		gen.enemy_spawn_zones[room] = data.get("spawn_zones", [])
		gen.reserved_cells[room] = data.get("reserved_cells", [])


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
	if level >= 4:
		result.append(Type.KILLBOX)
	return result


func _pick_type(theme: DungeonGenerator.RoomTheme, level: int, rng: RandomNumberGenerator) -> Type:
	var available := _available_types(level)
	var total := 0.0
	var weights: Array[float] = []

	for room_type: Type in available:
		var weight := float(BASE_WEIGHTS.get(room_type, 1.0))
		match theme:
			DungeonGenerator.RoomTheme.BURGER:
				if room_type in [Type.CLUSTERS, Type.FORTIFIED, Type.PILLARS]:
					weight *= 1.35
			DungeonGenerator.RoomTheme.TACO:
				if room_type in [Type.OPEN, Type.RING, Type.PILLARS]:
					weight *= 1.35
			DungeonGenerator.RoomTheme.PIZZA:
				if room_type in [Type.LANES, Type.CROSSFIRE, Type.PILLARS]:
					weight *= 1.35
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
		"difficulty": _base_difficulty(room_type) * (1.0 + minf(float(level - 1) * 0.025, 0.35)),
		"wall_cells": [],
		"spawn_zones": [],
		"reserved_cells": reserved,
	}

	match room_type:
		Type.OPEN:
			_generate_open(gen, room, level, rng, data)
		Type.PILLARS:
			_generate_pillars(gen, room, level, rng, data)
		Type.LANES:
			_generate_lanes(gen, room, level, rng, data)
		Type.RING:
			_generate_ring(gen, room, level, rng, data)
		Type.CLUSTERS:
			_generate_clusters(gen, room, level, rng, data)
		Type.CROSSFIRE:
			_generate_crossfire(gen, room, level, rng, data)
		Type.FORTIFIED:
			_generate_fortified(gen, room, level, rng, data)
		Type.KILLBOX:
			_generate_killbox(gen, room, level, rng, data)

	# room_cells was captured before corridors were carved so unrelated corridors
	# never become part of a room trigger. Remove only the floor we deliberately
	# converted into internal walls, preserving that useful property.
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
		Type.RING: return 1.05
		Type.CLUSTERS: return 1.05
		Type.CROSSFIRE: return 1.15
		Type.FORTIFIED: return 1.25
		Type.KILLBOX: return 1.4
	return 1.0


func _generate_open(gen: DungeonGenerator, room: Rect2i, level: int, rng: RandomNumberGenerator, data: Dictionary) -> void:
	# Open is intentionally a breather. On later floors it can gain two small
	# masonry islands while remaining mostly unobstructed.
	if level >= 5 and rng.randf() < 0.45:
		var c := _center(room)
		_try_carve_block(gen, room, data, c + Vector2i(-7, rng.randi_range(-3, 3)), Vector2i(3, 3), rng)
		_try_carve_block(gen, room, data, c + Vector2i(7, rng.randi_range(-3, 3)), Vector2i(3, 3), rng)


func _generate_pillars(gen: DungeonGenerator, room: Rect2i, level: int, rng: RandomNumberGenerator, data: Dictionary) -> void:
	var c := _center(room)
	var pattern := rng.randi_range(0, 2 if level < 4 else 4)
	match pattern:
		0:
			for off in [Vector2i(-8,-5), Vector2i(8,-5), Vector2i(-8,5), Vector2i(8,5)]:
				_try_carve_block(gen, room, data, c + off, Vector2i(3, 3), rng)
		1:
			for d in [-8, -3, 3, 8]:
				_try_carve_block(gen, room, data, c + Vector2i(d, int(d / 2)), Vector2i(3, 3), rng)
		2:
			for x in [-8, 0, 8]:
				for y in [-5, 5]:
					_try_carve_block(gen, room, data, c + Vector2i(x, y), Vector2i(3, 3), rng)
		3:
			for off in [Vector2i(-9,-5), Vector2i(-4,-1), Vector2i(7,-4), Vector2i(9,4), Vector2i(-6,6)]:
				_try_carve_block(gen, room, data, c + off, Vector2i(3, 3), rng)
		4:
			for off in [Vector2i(-7,-4), Vector2i(0,-7), Vector2i(7,-4), Vector2i(7,4), Vector2i(0,7), Vector2i(-7,4)]:
				_try_carve_block(gen, room, data, c + off, Vector2i(3, 3), rng)


func _generate_lanes(gen: DungeonGenerator, room: Rect2i, level: int, rng: RandomNumberGenerator, data: Dictionary) -> void:
	var c := _center(room)
	var vertical := rng.randf() < 0.5
	var segment_length := 7 if level < 5 else rng.randi_range(7, 10)
	if vertical:
		_try_carve_block(gen, room, data, c + Vector2i(-7, -5), Vector2i(3, segment_length), rng, false)
		_try_carve_block(gen, room, data, c + Vector2i(7, 5), Vector2i(3, segment_length), rng, false)
		if level >= 6:
			_try_carve_block(gen, room, data, c + Vector2i(-7, 7), Vector2i(3, 5), rng, false)
	else:
		_try_carve_block(gen, room, data, c + Vector2i(-6, -6), Vector2i(segment_length, 3), rng, false)
		_try_carve_block(gen, room, data, c + Vector2i(6, 6), Vector2i(segment_length, 3), rng, false)
		if level >= 6:
			_try_carve_block(gen, room, data, c + Vector2i(7, -6), Vector2i(5, 3), rng, false)


func _generate_ring(gen: DungeonGenerator, room: Rect2i, level: int, rng: RandomNumberGenerator, data: Dictionary) -> void:
	var c := _center(room)
	# A broken masonry ring: four short wall segments with generous gaps at the
	# diagonals. Early floors omit one segment for extra breathing room.
	var parts := [
		{"pos": c + Vector2i(0, -7), "size": Vector2i(7, 3)},
		{"pos": c + Vector2i(0, 7), "size": Vector2i(7, 3)},
		{"pos": c + Vector2i(-8, 0), "size": Vector2i(3, 5)},
		{"pos": c + Vector2i(8, 0), "size": Vector2i(3, 5)},
	]
	if level <= 2:
		parts.remove_at(rng.randi_range(0, parts.size() - 1))
	for part: Dictionary in parts:
		_try_carve_block(gen, room, data, part.pos, part.size, rng, false)


func _generate_clusters(gen: DungeonGenerator, room: Rect2i, level: int, rng: RandomNumberGenerator, data: Dictionary) -> void:
	var c := _center(room)
	var bases := [Vector2i(-8,-5), Vector2i(8,5)]
	if level >= 3 or rng.randf() < 0.5:
		bases.append(Vector2i(8,-5))
	for base: Vector2i in bases:
		_try_carve_block(gen, room, data, c + base, Vector2i(4, 3), rng)
		_try_carve_block(gen, room, data, c + base + Vector2i(3, 2), Vector2i(3, 3), rng)
		if level >= 6:
			_try_carve_block(gen, room, data, c + base + Vector2i(-2, 3), Vector2i(3, 3), rng)


func _generate_crossfire(gen: DungeonGenerator, room: Rect2i, level: int, rng: RandomNumberGenerator, data: Dictionary) -> void:
	var c := _center(room)
	# Four short walls point toward the centre but stop well before it, leaving a
	# large central dodge space and four clear approaches.
	_try_carve_block(gen, room, data, c + Vector2i(0, -8), Vector2i(3, 5), rng, false)
	_try_carve_block(gen, room, data, c + Vector2i(0, 8), Vector2i(3, 5), rng, false)
	_try_carve_block(gen, room, data, c + Vector2i(-9, 0), Vector2i(6, 3), rng, false)
	_try_carve_block(gen, room, data, c + Vector2i(9, 0), Vector2i(6, 3), rng, false)
	if level >= 6:
		var sx := -1 if rng.randf() < 0.5 else 1
		var sy := -1 if rng.randf() < 0.5 else 1
		_try_carve_block(gen, room, data, c + Vector2i(6 * sx, 6 * sy), Vector2i(3, 3), rng)


func _generate_fortified(gen: DungeonGenerator, room: Rect2i, level: int, rng: RandomNumberGenerator, data: Dictionary) -> void:
	var c := _center(room)
	var flip := -1 if rng.randf() < 0.5 else 1
	# Two staggered defensive walls with openings rather than a row of props.
	_try_carve_block(gen, room, data, c + Vector2i(-6, -6 * flip), Vector2i(7, 3), rng, false)
	_try_carve_block(gen, room, data, c + Vector2i(6, -6 * flip), Vector2i(5, 3), rng, false)
	_try_carve_block(gen, room, data, c + Vector2i(0, 6 * flip), Vector2i(9, 3), rng, false)
	if level >= 7:
		_try_carve_block(gen, room, data, c + Vector2i(-9, 1 * flip), Vector2i(3, 4), rng, false)
		_try_carve_block(gen, room, data, c + Vector2i(9, -1 * flip), Vector2i(3, 4), rng, false)


func _generate_killbox(gen: DungeonGenerator, room: Rect2i, level: int, rng: RandomNumberGenerator, data: Dictionary) -> void:
	var c := _center(room)
	# Aggressive but still connectivity-checked: paired side walls create a long
	# central firing channel while the top/bottom blocks force route choices.
	_try_carve_block(gen, room, data, c + Vector2i(-9, 0), Vector2i(3, 11), rng, false)
	_try_carve_block(gen, room, data, c + Vector2i(9, 0), Vector2i(3, 11), rng, false)
	_try_carve_block(gen, room, data, c + Vector2i(-4, -7), Vector2i(5, 3), rng, false)
	_try_carve_block(gen, room, data, c + Vector2i(4, 7), Vector2i(5, 3), rng, false)
	if level >= 8:
		_try_carve_block(gen, room, data, c + Vector2i(4, -7), Vector2i(3, 3), rng)
		_try_carve_block(gen, room, data, c + Vector2i(-4, 7), Vector2i(3, 3), rng)


func _try_carve_block(
	gen: DungeonGenerator,
	room: Rect2i,
	data: Dictionary,
	centre: Vector2i,
	size: Vector2i,
	rng: RandomNumberGenerator,
	jitter: bool = true
) -> bool:
	var actual_centre := centre
	if jitter:
		actual_centre += Vector2i(rng.randi_range(-1, 1), rng.randi_range(-1, 1))

	# Wall islands need real thickness so the normal wall atlas can draw their
	# perimeter around an interior of solid rock.
	var safe_size := Vector2i(maxi(size.x, 3), maxi(size.y, 3))
	var start := actual_centre - safe_size / 2
	var candidate := Rect2i(start, safe_size)
	var reserved: Array = data.reserved_cells
	var removed: Array[Vector2i] = []

	for x in range(candidate.position.x, candidate.end.x):
		for y in range(candidate.position.y, candidate.end.y):
			var cell := Vector2i(x, y)
			if not room.has_point(cell) or not gen.grid.has(cell) or reserved.has(cell):
				return false
			removed.append(cell)

	if removed.is_empty():
		return false

	for cell: Vector2i in removed:
		gen.grid.erase(cell)

	# Reject a structure if it splits this room's original playable floor into
	# separate islands. This is intentionally local and much cheaper than a full
	# dungeon flood fill for every candidate block.
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
	for x in range(c.x - 2, c.x + 3):
		for y in range(c.y - 2, c.y + 3):
			var cell := Vector2i(x, y)
			if gen.grid.has(cell):
				reserved.append(cell)

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

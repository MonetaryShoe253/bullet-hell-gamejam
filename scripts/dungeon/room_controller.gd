class_name RoomController
extends Node2D
## Gameplay side of one room's trigger: notices the player walking in, and -
## for gated rooms - a set of colliders at the doorways that can be switched
## on to seal it. Built entirely at runtime (see setup()) since its geometry
## only exists once DungeonGenerator has actually run.

signal player_entered(controller: RoomController)
signal all_enemies_cleared(controller: RoomController)

## The combat trigger deliberately begins several tiles inside each doorway.
## This prevents the gate from becoming solid while the player's collider is
## still straddling the threshold. This is independent of doorway width: a wide
## doorway can still trap the player if it closes too early.
const ENTRY_TRIGGER_DEPTH := 4
const ENTRY_TRIGGER_SIDE_MARGIN := 2

var room_rect: Rect2i
var kind: DungeonGenerator.RoomKind
var gated: bool = true
var spawned: bool = false
var cleared: bool = false
var locked: bool = false
var exits: Array = []

var waves_remaining: int = 0
var spawn_next_wave: Callable = Callable()

var _enemies_alive: int = 0
var _gate_bodies: Array[StaticBody2D] = []
var _trigger: Area2D


func setup(tile_layer: TileMapLayer, exit_spans: Array, floor_cells: Array[Vector2i]) -> void:
	exits = exit_spans
	_build_trigger(tile_layer, floor_cells)
	if gated:
		for span: Array in exit_spans:
			_build_gate(tile_layer, span)


func register_enemy(enemy: Enemy) -> void:
	_enemies_alive += 1
	enemy.health_component.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)


func lock() -> void:
	if locked:
		return
	locked = true
	for body: StaticBody2D in _gate_bodies:
		for shape: CollisionShape2D in body.get_children():
			shape.set_deferred("disabled", false)


func unlock() -> void:
	locked = false
	for body: StaticBody2D in _gate_bodies:
		for shape: CollisionShape2D in body.get_children():
			shape.set_deferred("disabled", true)


## Built from the room's actual floor cells, but gated rooms exclude a rectangular
## throat just inside every doorway. The body_entered signal therefore cannot
## fire until the player's centre has moved well clear of the gate collider.
func _build_trigger(tile_layer: TileMapLayer, floor_cells: Array[Vector2i]) -> void:
	var tile_size := Vector2(tile_layer.tile_set.tile_size)

	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2  # Player
	_trigger.monitorable = false
	add_child(_trigger)

	var trigger_cells: Array[Vector2i] = floor_cells
	if gated:
		trigger_cells = _combat_trigger_cells(floor_cells)

	var strips: Array[Rect2i] = _row_runs(trigger_cells)
	if strips.is_empty():
		# Normal/boss rooms are large enough that this should never happen. Keep a
		# defensive fallback so a malformed room still functions rather than never
		# starting its encounter.
		push_warning("RoomController: safe trigger became empty; falling back to full room trigger")
		strips = _row_runs(floor_cells)
		if strips.is_empty():
			strips = [room_rect]

	for strip: Rect2i in strips:
		var world_rect := Rect2(
				tile_layer.map_to_local(strip.position) - tile_size / 2.0,
				Vector2(strip.size) * tile_size)

		var shape := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = world_rect.size
		shape.shape = rect_shape
		shape.position = world_rect.position + world_rect.size / 2.0
		_trigger.add_child(shape)

	_trigger.body_entered.connect(_on_trigger_body_entered)


## Removes the inner doorway throats from the encounter trigger. ENTRY_TRIGGER_DEPTH
## controls how far the player must enter the room; ENTRY_TRIGGER_SIDE_MARGIN makes
## the dead zone wider than the doorway itself so entering diagonally cannot graze
## the trigger while part of the collider is still outside.
func _combat_trigger_cells(floor_cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in floor_cells:
		if not _inside_any_entry_dead_zone(cell):
			result.append(cell)
	return result


func _inside_any_entry_dead_zone(cell: Vector2i) -> bool:
	for span: Array in exits:
		if span.is_empty():
			continue

		var min_cell: Vector2i = span[0]
		var max_cell: Vector2i = span[0]
		for exit_cell: Vector2i in span:
			min_cell = min_cell.min(exit_cell)
			max_cell = max_cell.max(exit_cell)

		var sample: Vector2i = span[0]

		# North doorway: exit cells are one tile above room_rect.
		if sample.y == room_rect.position.y - 1:
			if cell.y >= room_rect.position.y and cell.y < room_rect.position.y + ENTRY_TRIGGER_DEPTH:
				if cell.x >= min_cell.x - ENTRY_TRIGGER_SIDE_MARGIN and cell.x <= max_cell.x + ENTRY_TRIGGER_SIDE_MARGIN:
					return true

		# South doorway.
		elif sample.y == room_rect.end.y:
			if cell.y < room_rect.end.y and cell.y >= room_rect.end.y - ENTRY_TRIGGER_DEPTH:
				if cell.x >= min_cell.x - ENTRY_TRIGGER_SIDE_MARGIN and cell.x <= max_cell.x + ENTRY_TRIGGER_SIDE_MARGIN:
					return true

		# West doorway.
		elif sample.x == room_rect.position.x - 1:
			if cell.x >= room_rect.position.x and cell.x < room_rect.position.x + ENTRY_TRIGGER_DEPTH:
				if cell.y >= min_cell.y - ENTRY_TRIGGER_SIDE_MARGIN and cell.y <= max_cell.y + ENTRY_TRIGGER_SIDE_MARGIN:
					return true

		# East doorway.
		elif sample.x == room_rect.end.x:
			if cell.x < room_rect.end.x and cell.x >= room_rect.end.x - ENTRY_TRIGGER_DEPTH:
				if cell.y >= min_cell.y - ENTRY_TRIGGER_SIDE_MARGIN and cell.y <= max_cell.y + ENTRY_TRIGGER_SIDE_MARGIN:
					return true

	return false


func _row_runs(cells: Array[Vector2i]) -> Array[Rect2i]:
	var by_row: Dictionary = {}
	for cell: Vector2i in cells:
		var xs: Array = by_row.get(cell.y, [])
		xs.append(cell.x)
		by_row[cell.y] = xs

	var strips: Array[Rect2i] = []
	for y: int in by_row:
		var xs: Array = by_row[y]
		if xs.is_empty():
			continue
		xs.sort()
		var run_start: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size()):
			var x: int = xs[i]
			if x != prev + 1:
				strips.append(Rect2i(run_start, y, prev - run_start + 1, 1))
				run_start = x
			prev = x
		strips.append(Rect2i(run_start, y, prev - run_start + 1, 1))

	return strips


func _build_gate(tile_layer: TileMapLayer, span: Array) -> void:
	if span.is_empty():
		return

	var tile_size := Vector2(tile_layer.tile_set.tile_size)
	var min_cell: Vector2i = span[0]
	var max_cell: Vector2i = span[0]
	for cell: Vector2i in span:
		min_cell = min_cell.min(cell)
		max_cell = max_cell.max(cell)

	var world_min: Vector2 = tile_layer.map_to_local(min_cell) - tile_size / 2.0
	var world_max: Vector2 = tile_layer.map_to_local(max_cell) + tile_size / 2.0
	var size: Vector2 = world_max - world_min

	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = size
	shape.shape = rect_shape
	shape.position = world_min + size / 2.0
	shape.disabled = true
	body.add_child(shape)

	_gate_bodies.append(body)


func _on_trigger_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_entered.emit(self)


func _on_enemy_died() -> void:
	_enemies_alive -= 1
	if _enemies_alive > 0:
		return

	if waves_remaining > 0:
		waves_remaining -= 1
		if spawn_next_wave.is_valid():
			spawn_next_wave.call()
		return

	cleared = true
	unlock()
	all_enemies_cleared.emit(self)

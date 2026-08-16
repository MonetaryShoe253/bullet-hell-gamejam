class_name RoomController
extends Node2D
## Gameplay side of one room's trigger: notices the player walking in, and -
## for gated rooms - a set of colliders at the doorways that can be switched
## on to seal it. Built entirely at runtime (see setup()) since its geometry
## only exists once DungeonGenerator has actually run. Created for NORMAL,
## BOSS and SHOP rooms; dungeon_map.gd never makes one for the start room,
## which is always considered explored. Only NORMAL/BOSS ever lock - the shop
## controller (gated = false) exists purely so entering it can flip `cleared`
## for the minimap, with no gate bodies and no enemies to wait for.
##
## dungeon_map.gd owns what happens on these signals (spawning enemies,
## painting the gate art); this script only owns the physics and bookkeeping.

signal player_entered(controller: RoomController)
signal all_enemies_cleared(controller: RoomController)

var room_rect: Rect2i
var kind: DungeonGenerator.RoomKind
var gated: bool = true
var spawned: bool = false
var cleared: bool = false
var locked: bool = false
var exits: Array = []  ## exit spans (Array[Array[Vector2i]]), for the caller to paint gate art on

var _enemies_alive: int = 0
var _gate_bodies: Array[StaticBody2D] = []
var _trigger: Area2D


func setup(tile_layer: TileMapLayer, exit_spans: Array) -> void:
	exits = exit_spans
	_build_trigger(tile_layer)
	if gated:
		for span: Array in exit_spans:
			_build_gate(tile_layer, span)


func register_enemy(enemy: Enemy) -> void:
	_enemies_alive += 1
	enemy.health_component.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)


func lock() -> void:
	locked = true
	for body: StaticBody2D in _gate_bodies:
		for shape: CollisionShape2D in body.get_children():
			shape.set_deferred("disabled", false)


func unlock() -> void:
	locked = false
	for body: StaticBody2D in _gate_bodies:
		for shape: CollisionShape2D in body.get_children():
			shape.set_deferred("disabled", true)


func _build_trigger(tile_layer: TileMapLayer) -> void:
	var tile_size := Vector2(tile_layer.tile_set.tile_size)
	var world_rect := Rect2(
			tile_layer.map_to_local(room_rect.position) - tile_size / 2.0,
			Vector2(room_rect.size) * tile_size)

	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 2  # Player
	_trigger.monitorable = false
	add_child(_trigger)

	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = world_rect.size
	shape.shape = rect_shape
	shape.position = world_rect.position + world_rect.size / 2.0
	_trigger.add_child(shape)

	_trigger.body_entered.connect(_on_trigger_body_entered)


func _build_gate(tile_layer: TileMapLayer, span: Array) -> void:
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
	body.collision_layer = 1  # World - matches the tileset's wall physics layer
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
	if _enemies_alive <= 0:
		cleared = true
		unlock()
		all_enemies_cleared.emit(self)

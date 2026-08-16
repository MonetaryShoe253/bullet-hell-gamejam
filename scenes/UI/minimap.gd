extends Control
## Fog-of-war minimap: cleared rooms (plus the start room, always) draw
## filled-in; rooms adjacent to a cleared room, or already entered but not yet
## cleared, draw as an outline only - you know something is there, not what's
## in it. Anything else never gets drawn at all. Self-drawn (no child nodes)
## since the room count is small enough that _draw() every frame is cheap.

enum _State { HIDDEN, OUTLINE, REVEALED }

const PADDING := 10.0
const BG_COLOR := Color(0.02, 0.01, 0.02, 0.65)
const REVEALED_COLOR := Color(0.85, 0.75, 0.55, 0.9)
const OUTLINE_COLOR := Color(0.6, 0.6, 0.6, 0.6)
const BOSS_REVEALED_COLOR := Color(0.85, 0.2, 0.25, 0.9)
const PLAYER_COLOR := Color(0.3, 0.9, 1.0, 1.0)

var _gen: DungeonGenerator
var _room_controllers: Array = []
var _tile_layer: TileMapLayer
var _player: Node2D


func setup(gen: DungeonGenerator, room_controllers: Array, tile_layer: TileMapLayer, player: Node2D) -> void:
	_gen = gen
	_room_controllers = room_controllers
	_tile_layer = tile_layer
	_player = player
	queue_redraw()


func _process(_delta: float) -> void:
	if _gen:
		queue_redraw()  # cheap: at most ~10 rooms plus a player dot


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR, true)

	if _gen == null:
		return

	var bounds: Rect2i = _gen.get_bounds()
	if bounds.size == Vector2i.ZERO:
		return

	var usable: Vector2 = size - Vector2(PADDING, PADDING) * 2.0
	var scale_factor: float = minf(usable.x / bounds.size.x, usable.y / bounds.size.y)
	var offset: Vector2 = Vector2(PADDING, PADDING) \
			+ (usable - Vector2(bounds.size) * scale_factor) / 2.0

	var states := _compute_states()

	for room: Rect2i in _gen.rooms:
		var state: _State = states.get(room, _State.HIDDEN)
		if state == _State.HIDDEN:
			continue

		var local_pos: Vector2 = Vector2(room.position - bounds.position) * scale_factor + offset
		var local_size: Vector2 = Vector2(room.size) * scale_factor
		var rect := Rect2(local_pos, local_size)

		if state == _State.REVEALED:
			var color := BOSS_REVEALED_COLOR if room == _gen.boss_room else REVEALED_COLOR
			draw_rect(rect, color, true)
		else:
			draw_rect(rect, OUTLINE_COLOR, false, 1.5)

	if _player and is_instance_valid(_player) and _tile_layer:
		var player_cell: Vector2i = _tile_layer.local_to_map(_tile_layer.to_local(_player.global_position))
		var player_pos: Vector2 = Vector2(player_cell - bounds.position) * scale_factor + offset
		draw_circle(player_pos, 3.0, PLAYER_COLOR)


## REVEALED: the start room, or any room controller marked cleared.
## OUTLINE: not revealed, but either already entered (spawned) or adjacent to
## a revealed room - "there's something there", contents still unknown.
## HIDDEN (the default): everything else.
func _compute_states() -> Dictionary:
	var states: Dictionary = {}
	states[_gen.start_room] = _State.REVEALED
	for rc: RoomController in _room_controllers:
		if rc.cleared:
			states[rc.room_rect] = _State.REVEALED

	for room: Rect2i in _gen.rooms:
		if states.has(room):
			continue

		var rc := _controller_for(room)
		var is_frontier: bool = rc != null and rc.spawned
		if not is_frontier:
			for neighbor: Rect2i in _gen.room_adjacency.get(room, []):
				if states.has(neighbor):
					is_frontier = true
					break

		states[room] = _State.OUTLINE if is_frontier else _State.HIDDEN

	return states


func _controller_for(room: Rect2i) -> RoomController:
	for rc: RoomController in _room_controllers:
		if rc.room_rect == room:
			return rc
	return null

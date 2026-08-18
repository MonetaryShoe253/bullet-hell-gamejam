extends Control
## Minimap. Fog of war is currently OFF (see FOG_OF_WAR_ENABLED) - the full
## layout is drawn regardless of exploration. What's still gated on progress
## is fill colour: uncleared rooms draw a neutral grey and flip to their
## "real" colour once the room controller reports cleared - a shop clears
## instantly on entry, a fight room once its enemies are dead. The boss room
## is a special case rather than grey-until-cleared: it's always red (a
## known danger the moment it exists on the map) and turns green - not the
## uncleared grey - once the boss is actually dead. The original full
## "outline what's nearby, blank what isn't" fog logic is still intact
## underneath FOG_OF_WAR_ENABLED for later.
##
## This is a fixed-zoom camera that follows the player (see PIXELS_PER_TILE/
## _view_center), not a fit-the-whole-map view - a big dungeon has more floor
## than a small HUD widget can show at a legible scale anyway. _view_center
## lerps toward the player's cell each frame rather than snapping, clamped so
## it never pans past the edge of the generated map, and clip_contents on the
## Control (see the .tscn) keeps anything outside the widget's rect from
## spilling over it.
##
## Rooms and corridors are both drawn from the dungeon's *actual* floor
## cells, not an abstracted shape - every cell in `grid` is either part of
## some room's own footprint (DungeonGenerator.room_cells) or, if it isn't,
## a corridor cell by definition. Cells are merged row by row into the
## fewest same-owner rectangular strips (see _compute_floor_rects()), cached
## once per level rather than walked every frame. This is deliberately exact
## rather than approximated: a corridor drawn this way can never appear
## offset from a room or start from its centre, and an irregular room
## silhouette (an L-shape/notch/diagonal cut from room-shape variation)
## draws as its real shape instead of a bounding rectangle that doesn't
## match it.

enum _State { HIDDEN, OUTLINE, REVEALED }

const FOG_OF_WAR_ENABLED := false

## Fixed zoom - pixels per dungeon tile. Higher = more zoomed in. Kept
## moderate on purpose: enough room to see a corridor's actual bend clearly,
## not so much that only a sliver of the current room fits on screen.
const PIXELS_PER_TILE := 1.2

## How quickly the view re-centres on the player, in lerp-per-second terms -
## low enough that panning reads as catching up rather than snapping.
const FOLLOW_SPEED := 2.5

const BG_COLOR := Color(0.02, 0.01, 0.02, 0.65)
const BORDER_COLOR := Color(0.55, 0.5, 0.4, 0.35)

const UNCLEARED_COLOR := Color(0.42, 0.42, 0.47, 0.75)
const REVEALED_COLOR := Color(0.85, 0.75, 0.55, 0.9)
const SHOP_REVEALED_COLOR := Color(0.88, 0.66, 0.24, 0.9)
const BOSS_COLOR := Color(0.85, 0.2, 0.25, 0.9)
const BOSS_CLEARED_COLOR := Color(0.35, 0.8, 0.4, 0.9)
const OUTLINE_COLOR := Color(0.6, 0.6, 0.6, 0.6)

const CORRIDOR_COLOR := Color(0.55, 0.5, 0.42, 0.55)

const PLAYER_COLOR := Color(0.3, 0.9, 1.0, 1.0)
const SHOP_ICON_COLOR := Color(1.0, 0.92, 0.55, 1.0)
const BOSS_ICON_COLOR := Color(1.0, 0.35, 0.35, 1.0)
const EXIT_ICON_COLOR := Color(0.6, 1.0, 0.75, 1.0)

var _gen: DungeonGenerator
var _room_controllers: Array = []
var _tile_layer: TileMapLayer
var _player: Node2D

var _view_center: Vector2 = Vector2.ZERO

## Rect2i (room) -> Array[Rect2i], that room's own floor cells merged into
## row strips. Corridor cells (anything in `grid` not owned by any room) are
## merged the same way into _corridor_rects. Both computed once per level by
## setup() -> _compute_floor_rects().
var _room_rects: Dictionary = {}
var _corridor_rects: Array[Rect2i] = []

var _exit_cell: Vector2i
var _exit_visible: bool = false


func setup(gen: DungeonGenerator, room_controllers: Array, tile_layer: TileMapLayer, player: Node2D) -> void:
	_gen = gen
	_room_controllers = room_controllers
	_tile_layer = tile_layer
	_player = player
	_exit_visible = false
	_view_center = Vector2(gen.player_spawn)  # start centred on the player, not panning in from (0,0)
	_compute_floor_rects()
	queue_redraw()


## Called once the boss is dead and the stairway trigger actually exists -
## see dungeon_map.gd's _spawn_stairs_trigger(). Reset per-level by setup().
func show_exit(cell: Vector2i) -> void:
	_exit_cell = cell
	_exit_visible = true


func _process(delta: float) -> void:
	if _gen == null:
		return

	if _player and is_instance_valid(_player) and _tile_layer:
		var player_cell: Vector2i = _tile_layer.local_to_map(_tile_layer.to_local(_player.global_position))
		_view_center = _view_center.lerp(Vector2(player_cell), clampf(delta * FOLLOW_SPEED, 0.0, 1.0))

	queue_redraw()  # cheap: cached rect lists, at most ~10 rooms' worth, plus a few icons


## Every floor cell belongs to exactly one room (DungeonGenerator.room_cells)
## or, if it doesn't, is a corridor cell by definition - there is no third
## option, since `grid` only ever gains cells (rooms, then corridors, then
## cleanup/doorway-widening touch-ups) and never loses any. Cells are merged
## row by row into the fewest same-owner rectangular strips, same technique
## RoomController uses for its entry trigger - this is a one-time O(cells)
## pass, cached, not repeated per frame.
func _compute_floor_rects() -> void:
	_room_rects.clear()
	_corridor_rects.clear()

	var cell_owner: Dictionary = {}  # Vector2i -> Rect2i
	for room: Rect2i in _gen.room_cells:
		for cell: Vector2i in _gen.room_cells[room]:
			cell_owner[cell] = room

	var by_row: Dictionary = {}  # int y -> Array[int] xs
	for cell: Vector2i in _gen.grid:
		var xs: Array = by_row.get(cell.y, [])
		xs.append(cell.x)
		by_row[cell.y] = xs

	for y: int in by_row:
		var xs: Array = by_row[y]
		xs.sort()

		var run_start: int = xs[0]
		var run_owner: Rect2i = cell_owner.get(Vector2i(run_start, y), Rect2i())
		var prev: int = xs[0]

		for i in range(1, xs.size()):
			var x: int = xs[i]
			var owner: Rect2i = cell_owner.get(Vector2i(x, y), Rect2i())
			if x != prev + 1 or owner != run_owner:
				_add_floor_rect(run_owner, Rect2i(run_start, y, prev - run_start + 1, 1))
				run_start = x
				run_owner = owner
			prev = x

		_add_floor_rect(run_owner, Rect2i(run_start, y, prev - run_start + 1, 1))


func _add_floor_rect(owner: Rect2i, rect: Rect2i) -> void:
	if owner == Rect2i():
		_corridor_rects.append(rect)
		return

	var list: Array = _room_rects.get(owner, [])
	list.append(rect)
	_room_rects[owner] = list


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR, true)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 1.5)

	if _gen == null:
		return

	var bounds: Rect2i = _gen.get_bounds()
	if bounds.size == Vector2i.ZERO:
		return

	var origin: Vector2 = _clamped_origin(bounds)

	_draw_cell_rects(_corridor_rects, CORRIDOR_COLOR, origin)

	var states := _compute_states() if FOG_OF_WAR_ENABLED else {}

	for room: Rect2i in _gen.rooms:
		var rc := _controller_for(room)
		var icon_center: Vector2 = _to_screen(Vector2(room.position + room.size / 2), origin)

		if not FOG_OF_WAR_ENABLED:
			_draw_cell_rects(_room_rects.get(room, []), _room_fill_color(room, rc), origin)
			_draw_room_icon(room, icon_center)
			continue

		var state: _State = states.get(room, _State.HIDDEN)
		if state == _State.HIDDEN:
			continue

		if state == _State.REVEALED:
			_draw_cell_rects(_room_rects.get(room, []), _room_fill_color(room, rc), origin)
		else:
			# Outline state deliberately stays a plain bounding-rect stroke,
			# not the real shape - fog of war is about not knowing what a
			# room actually looks like yet, only that something's there.
			var local_pos: Vector2 = _to_screen(Vector2(room.position), origin)
			var local_size: Vector2 = Vector2(room.size) * PIXELS_PER_TILE
			draw_rect(Rect2(local_pos, local_size), OUTLINE_COLOR, false, 1.5)

		if _is_discovered(rc):
			_draw_room_icon(room, icon_center)

	if _exit_visible:
		_draw_exit_icon(_to_screen(Vector2(_exit_cell), origin))

	if _player and is_instance_valid(_player) and _tile_layer:
		var player_cell: Vector2i = _tile_layer.local_to_map(_tile_layer.to_local(_player.global_position))
		draw_circle(_to_screen(Vector2(player_cell), origin), 3.0, PLAYER_COLOR)


func _draw_cell_rects(rects: Array, color: Color, origin: Vector2) -> void:
	for rect: Rect2i in rects:
		var local_pos: Vector2 = _to_screen(Vector2(rect.position), origin)
		var local_size: Vector2 = Vector2(rect.size) * PIXELS_PER_TILE
		draw_rect(Rect2(local_pos, local_size), color, true)


## Top-left corner of the visible window, in cell space - _view_center minus
## half the window, clamped so the window never shows past the edge of the
## generated map on an axis where the map is bigger than the window; on an
## axis where the map is *smaller* than the window, centres on the map
## instead of clamping into a degenerate (min > max) range.
func _clamped_origin(bounds: Rect2i) -> Vector2:
	var half_view: Vector2 = size / PIXELS_PER_TILE / 2.0
	var center := _view_center

	if bounds.size.x > half_view.x * 2.0:
		center.x = clampf(center.x, bounds.position.x + half_view.x, bounds.end.x - half_view.x)
	else:
		center.x = bounds.position.x + bounds.size.x / 2.0

	if bounds.size.y > half_view.y * 2.0:
		center.y = clampf(center.y, bounds.position.y + half_view.y, bounds.end.y - half_view.y)
	else:
		center.y = bounds.position.y + bounds.size.y / 2.0

	return center - half_view


func _to_screen(cell: Vector2, origin: Vector2) -> Vector2:
	return (cell - origin) * PIXELS_PER_TILE


## Grey until the room controller says otherwise - the start room has no
## controller at all (dungeon_map.gd never makes one for it) and is always
## considered explored, same as before. The boss room is the one exception:
## it's a known danger from the moment it exists on the map, not a mystery
## box, so it's always red rather than grey, and its "cleared" colour is a
## distinct green rather than the shared REVEALED_COLOR.
func _room_fill_color(room: Rect2i, rc: RoomController) -> Color:
	var cleared: bool = rc == null or rc.cleared

	if room == _gen.boss_room:
		return BOSS_CLEARED_COLOR if cleared else BOSS_COLOR

	if not cleared:
		return UNCLEARED_COLOR
	if room == _gen.shop_room:
		return SHOP_REVEALED_COLOR
	return REVEALED_COLOR


## With fog of war off, every room's icon is visible immediately regardless
## of clear state (matches "see the whole map" on load) - see the call site.
## Left in place for when fog comes back: gates on the room controller having
## actually been entered (spawned, or cleared for the shop which marks
## itself cleared on entry) rather than waiting on the room's fill colour,
## since a boss/shop icon shouldn't have to wait on "fully cleared" either.
func _is_discovered(rc: RoomController) -> bool:
	if not FOG_OF_WAR_ENABLED:
		return true
	return rc != null and (rc.spawned or rc.cleared)


func _draw_room_icon(room: Rect2i, center: Vector2) -> void:
	if room == _gen.shop_room:
		_draw_shop_icon(center)
	elif room == _gen.boss_room:
		_draw_boss_icon(center)


## A small diamond - reads as "valuable" at minimap scale without needing an
## actual coin sprite.
func _draw_shop_icon(center: Vector2) -> void:
	var r := 5.0
	var points := PackedVector2Array([
		center + Vector2(0, -r),
		center + Vector2(r, 0),
		center + Vector2(0, r),
		center + Vector2(-r, 0),
	])
	draw_colored_polygon(points, SHOP_ICON_COLOR)


## A small warning triangle for the boss arena.
func _draw_boss_icon(center: Vector2) -> void:
	var r := 5.5
	var points := PackedVector2Array([
		center + Vector2(0, -r),
		center + Vector2(r * 0.87, r * 0.5),
		center + Vector2(-r * 0.87, r * 0.5),
	])
	draw_colored_polygon(points, BOSS_ICON_COLOR)


## A tiny ladder - two rails, three rungs - marking the way to the next level.
func _draw_exit_icon(center: Vector2) -> void:
	var half_w := 3.5
	var half_h := 5.0
	var top := center.y - half_h
	var bottom := center.y + half_h

	draw_line(Vector2(center.x - half_w, top), Vector2(center.x - half_w, bottom), EXIT_ICON_COLOR, 1.2)
	draw_line(Vector2(center.x + half_w, top), Vector2(center.x + half_w, bottom), EXIT_ICON_COLOR, 1.2)

	for i in 3:
		var y: float = lerpf(top, bottom, (i + 0.5) / 3.0)
		draw_line(Vector2(center.x - half_w, y), Vector2(center.x + half_w, y), EXIT_ICON_COLOR, 1.0)


## REVEALED: the start room, or any room controller marked cleared.
## OUTLINE: not revealed, but either already entered (spawned) or adjacent to
## a revealed room - "there's something there", contents still unknown.
## HIDDEN (the default): everything else. Only used when FOG_OF_WAR_ENABLED.
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

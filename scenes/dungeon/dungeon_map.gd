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
## This also owns the run's room-gating: every NORMAL/BOSS room gets a
## RoomController (see room_controller.gd) that seals its doorways the moment
## the player steps in, and opens them again once EnemySpawner's enemies are
## all dead. Beating the boss reveals a stairway that regenerates the whole
## dungeon one level harder.
##
## See docs/dungeon-generator.md for the full atlas map and how it was derived.

@onready var tile_layer: TileMapLayer = $TileMapLayer
@onready var prop_layer: TileMapLayer = $PropLayer
## y_sort_enabled - player, enemies and obstacles all live here so a tall
## pillar can actually be walked behind (and hide the player/an enemy behind
## it) rather than always drawing in front or behind by sheer luck of add
## order. Cosmetic decorations deliberately stay OUT of this layer - they're
## floor clutter, not cover, and always belong under everything (see
## _spawn_decoration()).
@onready var gameplay_layer: Node2D = $GameplayLayer
@onready var money_label: Label = $HUD/MoneyLabel
@onready var boss_health_bar: CanvasLayer = $BossHealthBar
@onready var shop_ui: ShopUI = $ShopUI
@onready var minimap: Control = $HUD/Minimap
@onready var inventory_ui: InventoryUI = %InventoryUI
@onready var ability_menu_ui: AbilityMenuUI = %AbilityMenuUI
@onready var stats_menu: StatsMenu = %StatsMenu
@onready var death_reward_ui: DeathRewardUI = $DeathRewardUI

@export var tile_source_id := 0   # the TileSetAtlasSource id for the tileset (0 if it's the only source)
@export var map_size := Vector2i(260, 180)
@export var use_random_seed := true
@export var fixed_seed := 12345   # used when use_random_seed is false, for reproducible testing

## Rings of solid rock painted beyond the map edge. Only needs to cover whatever
## the camera can see past the dungeon; it is not part of the playable area.
@export var void_margin := 16
@export var fit_camera_to_map := true
## Draws the ladder / wares / gate that mark out the start, shop and boss rooms.
@export var show_room_props := true

## Debug/testing: skip traversal and start directly in the boss arena.
## Leave this false for normal gameplay. When enabled, the player is placed near
## the boss-room centre and the boss encounter is started immediately after the
## room controllers are built.
@export_category("Testing")
@export var test_start_at_boss := false

## Players and Enemies
@export var player_scene: PackedScene
var player: Node2D

const DemonPortalScene := preload("res://scenes/dungeon/demon_portal.tscn")

# --- atlas coordinates (column, row) in the 16px grid ---

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
var _spawner: EnemySpawner
var _renderer: DungeonRenderer
var _decorator: DungeonDecorator
var _room_controllers: Array[RoomController] = []
var _stairs_trigger: Area2D
var _shop_trigger: Area2D


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	_on_money_changed(GameState.money)
	generate_dungeon()


func _spawn_player() -> void:
	var spawn_cell: Vector2i = _generator.player_spawn
	if test_start_at_boss and _generator.boss_room.size != Vector2i.ZERO:
		spawn_cell = _boss_test_spawn_cell()

	var spawn_position := tile_layer.map_to_local(spawn_cell)

	if player == null or not is_instance_valid(player):
		# First dungeon - create the player.
		player = player_scene.instantiate()
		gameplay_layer.add_child(player)

		inventory_ui.setup(player)
		ability_menu_ui.setup(player)
		stats_menu.setup(player)
		print("Player created")
	else:
		# Next dungeon - keep existing player.
		print("Reusing existing player")

	# Move existing/new player to the new dungeon spawn.
	player.position = spawn_position

	print("Player positioned at: ", spawn_position)


## Prefer the boss-room centre, but choose the closest captured playable floor
## cell defensively in case future boss-room shaping/cover makes the exact centre
## unavailable.
func _boss_test_spawn_cell() -> Vector2i:
	var room: Rect2i = _generator.boss_room
	var centre: Vector2i = room.position + room.size / 2
	var cells: Array = _generator.room_cells.get(room, [])
	if cells.is_empty():
		return centre

	var best: Vector2i = cells[0]
	var best_distance := 1 << 30
	for candidate: Vector2i in cells:
		if not _generator.grid.has(candidate):
			continue
		var delta := candidate - centre
		var distance := delta.x * delta.x + delta.y * delta.y
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _on_money_changed(total: int) -> void:
	if money_label:
		money_label.text = "Cluck Coins: %d" % total	

## Tears down everything from the previous dungeon (player, enemies, gates,
## stairs, decorations) before a new layout is generated for the next level.
func _clear_level_entities() -> void:

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.get_parent() == gameplay_layer:
			enemy.queue_free()

	for rc: RoomController in _room_controllers:
		if is_instance_valid(rc):
			rc.queue_free()
	_room_controllers.clear()

	if _stairs_trigger and is_instance_valid(_stairs_trigger):
		_stairs_trigger.queue_free()
	_stairs_trigger = null

	if _shop_trigger and is_instance_valid(_shop_trigger):
		_shop_trigger.queue_free()
	_shop_trigger = null

	# Godot uniquifies sibling names ("DemonPortal", "DemonPortal2", ...) since
	# there can be several, so match by prefix rather than tracking an array.
	# Decorations/barrels are named "Decoration" wherever they live. Cosmetic
	# sprites are children of this node and barrels live in gameplay_layer, so
	# both parents need the sweep; permanent cover is TileMap wall geometry now.
	# The player is gameplay_layer's only other child and does not match.
	for child in get_children():
		if child.name.begins_with("DemonPortal") or child.name.begins_with("Decoration"):
			child.queue_free()
	for child in gameplay_layer.get_children():
		if child.name.begins_with("Decoration"):
			child.queue_free()

	boss_health_bar.visible = false


func generate_dungeon() -> void:
	
	if player and is_instance_valid(player):
		player.global_position = Vector2(-100000, -100000)
		
	_clear_level_entities()
	# Allow everything we just queue_free()'d to actually disappear.
	await get_tree().process_frame

	_generator = DungeonGenerator.new()
	_generator.map_size = map_size

	_generator.generate(-1 if use_random_seed else fixed_seed, GameState.level)

	_renderer = DungeonRenderer.new(tile_layer, tile_source_id, map_size, void_margin)
	_decorator = DungeonDecorator.new(self, tile_layer, gameplay_layer)
	_paint(_generator)

	_spawn_player()
	_spawner = EnemySpawner.new(gameplay_layer, tile_layer, player)
	
	# Give the physics server a chance to register the player's
	# new position.
	await get_tree().physics_frame

	_setup_rooms(_generator)
	if test_start_at_boss:
		_start_boss_test_encounter()
	_decorator.scatter(_generator)

	_spawn_shop_trigger()
	
	shop_ui.reset_shop()


	minimap.setup(_generator, _room_controllers, tile_layer, player)



## One RoomController per fight room. Start and shop never gate, so they don't
## get one at all - the start room is always considered explored, and the
## shop's controller is ungated (see room_controller.gd), there purely so
## walking in flips `cleared` for the minimap.
func _setup_rooms(gen: DungeonGenerator) -> void:
	for room: Rect2i in gen.rooms:
		var kind: DungeonGenerator.RoomKind = gen.kind_of(room)
		if kind == DungeonGenerator.RoomKind.START:
			continue

		var rc := RoomController.new()
		rc.room_rect = room
		rc.kind = kind
		rc.gated = kind != DungeonGenerator.RoomKind.SHOP
		add_child(rc)
		rc.setup(tile_layer, gen.get_room_exits(room), gen.room_cells.get(room, []))
		rc.player_entered.connect(_on_room_player_entered)
		rc.all_enemies_cleared.connect(_on_room_cleared)
		_room_controllers.append(rc)


## Starting inside an Area2D before it exists does not reliably produce the same
## body_entered edge as walking through its doorway. In boss-test mode, invoke
## the normal room-entry path explicitly once setup is complete.
func _start_boss_test_encounter() -> void:
	for rc: RoomController in _room_controllers:
		if rc.kind == DungeonGenerator.RoomKind.BOSS:
			_on_room_player_entered(rc)
			return
	push_warning("Boss test mode enabled, but no boss RoomController was created")


func _on_room_player_entered(rc: RoomController) -> void:
	if rc.cleared:
		return

	if not rc.gated:
		rc.cleared = true  # shop: nothing to fight, just mark it explored
		return

	if not rc.spawned:
		rc.spawned = true
		if rc.kind == DungeonGenerator.RoomKind.BOSS:
			_spawner.spawn_boss(rc.room_rect, rc, boss_health_bar.show_for)
		else:
			_spawner.spawn_room(_generator, rc.room_rect, rc)

	rc.lock()
	_paint_gate(rc, true)


func _on_room_cleared(rc: RoomController) -> void:
	_paint_gate(rc, false)
	if rc.kind == DungeonGenerator.RoomKind.BOSS:
		_spawn_stairs_trigger.call_deferred()


## Overlays (or clears) the gate arch art at a room's doorways. The blocking
## collider itself is owned by the RoomController; this only handles what the
## player sees.
func _paint_gate(rc: RoomController, locked: bool) -> void:
	for span: Array in rc.exits:
		if span.is_empty():
			continue

		# The deliberate dungeon entrance uses the demon-portal threshold instead
		# of ordinary door tiles. Other boss openings (notably the post-boss stairs
		# side) still use normal gate art, so portal props never overlap the stairs.
		if rc.kind == DungeonGenerator.RoomKind.BOSS:
			var boss_entrance: Array = _generator.get_boss_entrance_span()
			if _same_span(span, boss_entrance):
				for cell: Vector2i in span:
					prop_layer.set_cell(cell, -1)
				continue

		# Exit spans on north/south walls run along X and use the gate art as drawn.
		# Exit spans on west/east walls run along Y, so rotate each atlas tile 90 degrees.
		var first: Vector2i = span[0]
		var last: Vector2i = span[span.size() - 1]
		var vertical_wall: bool = first.x == last.x

		var transform: int = 0
		if vertical_wall:
			transform = TileSetAtlasSource.TRANSFORM_TRANSPOSE | TileSetAtlasSource.TRANSFORM_FLIP_H

		for i in span.size():
			var cell: Vector2i = span[i]
			if locked:
				prop_layer.set_cell(cell, tile_source_id, PROP_GATE[i % PROP_GATE.size()], transform)
			else:
				prop_layer.set_cell(cell, -1)


func _same_span(a: Array, b: Array) -> bool:
	if a.size() != b.size() or a.is_empty():
		return false
	for cell: Vector2i in a:
		if not b.has(cell):
			return false
	return true


## A stairway up appears once the boss is dead, at the small landing carved
## behind the arena (or right at the arena gate if that landing didn't fit -
## see DungeonGenerator._carve_stairs_room()). Walking into it advances the run.
func _spawn_stairs_trigger() -> void:
	var gen := _generator
	var cell: Vector2i
	if gen.stairs_room.size != Vector2i.ZERO:
		cell = gen.stairs_cell
	elif not gen.boss_gate_cells.is_empty():
		cell = gen.boss_gate_cells[0]
	else:
		return

	_stairs_trigger = Area2D.new()
	_stairs_trigger.collision_layer = 0
	_stairs_trigger.collision_mask = 2  # Player
	add_child(_stairs_trigger)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	shape.shape = circle
	_stairs_trigger.add_child(shape)
	_stairs_trigger.position = tile_layer.map_to_local(cell)
	_stairs_trigger.body_entered.connect(_on_stairs_entered)

	prop_layer.set_cell(cell, tile_source_id, PROP_LADDER)
	minimap.show_exit(cell)

func _spawn_shop_trigger() -> void:
	var room: Rect2i = _generator.shop_room

	if room.size == Vector2i.ZERO:
		return

	_shop_trigger = Area2D.new()
	_shop_trigger.name = "ShopTrigger"

	# The trigger itself doesn't physically collide with anything.
	_shop_trigger.collision_layer = 0

	# Your Player is physics layer 2.
	_shop_trigger.collision_mask = 2

	add_child(_shop_trigger)

	var collision_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()

	# Convert the shop room from tiles into pixels.
	var tile_size := tile_layer.tile_set.tile_size

	rectangle.size = Vector2(
		room.size.x * tile_size.x,
		room.size.y * tile_size.y
	)

	collision_shape.shape = rectangle
	_shop_trigger.add_child(collision_shape)

	# Put the Area2D in the centre of the generated shop room.
	var center_cell: Vector2i = room.position + room.size / 2
	_shop_trigger.position = tile_layer.map_to_local(center_cell)

	_shop_trigger.body_entered.connect(_on_shop_entered)
	_shop_trigger.body_exited.connect(_on_shop_exited)

func _on_shop_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	shop_ui.open(body)


func _on_shop_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	shop_ui.close()
	
func _on_stairs_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if _stairs_trigger and _stairs_trigger.body_entered.is_connected(_on_stairs_entered):
		_stairs_trigger.body_entered.disconnect(_on_stairs_entered)
	_advance_level()


func _advance_level() -> void:
	GameState.advance_level()
	Fx.level_banner("LEVEL %d" % GameState.level)
	await get_tree().create_timer(1.2).timeout
	generate_dungeon()


func _paint(gen: DungeonGenerator) -> void:
	_renderer.paint(gen)
	_paint_props(gen)


func _paint_props(gen: DungeonGenerator) -> void:
	prop_layer.clear()
	if not show_room_props:
		return

	_decorate_start(gen)
	_decorate_shop(gen)
	_decorate_boss(gen)
	_place_boss_portals(gen)


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

	# Boss doorways are decorated from the generator's real exit spans in
	# _place_boss_portals(). Do not hard-code a gate on the north wall here: the
	# combat entrance can be on any side, and doing so made the north side look
	# special even when it was not an actual doorway.

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


## A demon portal flanking each side of the boss room's *entrance* (never its
## stairs-side exit), so a player approaching from the rest of the dungeon can
## tell what's behind that door before they walk in. Sitting beside the door
## rather than on top of it keeps them clear of the gate art, which already
## overlays that same span once the room locks.
func _place_boss_portals(gen: DungeonGenerator) -> void:
	var room: Rect2i = gen.boss_room
	if room.size == Vector2i.ZERO:
		return

	# Only the deliberate dungeon-side entrance gets the grand portal treatment.
	# The stairs opening is intentionally excluded and is placed on another side
	# by DungeonGenerator whenever possible.
	var entrance: Array = gen.get_boss_entrance_span()
	if entrance.is_empty():
		push_warning("DungeonMap: boss room has no deliberate entrance span for seed %d" % gen.seed_used)
		return

	_place_boss_portal_span(room, entrance)


func _place_boss_portal_span(room: Rect2i, span: Array) -> void:
	if span.is_empty():
		return

	var first: Vector2i = span[0]
	var last: Vector2i = span[span.size() - 1]
	var mid: Vector2i = span[span.size() / 2]
	var vertical_wall: bool = first.x == last.x
	var along: Vector2i = Vector2i(0, 1) if vertical_wall else Vector2i(1, 0)
	var outward := _boss_span_outward(room, mid)

	# One pair frames the doorway shoulders. A second pair sits farther out and
	# wider apart, producing an avenue/archway silhouette from either approach.
	# The offsets derive from the actual doorway width so wide openings remain
	# centred and narrow openings never collapse the portal sprites together.
	var half_span: int = maxi(1, span.size() / 2)
	var inner_offset: int = half_span + 2
	var outer_offset: int = inner_offset + 3

	_spawn_portal(mid - along * inner_offset + outward)
	_spawn_portal(mid + along * inner_offset + outward)
	_spawn_portal(mid - along * outer_offset + outward * 3)
	_spawn_portal(mid + along * outer_offset + outward * 3)


func _boss_span_outward(room: Rect2i, cell: Vector2i) -> Vector2i:
	if cell.y == room.position.y - 1:
		return NORTH
	if cell.y == room.end.y:
		return SOUTH
	if cell.x == room.position.x - 1:
		return WEST
	if cell.x == room.end.x:
		return EAST

	# Exit spans should always be one cell outside an edge, but use the closest
	# edge as a defensive fallback if cleanup ever hands us an unusual span.
	var distances := {
		NORTH: abs(cell.y - (room.position.y - 1)),
		SOUTH: abs(cell.y - room.end.y),
		WEST: abs(cell.x - (room.position.x - 1)),
		EAST: abs(cell.x - room.end.x),
	}
	var best: Vector2i = NORTH
	var best_distance: int = distances[NORTH]
	for dir: Vector2i in [SOUTH, WEST, EAST]:
		if distances[dir] < best_distance:
			best = dir
			best_distance = distances[dir]
	return best


func _spawn_portal(cell: Vector2i) -> void:
	var portal := DemonPortalScene.instantiate()
	portal.name = "DemonPortal"
	# force_readable_name: without it, add_child() resolves the name collision
	# between the two portals with an illegible internal name instead of
	# "DemonPortal2", and _clear_level_entities()'s begins_with() match misses it.
	add_child(portal, true)
	portal.position = tile_layer.map_to_local(cell)


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

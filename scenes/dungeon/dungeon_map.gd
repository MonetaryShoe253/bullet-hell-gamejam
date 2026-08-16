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
@onready var money_label: Label = $HUD/MoneyLabel
@onready var boss_health_bar: CanvasLayer = $BossHealthBar
@onready var shop_ui: ShopUI = $ShopUI
@onready var minimap: Control = $HUD/Minimap

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

## Players and Enemies
@export var player_scene: PackedScene
var player: Node2D

const DemonPortalScene := preload("res://scenes/dungeon/demon_portal.tscn")

## Cosmetic clutter scattered across ordinary fight rooms - no collision, just
## flavor so rooms stop reading as repeats of the same bare arena.
const DECORATION_PATHS: Array[String] = [
	"res://assets/Wing/decorations/stacked_chairs.png",
	"res://assets/Wing/decorations/condiment_station.png",
	"res://assets/Wing/decorations/jukebox.png",
	"res://assets/Wing/decorations/potted_plant.png",
	"res://assets/Wing/decorations/oil_barrel.png",
	"res://assets/Wing/decorations/trash_can.png",
	"res://assets/Wing/decorations/wing_crate.png",
	"res://assets/Wing/vending_machine.png",
]
const ShopkeeperTexture := preload("res://assets/Wing/shopkeeper.png")

var _decoration_rng := RandomNumberGenerator.new()


# --- atlas coordinates (column, row) in the 16px grid ---

## Flat block of (37, 19, 26) - the same near-black baked into the wall tiles.
const SOLID_ROCK := Vector2i(8, 7)

## Straight wall runs, named for which way the wall faces. A north wall is the
## one drawn *above* a floor cell, so it is the piece whose full-height brick
## face you see; a south wall is drawn below the floor and only shows the wall's
## top capping, with rock below it.
const NORTH_WALL: Array[Vector2i] = [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
const SOUTH_WALL: Array[Vector2i] = [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
		Vector2i(1, 5), Vector2i(2, 5)]
const WEST_WALL: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]
const EAST_WALL: Array[Vector2i] = [Vector2i(5, 0), Vector2i(5, 1), Vector2i(5, 2), Vector2i(5, 3)]

## Convex corners - the outside of a bend, with floor only on the named diagonal.
## These double as the plain wall runs' end caps, which is why CONVEX_NW and
## WEST_WALL[0] are the same tile.
const CONVEX_NW := Vector2i(0, 0)
const CONVEX_NE := Vector2i(5, 0)
const CONVEX_SW := Vector2i(0, 4)
const CONVEX_SE := Vector2i(5, 4)

## Concave corners - the inside of a bend, with floor on two perpendicular sides.
## The artist only drew the two that sit below floor: a wall cap running east or
## west with the side wall's post attached. _wall_atlas_coords() explains what
## happens for the other two.
const CONCAVE_NW: Array[Vector2i] = [Vector2i(0, 5), Vector2i(4, 5)]  # floor to the north and west
const CONCAVE_NE: Array[Vector2i] = [Vector2i(3, 5), Vector2i(5, 5)]  # floor to the north and east

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
var _room_controllers: Array[RoomController] = []
var _stairs_trigger: Area2D
var _shop_trigger: Area2D


func _ready() -> void:
	GameState.money_changed.connect(_on_money_changed)
	_on_money_changed(GameState.money)
	generate_dungeon()


func _unhandled_input(event: InputEvent) -> void: # DELETE LATER - HELPFUL FOR TESTING
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			use_random_seed = true
			generate_dungeon()
			get_viewport().set_input_as_handled()

func _spawn_player() -> void:
	var spawn_position := tile_layer.map_to_local(_generator.player_spawn)

	if player == null or not is_instance_valid(player):
		# First dungeon - create the player.
		player = player_scene.instantiate()
		add_child(player)

		print("Player created")
	else:
		# Next dungeon - keep existing player.
		print("Reusing existing player")

	# Move existing/new player to the new dungeon spawn.
	player.position = spawn_position

	print("Player positioned at: ", spawn_position)


func _on_money_changed(total: int) -> void:
	if money_label:
		money_label.text = "Cluck Coins: %d" % total


## Tears down everything from the previous dungeon (player, enemies, gates,
## stairs) before a new layout is generated - both for the "R" debug regenerate
## and for advancing to the next level.
func _clear_level_entities() -> void:

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.get_parent() == self:
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
	for child in get_children():
		if child.name.begins_with("DemonPortal") or child.name.begins_with("Decoration"):
			child.queue_free()

	boss_health_bar.visible = false


func generate_dungeon() -> void:
	_clear_level_entities()

	_generator = DungeonGenerator.new()
	_generator.map_size = map_size

	_generator.generate(-1 if use_random_seed else fixed_seed)

	_paint(_generator)

	_spawn_player()
	_spawner = EnemySpawner.new(self, tile_layer, player)

	_setup_rooms(_generator)
	_scatter_decorations(_generator)
	_spawn_shopkeeper(_generator)
	
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
		rc.setup(tile_layer, gen.get_room_exits(room))
		rc.player_entered.connect(_on_room_player_entered)
		rc.all_enemies_cleared.connect(_on_room_cleared)
		_room_controllers.append(rc)


## Cosmetic clutter (no collision) scattered across ordinary fight rooms so
## they read as distinct spaces instead of repeats of the same bare arena.
## Start/shop/boss already get their own hand-placed dressing via
## _decorate_start()/_decorate_shop()/_decorate_boss(), so this only touches
## NORMAL rooms. Plain Sprite2D children rather than PropLayer tiles - these
## art pieces don't live in Dungeon_Tileset.png's atlas, and a handful of
## loose sprites per floor is cheap.
func _scatter_decorations(gen: DungeonGenerator) -> void:
	_decoration_rng.seed = gen.seed_used
	for room: Rect2i in gen.rooms:
		if gen.kind_of(room) == DungeonGenerator.RoomKind.NORMAL:
			_scatter_room(gen, room)


func _scatter_room(gen: DungeonGenerator, room: Rect2i) -> void:
	var margin := 3  # keep clear of walls/doorways - these sprites are ~2 tiles wide
	if room.size.x <= margin * 2 or room.size.y <= margin * 2:
		return

	var count: int = _decoration_rng.randi_range(1, 3)
	var min_spacing := 5
	var placed: Array[Vector2i] = []

	for i in count:
		var cell := Vector2i.ZERO
		var found := false
		for attempt in 10:
			cell = Vector2i(
					_decoration_rng.randi_range(room.position.x + margin, room.end.x - margin),
					_decoration_rng.randi_range(room.position.y + margin, room.end.y - margin))
			if not gen.grid.has(cell):
				continue
			var too_close := false
			for other: Vector2i in placed:
				if cell.distance_squared_to(other) < min_spacing * min_spacing:
					too_close = true
					break
			if not too_close:
				found = true
				break
		if not found:
			break  # room's too tight for another - stop rather than keep retrying

		var path: String = DECORATION_PATHS[_decoration_rng.randi_range(0, DECORATION_PATHS.size() - 1)]
		_spawn_decoration(load(path), cell)
		placed.append(cell)


## A shopkeeper standing at the shop's counter, just behind the wares
## _decorate_shop() already lays out on the floor there.
func _spawn_shopkeeper(gen: DungeonGenerator) -> void:
	var room: Rect2i = gen.shop_room
	if room.size == Vector2i.ZERO:
		return

	var middle: Vector2i = room.position + room.size / 2
	var cell: Vector2i = middle + Vector2i(0, -2)
	if room.has_point(cell) and gen.grid.has(cell):
		_spawn_decoration(ShopkeeperTexture, cell)


func _spawn_decoration(texture: Texture2D, cell: Vector2i) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Decoration"
	sprite.texture = texture
	sprite.texture_filter = 1
	sprite.position = tile_layer.map_to_local(cell)
	add_child(sprite)


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
		for i in span.size():
			var cell: Vector2i = span[i]
			if locked:
				prop_layer.set_cell(cell, tile_source_id, PROP_GATE[i % PROP_GATE.size()])
			else:
				prop_layer.set_cell(cell, -1)


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
	tile_layer.clear()

	# Solid rock first, then the wall ring, then floor. Later passes overwrite
	# earlier ones, so each cell ends up with the most specific piece that fits.
	var filled := Rect2i(Vector2i.ZERO, map_size).grow(void_margin)
	for y in range(filled.position.y, filled.end.y):
		for x in range(filled.position.x, filled.end.x):
			tile_layer.set_cell(Vector2i(x, y), tile_source_id, SOLID_ROCK)

	for cell: Vector2i in gen.get_wall_cells():
		tile_layer.set_cell(cell, tile_source_id, _wall_atlas_coords(cell, gen.grid))

	for cell: Vector2i in gen.grid:
		tile_layer.set_cell(cell, tile_source_id, _floor_atlas_coords(cell, gen.grid))

	_paint_props(gen)


## Marks out the three special rooms. Nothing here changes the dungeon - it only
## makes the roles the generator assigned visible at a glance, both for playing
## and for checking a screenshot.
func _paint_props(gen: DungeonGenerator) -> void:
	prop_layer.clear()
	if not show_room_props:
		return

	_decorate_start(gen)
	_decorate_shop(gen)
	_decorate_boss(gen)
	_place_boss_portal(gen)


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

	# The gate goes on the floor row against the north wall, so it reads as the
	# way out of the arena, with a torch to either side up on the wall itself.
	var gate_x: int = room.position.x + room.size.x / 2 - 1
	var top: int = room.position.y
	for i in PROP_GATE.size():
		_set_prop(gen, room, Vector2i(gate_x + i, top), PROP_GATE[i])
	_set_wall_prop(gen, Vector2i(gate_x - 2, top - 1), PROP_TORCH[0])
	_set_wall_prop(gen, Vector2i(gate_x + 3, top - 1), PROP_TORCH[1])

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
func _place_boss_portal(gen: DungeonGenerator) -> void:
	var room: Rect2i = gen.boss_room
	if room.size == Vector2i.ZERO:
		return

	var north_y: int = room.position.y - 1  # where the stairs corridor exits - not the entrance
	var entrance_span: Array = []
	for span: Array in gen.get_room_exits(room):
		var cell: Vector2i = span[0]
		if cell.y != north_y:
			entrance_span = span
			break
	if entrance_span.is_empty():
		return

	# Flank the span's midpoint rather than its two ends: most exits are a
	# narrow corridor doorway where that's the same thing, but where a big
	## room sits flush against the boss arena for a long stretch, the "ends"
	# would be tiles apart - the midpoint keeps the pair tight regardless.
	var first: Vector2i = entrance_span[0]
	var last: Vector2i = entrance_span[entrance_span.size() - 1]
	var mid: Vector2i = entrance_span[entrance_span.size() / 2]
	var along: Vector2i = Vector2i(0, 1) if first.x == last.x else Vector2i(1, 0)
	var spacing := 3

	_spawn_portal(mid - along * spacing)
	_spawn_portal(mid + along * spacing)


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


func _floor_atlas_coords(cell: Vector2i, grid: Dictionary) -> Vector2i:
	var wall_n: bool = not grid.has(cell + NORTH)
	var wall_s: bool = not grid.has(cell + SOUTH)
	var wall_w: bool = not grid.has(cell + WEST)
	var wall_e: bool = not grid.has(cell + EAST)

	# Rows 1/2/3 carry north-edge shading, no shading, and south-edge shading;
	# columns 1/2-3/4 do the same for west and east. A cell walled on both
	# opposite sides can only show one of them - the generator's cleanup makes
	# floor at least three cells thick, so in practice this never comes up.
	var row: int = 2
	if wall_n and not wall_s:
		row = 1
	elif wall_s and not wall_n:
		row = 3

	var col: int = 2 + _variant_index(cell, 2)  # two interchangeable interior variants
	if wall_w and not wall_e:
		col = 1
	elif wall_e and not wall_w:
		col = 4

	return Vector2i(col, row)


func _wall_atlas_coords(cell: Vector2i, grid: Dictionary) -> Vector2i:
	var n: bool = grid.has(cell + NORTH)
	var s: bool = grid.has(cell + SOUTH)
	var e: bool = grid.has(cell + EAST)
	var w: bool = grid.has(cell + WEST)

	# Concave corners before straight runs: a cell with floor on two
	# perpendicular sides needs the piece that turns, not either straight wall.
	if n and w:
		return _variant(cell, CONCAVE_NW)
	if n and e:
		return _variant(cell, CONCAVE_NE)

	# The mirrored pair (floor to the south plus floor to one side) has no art.
	# A north wall is a full-tile-tall brick face, which leaves no room to also
	# draw the side wall's post the way the south-facing corners do. Falling
	# through to the plain north wall is the right call: the face is the loud
	# part of the silhouette, and the floor beside it supplies its own edge
	# shading, so the corner still reads as a corner.
	if s:
		return _variant(cell, NORTH_WALL)
	if n:
		return _variant(cell, SOUTH_WALL)
	if e:
		return _variant(cell, WEST_WALL)
	if w:
		return _variant(cell, EAST_WALL)

	# No orthogonal floor left, so this is the outside of a bend. Cleanup
	# guarantees at most one diagonal touches floor, making the choice unambiguous.
	if grid.has(cell + Vector2i(1, 1)):
		return CONVEX_NW
	if grid.has(cell + Vector2i(-1, 1)):
		return CONVEX_NE
	if grid.has(cell + Vector2i(1, -1)):
		return CONVEX_SW
	if grid.has(cell + Vector2i(-1, -1)):
		return CONVEX_SE

	return SOLID_ROCK


## Picks between interchangeable variants of the same piece. Hashing the cell
## rather than pulling from an RNG keeps the choice stable: repainting the same
## grid gives the same picture, whatever order the cells come out of the dictionary.
func _variant(cell: Vector2i, options: Array[Vector2i]) -> Vector2i:
	return options[_variant_index(cell, options.size())]


func _variant_index(cell: Vector2i, count: int) -> int:
	var hash_value: int = (cell.x * 73856093) ^ (cell.y * 19349663)
	return (hash_value & 0x7fffffff) % count

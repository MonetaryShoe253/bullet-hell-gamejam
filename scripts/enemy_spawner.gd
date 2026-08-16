class_name EnemySpawner
extends RefCounted
## Decides how many enemies, of what type, and where, for a room - and scales
## their stats to the current GameState.level. One instance per dungeon.

const SlimeScene := preload("res://scenes/enemies/slime/slime.tscn")
const BurgerScene := preload("res://scenes/enemies/burger/burger.tscn")
const TacoScene := preload("res://scenes/enemies/taco/taco.tscn")
const PizzaScene := preload("res://scenes/enemies/pizza/pizza.tscn")

## Three palette variants of the same slime sprite - only the tint changes
## visually (per the brief, that's enough for now); health/damage/speed/
## reward differ so they read as different threats in a fight. Mixed in
## alongside the themed variant below so a themed room doesn't read as one
## single reskinned copy repeated - see _pick_variant().
const SLIME_TYPES: Array[Dictionary] = [
	{
		"scene": SlimeScene,
		"color": Color(1, 1, 1, 1),
		"health": 18.0,
		"damage": 4.0,
		"move_speed": 90.0,
		"fire_rate": 1.3,
		"money_reward": 4,
		"shot_pattern": Enemy.ShotPattern.SINGLE
	},
	{
		"scene": SlimeScene,
		"color": Color(0.35, 0.65, 1.0, 1),
		"health": 12.0,
		"damage": 3.0,
		"move_speed": 150.0,
		"fire_rate": 0.8,
		"money_reward": 5,
		"shot_pattern": Enemy.ShotPattern.BURST
	},
	{
		"scene": SlimeScene,
		"color": Color(1.0, 0.35, 0.35, 1),
		"health": 32.0,
		"damage": 7.0,
		"move_speed": 55.0,
		"fire_rate": 1.8,
		"money_reward": 7,
		"shot_pattern": Enemy.ShotPattern.SPREAD
	},
]

## One stat profile per competitor food-stand theme - each already has its
## own distinct sprite/projectile (see the scene files), so unlike the slime
## palette these don't need color variants to read as different threats.
const THEMED_TYPES: Dictionary = {
	DungeonGenerator.RoomTheme.BURGER: {
		"scene": BurgerScene,
		"health": 22.0,
		"damage": 5.0,
		"move_speed": 80.0,
		"fire_rate": 1.1,
		"money_reward": 5,
		"shot_pattern": Enemy.ShotPattern.SPREAD,
	},
	DungeonGenerator.RoomTheme.TACO: {
		"scene": TacoScene,
		"health": 14.0,
		"damage": 4.0,
		"move_speed": 140.0,
		"fire_rate": 0.9,
		"money_reward": 5,
		"shot_pattern": Enemy.ShotPattern.BURST,
	},
	DungeonGenerator.RoomTheme.PIZZA: {
		"scene": PizzaScene,
		"health": 18.0,
		"damage": 4.5,
		"move_speed": 100.0,
		"fire_rate": 1.0,
		"money_reward": 5,
		"shot_pattern": Enemy.ShotPattern.SINGLE,
	},
}

const BOSS_STATS: Dictionary = {
	"scene": SlimeScene,
	"color": Color(0.75, 0.3, 0.95, 1),
	"health": 220.0,
	"damage": 12.0,
	"move_speed": 70.0,
	"fire_rate": 0.5,
	"money_reward": 60,
	"scale": 2.4,
	"shot_pattern": Enemy.ShotPattern.CIRCLE,
}

var _parent: Node
var _tile_layer: TileMapLayer
var _player: Node2D
var _rng := RandomNumberGenerator.new()


func _init(parent: Node, tile_layer: TileMapLayer, player: Node2D) -> void:
	_parent = parent
	_tile_layer = tile_layer
	_player = player
	_rng.randomize()


## Fills a normal fight room with a wave of enemies matching its theme (mixed
## with a few generic slimes for variety), spread across its floor. Rooms
## sometimes get 2-3 waves instead of 1 - the next wave only spawns once the
## room controller sees the current one fully dead (see
## RoomController.waves_remaining/spawn_next_wave), and the room only
## unlocks after the last wave.
func spawn_room(gen: DungeonGenerator, room: Rect2i, room_controller: RoomController) -> void:
	var wave_count := _roll_wave_count()
	room_controller.waves_remaining = wave_count - 1
	room_controller.spawn_next_wave = func() -> void: _spawn_wave(gen, room, room_controller)
	_spawn_wave(gen, room, room_controller)


## Mostly a single wave; sometimes two, rarely three - "some rooms should
## have multiple waves" reads as an occasional escalation, not the norm.
func _roll_wave_count() -> int:
	var roll := _rng.randf()
	if roll < 0.55:
		return 1
	if roll < 0.85:
		return 2
	return 3


func _spawn_wave(gen: DungeonGenerator, room: Rect2i, room_controller: RoomController) -> void:
	var theme: DungeonGenerator.RoomTheme = gen.theme_of(room)
	var count: int = _rng.randi_range(4, 6) + int(GameState.level / 3)
	count = mini(count, 9)

	var exclude: Array = gen.obstacle_cells.get(room, [])
	for i in count:
		var variant: Dictionary = _pick_variant(theme)
		var cell := _random_room_cell(gen, room, exclude)
		_spawn(variant, cell, room_controller, Callable())


## Themed enemy most of the time (reads as "the burger room's enemies"), with
## a plain slime mixed in for variety so a themed room isn't one sprite
## copy-pasted across the whole fight.
func _pick_variant(theme: DungeonGenerator.RoomTheme) -> Dictionary:
	if THEMED_TYPES.has(theme) and _rng.randf() < 0.7:
		return THEMED_TYPES[theme]
	return SLIME_TYPES[_rng.randi_range(0, SLIME_TYPES.size() - 1)]


## The boss room gets one big, tough slime instead of a crowd. on_spawned, if
## given, is called with the actual Enemy once it exists (spawning is
## deferred - see _spawn()) so callers like the boss health bar can hook up
## to it without knowing about that delay themselves.
func spawn_boss(room: Rect2i, room_controller: RoomController, on_spawned: Callable = Callable()) -> void:
	var cell: Vector2i = room.position + room.size / 2
	_spawn(BOSS_STATS, cell, room_controller, on_spawned)


## Random floor cell inside `room`, away from its edges/doorways, that isn't
## already sitting on a cover obstacle - `exclude` is
## gen.obstacle_cells.get(room, []), so an enemy never spawns wedged inside a
## pillar's collider.
func _random_room_cell(gen: DungeonGenerator, room: Rect2i, exclude: Array = []) -> Vector2i:
	var margin := 4
	if room.size.x <= margin * 2 or room.size.y <= margin * 2:
		return room.position + room.size / 2

	for attempt in 20:
		var c := Vector2i(
				_rng.randi_range(room.position.x + margin, room.end.x - margin),
				_rng.randi_range(room.position.y + margin, room.end.y - margin))
		if gen.grid.has(c) and not exclude.has(c):
			return c
	return room.position + room.size / 2


## Spawning happens in response to the room's trigger Area2D firing
## body_entered, which is itself dispatched while the physics server is mid-
## flush - adding a whole new physics-enabled subtree (collision shapes,
## RayCast2D, the hurtbox Area2D) synchronously in that window trips Godot's
## "can't change this state while flushing queries" guard. Deferring the
## add_child (and everything that depends on its @onready refs) to the next
## idle frame sidesteps that entirely.
func _spawn(
	base_stats: Dictionary,
	cell: Vector2i,
	room_controller: RoomController,
	on_spawned: Callable = Callable()
) -> void:
	var scene: PackedScene = base_stats.get("scene", SlimeScene)
	var enemy: Enemy = scene.instantiate()

	enemy.player = _player
	enemy.position = _tile_layer.map_to_local(cell)

	var stats := _scaled(base_stats)
	var parent := _parent

	(func() -> void:
		parent.add_child(enemy)
		enemy.configure(stats)

		if room_controller:
			room_controller.register_enemy(enemy)

		if on_spawned.is_valid():
			on_spawned.call(enemy)
	).call_deferred()


func _scaled(base: Dictionary) -> Dictionary:
	var stats: Dictionary = base.duplicate()
	stats.health = base.health * GameState.health_multiplier()
	stats.damage = base.damage * GameState.damage_multiplier()
	stats.move_speed = base.move_speed * GameState.speed_multiplier()
	stats.fire_rate = maxf(base.fire_rate / GameState.speed_multiplier(), 0.15)
	stats.money_reward = int(round(base.money_reward * GameState.money_multiplier()))
	return stats

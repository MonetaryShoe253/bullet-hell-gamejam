class_name EnemySpawner
extends RefCounted
## Decides how many enemies, of what type, and where, for a room - and scales
## their stats to the current GameState.level. One instance per dungeon.

const SlimeScene := preload("res://scenes/enemies/slime/slime.tscn")

## Three palette variants of the same slime sprite - only the tint changes
## visually (per the brief, that's enough for now); health/damage/speed/
## reward differ so they read as different threats in a fight.
const SLIME_TYPES: Array[Dictionary] = [
	{
		"color": Color(1, 1, 1, 1),
		"health": 18.0,
		"damage": 4.0,
		"move_speed": 90.0,
		"fire_rate": 0.8,
		"money_reward": 4,
		"shot_pattern": Enemy.ShotPattern.SINGLE
	},
	{
		"color": Color(0.35, 0.65, 1.0, 1),
		"health": 12.0,
		"damage": 3.0,
		"move_speed": 150.0,
		"fire_rate": 0.5,
		"money_reward": 5,
		"shot_pattern": Enemy.ShotPattern.BURST
	},
	{
		"color": Color(1.0, 0.35, 0.35, 1),
		"health": 32.0,
		"damage": 7.0,
		"move_speed": 55.0,
		"fire_rate": 1.0,
		"money_reward": 7,
		"shot_pattern": Enemy.ShotPattern.SPREAD
	},
]

const BOSS_STATS: Dictionary = {
	"color": Color(0.75, 0.3, 0.95, 1),
	"health": 220.0,
	"damage": 12.0,
	"move_speed": 70.0,
	"fire_rate": 0.2,
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


func _random_shot_pattern() -> Enemy.ShotPattern:
	var patterns: Array[Enemy.ShotPattern] = [
		Enemy.ShotPattern.SINGLE,
		Enemy.ShotPattern.SPREAD,
		Enemy.ShotPattern.BURST,
	]

	return patterns[_rng.randi_range(0, patterns.size() - 1)]
	
## Fills a normal fight room with a handful of slimes, spread across its
## floor. Every spawned enemy is registered with room_controller so it can
## track when the room is cleared.
func spawn_room(
	gen: DungeonGenerator,
	room: Rect2i,
	room_controller: RoomController
) -> void:
	var count: int = _rng.randi_range(3, 5) + int(GameState.level / 3)
	count = mini(count, 10)

	for i in count:
		var variant: Dictionary = SLIME_TYPES[
			_rng.randi_range(0, SLIME_TYPES.size() - 1)
		]

		var cell := _random_room_cell(gen, room)

		var shot_pattern: Enemy.ShotPattern = _random_shot_pattern()

		_spawn(
			variant,
			cell,
			room_controller,
			Callable()
		)

## The boss room gets one big, tough slime instead of a crowd. on_spawned, if
## given, is called with the actual Enemy once it exists (spawning is
## deferred - see _spawn()) so callers like the boss health bar can hook up
## to it without knowing about that delay themselves.
func spawn_boss(room: Rect2i, room_controller: RoomController, on_spawned: Callable = Callable()) -> void:
	var cell: Vector2i = room.position + room.size / 2
	_spawn(
	BOSS_STATS,
	cell,
	room_controller,
	on_spawned
	)

func _random_room_cell(gen: DungeonGenerator, room: Rect2i) -> Vector2i:
	var margin := 4
	if room.size.x <= margin * 2 or room.size.y <= margin * 2:
		return room.position + room.size / 2

	for attempt in 20:
		var c := Vector2i(
				_rng.randi_range(room.position.x + margin, room.end.x - margin),
				_rng.randi_range(room.position.y + margin, room.end.y - margin))
		if gen.grid.has(c):
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
	var enemy: Enemy = SlimeScene.instantiate()

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

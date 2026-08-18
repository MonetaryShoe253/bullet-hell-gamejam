class_name EnemySpawner
extends RefCounted
## Creates waves from a simple threat budget and places enemies in the tactical
## zones produced by RoomGenerator.

var _parent: Node
var _tile_layer: TileMapLayer
var _player: Node2D
var _rng := RandomNumberGenerator.new()
var _wave_index_by_room: Dictionary = {}
var _budget_by_room: Dictionary = {}


func _init(parent: Node, tile_layer: TileMapLayer, player: Node2D) -> void:
	_parent = parent
	_tile_layer = tile_layer
	_player = player
	_rng.randomize()


func spawn_room(gen: DungeonGenerator, room: Rect2i, room_controller: RoomController) -> void:
	_wave_index_by_room[room] = 0
	var room_data: Dictionary = gen.plan_of(room)
	var difficulty := float(room_data.get("difficulty", 1.0))
	var budget := (5.0 + float(GameState.level) * 1.15) * difficulty
	_budget_by_room[room] = budget

	var wave_count := _roll_wave_count(budget)
	room_controller.waves_remaining = wave_count - 1
	room_controller.spawn_next_wave = func() -> void: _spawn_wave(gen, room, room_controller, wave_count)
	_spawn_wave(gen, room, room_controller, wave_count)


func _roll_wave_count(budget: float) -> int:
	var roll := _rng.randf()
	var three_chance := clampf((budget - 14.0) * 0.012, 0.0, 0.15)
	var two_chance := clampf(0.18 + budget * 0.015, 0.18, 0.48)
	if roll < three_chance:
		return 3
	if roll < three_chance + two_chance:
		return 2
	return 1


func _spawn_wave(gen: DungeonGenerator, room: Rect2i, room_controller: RoomController, total_waves: int) -> void:
	var wave_index: int = _wave_index_by_room.get(room, 0)
	var total_budget: float = _budget_by_room.get(room, 6.0)
	var wave_budget := total_budget / float(maxi(total_waves, 1))
	wave_budget *= 0.9 + float(wave_index) * 0.15

	var composition := _build_composition(gen.theme_of(room), wave_budget)
	var exclude: Array = []
	var used: Array[Vector2i] = []
	for definition: Dictionary in composition:
		var cell := _spawn_cell(gen, room, definition, wave_index, exclude, used)
		used.append(cell)
		_spawn(definition, cell, room_controller)

	_wave_index_by_room[room] = wave_index + 1


func _build_composition(theme: DungeonGenerator.RoomTheme, budget: float) -> Array[Dictionary]:
	var pool := EnemyCatalog.eligible(GameState.level, theme)
	var result: Array[Dictionary] = []
	var remaining := budget
	var attempts := 0

	while remaining >= 0.8 and result.size() < 14 and attempts < 40:
		attempts += 1
		var affordable: Array[Dictionary] = []
		for definition: Dictionary in pool:
			if float(definition.get("cost", 1.0)) <= remaining + 0.2:
				affordable.append(definition)
		if affordable.is_empty():
			break

		var picked := _weighted_pick(affordable, theme)
		result.append(picked)
		remaining -= float(picked.get("cost", 1.0))

	if result.is_empty() and not pool.is_empty():
		result.append(_cheapest(pool))
	return result


func _weighted_pick(pool: Array[Dictionary], theme: DungeonGenerator.RoomTheme) -> Dictionary:
	var total := 0.0
	for definition: Dictionary in pool:
		var weight := float(definition.get("weight", 1.0))
		if definition.get("theme", DungeonGenerator.RoomTheme.NONE) == theme:
			weight *= 1.7
		total += weight

	var roll := _rng.randf() * total
	for definition: Dictionary in pool:
		var weight := float(definition.get("weight", 1.0))
		if definition.get("theme", DungeonGenerator.RoomTheme.NONE) == theme:
			weight *= 1.7
		roll -= weight
		if roll <= 0.0:
			return definition
	return pool[-1]


func _cheapest(pool: Array[Dictionary]) -> Dictionary:
	var result := pool[0]
	for definition: Dictionary in pool:
		if float(definition.get("cost", 1.0)) < float(result.get("cost", 1.0)):
			result = definition
	return result


func _spawn_cell(gen: DungeonGenerator, room: Rect2i, definition: Dictionary, wave_index: int, exclude: Array, used: Array[Vector2i]) -> Vector2i:
	var zones: Array = gen.enemy_spawn_zones.get(room, [])
	if zones.is_empty():
		return _random_room_cell(gen, room, exclude + used)

	var preferred: Array[String] = []
	var role: EnemyCatalog.SpawnRole = definition.get("role", EnemyCatalog.SpawnRole.ANY)
	match role:
		EnemyCatalog.SpawnRole.FRONTLINE:
			preferred = ["centre", "north", "south", "west", "east"]
		EnemyCatalog.SpawnRole.BACKLINE:
			preferred = ["north", "south", "west", "east", "centre"]
		EnemyCatalog.SpawnRole.FLANKER:
			preferred = ["west", "east", "north", "south", "centre"]
		_:
			preferred = ["north", "south", "west", "east", "centre"]

	# Rotate directional preference between waves so reinforcements do not always
	# enter from the same side.
	if preferred.size() > 1:
		for _i in wave_index % mini(4, preferred.size()):
			preferred.append(preferred.pop_front())

	for name: String in preferred:
		for zone: Dictionary in zones:
			if zone.get("name", "") != name:
				continue
			var valid: Array[Vector2i] = []
			for cell: Vector2i in zone.get("cells", []):
				if not exclude.has(cell) and not used.has(cell):
					valid.append(cell)
			if not valid.is_empty():
				return valid[_rng.randi_range(0, valid.size() - 1)]

	return _random_room_cell(gen, room, exclude + used)


func spawn_boss(room: Rect2i, room_controller: RoomController, on_spawned: Callable = Callable()) -> void:
	_spawn(EnemyCatalog.BOSS_STATS, room.position + room.size / 2, room_controller, on_spawned)


func _random_room_cell(gen: DungeonGenerator, room: Rect2i, exclude: Array = []) -> Vector2i:
	var margin := 4
	if room.size.x <= margin * 2 or room.size.y <= margin * 2:
		return room.position + room.size / 2
	for _attempt in 20:
		var cell := Vector2i(
			_rng.randi_range(room.position.x + margin, room.end.x - margin),
			_rng.randi_range(room.position.y + margin, room.end.y - margin)
		)
		if gen.grid.has(cell) and not exclude.has(cell):
			return cell
	return room.position + room.size / 2


func _spawn(base_stats: Dictionary, cell: Vector2i, room_controller: RoomController, on_spawned: Callable = Callable()) -> void:
	var scene: PackedScene = base_stats.get("scene", EnemyCatalog.SlimeScene)
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

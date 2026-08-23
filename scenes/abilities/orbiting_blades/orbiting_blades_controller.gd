class_name OrbitingBladesController
extends Node2D

var player: Player

var duration: float
var blade_count: int
var orbit_radius: float
var rotation_speed: float
var damage: float
var hit_radius: float
var hit_cooldown: float

var elapsed: float = 0.0
var orbit_angle: float = 0.0

var blades: Array[Node2D] = []

# Tracks when each enemy can be hit again.
var enemy_hit_times: Dictionary = {}
	
func setup(
	target_player: Player,
	new_duration: float,
	new_blade_count: int,
	new_orbit_radius: float,
	new_rotation_speed: float,
	new_damage: float,
	new_hit_radius: float,
	new_hit_cooldown: float
) -> void:
	player = target_player

	duration = new_duration
	blade_count = new_blade_count
	orbit_radius = new_orbit_radius
	rotation_speed = new_rotation_speed
	damage = new_damage
	hit_radius = new_hit_radius
	hit_cooldown = new_hit_cooldown

	global_position = player.global_position

	_create_blades()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return

	elapsed += delta

	if elapsed >= duration:
		_finish()
		return

	global_position = player.global_position

	orbit_angle += rotation_speed * delta

	_update_blade_positions()

	_update_hit_cooldowns(delta)

	_check_enemy_hits()
	
func _create_blades() -> void:
	for i in range(blade_count):
		var blade := _create_blade_visual()

		add_child(blade)
		blades.append(blade)

	_update_blade_positions()
	
func _create_blade_visual() -> Node2D:
	var blade := Node2D.new()

	# Main blade shape
	var polygon := Polygon2D.new()

	polygon.polygon = PackedVector2Array([
		Vector2(0, -16),
		Vector2(5, -5),
		Vector2(4, 12),
		Vector2(0, 18),
		Vector2(-4, 12),
		Vector2(-5, -5)
	])

	polygon.color = Color(
		0.75,
		0.85,
		1.0,
		0.95
	)

	blade.add_child(polygon)


	# Small glowing centre
	var core := Polygon2D.new()

	core.polygon = PackedVector2Array([
		Vector2(-4, -4),
		Vector2(4, -4),
		Vector2(4, 4),
		Vector2(-4, 4)
	])

	core.color = Color(
		0.4,
		0.65,
		1.0,
		0.9
	)

	blade.add_child(core)

	return blade
	
func _update_blade_positions() -> void:
	if blades.is_empty():
		return

	for i in range(blades.size()):
		var blade := blades[i]

		var angle_offset := (
			TAU
			* float(i)
			/ float(blades.size())
		)

		var angle := orbit_angle + angle_offset

		var direction := Vector2(
			cos(angle),
			sin(angle)
		)

		blade.position = direction * orbit_radius

		# Point the blade along its orbit.
		blade.rotation = angle + PI / 2.0
		
func _check_enemy_hits() -> void:
	for blade in blades:
		var blade_position := blade.global_position

		for enemy in get_tree().get_nodes_in_group("enemy"):
			if not enemy is Node2D:
				continue

			if enemy_hit_times.has(enemy):
				continue

			if blade_position.distance_to(
				enemy.global_position
			) > hit_radius:
				continue

			var hurt_box = enemy.get_node_or_null(
				"Components/HurtBox"
			)

			if hurt_box == null:
				continue

			hurt_box.take_damage(damage)

			enemy_hit_times[enemy] = hit_cooldown
			
func _update_hit_cooldowns(delta: float) -> void:
	var finished: Array = []

	for enemy in enemy_hit_times:
		if not is_instance_valid(enemy):
			finished.append(enemy)
			continue

		enemy_hit_times[enemy] -= delta

		if enemy_hit_times[enemy] <= 0.0:
			finished.append(enemy)

	for enemy in finished:
		enemy_hit_times.erase(enemy)
		
func _finish() -> void:
	set_physics_process(false)

	var tween := create_tween()
	tween.set_parallel(true)

	for blade in blades:
		tween.tween_property(
			blade,
			"modulate:a",
			0.0,
			0.2
		)

		tween.tween_property(
			blade,
			"scale",
			Vector2(0.2, 0.2),
			0.2
		)

	tween.chain().tween_callback(queue_free)

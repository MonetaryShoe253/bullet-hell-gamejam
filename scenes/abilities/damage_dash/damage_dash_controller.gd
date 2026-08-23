class_name DamageDashController
extends Node

var player: Player
var dash_effects: DashEffectsComponent

var direction: Vector2
var duration: float
var damage: float
var hit_radius: float
var post_invincibility_duration: float

var elapsed: float = 0.0
var active: bool = false

var hit_enemies: Array[Node2D] = []


func setup(
	target_player: Player,
	new_damage: float,
	new_speed: float,
	new_duration: float,
	new_hit_radius: float,
	new_post_invincibility_duration: float = 0.0
) -> void:
	player = target_player

	damage = new_damage
	duration = new_duration
	hit_radius = new_hit_radius
	post_invincibility_duration = new_post_invincibility_duration

	dash_effects = player.get_node(
		"Components/DashEffectsComponent"
	) as DashEffectsComponent

	direction = (
		player.get_global_mouse_position()
		- player.global_position
	).normalized()

	# Ask Player to begin forced movement.
	var started := player.start_ability_dash(
		direction,
		new_speed
	)

	if not started:
		queue_free()
		return

	hit_enemies.clear()
	active = true

	player.health_component.invulnerable = true

	if dash_effects != null:
		dash_effects.start_damage_dash(
			direction,
			hit_radius
		)


func _physics_process(delta: float) -> void:
	if not active:
		return

	if player == null or not is_instance_valid(player):
		queue_free()
		return

	elapsed += delta

	_damage_dash_path()

	if elapsed >= duration:
		_finish_dash()


func _damage_dash_path() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D:
			continue

		if enemy in hit_enemies:
			continue

		if player.global_position.distance_to(
			enemy.global_position
		) > hit_radius:
			continue

		hit_enemies.append(enemy)

		var hurt_box = enemy.get_node_or_null(
			"Components/HurtBox"
		)

		if hurt_box != null:
			hurt_box.take_damage(damage)


func _finish_dash() -> void:
	if not active:
		return

	active = false

	# Stop Player movement immediately.
	if is_instance_valid(player):
		player.stop_ability_dash()

	if dash_effects != null:
		dash_effects.end_damage_dash()

	# I-frames can continue after movement ends.
	if post_invincibility_duration > 0.0:
		await get_tree().create_timer(
			post_invincibility_duration
		).timeout

	if is_instance_valid(player):
		player.health_component.invulnerable = false

	queue_free()

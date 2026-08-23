class_name OrbitingBladesController
extends Node2D


const BLADE_SCENE := preload(
	"res://scenes/abilities/orbiting_blades/orbiting_blade.tscn"
)

var player: Player

var duration: float
var blade_count: int
var orbit_radius: float
var rotation_speed: float
var damage: float
var hit_radius: float
var hit_cooldown: float
var blade_spin_speed: float


var elapsed: float = 0.0
var orbit_angle: float = 0.0

# Used for the spawn animation.
var current_orbit_radius: float = 0.0


var blades: Array[OrbitingBlade] = []

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
	new_hit_cooldown: float,
	new_blade_spin_speed: float
) -> void:
	player = target_player

	duration = new_duration
	blade_count = new_blade_count
	orbit_radius = new_orbit_radius
	rotation_speed = new_rotation_speed
	damage = new_damage
	hit_radius = new_hit_radius
	hit_cooldown = new_hit_cooldown
	blade_spin_speed = new_blade_spin_speed

	global_position = player.global_position

	_create_blades()

	_animate_blades_out()


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_cleanup()
		return

	elapsed += delta

	if elapsed >= duration:
		_finish()
		return

	# Follow the player.
	global_position = player.global_position

	# Rotate the entire formation.
	orbit_angle += rotation_speed * delta

	_update_blade_positions()

	_update_hit_cooldowns(delta)

	_check_enemy_hits()
	

# ---------------------------------------------------------------------------
# Blade Creation
# ---------------------------------------------------------------------------

func _create_blades() -> void:
	for i in range(blade_count):
		var blade := BLADE_SCENE.instantiate() as OrbitingBlade

		if blade == null:
			continue

		add_child(blade)

		blade.spin_speed = blade_spin_speed

		# Start slightly smaller for the spawn effect.
		blade.scale = Vector2(0.4, 0.4)

		blades.append(blade)

	_update_blade_positions()


# ---------------------------------------------------------------------------
# Spawn Animation
# ---------------------------------------------------------------------------

func _animate_blades_out() -> void:
	current_orbit_radius = 8.0

	var tween := create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		self,
		"current_orbit_radius",
		orbit_radius,
		0.25
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	for blade in blades:
		tween.tween_property(
			blade,
			"scale",
			Vector2.ONE,
			0.18
		).set_trans(
			Tween.TRANS_BACK
		).set_ease(
			Tween.EASE_OUT
		)


# ---------------------------------------------------------------------------
# Orbit
# ---------------------------------------------------------------------------

func _update_blade_positions() -> void:
	if blades.is_empty():
		return

	for i in range(blades.size()):
		var blade := blades[i]

		if not is_instance_valid(blade):
			continue

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

		blade.position = (
			direction
			* current_orbit_radius
		)


# ---------------------------------------------------------------------------
# Damage
# ---------------------------------------------------------------------------

func _check_enemy_hits() -> void:
	for blade in blades:
		if not is_instance_valid(blade):
			continue

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


# ---------------------------------------------------------------------------
# Finish
# ---------------------------------------------------------------------------

func _finish() -> void:
	set_physics_process(false)

	var tween := create_tween()

	tween.set_parallel(true)

	for blade in blades:
		if not is_instance_valid(blade):
			continue

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

	await tween.finished

	_cleanup()


func _cleanup() -> void:
	for blade in blades:
		if is_instance_valid(blade):
			blade.cleanup()

	blades.clear()

	queue_free()

class_name BlackHoleController
extends Node2D


var duration: float
var radius: float
var pull_strength: float
var explosion_damage: float

var elapsed: float = 0.0


func setup(
	spawn_position: Vector2,
	new_duration: float,
	new_radius: float,
	new_pull_strength: float,
	new_explosion_damage: float
) -> void:
	global_position = spawn_position

	duration = new_duration
	radius = new_radius
	pull_strength = new_pull_strength
	explosion_damage = new_explosion_damage

	_create_visual()


func _physics_process(delta: float) -> void:
	elapsed += delta

	if elapsed >= duration:
		_explode()
		return

	_pull_enemies(delta)


# ---------------------------------------------------------------------------
# Enemy Pull
# ---------------------------------------------------------------------------

func _pull_enemies(delta: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D:
			continue

		var enemy_node := enemy as Node2D

		var distance := enemy_node.global_position.distance_to(
			global_position
		)

		if distance > radius:
			continue

		var direction := (
			global_position
			- enemy_node.global_position
		).normalized()

		# Pull becomes stronger toward the centre.
		var strength := 1.0 - (distance / radius)

		strength = lerpf(
			0.35,
			1.0,
			strength
		)

		enemy_node.global_position += (
			direction
			* pull_strength
			* strength
			* delta
		)


# ---------------------------------------------------------------------------
# Explosion
# ---------------------------------------------------------------------------

func _explode() -> void:
	# Prevent _physics_process from exploding more than once.
	set_physics_process(false)

	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D:
			continue

		if enemy.global_position.distance_to(
			global_position
		) > radius:
			continue

		var hurt_box = enemy.get_node_or_null(
			"Components/HurtBox"
		)

		if hurt_box != null:
			hurt_box.take_damage(explosion_damage)

	_spawn_explosion_visual()

	# Give the explosion animation time to finish before
	# deleting the controller.
	await get_tree().create_timer(0.35).timeout

	queue_free()


# ---------------------------------------------------------------------------
# Main Visual
# ---------------------------------------------------------------------------

func _create_visual() -> void:
	_create_outer_ring()
	_create_core()


func _create_outer_ring() -> void:
	var outer_ring := Line2D.new()

	outer_ring.width = 3.0

	outer_ring.default_color = Color(
		0.55,
		0.25,
		1.0,
		0.65
	)

	outer_ring.closed = true

	var segments := 48

	for i in range(segments):
		var angle := (
			TAU
			* float(i)
			/ float(segments)
		)

		outer_ring.add_point(
			Vector2(
				cos(angle),
				sin(angle)
			) * radius
		)

	add_child(outer_ring)


func _create_core() -> void:
	var core := Polygon2D.new()

	var points := PackedVector2Array()

	var core_radius := 20.0

	for i in range(32):
		var angle := (
			TAU
			* float(i)
			/ 32.0
		)

		points.append(
			Vector2(
				cos(angle),
				sin(angle)
			) * core_radius
		)

	core.polygon = points

	core.color = Color(
		0.03,
		0.01,
		0.06,
		1.0
	)

	add_child(core)

	# Pulse the singularity.
	var tween := core.create_tween()

	tween.set_loops()

	tween.tween_property(
		core,
		"scale",
		Vector2(1.35, 1.35),
		0.35
	).set_trans(Tween.TRANS_SINE)

	tween.tween_property(
		core,
		"scale",
		Vector2.ONE,
		0.35
	).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------------------
# Explosion Visual
# ---------------------------------------------------------------------------

func _spawn_explosion_visual() -> void:
	var ring := Line2D.new()

	ring.width = 5.0

	ring.default_color = Color(
		0.75,
		0.4,
		1.0,
		0.9
	)

	ring.closed = true

	var segments := 48

	for i in range(segments):
		var angle := (
			TAU
			* float(i)
			/ float(segments)
		)

		ring.add_point(
			Vector2(
				cos(angle),
				sin(angle)
			) * radius
		)

	add_child(ring)

	ring.scale = Vector2(0.15, 0.15)

	var tween := ring.create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector2.ONE,
		0.18
	).set_trans(
		Tween.TRANS_EXPO
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		ring,
		"modulate:a",
		0.0,
		0.30
	)

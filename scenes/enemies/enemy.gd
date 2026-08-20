class_name Enemy
extends CharacterBody2D

@export var fire_rate: float = 1.0
@export var move_speed: float = 250.0
@export var preferred_distance: float = 150.0
@export var distance_tolerance: float = 20.0
@export var projectile_damage: float = 5.0
@export var money_reward: int = 5
@export var player: Node2D

enum ShotPattern {
	SINGLE,
	SPREAD,
	BURST,
	CIRCLE,
	SPIRAL,
	WAVE,
	SHOTGUN,
	ALTERNATING_SPREAD,
	RING_GAP,
	CROSS_BURST
}
@export var shot_pattern: ShotPattern = ShotPattern.SINGLE

enum MovementPattern {
	KITE,
	CHASE,
	BOUNCE,
	STRAFE,
	ORBIT
}
@export var movement_pattern: MovementPattern = MovementPattern.KITE

var strafe_direction: float = 1.0
var strafe_timer: float = 0.0
var bounce_phase: float = 0.0

@export var projectile_scene: PackedScene

@export var spread_angle: float = 20.0
@export var spread_projectiles: int = 3
@export var circle_projectiles: int = 12

@export var burst_count: int = 3
@export var burst_delay: float = 0.1

@export var spiral_projectiles: int = 2
@export var spiral_rotation_speed: float = 12.0
var spiral_rotation: float = 0.0

@export var wave_angle: float = 45.0
@export var wave_step: float = 8.0

var wave_rotation: float = -45.0
var wave_direction: float = 1.0

@export var shotgun_projectiles: int = 6
@export var shotgun_angle: float = 35.0

@export var alternating_projectiles: int = 5
@export var alternating_angle: float = 60.0
@export var alternating_offset: float = 10.0

var alternating_side: float = 1.0

@export var ring_gap_projectiles: int = 16
@export var ring_gap_size: float = 50.0
@export var ring_gap_rotation_speed: float = 15.0

var ring_gap_rotation: float = 0.0

@export var cross_burst_count: int = 3
@export var cross_burst_projectiles: int = 5
@export var cross_burst_angle: float = 50.0
@export var cross_burst_rotation: float = 12.0
@export var cross_burst_delay: float = 0.12

var orbit_direction: float = 1.0
var orbit_wall_turn_cooldown: float = 0.0

@export var orbit_wall_turn_delay: float = 0.4

@onready var visual: CanvasItem = $Sprite2D
@onready var health_component: HealthComponent = $Components/HealthComponent

var _fire_timer: Timer
var _flash_tween: Tween
var _base_modulate: Color = Color.WHITE

func _ready() -> void:
	_base_modulate = visual.modulate

	_fire_timer = Timer.new()
	_fire_timer.wait_time = fire_rate
	_fire_timer.timeout.connect(fire_at_player)
	add_child(_fire_timer)
	_fire_timer.start()

	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)

func configure(stats: Dictionary) -> void:
	if stats.has("health"):
		health_component.max_health = stats.health
		health_component.current_health = stats.health
	if stats.has("move_speed"):
		move_speed = stats.move_speed
	if stats.has("fire_rate"):
		fire_rate = stats.fire_rate
		if _fire_timer:
			_fire_timer.wait_time = fire_rate
	if stats.has("damage"):
		projectile_damage = stats.damage
	if stats.has("money_reward"):
		money_reward = stats.money_reward
	if stats.has("color"):
		visual.modulate = stats.color
		_base_modulate = stats.color
	if stats.has("scale"):
		scale = Vector2.ONE * float(stats.scale)
	if stats.has("shot_pattern"):
		shot_pattern = stats.shot_pattern
	if stats.has("movement_pattern"):
		movement_pattern = stats.movement_pattern
	if stats.has("preferred_distance"):
		preferred_distance = stats.preferred_distance
	if stats.has("distance_tolerance"):
		distance_tolerance = stats.distance_tolerance
	if stats.has("spiral_projectiles"):
		spiral_projectiles = stats.spiral_projectiles
	if stats.has("spiral_rotation_speed"):
		spiral_rotation_speed = stats.spiral_rotation_speed
	if stats.has("wave_angle"):
		wave_angle = stats.wave_angle
		wave_rotation = -wave_angle
	if stats.has("wave_step"):
		wave_step = stats.wave_step
	if stats.has("shotgun_projectiles"):
		shotgun_projectiles = stats.shotgun_projectiles
	if stats.has("shotgun_angle"):
		shotgun_angle = stats.shotgun_angle		
	if stats.has("alternating_projectiles"):
		alternating_projectiles = stats.alternating_projectiles
	if stats.has("alternating_angle"):
		alternating_angle = stats.alternating_angle
	if stats.has("alternating_offset"):
		alternating_offset = stats.alternating_offset
	if stats.has("ring_gap_projectiles"):
		ring_gap_projectiles = stats.ring_gap_projectiles
	if stats.has("ring_gap_size"):
		ring_gap_size = stats.ring_gap_size
	if stats.has("ring_gap_rotation_speed"):
		ring_gap_rotation_speed = stats.ring_gap_rotation_speed
	if stats.has("projectile_scene"):
		projectile_scene = stats.projectile_scene
	if stats.has("cross_burst_count"):
		cross_burst_count = stats.cross_burst_count
	if stats.has("cross_burst_projectiles"):
		cross_burst_projectiles = stats.cross_burst_projectiles
	if stats.has("cross_burst_angle"):
		cross_burst_angle = stats.cross_burst_angle
	if stats.has("cross_burst_rotation"):
		cross_burst_rotation = stats.cross_burst_rotation
	if stats.has("cross_burst_delay"):
		cross_burst_delay = stats.cross_burst_delay
		

func _physics_process(_delta: float) -> void:
	if not can_see_player():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	match movement_pattern:
		MovementPattern.KITE:
			_kite()
		MovementPattern.CHASE:
			_chase()
		MovementPattern.BOUNCE:
			_bounce(_delta)
		MovementPattern.STRAFE:
			_strafe(_delta)
		MovementPattern.ORBIT:
			_orbit(_delta)
	
func can_see_player() -> bool:
	if player == null:
		return false

	var ray := $PlayerSight as RayCast2D
	var target := ray.to_local(player.global_position)

	if target.is_zero_approx():
		return true

	ray.target_position = target
	ray.force_raycast_update()

	return ray.is_colliding() and ray.get_collider() == player

func fire_at_player() -> void:
	if player == null:
		return

	if not can_see_player():
		return

	var direction := (player.global_position - global_position).normalized()

	match shot_pattern:
		ShotPattern.SINGLE:
			fire_single(direction)

		ShotPattern.SPREAD:
			fire_spread(direction)

		ShotPattern.BURST:
			fire_burst(direction)

		ShotPattern.CIRCLE:
			fire_circle()

		ShotPattern.SPIRAL:
			fire_spiral()

		ShotPattern.WAVE:
			fire_wave(direction)

		ShotPattern.SHOTGUN:
			fire_shotgun(direction)

		ShotPattern.ALTERNATING_SPREAD:
			fire_alternating_spread(direction)
			
		ShotPattern.RING_GAP:
			fire_ring_gap()
						
		ShotPattern.CROSS_BURST:
			fire_cross_burst(direction)

func spawn_projectile(direction: Vector2) -> void:
	if projectile_scene == null:
		push_warning(
			"Enemy has no projectile scene assigned: " + name
		)
		return

	var proj: EnemyProjectile = projectile_scene.instantiate()

	get_tree().current_scene.add_child(proj)

	proj.launch(
		global_position,
		direction,
		projectile_damage
	)

func fire_single(direction: Vector2) -> void:
	spawn_projectile(direction)

func fire_spread(direction: Vector2) -> void:
	if spread_projectiles <= 1:
		spawn_projectile(direction)
		return

	var total_angle := deg_to_rad(spread_angle)
	var start_angle := -total_angle / 2.0
	var step := total_angle / (spread_projectiles - 1)

	for i in range(spread_projectiles):
		var angle := start_angle + step * i
		var bullet_direction := direction.rotated(angle)
		spawn_projectile(bullet_direction)

func fire_circle() -> void:
	for i in range(circle_projectiles):
		var angle := TAU * i / circle_projectiles

		var direction := Vector2.RIGHT.rotated(angle)

		spawn_projectile(direction)

func fire_burst(_direction: Vector2) -> void:
	for i in range(burst_count):
		if player == null:
			return

		var direction := (player.global_position - global_position).normalized()
		spawn_projectile(direction)
		await get_tree().create_timer(burst_delay).timeout
		
func fire_spiral() -> void:
	for i in range(spiral_projectiles):
		var angle := (
			deg_to_rad(spiral_rotation)
			+ TAU * i / spiral_projectiles
		)

		var direction := Vector2.RIGHT.rotated(angle)

		spawn_projectile(direction)

	spiral_rotation = fmod(
		spiral_rotation + spiral_rotation_speed,
		360.0
	)
	
func fire_wave(direction: Vector2) -> void:
	var bullet_direction := direction.rotated(
		deg_to_rad(wave_rotation)
	)

	spawn_projectile(bullet_direction)

	wave_rotation += wave_step * wave_direction

	if wave_rotation >= wave_angle:
		wave_rotation = wave_angle
		wave_direction = -1.0

	elif wave_rotation <= -wave_angle:
		wave_rotation = -wave_angle
		wave_direction = 1.0

func fire_alternating_spread(direction: Vector2) -> void:
	if alternating_projectiles <= 1:
		spawn_projectile(direction)
		return

	var total_angle := deg_to_rad(alternating_angle)
	var start_angle := -total_angle / 2.0
	var step := total_angle / (alternating_projectiles - 1)

	var offset := deg_to_rad(
		alternating_offset * alternating_side
	)

	for i in range(alternating_projectiles):
		var angle := start_angle + step * i + offset

		spawn_projectile(
			direction.rotated(angle)
		)

	alternating_side *= -1.0

func fire_ring_gap() -> void:
	var gap_half_size := ring_gap_size / 2.0

	for i in range(ring_gap_projectiles):
		var angle_degrees := (
			360.0 * i / ring_gap_projectiles
		)

		var relative_angle := wrapf(
			angle_degrees - ring_gap_rotation,
			-180.0,
			180.0
		)

		# Don't fire bullets inside the gap.
		if abs(relative_angle) < gap_half_size:
			continue

		var direction := Vector2.RIGHT.rotated(
			deg_to_rad(angle_degrees)
		)

		spawn_projectile(direction)

	ring_gap_rotation = fmod(
		ring_gap_rotation + ring_gap_rotation_speed,
		360.0
	)
	
func fire_cross_burst(_initial_direction: Vector2) -> void:
	for burst_index in range(cross_burst_count):
		if player == null:
			return

		# Re-aim every burst.
		var aim_direction := (
			player.global_position - global_position
		).normalized()

		# Alternate the spread rotation left/right.
		var rotation_sign := 1.0
		if burst_index % 2 == 1:
			rotation_sign = -1.0

		var rotation_offset := deg_to_rad(
			cross_burst_rotation
			* rotation_sign
		)

		var total_angle := deg_to_rad(cross_burst_angle)
		var start_angle := -total_angle / 2.0

		var step := 0.0
		if cross_burst_projectiles > 1:
			step = total_angle / (
				cross_burst_projectiles - 1
			)

		for i in range(cross_burst_projectiles):
			var angle := (
				start_angle
				+ step * i
				+ rotation_offset
			)

			var bullet_direction := aim_direction.rotated(angle)

			spawn_projectile(bullet_direction)

		await get_tree().create_timer(
			cross_burst_delay
		).timeout

func _kite() -> void:
	if player == null:
		return

	var to_player := player.global_position - global_position
	var current_distance := to_player.length()
	var direction := to_player.normalized()

	if current_distance > preferred_distance + distance_tolerance:
		velocity = direction * move_speed
	elif current_distance < preferred_distance - distance_tolerance:
		velocity = -direction * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	
func fire_shotgun(direction: Vector2) -> void:
	var half_angle := shotgun_angle / 2.0

	for i in range(shotgun_projectiles):
		var random_angle := randf_range(
			-half_angle,
			half_angle
		)

		var bullet_direction := direction.rotated(
			deg_to_rad(random_angle)
		)

		spawn_projectile(bullet_direction)

func _chase() -> void:
	if player == null:
		return

	var direction := (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()

func _strafe(_delta: float) -> void:
	if player == null:
		return

	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var toward := to_player.normalized()
	var side := Vector2(-toward.y, toward.x)

	strafe_timer -= _delta
	if strafe_timer <= 0.0:
		strafe_timer = 0.9
		strafe_direction *= -1.0

	var drift := Vector2.ZERO

	if distance > preferred_distance + 20.0:
		drift += toward * move_speed
	elif distance < preferred_distance - 20.0:
		drift -= toward * move_speed

	drift += side * strafe_direction * move_speed * 0.8

	velocity = drift
	move_and_slide()

func _bounce(_delta: float) -> void:
	if player == null:
		return

	var to_player := player.global_position - global_position
	var direction := to_player.normalized()
	var side := Vector2(-direction.y, direction.x)

	bounce_phase += _delta * 4.0

	var wave := sin(bounce_phase)
	var offset := side * wave * 80.0

	var target_pos := player.global_position + offset
	var desired_dir := (target_pos - global_position).normalized()

	velocity = desired_dir * move_speed * 1.15
	move_and_slide()
	
func _orbit(delta: float) -> void:
	if player == null:
		return

	# Update wall-turn cooldown.
	if orbit_wall_turn_cooldown > 0.0:
		orbit_wall_turn_cooldown -= delta

	var to_player := player.global_position - global_position
	var distance := to_player.length()

	if distance <= 0.0:
		velocity = Vector2.ZERO
		return

	var toward_player := to_player.normalized()

	# Perpendicular direction around the player.
	var sideways := Vector2(
		-toward_player.y,
		toward_player.x
	) * orbit_direction

	var movement := sideways

	# Too far away: orbit while moving inward.
	if distance > preferred_distance + distance_tolerance:
		movement += toward_player * 0.5

	# Too close: orbit while moving outward.
	elif distance < preferred_distance - distance_tolerance:
		movement -= toward_player * 0.5

	velocity = movement.normalized() * move_speed

	move_and_slide()

	# If we hit something, reverse the orbit direction.
	if (
		get_slide_collision_count() > 0
		and orbit_wall_turn_cooldown <= 0.0
	):
		orbit_direction *= -1.0
		orbit_wall_turn_cooldown = orbit_wall_turn_delay

func _on_damaged(amount: float) -> void:
	Fx.damage_number(global_position + Vector2(0, -24), amount)
	_flash_red()

func _flash_red() -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual, "modulate", Color(1.0, 0.25, 0.25, 1.0), 0.05)
	_flash_tween.tween_property(visual, "modulate", _base_modulate, 0.15)

func _on_died() -> void:
	Fx.money_popup(global_position + Vector2(0, -24), money_reward)
	GameState.add_money(money_reward)
	GameState.enemy_killed.emit()
	
	queue_free()

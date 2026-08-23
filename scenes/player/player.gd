class_name Player
extends CharacterBody2D

@export var muzzle_offset: float = 30.0  # distance from player center to spawn point


@export_category("Dash")
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.15

var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: Vector2
var dash_cooldown_remaining: float = 0.0

## Separate movement state for the Damage Dash ability - deliberately not
## sharing is_dashing/can_dash/dash_cooldown_remaining with the regular dash
## above, since the ability has its own cooldown on AbilityComponent.
var is_ability_dashing: bool = false
var ability_dash_direction: Vector2

var _ability_dash_speed: float = 0.0
var _ability_dash_damage: float = 0.0
var _ability_dash_hit_radius: float = 0.0
var _ability_dash_hit_enemies: Array[Node2D] = []

@export var damage_ring_interval: float = 0.04
@export var damage_ring_lifetime: float = 0.22

var _damage_ring_timer: float = 0.0

# ---------------------------------------------------------------------------
# Dash Visual FX
# ---------------------------------------------------------------------------

@export_category("Dash Visual FX")

@export var camera: Camera2D

# Camera falls this far behind the player during a dash.
@export var dash_camera_lag: float = 35.0

# How quickly camera moves into its lag position.
@export var dash_camera_lag_time: float = 0.08

# How quickly camera catches the player afterward.
@export var dash_camera_recovery_time: float = 0.22

# Afterimages
@export var afterimage_interval: float = 0.025
@export var afterimage_lifetime: float = 0.45
@export_range(0.0, 1.0) var afterimage_start_alpha: float = 0.75
# Dash lines
@export var dash_line_count: int = 5
@export var dash_line_length: float = 30.0
@export var dash_line_lifetime: float = 0.15
@export var dash_line_spread: float = 18.0


var _camera_default_position: Vector2
var _camera_tween: Tween
var _afterimage_timer: float = 0.0


@onready var hurt_box: HurtboxComponent = $Components/HurtBox
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var inventory: InventoryComponent = $Components/InventoryComponent
@onready var stats: StatsComponent = $Components/StatsComponent
@onready var passive_ability_component: PassiveAbilityComponent = $Components/PassiveAbilityComponent
@onready var ability_component: AbilityComponent = $Components/AbilityComponent

## Index order matches an angle sector walk (45 deg each) starting at east and
## going clockwise - Y is down in Godot 2D, so a positive angle sweeps toward
## south, matching the sprite sheet's own direction names.
const FACING_NAMES: Array[String] = [
	"east", "south_east", "south", "south_west",
	"west", "north_west", "north", "north_east",
]

var _facing: String = "south"

## The attack SpriteFrames animation is 7 frames at 12 fps (~0.58s) as
## authored - matches this so the throw motion actually finishes around the
## same time a shot at the *default* fire_rate goes off. shoot() scales
## AnimatedSprite2D.speed_scale by base_duration/fire_rate so upgrading fire
## rate (see apply_upgrade()) speeds the animation up to match, rather than
## the throw visibly lagging behind shots that are already firing again.
const ATTACK_ANIM_BASE_DURATION: float = 7.0 / 12.0


var projectile_scene: PackedScene = preload("res://scenes/projectiles/playerbullet/playerbullet.tscn")
var time_since_last_shot: float = 0.0

const DeathRewardScene := preload("res://scenes/ui/death_reward_ui.tscn")

const GameOverScene := preload("res://scenes/ui/game_over.tscn")

@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var health_bar: ProgressBar = $HealthBar/HealthBar
@onready var dash_cooldown_bar: ProgressBar = $EnergyBar/EnergyBar
@onready var ability_bars: AbilityBars = $AbilityBars


func _ready() -> void:
	# StatsComponent calculates the player's max HP; HealthComponent owns the
	# actual health state. Sync them once on startup.
	health_component.set_max_health(stats.get_max_health(), true)
	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.current_health

	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	
	stats.stats_changed.connect(_on_stats_changed)
	inventory.equipment_changed.connect(_on_equipment_changed)

	dash_cooldown_bar.min_value = 0.0
	dash_cooldown_bar.max_value = 1.0
	dash_cooldown_bar.value = 1.0	
	
	ability_bars.setup(ability_component)

	passive_ability_component.equip_all()

	_setup_dash_camera()


func _on_health_changed(current_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	
func _on_equipment_changed() -> void:
	stats.set_equipment(
		inventory.equipped_armour,
		inventory.equipped_weapon,
		inventory.equipped_accessory
	)
	
func _on_stats_changed() -> void:
	# Player stats determine the desired max HP. HealthComponent remains generic
	# so enemies can use it without needing a StatsComponent.
	health_component.set_max_health(stats.get_max_health(), true)


func _on_died() -> void:
	
	print("PLAYER DIED")
	var level_reached := GameState.level

	var reward_ui: DeathRewardUI = DeathRewardScene.instantiate()

	get_tree().current_scene.add_child(reward_ui)

	reward_ui.finished.connect(
		_on_death_reward_finished
	)
	
	print("FINISHED SIGNAL CONNECTED")

	reward_ui.open(level_reached)
	
func _on_death_reward_finished() -> void:
	var game_over := GameOverScene.instantiate()

	get_tree().current_scene.add_child(game_over)

	get_tree().paused = true

func _physics_process(delta: float) -> void:
		
	# Afterimages for BOTH normal dash and Damage Dash
	if is_dashing or is_ability_dashing:
		_afterimage_timer -= delta

		if _afterimage_timer <= 0.0:
			_spawn_dash_afterimage()
			_afterimage_timer = afterimage_interval

	# Damage rings ONLY for Damage Dash
	if is_ability_dashing:
		_damage_ring_timer -= delta

		if _damage_ring_timer <= 0.0:
			_spawn_damage_trail_ring()
			_damage_ring_timer = damage_ring_interval
			
	if is_dashing:
		velocity = dash_direction * dash_speed

	elif is_ability_dashing:
		velocity = ability_dash_direction * _ability_dash_speed
		_damage_ability_dash_path()

	else:
		var direction := Input.get_vector(
			"move_left",
			"move_right",
			"move_up",
			"move_down"
		)

		velocity = direction * stats.get_move_speed()

		if Input.is_action_just_pressed("dash"):
			start_dash()

	move_and_slide()

	# Facing follows movement, not the mouse aim - _facing_for() already keeps
	# whatever direction we last had when velocity is ~zero, so standing
	# still and shooting doesn't flicker the sprite back to some default.
	_facing = _facing_for(velocity)
	_update_animation()

	# Dash cooldown
	if dash_cooldown_remaining > 0.0:
		dash_cooldown_remaining -= delta

		if dash_cooldown_remaining <= 0.0:
			dash_cooldown_remaining = 0.0
			can_dash = true

	dash_cooldown_bar.value = 1.0 - (
		dash_cooldown_remaining / stats.get_dash_cooldown()
	)

	ability_component.handle_input(self)


	# Shooting
	time_since_last_shot += delta

	if (Input.is_action_pressed("shoot") 
	and time_since_last_shot >= stats.get_fire_rate()):
		shoot()
		time_since_last_shot = 0.0

func start_dash() -> void:
	if not can_dash or is_dashing:
		return

	can_dash = false
	is_dashing = true

	dash_direction = (
		get_global_mouse_position() - global_position
	).normalized()

	health_component.invulnerable = true

	_afterimage_timer = 0.0

	# Dash juice
	_dash_camera_start(dash_direction)
	_spawn_dash_lines(dash_direction)

	await get_tree().create_timer(dash_duration).timeout

	is_dashing = false
	health_component.invulnerable = false

	_dash_camera_end()

	dash_cooldown_remaining = stats.get_dash_cooldown()
## Self-contained dash used by the Damage Dash ability: moves like a normal
## dash and grants the same invulnerability, but tracked independently of
## is_dashing/can_dash so it never touches the regular dash's cooldown -
## AbilityComponent's own per-slot cooldown is what paces this one.
## post_invincibility_duration keeps invulnerable on for a bit after the
## movement itself ends, without extending is_ability_dashing (so movement
## and input return to normal immediately, only the i-frames linger).
func perform_ability_dash(
	damage: float,
	speed: float,
	duration: float,
	hit_radius: float,
	post_invincibility_duration: float = 0.0
) -> void:
	if is_dashing or is_ability_dashing:
		return

	is_ability_dashing = true

	ability_dash_direction = (
		get_global_mouse_position() - global_position
	).normalized()

	_ability_dash_speed = speed
	_ability_dash_damage = damage
	_ability_dash_hit_radius = hit_radius
	_ability_dash_hit_enemies.clear()

	health_component.invulnerable = true

	# Start Damage Dash visual effects
	_afterimage_timer = 0.0
	_damage_ring_timer = 0.0

	_dash_camera_start(ability_dash_direction)
	_spawn_dash_lines(ability_dash_direction)

	await get_tree().create_timer(duration).timeout

	is_ability_dashing = false

	# Camera catches back up
	_dash_camera_end()

	if post_invincibility_duration > 0.0:
		await get_tree().create_timer(
			post_invincibility_duration
		).timeout

	health_component.invulnerable = false

## Enemies are on a collision mask the player's own CharacterBody2D doesn't
## test against (the player passes through them during move_and_slide), so
## this is a manual proximity sweep each physics frame rather than reading
## collisions off the dash's own movement. hit_radius is deliberately a bit
## larger than the player's own hurtbox extents so the swept path has some
## width to it, not just a pixel-thin line along the direction of travel.
func _damage_ability_dash_path() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy in _ability_dash_hit_enemies or not (enemy is Node2D):
			continue
		if global_position.distance_to(enemy.global_position) > _ability_dash_hit_radius:
			continue

		_ability_dash_hit_enemies.append(enemy)
		var hurt_box = enemy.get_node("Components/HurtBox")
		hurt_box.take_damage(_ability_dash_damage)

func shoot() -> void:
	var proj: PlayerProjectile = projectile_scene.instantiate()

	proj.damage = stats.get_damage()

	get_tree().current_scene.add_child(proj)

	var aim_direction := (
		get_global_mouse_position() - global_position
	).normalized()

	var spawn_position := global_position + aim_direction * muzzle_offset

	proj.launch(spawn_position, aim_direction)
	sprite.speed_scale = ATTACK_ANIM_BASE_DURATION / maxf(stats.get_fire_rate(), 0.05)
	sprite.play("attack_%s" % _facing)


## Snaps a direction vector to one of the 8 facings the sprite sheet has
## frames for. Falls back to whatever we were already facing for a
## near-zero vector (mouse sitting right on top of the player) instead of
## flickering to a meaningless direction.
func _facing_for(vector: Vector2) -> String:
	if vector.length_squared() < 1.0:
		return _facing
	var index: int = int(round(vector.angle() / (PI / 4.0))) % 8
	if index < 0:
		index += 8
	return FACING_NAMES[index]


## Attack is a one-shot animation (loop = false in the SpriteFrames
## resource) - while it's still playing, leave it alone rather than
## stomping it back to idle/walk every frame.
func _update_animation() -> void:
	if sprite.animation.begins_with("attack_") and sprite.is_playing():
		return
	sprite.speed_scale = 1.0  # attack's own speed_scale (see shoot()) only applies to attack

	var state := "walk" if velocity.length_squared() > 25.0 else "idle"
	var anim_name := "%s_%s" % [state, _facing]
	if sprite.animation != anim_name:
		sprite.play(anim_name)
	
func apply_upgrade(upgrade: ShopUpgrade) -> void:
	stats.apply_shop_upgrade(upgrade)


func _setup_dash_camera() -> void:
	if camera == null:
		return

	_camera_default_position = camera.position


func _dash_camera_start(direction: Vector2) -> void:
	if camera == null:
		return

	if _camera_tween != null:
		_camera_tween.kill()

	# Opposite the dash direction = camera gets left behind.
	var lag_position := (
		_camera_default_position
		- direction * dash_camera_lag
	)

	_camera_tween = create_tween()

	_camera_tween.tween_property(
		camera,
		"position",
		lag_position,
		dash_camera_lag_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _dash_camera_end() -> void:
	if camera == null:
		return

	if _camera_tween != null:
		_camera_tween.kill()

	_camera_tween = create_tween()

	_camera_tween.tween_property(
		camera,
		"position",
		_camera_default_position,
		dash_camera_recovery_time
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _spawn_dash_afterimage() -> void:
	var frames := sprite.sprite_frames

	var texture := frames.get_frame_texture(
		sprite.animation,
		sprite.frame
	)

	if texture == null:
		return

	var ghost := Sprite2D.new()

	ghost.texture = texture

	# Copy the AnimatedSprite2D appearance.
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v

	# Add to the WORLD first.
	# This prevents it from following the player.
	get_tree().current_scene.add_child(ghost)

	# Now copy the player's current world transform.
	ghost.global_position = sprite.global_position
	ghost.global_rotation = sprite.global_rotation
	ghost.global_scale = sprite.global_scale

	ghost.z_index = sprite.z_index - 1

	# Start clearly visible.
	ghost.modulate = Color(
		1.0,
		1.0,
		1.0,
		afterimage_start_alpha
	)

	var tween := ghost.create_tween()

	tween.tween_property(
		ghost,
		"modulate:a",
		0.0,
		afterimage_lifetime
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.finished.connect(ghost.queue_free)
	
func _spawn_dash_lines(direction: Vector2) -> void:
	var perpendicular := Vector2(-direction.y, direction.x)

	for i in range(dash_line_count):
		var line := Line2D.new()

		line.width = randf_range(1.0, 2.5)
		line.default_color = Color(1.0, 1.0, 1.0, 0.65)

		# Random position across the width of the dash.
		var side_offset := randf_range(
			-dash_line_spread,
			dash_line_spread
		)

		var forward_offset := randf_range(-10.0, 10.0)

		var start := (
			global_position
			+ perpendicular * side_offset
			+ direction * forward_offset
		)

		# Line stretches backwards from the player.
		var end := (
			start
			- direction
			* randf_range(
				dash_line_length * 0.6,
				dash_line_length
			)
		)

		line.add_point(start)
		line.add_point(end)

		get_tree().current_scene.add_child(line)

		var tween := line.create_tween()

		tween.tween_property(
			line,
			"modulate:a",
			0.0,
			dash_line_lifetime
		)

		tween.finished.connect(line.queue_free)
		
func _spawn_damage_dash_ring() -> void:
	var ring := Line2D.new()

	ring.width = 2.5
	ring.default_color = Color(1.0, 0.35, 0.15, 0.8)
	ring.closed = true

	var segments := 32

	for i in range(segments):
		var angle := TAU * float(i) / float(segments)

		var point := Vector2(
			cos(angle),
			sin(angle)
		) * _ability_dash_hit_radius

		ring.add_point(point)

	# Make the ring follow the player while the damage dash happens.
	ring.scale = Vector2(0.25, 0.25)

	add_child(ring)

	var tween := ring.create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector2.ONE,
		0.12
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		ring,
		"modulate:a",
		0.0,
		0.25
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.chain().tween_callback(ring.queue_free)

	tween.tween_property(
		ring,
		"modulate:a",
		0.0,
		0.25
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tween.finished.connect(ring.queue_free)
	
func _spawn_damage_trail_ring() -> void:
	var ring := Line2D.new()

	ring.width = 2.0
	ring.default_color = Color(1.0, 0.35, 0.15, 0.55)
	ring.closed = true

	var segments := 24

	for i in range(segments):
		var angle := TAU * float(i) / float(segments)

		ring.add_point(
			Vector2(cos(angle), sin(angle))
			* _ability_dash_hit_radius
		)

	# IMPORTANT:
	# Put it in the world so it stays behind.
	get_tree().current_scene.add_child(ring)

	ring.global_position = global_position

	var tween := ring.create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"modulate:a",
		0.0,
		damage_ring_lifetime
	)

	tween.tween_property(
		ring,
		"scale",
		Vector2(1.15, 1.15),
		damage_ring_lifetime
	)

	tween.chain().tween_callback(ring.queue_free)


func create_black_hole(
	target_position: Vector2,
	duration: float,
	radius: float,
	pull_strength: float,
	explosion_damage: float
) -> void:
	var black_hole := Node2D.new()

	get_tree().current_scene.add_child(black_hole)
	black_hole.global_position = target_position

	# Store values on the node.
	black_hole.set_meta("radius", radius)
	black_hole.set_meta("pull_strength", pull_strength)

	_create_black_hole_visual(
		black_hole,
		radius
	)

	_run_black_hole(
		black_hole,
		duration,
		radius,
		pull_strength,
		explosion_damage
	)


	
func _run_black_hole(
	black_hole: Node2D,
	duration: float,
	radius: float,
	pull_strength: float,
	explosion_damage: float
) -> void:
	var elapsed := 0.0

	while elapsed < duration:
		if not is_instance_valid(black_hole):
			return

		var delta := get_process_delta_time()

		_pull_enemies_to_black_hole(
			black_hole.global_position,
			radius,
			pull_strength,
			delta
		)

		elapsed += delta

		await get_tree().process_frame

	# Explosion
	_explode_black_hole(
		black_hole.global_position,
		radius,
		explosion_damage
	)

	black_hole.queue_free()
	
	
func _pull_enemies_to_black_hole(
	center: Vector2,
	radius: float,
	pull_strength: float,
	delta: float
) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D:
			continue

		var enemy_node := enemy as Node2D

		var distance := enemy_node.global_position.distance_to(center)

		if distance > radius:
			continue

		var direction := (
			center - enemy_node.global_position
		).normalized()

		# Stronger as the enemy gets closer.
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
		
func _explode_black_hole(
	center: Vector2,
	radius: float,
	damage: float
) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node2D:
			continue

		if enemy.global_position.distance_to(center) > radius:
			continue

		var hurt_box = enemy.get_node_or_null(
			"Components/HurtBox"
		)

		if hurt_box != null:
			hurt_box.take_damage(damage)

	_spawn_black_hole_explosion(
		center,
		radius
	)
	
func _create_black_hole_visual(
	black_hole: Node2D,
	radius: float
) -> void:
	# Outer gravitational ring
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
		var angle := TAU * float(i) / float(segments)

		outer_ring.add_point(
			Vector2(
				cos(angle),
				sin(angle)
			) * radius
		)

	black_hole.add_child(outer_ring)


	# Inner black core
	var core := Polygon2D.new()

	var points := PackedVector2Array()

	var core_radius := 20.0

	for i in range(32):
		var angle := TAU * float(i) / 32.0

		points.append(
			Vector2(
				cos(angle),
				sin(angle)
			) * core_radius
		)

	core.polygon = points
	core.color = Color(0.03, 0.01, 0.06, 1.0)

	black_hole.add_child(core)


	# Make the core pulse.
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
	
func _spawn_black_hole_explosion(
	position: Vector2,
	radius: float
) -> void:
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
		var angle := TAU * float(i) / float(segments)

		ring.add_point(
			Vector2(
				cos(angle),
				sin(angle)
			) * radius
		)

	get_tree().current_scene.add_child(ring)

	ring.global_position = position
	ring.scale = Vector2(0.15, 0.15)

	var tween := ring.create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector2.ONE,
		0.18
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		ring,
		"modulate:a",
		0.0,
		0.30
	)

	tween.chain().tween_callback(
		ring.queue_free
	)

	

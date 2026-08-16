class_name Player
extends CharacterBody2D

@export var muzzle_offset: float = 30.0  # distance from player center to spawn point

@export_category("Attack")
@export var fire_rate: float = 0.3  # seconds between shots

@export_category("Speed")
@export var move_speed: float = 250.0

@export_category("Dash")
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.75

var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: Vector2
var dash_cooldown_remaining: float = 0.0

@onready var hurt_box: HurtboxComponent = $Components/HurtBox


var projectile_scene: PackedScene = preload("res://scenes/projectiles/playerbullet/playerbullet.tscn")
var time_since_last_shot: float = 0.0

const GameOverScene := preload("res://scenes/UI/game_over.tscn")

@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var health_bar: ProgressBar = $HealthBar/HealthBar
@onready var dash_cooldown_bar: ProgressBar = $EnergyBar/EnergyBar
func _ready() -> void:
	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.current_health

	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)

	dash_cooldown_bar.min_value = 0.0
	dash_cooldown_bar.max_value = 1.0
	dash_cooldown_bar.value = 1.0


func _on_health_changed(current_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health


func _on_died() -> void:
	var game_over := GameOverScene.instantiate()
	# Parented under current_scene (not root) so it's actually destroyed when
	# Start Over reloads the scene - a root-level child survives a scene reload.
	get_tree().current_scene.add_child(game_over)
	get_tree().paused = true


func _physics_process(delta: float) -> void:
	if is_dashing:
		velocity = dash_direction * dash_speed
	else:
		var direction := Input.get_vector(
			"move_left",
			"move_right",
			"move_up",
			"move_down"
		)

		velocity = direction * move_speed

		if Input.is_action_just_pressed("dash"):
			start_dash()

	move_and_slide()


	# Dash cooldown
	if dash_cooldown_remaining > 0.0:
		dash_cooldown_remaining -= delta

		if dash_cooldown_remaining <= 0.0:
			dash_cooldown_remaining = 0.0
			can_dash = true

	dash_cooldown_bar.value = 1.0 - (
		dash_cooldown_remaining / dash_cooldown
	)


	# Shooting
	time_since_last_shot += delta

	if Input.is_action_pressed("shoot") and time_since_last_shot >= fire_rate:
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

	await get_tree().create_timer(dash_duration).timeout

	is_dashing = false
	health_component.invulnerable = false

	dash_cooldown_remaining = dash_cooldown
	
func shoot() -> void:
	var proj: PlayerProjectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	var aim_direction := (get_global_mouse_position() - global_position).normalized()
	var spawn_position := global_position + aim_direction * muzzle_offset
	proj.launch(spawn_position, aim_direction)
	
func apply_upgrade(upgrade: ShopUpgrade) -> void:
	match upgrade.type:

		ShopUpgrade.UpgradeType.MAX_HEALTH:
			health_component.max_health += upgrade.amount
			health_component.current_health += upgrade.amount

		ShopUpgrade.UpgradeType.MOVE_SPEED:
			move_speed += upgrade.amount

		ShopUpgrade.UpgradeType.DAMAGE:
			# We'll hook this into projectile damage
			# depending on where you're currently storing it.
			pass

		ShopUpgrade.UpgradeType.FIRE_RATE:
			fire_rate *= 1.0 - upgrade.amount

		ShopUpgrade.UpgradeType.DASH_COOLDOWN:
			dash_cooldown = max(
				0.1,
				dash_cooldown - upgrade.amount
			)

	print("Bought upgrade: ", upgrade.upgrade_name)

class_name Player
extends CharacterBody2D

@export var muzzle_offset: float = 30.0  # distance from player center to spawn point

@export_category("Attack")
@export var damage: float = 5.0
@export var fire_rate: float = 0.3

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
@onready var sprite: AnimatedSprite2D = $Sprite2D

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

	proj.damage = damage

	get_tree().current_scene.add_child(proj)

	var aim_direction := (
		get_global_mouse_position() - global_position
	).normalized()

	var spawn_position := global_position + aim_direction * muzzle_offset

	proj.launch(spawn_position, aim_direction)
	sprite.speed_scale = ATTACK_ANIM_BASE_DURATION / maxf(fire_rate, 0.05)
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
	match upgrade.type:

		ShopUpgrade.UpgradeType.MAX_HEALTH:
			health_component.increase_max_health(upgrade.amount)
	
		ShopUpgrade.UpgradeType.MOVE_SPEED:
			move_speed += upgrade.amount

		ShopUpgrade.UpgradeType.DAMAGE:
			damage += upgrade.amount

		ShopUpgrade.UpgradeType.FIRE_RATE:
			fire_rate *= 1.0 - upgrade.amount

		ShopUpgrade.UpgradeType.DASH_COOLDOWN:
			dash_cooldown = max(
				0.1,
				dash_cooldown - upgrade.amount
			)

	print("Bought upgrade: ", upgrade.upgrade_name)

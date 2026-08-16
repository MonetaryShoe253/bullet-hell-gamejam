class_name Enemy
extends CharacterBody2D

@export var fire_rate: float = 1.0  # seconds between shots
@export var move_speed: float = 250.0
@export var preferred_distance: float = 150.0
@export var distance_tolerance: float = 20.0
@export var projectile_damage: float = 5.0
@export var money_reward: int = 5
@export var player: Node2D  # reference to the player, set this however you're tracking it

var projectile_scene := preload("res://scenes/projectiles/enemybullet/enemybullet.tscn")

## Both the drone (Sprite2D) and the slime variants (AnimatedSprite2D) name
## their visual node "Sprite2D" so this script can stay agnostic of which.
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


## Applies the stats the spawner decided for this enemy (base stats scaled by
## GameState's level curve). Call after add_child() - this relies on the
## @onready refs above, and configure()'ing fire_rate needs _fire_timer to
## already exist.
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


func _physics_process(_delta: float) -> void:
	if can_see_player():
		_mirror_player_movement()
	else:
		velocity = Vector2.ZERO
		move_and_slide()

func can_see_player() -> bool:
	if player == null:
		return false

	var ray := $PlayerSight as RayCast2D

	ray.target_position = ray.to_local(player.global_position)
	ray.force_raycast_update()

	return ray.is_colliding() and ray.get_collider() == player

func fire_at_player() -> void:
	if player == null:
		return
	if not can_see_player():
		return
	var proj: EnemyProjectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	var dir := (player.global_position - global_position).normalized()
	proj.damage = projectile_damage
	proj.launch(global_position, dir)
	proj.hit_player.connect(_on_projectile_hit_player)

func _on_projectile_hit_player(player: Node2D) -> void:
	pass

func _mirror_player_movement() -> void:
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

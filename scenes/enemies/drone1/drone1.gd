extends CharacterBody2D   # changed from Node2D — needed for velocity/move_and_slide

@export var fire_rate: float = 1.0  # seconds between shots
@export var move_speed: float = 250.0
@export var preferred_distance: float = 300.0
@export var distance_tolerance: float = 20.0

var projectile_scene := preload("res://scenes/projectiles/enemybullet/enemybullet.tscn")
@export var player: Node2D  # reference to the player, set this however you're tracking it

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = fire_rate
	timer.timeout.connect(fire_at_player)
	add_child(timer)
	timer.start()

func _physics_process(_delta: float) -> void:
	_mirror_player_movement()

func fire_at_player() -> void:
	if player == null:
		return
	var proj: EnemyProjectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	var dir := (player.global_position - global_position).normalized()
	proj.launch(global_position, dir)
	proj.hit_player.connect(_on_projectile_hit_player)

func _on_projectile_hit_player(player: Node2D) -> void:
	print("Player hit!")

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

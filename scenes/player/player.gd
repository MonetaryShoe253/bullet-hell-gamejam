class_name Player
extends CharacterBody2D

@export var move_speed: float = 250.0
var projectile_scene: PackedScene = preload("res://scenes/projectiles/playerbullet/playerbullet.tscn")

@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var health_bar: ProgressBar = $HUD/HealthBar

func _ready() -> void:
	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.current_health

	health_component.health_changed.connect(_on_health_changed)

func _on_health_changed(current_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	
func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	velocity = direction * move_speed
	move_and_slide()

	if Input.is_action_just_pressed("shoot"):
		shoot()

func shoot() -> void:
	var proj: PlayerProjectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	var aim_direction := get_global_mouse_position() - global_position
	proj.launch(global_position, aim_direction)

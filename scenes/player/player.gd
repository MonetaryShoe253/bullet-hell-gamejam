class_name Player
extends CharacterBody2D

@export var move_speed: float = 250.0
@export var muzzle_offset: float = 30.0  # distance from player center to spawn point
@export var fire_rate: float = 0.3  # seconds between shots

var projectile_scene: PackedScene = preload("res://scenes/projectiles/playerbullet/playerbullet.tscn")
var time_since_last_shot: float = 0.0

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)
	velocity = direction * move_speed
	move_and_slide()

	time_since_last_shot += delta

	if Input.is_action_pressed("shoot") and time_since_last_shot >= fire_rate:
		shoot()
		time_since_last_shot = 0.0

func shoot() -> void:
	var proj: PlayerProjectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	var aim_direction := (get_global_mouse_position() - global_position).normalized()
	var spawn_position := global_position + aim_direction * muzzle_offset
	proj.launch(spawn_position, aim_direction)

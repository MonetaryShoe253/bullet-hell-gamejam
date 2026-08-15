extends Node2D

@export var fire_rate: float = 1.5  # seconds between shots
var projectile_scene := preload("res://scenes/projectiles/bullet1/bullet1.tscn")
@export var player: Node2D  # reference to the player, set this however you're tracking it

func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = fire_rate
	timer.timeout.connect(fire_at_player)
	add_child(timer)
	timer.start()

func fire_at_player() -> void:
	if player == null:
		return
	var proj: Projectile = projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	var dir := (player.global_position - global_position).normalized()
	proj.launch(global_position, dir)
	proj.hit_player.connect(_on_projectile_hit_player)

func _on_projectile_hit_player(player: Node2D) -> void:
	print("Player hit!")

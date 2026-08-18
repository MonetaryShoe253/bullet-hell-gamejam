class_name BulletStormAbility
extends Ability

@export_category("Bullet Storm")
@export var projectile_scene: PackedScene = preload("res://scenes/projectiles/playerbullet/playerbullet.tscn")
@export var projectile_count: int = 24
@export var damage: float = 5.0
@export var speed: float = 500.0

func activate(caster: Node2D) -> void:
	for i in projectile_count:
		var angle := TAU * i / projectile_count
		var direction := Vector2.RIGHT.rotated(angle)

		var proj: PlayerProjectile = projectile_scene.instantiate()
		proj.damage = damage
		proj.speed = speed

		caster.get_tree().current_scene.add_child(proj)
		proj.launch(caster.global_position, direction)

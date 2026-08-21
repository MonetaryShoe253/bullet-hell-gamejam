class_name ShockwavePulseAbility
extends Ability

## Mirrors ExplodingBarrel's projectile-clear logic (see
## exploding_barrel.gd::_clear_projectiles()) - same "collect every
## PlayerProjectile/EnemyProjectile/DamageWave in the scene and check
## distance" sweep, just centred on the caster instead of a barrel. Purely
## defensive - no damage, just wipes the immediate area clean of incoming
## fire.
@export_category("Shockwave Pulse")
@export var clear_radius: float = 300.0

const ShockwaveScene := preload("res://scenes/dungeon/exploding_barrel/shockwave_vfx.tscn")


func activate(caster: Node2D) -> void:
	var origin := caster.global_position

	_clear_projectiles(caster, origin)

	var shockwave: Node2D = ShockwaveScene.instantiate()
	caster.get_tree().current_scene.add_child(shockwave)
	shockwave.global_position = origin
	shockwave.set_radius(clear_radius)


func _clear_projectiles(caster: Node2D, origin: Vector2) -> void:
	for node in caster.get_tree().current_scene.get_children():
		var is_projectile := (
			is_instance_of(node, PlayerProjectile)
			or is_instance_of(node, EnemyProjectile)
			or is_instance_of(node, DamageWave)
		)
		if not is_projectile:
			continue
		if not (node is Node2D):
			continue
		if (node.global_position - origin).length() <= clear_radius:
			node.queue_free()

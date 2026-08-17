extends StaticBody2D
## An interactable hazard: pop it with a player bullet and it detonates -
## damages the player/enemies caught in the blast, clears every projectile
## nearby, and plays a shockwave VFX.
##
## Reuses the same HurtBox/HealthComponent every other damageable thing in
## the game already uses. The "enemy" group tag (see the .tscn) is what lets
## the *existing, unmodified* PlayerProjectile code apply damage to it -
## playerbullet.gd already does "if body.is_in_group('enemy'):
## body.get_node('Components/HurtBox').take_damage(damage)" for anything its
## Area2D touches, so this barrel just needs to look like an enemy to that
## one check. No projectile or enemy script needed any changes for this to
## work.

const ShockwaveScene := preload("res://scenes/dungeon/exploding_barrel/shockwave_vfx.tscn")

@export var blast_radius: float = 100.0
@export var blast_damage: float = 45.0
## Deliberately much larger than blast_radius - "clear the room", not just
## the immediate blast, is the point of this ability.
@export var projectile_clear_radius: float = 550.0

@onready var health_component: HealthComponent = $Components/HealthComponent


func _ready() -> void:
	health_component.died.connect(_on_died)


## Runs synchronously inside HealthComponent.die(), before it queue_frees
## this node's owner - safe to read global_position/spawn siblings here,
## just don't rely on this node still existing after this call returns.
func _on_died() -> void:
	var origin := global_position
	var parent := get_parent()

	_damage_nearby(origin)
	_clear_projectiles(origin)

	var shockwave: Node2D = ShockwaveScene.instantiate()
	parent.add_child(shockwave)
	shockwave.global_position = origin


func _damage_nearby(origin: Vector2) -> void:
	var targets: Array = []
	targets.append_array(get_tree().get_nodes_in_group("player"))
	targets.append_array(get_tree().get_nodes_in_group("enemy"))

	for target in targets:
		if target == self or not is_instance_valid(target) or not (target is Node2D):
			continue
		var dist: float = (target.global_position - origin).length()
		if dist > blast_radius:
			continue
		var hurt_box: Node = target.get_node_or_null("Components/HurtBox")
		if hurt_box:
			var falloff: float = 1.0 - (dist / blast_radius)
			hurt_box.take_damage(blast_damage * falloff)


func _clear_projectiles(origin: Vector2) -> void:
	for node in get_tree().current_scene.get_children():
		var is_projectile := (
			is_instance_of(node, PlayerProjectile)
			or is_instance_of(node, EnemyProjectile)
			or is_instance_of(node, DamageWave)
		)
		if not is_projectile:
			continue
		if not (node is Node2D):
			continue
		if (node.global_position - origin).length() <= projectile_clear_radius:
			node.queue_free()

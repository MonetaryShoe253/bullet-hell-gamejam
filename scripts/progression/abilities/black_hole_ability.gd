class_name BlackHoleAbility
extends Ability

@export_category("Black Hole")

@export var duration: float = 2.0
@export var radius: float = 220.0
@export var pull_strength: float = 350.0
@export var explosion_damage: float = 30.0


func activate(player: Node2D) -> void:
	var target_position := player.get_global_mouse_position()

	player.create_black_hole(
		target_position,
		duration,
		radius,
		pull_strength,
		explosion_damage
	)

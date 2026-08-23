class_name BlackHoleAbility
extends Ability

@export_category("Black Hole")

@export var duration: float = 2.0
@export var radius: float = 220.0
@export var pull_strength: float = 350.0
@export var explosion_damage: float = 30.0


func activate(player: Node2D) -> void:
	var black_hole := BlackHoleController.new()

	player.get_tree().current_scene.add_child(black_hole)

	black_hole.setup(
		player.get_global_mouse_position(),
		duration,
		radius,
		pull_strength,
		explosion_damage
	)

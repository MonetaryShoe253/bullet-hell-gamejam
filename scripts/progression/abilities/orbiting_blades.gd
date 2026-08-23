class_name OrbitingBladesAbility
extends Ability

@export_category("Orbiting Blades")

@export var duration: float = 5.0
@export var blade_count: int = 4
@export var orbit_radius: float = 75.0
@export var rotation_speed: float = 3.5
@export var damage: float = 12.0
@export var hit_radius: float = 18.0
@export var hit_cooldown: float = 0.4


func activate(player: Node2D) -> void:
	var actual_player := player as Player

	if actual_player == null:
		return

	var controller := OrbitingBladesController.new()

	player.get_tree().current_scene.add_child(controller)

	controller.setup(
		actual_player,
		duration,
		blade_count,
		orbit_radius,
		rotation_speed,
		damage,
		hit_radius,
		hit_cooldown
	)

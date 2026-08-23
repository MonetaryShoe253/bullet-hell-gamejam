class_name DamageDashAbility
extends Ability

@export_category("Damage Dash")

@export var damage_multiplier: float = 1.0
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.15
@export var hit_radius: float = 32.0
@export var post_invincibility_duration: float = 1.0


func activate(caster: Node2D) -> void:
	var player := caster as Player

	if player == null:
		return

	# Don't activate while another forced ability dash is active
	# or while the player is normal-dashing.
	if player.is_dashing or player.forced_movement_active:
		return

	var controller := DamageDashController.new()

	player.add_child(controller)

	controller.setup(
		player,
		player.stats.get_damage() * damage_multiplier,
		dash_speed,
		dash_duration,
		hit_radius,
		post_invincibility_duration
	)

class_name DamageDashAbility
extends Ability

@export_category("Damage Dash")
@export var damage_multiplier: float = 1.0  # 1.0 = the player's current damage stat, unmodified
@export var dash_speed: float = 800.0  # matches the regular dash's speed*duration, i.e. same distance
@export var dash_duration: float = 0.15
@export var hit_radius: float = 32.0  # a bit past the player's own hurtbox so the path has some width
@export var post_invincibility_duration: float = 1.0  # extra i-frames after the dash itself ends

func activate(caster: Node2D) -> void:
	var player := caster as Player
	if player == null:
		return

	player.perform_ability_dash(
		player.stats.get_damage() * damage_multiplier,
		dash_speed,
		dash_duration,
		hit_radius,
		post_invincibility_duration
	)

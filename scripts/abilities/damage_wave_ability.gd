class_name DamageWaveAbility
extends Ability

@export_category("Damage Wave")
@export var wave_scene: PackedScene = preload("res://scenes/abilities/damage_wave/damage_wave.tscn")
@export var angle_degrees: float = 30.0
@export var damage_multiplier: float = 2.5
@export var range_fraction: float = 0.3
@export var wave_duration: float = 0.25

func activate(caster: Node2D) -> void:
	var player := caster as Player
	if player == null:
		return

	var aim_direction := (
		caster.get_global_mouse_position() - caster.global_position
	).normalized()

	var wave: DamageWave = wave_scene.instantiate()
	caster.get_tree().current_scene.add_child(wave)

	wave.launch(
		caster.global_position,
		aim_direction,
		angle_degrees,
		player.stats.get_damage() * damage_multiplier,
		player.stats.get_projectile_range() * range_fraction,
		wave_duration
	)

class_name HurtboxComponent
extends Area2D

@export var health_component: HealthComponent


func take_damage(amount: float) -> void:	
	print("test")
	if health_component == null:
		push_warning("HurtboxComponent has no HealthComponent assigned.")
		return
	health_component.take_damage(amount)

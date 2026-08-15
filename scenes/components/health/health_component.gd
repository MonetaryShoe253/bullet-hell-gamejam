class_name HealthComponent
extends Node

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died

@export var max_health: float = 100.0

var current_health: float


func _ready() -> void:
	current_health = max_health


func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = max(current_health - amount, 0.0)

	print("Damage taken! New health: " + str(current_health))
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return

	var previous_health := current_health
	current_health = min(current_health + amount, max_health)

	var actual_healing := current_health - previous_health

	if actual_healing > 0.0:
		healed.emit(actual_healing)
		health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return current_health <= 0.0

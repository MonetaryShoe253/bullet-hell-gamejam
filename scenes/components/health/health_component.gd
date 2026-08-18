class_name HealthComponent
extends Node

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died

@export var max_health: float = 100.0

var current_health: float

var invulnerable: bool = false

func _ready() -> void:
	current_health = max_health

func increase_max_health(amount: float) -> void:
	if amount <= 0.0:
		return

	max_health += amount
	current_health += amount

	health_changed.emit(current_health, max_health)
	
func take_damage(amount: float) -> void:
	if invulnerable:
		return
		
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = max(current_health - amount, 0.0)

	print("Damage taken! New health: " + str(current_health))
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)

	if current_health <= 0.0:
		die()


func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return

	var previous_health := current_health
	current_health = min(current_health + amount, max_health)

	var actual_healing := current_health - previous_health

	if actual_healing > 0.0:
		healed.emit(actual_healing)
		health_changed.emit(current_health, max_health)

func die() -> void:
	if not is_dead():
		return
	died.emit()
	get_owner().queue_free()


func is_dead() -> bool:
	return current_health <= 0.0

class_name HealthComponent
extends Node

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died

## Fired the instant health would hit 0, before die() runs. A listener (e.g.
## Second Life) can revive() in response - take_damage() re-checks is_dead()
## right after, so a successful revive here cancels the death outright.
signal about_to_die

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
		about_to_die.emit()
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


## Restores health from 0, bypassing heal()'s "already dead" guard - used by
## revive effects (Second Life) that react to about_to_die.
func revive(amount: float) -> void:
	if amount <= 0.0:
		return

	current_health = min(amount, max_health)
	health_changed.emit(current_health, max_health)

func die() -> void:
	if not is_dead():
		return
	died.emit()


func is_dead() -> bool:
	return current_health <= 0.0

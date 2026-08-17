extends Node
## Autoload. Run-wide progress that survives dungeon regeneration between
## levels: money, current level, and the difficulty curve enemies are scaled
## against. Reset() is called by the "start over" flow after a game over.

signal money_changed(total: int)
signal level_changed(new_level: int)
signal enemy_killed

var money: int = 0
var level: int = 1


func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)
	
func spend_money(amount: int) -> bool:
	if amount <= 0:
		return false

	if money < amount:
		return false

	money -= amount
	money_changed.emit(money)

	return true


func advance_level() -> void:
	level += 1
	level_changed.emit(level)


func reset() -> void:
	money = 0
	level = 1
	money_changed.emit(money)
	level_changed.emit(level)


# --- Difficulty curve, read by EnemySpawner when it configures a fresh enemy.
# Health/damage climb faster than speed so a deep run feels tankier and harder
# hitting rather than just a blur - a fast, fragile swarm is a different kind
# of hard that the spawner's enemy count already covers.

func health_multiplier() -> float:
	return 1.0 + (level - 1) * 0.25


func damage_multiplier() -> float:
	return 1.0 + (level - 1) * 0.2


func speed_multiplier() -> float:
	return minf(1.0 + (level - 1) * 0.06, 1.6)


func money_multiplier() -> float:
	return 1.0 + (level - 1) * 0.15

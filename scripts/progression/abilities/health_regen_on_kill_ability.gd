class_name HealthRegenOnKillAbility
extends PassiveAbility

@export var heal_amount: float = 1.0

func equip(player: Player) -> void:
	GameState.enemy_killed.connect(_on_enemy_killed.bind(player))

func unequip(player: Player) -> void:
	var bound_callable := _on_enemy_killed.bind(player)
	if GameState.enemy_killed.is_connected(bound_callable):
		GameState.enemy_killed.disconnect(bound_callable)

func _on_enemy_killed(player: Player) -> void:
	player.health_component.heal(heal_amount)

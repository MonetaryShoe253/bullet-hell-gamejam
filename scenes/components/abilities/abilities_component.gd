class_name AbilityComponent
extends Node

signal cooldown_updated(index: int, remaining: float, total: float)
signal ability_used(index: int, ability: Ability)

@export var slots: Array[Ability] = []
@export var input_actions: Array[String] = ["ability 1", "ability 2"]

var _cooldowns: Array[float] = []

func _ready() -> void:
	_cooldowns.resize(slots.size())
	_cooldowns.fill(0.0)

func _process(delta: float) -> void:
	for i in slots.size():
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)
			var total := slots[i].cooldown if slots[i] else 1.0
			cooldown_updated.emit(i, _cooldowns[i], total)

func handle_input(caster: Node2D) -> void:
	for i in input_actions.size():
		if i < slots.size() and Input.is_action_just_pressed(input_actions[i]):
			try_activate(i, caster)

func try_activate(index: int, caster: Node2D) -> bool:
	if index < 0 or index >= slots.size():
		return false

	var ability := slots[index]
	if ability == null or _cooldowns[index] > 0.0:
		return false

	ability.activate(caster)
	_cooldowns[index] = ability.cooldown

	ability_used.emit(index, ability)
	cooldown_updated.emit(index, _cooldowns[index], ability.cooldown)
	return true

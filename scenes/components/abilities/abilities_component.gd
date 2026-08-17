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

## Puts ability into the first empty slot. Returns false if every slot is
## already filled, so the caller can fall back to storing it unequipped.
func equip_in_first_empty_slot(ability: Ability) -> bool:
	for i in slots.size():
		if slots[i] == null:
			slots[i] = ability
			_cooldowns[i] = 0.0
			return true
	return false

## Places ability into slot `index`, returning whatever was displaced (or
## null if it was empty). Used by the ability menu's equip flow, where the
## target slot is explicit rather than "first empty" - see
## equip_in_first_empty_slot() for that simpler case.
func equip_at(index: int, ability: Ability) -> Ability:
	if index < 0 or index >= slots.size():
		return null
	var displaced: Ability = slots[index]
	slots[index] = ability
	_cooldowns[index] = 0.0
	return displaced

## Empties slot `index`, returning whatever was in it (or null).
func unequip_at(index: int) -> Ability:
	if index < 0 or index >= slots.size():
		return null
	var ability: Ability = slots[index]
	slots[index] = null
	return ability

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

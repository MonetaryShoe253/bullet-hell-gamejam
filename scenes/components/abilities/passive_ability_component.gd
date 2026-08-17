class_name PassiveAbilityComponent
extends Node

@export var slots: Array[PassiveAbility] = []

func _ready() -> void:
	var player := get_owner() as Player
	for passive in slots:
		if passive:
			passive.equip(player)

## Mirrors _ready()'s equip pass - without this, a passive that hooks a
## persistent autoload signal (Health Regen connects to
## GameState.enemy_killed) would leave that connection dangling, pointing at
## a freed Player, every time the player is destroyed outside the normal
## equip menu flow (e.g. "Start Over" -> reload_current_scene()).
func _exit_tree() -> void:
	var player := get_owner() as Player
	for passive in slots:
		if passive:
			passive.unequip(player)

## Puts passive into the first empty slot and equips it immediately.
## Returns false if every slot is already filled, so the caller can fall
## back to storing it unequipped instead.
func equip_in_first_empty_slot(passive: PassiveAbility) -> bool:
	for i in slots.size():
		if slots[i] == null:
			slots[i] = passive
			passive.equip(get_owner() as Player)
			return true
	return false

## Places passive into slot `index`, unequipping whatever was displaced (if
## anything) and equipping the new one. Returns the displaced passive, or
## null if the slot was empty. Used by the ability menu's equip flow, where
## the target slot is explicit rather than "first empty".
func equip_at(index: int, passive: PassiveAbility) -> PassiveAbility:
	if index < 0 or index >= slots.size():
		return null
	var player := get_owner() as Player
	var displaced: PassiveAbility = slots[index]
	if displaced:
		displaced.unequip(player)
	slots[index] = passive
	passive.equip(player)
	return displaced

## Empties slot `index`, unequipping and returning whatever was in it.
func unequip_at(index: int) -> PassiveAbility:
	if index < 0 or index >= slots.size():
		return null
	var passive: PassiveAbility = slots[index]
	if passive:
		passive.unequip(get_owner() as Player)
	slots[index] = null
	return passive

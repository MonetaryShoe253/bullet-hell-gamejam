class_name InventoryComponent
extends Node

signal item_added(item: Item)
signal item_removed(item: Item)
signal equipment_changed()
signal ability_added(ability: Ability)
signal passive_ability_added(passive: PassiveAbility)

@export var max_inventory_size: int = 12

var items: Array[Item] = []

var equipped_armour: Item
var equipped_weapon: Item
var equipped_accessory: Item

## Abilities bought with no free AbilityComponent/PassiveAbilityComponent
## slot land here, owned but inactive, until manually equipped elsewhere.
var abilities: Array[Ability] = []
var passive_abilities: Array[PassiveAbility] = []

func add_ability(ability: Ability) -> void:
	abilities.append(ability)
	ability_added.emit(ability)

func add_passive_ability(passive: PassiveAbility) -> void:
	passive_abilities.append(passive)
	passive_ability_added.emit(passive)

func add_item(item: Item) -> bool:
	if items.size() >= max_inventory_size:
		print("Inventory full!")
		return false

	items.append(item)
	item_added.emit(item)

	print("Picked up: ", item.item_name)

	return true
	
func remove_item(item: Item) -> void:
	if not item in items:
		return

	items.erase(item)
	item_removed.emit(item)
	
func equip(item: Item) -> void:
	if not item in items:
		return

	match item.item_type:
		Item.ItemType.ARMOUR:
			equipped_armour = item

		Item.ItemType.WEAPON:
			equipped_weapon = item

		Item.ItemType.ACCESSORY:
			equipped_accessory = item

	equipment_changed.emit()
	
func unequip(item: Item) -> void:
	if equipped_armour == item:
		equipped_armour = null

	if equipped_weapon == item:
		equipped_weapon = null

	if equipped_accessory == item:
		equipped_accessory = null

	equipment_changed.emit()

class_name SavedBuildLoader
extends RefCounted

## Call once from Player._ready(), after all @onready component references exist.
static func apply_to_player(player: Player) -> void:
	_apply_items(player)
	_apply_active_abilities(player)
	_apply_passive_abilities(player)


static func _apply_items(player: Player) -> void:
	var inventory := player.inventory

	var weapon := ContentDatabase.find_item(
		MetaProgression.equipped_weapon_id
	)
	var armour := ContentDatabase.find_item(
		MetaProgression.equipped_armour_id
	)
	var accessory := ContentDatabase.find_item(
		MetaProgression.equipped_accessory_id
	)

	if weapon:
		inventory.add_item(weapon)
		inventory.equip(weapon)

	if armour:
		inventory.add_item(armour)
		inventory.equip(armour)

	if accessory:
		inventory.add_item(accessory)
		inventory.equip(accessory)

	player._on_equipment_changed()


static func _apply_active_abilities(player: Player) -> void:
	var component := player.ability_component
	var inventory := player.inventory

	# Clear authored/default state.
	for i in range(component.slots.size()):
		component.unequip_at(i)

	inventory.abilities.clear()

	var first := ContentDatabase.find_active_ability(
		MetaProgression.equipped_active_1_id
	)
	var second := ContentDatabase.find_active_ability(
		MetaProgression.equipped_active_2_id
	)

	if first and component.slots.size() > 0:
		component.equip_at(0, first)

	if second and component.slots.size() > 1:
		component.equip_at(1, second)


static func _apply_passive_abilities(player: Player) -> void:
	var component := player.passive_ability_component
	var inventory := player.inventory

	# Clear authored/default state.
	for i in range(component.slots.size()):
		component.unequip_at(i)

	inventory.passive_abilities.clear()

	var first := ContentDatabase.find_passive_ability(
		MetaProgression.equipped_passive_1_id
	)
	var second := ContentDatabase.find_passive_ability(
		MetaProgression.equipped_passive_2_id
	)

	if first and component.slots.size() > 0:
		component.equip_at(0, first)

	if second and component.slots.size() > 1:
		component.equip_at(1, second)

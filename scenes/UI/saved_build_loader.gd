class_name SavedBuildLoader
extends RefCounted

## Call once from Player._ready(), after all @onready component references exist.
static func apply_to_player(player: Player) -> void:
	_apply_items(player)
	_apply_active_abilities(player)
	# Passive resources are currently embedded subresources in player.tscn.
	# Keep those authored defaults for now. Once passive abilities are moved
	# into .tres resources, add them to ContentDatabase and resolve them here.
	player.passive_ability_component.equip_all()


static func _apply_items(player: Player) -> void:
	var inventory := player.inventory

	# Make every permanently unlocked item available in the run inventory.
	for item in ContentDatabase.ITEMS:
		if MetaProgression.is_unlocked(item) and not item in inventory.items:
			inventory.add_item(item)

	var weapon := ContentDatabase.find_item(MetaProgression.equipped_weapon_id)
	var armour := ContentDatabase.find_item(MetaProgression.equipped_armour_id)
	var accessory := ContentDatabase.find_item(MetaProgression.equipped_accessory_id)

	if weapon:
		inventory.equip(weapon)
	if armour:
		inventory.equip(armour)
	if accessory:
		inventory.equip(accessory)

	# Forces StatsComponent to receive the final saved equipment even when
	# nothing was selected yet.
	player._on_equipment_changed()


static func _apply_active_abilities(player: Player) -> void:
	var component := player.ability_component
	var inventory := player.inventory

	# Clear authored active defaults before applying the saved build.
	for i in component.slots.size():
		component.unequip_at(i)

	var equipped: Array[Ability] = []
	var first := ContentDatabase.find_active_ability(MetaProgression.equipped_active_1_id)
	var second := ContentDatabase.find_active_ability(MetaProgression.equipped_active_2_id)

	if first and component.slots.size() > 0:
		component.equip_at(0, first)
		equipped.append(first)
	if second and component.slots.size() > 1:
		component.equip_at(1, second)
		equipped.append(second)

	# All other unlocked abilities become owned/unequipped.
	inventory.abilities.clear()
	for ability in ContentDatabase.get_unlocked_active_abilities():
		if not ability in equipped:
			inventory.add_ability(ability)

	player.ability_bars.refresh(component)

class_name SavedBuildLoader
extends RefCounted

## Call once from Player._ready(), after all @onready component references exist.
static func apply_to_player(player: Player) -> void:
	_apply_items(player)
	_apply_active_abilities(player)
	_apply_passive_abilities(player)


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


static func _apply_passive_abilities(player: Player) -> void:
	var component := player.passive_ability_component
	var inventory := player.inventory

	# player.tscn still contains authored/default passive resources (including
	# Second Life). Clear every runtime slot first so the main-menu saved build
	# is the only source of starting passives. Player._ready() calls equip_all()
	# after this loader, so effects are applied exactly once.
	for i in component.slots.size():
		component.unequip_at(i)

	var equipped: Array[PassiveAbility] = []
	var first := ContentDatabase.find_passive_ability(MetaProgression.equipped_passive_1_id)
	var second := ContentDatabase.find_passive_ability(MetaProgression.equipped_passive_2_id)

	if first and component.slots.size() > 0:
		component.equip_at(0, first)
		equipped.append(first)
	if second and component.slots.size() > 1:
		component.equip_at(1, second)
		equipped.append(second)

	# Unlocked but unequipped passives are available in the run backpack.
	inventory.passive_abilities.clear()
	for passive: PassiveAbility in ContentDatabase.get_unlocked_passive_abilities():
		if passive not in equipped:
			inventory.passive_abilities.append(passive)

class_name InventoryUI
extends Control

enum View { GEAR, ABILITIES }

var player: Player
var inventory: InventoryComponent
var ability_component: AbilityComponent
var passive_component: PassiveAbilityComponent

var selected_item: Item = null
var selected_ability: Ability = null
var selected_passive: PassiveAbility = null
var current_view := View.GEAR
var current_item_type := Item.ItemType.WEAPON
var target_active_slot := 0
var target_passive_slot := 0

@onready var close_button: Button = $Panel/VBox/Header/CloseButton
@onready var coin_label: Label = $Panel/VBox/Header/CoinLabel

@onready var weapons_button: Button = $Panel/VBox/Content/AvailablePanel/VBox/Filters/Weapons
@onready var armour_button: Button = $Panel/VBox/Content/AvailablePanel/VBox/Filters/Armour
@onready var accessories_button: Button = $Panel/VBox/Content/AvailablePanel/VBox/Filters/Accessories
@onready var abilities_button: Button = $Panel/VBox/Content/AvailablePanel/VBox/Filters/Abilities
@onready var available_heading: Label = $Panel/VBox/Content/AvailablePanel/VBox/Heading
@onready var item_list: VBoxContainer = $Panel/VBox/Content/AvailablePanel/VBox/ItemScroll/ItemList

@onready var weapon_slot: Button = $Panel/VBox/Content/CenterPanel/VBox/GearGrid/WeaponSlot
@onready var armour_slot: Button = $Panel/VBox/Content/CenterPanel/VBox/GearGrid/ArmourSlot
@onready var accessory_slot: Button = $Panel/VBox/Content/CenterPanel/VBox/GearGrid/AccessorySlot
@onready var q_slot: Button = $Panel/VBox/Content/CenterPanel/VBox/AbilitiesRow/Q
@onready var e_slot: Button = $Panel/VBox/Content/CenterPanel/VBox/AbilitiesRow/E
@onready var passive_1_slot: Button = $Panel/VBox/Content/CenterPanel/VBox/AbilitiesRow/Passive1
@onready var passive_2_slot: Button = $Panel/VBox/Content/CenterPanel/VBox/AbilitiesRow/Passive2

@onready var details_heading: Label = $Panel/VBox/Content/DetailsPanel/VBox/Heading
@onready var details_icon: TextureRect = $Panel/VBox/Content/DetailsPanel/VBox/Icon
@onready var item_name_label: Label = $Panel/VBox/Content/DetailsPanel/VBox/ItemName
@onready var item_type_label: Label = $Panel/VBox/Content/DetailsPanel/VBox/Type
@onready var description_label: Label = $Panel/VBox/Content/DetailsPanel/VBox/Description
@onready var damage_label: Label = $Panel/VBox/Content/DetailsPanel/VBox/Stats/Damage
@onready var fire_rate_label: Label = $Panel/VBox/Content/DetailsPanel/VBox/Stats/FireRate
@onready var health_label: Label = $Panel/VBox/Content/DetailsPanel/VBox/Stats/Health
@onready var speed_label: Label = $Panel/VBox/Content/DetailsPanel/VBox/Stats/Speed
@onready var effect_title: Label = $Panel/VBox/Content/DetailsPanel/VBox/TraitTitle
@onready var effect_label: Label = $Panel/VBox/Content/DetailsPanel/VBox/Effect
@onready var equip_button: Button = $Panel/VBox/Content/DetailsPanel/VBox/EquipButton

@onready var hp_stat: Label = $Panel/VBox/StatsBar/HBox/HP
@onready var damage_stat: Label = $Panel/VBox/StatsBar/HBox/Damage
@onready var speed_stat: Label = $Panel/VBox/StatsBar/HBox/Speed
@onready var fire_rate_stat: Label = $Panel/VBox/StatsBar/HBox/FireRate
@onready var dash_stat: Label = $Panel/VBox/StatsBar/HBox/Dash

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	close_button.pressed.connect(close)

	weapons_button.pressed.connect(func(): _show_gear(Item.ItemType.WEAPON))
	armour_button.pressed.connect(func(): _show_gear(Item.ItemType.ARMOUR))
	accessories_button.pressed.connect(func(): _show_gear(Item.ItemType.ACCESSORY))
	abilities_button.pressed.connect(_show_abilities)

	weapon_slot.pressed.connect(func(): _show_gear(Item.ItemType.WEAPON))
	armour_slot.pressed.connect(func(): _show_gear(Item.ItemType.ARMOUR))
	accessory_slot.pressed.connect(func(): _show_gear(Item.ItemType.ACCESSORY))

	q_slot.pressed.connect(func(): _select_active_slot(0))
	e_slot.pressed.connect(func(): _select_active_slot(1))
	passive_1_slot.pressed.connect(func(): _select_passive_slot(0))
	passive_2_slot.pressed.connect(func(): _select_passive_slot(1))

	equip_button.pressed.connect(_on_action_pressed)
	visibility_changed.connect(_on_visibility_changed)

	hide()


func setup(target_player: Player) -> void:
	player = target_player
	inventory = player.inventory
	ability_component = player.ability_component
	passive_component = player.passive_ability_component

	if not inventory.item_added.is_connected(_on_item_inventory_changed):
		inventory.item_added.connect(_on_item_inventory_changed)
	if not inventory.item_removed.is_connected(_on_item_inventory_changed):
		inventory.item_removed.connect(_on_item_inventory_changed)
	if not inventory.equipment_changed.is_connected(_on_equipment_changed):
		inventory.equipment_changed.connect(_on_equipment_changed)
	if not inventory.ability_added.is_connected(_on_ability_inventory_changed):
		inventory.ability_added.connect(_on_ability_inventory_changed)
	if not inventory.passive_ability_added.is_connected(_on_passive_inventory_changed):
		inventory.passive_ability_added.connect(_on_passive_inventory_changed)
	if not player.stats.stats_changed.is_connected(_refresh_stats):
		player.stats.stats_changed.connect(_refresh_stats)

	_refresh_all()


func open() -> void:
	if player == null:
		push_warning("InventoryUI.open() called before setup(player).")
		return
	show()
	get_tree().paused = true
	_refresh_all()
	close_button.grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ability_menu"):
		close()
		get_viewport().set_input_as_handled()


func _on_visibility_changed() -> void:
	if not visible or player == null:
		return
	_refresh_all()


func _refresh_all() -> void:
	_refresh_money()
	_refresh_equipped()
	_refresh_stats()

	match current_view:
		View.GEAR:
			_show_gear(current_item_type)
		View.ABILITIES:
			_show_abilities()


# ---------------------------------------------------------------------------
# Gear
# ---------------------------------------------------------------------------

func _show_gear(type: Item.ItemType) -> void:
	if inventory == null:
		return

	current_view = View.GEAR
	current_item_type = type
	selected_ability = null
	selected_passive = null

	_set_tab_state()
	available_heading.text = _item_type_heading(type)
	_rebuild_item_list()
	_clear_details("SELECTED ITEM", "Choose an item from your backpack.")


func _rebuild_item_list() -> void:
	_clear_list()

	var matching_items: Array[Item] = []
	for item in inventory.items:
		if item.item_type == current_item_type:
			matching_items.append(item)

	for item in matching_items:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 82)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = _item_button_text(item)
		if item.icon:
			button.icon = item.icon
			button.expand_icon = true
		button.pressed.connect(func(): _select_item(item))
		item_list.add_child(button)

	if matching_items.is_empty():
		_add_empty_message("No %s in your backpack." % _item_type_heading(current_item_type).to_lower())


func _select_item(item: Item) -> void:
	selected_item = item
	selected_ability = null
	selected_passive = null

	details_heading.text = "SELECTED ITEM"
	details_icon.texture = item.icon
	item_name_label.text = item.item_name
	item_type_label.text = _item_type_name(item.item_type)
	description_label.text = item.description

	# Item already owns the canonical presentation of its modifiers in the
	# current project. Keep the redesign coupled to the Resource, not duplicate
	# its stat fields in UI code.
	damage_label.text = item.get_stats_text()
	fire_rate_label.text = ""
	health_label.text = ""
	speed_label.text = ""
	effect_title.text = "EQUIPMENT"
	effect_label.text = "Equipping this item immediately updates the player's runtime stats."

	var equipped := _is_equipped(item)
	equip_button.disabled = false
	equip_button.text = "UNEQUIP" if equipped else "EQUIP"


func _on_item_action() -> void:
	if selected_item == null:
		return

	if _is_equipped(selected_item):
		inventory.unequip(selected_item)
	else:
		inventory.equip(selected_item)

	_refresh_equipped()
	_refresh_stats()
	_rebuild_item_list()
	_select_item(selected_item)


func _is_equipped(item: Item) -> bool:
	return (
		inventory.equipped_weapon == item
		or inventory.equipped_armour == item
		or inventory.equipped_accessory == item
	)


# ---------------------------------------------------------------------------
# Abilities
# ---------------------------------------------------------------------------

func _show_abilities() -> void:
	if inventory == null:
		return

	current_view = View.ABILITIES
	selected_item = null
	_set_tab_state()
	available_heading.text = "OWNED ABILITIES"
	_rebuild_ability_list()
	_clear_details("SELECTED ABILITY", "Choose an equipped or backpack ability.")


func _rebuild_ability_list() -> void:
	_clear_list()

	var shown_active: Array[Ability] = []
	for i in ability_component.slots.size():
		var ability: Ability = ability_component.slots[i]
		if is_instance_valid(ability) and not ability in shown_active:
			shown_active.append(ability)
			_add_ability_button(ability, false, i)

	for ability: Ability in inventory.abilities:
		if not is_instance_valid(ability):
			continue
		if ability in shown_active:
			continue
		shown_active.append(ability)
		_add_ability_button(ability, false, -1)

	var shown_passive: Array[PassiveAbility] = []
	for i in passive_component.slots.size():
		var passive: PassiveAbility = passive_component.slots[i]
		if is_instance_valid(passive) and not passive in shown_passive:
			shown_passive.append(passive)
			_add_passive_button(passive, i)

	for passive: PassiveAbility in inventory.passive_abilities:
		if not is_instance_valid(passive):
			continue
		if passive in shown_passive:
			continue
		shown_passive.append(passive)
		_add_passive_button(passive, -1)

	if item_list.get_child_count() == 0:
		_add_empty_message("No abilities owned yet.")

func _add_ability_button(ability: Ability, _passive: bool, slot_index: int) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 76)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var location := "Q" if slot_index == 0 else ("E" if slot_index == 1 else "BACKPACK")
	button.text = "%s\n%s  •  Cooldown %.1fs" % [ability.ability_name, location, ability.cooldown]
	if ability.icon:
		button.icon = ability.icon
		button.expand_icon = true
	button.pressed.connect(func(): _select_ability(ability))
	item_list.add_child(button)


func _add_passive_button(passive: PassiveAbility, slot_index: int) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 76)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var location := "PASSIVE SLOT" if slot_index >= 0 else "BACKPACK"
	button.text = "%s\n%s" % [passive.ability_name, location]
	button.pressed.connect(func(): _select_passive(passive))
	item_list.add_child(button)


func _select_ability(ability: Ability) -> void:
	selected_item = null
	selected_passive = null
	selected_ability = ability

	details_heading.text = "SELECTED ABILITY"
	details_icon.texture = ability.icon
	item_name_label.text = ability.ability_name
	item_type_label.text = "ACTIVE ABILITY"
	description_label.text = ability.description
	damage_label.text = "COOLDOWN   %.1fs" % ability.cooldown
	fire_rate_label.text = ""
	health_label.text = ""
	speed_label.text = ""
	effect_title.text = "LOADOUT"
	effect_label.text = "Choose Q or E in the centre, then use the action button to equip this ability."
	equip_button.disabled = false

	var slot := _find_active_slot(ability)
	if slot >= 0:
		equip_button.text = "UNEQUIP FROM %s" % ("Q" if slot == 0 else "E")
	else:
		equip_button.text = "EQUIP TO %s" % ("Q" if target_active_slot == 0 else "E")


func _select_passive(passive: PassiveAbility) -> void:
	selected_item = null
	selected_ability = null
	selected_passive = passive

	details_heading.text = "SELECTED ABILITY"
	details_icon.texture = passive.icon if "icon" in passive else null
	item_name_label.text = passive.ability_name
	item_type_label.text = "PASSIVE ABILITY"
	description_label.text = passive.description
	damage_label.text = "Always active while equipped"
	fire_rate_label.text = ""
	health_label.text = ""
	speed_label.text = ""
	effect_title.text = "LOADOUT"
	effect_label.text = "Passive abilities occupy passive slots and cannot be placed in Q or E."
	equip_button.disabled = false
	equip_button.text = "UNEQUIP" if _find_passive_slot(passive) >= 0 else "EQUIP PASSIVE"


func _select_active_slot(index: int) -> void:
	target_active_slot = index
	_show_abilities()

	if index < ability_component.slots.size():
		var ability: Ability = ability_component.slots[index]
		if ability:
			_select_ability(ability)


func _select_passive_slot(index: int) -> void:
	target_passive_slot = index
	_show_abilities()

	if index < passive_component.slots.size():
		var passive: PassiveAbility = passive_component.slots[index]
		if passive:
			_select_passive(passive)


func _on_ability_action() -> void:
	if selected_ability:
		var existing_slot := _find_active_slot(selected_ability)
		if existing_slot >= 0:
			var removed := ability_component.unequip_at(existing_slot)
			if removed and not removed in inventory.abilities:
				inventory.abilities.append(removed)
		else:
			inventory.abilities.erase(selected_ability)
			var displaced := ability_component.equip_at(target_active_slot, selected_ability)
			if displaced and not displaced in inventory.abilities:
				inventory.abilities.append(displaced)
		player.ability_bars.refresh(ability_component)

	elif selected_passive:
		var existing_slot := _find_passive_slot(selected_passive)
		if existing_slot >= 0:
			var removed := passive_component.unequip_at(existing_slot)
			if removed and not removed in inventory.passive_abilities:
				inventory.passive_abilities.append(removed)
		else:
			inventory.passive_abilities.erase(selected_passive)
			var displaced := passive_component.equip_at(target_passive_slot, selected_passive)
			if displaced and not displaced in inventory.passive_abilities:
				inventory.passive_abilities.append(displaced)

	_refresh_equipped()
	_rebuild_ability_list()

	if selected_ability:
		_select_ability(selected_ability)
	elif selected_passive:
		_select_passive(selected_passive)


func _find_active_slot(ability: Ability) -> int:
	for i in ability_component.slots.size():
		if ability_component.slots[i] == ability:
			return i
	return -1


func _find_passive_slot(passive: PassiveAbility) -> int:
	for i in passive_component.slots.size():
		if passive_component.slots[i] == passive:
			return i
	return -1


# ---------------------------------------------------------------------------
# Stats / common UI
# ---------------------------------------------------------------------------

func _set_tab_state() -> void:
	weapons_button.disabled = current_view == View.GEAR and current_item_type == Item.ItemType.WEAPON
	armour_button.disabled = current_view == View.GEAR and current_item_type == Item.ItemType.ARMOUR
	accessories_button.disabled = current_view == View.GEAR and current_item_type == Item.ItemType.ACCESSORY
	abilities_button.disabled = current_view == View.ABILITIES
	equip_button.visible = true


func _refresh_equipped() -> void:
	if inventory == null:
		return

	weapon_slot.text = _equipment_text("WEAPON", inventory.equipped_weapon)
	armour_slot.text = _equipment_text("ARMOUR", inventory.equipped_armour)
	accessory_slot.text = _equipment_text("ACCESSORY", inventory.equipped_accessory)

	var q: Ability = ability_component.slots[0] if ability_component.slots.size() > 0 else null
	var e: Ability = ability_component.slots[1] if ability_component.slots.size() > 1 else null
	var passive_1: PassiveAbility = passive_component.slots[0] if passive_component.slots.size() > 0 else null
	var passive_2: PassiveAbility = passive_component.slots[1] if passive_component.slots.size() > 1 else null

	q_slot.text = "Q\n%s" % (q.ability_name if q else "Empty")
	e_slot.text = "E\n%s" % (e.ability_name if e else "Empty")
	passive_1_slot.text = "PASSIVE 1\n%s" % (passive_1.ability_name if passive_1 else "Empty")
	passive_2_slot.text = "PASSIVE 2\n%s" % (passive_2.ability_name if passive_2 else "Empty")
	_set_slot_icon(weapon_slot, inventory.equipped_weapon.icon if inventory.equipped_weapon else null)
	_set_slot_icon(armour_slot, inventory.equipped_armour.icon if inventory.equipped_armour else null)
	_set_slot_icon(accessory_slot, inventory.equipped_accessory.icon if inventory.equipped_accessory else null)
	_set_slot_icon(q_slot, q.icon if q else null)
	_set_slot_icon(e_slot, e.icon if e else null)


func _refresh_stats() -> void:
	if player == null:
		return

	hp_stat.text = "♥  MAX HP\n%.0f" % player.stats.get_max_health()
	damage_stat.text = "⚔  DAMAGE\n%.1f" % player.stats.get_damage()
	speed_stat.text = "»  SPEED\n%.0f" % player.stats.get_move_speed()
	fire_rate_stat.text = "➤  FIRE RATE\n%.2fs" % player.stats.get_fire_rate()
	dash_stat.text = "»  DASH CD\n%.2fs" % player.stats.get_dash_cooldown()


func _refresh_money() -> void:
	coin_label.text = "●  %s\nPLUCK COINS" % _format_number(GameState.money)


func _on_action_pressed() -> void:
	if selected_item:
		_on_item_action()
	elif selected_ability or selected_passive:
		_on_ability_action()


func _clear_details(title: String, message: String) -> void:
	selected_item = null
	selected_ability = null
	selected_passive = null
	details_heading.text = title
	details_icon.texture = null
	item_name_label.text = "NOTHING SELECTED"
	item_type_label.text = ""
	description_label.text = message
	damage_label.text = ""
	fire_rate_label.text = ""
	health_label.text = ""
	speed_label.text = ""
	effect_title.text = ""
	effect_label.text = ""
	equip_button.disabled = true
	equip_button.text = "SELECT SOMETHING"


func _clear_list() -> void:
	for child in item_list.get_children():
		child.queue_free()


func _add_empty_message(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 70)
	item_list.add_child(label)


func _equipment_text(slot_name: String, item: Item) -> String:
	return "%s\n%s" % [slot_name, item.item_name if item else "Empty"]


func _item_button_text(item: Item) -> String:
	var suffix := "  ✓ EQUIPPED" if _is_equipped(item) else ""
	return "%s%s\n%s" % [item.item_name, suffix, item.get_stats_text()]


func _item_type_heading(type: Item.ItemType) -> String:
	match type:
		Item.ItemType.WEAPON:
			return "AVAILABLE WEAPONS"
		Item.ItemType.ARMOUR:
			return "AVAILABLE ARMOUR"
		Item.ItemType.ACCESSORY:
			return "AVAILABLE ACCESSORIES"
	return "AVAILABLE ITEMS"


func _item_type_name(type: Item.ItemType) -> String:
	match type:
		Item.ItemType.WEAPON:
			return "WEAPON"
		Item.ItemType.ARMOUR:
			return "ARMOUR"
		Item.ItemType.ACCESSORY:
			return "ACCESSORY"
	return "ITEM"


func _set_slot_icon(button: Button, texture: Texture2D) -> void:
	button.icon = texture
	button.expand_icon = true


func _format_number(value: int) -> String:
	var text := str(maxi(value, 0))
	var output := ""
	var count := 0
	for index in range(text.length() - 1, -1, -1):
		if count == 3:
			output = "," + output
			count = 0
		output = text[index] + output
		count += 1
	return output


func _on_item_inventory_changed(_item: Item) -> void:
	if visible:
		_refresh_all()


func _on_ability_inventory_changed(_ability: Ability) -> void:
	if visible:
		_refresh_all()


func _on_passive_inventory_changed(_passive: PassiveAbility) -> void:
	if visible:
		_refresh_all()


func _on_equipment_changed() -> void:
	if visible:
		_refresh_equipped()
		_refresh_stats()
		if current_view == View.GEAR:
			_rebuild_item_list()

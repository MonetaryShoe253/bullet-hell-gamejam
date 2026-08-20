class_name InventoryUI
extends Control

var player: Player
var inventory: InventoryComponent

var selected_item: Item = null
var item_buttons: Array[Button] = []


@onready var item_grid: GridContainer = %ItemGrid

@onready var weapon_slot: Button = %WeaponSlot
@onready var armour_slot: Button = %ArmourSlot
@onready var accessory_slot: Button = %AccessorySlot

@onready var details_panel: PanelContainer = %DetailsPanel
@onready var item_name: Label = %ItemName
@onready var item_description: Label = %ItemDescription
@onready var item_stats: Label = %ItemStats

@onready var equip_button: Button = %EquipButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	equip_button.pressed.connect(_on_equip_pressed)
	visibility_changed.connect(_on_visibility_changed)
	
	weapon_slot.pressed.connect(
		func():
			_select_equipped(inventory.equipped_weapon)
	)

	armour_slot.pressed.connect(
		func():
			_select_equipped(inventory.equipped_armour)
	)

	accessory_slot.pressed.connect(
		func():
			_select_equipped(inventory.equipped_accessory)
	)
	hide()

func setup(target_player: Player) -> void:
	player = target_player
	inventory = player.inventory

	inventory.item_added.connect(_on_inventory_changed)
	inventory.item_removed.connect(_on_inventory_changed)
	inventory.equipment_changed.connect(_on_equipment_changed)

	_create_inventory_slots()
	_refresh()
	
func _create_inventory_slots() -> void:
	for child in item_grid.get_children():
		child.queue_free()

	item_buttons.clear()

	for i in range(inventory.max_inventory_size):
		var button := Button.new()

		button.custom_minimum_size = Vector2(100, 100)

		var slot_index := i

		button.pressed.connect(
			func():
				_on_item_slot_pressed(slot_index)
		)

		item_grid.add_child(button)
		item_buttons.append(button)
		
func _refresh() -> void:
	_refresh_inventory()
	_refresh_equipment()
	_refresh_details()
	
func _refresh_inventory() -> void:
	for i in range(item_buttons.size()):
		var button := item_buttons[i]

		if i < inventory.items.size():
			var item := inventory.items[i]

			button.disabled = false
			button.text = item.item_name

			if item.icon:
				button.icon = item.icon
			else:
				button.icon = null

		else:
			button.text = ""
			button.icon = null
			button.disabled = true
			
func _on_item_slot_pressed(index: int) -> void:
	if index >= inventory.items.size():
		return

	selected_item = inventory.items[index]

	_refresh_details()
	
	
func _refresh_details() -> void:
	if selected_item == null:
		details_panel.hide()
		return

	details_panel.show()

	item_name.text = selected_item.item_name
	item_description.text = selected_item.description
	item_stats.text = selected_item.get_stats_text()

	if _is_equipped(selected_item):
		equip_button.text = "UNEQUIP"
	else:
		equip_button.text = "EQUIP"
		
	
func _on_equip_pressed() -> void:
	if selected_item == null:
		return

	if _is_equipped(selected_item):
		inventory.unequip(selected_item)
	else:
		inventory.equip(selected_item)

	_refresh()
	
func _refresh_equipment() -> void:
	weapon_slot.text = _equipment_text(
		"WEAPON",
		inventory.equipped_weapon
	)

	armour_slot.text = _equipment_text(
		"ARMOUR",
		inventory.equipped_armour
	)

	accessory_slot.text = _equipment_text(
		"ACCESSORY",
		inventory.equipped_accessory
	)
	
func _equipment_text(slot_name: String, item: Item) -> String:
	if item == null:
		return slot_name + "\nEmpty"

	return slot_name + "\n" + item.item_name

func _select_equipped(item: Item) -> void:
	if item == null:
		return

	selected_item = item
	_refresh_details()
	
func _is_equipped(item: Item) -> bool:
	return (
		inventory.equipped_armour == item
		or inventory.equipped_weapon == item
		or inventory.equipped_accessory == item
	)

func _on_inventory_changed(_item: Item) -> void:
	_refresh()

func _on_equipment_changed() -> void:
	_refresh()

## Refreshes on show() as well as being called directly, so the panel is
## always current the moment it becomes visible - whether that's this scene
## being shown directly or a parent tab container switching to it.
##
## The inventory == null guard matters here specifically: TabContainer
## forces its current tab's `visible` to true as part of its own setup,
## which can fire this before setup() has ever been called - without the
## guard that's a crash on inventory.items with inventory still null.
func _on_visibility_changed() -> void:
	if not visible or inventory == null:
		return
	_refresh()

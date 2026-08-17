class_name AbilityMenuUI
extends CanvasLayer

enum Source { NONE, OWNED_ABILITY, OWNED_PASSIVE, ACTIVE_SLOT, PASSIVE_SLOT }

var player: Player
var ability_component: AbilityComponent
var passive_component: PassiveAbilityComponent
var inventory: InventoryComponent

var _selection_source: Source = Source.NONE
var _selection_index: int = -1
var _selected_ability: Ability = null
var _selected_passive: PassiveAbility = null

@onready var active_slot_buttons: Array[Button] = [%ActiveSlot1, %ActiveSlot2]
@onready var passive_slot_buttons: Array[Button] = [%PassiveSlot1, %PassiveSlot2]
@onready var owned_grid: GridContainer = %OwnedGrid
@onready var details_panel: PanelContainer = %DetailsPanel
@onready var ability_name_label: Label = %AbilityName
@onready var ability_description_label: Label = %AbilityDescription
@onready var ability_stats_label: Label = %AbilityStats
@onready var action_button: Button = %ActionButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	close_button.pressed.connect(close)
	action_button.pressed.connect(_on_action_pressed)

	for i in active_slot_buttons.size():
		var index := i
		active_slot_buttons[i].pressed.connect(func(): _on_active_slot_pressed(index))

	for i in passive_slot_buttons.size():
		var index := i
		passive_slot_buttons[i].pressed.connect(func(): _on_passive_slot_pressed(index))

	hide()


func setup(target_player: Player) -> void:
	player = target_player
	ability_component = player.ability_component
	passive_component = player.passive_ability_component
	inventory = player.inventory

	inventory.ability_added.connect(_on_inventory_changed)
	inventory.passive_ability_added.connect(_on_inventory_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_menu"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_clear_selection()
	_refresh()
	show()


func close() -> void:
	hide()


func _on_inventory_changed(_added: Resource) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_refresh_slots()
	_refresh_owned_grid()
	_refresh_details()


func _refresh_slots() -> void:
	for i in active_slot_buttons.size():
		var ability: Ability = (
			ability_component.slots[i] if i < ability_component.slots.size() else null
		)
		active_slot_buttons[i].text = (
			"ACTIVE %d\n%s" % [i + 1, ability.ability_name if ability else "Empty"]
		)

	for i in passive_slot_buttons.size():
		var passive: PassiveAbility = (
			passive_component.slots[i] if i < passive_component.slots.size() else null
		)
		passive_slot_buttons[i].text = (
			"PASSIVE %d\n%s" % [i + 1, passive.ability_name if passive else "Empty"]
		)


func _refresh_owned_grid() -> void:
	for child in owned_grid.get_children():
		child.queue_free()

	for ability in inventory.abilities:
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 70)
		button.text = ability.ability_name
		button.pressed.connect(func(): _on_owned_ability_pressed(ability))
		owned_grid.add_child(button)

	for passive in inventory.passive_abilities:
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 70)
		button.text = passive.ability_name + "\n(Passive)"
		button.pressed.connect(func(): _on_owned_passive_pressed(passive))
		owned_grid.add_child(button)


func _on_owned_ability_pressed(ability: Ability) -> void:
	_selection_source = Source.OWNED_ABILITY
	_selection_index = -1
	_selected_ability = ability
	_selected_passive = null
	_refresh_details()


func _on_owned_passive_pressed(passive: PassiveAbility) -> void:
	_selection_source = Source.OWNED_PASSIVE
	_selection_index = -1
	_selected_ability = null
	_selected_passive = passive
	_refresh_details()


func _on_active_slot_pressed(index: int) -> void:
	var ability: Ability = (
		ability_component.slots[index] if index < ability_component.slots.size() else null
	)
	if ability == null:
		return

	_selection_source = Source.ACTIVE_SLOT
	_selection_index = index
	_selected_ability = ability
	_selected_passive = null
	_refresh_details()


func _on_passive_slot_pressed(index: int) -> void:
	var passive: PassiveAbility = (
		passive_component.slots[index] if index < passive_component.slots.size() else null
	)
	if passive == null:
		return

	_selection_source = Source.PASSIVE_SLOT
	_selection_index = index
	_selected_ability = null
	_selected_passive = passive
	_refresh_details()


func _refresh_details() -> void:
	if _selection_source == Source.NONE:
		details_panel.hide()
		return

	details_panel.show()

	if _selected_ability:
		ability_name_label.text = _selected_ability.ability_name
		ability_description_label.text = _selected_ability.description
		ability_stats_label.text = "Cooldown: %.1fs" % _selected_ability.cooldown
	elif _selected_passive:
		ability_name_label.text = _selected_passive.ability_name
		ability_description_label.text = _selected_passive.description
		ability_stats_label.text = "Passive - always active once equipped"

	var is_slot := (
		_selection_source == Source.ACTIVE_SLOT
		or _selection_source == Source.PASSIVE_SLOT
	)
	action_button.text = "UNEQUIP" if is_slot else "EQUIP"


func _on_action_pressed() -> void:
	match _selection_source:
		Source.OWNED_ABILITY:
			_equip_ability(_selected_ability)
		Source.OWNED_PASSIVE:
			_equip_passive(_selected_passive)
		Source.ACTIVE_SLOT:
			_unequip_active(_selection_index)
		Source.PASSIVE_SLOT:
			_unequip_passive(_selection_index)

	_clear_selection()
	_refresh()


func _clear_selection() -> void:
	_selection_source = Source.NONE
	_selection_index = -1
	_selected_ability = null
	_selected_passive = null


## Fills the first empty active slot, or overwrites slot 0 if every slot is
## full - whatever gets displaced goes back into the owned pool rather than
## being lost.
func _equip_ability(ability: Ability) -> void:
	inventory.abilities.erase(ability)

	var index: int = ability_component.slots.find(null)
	if index == -1:
		index = 0

	var displaced := ability_component.equip_at(index, ability)
	if displaced:
		inventory.abilities.append(displaced)

	player.ability_bars.refresh(ability_component)


func _equip_passive(passive: PassiveAbility) -> void:
	inventory.passive_abilities.erase(passive)

	var index: int = passive_component.slots.find(null)
	if index == -1:
		index = 0

	var displaced := passive_component.equip_at(index, passive)
	if displaced:
		inventory.passive_abilities.append(displaced)


func _unequip_active(index: int) -> void:
	var ability := ability_component.unequip_at(index)
	if ability:
		inventory.abilities.append(ability)
		player.ability_bars.refresh(ability_component)


func _unequip_passive(index: int) -> void:
	var passive := passive_component.unequip_at(index)
	if passive:
		inventory.passive_abilities.append(passive)

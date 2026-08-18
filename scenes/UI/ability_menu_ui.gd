class_name AbilityMenuUI
extends CanvasLayer

## ACTIVE/PASSIVE can never swap with each other - a PassiveAbility can't go
## in an AbilityComponent slot or vice versa.
enum Kind { ACTIVE, PASSIVE }

## Where a selected resource currently lives - a fixed-index component slot,
## or the unordered "owned but unequipped" backpack list.
enum Place { SLOT, BACKPACK }

var player: Player
var ability_component: AbilityComponent
var passive_component: PassiveAbilityComponent
var inventory: InventoryComponent

var _has_selection: bool = false
var _sel_kind: Kind = Kind.ACTIVE
var _sel_place: Place = Place.SLOT
var _sel_index: int = -1  # meaningful only when _sel_place == SLOT
var _sel_resource: Resource = null  # the Ability/PassiveAbility currently picked up

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
	action_button.pressed.connect(_on_unequip_pressed)

	for i in active_slot_buttons.size():
		var index := i
		active_slot_buttons[i].pressed.connect(func(): _on_slot_pressed(Kind.ACTIVE, index))

	for i in passive_slot_buttons.size():
		var index := i
		passive_slot_buttons[i].pressed.connect(func(): _on_slot_pressed(Kind.PASSIVE, index))

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
		var selected := _has_selection and _sel_kind == Kind.ACTIVE and _sel_place == Place.SLOT and _sel_index == i
		active_slot_buttons[i].text = (
			("» " if selected else "")
			+ "ACTIVE %d\n%s" % [i + 1, ability.ability_name if ability else "Empty"]
		)

	for i in passive_slot_buttons.size():
		var passive: PassiveAbility = (
			passive_component.slots[i] if i < passive_component.slots.size() else null
		)
		var selected := _has_selection and _sel_kind == Kind.PASSIVE and _sel_place == Place.SLOT and _sel_index == i
		passive_slot_buttons[i].text = (
			("» " if selected else "")
			+ "PASSIVE %d\n%s" % [i + 1, passive.ability_name if passive else "Empty"]
		)


func _refresh_owned_grid() -> void:
	for child in owned_grid.get_children():
		child.queue_free()

	for ability in inventory.abilities:
		var selected := _has_selection and _sel_place == Place.BACKPACK and _sel_resource == ability
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 70)
		button.text = ("» " if selected else "") + ability.ability_name
		button.pressed.connect(func(): _on_owned_pressed(Kind.ACTIVE, ability))
		owned_grid.add_child(button)

	for passive in inventory.passive_abilities:
		var selected := _has_selection and _sel_place == Place.BACKPACK and _sel_resource == passive
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 70)
		button.text = ("» " if selected else "") + passive.ability_name + "\n(Passive)"
		button.pressed.connect(func(): _on_owned_pressed(Kind.PASSIVE, passive))
		owned_grid.add_child(button)


func _on_slot_pressed(kind: Kind, index: int) -> void:
	var component = ability_component if kind == Kind.ACTIVE else passive_component
	var resource: Resource = component.slots[index] if index < component.slots.size() else null
	_handle_click(kind, Place.SLOT, index, resource)


func _on_owned_pressed(kind: Kind, resource: Resource) -> void:
	_handle_click(kind, Place.BACKPACK, -1, resource)


## The whole interaction model: first click picks something up, a second
## click of the same kind swaps it with whatever's there (empty slot, filled
## slot, or a backpack entry - all handled the same way by _swap()).
## Clicking the exact same thing again cancels the pick.
func _handle_click(kind: Kind, place: Place, index: int, resource: Resource) -> void:
	if not _has_selection:
		if resource == null:
			return  # nothing to pick up
		_set_selection(kind, place, index, resource)
		return

	if _is_current_selection(kind, place, index, resource):
		_clear_selection()
		_refresh()
		return

	if kind != _sel_kind:
		# Active and passive can't swap with each other. Treat this as
		# "start a new pick" if they clicked something real, otherwise just
		# drop the pending selection.
		_clear_selection()
		if resource != null:
			_set_selection(kind, place, index, resource)
		else:
			_refresh()
		return

	_swap(place, index, resource)
	_clear_selection()
	_refresh()


func _is_current_selection(kind: Kind, place: Place, index: int, resource: Resource) -> bool:
	if not _has_selection or kind != _sel_kind or place != _sel_place:
		return false
	if place == Place.SLOT:
		return index == _sel_index
	return resource == _sel_resource


func _set_selection(kind: Kind, place: Place, index: int, resource: Resource) -> void:
	_has_selection = true
	_sel_kind = kind
	_sel_place = place
	_sel_index = index
	_sel_resource = resource
	_refresh()


func _clear_selection() -> void:
	_has_selection = false
	_sel_index = -1
	_sel_resource = null


## Swaps whatever is currently selected with the thing at (target_place,
## target_index, target_resource). Both sides can be empty, filled, or a
## backpack entry - every combination reduces to "each side's item, if any,
## moves to where the other one was".
func _swap(target_place: Place, target_index: int, target_resource: Resource) -> void:
	if _sel_place == Place.SLOT and target_place == Place.SLOT:
		_swap_slots(_sel_kind, _sel_index, target_index)
	elif _sel_place == Place.SLOT and target_place == Place.BACKPACK:
		_move_into_slot(_sel_kind, target_resource, _sel_index)
	elif _sel_place == Place.BACKPACK and target_place == Place.SLOT:
		_move_into_slot(_sel_kind, _sel_resource, target_index)
	# BACKPACK <-> BACKPACK: the backpack is unordered, nothing to change.


func _swap_slots(kind: Kind, a: int, b: int) -> void:
	if a == b:
		return

	# Untyped on purpose - AbilityComponent and PassiveAbilityComponent share
	# no common ancestor beyond Node, but both expose the same equip_at()/
	# unequip_at() shape, so this dispatches by duck typing at runtime.
	var component = ability_component if kind == Kind.ACTIVE else passive_component
	var item_a: Resource = component.unequip_at(a)
	var item_b: Resource = component.unequip_at(b)

	if item_b:
		component.equip_at(a, item_b)
	if item_a:
		component.equip_at(b, item_a)

	if kind == Kind.ACTIVE:
		player.ability_bars.refresh(ability_component)


## Puts `resource` into slot `index`, pulling it out of the backpack first
## and returning whatever was displaced back into the backpack.
func _move_into_slot(kind: Kind, resource: Resource, index: int) -> void:
	var component = ability_component if kind == Kind.ACTIVE else passive_component
	var backpack: Array = inventory.abilities if kind == Kind.ACTIVE else inventory.passive_abilities

	backpack.erase(resource)
	var displaced: Resource = component.equip_at(index, resource)
	if displaced:
		backpack.append(displaced)

	if kind == Kind.ACTIVE:
		player.ability_bars.refresh(ability_component)


func _refresh_details() -> void:
	if not _has_selection:
		details_panel.hide()
		return

	details_panel.show()

	if _sel_kind == Kind.ACTIVE:
		var ability := _sel_resource as Ability
		ability_name_label.text = ability.ability_name
		ability_description_label.text = ability.description
		ability_stats_label.text = "Cooldown: %.1fs" % ability.cooldown
	else:
		var passive := _sel_resource as PassiveAbility
		ability_name_label.text = passive.ability_name
		ability_description_label.text = passive.description
		ability_stats_label.text = "Passive - always active once equipped"

	ability_description_label.text += (
		"\n\nClick another slot or owned ability to swap places, or click this again to cancel."
	)

	action_button.visible = _sel_place == Place.SLOT
	action_button.text = "UNEQUIP"


func _on_unequip_pressed() -> void:
	if not _has_selection or _sel_place != Place.SLOT:
		return

	if _sel_kind == Kind.ACTIVE:
		var removed := ability_component.unequip_at(_sel_index)
		if removed:
			inventory.abilities.append(removed)
			player.ability_bars.refresh(ability_component)
	else:
		var removed := passive_component.unequip_at(_sel_index)
		if removed:
			inventory.passive_abilities.append(removed)

	_clear_selection()
	_refresh()

class_name PlayerMenu
extends CanvasLayer

@onready var inventory_ui: InventoryUI = $InventoryUI


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true

	if inventory_ui == null:
		push_error("PlayerMenu: InventoryUI child is missing or does not have inventory_ui.gd attached.")
		return

	inventory_ui.hide()


func setup(player: Player) -> void:
	if inventory_ui == null:
		return
	inventory_ui.setup(player)


func _input(event: InputEvent) -> void:
	if inventory_ui == null:
		return

	if event.is_action_pressed("ability_menu"):
		if inventory_ui.visible:
			inventory_ui.close()
		else:
			inventory_ui.open()

		get_viewport().set_input_as_handled()

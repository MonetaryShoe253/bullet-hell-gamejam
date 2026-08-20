class_name PlayerMenu
extends CanvasLayer

const TAB_PATH := "CenterContainer/PanelContainer/MarginContainer/MainVBox/TabContainer"

@onready var close_button: Button = %CloseButton

@onready var inventory_tab: InventoryUI = $CenterContainer/PanelContainer/MarginContainer/MainVBox/TabContainer/Inventory
@onready var abilities_tab: AbilityMenuUI = $CenterContainer/PanelContainer/MarginContainer/MainVBox/TabContainer/Abilities
@onready var stats_tab: StatsMenu = $CenterContainer/PanelContainer/MarginContainer/MainVBox/TabContainer/Stats


func _ready() -> void:
	close_button.pressed.connect(hide)
	hide()


## Temporary toggle for testing - reuses the "ability_menu" action (Tab) since
## nothing else is listening to it anymore now that AbilityMenuUI's own input
## handling is gone. Revisit once we decide what R/Tab/C should each do (see
## Phase 5) - this may become its own dedicated action, or one of the
## existing three might become "open menu" while the others jump straight to
## a specific tab.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_menu"):
		visible = not visible
		get_viewport().set_input_as_handled()


func setup(player: Player) -> void:
	inventory_tab.setup(player)
	abilities_tab.setup(player)
	stats_tab.setup(player)

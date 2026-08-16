extends CanvasLayer
## Shown once, when the player's HealthComponent dies. Freezes the game
## (get_tree().paused) behind it - process_mode ALWAYS on this whole subtree
## is what lets the restart button still receive input while paused.

@onready var money_label: Label = $Panel/VBox/MoneyLabel
@onready var level_label: Label = $Panel/VBox/LevelLabel
@onready var restart_button: Button = $Panel/VBox/RestartButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	money_label.text = "Money collected: %d" % GameState.money
	level_label.text = "Level reached: %d" % GameState.level
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.grab_focus()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	GameState.reset()
	get_tree().reload_current_scene()

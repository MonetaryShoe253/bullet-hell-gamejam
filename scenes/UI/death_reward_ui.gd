class_name DeathRewardUI
extends CanvasLayer


var choices: Array[Resource] = []
var level_reached: int

var selected_reward_index: int = -1

signal finished

@onready var run_result: Label = %RunResult
@onready var reward_tier_label: Label = %RewardTier

@onready var buttons: Array[Button] = [
	%Reward1,
	%Reward2,
	%Reward3
]

func _ready() -> void:
	hide()

	%ConfirmButton.hide()

	for i in range(buttons.size()):
		var index := i

		buttons[i].pressed.connect(
			func():
				_select_reward(index)
		)

	%ConfirmButton.pressed.connect(_confirm_reward)

	print("Confirm button connected!")
		
func open(reached_level: int) -> void:
	level_reached = reached_level	
	
	selected_reward_index = -1
	%ConfirmButton.hide()

	choices = MetaProgression.get_unlock_choices(
		level_reached,
		3
	)

	run_result.text = (
		"Reached Floor "
		+ str(level_reached)
	)

	var tier := MetaProgression.get_reward_tier(
		level_reached
	)

	reward_tier_label.text = (
		"Reward Tier "
		+ str(tier)
	)
	
	if choices.is_empty():
		print("All content already unlocked!")

		# For now just skip the reward.
		_finish_reward_screen()
		return

	_update_buttons()

	show()

	get_tree().paused = true
	
func _update_buttons() -> void:
	for i in range(buttons.size()):
		var button := buttons[i]

		if i >= choices.size():
			button.hide()
			continue

		button.show()

		var reward := choices[i]

		if reward is Item:
			_setup_item_button(
				button,
				reward as Item
			)

		elif reward is ShopUpgrade:
			_setup_upgrade_button(
				button,
				reward as ShopUpgrade
			)

		if i == selected_reward_index:
			button.text = "✓ SELECTED\n\n" + button.text

func _confirm_reward() -> void:
	print("CONFIRM PRESSED")

	if selected_reward_index < 0:
		print("No reward selected!")
		return

	if selected_reward_index >= choices.size():
		print("Invalid reward index!")
		return

	var reward := choices[selected_reward_index]

	print("Attempting unlock: ", reward.unlock_id)

	if not MetaProgression.unlock(reward):
		print("UNLOCK FAILED")
		return

	print("UNLOCK SUCCESS")

	_finish_reward_screen()
	
func _setup_item_button(
	button: Button,
	item: Item
) -> void:

	button.text = (
		item.item_name
		+ "\n\n"
		+ item.description
		+ "\n\n"
		+ item.get_stats_text()
	)

	button.icon = item.icon
	
	
func _setup_upgrade_button(
	button: Button,
	upgrade: ShopUpgrade
) -> void:

	button.icon = null

	button.text = (
		upgrade.upgrade_name
		+ "\n\n"
		+ upgrade.description
	)
	
func _select_reward(index: int) -> void:
	if index < 0 or index >= choices.size():
		return

	selected_reward_index = index

	_update_buttons()

	%ConfirmButton.show()
	
func _finish_reward_screen() -> void:
	print("EMITTING FINISHED")

	finished.emit()

	print("FINISHED EMITTED")

	queue_free()

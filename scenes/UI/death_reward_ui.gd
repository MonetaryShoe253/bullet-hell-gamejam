class_name DeathRewardUI
extends CanvasLayer

const MAIN_MENU_SCENE := "res://scenes/UI/main_menu.tscn"

var choices: Array[Resource] = []
var level_reached: int = 0
var selected_reward_index: int = -1

@onready var run_result: Label = %RunResult
@onready var reward_tier_label: Label = %RewardTier
@onready var coins_label: Label = %CoinsLabel
@onready var selection_hint: Label = %SelectionHint
@onready var confirm_button: Button = %ConfirmButton

@onready var cards: Array[PanelContainer] = [%Card1, %Card2, %Card3]
@onready var card_buttons: Array[Button] = [%Reward1, %Reward2, %Reward3]
@onready var card_icons: Array[TextureRect] = [%Icon1, %Icon2, %Icon3]
@onready var card_types: Array[Label] = [%Type1, %Type2, %Type3]
@onready var card_names: Array[Label] = [%Name1, %Name2, %Name3]
@onready var card_descriptions: Array[Label] = [%Description1, %Description2, %Description3]
@onready var card_stats: Array[Label] = [%Stats1, %Stats2, %Stats3]

signal finished

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	confirm_button.show()
	confirm_button.disabled = true
	confirm_button.text = "SELECT A REWARD TO UNLOCK"

	for i in range(card_buttons.size()):
		var index := i
		card_buttons[i].pressed.connect(func(): _select_reward(index))

	confirm_button.pressed.connect(_confirm_reward)


func open(reached_level: int) -> void:
	level_reached = reached_level
	selected_reward_index = -1
	confirm_button.show()
	confirm_button.disabled = true
	confirm_button.text = "SELECT A REWARD TO UNLOCK"
	selection_hint.text = "SELECT ONE PERMANENT STARTING-BUILD UNLOCK"

	choices = MetaProgression.get_unlock_choices(level_reached, 3)

	run_result.text = "REACHED FLOOR %d" % level_reached
	reward_tier_label.text = "REWARD TIER %d" % MetaProgression.get_reward_tier(level_reached)
	coins_label.text = "PLUCK COINS COLLECTED: %d" % GameState.money

	if choices.is_empty():
		_finish_reward_screen()
		return

	_update_cards()
	show()
	get_tree().paused = true


func _update_cards() -> void:
	for i in range(cards.size()):
		if i >= choices.size():
			cards[i].hide()
			continue

		cards[i].show()
		_populate_card(i, choices[i])

		if i == selected_reward_index:
			cards[i].add_theme_stylebox_override("panel", cards[i].get_theme_stylebox("selected"))
		else:
			cards[i].remove_theme_stylebox_override("panel")


func _populate_card(index: int, reward: Resource) -> void:
	card_icons[index].texture = _reward_icon(reward)
	card_types[index].text = _reward_type(reward)
	card_names[index].text = _reward_name(reward)
	card_descriptions[index].text = _reward_description(reward)
	card_stats[index].text = _reward_stats(reward)
	card_stats[index].visible = not card_stats[index].text.is_empty()


func _reward_icon(reward: Resource) -> Texture2D:
	if reward is Item:
		return (reward as Item).icon
	if reward is Ability:
		return (reward as Ability).icon
	if reward is PassiveAbility and "icon" in reward:
		return reward.icon
	return null


func _reward_type(reward: Resource) -> String:
	if reward is Item:
		match (reward as Item).item_type:
			Item.ItemType.WEAPON:
				return "WEAPON"
			Item.ItemType.ARMOUR:
				return "ARMOUR"
			Item.ItemType.ACCESSORY:
				return "ACCESSORY"
		return "ITEM"
	if reward is Ability:
		return "ACTIVE ABILITY"
	if reward is PassiveAbility:
		return "PASSIVE ABILITY"
	if reward is ShopUpgrade:
		return "UPGRADE"
	return "REWARD"


func _reward_name(reward: Resource) -> String:
	if reward is Item:
		return (reward as Item).item_name
	if reward is Ability:
		return (reward as Ability).ability_name
	if reward is PassiveAbility:
		return (reward as PassiveAbility).ability_name
	if reward is ShopUpgrade:
		return (reward as ShopUpgrade).upgrade_name
	return "Reward"


func _reward_description(reward: Resource) -> String:
	if reward is Item:
		return (reward as Item).description
	if reward is Ability:
		return (reward as Ability).description
	if reward is PassiveAbility:
		return (reward as PassiveAbility).description
	if reward is ShopUpgrade:
		return (reward as ShopUpgrade).description
	return ""


func _reward_stats(reward: Resource) -> String:
	if reward is Item:
		return (reward as Item).get_stats_text()
	if reward is Ability:
		return "Cooldown: %.1fs" % (reward as Ability).cooldown
	return ""


func _select_reward(index: int) -> void:
	if index < 0 or index >= choices.size():
		return

	selected_reward_index = index
	selection_hint.text = "SELECTED: %s" % _reward_name(choices[index]).to_upper()
	confirm_button.text = "UNLOCK %s" % _reward_name(choices[index]).to_upper()
	confirm_button.disabled = false
	_update_cards()


func _confirm_reward() -> void:
	if selected_reward_index < 0 or selected_reward_index >= choices.size():
		return

	var reward := choices[selected_reward_index]
	if not MetaProgression.unlock(reward):
		push_warning("Reward could not be unlocked: %s" % _reward_name(reward))
		return

	_finish_reward_screen()


func _finish_reward_screen() -> void:
	# MetaProgression.unlock() has already persisted the selected reward.
	# Unpause before replacing the dungeon so the main menu receives input.
	get_tree().paused = false

	# Clear run-local state/currency before returning to the build screen.
	GameState.reset()

	# This screen now owns the death -> main menu transition. Do not emit the
	# old `finished` signal here, as legacy game-over listeners can interfere.
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

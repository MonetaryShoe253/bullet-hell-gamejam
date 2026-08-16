class_name ShopUI
extends CanvasLayer

@export var available_upgrades: Array[ShopUpgrade]

var player: Player
var offered_upgrades: Array[ShopUpgrade]
var offers_generated: bool = false

@onready var money_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MoneyLabel

@onready var buttons: Array[Button] = [
	$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Upgrades/Upgrade1,
	$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Upgrades/Upgrade2,
	$CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Upgrades/Upgrade3
]

func _ready() -> void:
	hide()

	for i in buttons.size():
		buttons[i].pressed.connect(
			func(): _buy_upgrade(i)
		)

func _generate_offers() -> void:
	offered_upgrades.clear()

	var pool := available_upgrades.duplicate()
	pool.shuffle()

	var count := mini(3, pool.size())

	for i in count:
		offered_upgrades.append(pool[i])


func reset_shop() -> void:
	offers_generated = false
	offered_upgrades.clear()

	for button in buttons:
		button.disabled = false

	hide()	
	
func _update_ui() -> void:
	money_label.text = "Gold: " + str(GameState.money)

	for i in buttons.size():
		var button := buttons[i]

		if i >= offered_upgrades.size():
			button.hide()
			continue

		var upgrade := offered_upgrades[i]

		button.show()

		button.text = (
			upgrade.upgrade_name
			+ "\n"
			+ upgrade.description
			+ "\n\n"
			+ str(upgrade.price)
			+ " GOLD"
		)

func _buy_upgrade(index: int) -> void:
	var upgrade := offered_upgrades[index]

	if not GameState.spend_money(upgrade.price):
		print("Not enough money!")
		return

	player.apply_upgrade(upgrade)

	buttons[index].disabled = true
	_update_ui()
	
func open(target_player: Player) -> void:
	player = target_player

	if not offers_generated:
		_generate_offers()
		offers_generated = true

	_update_ui()
	show()
	
func close() -> void:
	hide()

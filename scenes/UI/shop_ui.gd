class_name ShopUI
extends CanvasLayer

@export var available_upgrades: Array[ShopUpgrade]

var player: Player
var offered_upgrades: Array[ShopUpgrade]

@onready var money_label: Label = $Panel/VBoxContainer/MoneyLabel

@onready var buttons: Array[Button] = [
	$Panel/VBoxContainer/Upgrades/Upgrade1,
	$Panel/VBoxContainer/Upgrades/Upgrade2,
	$Panel/VBoxContainer/Upgrades/Upgrade3
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

	_generate_offers()
	_update_ui()

	show()
	
func close() -> void:
	hide()

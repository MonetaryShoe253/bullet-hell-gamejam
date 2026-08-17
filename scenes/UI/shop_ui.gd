class_name ShopUI
extends CanvasLayer

@export var upgrade_pool: Array[ShopUpgrade]
@export var item_pool: Array[Item] = []

var player: Player
var offered_offers: Array[Resource] = []
var offers_generated: bool = false

var purchased_offers: Array[bool] = []

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
			func(): _buy_offer(i)
		)

func _generate_offers() -> void:
	if offers_generated:
		return

	offered_offers.clear()

	var available: Array[Resource] = []

	for upgrade in upgrade_pool:
		if MetaProgression.is_unlocked(upgrade):
			available.append(upgrade)

	for item in item_pool:
		if MetaProgression.is_unlocked(item):
			available.append(item)

	available.shuffle()

	var offer_count := mini(
		buttons.size(),
		available.size()
	)

	for i in range(offer_count):
		offered_offers.append(available[i])
	
	purchased_offers.clear()

	for i in range(offered_offers.size()):
		purchased_offers.append(false)

	offers_generated = true


func reset_shop() -> void:
	offers_generated = false
	offered_offers.clear()
	purchased_offers.clear()

	for button in buttons:
		button.disabled = false

	hide()
	
func _update_ui() -> void:
	money_label.text = "Gold: " + str(GameState.money)

	for i in range(buttons.size()):
		var button := buttons[i]

		if i >= offered_offers.size():
			button.hide()
			continue

		button.show()

		var offer := offered_offers[i]

		if purchased_offers[i]:
			button.disabled = true

			if offer is ShopUpgrade:
				button.text = (
					(offer as ShopUpgrade).upgrade_name
					+ "\n\nSOLD"
				)

			elif offer is Item:
				button.text = (
					(offer as Item).item_name
					+ "\n\nSOLD"
				)

			continue

		button.disabled = false

		if offer is ShopUpgrade:
			_setup_upgrade_button(
				button,
				offer as ShopUpgrade
			)

		elif offer is Item:
			_setup_item_button(
				button,
				offer as Item
			)

func _setup_upgrade_button(
	button: Button,
	upgrade: ShopUpgrade
) -> void:
	button.text = (
		upgrade.upgrade_name
		+ "\n\n"
		+ upgrade.description
		+ "\n\n"
		+ str(upgrade.price)
		+ " GOLD"
	)

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
		+ "\n\n"
		+ str(item.price)
		+ " GOLD"
	)

	button.icon = item.icon
				
func _buy_offer(index: int) -> void:
	if index < 0 or index >= offered_offers.size():
		return

	var offer := offered_offers[index]

	if offer is ShopUpgrade:
		_buy_upgrade(
			offer as ShopUpgrade,
			index
		)

	elif offer is Item:
		_buy_item(
			offer as Item,
			index
		)
	
func open(target_player: Player) -> void:
	player = target_player

	if not offers_generated:
		_generate_offers()

	_update_ui()
	show()

func _buy_upgrade(
	upgrade: ShopUpgrade,
	index: int
) -> void:
	if not GameState.spend_money(upgrade.price):
		print("Not enough gold!")
		return

	player.apply_upgrade(upgrade)

	purchased_offers[index] = true

	_update_ui()
	
func _buy_item(
	item: Item,
	index: int
) -> void:
	if player.inventory.items.size() >= player.inventory.max_inventory_size:
		print("Inventory full!")
		return

	if not GameState.spend_money(item.price):
		print("Not enough gold!")
		return

	if not player.inventory.add_item(item):
		GameState.add_money(item.price)
		return

	purchased_offers[index] = true

	_update_ui()
		
func close() -> void:
	hide()

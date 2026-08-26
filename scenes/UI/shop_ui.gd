class_name ShopUI
extends Control

@export var upgrade_pool: Array[ShopUpgrade]
@export var item_pool: Array[Item] = []
@export var ability_pool: Array[Ability] = []
@export var passive_pool: Array[PassiveAbility] = []

## The redesigned scene has a reroll button. Set this to 0 if a particular
## shop should not charge for rerolls.
@export var refresh_price: int = 50

var player: Player
var offered_offers: Array[Resource] = []
var offers_generated := false
var purchased_offers: Array[bool] = []

@onready var money_label: Label = $Panel/VBox/Header/CoinLabel
@onready var close_button: Button = $Panel/VBox/Header/CloseButton
@onready var refresh_button: Button = $Panel/VBox/Footer/HBox/RefreshButton
@onready var stock_timer_label: Label = $Panel/VBox/StockRow/Timer

@onready var offer_cards: Array[PanelContainer] = [
	$Panel/VBox/Offers/Offer1,
	$Panel/VBox/Offers/Offer2,
	$Panel/VBox/Offers/Offer3,
]

@onready var offer_icons: Array[TextureRect] = [
	$Panel/VBox/Offers/Offer1/VBox/Icon,
	$Panel/VBox/Offers/Offer2/VBox/Icon,
	$Panel/VBox/Offers/Offer3/VBox/Icon,
]

@onready var offer_names: Array[Label] = [
	$Panel/VBox/Offers/Offer1/VBox/Name,
	$Panel/VBox/Offers/Offer2/VBox/Name,
	$Panel/VBox/Offers/Offer3/VBox/Name,
]

@onready var offer_types: Array[Label] = [
	$Panel/VBox/Offers/Offer1/VBox/Type,
	$Panel/VBox/Offers/Offer2/VBox/Type,
	$Panel/VBox/Offers/Offer3/VBox/Type,
]

@onready var offer_descriptions: Array[Label] = [
	$Panel/VBox/Offers/Offer1/VBox/Description,
	$Panel/VBox/Offers/Offer2/VBox/Description,
	$Panel/VBox/Offers/Offer3/VBox/Description,
]

@onready var offer_stats: Array[Label] = [
	$Panel/VBox/Offers/Offer1/VBox/Stats,
	$Panel/VBox/Offers/Offer2/VBox/Stats,
	$Panel/VBox/Offers/Offer3/VBox/Stats,
]

@onready var buy_buttons: Array[Button] = [
	$Panel/VBox/Offers/Offer1/VBox/BuyButton,
	$Panel/VBox/Offers/Offer2/VBox/BuyButton,
	$Panel/VBox/Offers/Offer3/VBox/BuyButton,
]


func _ready() -> void:
	# Shop interaction should still work if the surrounding game pauses while
	# a shop is open.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	close_button.pressed.connect(close)
	refresh_button.pressed.connect(_refresh_stock)

	for i in buy_buttons.size():
		buy_buttons[i].pressed.connect(func(): _buy_offer(i))

	# The original shop has no timed refresh system. The mockup included a
	# timer visually, so hide it rather than inventing gameplay behind it.
	stock_timer_label.text = "3 OFFERS"
	hide()


# ---------------------------------------------------------------------------
# Existing shop offer generation logic
# ---------------------------------------------------------------------------

func _generate_offers() -> void:
	if offers_generated:
		return

	offered_offers.clear()
	var available: Array[Resource] = []

	# Upgrades and items respect permanent unlock progression, matching the
	# existing shop implementation.
	for upgrade in upgrade_pool:
		if MetaProgression.is_unlocked(upgrade):
			available.append(upgrade)

	for item in item_pool:
		if MetaProgression.is_unlocked(item) and not _player_owns_item(item):
			available.append(item)

	# Existing behaviour: active/passive abilities are purchasable in-run
	# without requiring the MetaProgression unlock gate, but owned abilities
	# cannot be offered again.
	for ability in ability_pool:
		if not _player_owns_ability(ability):
			available.append(ability)

	for passive in passive_pool:
		if not _player_owns_passive(passive):
			available.append(passive)

	available.shuffle()

	var offer_count := mini(buy_buttons.size(), available.size())
	for i in range(offer_count):
		offered_offers.append(available[i])

	purchased_offers.clear()
	for i in range(offered_offers.size()):
		purchased_offers.append(false)

	offers_generated = true


func _player_owns_item(item: Item) -> bool:
	if player == null:
		return false
	return item in player.inventory.items


func _player_owns_ability(ability: Ability) -> bool:
	if player == null:
		return false

	if ability in player.ability_component.slots or ability in player.inventory.abilities:
		return true

	# Preserve the old script's name fallback for resources embedded directly
	# in scenes rather than referencing the same .tres object.
	for owned: Ability in player.ability_component.slots:
		if owned and owned.ability_name == ability.ability_name:
			return true

	for owned: Ability in player.inventory.abilities:
		if owned.ability_name == ability.ability_name:
			return true

	return false


func _player_owns_passive(passive: PassiveAbility) -> bool:
	if player == null:
		return false

	if passive in player.passive_ability_component.slots or passive in player.inventory.passive_abilities:
		return true

	for owned: PassiveAbility in player.passive_ability_component.slots:
		if owned and owned.ability_name == passive.ability_name:
			return true

	for owned: PassiveAbility in player.inventory.passive_abilities:
		if owned.ability_name == passive.ability_name:
			return true

	return false


# ---------------------------------------------------------------------------
# New scene presentation
# ---------------------------------------------------------------------------

func _update_ui() -> void:
	money_label.text = "●  %s\nCLUCK COINS" % _format_number(GameState.money)
	refresh_button.text = "●  %s" % refresh_price
	refresh_button.disabled = GameState.money < refresh_price

	for i in range(offer_cards.size()):
		if i >= offered_offers.size():
			offer_cards[i].hide()
			continue

		offer_cards[i].show()
		var offer := offered_offers[i]

		if purchased_offers[i]:
			_show_sold_offer(i, offer)
			continue

		_populate_offer(i, offer)


func _populate_offer(index: int, offer: Resource) -> void:
	buy_buttons[index].disabled = false
	offer_icons[index].texture = null

	if offer is ShopUpgrade:
		_setup_upgrade_card(index, offer as ShopUpgrade)
	elif offer is Item:
		_setup_item_card(index, offer as Item)
	elif offer is Ability:
		_setup_ability_card(index, offer as Ability)
	elif offer is PassiveAbility:
		_setup_passive_card(index, offer as PassiveAbility)


func _setup_upgrade_card(index: int, upgrade: ShopUpgrade) -> void:
	offer_names[index].text = upgrade.upgrade_name.to_upper()
	offer_types[index].text = "RUN UPGRADE"
	offer_descriptions[index].text = upgrade.description
	offer_stats[index].text = "Applies immediately for the rest of this run."
	buy_buttons[index].text = "●  %s" % _format_number(upgrade.price)
	buy_buttons[index].disabled = GameState.money < upgrade.price


func _setup_item_card(index: int, item: Item) -> void:
	offer_names[index].text = item.item_name.to_upper()
	offer_types[index].text = _item_type_name(item.item_type)
	offer_descriptions[index].text = item.description
	offer_stats[index].text = item.get_stats_text()
	offer_icons[index].texture = item.icon
	buy_buttons[index].text = "●  %s" % _format_number(item.price)
	buy_buttons[index].disabled = GameState.money < item.price


func _setup_ability_card(index: int, ability: Ability) -> void:
	offer_names[index].text = ability.ability_name.to_upper()
	offer_types[index].text = "ACTIVE ABILITY"
	offer_descriptions[index].text = ability.description
	offer_stats[index].text = "Cooldown: %.1fs\n\nEquips to the first empty Q / E slot." % ability.cooldown
	offer_icons[index].texture = ability.icon
	buy_buttons[index].text = "●  %s" % _format_number(ability.price)
	buy_buttons[index].disabled = GameState.money < ability.price


func _setup_passive_card(index: int, passive: PassiveAbility) -> void:
	offer_names[index].text = passive.ability_name.to_upper()
	offer_types[index].text = "PASSIVE ABILITY"
	offer_descriptions[index].text = passive.description
	offer_stats[index].text = "Passive effect\n\nEquips to the first empty passive slot."
	offer_icons[index].texture = passive.icon
	buy_buttons[index].text = "●  %s" % _format_number(passive.price)
	buy_buttons[index].disabled = GameState.money < passive.price


func _show_sold_offer(index: int, offer: Resource) -> void:
	buy_buttons[index].disabled = true
	buy_buttons[index].text = "SOLD ✓"

	if offer is ShopUpgrade:
		_setup_sold_text(index, (offer as ShopUpgrade).upgrade_name)
	elif offer is Item:
		_setup_sold_text(index, (offer as Item).item_name)
	elif offer is Ability:
		_setup_sold_text(index, (offer as Ability).ability_name)
	elif offer is PassiveAbility:
		_setup_sold_text(index, (offer as PassiveAbility).ability_name)


func _setup_sold_text(index: int, display_name: String) -> void:
	offer_names[index].text = display_name.to_upper()
	offer_types[index].text = "PURCHASED"
	offer_descriptions[index].text = "Added to your build."
	offer_stats[index].text = ""


# ---------------------------------------------------------------------------
# Existing purchase behaviour
# ---------------------------------------------------------------------------

func _buy_offer(index: int) -> void:
	if index < 0 or index >= offered_offers.size():
		return
	if purchased_offers[index]:
		return

	var offer := offered_offers[index]

	if offer is ShopUpgrade:
		_buy_upgrade(offer as ShopUpgrade, index)
	elif offer is Item:
		_buy_item(offer as Item, index)
	elif offer is Ability:
		_buy_ability(offer as Ability, index)
	elif offer is PassiveAbility:
		_buy_passive_ability(offer as PassiveAbility, index)


func _buy_upgrade(upgrade: ShopUpgrade, index: int) -> void:
	if not GameState.spend_money(upgrade.price):
		print("Not enough gold!")
		return

	player.apply_upgrade(upgrade)
	purchased_offers[index] = true
	_update_ui()


func _buy_item(item: Item, index: int) -> void:
	if player.inventory.items.size() >= player.inventory.max_inventory_size:
		print("Inventory full!")
		return

	if not GameState.spend_money(item.price):
		print("Not enough gold!")
		return

	if not player.inventory.add_item(item):
		# Preserve the original refund behaviour if add_item fails.
		GameState.add_money(item.price)
		return

	purchased_offers[index] = true
	_update_ui()


func _buy_ability(ability: Ability, index: int) -> void:
	if not GameState.spend_money(ability.price):
		print("Not enough gold!")
		return

	# Preserve existing behaviour: auto-equip into an empty Q/E slot, otherwise
	# put it into the run inventory for the player to equip later.
	if player.ability_component.equip_in_first_empty_slot(ability):
		player.ability_bars.refresh(player.ability_component)
	else:
		player.inventory.add_ability(ability)

	purchased_offers[index] = true
	_update_ui()


func _buy_passive_ability(passive: PassiveAbility, index: int) -> void:
	if not GameState.spend_money(passive.price):
		print("Not enough gold!")
		return

	if not player.passive_ability_component.equip_in_first_empty_slot(passive):
		player.inventory.add_passive_ability(passive)

	purchased_offers[index] = true
	_update_ui()


# ---------------------------------------------------------------------------
# Open / close / reroll
# ---------------------------------------------------------------------------

func open(target_player: Player) -> void:
	player = target_player

	if not offers_generated:
		_generate_offers()

	_update_ui()
	show()


func close() -> void:
	hide()


func reset_shop() -> void:
	# This is still available for the level/dungeon code that currently resets
	# shops between encounters.
	offers_generated = false
	offered_offers.clear()
	purchased_offers.clear()

	for button in buy_buttons:
		button.disabled = false

	hide()


func _refresh_stock() -> void:
	if player == null:
		return

	if not GameState.spend_money(refresh_price):
		print("Not enough gold to refresh shop!")
		return

	# Reroll only the currently unpurchased shop stock. Purchased resources are
	# already owned/applied, so the existing ownership checks naturally prevent
	# them from appearing again.
	offers_generated = false
	offered_offers.clear()
	purchased_offers.clear()
	_generate_offers()
	_update_ui()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _item_type_name(type: Item.ItemType) -> String:
	match type:
		Item.ItemType.WEAPON:
			return "WEAPON"
		Item.ItemType.ARMOUR:
			return "ARMOUR"
		Item.ItemType.ACCESSORY:
			return "ACCESSORY"
	return "ITEM"


func _format_number(value: int) -> String:
	var text := str(maxi(value, 0))
	var output := ""
	var count := 0

	for index in range(text.length() - 1, -1, -1):
		if count == 3:
			output = "," + output
			count = 0
		output = text[index] + output
		count += 1

	return output

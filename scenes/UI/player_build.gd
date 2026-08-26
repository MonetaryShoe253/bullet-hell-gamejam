extends Control

const MAIN_MENU_SCENE := "res://scenes/UI/main_menu.tscn"

enum BuildView { LOADOUT, ABILITIES, STATS }

@onready var back_button: Button = $Header/BackButton
@onready var coin_label: Label = $Header/Coins/Label

@onready var loadout_tab: Button = $Main/CenterColumn/Tabs/Loadout
@onready var abilities_tab: Button = $Main/CenterColumn/Tabs/Abilities
@onready var stats_tab: Button = $Main/CenterColumn/Tabs/Stats

@onready var weapons_tab: Button = $Main/AvailablePanel/VBox/CategoryTabs/Weapons
@onready var armour_tab: Button = $Main/AvailablePanel/VBox/CategoryTabs/Armour
@onready var accessories_tab: Button = $Main/AvailablePanel/VBox/CategoryTabs/Accessories
@onready var available_heading: Label = $Main/AvailablePanel/VBox/FilterRow/Heading
@onready var item_list: Container = $Main/AvailablePanel/VBox/ItemList

@onready var weapon_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/HeroArea/WeaponSlot
@onready var armour_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/HeroArea/ArmourSlot
@onready var accessory_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/HeroArea/AccessorySlot
@onready var q_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/AbilitiesRow/Q
@onready var e_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/AbilitiesRow/E
@onready var passive_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/AbilitiesRow/Passive

@onready var detail_icon = $Main/DetailsPanel/VBox/ItemHeader/Icon/Label
@onready var detail_name: Label = $Main/DetailsPanel/VBox/ItemHeader/Text/Name
@onready var detail_rarity: Label = $Main/DetailsPanel/VBox/ItemHeader/Text/Rarity
@onready var detail_description: Label = $Main/DetailsPanel/VBox/ItemHeader/Text/Description
@onready var detail_damage: Label = $Main/DetailsPanel/VBox/Stats/Damage
@onready var detail_fire_rate: Label = $Main/DetailsPanel/VBox/Stats/FireRate
@onready var detail_crit_chance: Label = $Main/DetailsPanel/VBox/Stats/CritChance
@onready var detail_crit_damage: Label = $Main/DetailsPanel/VBox/Stats/CritDamage
@onready var detail_knockback: Label = $Main/DetailsPanel/VBox/Stats/Knockback
@onready var detail_burn: Label = $Main/DetailsPanel/VBox/Stats/Burn
@onready var detail_effect: Label = $Main/DetailsPanel/VBox/Effect
@onready var upgrade_title: Label = $Main/DetailsPanel/VBox/UpgradeTitle
@onready var upgrade_dots: Label = $Main/DetailsPanel/VBox/UpgradeDots
@onready var equip_button: Button = $Main/DetailsPanel/VBox/EquipButton

var selected_item: Item = null
var selected_ability: Ability = null
var target_ability_slot := 0
var current_view := BuildView.LOADOUT
var current_item_type := Item.ItemType.WEAPON


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	loadout_tab.pressed.connect(func(): _show_loadout(Item.ItemType.WEAPON))
	abilities_tab.pressed.connect(_show_abilities)
	stats_tab.pressed.connect(_show_stats)

	weapons_tab.pressed.connect(func(): _show_loadout(Item.ItemType.WEAPON))
	armour_tab.pressed.connect(func(): _show_loadout(Item.ItemType.ARMOUR))
	accessories_tab.pressed.connect(func(): _show_loadout(Item.ItemType.ACCESSORY))

	weapon_slot.pressed.connect(func(): _show_loadout(Item.ItemType.WEAPON))
	armour_slot.pressed.connect(func(): _show_loadout(Item.ItemType.ARMOUR))
	accessory_slot.pressed.connect(func(): _show_loadout(Item.ItemType.ACCESSORY))
	q_slot.pressed.connect(func(): _show_abilities(0))
	e_slot.pressed.connect(func(): _show_abilities(1))

	equip_button.pressed.connect(_on_equip_pressed)

	if not MetaProgression.loadout_changed.is_connected(_refresh_equipped):
		MetaProgression.loadout_changed.connect(_refresh_equipped)

	_show_loadout(Item.ItemType.WEAPON)
	_refresh_equipped()
	_refresh_money()


func _show_loadout(type: Item.ItemType) -> void:
	current_view = BuildView.LOADOUT
	current_item_type = type
	selected_ability = null
	_set_tab_state()
	available_heading.text = {
		Item.ItemType.WEAPON: "AVAILABLE WEAPONS",
		Item.ItemType.ARMOUR: "AVAILABLE ARMOUR",
		Item.ItemType.ACCESSORY: "AVAILABLE ACCESSORIES",
	}[type]
	_rebuild_item_buttons(ContentDatabase.get_unlocked_items(type))
	_clear_details()


func _show_abilities(slot: int = 0) -> void:
	current_view = BuildView.ABILITIES
	target_ability_slot = slot
	selected_item = null
	_set_tab_state()
	available_heading.text = "AVAILABLE ABILITIES"
	_rebuild_ability_buttons(ContentDatabase.get_unlocked_active_abilities())
	_clear_details()


func _show_stats() -> void:
	current_view = BuildView.STATS
	_set_tab_state()
	available_heading.text = "BUILD STATS"
	_clear_list()
	_clear_details()
	detail_name.text = "BUILD STATS"
	detail_description.text = "Your final combat stats are applied by StatsComponent when the run starts."
	equip_button.disabled = true
	equip_button.text = "NO ITEM SELECTED"


func _set_tab_state() -> void:
	loadout_tab.disabled = current_view == BuildView.LOADOUT
	abilities_tab.disabled = current_view == BuildView.ABILITIES
	stats_tab.disabled = current_view == BuildView.STATS
	weapons_tab.visible = current_view == BuildView.LOADOUT
	armour_tab.visible = current_view == BuildView.LOADOUT
	accessories_tab.visible = current_view == BuildView.LOADOUT


func _clear_list() -> void:
	for child in item_list.get_children():
		child.queue_free()


func _rebuild_item_buttons(items: Array[Item]) -> void:
	_clear_list()
	for item in items:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 76)
		button.text = item.item_name + "\n" + item.get_stats_text()
		if item.icon:
			button.icon = item.icon
		button.expand_icon = true
		button.icon_max_width = 52
		button.pressed.connect(func(): _select_item(item))
		item_list.add_child(button)

	if items.is_empty():
		var label := Label.new()
		label.text = "No unlocked items in this category yet."
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_list.add_child(label)


func _rebuild_ability_buttons(abilities: Array[Ability]) -> void:
	_clear_list()
	for ability in abilities:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 76)
		button.text = "%s\nCooldown: %.1fs" % [ability.ability_name, ability.cooldown]
		if "icon" in ability and ability.icon:
			button.icon = ability.icon
			button.expand_icon = true
			button.icon_max_width = 52
		button.pressed.connect(func(): _select_ability(ability))
		item_list.add_child(button)

	if abilities.is_empty():
		var label := Label.new()
		label.text = "No unlocked active abilities yet."
		item_list.add_child(label)


func _select_item(item: Item) -> void:
	selected_item = item
	selected_ability = null
	detail_name.text = item.item_name
	detail_rarity.text = "UNLOCKED EQUIPMENT"
	detail_description.text = item.description
	if item.icon and detail_icon is TextureRect:
		detail_icon.texture = item.icon
	elif detail_icon is Label:
		detail_icon.text = "◆"
	_set_item_stats(item.get_stats_text())
	equip_button.disabled = _item_is_equipped(item)
	equip_button.text = "EQUIPPED ✓" if equip_button.disabled else "EQUIP"


func _select_ability(ability: Ability) -> void:
	selected_item = null
	selected_ability = ability
	detail_name.text = ability.ability_name
	detail_rarity.text = "ACTIVE ABILITY"
	detail_description.text = ability.description
	_set_item_stats("Cooldown: %.1fs" % ability.cooldown)
	var equipped_id := (
		MetaProgression.equipped_active_1_id
		if target_ability_slot == 0
		else MetaProgression.equipped_active_2_id
	)
	equip_button.disabled = ContentDatabase.get_content_id(ability) == equipped_id
	equip_button.text = (
		"EQUIPPED TO %s ✓" % ("Q" if target_ability_slot == 0 else "E")
		if equip_button.disabled
		else "EQUIP TO %s" % ("Q" if target_ability_slot == 0 else "E")
	)


func _set_item_stats(text: String) -> void:
	detail_damage.text = text
	detail_fire_rate.text = ""
	detail_crit_chance.text = ""
	detail_crit_damage.text = ""
	detail_knockback.text = ""
	detail_burn.text = ""
	detail_effect.text = ""
	upgrade_title.text = ""
	upgrade_dots.text = ""


func _clear_details() -> void:
	selected_item = null
	selected_ability = null
	detail_name.text = "SELECT SOMETHING"
	detail_rarity.text = ""
	detail_description.text = "Choose an unlocked item or ability from the left."
	_set_item_stats("")
	equip_button.disabled = true
	equip_button.text = "SELECT AN ITEM"


func _on_equip_pressed() -> void:
	if selected_item:
		MetaProgression.set_equipped_item(selected_item)
		_refresh_equipped()
		_select_item(selected_item)
	elif selected_ability:
		MetaProgression.set_active_ability(target_ability_slot, selected_ability)
		_refresh_equipped()
		_select_ability(selected_ability)


func _item_is_equipped(item: Item) -> bool:
	var id := ContentDatabase.get_content_id(item)
	match item.item_type:
		Item.ItemType.WEAPON:
			return id == MetaProgression.equipped_weapon_id
		Item.ItemType.ARMOUR:
			return id == MetaProgression.equipped_armour_id
		Item.ItemType.ACCESSORY:
			return id == MetaProgression.equipped_accessory_id
	return false


func _refresh_equipped() -> void:
	weapon_slot.text = _item_slot_text("WEAPON", ContentDatabase.find_item(MetaProgression.equipped_weapon_id))
	armour_slot.text = _item_slot_text("ARMOUR", ContentDatabase.find_item(MetaProgression.equipped_armour_id))
	accessory_slot.text = _item_slot_text("ACCESSORY", ContentDatabase.find_item(MetaProgression.equipped_accessory_id))

	var q := ContentDatabase.find_active_ability(MetaProgression.equipped_active_1_id)
	var e := ContentDatabase.find_active_ability(MetaProgression.equipped_active_2_id)
	q_slot.text = "Q\n%s" % (q.ability_name if q else "Empty")
	e_slot.text = "E\n%s" % (e.ability_name if e else "Empty")
	passive_slot.text = "PASSIVE\nSaved passives next"


func _item_slot_text(title: String, item: Item) -> String:
	return "%s\n%s" % [title, item.item_name if item else "Empty"]


func _refresh_money() -> void:
	coin_label.text = "●  %s\nPLUCK COINS" % _format_number(GameState.money)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


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

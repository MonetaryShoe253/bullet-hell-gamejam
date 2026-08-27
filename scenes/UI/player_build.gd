extends Control

const MAIN_MENU_SCENE := "res://scenes/UI/main_menu.tscn"

enum BuildView { LOADOUT, ABILITIES, STATS }
enum EquipmentCategory { WEAPONS, ARMOUR, ACCESSORIES }

const TAB_ACTIVE := Color(1.0, 0.62, 0.12, 1.0)
const TAB_INACTIVE := Color(0.82, 0.76, 0.70, 1.0)
const SELECTED_COLOR := Color(1.0, 0.78, 0.30, 1.0)
const NORMAL_COLOR := Color.WHITE

# Temporary presentation data matching the mockup. This is intentionally kept
# in one place so it can later be replaced by your actual item resources/data.
const EQUIPMENT := {
	"hot_wing": {
		"name": "HOT WING",
		"category": EquipmentCategory.WEAPONS,
		"rarity": "RARE WEAPON",
		"icon": "🔥",
		"description": "A scorching blade forged\nin the heart of the fryer.",
		"summary": "+25 Damage   •   +10% Fire Rate",
		"damage": "25",
		"fire_rate": "0.30s",
		"crit_chance": "10%",
		"crit_damage": "150%",
		"knockback": "15",
		"burn": "20%",
		"effect": "Chance to ignite enemies for 3s.",
		"upgrade": "2 / 6",
		"upgrade_dots": "◆  ◆  ◇  ◇  ◇  ◇",
		"cost": 500,
	},
	"spicy_skewer": {
		"name": "SPICY SKEWER",
		"category": EquipmentCategory.WEAPONS,
		"rarity": "EPIC WEAPON",
		"icon": "🌶",
		"description": "A vicious skewer seasoned for\nmaximum critical flavour.",
		"summary": "+40 Damage   •   +15% Crit Chance",
		"damage": "40",
		"fire_rate": "0.40s",
		"crit_chance": "15%",
		"crit_damage": "175%",
		"knockback": "10",
		"burn": "5%",
		"effect": "Higher critical chance at the cost of fire rate.",
		"upgrade": "1 / 6",
		"upgrade_dots": "◆  ◇  ◇  ◇  ◇  ◇",
		"cost": 650,
	},
	"drumstick_mace": {
		"name": "DRUMSTICK MACE",
		"category": EquipmentCategory.WEAPONS,
		"rarity": "UNCOMMON WEAPON",
		"icon": "🍗",
		"description": "Heavy, greasy and surprisingly\neffective at crowd control.",
		"summary": "+15 Damage   •   +20 Knockback",
		"damage": "15",
		"fire_rate": "0.55s",
		"crit_chance": "5%",
		"crit_damage": "140%",
		"knockback": "20",
		"burn": "0%",
		"effect": "Strong knockback helps keep enemies away.",
		"upgrade": "1 / 6",
		"upgrade_dots": "◆  ◇  ◇  ◇  ◇  ◇",
		"cost": 300,
	},
	"feather_fans": {
		"name": "FEATHER FANS",
		"category": EquipmentCategory.WEAPONS,
		"rarity": "COMMON WEAPON",
		"icon": "✦",
		"description": "Rapid feather volleys for chickens\nwho value speed over impact.",
		"summary": "+10 Damage   •   +5% Attack Speed",
		"damage": "10",
		"fire_rate": "0.24s",
		"crit_chance": "5%",
		"crit_damage": "125%",
		"knockback": "5",
		"burn": "0%",
		"effect": "Fast attacks make it easier to keep pressure on enemies.",
		"upgrade": "0 / 6",
		"upgrade_dots": "◇  ◇  ◇  ◇  ◇  ◇",
		"cost": 150,
	},
}

@onready var back_button: Button = $Header/BackButton
@onready var coin_label: Label = $Header/Coins/Label

@onready var loadout_tab: Button = $Main/CenterColumn/Tabs/Loadout
@onready var abilities_tab: Button = $Main/CenterColumn/Tabs/Abilities
@onready var stats_tab: Button = $Main/CenterColumn/Tabs/Stats

@onready var weapons_tab: Button = $Main/AvailablePanel/VBox/CategoryTabs/Weapons
@onready var armour_tab: Button = $Main/AvailablePanel/VBox/CategoryTabs/Armour
@onready var accessories_tab: Button = $Main/AvailablePanel/VBox/CategoryTabs/Accessories
@onready var available_heading: Label = $Main/AvailablePanel/VBox/FilterRow/Heading

@onready var hot_wing_button: Button = $Main/AvailablePanel/VBox/ItemList/HotWing
@onready var spicy_skewer_button: Button = $Main/AvailablePanel/VBox/ItemList/SpicySkewer
@onready var drumstick_mace_button: Button = $Main/AvailablePanel/VBox/ItemList/DrumstickMace
@onready var feather_fans_button: Button = $Main/AvailablePanel/VBox/ItemList/FeatherFans
@onready var locked_item_button: Button = $Main/AvailablePanel/VBox/ItemList/LockedItem

@onready var weapon_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/HeroArea/WeaponSlot
@onready var armour_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/HeroArea/ArmourSlot
@onready var accessory_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/HeroArea/AccessorySlot
@onready var trinket_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/HeroArea/TrinketSlot

@onready var q_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/AbilitiesRow/Q
@onready var e_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/AbilitiesRow/E
@onready var passive_slot: Button = $Main/CenterColumn/LoadoutPanel/VBox/AbilitiesRow/Passive

@onready var detail_icon: Label = $Main/DetailsPanel/VBox/ItemHeader/Icon/Label
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

@onready var hp_stat: Label = $Main/CenterColumn/CoreStats/HBox/HP
@onready var damage_stat: Label = $Main/CenterColumn/CoreStats/HBox/Damage
@onready var speed_stat: Label = $Main/CenterColumn/CoreStats/HBox/Speed
@onready var fire_rate_stat: Label = $Main/CenterColumn/CoreStats/HBox/FireRate
@onready var dash_stat: Label = $Main/CenterColumn/CoreStats/HBox/Dash

var current_view := BuildView.LOADOUT
var current_category := EquipmentCategory.WEAPONS
var selected_item_id := "hot_wing"

# Local mockup state. Swap these for your real persistent equipment fields once
# those are exposed by the game's inventory/meta-progression layer.
var equipped_weapon_id := "hot_wing"
var equipped_armour_name := "Crispy Coat"
var equipped_accessory_name := "Lucky Drumstick"
var equipped_trinket_name := "Empty"


func _ready() -> void:
	_connect_buttons()

	if not GameState.money_changed.is_connected(_on_money_changed):
		GameState.money_changed.connect(_on_money_changed)

	_on_money_changed(GameState.money)
	_select_view(BuildView.LOADOUT)
	_select_category(EquipmentCategory.WEAPONS)
	_select_item("hot_wing")
	_refresh_equipped_slots()
	_refresh_core_stats()
	back_button.grab_focus()


func _connect_buttons() -> void:
	back_button.pressed.connect(_on_back_pressed)

	loadout_tab.pressed.connect(func(): _select_view(BuildView.LOADOUT))
	abilities_tab.pressed.connect(func(): _select_view(BuildView.ABILITIES))
	stats_tab.pressed.connect(func(): _select_view(BuildView.STATS))

	weapons_tab.pressed.connect(func(): _select_category(EquipmentCategory.WEAPONS))
	armour_tab.pressed.connect(func(): _select_category(EquipmentCategory.ARMOUR))
	accessories_tab.pressed.connect(func(): _select_category(EquipmentCategory.ACCESSORIES))

	hot_wing_button.pressed.connect(func(): _select_item("hot_wing"))
	spicy_skewer_button.pressed.connect(func(): _select_item("spicy_skewer"))
	drumstick_mace_button.pressed.connect(func(): _select_item("drumstick_mace"))
	feather_fans_button.pressed.connect(func(): _select_item("feather_fans"))

	weapon_slot.pressed.connect(func(): _select_category(EquipmentCategory.WEAPONS))
	armour_slot.pressed.connect(func(): _select_category(EquipmentCategory.ARMOUR))
	accessory_slot.pressed.connect(func(): _select_category(EquipmentCategory.ACCESSORIES))
	trinket_slot.pressed.connect(_on_trinket_pressed)

	q_slot.pressed.connect(_on_ability_slot_pressed.bind("Q"))
	e_slot.pressed.connect(_on_ability_slot_pressed.bind("E"))
	passive_slot.pressed.connect(_on_ability_slot_pressed.bind("PASSIVE"))

	equip_button.pressed.connect(_on_equip_pressed)


func _on_back_pressed() -> void:
	if ResourceLoader.exists(MAIN_MENU_SCENE):
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	else:
		get_tree().change_scene_to_file("res://scenes/UI/main_menu_redesign.tscn")


func _select_view(view: BuildView) -> void:
	current_view = view

	loadout_tab.modulate = SELECTED_COLOR if view == BuildView.LOADOUT else NORMAL_COLOR
	abilities_tab.modulate = SELECTED_COLOR if view == BuildView.ABILITIES else NORMAL_COLOR
	stats_tab.modulate = SELECTED_COLOR if view == BuildView.STATS else NORMAL_COLOR

	# The approved TSCN currently contains the full Loadout composition. Until
	# dedicated Abilities/Stats content panels are added, the tabs behave as
	# focused shortcuts rather than hiding the only working build interface.
	match view:
		BuildView.LOADOUT:
			$FooterTip.text = "💡 Tip: Mix and match gear and abilities to create your perfect build for the Deep-Fry Gauntlet!"
		BuildView.ABILITIES:
			$FooterTip.text = "💡 Select Q, E or Passive in the centre to manage that ability slot."
			q_slot.grab_focus()
		BuildView.STATS:
			$FooterTip.text = "💡 Your core combat stats are shown below the loadout."
			hp_stat.grab_focus()


func _select_category(category: EquipmentCategory) -> void:
	current_category = category

	weapons_tab.modulate = SELECTED_COLOR if category == EquipmentCategory.WEAPONS else NORMAL_COLOR
	armour_tab.modulate = SELECTED_COLOR if category == EquipmentCategory.ARMOUR else NORMAL_COLOR
	accessories_tab.modulate = SELECTED_COLOR if category == EquipmentCategory.ACCESSORIES else NORMAL_COLOR

	match category:
		EquipmentCategory.WEAPONS:
			available_heading.text = "AVAILABLE WEAPONS"
			_set_weapon_list_visible(true)
			if EQUIPMENT[selected_item_id]["category"] != EquipmentCategory.WEAPONS:
				_select_item("hot_wing")
		EquipmentCategory.ARMOUR:
			available_heading.text = "AVAILABLE ARMOUR"
			_set_weapon_list_visible(false)
			_show_category_placeholder("ARMOUR", "Armour items will populate here from your inventory data.")
		EquipmentCategory.ACCESSORIES:
			available_heading.text = "AVAILABLE ACCESSORIES"
			_set_weapon_list_visible(false)
			_show_category_placeholder("ACCESSORIES", "Accessories will populate here from your inventory data.")


func _set_weapon_list_visible(is_visible: bool) -> void:
	hot_wing_button.visible = is_visible
	spicy_skewer_button.visible = is_visible
	drumstick_mace_button.visible = is_visible
	feather_fans_button.visible = is_visible
	locked_item_button.visible = is_visible


func _show_category_placeholder(category_name: String, message: String) -> void:
	detail_icon.text = "◆"
	detail_name.text = category_name
	detail_rarity.text = "SELECT AN ITEM"
	detail_description.text = message
	detail_damage.text = "⚔  DAMAGE                                      --"
	detail_fire_rate.text = "➤  FIRE RATE                                  --"
	detail_crit_chance.text = "◎  CRITICAL CHANCE                              --"
	detail_crit_damage.text = "✦  CRITICAL DAMAGE                             --"
	detail_knockback.text = "↠  KNOCKBACK                                     --"
	detail_burn.text = "♨  SPECIAL                                        --"
	detail_effect.text = ""
	upgrade_title.text = "UPGRADE LEVEL                                      --"
	upgrade_dots.text = "◇  ◇  ◇  ◇  ◇  ◇"
	equip_button.text = "SELECT AN ITEM"
	equip_button.disabled = true


func _select_item(item_id: String) -> void:
	if not EQUIPMENT.has(item_id):
		return

	selected_item_id = item_id
	var item: Dictionary = EQUIPMENT[item_id]

	current_category = item["category"]
	_set_weapon_list_visible(true)
	available_heading.text = "AVAILABLE WEAPONS"
	weapons_tab.modulate = SELECTED_COLOR
	armour_tab.modulate = NORMAL_COLOR
	accessories_tab.modulate = NORMAL_COLOR

	hot_wing_button.modulate = SELECTED_COLOR if item_id == "hot_wing" else NORMAL_COLOR
	spicy_skewer_button.modulate = SELECTED_COLOR if item_id == "spicy_skewer" else NORMAL_COLOR
	drumstick_mace_button.modulate = SELECTED_COLOR if item_id == "drumstick_mace" else NORMAL_COLOR
	feather_fans_button.modulate = SELECTED_COLOR if item_id == "feather_fans" else NORMAL_COLOR

	_populate_details(item)
	_refresh_equip_button()


func _populate_details(item: Dictionary) -> void:
	detail_icon.text = item["icon"]
	detail_name.text = item["name"]
	detail_rarity.text = item["rarity"]
	detail_description.text = item["description"]
	detail_damage.text = "⚔  DAMAGE                                      %s" % item["damage"]
	detail_fire_rate.text = "➤  FIRE RATE                                  %s" % item["fire_rate"]
	detail_crit_chance.text = "◎  CRITICAL CHANCE                              %s" % item["crit_chance"]
	detail_crit_damage.text = "✦  CRITICAL DAMAGE                             %s" % item["crit_damage"]
	detail_knockback.text = "↠  KNOCKBACK                                     %s" % item["knockback"]
	detail_burn.text = "♨  BURN CHANCE                                   %s" % item["burn"]
	detail_effect.text = item["effect"]
	upgrade_title.text = "UPGRADE LEVEL                                      %s" % item["upgrade"]
	upgrade_dots.text = item["upgrade_dots"]


func _refresh_equip_button() -> void:
	var item: Dictionary = EQUIPMENT[selected_item_id]
	var already_equipped := selected_item_id == equipped_weapon_id

	equip_button.disabled = already_equipped
	if already_equipped:
		equip_button.text = "EQUIPPED  ✓"
	else:
		equip_button.text = "EQUIP     ● %d" % item["cost"]


func _on_equip_pressed() -> void:
	if not EQUIPMENT.has(selected_item_id):
		return

	var item: Dictionary = EQUIPMENT[selected_item_id]
	if item["category"] != EquipmentCategory.WEAPONS:
		return

	if selected_item_id == equipped_weapon_id:
		return

	var cost: int = item["cost"]
	if GameState.money < cost:
		_show_message("NOT ENOUGH CLUCK COINS", "You need %d Cluck Coins to equip %s." % [cost, item["name"]])
		return

	# This assumes GameState.money is writable, matching the existing menu's
	# use of GameState as live run state. If your project exposes a spend_money()
	# method, replace these two lines with that method instead.
	GameState.money -= cost
	GameState.money_changed.emit(GameState.money)

	equipped_weapon_id = selected_item_id
	_refresh_equipped_slots()
	_refresh_core_stats()
	_refresh_equip_button()


func _refresh_equipped_slots() -> void:
	var weapon: Dictionary = EQUIPMENT[equipped_weapon_id]
	weapon_slot.text = "WEAPON\n%s\n%s" % [weapon["icon"], _title_case(weapon["name"])]
	armour_slot.text = "ARMOUR\n🛡\n%s" % equipped_armour_name
	accessory_slot.text = "ACCESSORY\n◆\n%s" % equipped_accessory_name
	trinket_slot.text = "TRINKET\n+\n%s" % equipped_trinket_name


func _refresh_core_stats() -> void:
	var weapon: Dictionary = EQUIPMENT[equipped_weapon_id]

	# Keep the project's known baseline values and preview the selected weapon's
	# damage/fire-rate values in the build summary.
	hp_stat.text = "♥  100\nMAX HP"
	damage_stat.text = "⚔  %s\nDAMAGE" % weapon["damage"]
	speed_stat.text = "♟  250\nSPEED"
	fire_rate_stat.text = "➤  %s\nFIRE RATE" % weapon["fire_rate"]
	dash_stat.text = "»  0.75s\nDASH CD"


func _on_ability_slot_pressed(slot_name: String) -> void:
	_select_view(BuildView.ABILITIES)
	_show_message(
		"%s ABILITY" % slot_name,
		"This slot is ready to connect to the game's ability inventory/equip data."
	)


func _on_trinket_pressed() -> void:
	_show_message("TRINKET", "The trinket slot is currently empty.")


func _on_money_changed(total: int) -> void:
	coin_label.text = "●  %s\nCLUCK COINS" % _format_number(total)


func _show_message(title_text: String, body: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title_text
	dialog.dialog_text = body
	dialog.unresizable = true
	add_child(dialog)
	dialog.popup_centered(Vector2i(560, 200))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


func _title_case(value: String) -> String:
	var words := value.to_lower().split(" ")
	var result: Array[String] = []
	for word in words:
		result.append(word.capitalize())
	return " ".join(result)


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

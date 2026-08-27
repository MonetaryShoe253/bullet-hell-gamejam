extends CanvasLayer

const DUNGEON_SCENE := "res://scenes/dungeon/dungeon.tscn"

enum BrowserTab { WEAPON, ARMOUR, ACCESSORY, ABILITIES }

var browser_tab := BrowserTab.WEAPON
var selected_resource: Resource = null

@onready var settings_button: Button = $Root/Margin/VBox/Header/SettingsButton
@onready var start_button: Button = $Root/Margin/VBox/Main/Center/StartRun

@onready var weapons_filter: Button = $Root/Margin/VBox/Main/GearPanel/VBox/Filters/Weapons
@onready var armour_filter: Button = $Root/Margin/VBox/Main/GearPanel/VBox/Filters/Armour
@onready var accessories_filter: Button = $Root/Margin/VBox/Main/GearPanel/VBox/Filters/Accessories
@onready var abilities_filter: Button = $Root/Margin/VBox/Main/GearPanel/VBox/Filters/Abilities
@onready var browser_list: VBoxContainer = $Root/Margin/VBox/Main/GearPanel/VBox/Scroll/GearList

@onready var weapon_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/GearSlots/Weapon
@onready var armour_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/GearSlots/Armour
@onready var accessory_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/GearSlots/Accessory
@onready var q_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/AbilitySlots/Q
@onready var e_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/AbilitySlots/E
@onready var passive_1_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/AbilitySlots/Passive1
@onready var passive_2_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/AbilitySlots/Passive2

@onready var info_icon: TextureRect = $Root/Margin/VBox/Main/InfoPanel/VBox/Icon
@onready var info_name: Label = $Root/Margin/VBox/Main/InfoPanel/VBox/Name
@onready var info_type: Label = $Root/Margin/VBox/Main/InfoPanel/VBox/Type
@onready var info_description: Label = $Root/Margin/VBox/Main/InfoPanel/VBox/Description
@onready var info_stats: Label = $Root/Margin/VBox/Main/InfoPanel/VBox/Stats
@onready var info_equipped: Label = $Root/Margin/VBox/Main/InfoPanel/VBox/Equipped
@onready var primary_action: Button = $Root/Margin/VBox/Main/InfoPanel/VBox/Actions/Primary
@onready var secondary_action: Button = $Root/Margin/VBox/Main/InfoPanel/VBox/Actions/Secondary

@onready var boss_names: Array[Label] = [
	$Root/Margin/VBox/BossFooter/BossVBox/BossRow/Pizza/Name,
	$Root/Margin/VBox/BossFooter/BossVBox/BossRow/Burger/Name,
	$Root/Margin/VBox/BossFooter/BossVBox/BossRow/Taco/Name,
	$Root/Margin/VBox/BossFooter/BossVBox/BossRow/Pepper/Name,
]
@onready var boss_icons: Array[TextureRect] = [
	$Root/Margin/VBox/BossFooter/BossVBox/BossRow/Pizza/Icon,
	$Root/Margin/VBox/BossFooter/BossVBox/BossRow/Burger/Icon,
	$Root/Margin/VBox/BossFooter/BossVBox/BossRow/Taco/Icon,
	$Root/Margin/VBox/BossFooter/BossVBox/BossRow/Pepper/Icon,
]
@onready var boss_statuses: Array[Label] = [
	$Root/Margin/VBox/BossFooter/BossVBox/BossRow/Pizza/Status,
	$Root/Margin/VBox/BossFooter/BossVBox/BossRow/Burger/Status,
	$Root/Margin/VBox/BossFooter/BossVBox/BossRow/Taco/Status,
	$Root/Margin/VBox/BossFooter/BossVBox/BossRow/Pepper/Status,
]
@onready var boss_dots: Array[ColorRect] = [
	$Root/Margin/VBox/BossFooter/BossVBox/Track/Col1/Dot,
	$Root/Margin/VBox/BossFooter/BossVBox/Track/Col2/Dot,
	$Root/Margin/VBox/BossFooter/BossVBox/Track/Col3/Dot,
	$Root/Margin/VBox/BossFooter/BossVBox/Track/Col4/Dot,
]
@onready var boss_lines: Array[ColorRect] = [
	$Root/Margin/VBox/BossFooter/BossVBox/Track/Col1/LineRight,
	$Root/Margin/VBox/BossFooter/BossVBox/Track/Col2/LineRight,
	$Root/Margin/VBox/BossFooter/BossVBox/Track/Col3/LineRight,
]
@onready var boss_line_continuations: Array[ColorRect] = [
	$Root/Margin/VBox/BossFooter/BossVBox/Track/Col2/LineLeft,
	$Root/Margin/VBox/BossFooter/BossVBox/Track/Col3/LineLeft,
	$Root/Margin/VBox/BossFooter/BossVBox/Track/Col4/LineLeft,
]

const BOSS_IDS: Array[StringName] = [
	&"boss_pizza_defeated", &"boss_burger_defeated",
	&"boss_taco_defeated", &"boss_pepper_defeated"
]
const BOSS_LABELS := ["PIZZA", "BURGER", "TACO", "PEPPER"]


func _ready() -> void:
	# Death/reward screens pause gameplay; the menu must always receive input.
	get_tree().paused = false
	settings_button.pressed.connect(_open_settings)
	start_button.pressed.connect(_start_run)

	weapons_filter.pressed.connect(func(): _set_browser_tab(BrowserTab.WEAPON))
	armour_filter.pressed.connect(func(): _set_browser_tab(BrowserTab.ARMOUR))
	accessories_filter.pressed.connect(func(): _set_browser_tab(BrowserTab.ACCESSORY))
	abilities_filter.pressed.connect(func(): _set_browser_tab(BrowserTab.ABILITIES))

	weapon_slot.pressed.connect(func(): _select_resource(ContentDatabase.find_item(MetaProgression.equipped_weapon_id)))
	armour_slot.pressed.connect(func(): _select_resource(ContentDatabase.find_item(MetaProgression.equipped_armour_id)))
	accessory_slot.pressed.connect(func(): _select_resource(ContentDatabase.find_item(MetaProgression.equipped_accessory_id)))
	q_slot.pressed.connect(func(): _select_resource(ContentDatabase.find_active_ability(MetaProgression.equipped_active_1_id)))
	e_slot.pressed.connect(func(): _select_resource(ContentDatabase.find_active_ability(MetaProgression.equipped_active_2_id)))
	passive_1_slot.pressed.connect(func(): _select_resource(ContentDatabase.find_passive_ability(MetaProgression.equipped_passive_1_id)))
	passive_2_slot.pressed.connect(func(): _select_resource(ContentDatabase.find_passive_ability(MetaProgression.equipped_passive_2_id)))

	if not MetaProgression.loadout_changed.is_connected(_on_loadout_changed):
		MetaProgression.loadout_changed.connect(_on_loadout_changed)
	if not MetaProgression.content_unlocked.is_connected(_on_content_unlocked):
		MetaProgression.content_unlocked.connect(_on_content_unlocked)

	_refresh_all()
	start_button.grab_focus()


func _refresh_all() -> void:
	_refresh_browser()
	_refresh_equipped()
	_refresh_selected()
	_refresh_bosses()


func _set_browser_tab(tab: BrowserTab) -> void:
	browser_tab = tab
	_refresh_browser()


func _refresh_browser() -> void:
	_clear(browser_list)
	weapons_filter.disabled = browser_tab == BrowserTab.WEAPON
	armour_filter.disabled = browser_tab == BrowserTab.ARMOUR
	accessories_filter.disabled = browser_tab == BrowserTab.ACCESSORY
	abilities_filter.disabled = browser_tab == BrowserTab.ABILITIES

	match browser_tab:
		BrowserTab.WEAPON:
			_add_items(Item.ItemType.WEAPON)
		BrowserTab.ARMOUR:
			_add_items(Item.ItemType.ARMOUR)
		BrowserTab.ACCESSORY:
			_add_items(Item.ItemType.ACCESSORY)
		BrowserTab.ABILITIES:
			_add_abilities()

	if browser_list.get_child_count() == 0:
		_add_empty(browser_list, "Nothing unlocked in this category yet.")


func _add_items(type: Item.ItemType) -> void:
	for item: Item in ContentDatabase.get_unlocked_items(type):
		var button := _make_browser_button(item.item_name, item.get_stats_text(), item.icon)
		button.pressed.connect(func(): _select_resource(item))
		browser_list.add_child(button)


func _add_abilities() -> void:
	for ability: Ability in ContentDatabase.get_unlocked_active_abilities():
		var detail := "ACTIVE  •  Cooldown %.1fs" % ability.cooldown
		var button := _make_browser_button(ability.ability_name, detail, ability.icon)
		button.pressed.connect(func(): _select_resource(ability))
		browser_list.add_child(button)

	for passive: PassiveAbility in ContentDatabase.get_unlocked_passive_abilities():
		var button := _make_browser_button(passive.ability_name, "PASSIVE", passive.icon)
		button.pressed.connect(func(): _select_resource(passive))
		browser_list.add_child(button)


func _make_browser_button(title: String, detail: String, icon: Texture2D) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 76)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = title + ("\n" + detail if detail != "" else "")
	if icon:
		button.icon = icon
		button.expand_icon = true
	return button


func _select_resource(resource: Resource) -> void:
	selected_resource = resource
	_refresh_selected()


func _refresh_selected() -> void:
	_disconnect_action_buttons()
	primary_action.hide()
	secondary_action.hide()

	if selected_resource == null:
		info_icon.texture = null
		info_name.text = "Select something"
		info_type.text = "—"
		info_description.text = "Choose an unlocked item or ability on the left, or click an equipped slot in the centre."
		info_stats.text = ""
		info_equipped.text = ""
		return

	if selected_resource is Item:
		_show_item(selected_resource as Item)
	elif selected_resource is Ability:
		_show_active(selected_resource as Ability)
	elif selected_resource is PassiveAbility:
		_show_passive(selected_resource as PassiveAbility)


func _show_item(item: Item) -> void:
	info_icon.texture = item.icon
	info_name.text = item.item_name
	info_type.text = _item_type_name(item.item_type)
	info_description.text = item.description
	info_stats.text = item.get_stats_text()

	var equipped := _is_item_equipped(item)
	if equipped:
		info_equipped.text = "EQUIPPED"
		primary_action.text = "UNEQUIP"
		primary_action.show()
		primary_action.pressed.connect(func(): _unequip_item(item))
	else:
		info_equipped.text = ""
		primary_action.text = "EQUIP"
		primary_action.show()
		primary_action.pressed.connect(func(): MetaProgression.set_equipped_item(item))


func _show_active(ability: Ability) -> void:
	info_icon.texture = ability.icon
	info_name.text = ability.ability_name
	info_type.text = "ACTIVE ABILITY"
	info_description.text = ability.description
	info_stats.text = "Cooldown: %.1fs" % ability.cooldown

	var slot := _active_slot_for(ability)
	if slot >= 0:
		info_equipped.text = "EQUIPPED: %s" % ("Q" if slot == 0 else "E")
		primary_action.text = "UNEQUIP"
		primary_action.show()
		primary_action.pressed.connect(func(): MetaProgression.set_active_ability(slot, null))
	else:
		info_equipped.text = ""
		primary_action.text = "EQUIP Q"
		secondary_action.text = "EQUIP E"
		primary_action.show()
		secondary_action.show()
		primary_action.pressed.connect(func(): MetaProgression.set_active_ability(0, ability))
		secondary_action.pressed.connect(func(): MetaProgression.set_active_ability(1, ability))


func _show_passive(passive: PassiveAbility) -> void:
	info_icon.texture = passive.icon
	info_name.text = passive.ability_name
	info_type.text = "PASSIVE ABILITY"
	info_description.text = passive.description
	info_stats.text = ""

	var slot := _passive_slot_for(passive)
	if slot >= 0:
		info_equipped.text = "EQUIPPED: PASSIVE %d" % (slot + 1)
		primary_action.text = "UNEQUIP"
		primary_action.show()
		primary_action.pressed.connect(func(): MetaProgression.set_passive_ability(slot, null))
	else:
		info_equipped.text = ""
		primary_action.text = "EQUIP PASSIVE 1"
		secondary_action.text = "EQUIP PASSIVE 2"
		primary_action.show()
		secondary_action.show()
		primary_action.pressed.connect(func(): MetaProgression.set_passive_ability(0, passive))
		secondary_action.pressed.connect(func(): MetaProgression.set_passive_ability(1, passive))


func _disconnect_action_buttons() -> void:
	for connection in primary_action.pressed.get_connections():
		primary_action.pressed.disconnect(connection.callable)
	for connection in secondary_action.pressed.get_connections():
		secondary_action.pressed.disconnect(connection.callable)


func _is_item_equipped(item: Item) -> bool:
	var id := ContentDatabase.get_content_id(item)
	match item.item_type:
		Item.ItemType.WEAPON:
			return MetaProgression.equipped_weapon_id == id
		Item.ItemType.ARMOUR:
			return MetaProgression.equipped_armour_id == id
		Item.ItemType.ACCESSORY:
			return MetaProgression.equipped_accessory_id == id
	return false


func _active_slot_for(ability: Ability) -> int:
	var id := ContentDatabase.get_content_id(ability)
	if MetaProgression.equipped_active_1_id == id:
		return 0
	if MetaProgression.equipped_active_2_id == id:
		return 1
	return -1


func _passive_slot_for(passive: PassiveAbility) -> int:
	var id := ContentDatabase.get_content_id(passive)
	if MetaProgression.equipped_passive_1_id == id:
		return 0
	if MetaProgression.equipped_passive_2_id == id:
		return 1
	return -1


func _unequip_item(item: Item) -> void:
	if item == null:
		return

	MetaProgression.unequip_item(item.item_type)


func _refresh_equipped() -> void:
	_set_item_slot(weapon_slot, "WEAPON", ContentDatabase.find_item(MetaProgression.equipped_weapon_id))
	_set_item_slot(armour_slot, "ARMOUR", ContentDatabase.find_item(MetaProgression.equipped_armour_id))
	_set_item_slot(accessory_slot, "ACCESSORY", ContentDatabase.find_item(MetaProgression.equipped_accessory_id))
	_set_ability_slot(q_slot, "Q", ContentDatabase.find_active_ability(MetaProgression.equipped_active_1_id))
	_set_ability_slot(e_slot, "E", ContentDatabase.find_active_ability(MetaProgression.equipped_active_2_id))
	_set_passive_slot(passive_1_slot, "PASSIVE 1", ContentDatabase.find_passive_ability(MetaProgression.equipped_passive_1_id))
	_set_passive_slot(passive_2_slot, "PASSIVE 2", ContentDatabase.find_passive_ability(MetaProgression.equipped_passive_2_id))


func _set_item_slot(button: Button, title: String, item: Item) -> void:
	button.text = "%s\n%s" % [title, item.item_name if item else "Empty"]
	button.icon = item.icon if item != null and item.icon else null
	button.expand_icon = true


func _set_ability_slot(button: Button, title: String, ability: Ability) -> void:
	button.text = "%s\n%s" % [title, ability.ability_name if ability else "Empty"]
	button.icon = ability.icon if ability != null and ability.icon else null
	button.expand_icon = true


func _set_passive_slot(button: Button, title: String, passive: PassiveAbility) -> void:
	button.text = "%s\n%s" % [title, passive.ability_name if passive else "Empty"]
	button.icon = passive.icon if passive != null and passive.icon else null
	button.expand_icon = true


func _item_type_name(type: Item.ItemType) -> String:
	match type:
		Item.ItemType.WEAPON:
			return "WEAPON"
		Item.ItemType.ARMOUR:
			return "ARMOUR"
		Item.ItemType.ACCESSORY:
			return "ACCESSORY"
	return "ITEM"


func _refresh_bosses() -> void:
	var first_undefeated := -1
	for i in BOSS_IDS.size():
		if not _boss_is_defeated(BOSS_IDS[i]):
			first_undefeated = i
			break

	for i in BOSS_IDS.size():
		var defeated := _boss_is_defeated(BOSS_IDS[i])
		var next_up := i == first_undefeated

		boss_names[i].text = BOSS_LABELS[i] if defeated else "??????"

		if defeated:
			boss_icons[i].modulate = Color.WHITE
			boss_statuses[i].text = "DEFEATED"
			boss_statuses[i].modulate = Color(0.35, 0.9, 0.38, 1.0)
			boss_dots[i].color = Color(0.35, 0.9, 0.38, 1.0)
		elif next_up:
			boss_icons[i].modulate = Color(0.08, 0.08, 0.08, 1.0)
			boss_statuses[i].text = "NEXT UP"
			boss_statuses[i].modulate = Color(1.0, 0.55, 0.06, 1.0)
			boss_dots[i].color = Color(1.0, 0.55, 0.06, 1.0)
		else:
			boss_icons[i].modulate = Color(0.04, 0.04, 0.04, 1.0)
			boss_statuses[i].text = "LOCKED"
			boss_statuses[i].modulate = Color(0.52, 0.52, 0.52, 1.0)
			boss_dots[i].color = Color(0.32, 0.32, 0.32, 1.0)

	for i in boss_lines.size():
		var line_color := Color(0.35, 0.9, 0.38, 1.0) if _boss_is_defeated(BOSS_IDS[i]) else Color(0.25, 0.25, 0.25, 1.0)
		boss_lines[i].color = line_color
		boss_line_continuations[i].color = line_color


func _boss_is_defeated(boss_id: StringName) -> bool:
	return boss_id in MetaProgression.defeated_bosses

func _on_loadout_changed() -> void:
	if selected_resource != null and not MetaProgression.is_unlocked(selected_resource):
		selected_resource = null

	_refresh_browser()
	_refresh_equipped()
	_refresh_selected()


func _on_content_unlocked(_id: StringName) -> void:
	_refresh_browser()


func _start_run() -> void:
	GameState.reset()
	get_tree().change_scene_to_file(DUNGEON_SCENE)


func _open_settings() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "SETTINGS"
	dialog.dialog_text = "Settings UI goes here."
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 190))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func _add_empty(container: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(label)

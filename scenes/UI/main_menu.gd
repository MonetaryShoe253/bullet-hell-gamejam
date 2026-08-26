extends CanvasLayer

const DUNGEON_SCENE := "res://scenes/dungeon/dungeon.tscn"

enum GearFilter { WEAPON, ARMOUR, ACCESSORY }

var gear_filter := GearFilter.WEAPON
var active_target_slot := 0
var passive_target_slot := 0

@onready var settings_button: Button = $Root/Margin/VBox/Header/SettingsButton
@onready var start_button: Button = $Root/Margin/VBox/Main/Center/StartRun
@onready var character_texture: TextureRect = $Root/Margin/VBox/Main/Center/CharacterPanel/VBox/Character

@onready var weapons_filter: Button = $Root/Margin/VBox/Main/GearPanel/VBox/Filters/Weapons
@onready var armour_filter: Button = $Root/Margin/VBox/Main/GearPanel/VBox/Filters/Armour
@onready var accessories_filter: Button = $Root/Margin/VBox/Main/GearPanel/VBox/Filters/Accessories
@onready var gear_list: VBoxContainer = $Root/Margin/VBox/Main/GearPanel/VBox/Scroll/GearList

@onready var weapon_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/GearSlots/Weapon
@onready var armour_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/GearSlots/Armour
@onready var accessory_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/GearSlots/Accessory
@onready var q_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/AbilitySlots/Q
@onready var e_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/AbilitySlots/E
@onready var passive_1_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/AbilitySlots/Passive1
@onready var passive_2_slot: Button = $Root/Margin/VBox/Main/Center/Loadout/AbilitySlots/Passive2

@onready var active_list: VBoxContainer = $Root/Margin/VBox/Main/AbilityPanel/VBox/ActiveScroll/ActiveList
@onready var passive_list: VBoxContainer = $Root/Margin/VBox/Main/AbilityPanel/VBox/PassiveScroll/PassiveList

@onready var boss_names: Array[Label] = [
	$Root/Margin/VBox/BossFooter/BossRow/Pizza/Name,
	$Root/Margin/VBox/BossFooter/BossRow/Burger/Name,
	$Root/Margin/VBox/BossFooter/BossRow/Taco/Name,
	$Root/Margin/VBox/BossFooter/BossRow/Pepper/Name,
]
@onready var boss_icons: Array[TextureRect] = [
	$Root/Margin/VBox/BossFooter/BossRow/Pizza/Icon,
	$Root/Margin/VBox/BossFooter/BossRow/Burger/Icon,
	$Root/Margin/VBox/BossFooter/BossRow/Taco/Icon,
	$Root/Margin/VBox/BossFooter/BossRow/Pepper/Icon,
]

const BOSS_IDS: Array[StringName] = [
	&"boss_pizza_defeated", &"boss_burger_defeated", &"boss_taco_defeated", &"boss_pepper_defeated"
]
const BOSS_LABELS := ["PIZZA", "BURGER", "TACO", "PEPPER"]

func _ready() -> void:
	settings_button.pressed.connect(_open_settings)
	start_button.pressed.connect(_start_run)
	weapons_filter.pressed.connect(func(): _set_gear_filter(GearFilter.WEAPON))
	armour_filter.pressed.connect(func(): _set_gear_filter(GearFilter.ARMOUR))
	accessories_filter.pressed.connect(func(): _set_gear_filter(GearFilter.ACCESSORY))
	q_slot.pressed.connect(func(): active_target_slot = 0)
	e_slot.pressed.connect(func(): active_target_slot = 1)
	passive_1_slot.pressed.connect(func(): passive_target_slot = 0)
	passive_2_slot.pressed.connect(func(): passive_target_slot = 1)
	if not MetaProgression.loadout_changed.is_connected(_refresh_all):
		MetaProgression.loadout_changed.connect(_refresh_all)
	if not MetaProgression.content_unlocked.is_connected(_on_content_unlocked):
		MetaProgression.content_unlocked.connect(_on_content_unlocked)
	_refresh_all()
	start_button.grab_focus()

func _refresh_all() -> void:
	_refresh_gear_list()
	_refresh_ability_lists()
	_refresh_equipped()
	_refresh_bosses()

func _set_gear_filter(filter: GearFilter) -> void:
	gear_filter = filter
	_refresh_gear_list()

func _refresh_gear_list() -> void:
	_clear(gear_list)
	weapons_filter.disabled = gear_filter == GearFilter.WEAPON
	armour_filter.disabled = gear_filter == GearFilter.ARMOUR
	accessories_filter.disabled = gear_filter == GearFilter.ACCESSORY
	var item_type := Item.ItemType.WEAPON
	match gear_filter:
		GearFilter.ARMOUR: item_type = Item.ItemType.ARMOUR
		GearFilter.ACCESSORY: item_type = Item.ItemType.ACCESSORY
	for item: Item in ContentDatabase.get_unlocked_items(item_type):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 76)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = item.item_name + "\n" + item.get_stats_text()
		if item.icon:
			b.icon = item.icon
			b.expand_icon = true
			b.icon_max_width = 56
		b.pressed.connect(func(): MetaProgression.set_equipped_item(item))
		gear_list.add_child(b)
	if gear_list.get_child_count() == 0:
		_add_empty(gear_list, "No starting gear unlocked in this category yet.")

func _refresh_ability_lists() -> void:
	_clear(active_list)
	_clear(passive_list)
	for ability: Ability in ContentDatabase.get_unlocked_active_abilities():
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 76)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s\nCooldown %.1fs" % [ability.ability_name, ability.cooldown]
		if ability.icon:
			b.icon = ability.icon
			b.expand_icon = true
			b.icon_max_width = 56
		b.pressed.connect(func(): MetaProgression.set_active_ability(active_target_slot, ability))
		active_list.add_child(b)
	for passive: PassiveAbility in ContentDatabase.passive_abilities:
		if not MetaProgression.is_unlocked(passive):
			continue

		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 72)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = passive.ability_name + "\n" + passive.description

		if passive.icon:
			b.icon = passive.icon
			b.expand_icon = true
			b.icon_max_width = 52

		b.pressed.connect(
			func():
				MetaProgression.set_passive_ability(passive_target_slot, passive)
				_refresh_loadout()
		)

		passive_list.add_child(b)
	if active_list.get_child_count() == 0:
		_add_empty(active_list, "No active abilities unlocked yet.")
	if passive_list.get_child_count() == 0:
		_add_empty(passive_list, "No passive abilities unlocked yet.")

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
	button.icon = item.icon if item and item.icon else null
	button.expand_icon = true
	button.icon_max_width = 48

func _set_ability_slot(button: Button, title: String, ability: Ability) -> void:
	button.text = "%s\n%s" % [title, ability.ability_name if ability else "Empty"]
	button.icon = ability.icon if ability and ability.icon else null
	button.expand_icon = true
	button.icon_max_width = 48

func _set_passive_slot(button: Button, title: String, passive: PassiveAbility) -> void:
	button.text = "%s\n%s" % [title, passive.ability_name if passive else "Empty"]
	button.icon = passive.icon if passive and "icon" in passive and passive.icon else null
	button.expand_icon = true
	button.icon_max_width = 48

func _refresh_bosses() -> void:
	for i in BOSS_IDS.size():
		var defeated := BOSS_IDS[i] in MetaProgression.unlocked_content
		boss_names[i].text = BOSS_LABELS[i] if defeated else "??????"
		boss_icons[i].modulate = Color.WHITE if defeated else Color(0.06, 0.06, 0.06, 1)

func _start_run() -> void:
	# Coins/gold are run-local: GameState.reset() is the boundary that clears
	# the previous run before SavedBuildLoader applies this selected loadout.
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

func _on_content_unlocked(_id: StringName) -> void:
	_refresh_all()

func _clear(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()

func _add_empty(container: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(label)

extends CanvasLayer

const DUNGEON_SCENE := "res://scenes/dungeon/dungeon.tscn"
const PLAYER_BUILD_SCENE := "res://scenes/UI/player_build.tscn"

const BOSS_UNLOCK_IDS: Array[StringName] = [
	&"boss_pizza_defeated", &"boss_burger_defeated", &"boss_taco_defeated", &"boss_pepper_defeated"
]
const BOSS_NAMES := ["PIZZA", "BURGER", "TACO", "PEPPER"]

const COLOR_DEFEATED := Color(0.43, 0.82, 0.15, 1.0)
const COLOR_NEXT := Color(0.18, 0.61, 0.95, 1.0)
const COLOR_UNKNOWN := Color(0.34, 0.30, 0.31, 1.0)
const COLOR_REVEALED := Color(1.0, 0.55, 0.08, 1.0)

@onready var start_run_button: Button = $Panel/Margin/MainLayout/LeftColumn/StartRun
@onready var continue_button: Button = $Panel/Margin/MainLayout/LeftColumn/ContinueButton
@onready var manage_build_button: Button = $Panel/Margin/MainLayout/LeftColumn/LoadoutButton
@onready var abilities_button: Button = $Panel/Margin/MainLayout/LeftColumn/AbilitiesButton
@onready var stats_button: Button = $Panel/Margin/MainLayout/LeftColumn/StatsButton
@onready var settings_button: Button = $Panel/Margin/MainLayout/LeftColumn/SettingsButton
@onready var exit_button: Button = $Panel/Margin/MainLayout/LeftColumn/ExitButton

@onready var left_coin_label: Label = $Panel/Margin/MainLayout/LeftColumn/CoinPanel/CoinVBox/CoinAmount
@onready var level_label: Label = $Panel/Margin/MainLayout/VBox/LevelLabel
@onready var center_coin_label: Label = $Panel/Margin/MainLayout/VBox/CenterCoin
@onready var play_button: Button = $Panel/Margin/MainLayout/VBox/PlayButton

@onready var bottom_loadout: Button = $Panel/Margin/MainLayout/VBox/BottomNav/Loadout
@onready var bottom_abilities: Button = $Panel/Margin/MainLayout/VBox/BottomNav/Abilities
@onready var bottom_stats: Button = $Panel/Margin/MainLayout/VBox/BottomNav/Stats

@onready var weapon_label: Label = $Panel/Margin/MainLayout/RightColumn/LoadoutPanel/VBox/Slots/Weapon/Label
@onready var armour_label: Label = $Panel/Margin/MainLayout/RightColumn/LoadoutPanel/VBox/Slots/Armour/Label
@onready var accessory_label: Label = $Panel/Margin/MainLayout/RightColumn/LoadoutPanel/VBox/Slots/Accessory/Label
@onready var loadout_hint: Label = $Panel/Margin/MainLayout/RightColumn/LoadoutPanel/VBox/LoadoutHint

@onready var deepest_label: Label = $Panel/Margin/MainLayout/RightColumn/RunStatsPanel/VBox/Deepest
@onready var runs_label: Label = $Panel/Margin/MainLayout/RightColumn/RunStatsPanel/VBox/Runs
@onready var coins_label: Label = $Panel/Margin/MainLayout/RightColumn/RunStatsPanel/VBox/Coins
@onready var bosses_label: Label = $Panel/Margin/MainLayout/RightColumn/RunStatsPanel/VBox/Bosses

@onready var boss_cards: Array[PanelContainer] = [
	$Panel/Margin/MainLayout/VBox/BossRow/PizzaCard,
	$Panel/Margin/MainLayout/VBox/BossRow/BurgerCard,
	$Panel/Margin/MainLayout/VBox/BossRow/TacoCard,
	$Panel/Margin/MainLayout/VBox/BossRow/PepperCard,
]
@onready var progress_dots: Array[Label] = [
	$Panel/Margin/MainLayout/VBox/Progress/Dot1,
	$Panel/Margin/MainLayout/VBox/Progress/Dot2,
	$Panel/Margin/MainLayout/VBox/Progress/Dot3,
	$Panel/Margin/MainLayout/VBox/Progress/Dot4,
]

func _ready() -> void:
	# The redesigned home has one Start action and one Player Build destination.
	continue_button.hide()
	abilities_button.hide()
	stats_button.hide()
	manage_build_button.text = "▣  PLAYER BUILD"
	bottom_loadout.text = "▣  PLAYER BUILD"
	bottom_abilities.hide()
	bottom_stats.hide()

	start_run_button.pressed.connect(_start_run)
	play_button.pressed.connect(_start_run)
	manage_build_button.pressed.connect(_open_player_build)
	bottom_loadout.pressed.connect(_open_player_build)
	settings_button.pressed.connect(_open_settings)
	exit_button.pressed.connect(func(): get_tree().quit())

	if not GameState.money_changed.is_connected(_on_money_changed):
		GameState.money_changed.connect(_on_money_changed)
	if not GameState.level_changed.is_connected(_on_level_changed):
		GameState.level_changed.connect(_on_level_changed)
	if not MetaProgression.content_unlocked.is_connected(_on_content_unlocked):
		MetaProgression.content_unlocked.connect(_on_content_unlocked)
	if MetaProgression.has_signal("loadout_changed") and not MetaProgression.loadout_changed.is_connected(_refresh_build):
		MetaProgression.loadout_changed.connect(_refresh_build)

	refresh_home_screen()
	play_button.grab_focus()

func refresh_home_screen() -> void:
	_on_level_changed(GameState.level)
	_on_money_changed(GameState.money)
	_refresh_build()
	_refresh_bosses()
	_refresh_progression_dots()
	_refresh_run_stats()

func _start_run() -> void:
	GameState.reset()
	get_tree().change_scene_to_file(DUNGEON_SCENE)

func _open_player_build() -> void:
	get_tree().change_scene_to_file(PLAYER_BUILD_SCENE)

func _open_settings() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "SETTINGS"
	dialog.dialog_text = "Settings UI goes here."
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 190))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

func _on_money_changed(total: int) -> void:
	var formatted := _format_number(total)
	left_coin_label.text = "●  %s" % formatted
	center_coin_label.text = "●  %s  PLUCK COINS" % formatted

func _on_level_changed(level: int) -> void:
	level_label.text = "LEVEL %d" % level

func _refresh_build() -> void:
	var weapon = ContentDatabase.find_item(MetaProgression.equipped_weapon_id)
	var armour = ContentDatabase.find_item(MetaProgression.equipped_armour_id)
	var accessory = ContentDatabase.find_item(MetaProgression.equipped_accessory_id)
	weapon_label.text = "WEAPON\n%s" % (weapon.item_name if weapon else "Empty")
	armour_label.text = "ARMOUR\n%s" % (armour.item_name if armour else "Empty")
	accessory_label.text = "ACCESSORY\n%s" % (accessory.item_name if accessory else "Empty")

	var q = ContentDatabase.find_active_ability(MetaProgression.equipped_active_1_id)
	var e = ContentDatabase.find_active_ability(MetaProgression.equipped_active_2_id)
	loadout_hint.text = "Q: %s    •    E: %s" % [q.ability_name if q else "Empty", e.ability_name if e else "Empty"]

func _refresh_run_stats() -> void:
	deepest_label.text = "Deepest Level                                      %d" % GameState.level
	runs_label.text = "Total Runs                                          --"
	coins_label.text = "Current Pluck Coins                         %s" % _format_number(GameState.money)
	bosses_label.text = "Bosses Defeated                              %d / 4" % _bosses_defeated()

func _boss_is_defeated(index: int) -> bool:
	return index >= 0 and index < BOSS_UNLOCK_IDS.size() and BOSS_UNLOCK_IDS[index] in MetaProgression.unlocked_content

func _bosses_defeated() -> int:
	var total := 0
	for i in BOSS_UNLOCK_IDS.size():
		if _boss_is_defeated(i): total += 1
	return total

func _next_boss_index() -> int:
	for i in BOSS_UNLOCK_IDS.size():
		if not _boss_is_defeated(i): return i
	return -1

func _refresh_bosses() -> void:
	var next_boss := _next_boss_index()
	for i in boss_cards.size():
		var card := boss_cards[i]
		var silhouette: Label = card.get_node("VBox/Portrait/Silhouette")
		var boss_name: Label = card.get_node("VBox/Name")
		var status: PanelContainer = card.get_node("VBox/Status")
		var status_label: Label = card.get_node("VBox/Status/Label")
		if _boss_is_defeated(i):
			boss_name.text = BOSS_NAMES[i]
			silhouette.modulate = COLOR_REVEALED
			status_label.text = "DEFEATED ✓"
			status.add_theme_stylebox_override("panel", _status_style(Color(0.12, 0.40, 0.055, 1), COLOR_DEFEATED))
		elif i == next_boss:
			boss_name.text = "??????"
			silhouette.modulate = Color.WHITE
			status_label.text = "NEXT UP"
			status.add_theme_stylebox_override("panel", _status_style(Color(0.055, 0.23, 0.42, 1), COLOR_NEXT))
		else:
			boss_name.text = "??????"
			silhouette.modulate = Color(0.48, 0.42, 0.42, 1)
			status_label.text = "UNKNOWN"
			status.add_theme_stylebox_override("panel", _status_style(Color(0.18, 0.16, 0.17, 1), COLOR_UNKNOWN))

func _refresh_progression_dots() -> void:
	var next_boss := _next_boss_index()
	for i in progress_dots.size():
		var dot := progress_dots[i]
		if _boss_is_defeated(i):
			dot.text = "●"; dot.add_theme_color_override("font_color", COLOR_DEFEATED)
		elif i == next_boss:
			dot.text = "●"; dot.add_theme_color_override("font_color", COLOR_NEXT)
		else:
			dot.text = "○"; dot.add_theme_color_override("font_color", COLOR_UNKNOWN)

func _on_content_unlocked(_id: StringName) -> void:
	_refresh_bosses()
	_refresh_progression_dots()
	_refresh_run_stats()

func _status_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style

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

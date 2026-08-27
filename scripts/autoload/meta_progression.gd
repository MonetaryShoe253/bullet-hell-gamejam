extends Node

const SAVE_PATH := "user://meta_progression.json"

signal content_unlocked(unlock_id: StringName)
signal loadout_changed()
signal progression_reset()

var unlocked_content: Array[StringName] = []
var defeated_bosses: Array[StringName] = []

var equipped_weapon_id: StringName = &""
var equipped_armour_id: StringName = &""
var equipped_accessory_id: StringName = &""
var equipped_active_1_id: StringName = &""
var equipped_active_2_id: StringName = &""
var equipped_passive_1_id: StringName = &""
var equipped_passive_2_id: StringName = &""


func _ready() -> void:
	#load_progression()
	reset_progression()
	

# ---------------------------------------------------------------------------
# SAVE / LOAD
# ---------------------------------------------------------------------------

func load_progression() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No meta progression save found.")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not load meta progression.")
		return

	var data = JSON.parse_string(file.get_as_text())
	if data == null or not data is Dictionary:
		push_error("Meta progression save is invalid.")
		return

	unlocked_content.clear()
	for id in data.get("unlocked_content", []):
		unlocked_content.append(StringName(id))

	defeated_bosses.clear()
	for id in data.get("defeated_bosses", []):
		defeated_bosses.append(StringName(id))

	var loadout: Dictionary = data.get("loadout", {})

	equipped_weapon_id = StringName(loadout.get("weapon", ""))
	equipped_armour_id = StringName(loadout.get("armour", ""))
	equipped_accessory_id = StringName(loadout.get("accessory", ""))
	equipped_active_1_id = StringName(loadout.get("active_1", ""))
	equipped_active_2_id = StringName(loadout.get("active_2", ""))
	equipped_passive_1_id = StringName(loadout.get("passive_1", ""))
	equipped_passive_2_id = StringName(loadout.get("passive_2", ""))


func save_progression() -> void:
	var save_data := {
		"unlocked_content": unlocked_content,
		"defeated_bosses": defeated_bosses,
		"loadout": {
			"weapon": equipped_weapon_id,
			"armour": equipped_armour_id,
			"accessory": equipped_accessory_id,
			"active_1": equipped_active_1_id,
			"active_2": equipped_active_2_id,
			"passive_1": equipped_passive_1_id,
			"passive_2": equipped_passive_2_id,
		}
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not save meta progression.")
		return

	file.store_string(JSON.stringify(save_data))


# ---------------------------------------------------------------------------
# PERMANENT CONTENT
# ---------------------------------------------------------------------------

func is_unlocked(content: Resource) -> bool:
	if content == null:
		return false

	var id := ContentDatabase.get_content_id(content)
	if id == &"":
		return false

	return id in unlocked_content


func unlock(content: Resource) -> bool:
	if content == null:
		return false

	var id := ContentDatabase.get_content_id(content)

	if id == &"":
		push_warning(
			"Cannot unlock resource without a stable content id: %s" % content
		)
		return false

	if id in unlocked_content:
		return false

	unlocked_content.append(id)
	save_progression()
	content_unlocked.emit(id)

	return true


# ---------------------------------------------------------------------------
# STARTING ITEMS
# ---------------------------------------------------------------------------

func set_equipped_item(item: Item) -> void:
	if item == null:
		return

	# Starting builds may only contain permanently unlocked content.
	if not is_unlocked(item):
		return

	var id := ContentDatabase.get_content_id(item)

	match item.item_type:
		Item.ItemType.WEAPON:
			equipped_weapon_id = id
		Item.ItemType.ARMOUR:
			equipped_armour_id = id
		Item.ItemType.ACCESSORY:
			equipped_accessory_id = id
		_:
			return

	save_progression()
	loadout_changed.emit()


func unequip_item(item_type: Item.ItemType) -> void:
	match item_type:
		Item.ItemType.WEAPON:
			equipped_weapon_id = &""
		Item.ItemType.ARMOUR:
			equipped_armour_id = &""
		Item.ItemType.ACCESSORY:
			equipped_accessory_id = &""
		_:
			return

	save_progression()
	loadout_changed.emit()


# ---------------------------------------------------------------------------
# STARTING ACTIVE ABILITIES
# ---------------------------------------------------------------------------

func set_active_ability(slot: int, ability: Ability) -> void:
	if ability != null and not is_unlocked(ability):
		return

	var id := ContentDatabase.get_content_id(ability) if ability else &""

	match slot:
		0:
			equipped_active_1_id = id
		1:
			equipped_active_2_id = id
		_:
			return

	save_progression()
	loadout_changed.emit()


# ---------------------------------------------------------------------------
# STARTING PASSIVE ABILITIES
# ---------------------------------------------------------------------------

func set_passive_ability(slot: int, passive: PassiveAbility) -> void:
	if passive != null and not is_unlocked(passive):
		return

	var id := ContentDatabase.get_content_id(passive) if passive else &""

	match slot:
		0:
			equipped_passive_1_id = id
		1:
			equipped_passive_2_id = id
		_:
			return

	save_progression()
	loadout_changed.emit()


# ---------------------------------------------------------------------------
# BOSS PROGRESSION
# ---------------------------------------------------------------------------

func mark_boss_defeated(boss_id: StringName) -> void:
	if boss_id == &"" or boss_id in defeated_bosses:
		return

	defeated_bosses.append(boss_id)
	save_progression()


# ---------------------------------------------------------------------------
# DEATH REWARDS
# ---------------------------------------------------------------------------

func get_reward_tier(level_reached: int) -> int:
	return clampi(1 + int((level_reached - 1) / 2), 1, 5)


func get_unlock_choices(
	level_reached: int,
	count: int = 3
) -> Array[Resource]:
	var max_tier := get_reward_tier(level_reached)
	var candidates: Array[Resource] = []

	for content in ContentDatabase.get_all_content():
		if content == null:
			continue

		if is_unlocked(content):
			continue

		if not "unlock_tier" in content:
			continue

		var tier := clampi(int(content.unlock_tier), 1, 5)

		if tier <= max_tier:
			candidates.append(content)

	candidates.shuffle()

	if candidates.size() > count:
		candidates.resize(count)

	return candidates


# ---------------------------------------------------------------------------
# RESET
# ---------------------------------------------------------------------------

func reset_progression() -> void:
	unlocked_content.clear()
	defeated_bosses.clear()

	equipped_weapon_id = &""
	equipped_armour_id = &""
	equipped_accessory_id = &""
	equipped_active_1_id = &""
	equipped_active_2_id = &""
	equipped_passive_1_id = &""
	equipped_passive_2_id = &""

	if FileAccess.file_exists(SAVE_PATH):
		var absolute_path := ProjectSettings.globalize_path(SAVE_PATH)
		var error := DirAccess.remove_absolute(absolute_path)

		if error != OK:
			push_error(
				"Failed to delete meta progression save. Error: %s" % error
			)

	progression_reset.emit()
	loadout_changed.emit()

	print("Meta progression reset.")

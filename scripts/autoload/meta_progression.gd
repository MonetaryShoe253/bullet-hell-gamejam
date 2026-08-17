extends Node

const SAVE_PATH := "user://meta_progression.json"

signal content_unlocked(unlock_id: StringName)

var unlocked_content: Array[StringName] = []

func _ready() -> void:
	#load_progression()
	reset_progression()
	
func load_progression() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No meta progression save found.")
		return

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"Could not load meta progression."
		)
		return

	var json_text := file.get_as_text()

	var data = JSON.parse_string(json_text)

	if data == null:
		push_error(
			"Meta progression save is invalid."
		)
		return

	if data.has("unlocked_content"):
		unlocked_content.clear()

		for id in data["unlocked_content"]:
			unlocked_content.append(
				StringName(id)
			)
			
func save_progression() -> void:
	var save_data := {
		"unlocked_content": unlocked_content
	}

	var file := FileAccess.open(
		SAVE_PATH,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"Could not save meta progression."
		)
		return

	file.store_string(
		JSON.stringify(save_data)
	)

func is_unlocked(content: Resource) -> bool:
	if content.unlocked_by_default:
		return true

	return content.unlock_id in unlocked_content


func unlock(content: Resource) -> bool:
	if content == null:
		return false

	if is_unlocked(content):
		return false

	unlocked_content.append(content.unlock_id)

	content_unlocked.emit(content.unlock_id)

	save_progression()

	return true
	

func get_reward_tier(level_reached: int) -> int:
	return clampi(
		1 + int((level_reached - 1) / 2),
		1,
		5
	)
	
func get_unlock_choices(
	level_reached: int,
	count: int = 3
) -> Array[Resource]:

	var reward_tier := get_reward_tier(level_reached)

	var choices: Array[Resource] = []

	for tier in range(reward_tier, 0, -1):

		var tier_candidates: Array[Resource] = []

		for content in ContentDatabase.get_all_content():

			if is_unlocked(content):
				continue

			if content.unlock_tier != tier:
				continue

			if content in choices:
				continue

			tier_candidates.append(content)

		tier_candidates.shuffle()

		for candidate in tier_candidates:
			choices.append(candidate)

			if choices.size() >= count:
				return choices

	return choices


func reset_progression() -> void:
	unlocked_content.clear()

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(SAVE_PATH)
		)

	print("Meta progression reset.")

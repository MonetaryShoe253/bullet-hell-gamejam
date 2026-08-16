extends Node
## Autoload. One place to spawn the transient visual feedback used all over
## the run - damage numbers, money popups, the level-up banner - so callers
## don't each need a preload and don't need to know where the popup should be
## parented.

const FloatingTextScene := preload("res://scenes/UI/floating_text.tscn")
const LevelBannerScene := preload("res://scenes/UI/level_banner.tscn")


func damage_number(world_position: Vector2, amount: float) -> void:
	_spawn_text(world_position, "-%d" % int(round(amount)), Color(1.0, 0.25, 0.2))


func money_popup(world_position: Vector2, amount: int) -> void:
	_spawn_text(world_position, "+%d" % amount, Color(1.0, 0.85, 0.2))


func level_banner(text: String) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var banner := LevelBannerScene.instantiate()
	scene.add_child(banner)
	banner.show_text(text)


func _spawn_text(world_position: Vector2, text: String, color: Color) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var popup := FloatingTextScene.instantiate()
	scene.add_child(popup)
	popup.global_position = world_position
	popup.show_text(text, color)

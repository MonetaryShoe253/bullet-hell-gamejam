class_name Item
extends Resource

enum ItemType {
	ARMOUR,
	WEAPON,
	ACCESSORY
}

@export_category("Item")
@export var item_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var item_type: ItemType
@export var price: int = 50

@export_category("Stats")
@export var max_health: float = 0.0
@export var damage: float = 0.0
@export var move_speed: float = 0.0
@export var fire_rate_multiplier: float = 1.0
@export var dash_cooldown: float = 0.0
@export var projectile_range: float = 0.0
func get_stats_text() -> String:
	var lines: Array[String] = []

	if max_health != 0:
		lines.append(_format_stat(max_health) + " Max Health")

	if damage != 0:
		lines.append(_format_stat(damage) + " Damage")

	if move_speed != 0:
		lines.append(_format_stat(move_speed) + " Move Speed")

	if projectile_range != 0:
		lines.append(_format_stat(projectile_range) + " Range")

	if fire_rate_multiplier != 0:
		lines.append(_format_stat(fire_rate_multiplier) + " Fire Rate")

	if dash_cooldown != 0:
		lines.append(_format_stat(dash_cooldown) + " Dash Cooldown")

	return "\n".join(lines)


func _format_stat(value: float) -> String:
	var formatted := "%.2f" % abs(value)

	formatted = formatted.rstrip("0").rstrip(".")

	if value > 0:
		return "+" + formatted
	elif value < 0:
		return "-" + formatted

	return "0"

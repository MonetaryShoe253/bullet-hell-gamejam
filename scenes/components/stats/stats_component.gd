class_name StatsComponent
extends Node

signal stats_changed

@export_category("Base Stats")

@export var base_max_health: float = 100.0
@export var base_damage: float = 5.0
@export var base_move_speed: float = 250.0
@export var base_fire_rate: float = 0.3
@export var base_dash_cooldown: float = 0.75
@export var base_projectile_range: float = 600.0

var shop_max_health: float = 0.0
var shop_damage: float = 0.0
var shop_move_speed: float = 0.0
var shop_fire_rate: float = 0.0
var shop_dash_cooldown: float = 0.0
var shop_projectile_range: float = 0.0

var equipment_max_health: float = 0.0
var equipment_damage: float = 0.0
var equipment_move_speed: float = 0.0
var equipment_fire_rate: float = 0.0
var equipment_dash_cooldown: float = 0.0
var equipment_projectile_range: float = 0.0

func get_max_health() -> float:
	return (
		base_max_health
		+ shop_max_health
		+ equipment_max_health
	)


func get_damage() -> float:
	return (
		base_damage
		+ shop_damage
		+ equipment_damage
	)


func get_move_speed() -> float:
	return (
		base_move_speed
		+ shop_move_speed
		+ equipment_move_speed
	)


func get_fire_rate() -> float:
	return max(
		0.05,
		base_fire_rate
		- shop_fire_rate
		- equipment_fire_rate
	)


func get_dash_cooldown() -> float:
	return max(
		0.1,
		base_dash_cooldown
		- shop_dash_cooldown
		- equipment_dash_cooldown
	)


func get_projectile_range() -> float:
	return (
		base_projectile_range
		+ shop_projectile_range
		+ equipment_projectile_range
	)
	
func apply_shop_upgrade(upgrade: ShopUpgrade) -> void:
	match upgrade.type:

		ShopUpgrade.UpgradeType.MAX_HEALTH:
			shop_max_health += upgrade.amount

		ShopUpgrade.UpgradeType.DAMAGE:
			shop_damage += upgrade.amount

		ShopUpgrade.UpgradeType.MOVE_SPEED:
			shop_move_speed += upgrade.amount

		ShopUpgrade.UpgradeType.FIRE_RATE:
			shop_fire_rate += upgrade.amount

		ShopUpgrade.UpgradeType.DASH_COOLDOWN:
			shop_dash_cooldown += upgrade.amount

		#ShopUpgrade.UpgradeType.RANGE:
		#	shop_projectile_range += upgrade.amount

	stats_changed.emit()
	
func set_equipment(
	armour: Item,
	weapon: Item,
	accessory: Item
) -> void:
	# Reset all equipment bonuses first.
	equipment_max_health = 0.0
	equipment_damage = 0.0
	equipment_move_speed = 0.0
	equipment_fire_rate = 0.0
	equipment_dash_cooldown = 0.0
	equipment_projectile_range = 0.0

	_apply_item_stats(armour)
	_apply_item_stats(weapon)
	_apply_item_stats(accessory)

	stats_changed.emit()
	
func _apply_item_stats(item: Item) -> void:
	if item == null:
		return

	equipment_max_health += item.max_health
	equipment_damage += item.damage
	equipment_move_speed += item.move_speed
	equipment_fire_rate += item.fire_rate_multiplier
	equipment_dash_cooldown += item.dash_cooldown
	equipment_projectile_range += item.projectile_range

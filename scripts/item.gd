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

class_name ShopUpgrade
extends Resource

enum UpgradeType {
	MAX_HEALTH,
	MOVE_SPEED,
	DAMAGE,
	FIRE_RATE,
	DASH_COOLDOWN
}

@export_category("Unlock")

@export var unlock_id: StringName
@export var unlocked_by_default: bool = false
@export_range(1, 10) var unlock_tier: int = 1

@export_category("Upgrade")
@export var upgrade_name: String
@export_multiline var description: String
@export var price: int = 20

@export var type: UpgradeType
@export var amount: float

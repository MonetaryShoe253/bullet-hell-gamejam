class_name ShopUpgrade
extends Resource

enum UpgradeType {
	MAX_HEALTH,
	MOVE_SPEED,
	DAMAGE,
	FIRE_RATE,
	DASH_COOLDOWN
}

@export var upgrade_name: String
@export_multiline var description: String
@export var price: int = 20

@export var type: UpgradeType
@export var amount: float

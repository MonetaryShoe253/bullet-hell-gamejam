class_name ContentDatabase
extends RefCounted


const ITEMS: Array[Item] = [
	preload("res://resources/items/bucket_helmet.tres"),
	preload("res://resources/items/crispy_armour.tres"),
	preload("res://resources/items/chicken_boots.tres"),
	preload("res://resources/items/hot_wings.tres"),
	# Add your other item resources here.
]


const UPGRADES: Array[ShopUpgrade] = [
	preload("res://resources/shop_upgrades/extra_health.tres"),
	preload("res://resources/shop_upgrades/extra_damage.tres"),	
	preload("res://resources/shop_upgrades/faster_dash.tres"),
	preload("res://resources/shop_upgrades/faster_firing.tres"),
	preload("res://resources/shop_upgrades/faster_movement.tres"),
	# Add your other upgrade resources here.
]


static func get_all_content() -> Array[Resource]:
	var content: Array[Resource] = []

	for item in ITEMS:
		content.append(item)

	for upgrade in UPGRADES:
		content.append(upgrade)

	return content

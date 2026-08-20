class_name ContentDatabase
extends RefCounted


const ITEMS: Array[Item] = [
	preload("res://resources/items/Barrel Armour.tres"),
	preload("res://resources/items/Bucket Helmet.tres"),
	preload("res://resources/items/Chicken Apron.tres"),
	preload("res://resources/items/Chicken Breast Plate.tres"),
	preload("res://resources/items/Chicken Bucket.tres"),
	preload("res://resources/items/Chicken Cleaver.tres"),
	preload("res://resources/items/Chicken Coat.tres"),
	preload("res://resources/items/Chicken Shield.tres"),
	preload("res://resources/items/Cob of Corn.tres"),
	preload("res://resources/items/Crossbow.tres"),
	preload("res://resources/items/Egg Amulet.tres"),
	preload("res://resources/items/Egg Hat.tres"),
	preload("res://resources/items/Egg Launcher.tres"),
	preload("res://resources/items/Egg Sling-shot.tres"),
	preload("res://resources/items/Farmer's Bandana.tres"),
	preload("res://resources/items/Farmer's Hat.tres"),
	preload("res://resources/items/Feather Cloak.tres"),
	preload("res://resources/items/Feather Sword.tres"),
	preload("res://resources/items/Feather Tunic.tres"),
	preload("res://resources/items/Fork.tres"),
	preload("res://resources/items/Fried Egg Pan.tres"),
	preload("res://resources/items/Golden Chicken Ring.tres"),
	preload("res://resources/items/Golden Chicken Wing.tres"),
	preload("res://resources/items/Golden Shield.tres"),
	preload("res://resources/items/Hot Sauce.tres"),
	preload("res://resources/items/Mascot Hood.tres"),
	preload("res://resources/items/Nugget Shield.tres"),
	preload("res://resources/items/Shell Helmet.tres"),
	preload("res://resources/items/Skewer.tres"),
	preload("res://resources/items/Spatchula.tres"),
	preload("res://resources/items/Toast.tres"),
	preload("res://resources/items/Whisk.tres"),
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

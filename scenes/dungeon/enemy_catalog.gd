class_name EnemyCatalog
extends RefCounted
## Simple enemy data table. New normal enemies should only need a definition
## here plus their scene. The spawner automatically handles level eligibility,
## threat cost, weighting, theme preference and tactical spawn role.

enum SpawnRole { ANY, FRONTLINE, FLANKER, BACKLINE }

const SlimeScene := preload("res://scenes/enemies/slime/slime.tscn")
const BurgerScene := preload("res://scenes/enemies/burger/burger.tscn")
const TacoScene := preload("res://scenes/enemies/taco/taco.tscn")
const PizzaScene := preload("res://scenes/enemies/pizza/pizza.tscn")

const SlimeProjectile := preload(
	"res://scenes/projectiles/enemybullet/enemybullet.tscn"
)
const BurgerProjectile := preload(
	"res://scenes/projectiles/enemybullet/lettuce.tscn"
)
const TacoProjectile := preload(
	"res://scenes/projectiles/enemybullet/dorito.tscn"
)
const PizzaProjectile := preload(
	"res://scenes/projectiles/enemybullet/pepperoni.tscn"
)

const ENEMIES: Array[Dictionary] = [
	{
		"id": &"slime_basic", "scene": SlimeScene,		
		"projectile_scene": SlimeProjectile,
		"theme": DungeonGenerator.RoomTheme.NONE, "min_level": 1,
		"cost": 1.0, "weight": 1.0, "role": SpawnRole.FRONTLINE,
		"color": Color(1, 1, 1, 1), "health": 26.0, "damage": 5.0,
		"move_speed": 90.0, "fire_rate": 0.8, "money_reward": 4,
		"shot_pattern": Enemy.ShotPattern.SINGLE,
		"movement_pattern": Enemy.MovementPattern.CHASE,
	},
	{
		"id": &"burger", "scene": BurgerScene,
		"projectile_scene": BurgerProjectile,
		"theme": DungeonGenerator.RoomTheme.BURGER, "min_level": 1,
		"cost": 1.8, "weight": 1.3, "role": SpawnRole.FRONTLINE,
		"health": 31.0, "damage": 5.0, "move_speed": 160.0,
		"fire_rate": 1.1, "money_reward": 5,
		"shot_pattern": Enemy.ShotPattern.SPREAD,
		"movement_pattern": Enemy.MovementPattern.ORBIT,
	},
	{
		"id": &"taco", "scene": TacoScene,		
		"projectile_scene": TacoProjectile,
		"theme": DungeonGenerator.RoomTheme.TACO, "min_level": 1,
		"cost": 1.5, "weight": 1.3, "role": SpawnRole.FLANKER,
		"health": 22.0, "damage": 6.0, "move_speed": 140.0,
		"fire_rate": 0.9, "money_reward": 5,
		"shot_pattern": Enemy.ShotPattern.BURST,
		"movement_pattern": Enemy.MovementPattern.STRAFE,
	},
	{
		"id": &"pizza", "scene": PizzaScene,
		"projectile_scene": PizzaProjectile,
		"theme": DungeonGenerator.RoomTheme.PIZZA, "min_level": 1,
		"cost": 1.9, "weight": 1.3, "role": SpawnRole.BACKLINE,
		"health": 18.0, "damage": 8.0, "move_speed": 100.0,
		"fire_rate": 0.5, "money_reward": 5,
		"shot_pattern": Enemy.ShotPattern.SINGLE,
		"movement_pattern": Enemy.MovementPattern.KITE,
	}
]

const BOSSES: Array[Dictionary] = [	
	{
	"id": &"pizza_boss",
	"scene": PizzaScene,
	"projectile_scene": PizzaProjectile,
	"color": Color(0.75, 0.3, 0.95, 1),
	"health": 380.0,
	"damage": 10.0,
	"move_speed": 85.0,
	"fire_rate": 0.65,
	"money_reward": 100,
	"scale": 2.6,
	"shot_pattern": Enemy.ShotPattern.RING_GAP,
	"movement_pattern": Enemy.MovementPattern.CHASE,
	"ring_gap_projectiles": 22,
	"ring_gap_size": 55.0,
	"ring_gap_rotation_speed": 22.0,
	"preferred_distance": 100.0,
	"distance_tolerance": 25.0,
	},
	{
		"id": &"burger_boss",
		"scene": BurgerScene,				
		"projectile_scene": BurgerProjectile,
		"color": Color(0.75, 0.3, 0.95, 1),
		"health": 280.0,
		"damage": 13.0,
		"move_speed": 400.0,
		"fire_rate": 0.30,
		"money_reward": 70,		
		"scale": 2.4,
		"shot_pattern": Enemy.ShotPattern.SPIRAL,
		"movement_pattern": Enemy.MovementPattern.ORBIT,
		"spiral_projectiles": 4,
		"spiral_rotation_speed": 5.7,
		"preferred_distance": 150.0,
	},	
	{
		"id": &"taco_boss",
		"scene": TacoScene,
		"projectile_scene": TacoProjectile,		
		"color": Color(0.75, 0.3, 0.95, 1),
		"health": 300.0,
		"damage": 14.0,
		"move_speed": 190.0,
		"fire_rate": 0.8,
		"money_reward": 85,
		"scale": 2.4,
		"shot_pattern": Enemy.ShotPattern.CROSS_BURST,
		"movement_pattern": Enemy.MovementPattern.STRAFE,
		"cross_burst_count": 4,
		"cross_burst_projectiles": 5,
		"cross_burst_angle": 180.0,
		"cross_burst_rotation": 8.0,
		"cross_burst_delay": 0.18,
		"preferred_distance": 250.0,
		"distance_tolerance": 25.0,
	},
	{
	"id": &"slime_boss",
	"scene": SlimeScene,	
	"projectile_scene": SlimeProjectile,
	"color": Color(0.75, 0.3, 0.95, 1),
	"health": 400.0,
	"damage": 25.0,
	"move_speed": 70.0,
	"fire_rate": 0.2,
	"money_reward": 60,
	"scale": 2.4,
	"shot_pattern": Enemy.ShotPattern.SPIRAL,
	"movement_pattern": Enemy.MovementPattern.CHASE,
	"spiral_projectiles": 12,
	"spiral_rotation_speed": 7.0,
}
]


static func eligible(level: int, theme: DungeonGenerator.RoomTheme) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition: Dictionary in ENEMIES:
		if int(definition.get("min_level", 1)) > level:
			continue
		var enemy_theme: DungeonGenerator.RoomTheme = definition.get("theme", DungeonGenerator.RoomTheme.NONE)
		if enemy_theme == DungeonGenerator.RoomTheme.NONE or enemy_theme == theme:
			result.append(definition)
	return result

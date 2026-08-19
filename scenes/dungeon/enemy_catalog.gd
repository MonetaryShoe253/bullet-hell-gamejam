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
		"color": Color(1, 1, 1, 1), "health": 18.0, "damage": 5.0,
		"move_speed": 90.0, "fire_rate": 0.8, "money_reward": 4,
		"shot_pattern": Enemy.ShotPattern.SINGLE,
		"movement_pattern": Enemy.MovementPattern.CHASE,
	},
	{
		"id": &"slime_fast", "scene": SlimeScene,		
		"projectile_scene": SlimeProjectile,
		"theme": DungeonGenerator.RoomTheme.NONE, "min_level": 1,
		"cost": 1.6, "weight": 0.75, "role": SpawnRole.FLANKER,
		"color": Color(0.35, 0.65, 1.0, 1), "health": 12.0, "damage": 3.0,
		"move_speed": 150.0, "fire_rate": 0.5, "money_reward": 5,
		"shot_pattern": Enemy.ShotPattern.BURST,
		"movement_pattern": Enemy.MovementPattern.STRAFE,
	},
	{
		"id": &"slime_heavy", "scene": SlimeScene,
		"projectile_scene": SlimeProjectile,
		"theme": DungeonGenerator.RoomTheme.NONE, "min_level": 3,
		"cost": 2.6, "weight": 0.55, "role": SpawnRole.FRONTLINE,
		"color": Color(1.0, 0.35, 0.35, 1), "health": 32.0, "damage": 10.0,
		"move_speed": 55.0, "fire_rate": 1.0, "money_reward": 7,
		"shot_pattern": Enemy.ShotPattern.SPREAD,
		"movement_pattern": Enemy.MovementPattern.BOUNCE,
	},
	{
		"id": &"burger", "scene": BurgerScene,
		"projectile_scene": BurgerProjectile,
		"theme": DungeonGenerator.RoomTheme.BURGER, "min_level": 1,
		"cost": 1.8, "weight": 1.3, "role": SpawnRole.FRONTLINE,
		"health": 22.0, "damage": 5.0, "move_speed": 80.0,
		"fire_rate": 1.1, "money_reward": 5,
		"shot_pattern": Enemy.ShotPattern.SPREAD,
		"movement_pattern": Enemy.MovementPattern.CHASE,
	},
	{
		"id": &"taco", "scene": TacoScene,		
		"projectile_scene": TacoProjectile,
		"theme": DungeonGenerator.RoomTheme.TACO, "min_level": 1,
		"cost": 1.7, "weight": 1.3, "role": SpawnRole.FLANKER,
		"health": 14.0, "damage": 5.0, "move_speed": 140.0,
		"fire_rate": 0.9, "money_reward": 5,
		"shot_pattern": Enemy.ShotPattern.BURST,
		"movement_pattern": Enemy.MovementPattern.STRAFE,
	},
	{
		"id": &"pizza", "scene": PizzaScene,
		"projectile_scene": PizzaProjectile,
		"theme": DungeonGenerator.RoomTheme.PIZZA, "min_level": 1,
		"cost": 1.9, "weight": 1.3, "role": SpawnRole.BACKLINE,
		"health": 18.0, "damage": 5.0, "move_speed": 100.0,
		"fire_rate": 1.0, "money_reward": 5,
		"shot_pattern": Enemy.ShotPattern.SINGLE,
		"movement_pattern": Enemy.MovementPattern.KITE,
	},
]

const BOSSES: Array[Dictionary] = [
	{
		"id": &"burger_boss",
		"scene": BurgerScene,				
		"projectile_scene": BurgerProjectile,
		"color": Color(0.75, 0.3, 0.95, 1),
		"health": 280.0,
		"damage": 10.0,
		"move_speed": 100.0,
		"fire_rate": 0.15,
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
	"health": 320.0,
	"damage": 11.0,
	"move_speed": 175.0,
	"fire_rate": 0.14,
	"money_reward": 85,
	"scale": 2.4,
	"shot_pattern": Enemy.ShotPattern.WAVE,
	"movement_pattern": Enemy.MovementPattern.STRAFE,
	"wave_angle": 50.0,
	"wave_step": 9.0,
	"preferred_distance": 130.0,
	"distance_tolerance": 25.0,
	},
	{
	"id": &"pizza_boss",
	"scene": PizzaScene,
	"projectile_scene": PizzaProjectile,
	"color": Color(0.75, 0.3, 0.95, 1),
	"health": 380.0,
	"damage": 13.0,
	"move_speed": 85.0,
	"fire_rate": 0.75,
	"money_reward": 100,
	"scale": 2.6,
	"shot_pattern": Enemy.ShotPattern.RING_GAP,
	"movement_pattern": Enemy.MovementPattern.CHASE,
	"ring_gap_projectiles": 18,
	"ring_gap_size": 65.0,
	"ring_gap_rotation_speed": 22.0,
	"preferred_distance": 100.0,
	"distance_tolerance": 25.0,
	},
	{
	"id": &"slime_boss",
	"scene": SlimeScene,	
	"projectile_scene": SlimeProjectile,
	"color": Color(0.75, 0.3, 0.95, 1),
	"health": 280.0,
	"damage": 12.0,
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

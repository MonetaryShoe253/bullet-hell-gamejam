class_name Player
extends CharacterBody2D

@export var muzzle_offset: float = 30.0  # distance from player center to spawn point


@export_category("Dash")
@export var dash_speed: float = 800.0
@export var dash_duration: float = 0.15

var is_dashing: bool = false
var can_dash: bool = true
var dash_direction: Vector2
var dash_cooldown_remaining: float = 0.0

## Separate movement state for the Damage Dash ability - deliberately not
## sharing is_dashing/can_dash/dash_cooldown_remaining with the regular dash
## above, since the ability has its own cooldown on AbilityComponent.
var is_ability_dashing: bool = false
var ability_dash_direction: Vector2

var _ability_dash_speed: float = 0.0
var _ability_dash_damage: float = 0.0
var _ability_dash_hit_radius: float = 0.0
var _ability_dash_hit_enemies: Array[Node2D] = []

@onready var hurt_box: HurtboxComponent = $Components/HurtBox
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var inventory: InventoryComponent = $Components/InventoryComponent
@onready var stats: StatsComponent = $Components/StatsComponent
@onready var passive_ability_component: PassiveAbilityComponent = $Components/PassiveAbilityComponent
@onready var ability_component: AbilityComponent = $Components/AbilityComponent

## Index order matches an angle sector walk (45 deg each) starting at east and
## going clockwise - Y is down in Godot 2D, so a positive angle sweeps toward
## south, matching the sprite sheet's own direction names.
const FACING_NAMES: Array[String] = [
	"east", "south_east", "south", "south_west",
	"west", "north_west", "north", "north_east",
]

var _facing: String = "south"

## The attack SpriteFrames animation is 7 frames at 12 fps (~0.58s) as
## authored - matches this so the throw motion actually finishes around the
## same time a shot at the *default* fire_rate goes off. shoot() scales
## AnimatedSprite2D.speed_scale by base_duration/fire_rate so upgrading fire
## rate (see apply_upgrade()) speeds the animation up to match, rather than
## the throw visibly lagging behind shots that are already firing again.
const ATTACK_ANIM_BASE_DURATION: float = 7.0 / 12.0


var projectile_scene: PackedScene = preload("res://scenes/projectiles/playerbullet/playerbullet.tscn")
var time_since_last_shot: float = 0.0

const DeathRewardScene := preload("res://scenes/ui/death_reward_ui.tscn")

const GameOverScene := preload("res://scenes/ui/game_over.tscn")

@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var health_bar: ProgressBar = $HealthBar/HealthBar
@onready var dash_cooldown_bar: ProgressBar = $EnergyBar/EnergyBar
@onready var ability_bars: AbilityBars = $AbilityBars


func _ready() -> void:
	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.current_health

	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	
	stats.stats_changed.connect(_on_stats_changed)
	inventory.equipment_changed.connect(_on_equipment_changed)

	dash_cooldown_bar.min_value = 0.0
	dash_cooldown_bar.max_value = 1.0
	dash_cooldown_bar.value = 1.0	
	
	ability_bars.setup(ability_component)


func _on_health_changed(current_health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = current_health
	
func _on_equipment_changed() -> void:
	stats.set_equipment(
		inventory.equipped_armour,
		inventory.equipped_weapon,
		inventory.equipped_accessory
	)
	
func _on_stats_changed() -> void:
	var old_max_health := health_component.max_health
	var new_max_health := stats.get_max_health()

	var health_difference := new_max_health - old_max_health

	health_component.max_health = new_max_health

	# If max HP increased, give the player that extra HP too.
	if health_difference > 0:
		health_component.current_health += health_difference

	# Make sure current HP can never exceed max.
	health_component.current_health = min(
		health_component.current_health,
		health_component.max_health
	)

	health_component.health_changed.emit(
		health_component.current_health,
		health_component.max_health
	)


func _on_died() -> void:
	
	print("PLAYER DIED")
	var level_reached := GameState.level

	var reward_ui: DeathRewardUI = DeathRewardScene.instantiate()

	get_tree().current_scene.add_child(reward_ui)

	reward_ui.finished.connect(
		_on_death_reward_finished
	)
	
	print("FINISHED SIGNAL CONNECTED")

	reward_ui.open(level_reached)
	
func _on_death_reward_finished() -> void:
	var game_over := GameOverScene.instantiate()

	get_tree().current_scene.add_child(game_over)

	get_tree().paused = true

func _physics_process(delta: float) -> void:
	if is_dashing:
		velocity = dash_direction * dash_speed
	elif is_ability_dashing:
		velocity = ability_dash_direction * _ability_dash_speed
		_damage_ability_dash_path()
	else:
		var direction := Input.get_vector(
			"move_left",
			"move_right",
			"move_up",
			"move_down"
		)

		velocity = direction * stats.get_move_speed()

		if Input.is_action_just_pressed("dash"):
			start_dash()

	move_and_slide()

	# Facing follows movement, not the mouse aim - _facing_for() already keeps
	# whatever direction we last had when velocity is ~zero, so standing
	# still and shooting doesn't flicker the sprite back to some default.
	_facing = _facing_for(velocity)
	_update_animation()

	# Dash cooldown
	if dash_cooldown_remaining > 0.0:
		dash_cooldown_remaining -= delta

		if dash_cooldown_remaining <= 0.0:
			dash_cooldown_remaining = 0.0
			can_dash = true

	dash_cooldown_bar.value = 1.0 - (
		dash_cooldown_remaining / stats.get_dash_cooldown()
	)

	ability_component.handle_input(self)


	# Shooting
	time_since_last_shot += delta

	if (Input.is_action_pressed("shoot") 
	and time_since_last_shot >= stats.get_fire_rate()):
		shoot()
		time_since_last_shot = 0.0

func start_dash() -> void:
	if not can_dash or is_dashing:
		return

	can_dash = false
	is_dashing = true

	dash_direction = (
		get_global_mouse_position() - global_position
	).normalized()

	health_component.invulnerable = true

	await get_tree().create_timer(dash_duration).timeout

	is_dashing = false
	health_component.invulnerable = false

	dash_cooldown_remaining = stats.get_dash_cooldown()


## Self-contained dash used by the Damage Dash ability: moves like a normal
## dash and grants the same invulnerability, but tracked independently of
## is_dashing/can_dash so it never touches the regular dash's cooldown -
## AbilityComponent's own per-slot cooldown is what paces this one.
## post_invincibility_duration keeps invulnerable on for a bit after the
## movement itself ends, without extending is_ability_dashing (so movement
## and input return to normal immediately, only the i-frames linger).
func perform_ability_dash(
	damage: float,
	speed: float,
	duration: float,
	hit_radius: float,
	post_invincibility_duration: float = 0.0
) -> void:
	if is_dashing or is_ability_dashing:
		return

	is_ability_dashing = true
	ability_dash_direction = (
		get_global_mouse_position() - global_position
	).normalized()

	_ability_dash_speed = speed
	_ability_dash_damage = damage
	_ability_dash_hit_radius = hit_radius
	_ability_dash_hit_enemies.clear()

	health_component.invulnerable = true

	await get_tree().create_timer(duration).timeout

	is_ability_dashing = false

	if post_invincibility_duration > 0.0:
		await get_tree().create_timer(post_invincibility_duration).timeout

	health_component.invulnerable = false


## Enemies are on a collision mask the player's own CharacterBody2D doesn't
## test against (the player passes through them during move_and_slide), so
## this is a manual proximity sweep each physics frame rather than reading
## collisions off the dash's own movement. hit_radius is deliberately a bit
## larger than the player's own hurtbox extents so the swept path has some
## width to it, not just a pixel-thin line along the direction of travel.
func _damage_ability_dash_path() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy in _ability_dash_hit_enemies or not (enemy is Node2D):
			continue
		if global_position.distance_to(enemy.global_position) > _ability_dash_hit_radius:
			continue

		_ability_dash_hit_enemies.append(enemy)
		var hurt_box = enemy.get_node("Components/HurtBox")
		hurt_box.take_damage(_ability_dash_damage)

func shoot() -> void:
	var proj: PlayerProjectile = projectile_scene.instantiate()

	proj.damage = stats.get_damage()

	get_tree().current_scene.add_child(proj)

	var aim_direction := (
		get_global_mouse_position() - global_position
	).normalized()

	var spawn_position := global_position + aim_direction * muzzle_offset

	proj.launch(spawn_position, aim_direction)
	sprite.speed_scale = ATTACK_ANIM_BASE_DURATION / maxf(stats.get_fire_rate(), 0.05)
	sprite.play("attack_%s" % _facing)


## Snaps a direction vector to one of the 8 facings the sprite sheet has
## frames for. Falls back to whatever we were already facing for a
## near-zero vector (mouse sitting right on top of the player) instead of
## flickering to a meaningless direction.
func _facing_for(vector: Vector2) -> String:
	if vector.length_squared() < 1.0:
		return _facing
	var index: int = int(round(vector.angle() / (PI / 4.0))) % 8
	if index < 0:
		index += 8
	return FACING_NAMES[index]


## Attack is a one-shot animation (loop = false in the SpriteFrames
## resource) - while it's still playing, leave it alone rather than
## stomping it back to idle/walk every frame.
func _update_animation() -> void:
	if sprite.animation.begins_with("attack_") and sprite.is_playing():
		return
	sprite.speed_scale = 1.0  # attack's own speed_scale (see shoot()) only applies to attack

	var state := "walk" if velocity.length_squared() > 25.0 else "idle"
	var anim_name := "%s_%s" % [state, _facing]
	if sprite.animation != anim_name:
		sprite.play(anim_name)
	
func apply_upgrade(upgrade: ShopUpgrade) -> void:
	stats.apply_shop_upgrade(upgrade)

class_name ForceFieldAbility
extends PassiveAbility

@export_category("Force Field")
@export var field_scene: PackedScene = preload("res://scenes/abilities/force_field/force_field.tscn")
@export var radius: float = 60.0
@export var contact_damage_multiplier: float = 0.6  # 3 dmg at the default 5.0 damage stat
@export var tick_damage_multiplier: float = 0.6  # 3 dmg/sec at the default 5.0 damage stat

var _field: ForceField = null

func equip(player: Player) -> void:
	_field = field_scene.instantiate()
	# Added to current_scene rather than as a child of Player - Player has
	# scale = Vector2(1.5, 1.5) on itself, which would inherit down and
	# scale the field's radius unexpectedly. ForceField tracks the player's
	# position itself each frame instead (see its _physics_process()).
	player.get_tree().current_scene.add_child(_field)
	_field.activate(player, contact_damage_multiplier, tick_damage_multiplier, radius)

func unequip(player: Player) -> void:
	if _field and is_instance_valid(_field):
		_field.queue_free()
	_field = null

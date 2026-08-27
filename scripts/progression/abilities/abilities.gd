class_name Ability
extends Resource

@export_category("Unlock")
@export var unlock_id: StringName = &""
@export_range(1, 5, 1) var unlock_tier: int = 1
@export var unlocked_by_default: bool = false

@export_category("Ability")
@export var ability_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var price: int = 50
@export var cooldown: float = 1.0

## Override in subclasses. caster is the Node2D (Player) that triggered this.
func activate(caster: Node2D) -> void:
	pass

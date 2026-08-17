class_name Ability
extends Resource

@export_category("Ability")
@export var ability_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var cooldown: float = 1.0

## Override in subclasses. caster is the Node2D (Player) that triggered this.
func activate(caster: Node2D) -> void:
	pass

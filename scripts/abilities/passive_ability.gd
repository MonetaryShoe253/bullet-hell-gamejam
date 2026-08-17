class_name PassiveAbility
extends Resource

@export_category("Passive Ability")
@export var ability_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var price: int = 50

## Called once when this lands in a PassiveAbilityComponent slot - wire up
## whatever signals it reacts to here.
func equip(player: Player) -> void:
	pass

## Called if this is ever removed from a slot - undo whatever equip() wired up.
func unequip(player: Player) -> void:
	pass

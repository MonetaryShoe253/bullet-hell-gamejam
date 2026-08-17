class_name AbilityBars
extends CanvasLayer

@onready var _labels: Array[Label] = [$VBox/Slot1/Slot1Label, $VBox/Slot2/Slot2Label]
@onready var _bars: Array[ProgressBar] = [$VBox/Slot1/Slot1Bar, $VBox/Slot2/Slot2Bar]
@onready var _rows: Array[HBoxContainer] = [$VBox/Slot1, $VBox/Slot2]

func setup(ability_component: AbilityComponent) -> void:
	ability_component.cooldown_updated.connect(_on_cooldown_updated)
	refresh(ability_component)

## Re-reads slot contents - call again later if a slot's ability changes
## (e.g. once abilities can be equipped from the inventory menu).
func refresh(ability_component: AbilityComponent) -> void:
	for i in _rows.size():
		var ability: Ability = (
			ability_component.slots[i] if i < ability_component.slots.size() else null
		)

		_rows[i].visible = ability != null
		if ability == null:
			continue

		_labels[i].text = ability.ability_name
		_bars[i].max_value = ability.cooldown
		_bars[i].value = ability.cooldown

func _on_cooldown_updated(index: int, remaining: float, total: float) -> void:
	if index >= _bars.size():
		return
	_bars[index].max_value = total
	_bars[index].value = total - remaining

extends CanvasLayer
## Top-center health bar shown only while a boss is alive. dungeon_map.gd
## calls show_for() once EnemySpawner's deferred spawn_boss() actually
## produces the enemy; the bar hides itself again on that enemy's death.

@onready var bar: ProgressBar = $Bar
@onready var name_label: Label = $NameLabel

var _boss: Node


func _ready() -> void:
	visible = false


func show_for(boss: Node) -> void:
	_boss = boss
	bar.max_value = boss.health_component.max_health
	bar.value = boss.health_component.current_health
	visible = true

	boss.health_component.health_changed.connect(_on_health_changed)
	boss.health_component.died.connect(_on_boss_died, CONNECT_ONE_SHOT)


func _on_health_changed(current: float, max_health: float) -> void:
	bar.max_value = max_health
	bar.value = current


func _on_boss_died() -> void:
	visible = false
	_boss = null

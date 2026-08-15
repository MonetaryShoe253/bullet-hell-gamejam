extends Area2D
class_name EnemyProjectile

signal hit_player(player)

@export var speed: float = 400.0
@export var damage: float = 5.0
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func launch(start_position: Vector2, target_direction: Vector2) -> void:
	global_position = start_position
	direction = target_direction.normalized()
	rotation = direction.angle()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		
		var health_component = body.get_node("Components/HealthComponent")
		var hurt_box = body.get_node("Components/HurtBox")
		if (!health_component.invulnerable):			
			hurt_box.take_damage(damage)			
			queue_free()
	else:
		queue_free()

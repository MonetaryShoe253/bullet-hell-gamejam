extends Sprite2D
## Animates the shockwave ring shader from 0 to 1 over `duration`, then frees
## itself. A plain Sprite2D (not a Control/ColorRect) so it sits in world
## space and follows the game camera correctly - spawned wherever a barrel
## detonates, see exploding_barrel.gd.

@export var duration: float = 0.5


func _ready() -> void:
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, duration)
	tween.finished.connect(queue_free)


func _set_progress(value: float) -> void:
	material.set_shader_parameter("progress", value)

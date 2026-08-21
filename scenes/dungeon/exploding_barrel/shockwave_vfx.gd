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


## Optional - callers that just want the barrel's tuned look can skip this
## entirely. Rescales the sprite so the ring's outer edge lands at `radius`
## world units, for effects whose blast size isn't the barrel's fixed one
## (see ShockwavePulseAbility).
func set_radius(radius: float) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0:
		return
	scale = Vector2.ONE * (radius * 2.0 / texture_size.x)

class_name DamageWave
extends Area2D

@export var wavefront_thickness: float = 8.0
@export var ripple_amplitude: float = 6.0
@export var ripple_frequency: float = 3.0

var direction: Vector2 = Vector2.RIGHT
var half_angle: float = deg_to_rad(15.0)
var damage: float = 10.0
var max_range: float = 300.0
var duration: float = 1.0

var _elapsed: float = 0.0
var _hit_enemies: Array[Node2D] = []
var _base_color: Color

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _visual: Polygon2D = $Polygon2D

func _ready() -> void:
	_base_color = _visual.color

	# Additive blending makes the ribbon read as glowing energy instead of
	# a flat translucent shape - matches other magic-wave VFX conventions.
	var glow_material := CanvasItemMaterial.new()
	glow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_visual.material = glow_material

func launch(
	start_position: Vector2,
	aim_direction: Vector2,
	angle_degrees: float,
	wave_damage: float,
	wave_range: float,
	wave_duration: float
) -> void:
	global_position = start_position
	direction = aim_direction.normalized()
	half_angle = deg_to_rad(angle_degrees) / 2.0
	damage = wave_damage
	max_range = wave_range
	duration = wave_duration

func _physics_process(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	var current_radius := max_range * progress

	(_collision_shape.shape as CircleShape2D).radius = current_radius
	_update_visual(current_radius, progress)
	_damage_new_overlaps()

	if progress >= 1.0:
		queue_free()

func _damage_new_overlaps() -> void:
	for body in get_overlapping_bodies():
		if body in _hit_enemies:
			continue
		if not body.is_in_group("enemy"):
			continue
		if not _within_cone(body):
			continue

		_hit_enemies.append(body)
		var hurt_box = body.get_node("Components/HurtBox")
		hurt_box.take_damage(damage)

func _within_cone(body: Node2D) -> bool:
	var to_body := body.global_position - global_position
	if to_body.length_squared() < 1.0:
		return true
	return absf(direction.angle_to(to_body.normalized())) <= half_angle

## Draws only the leading edge of the wave - a thin ribbon between
## current_radius and (current_radius - wavefront_thickness), with a sine
## ripple on the edge and a fade from opaque (leading) to transparent
## (trailing) so it reads as a flowing burst of energy rather than a rigid
## geometric wedge.
func _update_visual(current_radius: float, progress: float) -> void:
	var inner_radius := maxf(current_radius - wavefront_thickness, 0.0)
	var segments := 16
	var start_angle := direction.angle() - half_angle
	var end_angle := direction.angle() + half_angle

	# Dissolve out over the last stretch of the wave's life instead of
	# popping when queue_free() hits.
	var life_fade := 1.0 - smoothstep(0.7, 1.0, progress)

	var points := PackedVector2Array()
	var colors := PackedColorArray()

	for i in segments + 1:
		var t := float(i) / float(segments)
		var angle := lerpf(start_angle, end_angle, t)
		var jitter := sin(t * TAU * ripple_frequency + _elapsed * 14.0) * ripple_amplitude
		points.append(Vector2.RIGHT.rotated(angle) * (current_radius + jitter))
		colors.append(Color(_base_color.r, _base_color.g, _base_color.b, _base_color.a * life_fade))

	for i in segments + 1:
		var t := 1.0 - float(i) / float(segments)
		var angle := lerpf(start_angle, end_angle, t)
		var jitter := sin(t * TAU * ripple_frequency + _elapsed * 14.0) * ripple_amplitude * 0.5
		points.append(Vector2.RIGHT.rotated(angle) * (inner_radius + jitter))
		colors.append(Color(_base_color.r, _base_color.g, _base_color.b, 0.0))

	_visual.polygon = points
	_visual.vertex_colors = colors

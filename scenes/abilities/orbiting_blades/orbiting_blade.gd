class_name OrbitingBlade
extends Node2D


@export_category("Visuals")

@export var trail_length: int = 8
@export var trail_width: float = 4.0
@export var spin_speed: float = 8.0


@onready var sprite: Sprite2D = $Sprite2D


var trail: Line2D


func _ready() -> void:
	_create_trail()


func _process(delta: float) -> void:
	rotation += spin_speed * delta


func _physics_process(_delta: float) -> void:
	if trail == null:
		return

	trail.add_point(global_position)

	while trail.get_point_count() > trail_length:
		trail.remove_point(0)


func _create_trail() -> void:
	trail = Line2D.new()

	trail.width = trail_width

	var gradient := Gradient.new()

	gradient.set_color(
		0,
		Color(
			1.0,
			0.55,
			0.05,
			0.0
		)
	)

	gradient.set_color(
		1,
		Color(
			1.0,
			0.8,
			0.3,
			0.45
		)
	)

	trail.gradient = gradient

	get_tree().current_scene.add_child.call_deferred(trail)


func cleanup() -> void:
	if trail != null:
		trail.queue_free()

	queue_free()

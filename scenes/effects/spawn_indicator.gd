class_name SpawnIndicator
extends Node2D

@export var duration: float = 1.0

func _ready() -> void:
	modulate.a = 0.45

	var tween := create_tween()
	tween.set_loops()

	tween.tween_property(
		self,
		"scale",
		Vector2(1.35, 1.35),
		0.15
	)

	tween.parallel().tween_property(
		self,
		"modulate:a",
		1.0,
		0.15
	)

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		0.15
	)

	tween.parallel().tween_property(
		self,
		"modulate:a",
		0.45,
		0.15
	)

	await get_tree().create_timer(duration).timeout
	queue_free()

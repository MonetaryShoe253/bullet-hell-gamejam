extends CanvasLayer
## Big centered text that flashes in, holds, then fades - used for "LEVEL 2"
## between dungeons. Screen-space (CanvasLayer), so it isn't affected by the
## camera moving to the new spawn point underneath it.

@onready var label: Label = $Label


func show_text(text: String) -> void:
	label.text = text
	label.modulate = Color(1, 1, 1, 0)
	label.scale = Vector2(0.7, 0.7)
	label.pivot_offset = label.size / 2.0

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.25)
	tween.parallel().tween_property(label, "scale", Vector2.ONE, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.35, 0.15)
	tween.tween_property(label, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

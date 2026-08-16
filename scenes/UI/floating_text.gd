extends Node2D
## A number that rises 50px and fades out, then frees itself. Used for both
## enemy damage ("-10", red) and money drops ("+5", gold) via Fx.

@onready var label: Label = $Label


func show_text(text: String, color: Color) -> void:
	label.text = text
	label.modulate = Color(color.r, color.g, color.b, 1.0)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 50.0, 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)

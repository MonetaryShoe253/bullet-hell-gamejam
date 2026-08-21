class_name SecondLifeBurst
extends Node2D

## Rest sizes authored on the nodes themselves in the .tscn - the animation
## below scales out to these values from something smaller, it doesn't
## invent its own target sizes.
const INNER_REST_SCALE := 25.0
const OUTER_REST_SCALE := 50.0
const OUTER_OVERSHOOT_SCALE := 65.0  # expands past its rest size, shockwave-style

const INNER_PUNCH_DURATION := 0.15
const INNER_FADE_DURATION := 0.55

const OUTER_RAMP_DURATION := 0.12
const OUTER_EXPAND_DURATION := 0.6
const OUTER_FADE_DURATION := 0.35

@onready var glow_outer: Polygon2D = $GlowOuter
@onready var glow_inner: Polygon2D = $GlowInner
@onready var sparkles: CPUParticles2D = $Sparkles


func _ready() -> void:
	sparkles.restart()
	_animate_inner()
	_animate_outer()


## A sharp bright flash at the centre: punches out from small/transparent to
## full size/opacity, then fades away.
func _animate_inner() -> void:
	glow_inner.scale = Vector2.ONE * (INNER_REST_SCALE * 0.3)
	glow_inner.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(glow_inner, "scale", Vector2.ONE * INNER_REST_SCALE, INNER_PUNCH_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(glow_inner, "modulate:a", 1.0, INNER_PUNCH_DURATION)
	tween.tween_property(glow_inner, "modulate:a", 0.0, INNER_FADE_DURATION)


## A slower shockwave ring: fades in, expands past its rest size, then
## dissolves. Drives the whole burst's lifetime - queue_free() once this
## finishes, since it's timed to outlast the inner flash.
func _animate_outer() -> void:
	glow_outer.scale = Vector2.ONE * (OUTER_REST_SCALE * 0.5)
	glow_outer.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(glow_outer, "modulate:a", 0.55, OUTER_RAMP_DURATION)
	tween.parallel().tween_property(glow_outer, "scale", Vector2.ONE * OUTER_OVERSHOOT_SCALE, OUTER_EXPAND_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow_outer, "modulate:a", 0.0, OUTER_FADE_DURATION)
	tween.finished.connect(queue_free)

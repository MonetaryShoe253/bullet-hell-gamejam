class_name DashEffectsComponent
extends Node

@export_category("References")
@export var camera: Camera2D
@export var sprite: AnimatedSprite2D
@export var player: Node2D

@export_category("Dash Camera FX")
@export var dash_camera_lag: float = 35.0
@export var dash_camera_lag_time: float = 0.08
@export var dash_camera_recovery_time: float = 0.22

@export_category("Afterimage FX")
@export var afterimage_interval: float = 0.025
@export var afterimage_lifetime: float = 0.45
@export_range(0.0, 1.0) var afterimage_start_alpha: float = 0.75

@export_category("Dash Line FX")
@export var dash_line_count: int = 5
@export var dash_line_length: float = 30.0
@export var dash_line_lifetime: float = 0.15
@export var dash_line_spread: float = 18.0

@export_category("Damage Dash FX")
@export var damage_ring_interval: float = 0.04
@export var damage_ring_lifetime: float = 0.22


var _camera_default_position: Vector2
var _camera_tween: Tween

var _afterimages_active: bool = false
var _afterimage_timer: float = 0.0

var _damage_trail_active: bool = false
var _damage_ring_timer: float = 0.0
var _damage_hit_radius: float = 0.0


func _ready() -> void:
	if camera != null:
		_camera_default_position = camera.position


func _physics_process(delta: float) -> void:
	_update_afterimages(delta)
	_update_damage_trail(delta)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func start_dash(direction: Vector2) -> void:
	_afterimages_active = true
	_afterimage_timer = 0.0

	_start_camera_lag(direction)
	_spawn_dash_lines(direction)


func end_dash() -> void:
	_afterimages_active = false
	_end_camera_lag()


func start_damage_dash(
	direction: Vector2,
	hit_radius: float
) -> void:
	_afterimages_active = true
	_afterimage_timer = 0.0

	_damage_trail_active = true
	_damage_ring_timer = 0.0
	_damage_hit_radius = hit_radius

	_start_camera_lag(direction)
	_spawn_dash_lines(direction)
	_spawn_damage_dash_ring(hit_radius)


func end_damage_dash() -> void:
	_afterimages_active = false
	_damage_trail_active = false

	_end_camera_lag()


# ---------------------------------------------------------------------------
# Updating
# ---------------------------------------------------------------------------

func _update_afterimages(delta: float) -> void:
	if not _afterimages_active:
		return

	_afterimage_timer -= delta

	if _afterimage_timer <= 0.0:
		_spawn_dash_afterimage()
		_afterimage_timer = afterimage_interval


func _update_damage_trail(delta: float) -> void:
	if not _damage_trail_active:
		return

	_damage_ring_timer -= delta

	if _damage_ring_timer <= 0.0:
		_spawn_damage_trail_ring(_damage_hit_radius)
		_damage_ring_timer = damage_ring_interval


# ---------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------

func _start_camera_lag(direction: Vector2) -> void:
	if camera == null:
		return

	if _camera_tween != null:
		_camera_tween.kill()

	var lag_position := (
		_camera_default_position
		- direction * dash_camera_lag
	)

	_camera_tween = create_tween()

	_camera_tween.tween_property(
		camera,
		"position",
		lag_position,
		dash_camera_lag_time
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)


func _end_camera_lag() -> void:
	if camera == null:
		return

	if _camera_tween != null:
		_camera_tween.kill()

	_camera_tween = create_tween()

	_camera_tween.tween_property(
		camera,
		"position",
		_camera_default_position,
		dash_camera_recovery_time
	).set_trans(
		Tween.TRANS_QUINT
	).set_ease(
		Tween.EASE_OUT
	)


# ---------------------------------------------------------------------------
# Afterimages
# ---------------------------------------------------------------------------

func _spawn_dash_afterimage() -> void:
	if sprite == null:
		return

	var frames := sprite.sprite_frames

	var texture := frames.get_frame_texture(
		sprite.animation,
		sprite.frame
	)

	if texture == null:
		return

	var ghost := Sprite2D.new()

	ghost.texture = texture
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.flip_v = sprite.flip_v

	get_tree().current_scene.add_child(ghost)

	ghost.global_position = sprite.global_position
	ghost.global_rotation = sprite.global_rotation
	ghost.global_scale = sprite.global_scale

	ghost.z_index = sprite.z_index - 1

	ghost.modulate = Color(
		1.0,
		1.0,
		1.0,
		afterimage_start_alpha
	)

	var tween := ghost.create_tween()

	tween.tween_property(
		ghost,
		"modulate:a",
		0.0,
		afterimage_lifetime
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_OUT
	)

	tween.finished.connect(ghost.queue_free)


# ---------------------------------------------------------------------------
# Dash Lines
# ---------------------------------------------------------------------------

func _spawn_dash_lines(direction: Vector2) -> void:
	if player == null:
		return

	var perpendicular := Vector2(
		-direction.y,
		direction.x
	)

	for i in range(dash_line_count):
		var line := Line2D.new()

		line.width = randf_range(1.0, 2.5)
		line.default_color = Color(
			1.0,
			1.0,
			1.0,
			0.65
		)

		var side_offset := randf_range(
			-dash_line_spread,
			dash_line_spread
		)

		var forward_offset := randf_range(
			-10.0,
			10.0
		)

		var start := (
			player.global_position
			+ perpendicular * side_offset
			+ direction * forward_offset
		)

		var end := (
			start
			- direction
			* randf_range(
				dash_line_length * 0.6,
				dash_line_length
			)
		)

		line.add_point(start)
		line.add_point(end)

		get_tree().current_scene.add_child(line)

		var tween := line.create_tween()

		tween.tween_property(
			line,
			"modulate:a",
			0.0,
			dash_line_lifetime
		)

		tween.finished.connect(line.queue_free)


# ---------------------------------------------------------------------------
# Damage Dash
# ---------------------------------------------------------------------------

func _spawn_damage_dash_ring(hit_radius: float) -> void:
	if player == null:
		return

	var ring := _create_ring(
		hit_radius,
		2.5,
		Color(1.0, 0.35, 0.15, 0.8),
		32
	)

	# This initial ring follows the player.
	player.add_child(ring)

	ring.scale = Vector2(0.25, 0.25)

	var tween := ring.create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"scale",
		Vector2.ONE,
		0.12
	).set_trans(
		Tween.TRANS_EXPO
	).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		ring,
		"modulate:a",
		0.0,
		0.25
	)

	tween.chain().tween_callback(
		ring.queue_free
	)


func _spawn_damage_trail_ring(hit_radius: float) -> void:
	if player == null:
		return

	var ring := _create_ring(
		hit_radius,
		2.0,
		Color(1.0, 0.35, 0.15, 0.55),
		24
	)

	# World child = stays behind as the player moves.
	get_tree().current_scene.add_child(ring)

	ring.global_position = player.global_position

	var tween := ring.create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		ring,
		"modulate:a",
		0.0,
		damage_ring_lifetime
	)

	tween.tween_property(
		ring,
		"scale",
		Vector2(1.15, 1.15),
		damage_ring_lifetime
	)

	tween.chain().tween_callback(
		ring.queue_free
	)


func _create_ring(
	radius: float,
	width: float,
	color: Color,
	segments: int
) -> Line2D:
	var ring := Line2D.new()

	ring.width = width
	ring.default_color = color
	ring.closed = true

	for i in range(segments):
		var angle := (
			TAU
			* float(i)
			/ float(segments)
		)

		ring.add_point(
			Vector2(
				cos(angle),
				sin(angle)
			) * radius
		)

	return ring
